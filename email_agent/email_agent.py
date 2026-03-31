"""
Email Checking Agent
--------------------
An AI agent that helps you check and manage your emails using Claude.

Setup:
  1. Copy .env.example to .env and fill in your credentials
  2. pip install -r requirements.txt
  3. python email_agent.py

For Gmail/Google Workspace, use an App Password:
  https://myaccount.google.com/apppasswords
"""

import imaplib
import email
import os
import json
import textwrap
from email.header import decode_header
from datetime import datetime
from dotenv import load_dotenv
import anthropic

load_dotenv()

# ── Email connection ──────────────────────────────────────────────────────────

def get_imap_connection():
    host = os.environ.get("IMAP_HOST", "imap.gmail.com")
    port = int(os.environ.get("IMAP_PORT", "993"))
    address = os.environ["EMAIL_ADDRESS"]
    password = os.environ["EMAIL_PASSWORD"]

    conn = imaplib.IMAP4_SSL(host, port)
    conn.login(address, password)
    return conn


def decode_str(value):
    """Decode an email header value to a plain string."""
    if value is None:
        return ""
    parts = decode_header(value)
    result = []
    for raw, charset in parts:
        if isinstance(raw, bytes):
            result.append(raw.decode(charset or "utf-8", errors="replace"))
        else:
            result.append(raw)
    return " ".join(result)


def get_body(msg):
    """Extract the plain-text body from an email message."""
    if msg.is_multipart():
        for part in msg.walk():
            if part.get_content_type() == "text/plain":
                payload = part.get_payload(decode=True)
                charset = part.get_content_charset() or "utf-8"
                return payload.decode(charset, errors="replace")
    else:
        payload = msg.get_payload(decode=True)
        if payload:
            charset = msg.get_content_charset() or "utf-8"
            return payload.decode(charset, errors="replace")
    return "(no plain-text body)"


# ── Tool implementations ──────────────────────────────────────────────────────

def list_emails(folder: str = "INBOX", count: int = 10, unread_only: bool = False) -> str:
    """List recent emails from a folder."""
    try:
        conn = get_imap_connection()
        conn.select(folder)

        criteria = "UNSEEN" if unread_only else "ALL"
        _, data = conn.search(None, criteria)
        ids = data[0].split()

        if not ids:
            conn.logout()
            return json.dumps({"emails": [], "total": 0})

        # Get the most recent `count` emails (highest IDs = most recent)
        recent_ids = ids[-count:][::-1]

        emails = []
        for uid in recent_ids:
            _, msg_data = conn.fetch(uid, "(RFC822.SIZE BODY.PEEK[HEADER.FIELDS (FROM TO SUBJECT DATE)])")
            raw_header = msg_data[0][1]
            msg = email.message_from_bytes(raw_header)
            emails.append({
                "id": uid.decode(),
                "from": decode_str(msg.get("From")),
                "to": decode_str(msg.get("To")),
                "subject": decode_str(msg.get("Subject")),
                "date": decode_str(msg.get("Date")),
            })

        conn.logout()
        return json.dumps({"emails": emails, "total": len(ids)})
    except Exception as e:
        return json.dumps({"error": str(e)})


def read_email(email_id: str, folder: str = "INBOX") -> str:
    """Read the full content of a specific email by its ID."""
    try:
        conn = get_imap_connection()
        conn.select(folder)

        _, msg_data = conn.fetch(email_id.encode(), "(RFC822)")
        raw = msg_data[0][1]
        msg = email.message_from_bytes(raw)

        result = {
            "id": email_id,
            "from": decode_str(msg.get("From")),
            "to": decode_str(msg.get("To")),
            "subject": decode_str(msg.get("Subject")),
            "date": decode_str(msg.get("Date")),
            "body": get_body(msg)[:4000],  # Cap at 4 000 chars to save tokens
        }

        conn.logout()
        return json.dumps(result)
    except Exception as e:
        return json.dumps({"error": str(e)})


def search_emails(query: str, folder: str = "INBOX", count: int = 10) -> str:
    """Search emails by subject or sender text."""
    try:
        conn = get_imap_connection()
        conn.select(folder)

        # Search in both Subject and From fields
        _, subject_data = conn.search(None, f'SUBJECT "{query}"')
        _, from_data = conn.search(None, f'FROM "{query}"')

        subject_ids = set(subject_data[0].split())
        from_ids = set(from_data[0].split())
        all_ids = sorted(subject_ids | from_ids, key=lambda x: int(x))

        if not all_ids:
            conn.logout()
            return json.dumps({"emails": [], "query": query})

        recent_ids = all_ids[-count:][::-1]

        emails = []
        for uid in recent_ids:
            _, msg_data = conn.fetch(uid, "(BODY.PEEK[HEADER.FIELDS (FROM TO SUBJECT DATE)])")
            raw_header = msg_data[0][1]
            msg = email.message_from_bytes(raw_header)
            emails.append({
                "id": uid.decode(),
                "from": decode_str(msg.get("From")),
                "to": decode_str(msg.get("To")),
                "subject": decode_str(msg.get("Subject")),
                "date": decode_str(msg.get("Date")),
            })

        conn.logout()
        return json.dumps({"emails": emails, "query": query, "found": len(all_ids)})
    except Exception as e:
        return json.dumps({"error": str(e)})


