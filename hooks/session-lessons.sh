#!/bin/bash
# SessionStart hook: check for learned lessons in project memory
# Reminds Claude to review past lessons at session start

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)

if [ -z "$CWD" ]; then
  exit 0
fi

PROJECTS_DIR="$HOME/.claude/projects"
PROJECT_KEY=$(echo "$CWD" | sed 's|/|-|g; s|^-||')
MEMORY_DIR="$PROJECTS_DIR/$PROJECT_KEY/memory"

if [ ! -d "$MEMORY_DIR" ]; then
  exit 0
fi

LESSON_COUNT=$(find "$MEMORY_DIR" -name "*.md" ! -name "last-session.md" -type f 2>/dev/null | wc -l | tr -d ' ')

if [ "$LESSON_COUNT" -gt 0 ]; then
  LESSONS=$(find "$MEMORY_DIR" -name "*.md" ! -name "last-session.md" -type f -printf '%f\n' 2>/dev/null | head -5 | sed 's/\.md$//' | tr '\n' ', ' | sed 's/,$//')
  if [ -z "$LESSONS" ]; then
    LESSONS=$(find "$MEMORY_DIR" -name "*.md" ! -name "last-session.md" -type f 2>/dev/null | head -5 | xargs -I{} basename {} .md | tr '\n' ', ' | sed 's/,$//')
  fi
  echo "📚 이 프로젝트에 ${LESSON_COUNT}개의 교훈이 있습니다: ${LESSONS}. 관련 작업 시 $MEMORY_DIR 를 참고하세요." >&2
fi

exit 0
