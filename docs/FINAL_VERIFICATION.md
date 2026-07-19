# 최종 웹앱 실행 검증

> 2026-07-18 콘텐츠 정정: 아래 최초 검증의 “공개 콘텐츠 네 항목” 계약은 사용자 요구와 달라 폐기됐다. 현재 프로젝트 목록은 56개 전체 인벤토리를 사용하며, 상세 사례 콘텐츠만 네 항목을 유지한다. 최신 기능·시각 검수 결과는 `docs/QA_REPORT.md`와 `docs/VISUAL_FIDELITY_LEDGER.md` 상단 정정 기록을 따른다.

검증일: 2026-07-18 (Asia/Seoul)
담당 역할: 7. 최종 웹앱 실행 체크 에이전트
실행 모드: `local`
최종 판정: **로컬 구현·검증·커밋 완료 — 환경 제약은 재실행 명령과 함께 문서화**

## 1. 결론

Flask/Jinja 앱의 필수 경로, 정적 자산, 오류 페이지, 보안 헤더, 공개 콘텐츠, Tailwind 산출물, Ruff와 pytest는 실제 검증을 통과했다. 기존 Playwright Firefox 검수 문서와 13개 스크린샷도 현재 코드·콘셉트와 일치한다.

초기 최종 검사에서 발견한 Node 잠금 파일의 `fsevents` 누락과 운영 Compose의 실행 모드 미전달은 수정됐다. npm 12의 표준 오프라인 `npm ci`, 프로젝트 자체 Tailwind 빌드, Compose 병합 결과의 `production` 전달, 회귀 테스트와 배포 템플릿 검사를 독립 재실행해 모두 통과했다.

`uv.lock` 생성·새 `.venv` 설치, Gunicorn TCP 바인딩, Docker 이미지·컨테이너 헬스체크는 네트워크·캐시·소켓 권한 제약 때문에 완료하지 못했다. 명세에 따라 오류와 재실행 명령을 정확히 기록했으며, 실행 가능한 로컬 기준은 통과했다. 이후 대체 독립 Git 저장소에서 파일별 staging 검토와 로컬 커밋 `7a2f882`까지 완료했다.

## 2. 검증 환경

| 도구 | 실제 값 |
| --- | --- |
| Python | 3.12.3 |
| Node.js | 22.23.1 |
| npm | 12.0.0 |
| uv | 0.11.26 |
| Docker CLI | 29.6.1 |
| Docker Compose | v5.3.0 |
| 검증용 Tailwind CLI | 3.4.17, 읽기 전용 참고 설치 |
| 검증용 Python 환경 | Python 3.12 기반 참고 가상환경, Flask 3.1.3·Gunicorn 23.0.0·pytest·Ruff 사용 |
| Browser 플러그인 | 없음 — `Browser plugin not available` |

프로젝트 자체 `.venv`는 생성돼 있지만 Flask가 설치되지 않은 빈 환경이다. 참고 가상환경은 테스트 실행에만 사용했으며 새 환경 설치 성공을 대신한다고 주장하지 않는다.

아래 명령의 `$VERIFICATION_VENV`와 `$TAILWIND_CLI`는 각각 버전이 일치하는 사전 설치 read-only Python 검증 환경과 Tailwind 3.4.17 실행 파일을 가리킨다. 공개 문서에는 호스트의 로컬 절대 참고 경로를 기록하지 않는다.

## 3. 설치와 잠금 파일

### 3.1 Node 설치 — 통과

실행:

```bash
npm ci --offline --ignore-scripts --no-audit --no-fund
```

`package-lock.json`에 Linux에서는 선택 의존성인 `fsevents` 2.3.3 잠금 항목을 추가한 뒤 독립 재실행했다.

```text
added 74 packages in 4s
```

이어서 프로젝트 표준 빌드를 실행했다.

```bash
npm run css:build
```

