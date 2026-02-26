#!/bin/bash
# claude-code-preset - Installation Script
# FastAPI Backend Infrastructure Configuration for Claude Code


set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Paths
CLAUDE_DIR="$HOME/.claude"
SKILLS_DIR="$CLAUDE_DIR/skills"
AGENTS_DIR="$CLAUDE_DIR/agents"
HOOKS_DIR="$CLAUDE_DIR/scripts"
MANIFEST_FILE="$CLAUDE_DIR/.claude-code-preset-manifest.json"
BACKUP_DIR="$CLAUDE_DIR/backup-$(date +%Y%m%d-%H%M%S)"

# Repository URL
REPO_URL="https://github.com/Nomik94/claude-code-preset.git"

# Determine script directory
if [[ -n "$BASH_SOURCE" ]] && [[ -f "${BASH_SOURCE[0]}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  TEMP_DIR=$(mktemp -d)
  echo -e "${BLUE}Downloading claude-code-preset...${NC}"
  git clone --depth 1 "$REPO_URL" "$TEMP_DIR" 2>/dev/null || {
    echo -e "${RED}Failed to clone repository.${NC}"
    exit 1
  }
  SCRIPT_DIR="$TEMP_DIR"
fi

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║         claude-code-preset Installation          ║${NC}"
echo -e "${CYAN}║   FastAPI Backend Infrastructure Config    ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
if ! command -v git &> /dev/null; then
  echo -e "${RED}git is required but not installed.${NC}"
  exit 1
fi

if ! command -v python3 &> /dev/null; then
  echo -e "${RED}python3 is required but not installed.${NC}"
  exit 1
fi

# Check if already installed
if [[ -f "$MANIFEST_FILE" ]]; then
  PREV_VERSION=$(python3 -c "import json; print(json.load(open('$MANIFEST_FILE')).get('version','unknown'))" 2>/dev/null || echo "unknown")
  echo -e "${YELLOW}claude-code-preset already installed (version: $PREV_VERSION)${NC}"
  echo -e "  ${CYAN}1)${NC} Upgrade      - 기존 설정 백업 후 재설치"
  echo -e "  ${CYAN}2)${NC} Cancel"
  echo ""
  read -p "Choice (1/2): " -n 1 -r
  echo ""
  if [[ $REPLY != "1" ]]; then
    echo -e "${RED}Installation cancelled.${NC}"
    exit 0
  fi
  INSTALL_MODE="1"  # Upgrade = full install
  IS_UPGRADE=true
else
  IS_UPGRADE=false
  # Install mode selection
  echo -e "${YELLOW}Select install mode:${NC}"
  echo ""
  echo -e "  ${CYAN}1)${NC} Full install    - Replace CLAUDE.md + install skills, agents, hooks"
  echo -e "  ${CYAN}2)${NC} Skills only     - Add skills, agents, hooks (keep existing CLAUDE.md)"
  echo -e "  ${CYAN}3)${NC} Cancel"
  echo ""
  read -p "Choice (1/2/3): " -n 1 -r
  echo ""

  if [[ $REPLY == "3" ]]; then
    echo -e "${RED}Installation cancelled.${NC}"
    exit 0
  fi
  INSTALL_MODE=$REPLY
fi

# Backup existing configuration
if [[ -f "$CLAUDE_DIR/CLAUDE.md" ]] || [[ -d "$SKILLS_DIR" ]] || [[ -d "$AGENTS_DIR" ]] || [[ -f "$CLAUDE_DIR/settings.json" ]]; then
  echo -e "${BLUE}Creating backup at: $BACKUP_DIR${NC}"
  mkdir -p "$BACKUP_DIR"
  [[ -f "$CLAUDE_DIR/CLAUDE.md" ]] && cp "$CLAUDE_DIR/CLAUDE.md" "$BACKUP_DIR/"
  [[ -f "$CLAUDE_DIR/settings.json" ]] && cp "$CLAUDE_DIR/settings.json" "$BACKUP_DIR/"
  [[ -f "$MANIFEST_FILE" ]] && cp "$MANIFEST_FILE" "$BACKUP_DIR/"
  [[ -d "$AGENTS_DIR" ]] && cp -r "$AGENTS_DIR" "$BACKUP_DIR/"
  # Backup only skills that will be overwritten
  if [[ -d "$SKILLS_DIR" ]]; then
    mkdir -p "$BACKUP_DIR/skills"
    for skill_dir in "$SCRIPT_DIR/skills/"*/; do
      skill_name=$(basename "$skill_dir")
      if [[ -d "$SKILLS_DIR/$skill_name" ]]; then
        cp -r "$SKILLS_DIR/$skill_name" "$BACKUP_DIR/skills/"
      fi
    done
  fi
  # Backup hooks
  if [[ -d "$HOOKS_DIR" ]]; then
    mkdir -p "$BACKUP_DIR/scripts"
    for hook_file in "$SCRIPT_DIR/hooks/"*.sh; do
      hook_name=$(basename "$hook_file")
      if [[ -f "$HOOKS_DIR/$hook_name" ]]; then
        cp "$HOOKS_DIR/$hook_name" "$BACKUP_DIR/scripts/"
      fi
    done
  fi
  echo -e "${GREEN}✓ Backup created${NC}"
fi

# Create directories
mkdir -p "$SKILLS_DIR"
mkdir -p "$AGENTS_DIR"
mkdir -p "$HOOKS_DIR"

# --- Manifest tracking arrays ---
INSTALLED_SKILLS=()
INSTALLED_AGENTS=()
INSTALLED_HOOKS=()

# Install CLAUDE.md (full mode only)
INSTALLED_CLAUDE_MD=false
if [[ $INSTALL_MODE == "1" ]]; then
  echo -e "${BLUE}Installing CLAUDE.md...${NC}"
  cp "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/"
  INSTALLED_CLAUDE_MD=true
  echo -e "${GREEN}✓ CLAUDE.md installed${NC}"
else
  echo -e "${YELLOW}⏭ Skipping CLAUDE.md (skills-only mode)${NC}"
fi

# Configure settings.json (preserve ALL existing settings)
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
echo -e "${BLUE}Configuring settings.json...${NC}"

if [[ -f "$SETTINGS_FILE" ]]; then
  # Merge: preserve ALL existing settings, add claude-code-preset defaults
  python3 -c "
import json

with open('$SETTINGS_FILE') as f:
    settings = json.load(f)

# Add Skill(*) permission if not present
settings['permissions'] = settings.get('permissions', {})
allow = settings['permissions'].get('allow', [])
if 'Skill(*)' not in allow:
    allow.append('Skill(*)')
settings['permissions']['allow'] = allow

# Set language (only if not already set)
if 'language' not in settings:
    settings['language'] = '한국어'

with open('$SETTINGS_FILE', 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
" 2>/dev/null
  echo -e "${GREEN}✓ settings.json updated (existing settings preserved)${NC}"
else
  python3 -c "
import json

settings = {
    'permissions': {
        'allow': ['Skill(*)'],
        'defaultMode': 'default'
    },
    'language': '한국어'
}

with open('$SETTINGS_FILE', 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
" 2>/dev/null
  echo -e "${GREEN}✓ settings.json created${NC}"
fi

# Install skills
echo -e "${BLUE}Installing skills...${NC}"
skill_count=0
if [[ -d "$SCRIPT_DIR/skills" ]]; then
  for skill_dir in "$SCRIPT_DIR/skills/"*/; do
    if [[ -d "$skill_dir" ]]; then
      skill_name=$(basename "$skill_dir")
      cp -r "${skill_dir%/}" "$SKILLS_DIR/"
      INSTALLED_SKILLS+=("$skill_name")
      echo -e "  ✓ $skill_name"
      ((skill_count++))
    fi
  done
  echo -e "${GREEN}✓ $skill_count skills installed${NC}"
fi

# Install hooks (*.sh and *.py)
echo -e "${BLUE}Installing hooks...${NC}"
hook_count=0
if [[ -d "$SCRIPT_DIR/hooks" ]]; then
  for hook_file in "$SCRIPT_DIR/hooks/"*.sh "$SCRIPT_DIR/hooks/"*.py; do
    if [[ -f "$hook_file" ]]; then
      cp "$hook_file" "$HOOKS_DIR/"
      chmod +x "$HOOKS_DIR/$(basename "$hook_file")"
      hook_name=$(basename "$hook_file")
      INSTALLED_HOOKS+=("$hook_name")
      echo -e "  ✓ ${hook_name%.*}"
      ((hook_count++))
    fi
  done
  echo -e "${GREEN}✓ $hook_count hooks installed${NC}"

  # Register hooks in settings.json (preserve existing hooks)
  python3 -c "
import json

SETTINGS_FILE = '$SETTINGS_FILE'
HOOKS_DIR = '$HOOKS_DIR'

with open(SETTINGS_FILE) as f:
    settings = json.load(f)

hooks = settings.get('hooks', {})

# Define claude-code-preset hooks
infra_hook_entries = [
    {'type': 'command', 'command': f'CLAUDE_FILE_PATH=\"\$CLAUDE_FILE_PATH\" {HOOKS_DIR}/python-lint-check.sh', 'timeout': 10000},
    {'type': 'command', 'command': f'CLAUDE_FILE_PATH=\"\$CLAUDE_FILE_PATH\" {HOOKS_DIR}/python-type-check.sh', 'timeout': 10000},
    {'type': 'command', 'command': f'CLAUDE_FILE_PATH=\"\$CLAUDE_FILE_PATH\" {HOOKS_DIR}/python-debug-check.sh', 'timeout': 5000},
]

# Merge: add claude-code-preset hooks without removing existing ones
existing = hooks.get('PostToolUse', [])
existing_commands = set()
for entry in existing:
    for h in entry.get('hooks', []):
        existing_commands.add(h.get('command', ''))

new_hooks = [h for h in infra_hook_entries if h['command'] not in existing_commands]
if new_hooks:
    # Find existing entry with Edit|Write matcher or create new
    found = False
    for entry in existing:
        if entry.get('matcher') == 'Edit|Write':
            entry['hooks'].extend(new_hooks)
            found = True
            break
    if not found:
        existing.append({'matcher': 'Edit|Write', 'hooks': new_hooks})
    hooks['PostToolUse'] = existing

# PreToolUse hook - suggest /compact at strategic points
pre_tool = hooks.get('PreToolUse', [])
suggest_cmd = f'bash {HOOKS_DIR}/suggest-compact.sh'
pt_commands = set()
for entry in pre_tool:
    for h in entry.get('hooks', []):
        pt_commands.add(h.get('command', ''))
if suggest_cmd not in pt_commands:
    pre_tool.append({
        'matcher': '.*',
        'hooks': [{'type': 'command', 'command': suggest_cmd, 'timeout': 3000}]
    })
    hooks['PreToolUse'] = pre_tool

# UserPromptSubmit hook - intercept /compact and remind to save notes
user_prompt = hooks.get('UserPromptSubmit', [])
note_cmd = f'bash {HOOKS_DIR}/pre-compact-note.sh'
up_commands = set()
for entry in user_prompt:
    for h in entry.get('hooks', []):
        up_commands.add(h.get('command', ''))
if note_cmd not in up_commands:
    user_prompt.append({
        'hooks': [{'type': 'command', 'command': note_cmd, 'timeout': 3000}]
    })
    hooks['UserPromptSubmit'] = user_prompt

# PreCompact hook - save state before compaction
pre_compact = hooks.get('PreCompact', [])
pre_compact_cmd = f'{HOOKS_DIR}/pre-compact-save.sh'
pc_commands = set()
for entry in pre_compact:
    for h in entry.get('hooks', []):
        pc_commands.add(h.get('command', ''))
if pre_compact_cmd not in pc_commands:
    pre_compact.append({
        'matcher': 'auto|manual',
        'hooks': [{'type': 'command', 'command': f'bash {pre_compact_cmd}', 'timeout': 5000}]
    })
    hooks['PreCompact'] = pre_compact

# SessionStart hook - remind about learned lessons
session_start_hooks = hooks.get('SessionStart', [])
lessons_cmd = f'bash {HOOKS_DIR}/session-lessons.sh'
ss_commands = set()
for entry in session_start_hooks:
    for h in entry.get('hooks', []):
        ss_commands.add(h.get('command', ''))
if lessons_cmd not in ss_commands:
    session_start_hooks.append({
        'matcher': 'startup',
        'hooks': [{'type': 'command', 'command': lessons_cmd, 'timeout': 3000}]
    })
    hooks['SessionStart'] = session_start_hooks

# SessionEnd hook - generate session summary when session terminates
session_end_hooks = hooks.get('SessionEnd', [])
stop_cmd = f'python3 {HOOKS_DIR}/session-summary.py'
se_commands = set()
for entry in session_end_hooks:
    for h in entry.get('hooks', []):
        se_commands.add(h.get('command', ''))
if stop_cmd not in se_commands:
    session_end_hooks.append({
        'hooks': [{'type': 'command', 'command': stop_cmd, 'timeout': 5000}]
    })
    hooks['SessionEnd'] = session_end_hooks

settings['hooks'] = hooks

with open(SETTINGS_FILE, 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
" 2>/dev/null
  echo -e "${GREEN}✓ hooks registered in settings.json${NC}"
fi

# Install agents
echo -e "${BLUE}Installing agents...${NC}"
agent_count=0
if [[ -d "$SCRIPT_DIR/agents" ]]; then
  for agent_file in "$SCRIPT_DIR/agents/"*.md; do
    if [[ -f "$agent_file" ]]; then
      cp "$agent_file" "$AGENTS_DIR/"
      agent_name=$(basename "$agent_file" .md)
      INSTALLED_AGENTS+=("$agent_name")
      echo -e "  ✓ $agent_name"
      ((agent_count++))
    fi
  done
  echo -e "${GREEN}✓ $agent_count agents installed${NC}"
fi

# Install notepad template (if not already exists)
echo -e "${BLUE}Setting up notepad...${NC}"
if [[ -f "$SCRIPT_DIR/templates/notepad.md" ]]; then
  if [[ ! -f "$CLAUDE_DIR/notepad.md" ]]; then
    cp "$SCRIPT_DIR/templates/notepad.md" "$CLAUDE_DIR/notepad.md"
    echo -e "${GREEN}✓ notepad.md created${NC}"
  else
    echo -e "${YELLOW}⏭ notepad.md already exists (preserved)${NC}"
  fi
fi

# Create state directory for snapshots
mkdir -p "$CLAUDE_DIR/state/snapshots"

# Copy uninstall.sh to ~/.claude/
echo -e "${BLUE}Installing uninstall script...${NC}"
if [[ -f "$SCRIPT_DIR/uninstall.sh" ]]; then
  cp "$SCRIPT_DIR/uninstall.sh" "$CLAUDE_DIR/uninstall-claude-code-preset.sh"
  chmod +x "$CLAUDE_DIR/uninstall-claude-code-preset.sh"
  echo -e "${GREEN}✓ uninstall script installed${NC}"
fi

# Write manifest (used by uninstall.sh for precise removal)
echo -e "${BLUE}Writing manifest...${NC}"
python3 -c "
import json
from datetime import datetime

manifest = {
    'version': '1.0.0',
    'installed_at': datetime.now().isoformat(),
    'install_mode': 'full' if '$INSTALL_MODE' == '1' else 'skills-only',
    'backup_dir': '$BACKUP_DIR',
    'claude_md': $( [[ "$INSTALLED_CLAUDE_MD" == "true" ]] && echo 'True' || echo 'False' ),
    'skills': $(python3 -c "import json; print(json.dumps([$(printf '"%s",' "${INSTALLED_SKILLS[@]}" | sed 's/,$//')]))" 2>/dev/null),
    'agents': $(python3 -c "import json; print(json.dumps([$(printf '"%s",' "${INSTALLED_AGENTS[@]}" | sed 's/,$//')]))" 2>/dev/null),
    'hooks': $(python3 -c "import json; print(json.dumps([$(printf '"%s",' "${INSTALLED_HOOKS[@]}" | sed 's/,$//')]))" 2>/dev/null),
}

with open('$MANIFEST_FILE', 'w') as f:
    json.dump(manifest, f, indent=2, ensure_ascii=False)
" 2>/dev/null
echo -e "${GREEN}✓ Manifest written${NC}"

# Cleanup temp directory
if [[ -n "${TEMP_DIR:-}" ]] && [[ -d "${TEMP_DIR:-}" ]]; then
  rm -rf "$TEMP_DIR"
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       Installation Complete!               ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Installed:"
if [[ $INSTALL_MODE == "1" ]]; then
  echo -e "  📄 CLAUDE.md (core configuration)"
fi
echo -e "  ⚙️  settings.json (existing settings preserved)"
echo -e "  🛠️  $skill_count skills"
echo -e "  🤖 $agent_count agents"
echo -e "  🪝 $hook_count hooks (ruff auto-fix, mypy, debug check)"
echo ""
if [[ -d "$BACKUP_DIR" ]]; then
  echo -e "  📦 Backup: $BACKUP_DIR"
  echo ""
fi
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. ${CYAN}Restart Claude Code${NC} to apply changes"
echo -e "  2. Try ${CYAN}/fastapi${NC} to load FastAPI project patterns"
echo -e "  3. Try ${CYAN}/domain-layer${NC} for DDD entity patterns"
echo -e "  4. Use ${CYAN}--think${NC} for complex analysis"
echo ""
echo -e "${YELLOW}Uninstall:${NC}"
echo -e "  ${CYAN}~/.claude/uninstall-claude-code-preset.sh${NC}"
echo ""
echo -e "${BLUE}Stack: Python 3.12+ / FastAPI / SQLAlchemy 2.0 / Poetry${NC}"
echo ""
