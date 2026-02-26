#!/bin/bash
# claude-code-preset - MCP Servers Setup Script
#
# Usage:
#   ./mcp-setup.sh           # Interactive mode (select servers)
#   ./mcp-setup.sh --all     # Install all MCP servers
#   ./mcp-setup.sh --core    # Install core servers only (context7 + sequential)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Check prerequisites
if ! command -v claude &> /dev/null; then
  echo -e "${RED}Error: 'claude' CLI not found. Install Claude Code first.${NC}"
  echo -e "${BLUE}https://docs.anthropic.com/en/docs/claude-code${NC}"
  exit 1
fi

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       claude-code-preset MCP Server Setup        ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""

# Server definitions
declare -A SERVERS
SERVERS=(
  ["context7"]="npx -y @upstash/context7-mcp@latest"
  ["sequential-thinking"]="npx -y @anthropics/sequential-thinking-mcp@latest"
  ["playwright"]="npx -y @anthropic/mcp-playwright@latest"
  ["serena"]="uvx serena-mcp"
  ["datadog-mcp"]="npx -y @anthropic/mcp-datadog@latest"
)

declare -A DESCRIPTIONS
DESCRIPTIONS=(
  ["context7"]="공식 라이브러리 문서 조회 (FastAPI, SQLAlchemy, Pydantic 등)"
  ["sequential-thinking"]="복잡한 분석, 다단계 추론, 아키텍처 설계"
  ["playwright"]="브라우저 자동화, E2E 테스트, 스크린샷"
  ["serena"]="시맨틱 코드 이해, 심볼 리네임, 참조 탐색"
  ["datadog-mcp"]="로그 조회, 메트릭, 모니터링 (DD_API_KEY 필요)"
)

declare -A CATEGORIES
CATEGORIES=(
  ["context7"]="core"
  ["sequential-thinking"]="core"
  ["playwright"]="optional"
  ["serena"]="optional"
  ["datadog-mcp"]="optional"
)

# Order for display
SERVER_ORDER=("context7" "sequential-thinking" "playwright" "serena" "datadog-mcp")

install_server() {
  local name=$1
  local cmd=${SERVERS[$name]}

  echo -e "${BLUE}Installing ${name}...${NC}"

  # Check for required env vars
  if [[ "$name" == "datadog-mcp" ]]; then
    if [[ -z "$DD_API_KEY" ]] || [[ -z "$DD_APP_KEY" ]]; then
      echo -e "${YELLOW}  ⚠ DD_API_KEY/DD_APP_KEY not set. Skipping datadog-mcp.${NC}"
      echo -e "${YELLOW}  Set env vars first, then re-run this script.${NC}"
      return 1
    fi
  fi

  # Check if uvx is available for serena
  if [[ "$name" == "serena" ]]; then
    if ! command -v uvx &> /dev/null; then
      echo -e "${YELLOW}  ⚠ 'uvx' not found. Installing via: pip install uv${NC}"
      pip install uv 2>/dev/null || {
        echo -e "${RED}  ✗ Failed to install uv. Install manually: pip install uv${NC}"
        return 1
      }
    fi
  fi

  # Check if npx is available for npm-based servers
  if [[ "$cmd" == npx* ]]; then
    if ! command -v npx &> /dev/null; then
      echo -e "${RED}  ✗ 'npx' not found. Install Node.js first.${NC}"
      return 1
    fi
  fi

  # Install via claude mcp add
  if claude mcp add "$name" -- $cmd 2>/dev/null; then
    echo -e "${GREEN}  ✓ ${name} installed${NC}"
    return 0
  else
    echo -e "${RED}  ✗ Failed to install ${name}${NC}"
    return 1
  fi
}

