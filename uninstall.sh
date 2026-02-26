#!/bin/bash
# claude-code-preset - Uninstall Script
# Reads manifest from install.sh for precise removal

set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
MANIFEST_FILE="$CLAUDE_DIR/.claude-code-preset-manifest.json"
BACKUP_DIR="$CLAUDE_DIR/backup-uninstall-$(date +%Y%m%d-%H%M%S)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       claude-code-preset Uninstaller             ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""

# Check if manifest exists
if [[ ! -f "$MANIFEST_FILE" ]]; then
  echo -e "${YELLOW}No manifest found. Using fallback list.${NC}"
  USE_MANIFEST=false
else
  USE_MANIFEST=true
  INSTALL_DATE=$(python3 -c "import json; print(json.load(open('$MANIFEST_FILE')).get('installed_at','unknown'))" 2>/dev/null || echo "unknown")
  VERSION=$(python3 -c "import json; print(json.load(open('$MANIFEST_FILE')).get('version','unknown'))" 2>/dev/null || echo "unknown")
  echo -e "  Version:   ${CYAN}$VERSION${NC}"
  echo -e "  Installed: ${CYAN}$INSTALL_DATE${NC}"
  echo ""
fi

read -p "Remove claude-code-preset from $CLAUDE_DIR? [y/N] " -r
if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
  echo -e "${RED}Cancelled.${NC}"
  exit 0
fi

echo ""
mkdir -p "$BACKUP_DIR"

if [[ "$USE_MANIFEST" == "true" ]]; then
  # --- Manifest-based removal (precise) ---

  # Read manifest
  SKILLS=$(python3 -c "import json; [print(s) for s in json.load(open('$MANIFEST_FILE')).get('skills',[])]" 2>/dev/null)
  AGENTS=$(python3 -c "import json; [print(a) for a in json.load(open('$MANIFEST_FILE')).get('agents',[])]" 2>/dev/null)
  HOOKS=$(python3 -c "import json; [print(h) for h in json.load(open('$MANIFEST_FILE')).get('hooks',[])]" 2>/dev/null)
  HAS_CLAUDE_MD=$(python3 -c "import json; print(json.load(open('$MANIFEST_FILE')).get('claude_md', False))" 2>/dev/null)
  INSTALL_BACKUP=$(python3 -c "import json; print(json.load(open('$MANIFEST_FILE')).get('backup_dir',''))" 2>/dev/null)

  # Remove CLAUDE.md
  if [[ "$HAS_CLAUDE_MD" == "True" ]] && [[ -f "$CLAUDE_DIR/CLAUDE.md" ]]; then
    cp "$CLAUDE_DIR/CLAUDE.md" "$BACKUP_DIR/"
    rm "$CLAUDE_DIR/CLAUDE.md"
    echo -e "${GREEN}✓ Removed CLAUDE.md${NC}"
  fi

  # Remove skills (from manifest)
  skill_count=0
  if [[ -n "$SKILLS" ]]; then
    mkdir -p "$BACKUP_DIR/skills"
    while IFS= read -r skill; do
      if [[ -d "$CLAUDE_DIR/skills/$skill" ]]; then
        cp -r "$CLAUDE_DIR/skills/$skill" "$BACKUP_DIR/skills/"
        rm -rf "$CLAUDE_DIR/skills/$skill"
        ((skill_count++))
      fi
    done <<< "$SKILLS"
  fi
  echo -e "${GREEN}✓ Removed $skill_count skills${NC}"

  # Remove agents (from manifest)
  agent_count=0
  if [[ -n "$AGENTS" ]]; then
    mkdir -p "$BACKUP_DIR/agents"
    while IFS= read -r agent; do
      if [[ -f "$CLAUDE_DIR/agents/$agent.md" ]]; then
        cp "$CLAUDE_DIR/agents/$agent.md" "$BACKUP_DIR/agents/"
        rm "$CLAUDE_DIR/agents/$agent.md"
        ((agent_count++))
      fi
    done <<< "$AGENTS"
  fi
  echo -e "${GREEN}✓ Removed $agent_count agents${NC}"

  # Remove hooks (from manifest)
  hook_count=0
  if [[ -n "$HOOKS" ]]; then
    mkdir -p "$BACKUP_DIR/scripts"
    while IFS= read -r hook; do
      if [[ -f "$CLAUDE_DIR/scripts/$hook" ]]; then
        cp "$CLAUDE_DIR/scripts/$hook" "$BACKUP_DIR/scripts/"
        rm "$CLAUDE_DIR/scripts/$hook"
        ((hook_count++))
      fi
    done <<< "$HOOKS"
  fi
  echo -e "${GREEN}✓ Removed $hook_count hooks${NC}"

  # Clean hook registrations from settings.json
  if [[ -f "$CLAUDE_DIR/settings.json" ]]; then
    python3 -c "
