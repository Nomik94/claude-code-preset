#!/bin/bash
# claude-code-preset - MCP Servers & Plugin Setup Script
#
# 현재 사용 중인 MCP 서버와 플러그인을 한번에 설치합니다.
# install.sh와 독립적으로 실행 가능합니다.
#
# Usage:
#   ./mcp-setup.sh           # 대화형 모드 (개별 선택)
#   ./mcp-setup.sh --all     # MCP 전체 + Plugin 설치
#   ./mcp-setup.sh --core    # Core MCP만 (context7 + sequential-thinking)
#   ./mcp-setup.sh --mcp     # MCP 서버만 (Plugin 제외)
#   ./mcp-setup.sh --plugin  # Plugin만 (superpowers)
#   ./mcp-setup.sh --list    # 현재 설치 상태 확인

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

CLAUDE_DIR="$HOME/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

# ──────────────────────────────────────────────
# Server Definitions
# ──────────────────────────────────────────────

# 순서 = 표시 순서
SERVER_ORDER=(
  "context7"
  "sequential-thinking"
  "playwright"
  "github"
  "taskmaster"
)

declare -A SERVER_CMD
SERVER_CMD=(
  ["context7"]="npx -y @upstash/context7-mcp"
  ["sequential-thinking"]="npx -y @modelcontextprotocol/server-sequential-thinking"
  ["playwright"]="npx -y @playwright/mcp"
  ["github"]="npx -y @modelcontextprotocol/server-github"
  ["taskmaster"]="npx -y task-master-ai"
)

declare -A SERVER_ENV
SERVER_ENV=(
  ["context7"]=""
  ["sequential-thinking"]=""
  ["playwright"]=""
  ["github"]="GITHUB_PERSONAL_ACCESS_TOKEN"
  ["taskmaster"]="MODEL=claude-code"
)

declare -A SERVER_DESC
SERVER_DESC=(
  ["context7"]="라이브러리 최신 문서/코드 예제 조회 (FastAPI, React 등)"
  ["sequential-thinking"]="복잡한 문제 단계별 분석, 아키텍처 설계, 디버깅 추론"
  ["playwright"]="브라우저 자동화, E2E 테스트, DOM 스냅샷, 스크린샷"
  ["github"]="GitHub PR/Issue/Review 관리, 코드 검색"
  ["taskmaster"]="AI 기반 프로젝트 플래닝, PRD -> 태스크 분해"
)

declare -A SERVER_CAT
SERVER_CAT=(
  ["context7"]="core"
  ["sequential-thinking"]="core"
  ["playwright"]="recommended"
  ["github"]="recommended"
  ["taskmaster"]="recommended"
)

# ──────────────────────────────────────────────
# Functions
# ──────────────────────────────────────────────

check_prerequisites() {
  if ! command -v claude &> /dev/null; then
    echo -e "${RED}Error: 'claude' CLI not found. Install Claude Code first.${NC}"
    echo -e "${BLUE}https://docs.anthropic.com/en/docs/claude-code${NC}"
    exit 1
  fi

  if ! command -v npx &> /dev/null; then
    echo -e "${RED}Error: 'npx' not found. Install Node.js first.${NC}"
    exit 1
  fi
}

get_github_token() {
  # gh CLI에서 자동 추출 시도
  if command -v gh &> /dev/null; then
    local token
    token=$(gh auth token 2>/dev/null || true)
    if [[ -n "$token" ]]; then
      echo "$token"
      return 0
    fi
  fi

  # 환경변수 확인
  if [[ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]]; then
    echo "$GITHUB_PERSONAL_ACCESS_TOKEN"
    return 0
  fi

  return 1
}

is_installed() {
  local name=$1
  # exit code로 판별 (서버 미등록 시 exit 1 반환)
  # "Connected" 문자열 의존 제거 — 출력 형식 변경에 견고
  claude mcp get "$name" &>/dev/null
}

