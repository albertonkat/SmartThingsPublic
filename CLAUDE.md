# SmartThings Public — Claude Agent Rules

## Project Overview
This repo contains official SmartThings SmartApps and Device Types written in Groovy
(SmartThings DSL). Apps live in `smartapps/`, device handlers in `devicetypes/`, each
organized by author namespace.

## Tech Stack
- Language: Groovy (SmartThings sandbox DSL)
- Build: Gradle (`build.gradle`, `gradlew`)
- CI: CircleCI (`circle.yml`)

## Coding Rules
- Follow existing namespace conventions: `smartapps/<namespace>/<app-name>.src/`
- Device handlers go in `devicetypes/<namespace>/<device-name>.src/`
- Keep SmartApp metadata blocks (`definition`, `preferences`, `tiles`) at the top
- Do not introduce external dependencies — the SmartThings sandbox is closed
- Prefer descriptive method names over inline comments

## Memory System (4 Layers)

This project uses a 4-layer agent memory system so agents never start from zero.

### Layer 1 — CLAUDE.md (this file)
Your stable rules. Update only when project conventions change permanently.

### Layer 2 — Auto Memory (`.claude/MEMORY.md`)
Claude's live session notes. After discovering something useful (a pattern, a gotcha,
a key file location), write it here using the append format:

```
## [YYYY-MM-DD] <short title>
<finding>
```

Mark stale or superseded entries by prefixing the heading with `[STALE]`.

### Layer 3 — Auto Dream (`.claude/hooks/auto-dream.sh`)
Runs automatically at session end (Stop hook). Moves `[STALE]` entries and entries
older than 30 days from `MEMORY.md` into `.claude/agent-memory/consolidated/`.
Keeps `MEMORY.md` lean. No action needed from you.

### Layer 4 — Memory Tool (`.claude/hooks/memory-tool.sh`)
For just-in-time retrieval. Call it when you need context without loading everything:

```bash
.claude/hooks/memory-tool.sh search "<query>"
.claude/hooks/memory-tool.sh recent 10
.claude/hooks/memory-tool.sh list
```

### Session Feedback (`.claude/FEEDBACK.md`)

**At session start:** Read `.claude/FEEDBACK.md` in full. Apply every correction,
preference, and "do differently" listed there — these are lessons extracted from real
past sessions and must carry forward.

**At session end (when asked):** Run the extraction prompt below, then append the
formatted output to `.claude/FEEDBACK.md` using the append script:

```bash
# Get the extraction prompt
.claude/hooks/feedback-extract.sh prompt

# After Claude answers, append the feedback
.claude/hooks/feedback-extract.sh append "<claude output>"

# Or run interactively (prints prompt, waits for paste)
.claude/hooks/feedback-extract.sh
```

The extraction prompt instructs Claude to pull every correction, preference, and lesson
from the conversation and format it as a structured block. `FEEDBACK.md` is committed
and shared — the compounding is the point.

## Team Sharing
Commit `.claude/agent-memory/` and `.claude/FEEDBACK.md` to share consolidated
knowledge across developers. `MEMORY.md` is intentionally gitignored (per-session
scratch) — only consolidated memories and feedback are shared.
