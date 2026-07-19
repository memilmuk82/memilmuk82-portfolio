#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
WORKDIR="${PORTFOLIO_WORKDIR:-$(cd -- "${SCRIPT_DIR}/.." && pwd -P)}"
APPS_ROOT="${PORTFOLIO_APPS_ROOT:-$(dirname -- "$WORKDIR")}"
PROMPT_FILE="${PORTFOLIO_PROMPT_FILE:-${WORKDIR}/automation/portfolio-improvement-prompt.md}"
RUN_ROOT="${PORTFOLIO_RUN_ROOT:-${WORKDIR}/.portfolio-agent-runs}"
MANUAL_CONTACT="${PORTFOLIO_MANUAL_CONTACT:-}"
NOTIFY_HOOK="${PORTFOLIO_NOTIFY_HOOK:-}"
AGENT_THREADS="${PORTFOLIO_AGENT_THREADS:-4}"
EXECUTION_SCOPE="${PORTFOLIO_EXECUTION_SCOPE:-all}"
MAX_FIX_LOOPS="${PORTFOLIO_MAX_FIX_LOOPS:-2}"
TEST_POLICY="essential-only"
ACTIVE_PID_FILE="${RUN_ROOT}/active.pid"
ACTIVE_RUN_FILE="${RUN_ROOT}/active-run"
LATEST_RUN_FILE="${RUN_ROOT}/latest-run"
LOCK_FILE="${RUN_ROOT}/runner.lock"

usage() {
    cat <<'EOF'
사용법:
  bash scripts/portfolio-agent.sh                # 현재 상태 확인
  bash scripts/portfolio-agent.sh start
  bash scripts/portfolio-agent.sh status
  bash scripts/portfolio-agent.sh gates
  bash scripts/portfolio-agent.sh resume --confirm-all
  bash scripts/portfolio-agent.sh logs
  bash scripts/portfolio-agent.sh report
  bash scripts/portfolio-agent.sh stop [--force]

환경 변수:
  PORTFOLIO_WORKDIR        포트폴리오 저장소 루트
  PORTFOLIO_APPS_ROOT      프로젝트 저장소 상위 폴더(기본값: WORKDIR의 부모)
  PORTFOLIO_PROMPT_FILE    실행할 Markdown 프롬프트
  PORTFOLIO_RUN_ROOT       로그·상태 저장 경로
  PORTFOLIO_MANUAL_CONTACT 수동 설정 안내 이메일 주소
  PORTFOLIO_NOTIFY_HOOK    선택적 메일 전송 실행 파일(본문은 stdin)
  PORTFOLIO_AGENT_THREADS  총괄 포함 동시 에이전트 수(기본값 4, 최대 4)
  PORTFOLIO_EXECUTION_SCOPE 실행 범위(all, gpt-vercel, static-sites, portfolio)
  PORTFOLIO_MAX_FIX_LOOPS  실패 시 최소 수정 루프 수(기본값 2, 최대 3)
  PORTFOLIO_CODEX_MODEL    선택적 Codex 모델 이름
  PORTFOLIO_CODEX_PROFILE  선택적 Codex 설정 프로필

권장 시작 예:
  PORTFOLIO_MANUAL_CONTACT='name@example.com' bash scripts/portfolio-agent.sh start

`start`는 준비·감사·로컬 수정 단계입니다. 외부 콘솔 설정이 필요하면 안내문을
만들고 `awaiting_manual`로 종료합니다. 설정을 마친 사람이 `resume --confirm-all`
을 실행하면 이전 산출물을 읽는 새 백그라운드 작업이 실제 링크 검증과 포트폴리오
통합을 재개합니다. 검사는 변경 범위에 직접 필요한 항목만 실행합니다.
EOF
}

fail() {
    printf '오류: %s\n' "$*" >&2
    exit 1
}

read_value() {
    local path="$1"
    if [ -s "$path" ]; then
        <"$path" tr -d '\r\n'
    fi
}

write_value() {
    local path="$1"
    local value="$2"
    local temporary="${path}.tmp.$$"
    printf '%s\n' "$value" > "$temporary"
    mv -f -- "$temporary" "$path"
}