install_server() {
  local name=$1
  local cmd="${SERVER_CMD[$name]}"
  local env_spec="${SERVER_ENV[$name]}"

  # 이미 설치 확인
  if is_installed "$name"; then
    echo -e "  ${DIM}skip${NC} ${name} (이미 설치됨)"
    return 0
  fi

  echo -ne "  ${BLUE}...${NC}  ${name}"

  # 환경변수가 필요한 서버 처리
  local env_args=""
  if [[ "$name" == "github" ]]; then
    local gh_token
    gh_token=$(get_github_token) || true
    if [[ -z "$gh_token" ]]; then
      echo -e "\r  ${YELLOW}skip${NC} ${name} - GitHub 토큰 없음 (gh auth login 후 재실행)"
      return 1
    fi
    env_args="-e GITHUB_PERSONAL_ACCESS_TOKEN=$gh_token"
  fi

  if [[ "$name" == "taskmaster" ]]; then
    env_args="-e MODEL=claude-code"
  fi

  # 설치
  if claude mcp add "$name" $env_args -s user -- $cmd 2>/dev/null; then
    echo -e "\r  ${GREEN}done${NC} ${name}"
    return 0
  else
    echo -e "\r  ${RED}fail${NC} ${name}"
    return 1
  fi
}

install_plugin() {
  echo -e "${BLUE}Setting up superpowers plugin...${NC}"

  if [[ ! -f "$SETTINGS_FILE" ]]; then
    echo -e "  ${RED}fail${NC} settings.json not found"
    return 1
  fi

  python3 -c "
import json

with open('$SETTINGS_FILE') as f:
    settings = json.load(f)

changed = False

# 마켓플레이스 등록
marketplaces = settings.get('extraKnownMarketplaces', {})
if 'superpowers-marketplace' not in marketplaces:
    marketplaces['superpowers-marketplace'] = {
        'source': {
            'source': 'github',
            'repo': 'obra/superpowers-marketplace'
        }
    }
    settings['extraKnownMarketplaces'] = marketplaces
    changed = True

# 플러그인 활성화
plugins = settings.get('enabledPlugins', {})
if not plugins.get('superpowers@superpowers-marketplace'):
    plugins['superpowers@superpowers-marketplace'] = True
    settings['enabledPlugins'] = plugins
    changed = True

if changed:
    with open('$SETTINGS_FILE', 'w') as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
    print('  \033[0;32mdone\033[0m superpowers plugin')
else:
    print('  \033[2mskip\033[0m superpowers plugin (이미 설치됨)')
" 2>/dev/null
}

show_status() {
  echo ""
  echo -e "${BOLD}MCP Servers${NC}"
  echo ""
  for name in "${SERVER_ORDER[@]}"; do
    local cat="${SERVER_CAT[$name]}"
    local desc="${SERVER_DESC[$name]}"
    if is_installed "$name"; then
      echo -e "  ${GREEN}●${NC} ${name} ${DIM}[${cat}]${NC} - ${desc}"
    else
      echo -e "  ${RED}○${NC} ${name} ${DIM}[${cat}]${NC} - ${desc}"
    fi
  done

  echo ""
  echo -e "${BOLD}Plugin${NC}"
  echo ""
  if python3 -c "
import json
with open('$SETTINGS_FILE') as f:
    s = json.load(f)
exit(0 if s.get('enabledPlugins',{}).get('superpowers@superpowers-marketplace') else 1)
" 2>/dev/null; then
    echo -e "  ${GREEN}●${NC} superpowers ${DIM}[plugin]${NC} - TDD, 브레인스토밍, 디버깅 등 고급 워크플로우"
  else
    echo -e "  ${RED}○${NC} superpowers ${DIM}[plugin]${NC} - TDD, 브레인스토밍, 디버깅 등 고급 워크플로우"
  fi

  echo ""
  echo -e "${DIM}● = installed, ○ = not installed${NC}"
  echo ""
}

show_help() {
  echo "Usage: ./mcp-setup.sh [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --all       MCP 전체 + Plugin 설치"
  echo "  --core      Core MCP만 (context7 + sequential-thinking)"
  echo "  --mcp       MCP 서버만 전체 설치 (Plugin 제외)"
  echo "  --plugin    Plugin만 설치 (superpowers)"
  echo "  --list      현재 설치 상태 확인"
  echo "  --help, -h  이 도움말"
  echo ""
  echo "옵션 없이 실행하면 대화형 선택 모드입니다."
}

# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────

check_prerequisites

# Parse arguments
MODE=""
case "${1:-}" in
  --all)     MODE="all" ;;
  --core)    MODE="core" ;;
  --mcp)     MODE="mcp" ;;
  --plugin)  MODE="plugin" ;;
  --list)
    show_status
    exit 0
    ;;
  --help|-h)
    show_help
    exit 0
    ;;
  "")
    MODE="interactive"
    ;;
  *)
    echo -e "${RED}Unknown option: $1${NC}"
    show_help
    exit 1
    ;;
esac

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║    claude-code-preset  MCP & Plugin Setup    ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
echo ""