# Parse arguments
MODE=""
case "${1:-}" in
  --all)
    MODE="all"
    ;;
  --core)
    MODE="core"
    ;;
  --help|-h)
    echo "Usage: ./mcp-setup.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --all     Install all MCP servers"
    echo "  --core    Install core servers only (context7 + sequential-thinking)"
    echo "  --help    Show this help"
    echo ""
    echo "Without options, runs in interactive mode."
    exit 0
    ;;
  "")
    MODE="interactive"
    ;;
  *)
    echo -e "${RED}Unknown option: $1${NC}"
    echo "Run with --help for usage."
    exit 1
    ;;
esac

# Interactive mode
if [[ "$MODE" == "interactive" ]]; then
  echo -e "${YELLOW}Select MCP servers to install:${NC}"
  echo ""
  echo -e "  ${CYAN}1)${NC} Core only      - context7 + sequential-thinking (권장)"
  echo -e "  ${CYAN}2)${NC} All servers    - 전체 설치"
  echo -e "  ${CYAN}3)${NC} Custom         - 개별 선택"
  echo -e "  ${CYAN}4)${NC} Cancel"
  echo ""
  read -p "Choice (1/2/3/4): " -n 1 -r
  echo ""

  case $REPLY in
    1) MODE="core" ;;
    2) MODE="all" ;;
    3) MODE="custom" ;;
    4)
      echo -e "${RED}Cancelled.${NC}"
      exit 0
      ;;
    *)
      echo -e "${RED}Invalid choice.${NC}"
      exit 1
      ;;
  esac
fi

# Custom selection
if [[ "$MODE" == "custom" ]]; then
  echo ""
  echo -e "${YELLOW}Select servers (space-separated numbers):${NC}"
  echo ""
  idx=1
  for name in "${SERVER_ORDER[@]}"; do
    local_cat=${CATEGORIES[$name]}
    local_desc=${DESCRIPTIONS[$name]}
    if [[ "$local_cat" == "core" ]]; then
      echo -e "  ${CYAN}${idx})${NC} ${name} ${GREEN}[core]${NC} - ${local_desc}"
    else
      echo -e "  ${CYAN}${idx})${NC} ${name} - ${local_desc}"
    fi
    ((idx++))
  done
  echo ""
  read -p "Numbers (e.g., 1 2 3): " -r SELECTIONS

  SELECTED_SERVERS=()
  for num in $SELECTIONS; do
    idx=$((num - 1))
    if [[ $idx -ge 0 ]] && [[ $idx -lt ${#SERVER_ORDER[@]} ]]; then
      SELECTED_SERVERS+=("${SERVER_ORDER[$idx]}")
    fi
  done

  if [[ ${#SELECTED_SERVERS[@]} -eq 0 ]]; then
    echo -e "${RED}No servers selected.${NC}"
    exit 0
  fi
fi

# Install
echo ""
installed=0
failed=0

if [[ "$MODE" == "core" ]]; then
  for name in "${SERVER_ORDER[@]}"; do
    if [[ "${CATEGORIES[$name]}" == "core" ]]; then
      if install_server "$name"; then
        ((installed++))
      else
        ((failed++))
      fi
    fi
  done
elif [[ "$MODE" == "all" ]]; then
  for name in "${SERVER_ORDER[@]}"; do
    if install_server "$name"; then
      ((installed++))
    else
      ((failed++))
    fi
  done
elif [[ "$MODE" == "custom" ]]; then
  for name in "${SELECTED_SERVERS[@]}"; do
    if install_server "$name"; then
      ((installed++))
    else
      ((failed++))
    fi
  done
fi

# Summary
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         MCP Setup Complete!                ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ✅ Installed: ${installed}"
if [[ $failed -gt 0 ]]; then
  echo -e "  ❌ Failed: ${failed}"
fi
echo ""
echo -e "${YELLOW}Verify:${NC}"
echo -e "  ${CYAN}claude mcp list${NC}"
echo ""
echo -e "${YELLOW}Note:${NC}"
echo -e "  Restart Claude Code to activate new MCP servers."
echo ""