import json

with open('$CLAUDE_DIR/settings.json') as f:
    settings = json.load(f)

hooks = settings.get('hooks', {})

# Clean PostToolUse
post_tool = hooks.get('PostToolUse', [])
for entry in post_tool:
    entry['hooks'] = [
        h for h in entry.get('hooks', [])
        if 'python-lint-check.sh' not in h.get('command', '')
        and 'python-type-check.sh' not in h.get('command', '')
        and 'python-debug-check.sh' not in h.get('command', '')
    ]
post_tool = [e for e in post_tool if e.get('hooks')]
if post_tool:
    hooks['PostToolUse'] = post_tool
elif 'PostToolUse' in hooks:
    del hooks['PostToolUse']

# Clean PreToolUse (suggest-compact)
pre_tool = hooks.get('PreToolUse', [])
for entry in pre_tool:
    entry['hooks'] = [
        h for h in entry.get('hooks', [])
        if 'suggest-compact.sh' not in h.get('command', '')
    ]
pre_tool = [e for e in pre_tool if e.get('hooks')]
if pre_tool:
    hooks['PreToolUse'] = pre_tool
elif 'PreToolUse' in hooks:
    del hooks['PreToolUse']

# Clean UserPromptSubmit (pre-compact-note)
user_prompt = hooks.get('UserPromptSubmit', [])
for entry in user_prompt:
    entry['hooks'] = [
        h for h in entry.get('hooks', [])
        if 'pre-compact-note.sh' not in h.get('command', '')
    ]
user_prompt = [e for e in user_prompt if e.get('hooks')]
if user_prompt:
    hooks['UserPromptSubmit'] = user_prompt
elif 'UserPromptSubmit' in hooks:
    del hooks['UserPromptSubmit']

# Clean PreCompact
pre_compact = hooks.get('PreCompact', [])
for entry in pre_compact:
    entry['hooks'] = [
        h for h in entry.get('hooks', [])
        if 'pre-compact-save.sh' not in h.get('command', '')
    ]
pre_compact = [e for e in pre_compact if e.get('hooks')]
if pre_compact:
    hooks['PreCompact'] = pre_compact
elif 'PreCompact' in hooks:
    del hooks['PreCompact']

# Clean SessionStart (session-lessons)
session_start = hooks.get('SessionStart', [])
for entry in session_start:
    entry['hooks'] = [
        h for h in entry.get('hooks', [])
        if 'session-lessons.sh' not in h.get('command', '')
    ]
session_start = [e for e in session_start if e.get('hooks')]
if session_start:
    hooks['SessionStart'] = session_start
elif 'SessionStart' in hooks:
    del hooks['SessionStart']

# Clean SessionEnd (and legacy Stop)
for event_name in ['SessionEnd', 'Stop']:
    event_hooks = hooks.get(event_name, [])
    for entry in event_hooks:
        entry['hooks'] = [
            h for h in entry.get('hooks', [])
            if 'session-summary.py' not in h.get('command', '')
        ]
    event_hooks = [e for e in event_hooks if e.get('hooks')]
    if event_hooks:
        hooks[event_name] = event_hooks
    elif event_name in hooks:
        del hooks[event_name]

# Remove Skill(*) from permissions
perms = settings.get('permissions', {})
allow = perms.get('allow', [])
if 'Skill(*)' in allow:
    allow.remove('Skill(*)')
perms['allow'] = allow

settings['hooks'] = hooks
settings['permissions'] = perms

