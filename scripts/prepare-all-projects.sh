#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PORTFOLIO_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
APPS_ROOT="${APPS_ROOT:-$(dirname -- "$PORTFOLIO_DIR")}"
INVENTORY="${PORTFOLIO_DIR}/app/content/project_inventory.json"
MASTER_PROMPT="${PORTFOLIO_DIR}/automation/all-projects-publish-prompt.md"
OUTPUT_SCHEMA="${PORTFOLIO_DIR}/automation/publication-result.schema.json"
RUN_ROOT="${PORTFOLIO_DIR}/.publication-agent-runs"

MODE="list"
PROJECT_FILTER=""
GROUP_FILTER=""
ALLOW_DIRTY=0
RESUME_DIR=""
MAX_PROJECTS=0

usage() {
    cat <<'EOF'
사용법:
  scripts/prepare-all-projects.sh
  scripts/prepare-all-projects.sh --apply [옵션]
  scripts/prepare-all-projects.sh --resume RUN_DIR [옵션]

기본 동작은 56개 프로젝트와 권장 게시 방식만 출력하며 파일을 수정하지 않습니다.

옵션:
  --apply               Codex를 저장소별로 순차 실행해 게시 준비 변경을 수행
  --resume RUN_DIR      기존 실행 디렉터리에서 완료되지 않은 프로젝트만 재개
  --project NAME        저장소 이름 하나만 처리
  --group GROUP         subdomain, site, source, excluded 중 하나만 처리
  --allow-dirty         기존 변경이 있는 저장소도 처리(기본값은 안전하게 건너뜀)
  --max N               최대 N개까지만 처리(0은 제한 없음)
  --apps-root PATH      프로젝트 상위 폴더 지정(기본값: /opt/apps 계열)
  -h, --help            도움말 표시

예시:
  scripts/prepare-all-projects.sh --project fastapi_crud
  scripts/prepare-all-projects.sh --apply --project fastapi_crud
  scripts/prepare-all-projects.sh --apply --group site --max 2
  scripts/prepare-all-projects.sh --resume .publication-agent-runs/20260719-120000
EOF
}

fail() {
    printf '오류: %s\n' "$*" >&2
    exit 1
}

publication_hint() {
    local name="$1"
    local group="$2"

    case "$name" in
        junior-college-admission|gpt-manager)
            printf '%s' 'existing-live'
            ;;
        nodebird|nodebird-api|DjangoBlog|ToDo|hello_flask|noom)
            printf '%s' 'docker'
            ;;
        do_it_django|DjangoBlog2)
            printf '%s' 'repository-only'
            ;;
        gpt-vercel|todo_260613|chatbot)
            printf '%s' 'vercel-firebase'
            ;;
        fastapi_crud|My_Dashboard|RestfulServer)
            printf '%s' 'vercel-supabase'
            ;;
        demo-app|BardAPI_test2|OpenAPI_project|Router_express.js|nodecat)
            printf '%s' 'vercel-stateless'
            ;;
        gpt-pro-shared-reservation-apps-script|whalespace-training)
            printf '%s' 'external-platform'
            ;;
        *)
            case "$group" in
                site) printf '%s' 'github-pages' ;;
                excluded) printf '%s' 'excluded' ;;
                *) printf '%s' 'repository-only' ;;
            esac
            ;;
    esac
}

write_skip_result() {
    local result_file="$1"
    local name="$2"
    local method="$3"
    local reason="$4"
    local group="$5"
    local destination="$6"

    jq -n \
        --arg project_name "$name" \
        --arg method "$method" \
        --arg reason "$reason" \
        --arg group "$group" \
        --arg destination "$destination" \
        '{
          project_name: $project_name,
          status: "blocked",
          publication_method: $method,
          readiness: "needs-work",
          summary: $reason,
          changed_files: [],
          verification: [],
          blockers: [$reason],
          external_actions: [],
          portfolio_update: {
            group: $group,
            destination: $destination,
            live_url: null,
            artifact_url: null,
            notes: $reason
          }
        }' > "$result_file"
}

