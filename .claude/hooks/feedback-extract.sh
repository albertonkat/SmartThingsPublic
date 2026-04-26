#!/usr/bin/env bash
# feedback-extract.sh — Session-end feedback extractor.
#
# Prints the extraction prompt for Claude to answer, then appends
# the formatted output to .claude/FEEDBACK.md.
#
# Usage (two modes):
#
#   Mode 1 — print the prompt (user pastes into Claude):
#     .claude/hooks/feedback-extract.sh prompt
#
#   Mode 2 — append Claude's answer to FEEDBACK.md:
#     .claude/hooks/feedback-extract.sh append "<claude output>"
#
#   Mode 3 — interactive (prints prompt, waits for paste, then appends):
#     .claude/hooks/feedback-extract.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$(dirname "$SCRIPT_DIR")"
FEEDBACK_FILE="$CLAUDE_DIR/FEEDBACK.md"
TODAY=$(date +%Y-%m-%d)

EXTRACTION_PROMPT='Read our whole conversation. Extract:
1. Every correction I made to your output (tone, format, approach, wording)
2. Every preference I stated (explicit or implied)
3. Anything you would do differently next time based on my feedback
4. Any project-specific patterns or constraints I enforced

Format the output as a markdown block starting with:
## ['"$TODAY"'] Session feedback
Then bullet points under these headings: Corrections | Preferences | Do differently | Project patterns

Be specific. Skip generic observations. Only include things that would actually change your behavior in a future session.'

cmd="${1:-interactive}"

case "$cmd" in

  prompt)
    echo "$EXTRACTION_PROMPT"
    ;;

  append)
    feedback_text="${2:-}"
    if [[ -z "$feedback_text" ]]; then
      echo "Usage: feedback-extract.sh append \"<claude output>\"" >&2
      exit 1
    fi
    # Insert after the <!-- Entries --> marker (or append at end)
    if grep -q "<!-- Entries" "$FEEDBACK_FILE" 2>/dev/null; then
      # Append after the marker line
      marker_line=$(grep -n "<!-- Entries" "$FEEDBACK_FILE" | head -1 | cut -d: -f1)
      head_part=$(head -n "$marker_line" "$FEEDBACK_FILE")
      tail_part=$(tail -n +"$((marker_line + 1))" "$FEEDBACK_FILE")
      printf '%s\n\n%s\n%s\n' \
        "$head_part" \
        "$feedback_text" \
        "$tail_part" > "$FEEDBACK_FILE"
    else
      printf '\n%s\n' "$feedback_text" >> "$FEEDBACK_FILE"
    fi
    echo "[feedback-extract] Appended to $FEEDBACK_FILE" >&2
    ;;

  interactive)
    echo ""
    echo "════════════════════════════════════════════════════════"
    echo "  SESSION FEEDBACK EXTRACTOR"
    echo "  Copy the prompt below and send it to Claude."
    echo "  Then paste Claude's response back here."
    echo "════════════════════════════════════════════════════════"
    echo ""
    echo "$EXTRACTION_PROMPT"
    echo ""
    echo "════════════════════════════════════════════════════════"
    echo "Paste Claude's feedback output below (Ctrl+D when done):"
    echo "════════════════════════════════════════════════════════"
    feedback_text=$(cat)
    if [[ -n "$feedback_text" ]]; then
      bash "$0" append "$feedback_text"
      echo "[feedback-extract] Saved. Future sessions will load this automatically."
    else
      echo "[feedback-extract] No input received — nothing saved."
    fi
    ;;

  *)
    echo "Usage: feedback-extract.sh [prompt|append \"<text>\"|interactive]" >&2
    exit 1
    ;;
esac