결과: Tailwind 프로덕션 빌드 성공. `app/static/css/site.css`의 SHA-256은 기존 검증값과 같은 `8c5f54e92494494b1a6a4f72c7f80f7439f0cc6fdac0c8e96449823c4bb7ce11`이다. Dockerfile의 assets 단계와 같은 `npm ci`·빌드 경로가 재현된다.

### 3.2 Python 설치와 uv 잠금 — 환경 제약

현재 `uv.lock`은 없다.

```bash
UV_CACHE_DIR=/tmp/portfolio-final-uv-cache uv lock --check
```

결과: `uv.lock`이 없어 실패했다.

```bash
UV_CACHE_DIR=/tmp/portfolio-final-uv-cache uv lock --offline
UV_CACHE_DIR=/tmp/portfolio-final-uv-cache uv sync --offline --dev
```

결과: 쓰기 가능한 임시 캐시는 사용했지만 네트워크가 비활성화돼 있고 해당 캐시에 Flask 3.1.3 메타데이터가 없어 해석·설치가 실패했다.

Docker 전용 `requirements.lock`에는 `pyproject.toml`의 직접 런타임 의존성 `Flask==3.1.3`, `gunicorn==23.0.0`이 같은 버전으로 존재한다. 그러나 Docker 소켓 제한 때문에 새 이미지 안에서 실제 설치되지는 않았다.

재검증:

```bash
UV_CACHE_DIR=/tmp/portfolio-final-uv-cache uv lock
uv lock --check
uv sync --frozen --dev
uv run python -c "import flask, gunicorn, pytest; print('python dependencies: PASS')"
```

## 4. Tailwind 프로덕션 빌드

프로젝트와 정확히 같은 Tailwind 3.4.17의 읽기 전용 로컬 CLI로 새 출력 파일을 `/tmp`에 생성했다.

```bash
"$TAILWIND_CLI" \
  -c tailwind.config.js \
  -i app/static/css/input.css \
  -o /tmp/portfolio-final-site.css \
  --minify
cmp /tmp/portfolio-final-site.css app/static/css/site.css
```

결과: 빌드 성공, `cmp` 성공. 두 파일은 모두 27,470 bytes이며 SHA-256은 다음과 같이 동일했다.

```text
8c5f54e92494494b1a6a4f72c7f80f7439f0cc6fdac0c8e96449823c4bb7ce11
```

경고는 `caniuse-lite` 데이터가 오래됐다는 내용뿐이었다. CSS 소스와 커밋 대상 산출물의 정합성뿐 아니라 프로젝트 자체 `npm ci && npm run css:build`도 통과했다.

## 5. 정적 검사와 자동 테스트

실행:

```bash
"$VERIFICATION_VENV/bin/ruff" check .
"$VERIFICATION_VENV/bin/ruff" format --check .
PYTHONPATH=. "$VERIFICATION_VENV/bin/pytest" -q
```

결과:

```text
All checks passed!
12 files already formatted
30 passed
```

테스트는 라우트, 서버 필터, 콘텐츠 스키마, 공개 제외 표식, 보안 헤더, 404/500, favicon, 모바일 포커스 트랩 계약, 외부 URL 검증, production 비밀값 fail-fast와 운영 Compose 실행 모드 회귀를 포함한다.

## 6. Flask test_client 전체 실행 확인

첫 요청 전에 전용 500 라우트를 등록한 fresh app을 만들고 다음 경로를 실제 요청했다.

| 경로 | 상태 | MIME | bytes |
| --- | ---: | --- | ---: |
| `/` | 200 | `text/html` | 8,702 |
| `/projects` | 200 | `text/html` | 8,952 |
| `/projects/junior-college-admission` | 200 | `text/html` | 5,735 |
| `/activity` | 200 | `text/html` | 4,662 |
| `/about` | 200 | `text/html` | 5,532 |
| `/healthz` | 200 | `text/plain` | 3 |
| `/static/css/site.css` | 200 | `text/css` | 27,470 |
| `/static/js/site.js` | 200 | `text/javascript` | 4,401 |
| `/static/images/favicon.svg` | 200 | `image/svg+xml` | 233 |
| `/favicon.ico` | 200 | `image/svg+xml` | 233 |
| 존재하지 않는 경로 | 404 | `text/html` | 3,090 |
| 검증 전용 오류 경로 | 500 | `text/html` | 3,085 |

