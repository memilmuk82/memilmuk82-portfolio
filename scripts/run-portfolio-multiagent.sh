#!/usr/bin/env bash
set -Eeuo pipefail

WORKDIR="/opt/apps/memilmuk82-portfolio"
SCRIPT_DIR="${WORKDIR}/scripts"
WORKER_SCRIPT="${SCRIPT_DIR}/run-portfolio-multiagent-worker.sh"
PROMPT_FILE="${WORKDIR}/automation/portfolio-multiagent-prompt.md"
RUN_ROOT="${WORKDIR}/.portfolio-agent-runs"
ACTIVE_PID_FILE="${RUN_ROOT}/active.pid"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
RUN_DIR="${RUN_ROOT}/${TIMESTAMP}-$$"
RUN_LOG="${RUN_DIR}/codex.log"
FINAL_REPORT="${RUN_DIR}/final.md"
STATE_FILE="${RUN_DIR}/state.md"
RESOLVED_PROMPT="${RUN_DIR}/prompt.md"
SESSION_NAME="milim-portfolio-${TIMESTAMP}-$$"

fail() {
    printf '오류: %s\n' "$*" >&2
    exit 1
}

command -v codex >/dev/null 2>&1 || fail "codex 명령을 찾을 수 없습니다."
command -v tmux >/dev/null 2>&1 || fail "tmux 명령을 찾을 수 없습니다."
[ -d "$WORKDIR" ] || fail "작업 디렉터리가 없습니다: ${WORKDIR}"
[ -f "$PROMPT_FILE" ] || fail "프롬프트 파일이 없습니다: ${PROMPT_FILE}"
[ -x "$WORKER_SCRIPT" ] || fail "실행 가능한 워커가 없습니다: ${WORKER_SCRIPT}"

mkdir -p "$RUN_ROOT"

if [ -f "$ACTIVE_PID_FILE" ]; then
    ACTIVE_PID="$(<"$ACTIVE_PID_FILE")"
    if [ -n "$ACTIVE_PID" ] && kill -0 "$ACTIVE_PID" 2>/dev/null; then
        printf '이미 멀티에이전트 작업이 실행 중입니다.\nPID: %s\n' "$ACTIVE_PID"
        exit 1
    fi
fi

mkdir -p "$RUN_DIR"
cp "$PROMPT_FILE" "$RESOLVED_PROMPT"
printf '\n## 이번 실행 파일\n\n- RUN_DIR: `%s`\n- STATE_FILE: `%s`\n- RUN_LOG: `%s`\n- FINAL_REPORT: `%s`\n\n위 STATE_FILE은 반드시 실제 진행에 맞춰 갱신한다.\n' \
    "$RUN_DIR" "$STATE_FILE" "$RUN_LOG" "$FINAL_REPORT" >> "$RESOLVED_PROMPT"

printf '# 포트폴리오 멀티에이전트 진행 상태\n\n- 시작: %s\n- 상태: 시작 대기\n- 실행 디렉터리: `%s`\n' \
    "$(date --iso-8601=seconds)" "$RUN_DIR" > "$STATE_FILE"

cd "$WORKDIR"
tmux new-session \
    -d \
    -s "$SESSION_NAME" \
    -c "$WORKDIR" \
    "$WORKER_SCRIPT" "$RUN_DIR" "$RESOLVED_PROMPT"

CODEX_PID="$(tmux list-panes -t "$SESSION_NAME" -F '#{pane_pid}' | head -n 1)"
printf '%s\n' "$CODEX_PID" > "$ACTIVE_PID_FILE"
printf '%s\n' "$RUN_DIR" > "${RUN_ROOT}/latest-run"
printf '%s\n' "$CODEX_PID" > "${RUN_DIR}/pid"
printf '%s\n' "$SESSION_NAME" > "${RUN_DIR}/tmux-session"

sleep 2
if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    printf 'Codex가 시작 직후 종료되었습니다.\n\n' >&2
    sed -n '1,240p' "$RUN_LOG" >&2
    exit 1
fi

printf '포트폴리오 멀티에이전트 작업을 시작했습니다.\n\n'
printf 'PID: %s\n' "$CODEX_PID"
printf 'tmux 세션: %s\n' "$SESSION_NAME"
printf '실행 디렉터리: %s\n' "$RUN_DIR"
printf '실행 로그: %s\n' "$RUN_LOG"
printf '진행 상태: %s\n' "$STATE_FILE"
printf '최종 보고서: %s\n\n' "$FINAL_REPORT"
printf '상태 확인: ps -p %s -o pid,etime,stat,%%cpu,%%mem,cmd\n' "$CODEX_PID"
printf '로그 확인: tail -f %s\n' "$RUN_LOG"
printf '세션 확인: tmux has-session -t %s\n' "$SESSION_NAME"
printf '작업 중지: tmux kill-session -t %s\n' "$SESSION_NAME"
