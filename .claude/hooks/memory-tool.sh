#!/usr/bin/env bash
# Memory Tool — Layer 4 of the agent memory system.
# Just-in-time retrieval: search without loading everything upfront.
#
# Usage:
#   memory-tool.sh search "<query>"   — keyword search across all memory
#   memory-tool.sh recent [N]         — show N most recent entries (default 10)
#   memory-tool.sh list               — list all consolidated archive files
#   memory-tool.sh dump               — print full MEMORY.md (live session notes)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$(dirname "$SCRIPT_DIR")"
MEMORY_FILE="$CLAUDE_DIR/MEMORY.md"
CONSOLIDATED_DIR="$CLAUDE_DIR/agent-memory/consolidated"

cmd="${1:-help}"
shift || true

# ── Helpers ───────────────────────────────────────────────────────────────────
all_memory_files() {
  # Live memory first, then consolidated archives newest-first
  [[ -f "$MEMORY_FILE" ]] && echo "$MEMORY_FILE"
  find "$CONSOLIDATED_DIR" -name '*.md' -type f 2>/dev/null | sort -r
}

print_entry() {
  # Print a full entry block (from ## heading to the next ## heading or EOF)
  local file="$1" heading="$2"
  awk -v h="$heading" '
    $0 == h { found=1 }
    found && /^## / && $0 != h { exit }
    found { print }
  ' "$file"
}

# ── Commands ──────────────────────────────────────────────────────────────────
case "$cmd" in

  search)
    query="${1:-}"
    [[ -z "$query" ]] && { echo "Usage: memory-tool.sh search \"<query>\""; exit 1; }
    found=0
    while IFS= read -r mem_file; do
      matches=$(grep -in "$query" "$mem_file" 2>/dev/null || true)
      [[ -z "$matches" ]] && continue
      echo "── ${mem_file##*/} ──────────────────────────"
      # For each matching line, print its parent entry block (deduplicated)
      declare -A seen_headings=()
      while IFS= read -r match_line; do
        line_no=$(echo "$match_line" | cut -d: -f1)
        heading=$(awk -v ln="$line_no" 'NR<=ln && /^## / {h=$0} END{print h}' "$mem_file")
        if [[ -n "$heading" && -z "${seen_headings[$heading]+set}" ]]; then
          seen_headings["$heading"]=1
          print_entry "$mem_file" "$heading"
          echo ""
        fi
      done <<< "$matches"
      unset seen_headings
      found=1
    done < <(all_memory_files)
    if [[ $found -eq 0 ]]; then echo "(no results for: $query)"; fi
    ;;

  recent)
    n="${1:-10}"
    count=0
    while IFS= read -r mem_file && [[ $count -lt $n ]]; do
      while IFS= read -r line; do
        if [[ "$line" =~ ^## ]]; then
          ((count++)) || true
          [[ $count -gt $n ]] && break
          echo "$line"
        fi
      done < "$mem_file"
    done < <(all_memory_files)
    ;;

  list)
    echo "Live memory:"
    [[ -f "$MEMORY_FILE" ]] && echo "  $MEMORY_FILE" || echo "  (none)"
    echo ""
    echo "Consolidated archives:"
    archives=$(find "$CONSOLIDATED_DIR" -name '*.md' -type f 2>/dev/null | sort -r)
    if [[ -z "$archives" ]]; then
      echo "  (none yet — auto-dream.sh will populate this)"
    else
      while IFS= read -r f; do
        count=$(grep -c '^## \[' "$f" 2>/dev/null || echo 0)
        echo "  $(basename "$f")  ($count entries)"
      done <<< "$archives"
    fi
    ;;

  dump)
    [[ -f "$MEMORY_FILE" ]] && cat "$MEMORY_FILE" || echo "(MEMORY.md not found)"
    ;;

  help|*)
    cat <<'HELP'
Memory Tool — just-in-time agent memory retrieval

  search "<query>"   Keyword search across all memory files
  recent [N]         Show N most recent entry headings (default 10)
  list               List all memory files and entry counts
  dump               Print full live MEMORY.md
HELP
    ;;
esac