def list_folders() -> str:
    """List all available email folders/mailboxes."""
    try:
        conn = get_imap_connection()
        _, folder_list = conn.list()
        folders = []
        for item in folder_list:
            parts = item.decode().split('"')
            folder_name = parts[-2] if len(parts) >= 3 else parts[-1].strip()
            folders.append(folder_name)
        conn.logout()
        return json.dumps({"folders": folders})
    except Exception as e:
        return json.dumps({"error": str(e)})


# ── Tool definitions for Claude ───────────────────────────────────────────────

TOOLS = [
    {
        "name": "list_emails",
        "description": (
            "List recent emails from a folder. Returns sender, recipient, subject, "
            "date, and ID for each email. Use this to get an overview of the inbox."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "folder": {"type": "string", "description": "Mailbox folder name (default: INBOX)"},
                "count": {"type": "integer", "description": "Number of emails to retrieve (default: 10, max: 50)"},
                "unread_only": {"type": "boolean", "description": "If true, only return unread emails"},
            },
        },
    },
    {
        "name": "read_email",
        "description": (
            "Read the full content (headers + body) of a specific email by its ID. "
            "Get email IDs first by calling list_emails or search_emails."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "email_id": {"type": "string", "description": "The numeric ID of the email to read"},
                "folder": {"type": "string", "description": "Mailbox folder name (default: INBOX)"},
            },
            "required": ["email_id"],
        },
    },
    {
        "name": "search_emails",
        "description": "Search emails by subject or sender. Returns matching emails from the specified folder.",
        "input_schema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Text to search for in subject or sender fields"},
                "folder": {"type": "string", "description": "Mailbox folder name (default: INBOX)"},
                "count": {"type": "integer", "description": "Max number of results to return (default: 10)"},
            },
            "required": ["query"],
        },
    },
    {
        "name": "list_folders",
        "description": "List all available email folders and mailboxes in the account.",
        "input_schema": {
            "type": "object",
            "properties": {},
        },
    },
]

TOOL_HANDLERS = {
    "list_emails": lambda args: list_emails(**args),
    "read_email": lambda args: read_email(**args),
    "search_emails": lambda args: search_emails(**args),
    "list_folders": lambda args: list_folders(),
}

# ── Agentic loop ──────────────────────────────────────────────────────────────

SYSTEM_PROMPT = f"""You are a helpful email assistant for {os.environ.get('EMAIL_ADDRESS', 'the user')}.

You have tools to list, read, and search emails. When the user asks about their emails, use the tools to fetch real data before answering. Always be concise and helpful.

Today's date is {datetime.now().strftime('%B %d, %Y')}.

Guidelines:
- When listing emails, show them in a readable table or list format.
- When reading an email, summarize the key points unless the user asks for the full text.
- If a search returns no results, suggest alternative search terms.
- Never guess email content — always use the tools to get real data."""


def run_agent_turn(client: anthropic.Anthropic, messages: list, user_input: str) -> str:
    """Run one turn of the agent loop and return Claude's final text response."""
    messages.append({"role": "user", "content": user_input})

    while True:
        response = client.messages.create(
            model="claude-opus-4-6",
            max_tokens=4096,
            system=SYSTEM_PROMPT,
            tools=TOOLS,
            messages=messages,
            thinking={"type": "adaptive"},
        )

        # Append assistant response to history
        messages.append({"role": "assistant", "content": response.content})

        if response.stop_reason == "end_turn":
            # Extract and return the text response
            for block in response.content:
                if hasattr(block, "text"):
                    return block.text
            return ""

        if response.stop_reason == "tool_use":
            # Execute all tool calls and collect results
            tool_results = []
            for block in response.content:
                if block.type == "tool_use":
                    print(f"  [calling tool: {block.name}]")
                    result = TOOL_HANDLERS[block.name](block.input)
                    tool_results.append({
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": result,
                    })

            messages.append({"role": "user", "content": tool_results})
        else:
            # Unexpected stop reason
            break

    return ""


# ── CLI ───────────────────────────────────────────────────────────────────────

def main():
    # Validate required env vars
    missing = [v for v in ("ANTHROPIC_API_KEY", "EMAIL_ADDRESS", "EMAIL_PASSWORD") if not os.environ.get(v)]
    if missing:
        print(f"Error: Missing environment variables: {', '.join(missing)}")
        print("Copy .env.example to .env and fill in your credentials.")
        return

    client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
    messages = []

    print("=" * 60)
    print("  Email Checking Agent")
    print(f"  Account: {os.environ['EMAIL_ADDRESS']}")
    print("=" * 60)
    print("Type your request (e.g. 'show my unread emails') or 'quit' to exit.\n")

    while True:
        try:
            user_input = input("You: ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nGoodbye!")
            break

        if not user_input:
            continue
        if user_input.lower() in ("quit", "exit", "q"):
            print("Goodbye!")
            break

        try:
            response = run_agent_turn(client, messages, user_input)
            print(f"\nAgent: {response}\n")
        except imaplib.IMAP4.error as e:
            print(f"\nEmail connection error: {e}")
            print("Check your EMAIL_PASSWORD (use an App Password for Gmail).\n")
        except Exception as e:
            print(f"\nError: {e}\n")


if __name__ == "__main__":
    main()
