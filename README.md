# MEMILMUK82 Portfolio

교육 현장의 문제를 검증 가능한 웹 서비스와 자동화 흐름으로 바꾸는 과정을 소개하는 한국어 포트폴리오입니다. Flask 애플리케이션 팩토리, 기능별 Blueprint, Jinja 서버 렌더링, 로컬 Tailwind CSS와 Vanilla JavaScript로 구성했습니다.

## 화면과 경로

- `/`: 핵심 소개, 대표 프로젝트, 작업 축과 원칙
- `/projects`: 검색·연결 방식을 조합하는 56개 인벤토리 필터와 점진적 향상
- `/projects/<slug>`: 문제, 판단, 기여, 검증된 결과와 개선 방향
- `/activity`: 2020~2026년 수업 내용의 변화와 다섯 가지 활동 주제 흐름
- `/about`: 다루는 문제, 기술, 작업 방식과 검증된 연결
- `/healthz`: 외부 의존성이 없는 상태 확인
- 사용자 친화적인 404·500 오류 화면

프로젝트 화면의 기준 데이터는 `app/content/project_inventory.json`입니다. `/opt/apps`의 독립 저장소 56개를 서브도메인 웹앱 9개(PostgreSQL 3, SQLite 5, 무DB 1), 정적 사이트 7개, 소스·프로젝트 소개 28개, 비공개·제외 12개로 빠짐없이 기록합니다. `app/content/projects.json`은 그중 상세 사례 페이지가 있는 네 프로젝트의 서술형 콘텐츠를 담당합니다. 확인된 운영 URL·GitHub 저장소·산출물 URL만 용도별 HTTPS 필드로 제공하며, 비공개·제외 항목에는 외부 링크를 제공하지 않습니다.

교육 변화는 2020—2021 `프로그래밍과 웹의 기초`, 2022—2023 `서버·API·데이터로 확장`, 2024—2025 `서비스와 에듀테크`, 2026 `AI 활용에서 설계·검증으로`의 네 시기로만 설명합니다. 근거 없는 학교명, 성과·경력 수치나 연도별 사건은 추가하지 않습니다.

## 로컬 실행

Python 3.12+, Node.js 20+와 `uv`를 기준으로 합니다.

```bash
uv sync --dev
npm ci
npm run css:build
uv run flask --app 'app:create_app()' run --host 127.0.0.1 --port 8000
```

운영 WSGI 실행은 다음과 같습니다.

```bash
uv run gunicorn --bind 127.0.0.1:8000 --workers 2 --threads 4 wsgi:app
curl --fail http://127.0.0.1:8000/healthz
```

## 품질 검사

```bash
make css
make lint
make format-check
make test
make check
```

CSS는 `app/static/css/input.css`를 Tailwind CLI로 빌드해 `app/static/css/site.css`로 제공합니다. 런타임은 외부 CDN과 외부 폰트 요청에 의존하지 않습니다. JavaScript가 없을 때도 핵심 링크와 GET 필터가 동작하며, JavaScript는 모바일 메뉴와 필터 상태 안내만 향상합니다.

## 환경 변수

`.env.example`에는 변수 이름만 유지합니다.

- `PORTFOLIO_EXECUTION_MODE`: 미설정하거나 비워 두면 `local`로 정규화. 운영 실행은 `production`
- `PORTFOLIO_SECRET_KEY`: 운영 세션 비밀값. `production`에서는 반드시 비어 있지 않은 별도 값을 설정해야 하며 로컬 기본값과 `change-me`는 앱 시작 단계에서 거부
- `PORTFOLIO_GITHUB_URL`: 소유권과 공개 범위를 확인한 HTTPS 프로필 URL만 선택적으로 설정

실제 비밀값은 저장소에 커밋하지 않습니다.

## 구조

```text
app/
  routes/       # 공개 페이지와 상태 확인 Blueprint
  services/     # 공개 콘텐츠 로딩·스키마 검증·필터
  templates/    # Jinja 상속 템플릿
  static/       # Tailwind 입력·빌드 CSS와 Vanilla JavaScript
  content/      # 검증된 최소 공개 JSON
tests/          # 라우트·오류·헤더·콘텐츠·필터 계약
docs/           # 검증, 설계, 활동 출처와 운영 보고서
```

## 보안·접근성

응답에 CSP, 프레이밍 제한, MIME 스니핑 방지, Referrer-Policy와 Permissions-Policy를 적용합니다. 건너뛰기 링크, 의미론적 제목, 키보드 포커스, 44px 이상 모바일 조작 영역, `aria-live`, `prefers-reduced-motion`을 지원합니다. 새 탭 외부 링크가 활성화되는 경우 `rel="noopener noreferrer"`를 사용합니다.

## 배포 개요

Gunicorn은 8000번 포트에서 실행하고, Compose 운영 구성은 루프백에만 노출하는 것을 전제로 합니다. 최종 호스트는 `www.memilmuk82.com`, 향후 원격은 `memilmuk82/memilmuk82-portfolio`입니다. 이번 local 실행에서는 GitHub 생성·push, DNS, Cloudflare, Nginx, 인증서, 방화벽과 운영 컨테이너를 변경하지 않습니다. 자세한 게이트와 롤백은 `docs/DEPLOYMENT.md` 및 `docs/EXTERNAL_ACTIONS.md`에서 관리합니다.
