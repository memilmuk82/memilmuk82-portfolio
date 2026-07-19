#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

printf '기존 실행기는 portfolio-agent.sh로 통합되었습니다.\n' >&2
exec bash "${SCRIPT_DIR}/portfolio-agent.sh" start
