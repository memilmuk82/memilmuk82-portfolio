#!/usr/bin/env bash
set -Eeuo pipefail

WORKDIR="/opt/apps/memilmuk82-portfolio"
RUN_DIR="${1:?실행 디렉터리가 필요합니다.}"
PROMPT_FILE="${2:?해결된 프롬프트 파일이 필요합니다.}"
RUN_LOG="${RUN_DIR}/codex.log"
FINAL_REPORT="${RUN_DIR}/final.md"
STATE_FILE="${RUN_DIR}/state.md"

PROMPT_CONTENT="$(<"$PROMPT_FILE")"

printf '\n- 워커 시작: %s\n- 상태: Codex 멀티에이전트 실행 중\n' \
    "$(date --iso-8601=seconds)" >> "$STATE_FILE"

set +e
codex \
    --enable multi_agent \
    --ask-for-approval never \
    --sandbox workspace-write \
    --cd "$WORKDIR" \
    exec \
    --skip-git-repo-check \
    --output-last-message "$FINAL_REPORT" \
    "$PROMPT_CONTENT" \
    > "$RUN_LOG" 2>&1 \
    < /dev/null
EXIT_CODE=$?
set -e

printf '\n- 워커 종료: %s\n- Codex 종료 코드: %s\n' \
    "$(date --iso-8601=seconds)" "$EXIT_CODE" >> "$STATE_FILE"

exit "$EXIT_CODE"
