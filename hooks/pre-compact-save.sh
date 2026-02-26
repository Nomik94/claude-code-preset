#!/bin/bash
# Pre-Compact Auto-Save Hook
# Saves state snapshot before Claude Code compresses conversation
# Triggered by PreCompact event (auto or manual)

set -e

STATE_DIR="${HOME}/.claude/state"
SNAPSHOT_DIR="${STATE_DIR}/snapshots"
MAX_SNAPSHOTS=10

mkdir -p "$SNAPSHOT_DIR"

# Read stdin (JSON input from Claude Code)
INPUT=$(cat)

TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Extract session info
SESSION_ID="default"
if command -v jq &> /dev/null; then
  SESSION_ID=$(echo "$INPUT" | jq -r '.sessionId // .session_id // "default"' 2>/dev/null)
  [[ "$SESSION_ID" == "null" ]] && SESSION_ID="default"
fi

SNAPSHOT_FILE="${SNAPSHOT_DIR}/snapshot-${TIMESTAMP}.json"

# Check notepad locations
NOTEPAD_PROJECT="${PWD}/.claude/notepad.md"
NOTEPAD_GLOBAL="${HOME}/.claude/notepad.md"

cat > "$SNAPSHOT_FILE" << EOF
{
  "timestamp": "$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')",
  "session_id": "$SESSION_ID",
  "working_directory": "$PWD",
  "notepad": {
    "project": $(if [[ -f "$NOTEPAD_PROJECT" ]]; then echo "true"; else echo "false"; fi),
    "global": $(if [[ -f "$NOTEPAD_GLOBAL" ]]; then echo "true"; else echo "false"; fi)
  }
}
EOF

# Cleanup old snapshots
SNAPSHOT_COUNT=$(ls -1 "$SNAPSHOT_DIR"/snapshot-*.json 2>/dev/null | wc -l | tr -d ' ')
if [[ "$SNAPSHOT_COUNT" -gt "$MAX_SNAPSHOTS" ]]; then
  ls -1t "$SNAPSHOT_DIR"/snapshot-*.json | tail -n +$((MAX_SNAPSHOTS + 1)) | xargs rm -f 2>/dev/null
fi

echo "" >&2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
echo "💾 [PreCompact] State snapshot saved" >&2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2

cat << EOF
{
  "continue": true,
  "message": "[PRE-COMPACT] Before compaction, save critical context:\n\n1. /note --priority <핵심 정보> (항상 로드)\n2. /note <작업 메모> (Working Memory)\n\nState snapshot: $SNAPSHOT_FILE"
}
EOF

exit 0