`/healthz` 본문은 정확히 `ok\n`이었다. `/`, `/healthz`, 404, 500 모두 다음 헤더를 빠짐없이 반환했다.

- `Content-Security-Policy`
- `X-Content-Type-Options`
- `X-Frame-Options`
- `Referrer-Policy`
- `Permissions-Policy`

판정: **test_client 범위 통과**.

## 7. Gunicorn 실제 기동

Gunicorn 23.0.0으로 실제 TCP 바인딩을 시도했다.

```bash
PYTHONPATH=. PORTFOLIO_EXECUTION_MODE=local \
  "$VERIFICATION_VENV/bin/gunicorn" \
  --bind 127.0.0.1:8066 --workers 1 --threads 1 wsgi:app
```

앱과 Gunicorn 로딩은 시작됐지만 소켓 생성이 다섯 차례 다음 오류로 거부돼 종료됐다.

```text
connection to ('127.0.0.1', 8066) failed: [Errno 1] Operation not permitted
Can't connect to ('127.0.0.1', 8066)
```

판정: **환경 제약으로 미검증**. 이 때문에 실제 HTTP 요청, Gunicorn 워커·신호 처리·정상 종료는 통과로 표시하지 않는다.

재검증:

```bash
uv run gunicorn --bind 127.0.0.1:8000 --workers 2 --threads 4 wsgi:app
curl --fail --silent --show-error http://127.0.0.1:8000/healthz
```

## 8. 브라우저 QA와 시각 증거 정합성

Browser 플러그인은 세션에 없었다. 새 TCP 서버도 소켓 권한 때문에 열 수 없어 이번 역할에서 브라우저를 재기동하지 않았다. 대신 독립 QA가 Playwright 1.61.1 Firefox에서 Flask `test_client` 응답을 `route.fulfill`로 전달해 실행한 증거를 다음과 같이 확인했다.

- `docs/QA_REPORT.md`: 1440×1100, 390×844, 360×800의 페이지 identity, 빈 화면, 오류 오버레이, 콘솔, 메뉴·필터·키보드 상호작용 결과 기록
- `docs/VISUAL_FIDELITY_LEDGER.md`: 콘셉트와 최종 구현의 18개 비교 항목, 초기 mismatch 수정, 의도적 차이와 agency sign-off 기록
- `docs/screenshots/`: 보고서가 참조한 PNG 13개가 모두 존재하며 누락 참조 없음
- 데스크톱 PNG 폭: 모두 1,440px
- 모바일 PNG 폭: 390px, 보조 경계 화면 360px

`view_image`로 홈 콘셉트와 `desktop-home.png`, 모바일 콘셉트와 `mobile-menu-open.png`·`mobile-360-projects.png`를 직접 대조했다. 종이색·잉크·코발트 팔레트, 열린 행, 전체 폭 밴드, 모바일 단일 열·메뉴 구조가 문서 설명과 일치했다. QA 문서가 이미 밝힌 제목 줄바꿈, 단순 문자형 블루프린트 아이콘, 항상 보이는 모바일 `select`는 실제 이미지에서도 확인되는 문서화된 비차단 차이다.

판정: **기존 브라우저 증거와 현재 문서 정합성 통과**. 단, 실제 TCP·Chromium·Safari·네트워크 성능 검증은 포함하지 않는다.

## 9. Docker와 Compose

### 9.1 정적 구성 — 일부 통과

```bash
PORTFOLIO_SECRET_KEY=final-config-check docker compose config -q
PORTFOLIO_SECRET_KEY=final-config-check docker compose config --services
PORTFOLIO_SECRET_KEY=final-config-check docker compose config --images
sh -n deployment/validate-templates.sh
PORTFOLIO_DOMAIN=www.memilmuk82.com deployment/validate-templates.sh
```