# Interactive mode
if [[ "$MODE" == "interactive" ]]; then
  echo -e "${BOLD}현재 상태:${NC}"
  show_status

  echo -e "${YELLOW}설치 범위를 선택하세요:${NC}"
  echo ""
  echo -e "  ${CYAN}1)${NC} All          - MCP 전체 + Plugin (권장)"
  echo -e "  ${CYAN}2)${NC} Core only    - context7 + sequential-thinking"
  echo -e "  ${CYAN}3)${NC} Custom       - 개별 선택"
  echo -e "  ${CYAN}4)${NC} Plugin only  - superpowers 플러그인만"
  echo -e "  ${CYAN}5)${NC} Cancel"
  echo ""
  read -p "Choice (1-5): " -n 1 -r
  echo ""

  case $REPLY in
    1) MODE="all" ;;
    2) MODE="core" ;;
    3) MODE="custom" ;;
    4) MODE="plugin" ;;
    5|*)
      echo -e "${RED}Cancelled.${NC}"
      exit 0
      ;;
  esac
fi

# Custom selection
SELECTED_SERVERS=()
if [[ "$MODE" == "custom" ]]; then
  echo ""
  echo -e "${YELLOW}설치할 서버를 선택하세요 (공백으로 구분):${NC}"
  echo ""
  idx=1
  for name in "${SERVER_ORDER[@]}"; do
    local_cat="${SERVER_CAT[$name]}"
    local_desc="${SERVER_DESC[$name]}"
    local_status=""
    if is_installed "$name"; then
      local_status="${GREEN}[installed]${NC}"
    fi
    if [[ "$local_cat" == "core" ]]; then
      echo -e "  ${CYAN}${idx})${NC} ${name} ${GREEN}[${local_cat}]${NC} ${local_status} - ${local_desc}"
    else
      echo -e "  ${CYAN}${idx})${NC} ${name} ${DIM}[${local_cat}]${NC} ${local_status} - ${local_desc}"
    fi
    ((idx++))
  done
  echo -e "  ${CYAN}${idx})${NC} superpowers ${DIM}[plugin]${NC} - TDD, 브레인스토밍, 디버깅 등 고급 워크플로우"
  echo ""
  read -p "Numbers (e.g., 1 2 3 6): " -r SELECTIONS

  INSTALL_PLUGIN=false
  for num in $SELECTIONS; do
    if [[ $num -eq $idx ]]; then
      INSTALL_PLUGIN=true
    else
      local sidx=$((num - 1))
      if [[ $sidx -ge 0 ]] && [[ $sidx -lt ${#SERVER_ORDER[@]} ]]; then
        SELECTED_SERVERS+=("${SERVER_ORDER[$sidx]}")
      fi
    fi
  done

  if [[ ${#SELECTED_SERVERS[@]} -eq 0 ]] && [[ "$INSTALL_PLUGIN" == "false" ]]; then
    echo -e "${RED}선택된 항목이 없습니다.${NC}"
    exit 0
  fi
fi

# ──────────────────────────────────────────────
# Install MCP Servers
# ──────────────────────────────────────────────

installed=0
failed=0
skipped=0

install_mcp_servers() {
  local servers=("$@")
  echo -e "${BOLD}MCP Servers 설치${NC}"
  echo ""
  for name in "${servers[@]}"; do
    if install_server "$name"; then
      ((installed++))
    else
      ((failed++))
    fi
  done
  echo ""
}

case "$MODE" in
  all)
    install_mcp_servers "${SERVER_ORDER[@]}"
    install_plugin
    ;;
  core)
    core_servers=()
    for name in "${SERVER_ORDER[@]}"; do
      if [[ "${SERVER_CAT[$name]}" == "core" ]]; then
        core_servers+=("$name")
      fi
    done
    install_mcp_servers "${core_servers[@]}"
    ;;
  mcp)
    install_mcp_servers "${SERVER_ORDER[@]}"
    ;;
  plugin)
    install_plugin
    ;;
  custom)
    if [[ ${#SELECTED_SERVERS[@]} -gt 0 ]]; then
      install_mcp_servers "${SELECTED_SERVERS[@]}"
    fi
    if [[ "$INSTALL_PLUGIN" == "true" ]]; then
      install_plugin
    fi
    ;;
esac

# ──────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────

echo ""
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${CYAN}claude mcp list${NC}  로 설치 상태를 확인하세요."
echo -e "  Claude Code를 ${BOLD}재시작${NC}해야 새 MCP가 활성화됩니다."
echo ""