is_pid() {
    [[ "${1:-}" =~ ^[1-9][0-9]*$ ]]
}

is_email() {
    [[ "${1:-}" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]
}

is_running() {
    local pid
    pid="$(read_value "$ACTIVE_PID_FILE")"
    is_pid "$pid" && kill -0 "$pid" 2>/dev/null
}

latest_run() {
    local run_dir
    run_dir="$(read_value "$LATEST_RUN_FILE")"
    [ -n "$run_dir" ] && [ -d "$run_dir" ] || return 1
    printf '%s\n' "$run_dir"
}

show_paths() {
    local run_dir="$1"
    printf '실행 디렉터리: %s\n' "$run_dir"
    printf '진행 상태: %s/state.md\n' "$run_dir"
    printf '기계 상태: %s/run-state.json\n' "$run_dir"
    printf '실행 로그: %s/codex.log\n' "$run_dir"
    printf '수동 설정: %s/manual-actions.md\n' "$run_dir"
    printf '최종 보고서: %s/final.md\n' "$run_dir"
}

cleanup_active_files() {
    local expected_pid="$1"
    local current_pid
    current_pid="$(read_value "$ACTIVE_PID_FILE")"
    if [ "$current_pid" = "$expected_pid" ]; then
        rm -f -- "$ACTIVE_PID_FILE" "$ACTIVE_RUN_FILE"
    fi
}

manual_gate_is_valid() {
    local actions_file="$1"
    jq -e '
        .status == "awaiting_manual"
        and (.gate_id | type == "string" and length > 0)
        and (.resume_command | type == "string" and length > 0)
        and (.actions | type == "array" and length > 0)
        and (([.actions[].id] | length) == ([.actions[].id] | unique | length))
        and all(.actions[];
            (.id | type == "string" and length > 0)
            and (.project | type == "string" and length > 0)
            and (.provider | IN("firebase", "vercel", "dns", "github", "supabase", "cloudflare", "other"))
            and (.instructions | type == "array" and length > 0)
            and (.required_environment_variables | type == "array")
            and (.completion_evidence | type == "array" and length > 0)
        )
    ' "$actions_file" >/dev/null 2>&1
}

run_state_is_awaiting_manual() {
    local run_state_file="$1"
    jq -e '
        .state == "awaiting_manual"
        and (
            (.pending_manual_actions | type == "number" and . > 0)
            or (.pending_manual_actions | type == "array" and length > 0)
        )
    ' "$run_state_file" >/dev/null 2>&1
}

run_state_is_completed() {
    local run_dir="$1"
    local run_state_file="${run_dir}/run-state.json"
    local required_path required_count required_index

    jq -e '
        .state == "completed"
        and (.required_results | type == "array" and length > 0)
        and (.checks | type == "array")
        and all(.checks[];
            (.status == "passed") or (.status == "not_applicable")
        )
        and (
            .pending_manual_actions == 0
            or (.pending_manual_actions | type == "array" and length == 0)
        )
    ' "$run_state_file" >/dev/null 2>&1 || return 1

    required_count="$(jq -r '.required_results | length' "$run_state_file")"
    for ((required_index = 0; required_index < required_count; required_index += 1)); do
        required_path="$(jq -r --argjson index "$required_index" '.required_results[$index]' "$run_state_file")"
        [[ "$required_path" =~ ^[A-Za-z0-9._/-]+$ ]] || return 1
        [[ "$required_path" != /* ]] || return 1
        [[ "/$required_path/" != *"/../"* ]] || return 1
        [ -s "${run_dir}/${required_path}" ] || return 1
    done
}

write_manual_email() {
    local run_dir="$1"
    local body_file="${run_dir}/manual-actions.md"
    local eml_file="${run_dir}/manual-actions.eml"
    local delivery_file="${run_dir}/manual-email-status"
    local subject='[MEMILMUK82] Portfolio manual setup required'

    [ -s "$body_file" ] || return 0

    if ! is_email "$MANUAL_CONTACT"; then
        printf 'not-sent: PORTFOLIO_MANUAL_CONTACT가 없거나 형식이 올바르지 않음\n' \
            > "$delivery_file"
        return 0
    fi

    {
        printf 'To: %s\n' "$MANUAL_CONTACT"
        printf 'Subject: %s\n' "$subject"
        printf 'Content-Type: text/plain; charset=UTF-8\n'
        printf '\n'
        sed 's/\r$//' "$body_file"
    } > "$eml_file"

    if [ -n "$NOTIFY_HOOK" ]; then
        if [ -x "$NOTIFY_HOOK" ] \
            && "$NOTIFY_HOOK" "$MANUAL_CONTACT" "$subject" < "$body_file"; then
            printf 'accepted-by-hook: %s\n' "$(date --iso-8601=seconds)" \
                > "$delivery_file"
            return 0
        fi
    elif command -v mail >/dev/null 2>&1; then
        if mail -s "$subject" -- "$MANUAL_CONTACT" < "$body_file"; then
            printf 'accepted-by-mail: %s\n' "$(date --iso-8601=seconds)" \
                > "$delivery_file"
            return 0
        fi
    elif command -v sendmail >/dev/null 2>&1; then
        if sendmail -t < "$eml_file"; then
            printf 'accepted-by-sendmail: %s\n' "$(date --iso-8601=seconds)" \
                > "$delivery_file"
            return 0
        fi
    fi

    printf 'not-sent: mail/sendmail 전송 실패; %s 확인 필요\n' "$eml_file" \
        > "$delivery_file"
}

run_worker() {
    local run_dir="${1:?실행 디렉터리가 필요합니다.}"
    local resolved_prompt="${2:?프롬프트 파일이 필요합니다.}"
    local state_file="${run_dir}/state.md"
    local run_log="${run_dir}/codex.log"
    local final_report="${run_dir}/final.md"
    local exit_file="${run_dir}/exit-code"
    local actions_file="${run_dir}/manual-actions.json"
    local run_state_file="${run_dir}/run-state.json"
    local final_state="blocked"
    local -a global_args exec_args

    trap 'cleanup_active_files "$$"' EXIT

    printf '\n- 워커 시작: %s\n- 상태: 멀티에이전트 실행 중\n' \
        "$(date --iso-8601=seconds)" >> "$state_file"
    touch "${run_dir}/ready"

    global_args=(
        --cd "$WORKDIR"
        --sandbox workspace-write
        --ask-for-approval never
        --config "agents.max_threads=${AGENT_THREADS}"
        --config 'agents.max_depth=1'
        --config 'agents.job_max_runtime_seconds=2400'
    )
    if [ "$APPS_ROOT" != "$WORKDIR" ]; then
        global_args+=(--add-dir "$APPS_ROOT")
    fi
    if [ -n "${PORTFOLIO_CODEX_MODEL:-}" ]; then
        global_args+=(--model "$PORTFOLIO_CODEX_MODEL")
    fi
    if [ -n "${PORTFOLIO_CODEX_PROFILE:-}" ]; then
        global_args+=(--profile "$PORTFOLIO_CODEX_PROFILE")
    fi
    exec_args=(
        --ephemeral
        --output-last-message "$final_report"
    )

    set +e
    codex "${global_args[@]}" exec "${exec_args[@]}" \
        - < "$resolved_prompt" > "$run_log" 2>&1
    local exit_code=$?
    set -e

    if [ -s "$actions_file" ]; then
        if manual_gate_is_valid "$actions_file" \
            && [ -s "${run_dir}/manual-actions.md" ] \
            && run_state_is_awaiting_manual "$run_state_file"; then
            touch "${run_dir}/awaiting-manual"
            write_manual_email "$run_dir"
            final_state="awaiting_manual"
            printf '\n- 수동 게이트: %s\n- 상태: awaiting_manual\n' \
                "$(date --iso-8601=seconds)" >> "$state_file"
        else
            printf '\n- 수동 게이트 오류: JSON 형식 또는 Markdown 안내 누락\n' \
                >> "$state_file"
            [ "$exit_code" -ne 0 ] || exit_code=2
        fi
    fi

    if [ "$final_state" != "awaiting_manual" ]; then
        if [ "$exit_code" -eq 0 ] \
            && [ -s "$final_report" ] \
            && run_state_is_completed "$run_dir"; then
            final_state="completed"
        else
            final_state="blocked"
            [ "$exit_code" -ne 0 ] || exit_code=2
            printf '\n- 완료 판정 실패: final.md, run-state.json, 필수 결과 또는 검사 상태 확인 필요\n' \
                >> "$state_file"
        fi
    fi

    printf '%s\n' "$exit_code" > "$exit_file"
    printf '\n- 워커 종료: %s\n- Codex 종료 코드: %s\n- 상태: %s\n' \
        "$(date --iso-8601=seconds)" \
        "$exit_code" \
        "$final_state" \
        >> "$state_file"

    return "$exit_code"
}

preflight() {
    command -v codex >/dev/null 2>&1 || fail "codex CLI를 찾을 수 없습니다."
    command -v git >/dev/null 2>&1 || fail "git을 찾을 수 없습니다."
    command -v jq >/dev/null 2>&1 || fail "jq를 찾을 수 없습니다."
    command -v flock >/dev/null 2>&1 || fail "flock을 찾을 수 없습니다."
    command -v nohup >/dev/null 2>&1 || fail "nohup을 찾을 수 없습니다."
    command -v setsid >/dev/null 2>&1 || fail "setsid를 찾을 수 없습니다."
    command -v sha256sum >/dev/null 2>&1 || fail "sha256sum을 찾을 수 없습니다."
    [[ "$AGENT_THREADS" =~ ^[1-4]$ ]] \
        || fail "PORTFOLIO_AGENT_THREADS는 1~4 정수여야 합니다."
    [[ "$MAX_FIX_LOOPS" =~ ^[1-3]$ ]] \
        || fail "PORTFOLIO_MAX_FIX_LOOPS는 1~3 정수여야 합니다."
    case "$EXECUTION_SCOPE" in
        all|gpt-vercel|static-sites|portfolio) ;;
        *) fail "PORTFOLIO_EXECUTION_SCOPE는 all, gpt-vercel, static-sites, portfolio 중 하나여야 합니다." ;;
    esac
    [ -d "$WORKDIR" ] || fail "작업 디렉터리가 없습니다: $WORKDIR"
    [ -d "$APPS_ROOT" ] || fail "프로젝트 상위 폴더가 없습니다: $APPS_ROOT"
    [ "$APPS_ROOT" != "/" ] || fail "프로젝트 상위 폴더로 /를 사용할 수 없습니다."
    [ "$APPS_ROOT" != "${HOME:-/__unset_home__}" ] \
        || fail "프로젝트 상위 폴더로 HOME을 사용할 수 없습니다."
    [ -f "$PROMPT_FILE" ] || fail "프롬프트 파일이 없습니다: $PROMPT_FILE"
    git -C "$WORKDIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
        || fail "작업 디렉터리가 Git 저장소가 아닙니다: $WORKDIR"
}

launch_run() {
    local mode="$1"
    local previous_run="${2:-}"
    local stamp run_dir resolved_prompt state_file run_state_file launcher_log pid
    local prompt_hash workdir_head

    preflight
    mkdir -p -- "$RUN_ROOT"
    exec 9>"$LOCK_FILE"
    flock -n 9 || fail "다른 시작·중지 작업이 진행 중입니다."

    if is_running; then
        local active_pid active_run
        active_pid="$(read_value "$ACTIVE_PID_FILE")"
        active_run="$(read_value "$ACTIVE_RUN_FILE")"
        printf '이미 포트폴리오 개선 작업이 실행 중입니다.\n'
        printf 'PID: %s\n' "$active_pid"
        [ -z "$active_run" ] || show_paths "$active_run"
        exit 1
    fi

    rm -f -- "$ACTIVE_PID_FILE" "$ACTIVE_RUN_FILE"

    stamp="$(date '+%Y%m%d-%H%M%S')"
    run_dir="$(mktemp -d "${RUN_ROOT}/${stamp}-${mode}-XXXXXX")"
    resolved_prompt="${run_dir}/prompt.md"
    state_file="${run_dir}/state.md"
    run_state_file="${run_dir}/run-state.json"
    launcher_log="${run_dir}/launcher.log"
    mkdir -p -- "${run_dir}/results" "${run_dir}/link-checks" \
        "${run_dir}/manual-actions"

    cp -- "$PROMPT_FILE" "$resolved_prompt"
    {
        printf '\n## 이번 백그라운드 실행 정보\n\n'
        printf -- '- EXECUTION_MODE: `%s`\n' "$mode"
        printf -- '- RUN_DIR: `%s`\n' "$run_dir"
        printf -- '- STATE_FILE: `%s`\n' "$state_file"
        printf -- '- RUN_STATE_JSON: `%s`\n' "$run_state_file"
        printf -- '- RUN_LOG: `%s/codex.log`\n' "$run_dir"
        printf -- '- FINAL_REPORT: `%s/final.md`\n' "$run_dir"
        printf -- '- APPS_ROOT: `%s`\n' "$APPS_ROOT"
        printf -- '- MANUAL_CONTACT: `%s`\n' "$MANUAL_CONTACT"
        printf -- '- EXECUTION_SCOPE: `%s`\n' "$EXECUTION_SCOPE"
        printf -- '- TEST_POLICY: `%s`\n' "$TEST_POLICY"
        printf -- '- MAX_FIX_LOOPS: `%s`\n' "$MAX_FIX_LOOPS"
        if [ -n "$previous_run" ]; then
            printf -- '- PREVIOUS_RUN: `%s`\n' "$previous_run"
            printf -- '- PREVIOUS_MANUAL_ACTIONS: `%s/manual-actions.json`\n' \
                "$previous_run"
            printf -- '- MANUAL_CONFIRMATION: `%s/manual-confirmation.json`\n' \
                "$run_dir"
        fi
        printf '\n진행 단계마다 STATE_FILE과 RUN_STATE_JSON을 실제 상태에 맞춰 갱신한다.\n'
    } >> "$resolved_prompt"

    prompt_hash="$(sha256sum "$PROMPT_FILE" | awk '{print $1}')"
    workdir_head="$(git -C "$WORKDIR" rev-parse HEAD)"
    jq -n \
        --arg mode "$mode" \
        --arg scope "$EXECUTION_SCOPE" \
        --arg test_policy "$TEST_POLICY" \
        --argjson max_fix_loops "$MAX_FIX_LOOPS" \
        --arg prompt_sha256 "$prompt_hash" \
        --arg workdir_head "$workdir_head" \
        --arg started_at "$(date --iso-8601=seconds)" \
        '{
          mode: $mode,
          scope: $scope,
          test_policy: $test_policy,
          max_fix_loops: $max_fix_loops,
          prompt_sha256: $prompt_sha256,
          workdir_head: $workdir_head,
          started_at: $started_at
        }' > "${run_dir}/run-manifest.json"

    jq -n \
        --arg updated_at "$(date --iso-8601=seconds)" \
        '{
          state: "discovering",
          required_results: [],
          checks: [],
          pending_manual_actions: 0,
          updated_at: $updated_at
        }' > "$run_state_file"

    if [ -n "$previous_run" ]; then
        local action_ids manual_actions_hash
        cp -- "${previous_run}/manual-actions.json" \
            "${run_dir}/previous-manual-actions.json"
        action_ids="$(jq -c '[.actions[].id]' "${previous_run}/manual-actions.json")"
        manual_actions_hash="$(sha256sum "${previous_run}/manual-actions.json" | awk '{print $1}')"
        jq -n \
            --arg gate_id "$(jq -r '.gate_id' "${previous_run}/manual-actions.json")" \
            --arg confirmed_at "$(date --iso-8601=seconds)" \
            --arg previous_run "$previous_run" \
            --arg manual_actions_sha256 "$manual_actions_hash" \
            --argjson action_ids "$action_ids" \
            '{
              gate_id: $gate_id,
              confirmed_all: true,
              action_ids: $action_ids,
              manual_actions_sha256: $manual_actions_sha256,
              confirmed_at: $confirmed_at,
              previous_run: $previous_run
            }' > "${run_dir}/manual-confirmation.json"
    fi

    {
        printf '# 포트폴리오 개선 진행 상태\n\n'
        printf -- '- 시작 요청: %s\n' "$(date --iso-8601=seconds)"
        printf -- '- 실행 모드: %s\n' "$mode"
        printf -- '- 실행 범위: %s\n' "$EXECUTION_SCOPE"
        printf -- '- 테스트 정책: %s\n' "$TEST_POLICY"
        printf -- '- 최대 수정 루프: %s\n' "$MAX_FIX_LOOPS"
        printf -- '- 상태: 워커 시작 중\n'
        printf -- '- 작업 디렉터리: `%s`\n' "$WORKDIR"
        printf -- '- 프로젝트 루트: `%s`\n' "$APPS_ROOT"
        printf -- '- 실행 디렉터리: `%s`\n' "$run_dir"
    } > "$state_file"

    nohup setsid bash "$0" __worker "$run_dir" "$resolved_prompt" \
        > "$launcher_log" 2>&1 < /dev/null 9>&- &
    pid=$!

    write_value "$ACTIVE_PID_FILE" "$pid"
    write_value "$ACTIVE_RUN_FILE" "$run_dir"
    write_value "$LATEST_RUN_FILE" "$run_dir"
    write_value "${run_dir}/pid" "$pid"

    local ready_attempt
    for ready_attempt in 1 2 3 4 5; do
        [ -f "${run_dir}/ready" ] && break
        kill -0 "$pid" 2>/dev/null || break
        sleep 1
    done
    if ! kill -0 "$pid" 2>/dev/null || [ ! -f "${run_dir}/ready" ]; then
        rm -f -- "$ACTIVE_PID_FILE" "$ACTIVE_RUN_FILE"
        printf 'Codex가 시작 직후 종료되었습니다.\n' >&2
        sed -n '1,200p' "$launcher_log" >&2
        exit 1
    fi

    printf '포트폴리오 멀티에이전트 작업을 시작했습니다.\n'
    printf 'PID: %s\n' "$pid"
    show_paths "$run_dir"
}

start_run() {
    launch_run prepare
}

resume_run() {
    local confirmation="${1:-}"
    local previous_run
    [ "$confirmation" = "--confirm-all" ] \
        || fail "수동 설정 완료 후 resume --confirm-all을 사용합니다."
    previous_run="$(latest_run)" || fail "재개할 실행 기록이 없습니다."
    [ -f "${previous_run}/awaiting-manual" ] \
        || fail "최근 실행은 수동 설정 대기 상태가 아닙니다."
    [ -s "${previous_run}/manual-actions.json" ] \
        || fail "수동 설정 목록이 없습니다."
    manual_gate_is_valid "${previous_run}/manual-actions.json" \
        || fail "수동 설정 목록 형식이 올바르지 않습니다."
    launch_run resume "$previous_run"
}

show_status() {
    local run_dir pid
    run_dir="$(read_value "$ACTIVE_RUN_FILE")"
    pid="$(read_value "$ACTIVE_PID_FILE")"

    if is_running; then
        printf '상태: 실행 중\nPID: %s\n' "$pid"
        show_paths "$run_dir"
        if [ -f "${run_dir}/state.md" ]; then
            printf '\n'
            tail -n 24 "${run_dir}/state.md"
        fi
        return 0
    fi

    printf '상태: 실행 중인 작업 없음\n'
    if run_dir="$(latest_run)"; then
        if [ -f "${run_dir}/awaiting-manual" ]; then
            printf '최근 상태: awaiting_manual\n'
            printf '재개 명령: bash scripts/portfolio-agent.sh resume --confirm-all\n'
        fi
        show_paths "$run_dir"
        if [ -s "${run_dir}/exit-code" ]; then
            printf '최근 종료 코드: %s\n' "$(read_value "${run_dir}/exit-code")"
        fi
        if [ -s "${run_dir}/manual-email-status" ]; then
            printf '이메일 상태: %s\n' "$(read_value "${run_dir}/manual-email-status")"
        fi
    fi
}

show_gates() {
    local run_dir
    run_dir="$(latest_run)" || fail "확인할 실행 기록이 없습니다."
    if [ -s "${run_dir}/manual-actions.md" ]; then
        sed -n '1,360p' "${run_dir}/manual-actions.md"
        printf '\n재개 명령: bash scripts/portfolio-agent.sh resume --confirm-all\n'
    else
        printf '수동 설정 대기 항목이 없습니다.\n'
    fi
}

show_logs() {
    local run_dir pid
    if is_running; then
        run_dir="$(read_value "$ACTIVE_RUN_FILE")"
    else
        run_dir="$(latest_run)" || fail "확인할 실행 기록이 없습니다."
    fi
    [ -f "${run_dir}/codex.log" ] \
        || fail "아직 실행 로그가 없습니다: ${run_dir}/codex.log"
    pid="$(read_value "${run_dir}/pid")"
    if is_pid "$pid" && kill -0 "$pid" 2>/dev/null \
        && tail --help 2>&1 | grep -q -- '--pid'; then
        tail --pid="$pid" -n 120 -F "${run_dir}/codex.log"
    else
        tail -n 120 -F "${run_dir}/codex.log"
    fi
}

show_report() {
    local run_dir
    run_dir="$(latest_run)" || fail "확인할 실행 기록이 없습니다."
    if [ -s "${run_dir}/final.md" ]; then
        sed -n '1,360p' "${run_dir}/final.md"
    else
        printf '최종 보고서가 아직 없습니다.\n'
        show_paths "$run_dir"
    fi
}

stop_run() {
    local force="${1:-}" pid pgid run_dir signal
    [ -z "$force" ] || [ "$force" = "--force" ] \
        || fail "stop은 --force만 허용합니다."

    mkdir -p -- "$RUN_ROOT"
    exec 9>"$LOCK_FILE"
    flock -n 9 || fail "다른 시작·중지 작업이 진행 중입니다."

    if ! is_running; then
        printf '실행 중인 작업이 없습니다.\n'
        rm -f -- "$ACTIVE_PID_FILE" "$ACTIVE_RUN_FILE"
        return 0
    fi

    pid="$(read_value "$ACTIVE_PID_FILE")"
    run_dir="$(read_value "$ACTIVE_RUN_FILE")"
    signal="TERM"
    [ "$force" != "--force" ] || signal="KILL"

    pgid="$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')"
    if is_pid "$pgid" && [ "$pgid" = "$pid" ]; then
        kill -s "$signal" -- "-$pgid" 2>/dev/null \
            || fail "프로세스 그룹 $pgid 작업을 중지하지 못했습니다."
    else
        kill -s "$signal" "$pid" 2>/dev/null \
            || fail "PID $pid 작업을 중지하지 못했습니다."
    fi

    printf '%s 신호를 보냈습니다. PID: %s\n' "$signal" "$pid"
    [ -z "$run_dir" ] || show_paths "$run_dir"
}

command_name="${1:-status}"
case "$command_name" in
    start)
        [ "$#" -eq 1 ] || fail "start에는 추가 인수가 없습니다."
        start_run
        ;;
    status)
        [ "$#" -le 1 ] || fail "status에는 추가 인수가 없습니다."
        show_status
        ;;
    gates)
        [ "$#" -eq 1 ] || fail "gates에는 추가 인수가 없습니다."
        show_gates
        ;;
    resume)
        [ "$#" -eq 2 ] || fail "resume --confirm-all 형식으로 사용합니다."
        resume_run "$2"
        ;;
    logs)
        [ "$#" -eq 1 ] || fail "logs에는 추가 인수가 없습니다."
        show_logs
        ;;
    report)
        [ "$#" -eq 1 ] || fail "report에는 추가 인수가 없습니다."
        show_report
        ;;
    stop)
        [ "$#" -le 2 ] || fail "stop [--force] 형식으로 사용합니다."
        stop_run "${2:-}"
        ;;
    __worker)
        [ "$#" -eq 3 ] || fail "내부 워커 인수가 올바르지 않습니다."
        run_worker "$2" "$3"
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        usage >&2
        fail "알 수 없는 명령: $command_name"
        ;;
esac
