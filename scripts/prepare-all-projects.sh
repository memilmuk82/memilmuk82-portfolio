#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

cat >&2 <<'EOF'
이전 저장소별 순차 실행기는 차단·수동 게이트를 완료로 오인할 수 있어 중단했습니다.

새 하네스를 사용하세요.
  bash scripts/portfolio-agent.sh start
  bash scripts/portfolio-agent.sh status
  bash scripts/portfolio-agent.sh gates
  bash scripts/portfolio-agent.sh resume --confirm-all
EOF

exec bash "${SCRIPT_DIR}/portfolio-agent.sh" --help
