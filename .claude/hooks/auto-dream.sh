#!/usr/bin/env bash
# Auto Dream — Layer 3 of the agent memory system.
# Runs at session end (Stop hook). Sweeps MEMORY.md:
#   - Moves [STALE] entries to consolidated archive
#   - Archives entries older than STALE_DAYS
#   - Updates agent-memory/index.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$(dirname "$SCRIPT_DIR")"
MEMORY_FILE="$CLAUDE_DIR/MEMORY.md"
CONSOLIDATED_DIR="$CLAUDE_DIR/agent-memory/consolidated"
INDEX_FILE="$CLAUDE_DIR/agent-memory/index.md"
STALE_DAYS=30
TODAY=$(date +%Y-%m-%d)
ARCHIVE_FILE="$CONSOLIDATED_DIR/$TODAY.md"

[[ -f "$MEMORY_FILE" ]] || exit 0

# ── Collect entries to archive ────────────────────────────────────────────────
declare -a stale_entries=()
declare -a fresh_lines=()
in_stale=0
current_entry=()
cutoff_epoch=$(date -d "$STALE_DAYS days ago" +%s 2>/dev/null || \
               date -v-"${STALE_DAYS}"d +%s 2>/dev/null || echo 0)

flush_entry() {
  if [[ ${#current_entry[@]} -gt 0 ]]; then
    if [[ $in_stale -eq 1 ]]; then
      stale_entries+=("${current_entry[@]}")
    else
      fresh_lines+=("${current_entry[@]}")
    fi
    current_entry=()
  fi
}

while IFS= read -r line; do
  if [[ "$line" =~ ^##\ \[([0-9]{4}-[0-9]{2}-[0-9]{2})\] ]]; then
    flush_entry
    entry_date="${BASH_REMATCH[1]}"
    entry_epoch=$(date -d "$entry_date" +%s 2>/dev/null || \
                  date -j -f "%Y-%m-%d" "$entry_date" +%s 2>/dev/null || echo 9999999999)
    if [[ "$line" =~ ^\#\#\ \[STALE\] ]] || \
       [[ $cutoff_epoch -gt 0 && $entry_epoch -lt $cutoff_epoch ]]; then
      in_stale=1
    else
      in_stale=0
    fi
    current_entry=("$line")
  elif [[ ${#current_entry[@]} -gt 0 ]]; then
    current_entry+=("$line")
  else
    fresh_lines+=("$line")
  fi
done < "$MEMORY_FILE"
flush_entry

# ── Nothing to archive? ───────────────────────────────────────────────────────
if [[ ${#stale_entries[@]} -eq 0 ]]; then
  echo "[auto-dream] MEMORY.md is fresh — nothing to consolidate." >&2
  exit 0
fi

# ── Write archive file ────────────────────────────────────────────────────────
mkdir -p "$CONSOLIDATED_DIR"
{
  echo "# Consolidated Memory — $TODAY"
  echo ""
  printf '%s\n' "${stale_entries[@]}"
} >> "$ARCHIVE_FILE"

echo "[auto-dream] Archived ${#stale_entries[@]} lines → $ARCHIVE_FILE" >&2

# ── Rewrite MEMORY.md without the stale entries ───────────────────────────────
printf '%s\n' "${fresh_lines[@]}" > "$MEMORY_FILE"

# ── Update index.md ───────────────────────────────────────────────────────────
archive_name="$(basename "$ARCHIVE_FILE")"
if ! grep -qF "$archive_name" "$INDEX_FILE" 2>/dev/null; then
  topics=$(grep '^## \[' "$ARCHIVE_FILE" | sed 's/^## \[[^]]*\] //' | paste -sd ', ' -)
  # Insert new row before the "(none yet)" placeholder or append to table
  if grep -q "none yet" "$INDEX_FILE"; then
    sed -i "s|.*none yet.*|| " "$INDEX_FILE"
  fi
  # Append to the table section
  sed -i "/^| File /,/^$/{/^$/{i\\| $archive_name | $TODAY | $topics |
}}" "$INDEX_FILE" 2>/dev/null || true
fi

echo "[auto-dream] Done." >&2