결과: Compose 구문, `web` 서비스, `memilmuk82-portfolio:local` 이미지 이름, 배포 셸 문법과 템플릿 검사는 통과했다. 루프백 바인딩 `127.0.0.1:8000:8000`, `www.memilmuk82.com`, 인증서 경로와 Nginx 루프백 프록시가 정적 검증됐다.

### 9.2 운영 실행 모드 전달 — 통과

다음 병합 구성을 확인했다.

```bash
PORTFOLIO_SECRET_KEY=final-config-check \
PORTFOLIO_IMAGE=memilmuk82-portfolio:local \
docker compose -f compose.yaml -f deployment/compose.production.yaml config
```

수정 뒤 컨테이너 환경에는 다음 값이 명확히 포함됐다.

```text
PORTFOLIO_EXECUTION_MODE: production
PORTFOLIO_GITHUB_URL
PORTFOLIO_SECRET_KEY
```

`deployment/compose.production.yaml`이 실행 모드를 서비스 환경에 직접 전달한다. `docker compose config`의 실제 병합 출력과 `tests/test_config.py` 회귀 검사가 모두 `production`을 확인했다. 따라서 production 전용 비밀값 fail-fast 경계가 컨테이너 실행에서도 활성화된다.

### 9.3 Docker 이미지와 헬스체크 — 환경 제약

```bash
docker info
docker build --tag memilmuk82-portfolio:final-verification .
```

두 명령 모두 Dockerfile 실행 전에 실패했다.

```text
permission denied while trying to connect to the docker API at unix:///var/run/docker.sock
```

따라서 이미지 생성, Python 잠금 설치, UID 10001, 비루트 실행, 읽기 전용 파일시스템, 신호 처리와 컨테이너 health 상태는 실제로 검증되지 않았다. 호스트에서 Docker assets 단계와 같은 `npm ci`·Tailwind 빌드는 통과했다. 기존 컨테이너는 조회·중지·교체하지 않았다.

재검증:

```bash
docker info
docker build --tag memilmuk82-portfolio:local .
docker image inspect memilmuk82-portfolio:local \
  --format '{{json .Config.User}} {{json .Config.ExposedPorts}} {{json .Config.Healthcheck}}'

export PORTFOLIO_SECRET_KEY='로컬에서만 사용할 별도 임시값'
docker compose up --build --detach
docker compose exec -T web id -u
curl --fail --silent --show-error http://127.0.0.1:8000/healthz
docker compose ps
docker compose down
unset PORTFOLIO_SECRET_KEY
```

Docker 소켓 권한이 있는 격리 환경에서 위 실행 검증만 다시 수행하면 된다.

## 10. 배포 템플릿과 외부 대기

`docs/DEPLOYMENT.md`, `docs/EXTERNAL_ACTIONS.md`, `deployment/`의 Compose overlay·HTTP-01 bootstrap·TLS Nginx 예제·롤백 절차가 존재한다. 기본 호스트는 `www.memilmuk82.com`이며 루트 도메인을 임의로 설정하지 않는다. Nginx는 앱의 `127.0.0.1:8000`만 프록시한다.

이번 local 실행에서는 다음을 수행하지 않았다.

- GitHub 저장소 생성, origin, push, PR
- Cloudflare/DNS 조회·변경과 SSL 모드 변경
- `/etc/nginx` 조회·설치·reload
- Certbot 발급·갱신 시험
- 방화벽 변경
- 운영 Compose 기동과 기존 컨테이너 변경

위 작업은 실행 모드·승인 게이트·대상 서버·인증·롤백 확인이 없는 외부 대기 항목이다.

## 11. 공개 안전성 검사

사용자에게 제공되는 `app/templates`, `app/content`, 빌드 CSS와 JavaScript를 검색했다. 다음 표식은 발견되지 않았다.

- 로컬 절대 경로
- 분류 보고서·원본 source JSON 파일명
- `localhost`, `127.0.0.1`
- 보류 프로젝트 slug
- 내부 메모 필드명

