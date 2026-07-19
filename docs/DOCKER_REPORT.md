# Docker 빌드 검증 보고서

검증일: 2026-07-18 (Asia/Seoul)
대상 이미지: `memilmuk82-portfolio:local`
판정: **Compose 정적 검증과 Tailwind 빌드 통과 / 컨테이너용 Python 잠금 파일 작성 / Docker 이미지 빌드 미실행(소켓 권한)**

## 1. 작성한 컨테이너 구성

### Dockerfile

- `node:22-alpine` 자산 단계에서 `npm ci`와 Tailwind 프로덕션 빌드를 수행한다.
- 별도 Python 의존성 단계는 `python:3.12-slim-bookworm`에서 독립 `/build/.venv`를 만들고 `requirements.lock`의 정확한 핀만 설치한다.
- 최종 런타임은 Python slim 이미지이며 Node, npm, uv, pip 다운로드 캐시를 포함하지 않는다.
- UID/GID 10001의 셸·홈 없는 `portfolio` 사용자로 실행한다.
- Gunicorn을 exec-form `CMD`로 직접 실행하고 `0.0.0.0:8000`에 바인딩한다.
- `EXPOSE 8000`과 Python 표준 라이브러리 기반 `/healthz` 이미지 헬스체크를 포함한다.
- 정적 CSS는 Tailwind 단계에서만 만들고 최종 앱 소스에 복사한다.

### Compose

- 호스트 공개 범위는 `127.0.0.1:8000:8000`으로 제한한다.
- `PORTFOLIO_SECRET_KEY`는 환경 변수로 반드시 제공해야 하며 저장소 기본값을 두지 않는다.
- 읽기 전용 루트 파일시스템, `/tmp` tmpfs, 전체 capability 제거, `no-new-privileges`, PID 제한과 init 프로세스를 적용한다.
- 기존 컨테이너 이름을 고정하지 않았고 운영 서비스, 네트워크 또는 volume을 참조하지 않는다.

### 빌드 컨텍스트

`.dockerignore`는 Git 메타데이터, 실제 환경 파일, 가상환경, Node 의존성, 캐시, 인스턴스 데이터베이스, coverage, 로그, 테스트·배포·설계 문서와 로컬 생성 CSS를 제외한다. `.env.example`은 빈 변수 이름 문서로 유지한다. `requirements.lock`은 명시적인 negation 규칙으로 빌드 컨텍스트에 포함한다.

## 2. 실제 실행 결과

### Compose 정적 구성

실행:

```bash
PORTFOLIO_SECRET_KEY=compose-config-validation docker compose config -q
PORTFOLIO_SECRET_KEY=compose-config-validation docker compose config --images
PORTFOLIO_SECRET_KEY=compose-config-validation docker compose config --services
```

결과: 통과. 이미지 이름은 `memilmuk82-portfolio:local`, 서비스 이름은 `web`으로 해석됐다. 검증용 값은 실제 비밀이 아니며 파일에 저장하지 않았다.

### Tailwind 프로덕션 CSS

`package-lock.json`의 macOS 선택 의존성 `fsevents` 메타데이터를 현재 npm lock 형식과 맞춘 뒤, 새 프로젝트 루트에서 다음 명령을 실제 실행했다.

```bash
npm ci --offline --ignore-scripts --no-audit --no-fund
npm run css:build
```

결과: npm이 잠금 파일 그대로 74개 패키지를 설치했고, Tailwind 3.4.17 프로덕션 빌드가 통과해 minified `app/static/css/site.css`를 생성했다. `caniuse-lite` 갱신 안내는 있었지만 빌드 실패는 없었다.

Docker assets 단계와 같은 옵션의 재실행 명령:

```bash
npm ci --ignore-scripts --no-audit --no-fund
npm run css:build
```

### Node 잠금 파일

초기 캐시가 준비되기 전의 오프라인 설치는 `ENOTCACHED`로 실패했다. 이후 프로젝트 전용 `package-lock.json`을 완성하고 선택 의존성 메타데이터를 교정했으며, 최종 오프라인 `npm ci`가 실제 설치까지 통과했다.

```bash
npm ci --offline --ignore-scripts --no-audit --no-fund
```

- lockfile version: 3
- 루트 개발 의존성: `tailwindcss` 3.4.17
- 잠긴 `packages` 항목: 루트 포함 76개
- 실제 설치: 74개 패키지
- `fsevents` 2.3.3: `darwin` 전용 optional 의존성으로 기록되어 Linux 설치 대상에서 제외
- `--no-audit`로 실행했으므로 이 명령 결과를 취약점 검사 통과로 표현하지 않음

### Python 잠금 파일

첫 실행:

```bash
uv lock --offline
```

실패:

```text
Could not acquire lock
Could not create temporary file
Read-only file system ... at the default uv cache
```

쓰기 가능한 임시 캐시로 재시도:

```bash
UV_CACHE_DIR=/tmp/memilmuk82-portfolio-uv-cache uv lock --offline
```