with open('$CLAUDE_DIR/settings.json', 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
" 2>/dev/null
    echo -e "${GREEN}✓ Cleaned settings.json (hooks & permissions)${NC}"
  fi

  # Remove manifest and uninstall script
  cp "$MANIFEST_FILE" "$BACKUP_DIR/"
  rm "$MANIFEST_FILE"
  [[ -f "$CLAUDE_DIR/uninstall-claude-code-preset.sh" ]] && rm "$CLAUDE_DIR/uninstall-claude-code-preset.sh"

else
  # --- Fallback: hardcoded list (no manifest found) ---

  SKILLS=(fastapi domain-layer api-versioning middleware environment sqlalchemy alembic pydantic-schema testing error-handling debugging production-checklist security-audit monitoring docker cicd background-tasks websocket confidence-check verify build-fix feature-planner gap-analysis learn checkpoint audit note engineer code-review root-cause devops docs)
  AGENTS=(engineer code-reviewer root-cause-analyst devops-architect technical-writer)
  HOOKS=(python-lint-check.sh python-type-check.sh python-debug-check.sh pre-compact-save.sh session-summary.py suggest-compact.sh pre-compact-note.sh)

  # Remove CLAUDE.md
  if [[ -f "$CLAUDE_DIR/CLAUDE.md" ]]; then
    cp "$CLAUDE_DIR/CLAUDE.md" "$BACKUP_DIR/"
    rm "$CLAUDE_DIR/CLAUDE.md"
    echo -e "${GREEN}✓ Removed CLAUDE.md${NC}"
  fi

  # Remove skills
  for skill in "${SKILLS[@]}"; do
    if [[ -d "$CLAUDE_DIR/skills/$skill" ]]; then
      mkdir -p "$BACKUP_DIR/skills"
      cp -r "$CLAUDE_DIR/skills/$skill" "$BACKUP_DIR/skills/"
      rm -rf "$CLAUDE_DIR/skills/$skill"
    fi
  done
  echo -e "${GREEN}✓ Removed ${#SKILLS[@]} skills${NC}"

  # Remove agents
  for agent in "${AGENTS[@]}"; do
    if [[ -f "$CLAUDE_DIR/agents/$agent.md" ]]; then
      mkdir -p "$BACKUP_DIR/agents"
      cp "$CLAUDE_DIR/agents/$agent.md" "$BACKUP_DIR/agents/"
      rm "$CLAUDE_DIR/agents/$agent.md"
    fi
  done
  echo -e "${GREEN}✓ Removed ${#AGENTS[@]} agents${NC}"

  # Remove hooks
  for hook in "${HOOKS[@]}"; do
    if [[ -f "$CLAUDE_DIR/scripts/$hook" ]]; then
      mkdir -p "$BACKUP_DIR/scripts"
      cp "$CLAUDE_DIR/scripts/$hook" "$BACKUP_DIR/scripts/"
      rm "$CLAUDE_DIR/scripts/$hook"
    fi
  done
  echo -e "${GREEN}✓ Removed ${#HOOKS[@]} hooks${NC}"

  [[ -f "$CLAUDE_DIR/uninstall-claude-code-preset.sh" ]] && rm "$CLAUDE_DIR/uninstall-claude-code-preset.sh"
fi

echo ""
echo -e "${GREEN}Uninstall complete.${NC}"
echo -e "  📦 Backup: $BACKUP_DIR"
echo ""

# Offer to restore previous backup (from install time)
INSTALL_BACKUP_DIR="${INSTALL_BACKUP:-}"
if [[ -z "$INSTALL_BACKUP_DIR" ]]; then
  INSTALL_BACKUP_DIR=$(ls -td "$CLAUDE_DIR"/backup-2* 2>/dev/null | grep -v uninstall | head -1 || true)
fi

if [[ -n "$INSTALL_BACKUP_DIR" ]] && [[ -d "$INSTALL_BACKUP_DIR" ]]; then
  echo -e "  Previous config found: ${CYAN}$INSTALL_BACKUP_DIR${NC}"
  read -p "  Restore previous configuration? [y/N] " -r
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    [[ -f "$INSTALL_BACKUP_DIR/CLAUDE.md" ]] && cp "$INSTALL_BACKUP_DIR/CLAUDE.md" "$CLAUDE_DIR/"
    [[ -f "$INSTALL_BACKUP_DIR/settings.json" ]] && cp "$INSTALL_BACKUP_DIR/settings.json" "$CLAUDE_DIR/"
    [[ -d "$INSTALL_BACKUP_DIR/skills" ]] && cp -r "$INSTALL_BACKUP_DIR/skills/"* "$CLAUDE_DIR/skills/" 2>/dev/null || true
    [[ -d "$INSTALL_BACKUP_DIR/agents" ]] && cp -r "$INSTALL_BACKUP_DIR/agents/"* "$CLAUDE_DIR/agents/" 2>/dev/null || true
    [[ -d "$INSTALL_BACKUP_DIR/scripts" ]] && cp -r "$INSTALL_BACKUP_DIR/scripts/"* "$CLAUDE_DIR/scripts/" 2>/dev/null || true
    echo -e "  ${GREEN}✓ Previous configuration restored${NC}"
  fi
fi

echo ""
echo -e "  Restart Claude Code to apply changes."
echo ""