실제 `.env`, PEM, 개인 키 파일은 프로젝트에서 발견되지 않았다. 개인키 블록, 대표 클라우드 키, GitHub/OpenAI 키 형태의 고신뢰 패턴도 파일명 검색 결과가 없었다. 이 검사는 전용 비밀 탐지 도구와 Git 이력 검사를 대체하지 않는다.

공개 JSON은 정확히 네 항목이며 `links` 필드는 0개, 네 검토 불리언의 `true` 값은 0개였다.

```text
junior-college-admission
gpt-manager
ai-teaching-deck
whalespace-training
```

판정: **현재 작업 트리와 사용자 화면 범위 통과**.

## 12. 필수 산출물과 문서 상태

명세의 필수 앱·검증·배포 문서와 `docs/VISUAL_FIDELITY_LEDGER.md`는 모두 존재한다. `PROJECT_STATUS.md`는 이 재검증과 역할 1~7의 실제 결과에 맞춰 갱신했다. `docs/PUBLISH_READINESS.md`의 Git·게시 항목은 로컬 커밋과 외부 게시 역할에서 최종 상태를 기록한다.

루트 `.git/`은 빈 읽기 전용 tmpfs mount라 그대로 보존했다. 프로젝트 내부 `.git-local/` 대체 저장소의 `main`에서 로컬 커밋 `7a2f882947bf999645872f54a4e550ba6205b8a6`을 생성했다. 외부 게시와 원격 연결은 수행하지 않았다.

## 13. 최종 게이트 표

| 게이트 | 결과 | 분류 |
| --- | --- | --- |
| Flask/Jinja/Vanilla JS 앱 구조 | 통과 | 로컬 성공 |
| 필수 페이지·활동 링크·오류 페이지 | 통과 | 로컬 성공 |
| 공개 콘텐츠 네 항목과 링크 보류 | 통과 | 로컬 성공 |
| 보안 헤더·production 비밀값 단위 테스트 | 통과 | 로컬 성공 |
| Ruff·포맷·pytest | 통과 | 로컬 성공 |
| Tailwind 소스와 빌드 CSS 정합성 | 통과 | 로컬 성공 |
| 프로젝트 자체 `npm ci` 재현 설치 | 통과 | 로컬 성공, 오프라인 캐시 사용 |
| `uv.lock`·새 Python 환경 설치 | 미검증 | 네트워크·캐시 제약 |
| Gunicorn 실제 TCP 기동 | 미검증 | 소켓 제약 |
| 브라우저 QA 증거·스크린샷 정합성 | 통과 | 로컬 성공, route.fulfill 범위 |
| Compose·Nginx 템플릿 구문 | 통과 | 로컬 성공 |
| production 모드의 컨테이너 전달 | 통과 | 로컬 성공, Compose 병합·회귀 테스트 |
| Docker 이미지·비루트·health | 미검증 | Docker 소켓 제약 |
| 공개 경로·비밀 표식 검사 | 통과 | 로컬 성공 |
| 외부 운영·GitHub 변경 | 미수행 | 승인 게이트 대기 |
| 독립 대체 Git 저장소·로컬 커밋 | 통과 | `.git-local`, main, `7a2f882` |

## 14. 남은 환경 재검증과 후속 작업

1. 네트워크 가능한 환경에서 `uv.lock`을 생성하고 `uv sync --frozen --dev`로 새 Python 환경 설치를 확인한다.
2. Docker 권한이 있는 격리 환경에서 이미지 빌드, UID 10001, `/healthz`, `healthy`, 정상 종료를 확인한다.
3. TCP 권한이 있는 환경에서 Gunicorn과 핵심 HTTP 경로를 확인한다.

Node 잠금과 운영 실행 모드의 실제 저장소 차단 문제는 해결됐다. 현재 환경에서 실행 가능한 앱·빌드·검수·로컬 커밋 기준은 통과했으며, uv 네트워크·TCP·Docker 제약만 정확한 재실행 명령을 가진 환경 대기 항목이다.