실패:

```text
No solution found when resolving dependencies
flask was not found in the cache
```

원인은 네트워크 비활성 상태에서 Flask 3.1.3 메타데이터가 지정 캐시에 없기 때문이다. 개발 환경용 `uv.lock`은 추측하거나 다른 프로젝트에서 복사하지 않았다.

네트워크 허용 환경의 정확한 재실행 명령:

```bash
UV_CACHE_DIR=/tmp/memilmuk82-portfolio-uv-cache uv lock
uv lock --check
```

Docker 빌드가 존재하지 않는 `uv.lock`에 종속되지 않도록 컨테이너 전용 `requirements.lock`을 별도로 작성했다. `pyproject.toml`의 직접 의존성과 Flask/Gunicorn의 Linux 런타임 전이를 현재 잠금 메타데이터와 대조해 다음을 모두 정확히 고정했다.

```text
blinker==1.9.0
click==8.4.2
Flask==3.1.3
gunicorn==23.0.0
itsdangerous==2.2.0
Jinja2==3.1.6
MarkupSafe==3.0.3
packaging==26.2
Werkzeug==3.1.8
```

Dockerfile의 dependencies 단계는 시스템 Python에 설치하지 않고 `/build/.venv`를 만든 뒤 이 파일만 설치한다. 런타임 단계에는 완성된 가상환경만 복사한다. `uv.lock` 미생성은 개발 환경의 잠금 검증 제약으로 계속 기록하지만 더 이상 Dockerfile의 선행 파일 오류는 아니다.

### Docker 이미지 빌드

실행:

```bash
docker build --tag memilmuk82-portfolio:local .
```

실패:

```text
permission denied while trying to connect to the docker API at unix:///var/run/docker.sock
```

Docker 클라이언트 29.6.1은 설치되어 있으나 현재 사용자에게 Docker 소켓 접근 권한이 없다. `uv.lock` 참조를 제거하고 `requirements.lock`으로 수정한 뒤에도 같은 명령을 재실행했으며 동일한 소켓 오류로 Dockerfile 단계 실행 전 차단됐다. 따라서 이미지 생성, Python 잠금 설치, 레이어 검사, 런타임 UID와 컨테이너 헬스체크는 실제로 검증되지 않았다. 기존 이미지나 컨테이너는 조회·중지·교체하지 않았다.

## 3. 권한 있는 환경의 재검증 절차

먼저 컨테이너 잠금 파일과 Docker 데몬 접근을 확인한다. `requirements.lock`은 이미 존재하며 Docker 빌드에 사용된다.

```bash
test -s requirements.lock
docker info
```

개발 환경용 `uv.lock`도 생성할 수 있는 네트워크 환경이라면 별도로 다음을 실행한다. 이는 Docker 빌드의 선행 조건은 아니다.

```bash
UV_CACHE_DIR=/tmp/memilmuk82-portfolio-uv-cache uv lock
uv lock --check
```

그 다음 이 프로젝트 이미지만 빌드한다.

```bash
docker build --tag memilmuk82-portfolio:local .
docker image inspect memilmuk82-portfolio:local \
  --format '{{json .Config.User}} {{json .Config.ExposedPorts}} {{json .Config.Healthcheck}}'
```

예상 사용자는 `portfolio:portfolio`, 노출 포트는 `8000/tcp`이며 Healthcheck가 존재해야 한다.

격리된 로컬 Compose 검증:

```bash
export PORTFOLIO_SECRET_KEY='로컬에서만 사용할 충분히 긴 임시값'
docker compose up --build --detach
docker compose exec -T web id -u
curl --fail --silent --show-error http://127.0.0.1:8000/healthz
docker compose ps
docker compose logs --no-color --tail=100 web
docker compose down
unset PORTFOLIO_SECRET_KEY
```

- `id -u`는 `10001`이어야 한다.
- `/healthz`는 외부 의존성 없이 200이어야 한다.
- `docker compose ps`에서 health가 `healthy`가 되어야 한다.
- 실패하더라도 이 프로젝트 Compose만 `down`하고 다른 컨테이너나 volume은 건드리지 않는다.
- 이 구성은 named volume을 만들지 않으므로 `down --volumes`가 필요하지 않다.

## 4. 미검증 항목

- 베이스 이미지 다운로드와 다중 아키텍처 매니페스트 해석
- Tailwind `npm ci` 단계의 컨테이너 내부 실행
- `requirements.lock`을 설치하는 Python 의존성 레이어
- 런타임이 실제로 UID 10001로 시작하는지
- Gunicorn 신호 처리와 정상 종료
- 이미지 Healthcheck의 `healthy` 전환
- 읽기 전용 파일시스템에서 모든 핵심 경로가 동작하는지
- 최종 이미지 크기와 취약점 스캔

위 항목은 Docker 소켓과 네트워크가 허용되는 환경에서 실제 명령 결과가 생기기 전까지 성공으로 표시하지 않는다.