while (($#)); do
    case "$1" in
        --apply)
            MODE="apply"
            shift
            ;;
        --resume)
            (($# >= 2)) || fail "--resume에는 실행 디렉터리가 필요합니다."
            MODE="apply"
            RESUME_DIR="$2"
            shift 2
            ;;
        --project)
            (($# >= 2)) || fail "--project에는 저장소 이름이 필요합니다."
            PROJECT_FILTER="$2"
            shift 2
            ;;
        --group)
            (($# >= 2)) || fail "--group에는 분류가 필요합니다."
            GROUP_FILTER="$2"
            shift 2
            ;;
        --allow-dirty)
            ALLOW_DIRTY=1
            shift
            ;;
        --max)
            (($# >= 2)) || fail "--max에는 숫자가 필요합니다."
            MAX_PROJECTS="$2"
            [[ "$MAX_PROJECTS" =~ ^[0-9]+$ ]] || fail "--max는 0 이상의 정수여야 합니다."
            shift 2
            ;;
        --apps-root)
            (($# >= 2)) || fail "--apps-root에는 경로가 필요합니다."
            APPS_ROOT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "알 수 없는 옵션: $1"
            ;;
    esac
done

case "$GROUP_FILTER" in
    ""|subdomain|site|source|excluded) ;;
    *) fail "지원하지 않는 group입니다: $GROUP_FILTER" ;;
esac

[ -d "$APPS_ROOT" ] || fail "프로젝트 상위 폴더가 없습니다: $APPS_ROOT"
[ -f "$INVENTORY" ] || fail "인벤토리가 없습니다: $INVENTORY"
[ -f "$MASTER_PROMPT" ] || fail "마스터 프롬프트가 없습니다: $MASTER_PROMPT"
[ -f "$OUTPUT_SCHEMA" ] || fail "출력 스키마가 없습니다: $OUTPUT_SCHEMA"
command -v jq >/dev/null 2>&1 || fail "jq가 필요합니다."

inventory_count="$(jq 'length' "$INVENTORY")"
[ "$inventory_count" -eq 56 ] || fail "인벤토리 항목이 56개가 아닙니다: $inventory_count"

mapfile -t PROJECT_RECORDS < <(jq -c '.[]' "$INVENTORY")

if [ "$MODE" = "list" ]; then
    printf 'NAME\tGROUP\tRECOMMENDED_METHOD\tLOCAL_PATH\n'
    for record in "${PROJECT_RECORDS[@]}"; do
        name="$(jq -r '.name' <<<"$record")"
        group="$(jq -r '.group' <<<"$record")"
        [ -z "$PROJECT_FILTER" ] || [ "$name" = "$PROJECT_FILTER" ] || continue
        [ -z "$GROUP_FILTER" ] || [ "$group" = "$GROUP_FILTER" ] || continue
        method="$(publication_hint "$name" "$group")"
        printf '%s\t%s\t%s\t%s/%s\n' "$name" "$group" "$method" "$APPS_ROOT" "$name"
    done
    printf '\n실제 수정은 --apply를 명시해야 시작됩니다.\n'
    exit 0
fi

command -v codex >/dev/null 2>&1 || fail "codex CLI가 필요합니다."
command -v git >/dev/null 2>&1 || fail "git이 필요합니다."

if [ -n "$RESUME_DIR" ]; then
    RUN_DIR="$(cd -- "$RESUME_DIR" 2>/dev/null && pwd)" || fail "재개할 실행 디렉터리가 없습니다: $RESUME_DIR"
else
    RUN_DIR="${RUN_ROOT}/$(date '+%Y%m%d-%H%M%S')"
    mkdir -p "$RUN_DIR"
fi

RESULT_DIR="${RUN_DIR}/results"
LOG_DIR="${RUN_DIR}/logs"
mkdir -p "$RESULT_DIR" "$LOG_DIR"

printf '실행 디렉터리: %s\n' "$RUN_DIR"
printf '프로젝트 루트: %s\n' "$APPS_ROOT"
printf '외부 배포: 비활성화(게시 준비만 수행)\n\n'

processed=0
succeeded=0
skipped=0
failed=0

for record in "${PROJECT_RECORDS[@]}"; do
    name="$(jq -r '.name' <<<"$record")"
    slug="$(jq -r '.slug' <<<"$record")"
    group="$(jq -r '.group' <<<"$record")"
    stack="$(jq -r '.stack' <<<"$record")"
    destination="$(jq -r '.destination' <<<"$record")"
    summary="$(jq -r '.summary' <<<"$record")"

    [ -z "$PROJECT_FILTER" ] || [ "$name" = "$PROJECT_FILTER" ] || continue
    [ -z "$GROUP_FILTER" ] || [ "$group" = "$GROUP_FILTER" ] || continue
    if [ "$MAX_PROJECTS" -gt 0 ] && [ "$processed" -ge "$MAX_PROJECTS" ]; then
        break
    fi

    processed=$((processed + 1))
    method="$(publication_hint "$name" "$group")"
    repo_dir="${APPS_ROOT}/${name}"
    result_file="${RESULT_DIR}/${slug}.json"
    log_file="${LOG_DIR}/${slug}.log"

    if [ -s "$result_file" ] && jq -e . "$result_file" >/dev/null 2>&1; then
        printf '[%d] 완료 결과 존재, 건너뜀: %s\n' "$processed" "$name"
        skipped=$((skipped + 1))
        continue
    fi

    printf '[%d] 준비 시작: %s (%s)\n' "$processed" "$name" "$method"

    if [ ! -d "$repo_dir" ]; then
        write_skip_result "$result_file" "$name" "$method" "로컬 저장소 디렉터리가 없습니다: $repo_dir" "$group" "$destination"
        printf '  건너뜀: 로컬 디렉터리 없음\n'
        skipped=$((skipped + 1))
        continue
    fi

    if ! git -C "$repo_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        write_skip_result "$result_file" "$name" "$method" "Git 저장소가 아닙니다: $repo_dir" "$group" "$destination"
        printf '  건너뜀: Git 저장소 아님\n'
        skipped=$((skipped + 1))
        continue
    fi

    if [ "$ALLOW_DIRTY" -eq 0 ] && [ -n "$(git -C "$repo_dir" status --short)" ]; then
        write_skip_result "$result_file" "$name" "$method" "기존 작업 트리 변경이 있어 안전하게 건너뛰었습니다. 검토 후 --allow-dirty로 다시 실행하세요." "$group" "$destination"
        printf '  건너뜀: 기존 변경 존재\n'
        skipped=$((skipped + 1))
        continue
    fi

    set +e
    {
        cat "$MASTER_PROMPT"
        printf '\n## 프로젝트 컨텍스트\n\n'
        printf '%s\n' '```json'
        jq -n \
            --arg name "$name" \
            --arg slug "$slug" \
            --arg group "$group" \
            --arg stack "$stack" \
            --arg destination "$destination" \
            --arg summary "$summary" \
            --arg recommended_method "$method" \
            '{
              name: $name,
              slug: $slug,
              current_group: $group,
              current_stack: $stack,
              current_destination: $destination,
              current_summary: $summary,
              recommended_method: $recommended_method,
              external_deployment_allowed: false
            }'
        printf '%s\n' '```'
    } | codex exec \
        --cd "$repo_dir" \
        --sandbox workspace-write \
        --ephemeral \
        --output-schema "$OUTPUT_SCHEMA" \
        --output-last-message "$result_file" \
        - > "$log_file" 2>&1
    exit_code=$?
    set -e

    if [ "$exit_code" -eq 0 ] && [ -s "$result_file" ] && jq -e . "$result_file" >/dev/null 2>&1; then
        printf '  완료: %s\n' "$result_file"
        succeeded=$((succeeded + 1))
    else
        printf '  실패(exit=%d): %s\n' "$exit_code" "$log_file" >&2
        failed=$((failed + 1))
    fi
done

mapfile -t VALID_RESULTS < <(find "$RESULT_DIR" -maxdepth 1 -type f -name '*.json' -print | sort)
if [ "${#VALID_RESULTS[@]}" -gt 0 ]; then
    jq -s \
        --arg generated_at "$(date --iso-8601=seconds)" \
        '{generated_at: $generated_at, count: length, results: .}' \
        "${VALID_RESULTS[@]}" > "${RUN_DIR}/summary.json"
fi

printf '\n처리=%d 성공=%d 건너뜀=%d 실패=%d\n' "$processed" "$succeeded" "$skipped" "$failed"
printf '결과 요약: %s\n' "${RUN_DIR}/summary.json"

if [ "$failed" -gt 0 ]; then
    exit 1
fi
