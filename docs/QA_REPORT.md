# 웹앱 독립 검수 보고서

## 2026-07-19 현재 56개 인벤토리 통합 검수

- 프로젝트 화면은 독립 저장소 56개를 서브도메인 9·정적 7·소스 소개 28·비공개·제외 12로 표시한다. `noom`은 무DB 웹앱이며 `curriculum-subject-overlap-check`와 나머지 비공개·제외 항목은 외부 링크가 없다.
- 활동 화면은 2020—2021 프로그래밍과 웹의 기초, 2022—2023 서버·API·데이터로 확장, 2024—2025 서비스와 에듀테크, 2026 AI 활용에서 설계·검증으로의 네 시기를 표시한다.
- JSON 파싱, Ruff 검사·포맷 검사, pytest 35개와 Tailwind 빌드가 통과했다. 서버 GET 필터는 JavaScript 없이 동작하며, 부분 필터 응답에서는 적용 버튼을 유지해 전체 56개로 다시 이동할 수 있다.
- Chromium은 샌드박스 호스트 권한으로 기동하지 못했다. Flask `test_client` 응답을 Playwright Firefox 1532의 `route.fulfill`로 전달해 1440×1100·390×844·360×800에서 렌더링했고 모든 검사 폭의 가로 오버플로가 0px였다. 부분 서버 필터에서 전체 선택 후 56행으로 복귀하는 상호작용도 확인했다.
- `docs/screenshots`의 홈·프로젝트·상세·활동·소개, 프로젝트 목록·빈 결과·모바일 메뉴·360px 캡처를 현재 소스로 다시 생성했다.

## 최초 네 개 상세 사례 구현 검수 (역사 기록)

> 이 지점부터 문서 끝까지의 네 항목·검색/주제/상태 필터·pytest 30개 기록은 최초 구현 당시의 증거이며 현재 56개 인벤토리 계약을 설명하지 않는다.

당시 갱신: 2026-07-18
역할: 웹앱 검수 에이전트
당시 상태: **최종 통과 — 환경 제약은 별도 기록**

## 결론

수정 루프 2~3 뒤 동일한 브라우저 흐름을 다시 실행했다. 필수 페이지의 서버 렌더링, 프로젝트 필터, 핵심 링크, 모바일 재배치, 오류 페이지, 보안 헤더가 동작했다. 1440×1100, 390×844, 추가 360×800에서 가로 오버플로와 앱 콘솔 오류는 발견되지 않았다. 초기의 푸터 중복 텍스트, 모바일 포커스 이탈, 파비콘 404, 포맷 실패는 모두 해결되어 로컬 브라우저 검수 범위를 최종 통과로 판정한다.

검수 흐름은 `앱 로드 → 핵심 페이지 렌더링 → 메뉴·필터·키보드 조작 → URL·포커스·결과 상태 확인`이었다.

## 환경과 브라우저 경로

- 실행 모드: `local`
- 의도한 로컬 호스트: `127.0.0.1:8055`
- 뷰포트: 데스크톱 1440×1100, 모바일 390×844, 보조 모바일 360×800
- Browser 플러그인 분류: **없음** — `Browser plugin not available`
- 대체 도구: 참고 프로젝트에 이미 설치된 Playwright 1.61.1을 읽기 전용으로 재사용
- Chromium: 프로세스 샌드박스 제한으로 기동 실패
- Firefox 1532: 기동 성공
- Flask TCP 기동: 소켓 생성이 `PermissionError: [Errno 1] Operation not permitted`로 차단됨
- 브라우저 검수 방식: Flask 3.1.3 `test_client`가 생성한 실제 응답과 헤더를 Playwright `route.fulfill`로 `http://portfolio.local`에 전달해 Firefox에서 HTML/CSS/JavaScript를 렌더링하고 상호작용함

따라서 DOM, CSS, JavaScript, 키보드, 반응형, 스크린샷 검수는 실제 브라우저에서 수행했지만, TCP·Gunicorn·리버스 프록시·실제 네트워크 타이밍은 이 검수의 통과 범위가 아니다.

## 초기 발견 사항과 해결 상태

### QA-01 — 중간 — 해결됨 — 푸터 아래 현재 페이지명 중복

**사용자 영향**
모든 데스크톱·모바일 페이지에서 짙은 푸터가 끝난 뒤 흰 배경에 `홈`, `프로젝트`, `활동`, `소개` 같은 텍스트가 한 번 더 보인다. 완성된 페이지가 깨진 것처럼 보이며 문서 구조에도 불필요한 텍스트 노드가 생긴다.

**재현**

1. `/`, `/projects`, 대표 상세, `/activity`, `/about` 중 하나를 연다.
2. 페이지 맨 아래까지 스크롤한다.
3. 푸터 다음에 현재 페이지명이 표시되는지 확인한다.

**증거**

- 다섯 데스크톱 및 다섯 모바일 페이지 모두 `footer.nextSibling` 텍스트가 현재 페이지명이었다.
- `desktop-home.png`, `desktop-projects.png`, `mobile-home.png`, `mobile-activity.png` 아래쪽에서 육안으로 확인했다.
- 원인은 [base.html](../app/templates/base.html)의 `page_name` 블록 기본 선언이 `</html>` 뒤에 있어 자식 블록 값이 출력되는 구조로 보인다.

**수정·재검증**
`page_name` 블록의 문서 끝 출력을 제거했다. 다섯 데스크톱·다섯 모바일 페이지에서 `footer.nextSibling`의 가시 텍스트가 모두 빈 배열이고, 최종 스크린샷에서도 푸터 뒤 중복 문구가 사라졌다.

### QA-02 — 중간 — 해결됨 — 모바일 메뉴 포커스의 배경 이탈

**사용자 영향**
오버레이 메뉴가 열린 상태에서 키보드 사용자가 마지막 메뉴 링크 다음으로 이동하면 보이지 않는 배경 본문의 `프로젝트 보기` 링크에 포커스가 간다. 현재 화면과 포커스 위치가 어긋나 탐색이 혼란스럽다.

**재현**

1. 390×844에서 `/`를 연다.
2. 메뉴 토글을 눌러 메뉴를 연다.
3. `소개` 링크에 포커스를 둔 뒤 `Tab`을 누른다.
4. 포커스가 메뉴 밖 배경의 `프로젝트 보기`로 이동한다.

**증거**

- 열린 직후: `aria-expanded="true"`, 첫 링크 `홈` 포커스, `body` 오버플로 잠금은 정상.
- 마지막 링크 다음: 활성 요소가 `href="/projects"`, 텍스트 `프로젝트 보기`, `insideMenu=false`.
- `Escape` 후 메뉴 닫힘과 토글 포커스 복귀는 정상.

**수정·재검증**
토글과 네 메뉴 링크를 하나의 포커스 순환 범위로 처리했다. 첫 링크에서 `Shift+Tab`은 토글로, 토글에서 `Shift+Tab`은 마지막 `소개` 링크로, 마지막 링크에서 `Tab`은 토글로 이동했다. `Escape` 뒤 메뉴 닫힘과 토글 포커스 복귀도 유지됐다. 배경 본문으로 포커스가 빠지지 않는다.

### QA-03 — 낮음 — 해결됨 — 파비콘 요청 404

자체 `favicon.svg`와 `/favicon.ico` 호환 라우트를 추가했다. 브라우저 리소스 목록에는 동일 출처 SVG가 정상 로드되고, 직접 요청은 200 `image/svg+xml`을 반환한다.

### QA-04 — 낮음 — 해결됨 — 포맷 검사 실패

해당 파일을 포맷했다. 재검증에서 `ruff check .`은 통과했고 `ruff format --check .`은 `12 files already formatted`로 통과했다.

## 필수 브라우저 체크

| 항목 | 결과 | 증거 |
| --- | --- | --- |
| 페이지 identity | 통과 | 다섯 핵심 경로의 URL·제목이 기대값과 일치 |
| 빈 화면 여부 | 통과 | 페이지별 본문 텍스트 381~917자, 의미 있는 콘텐츠 렌더링 |
| 프레임워크 오류 오버레이 | 통과 | 가시 오버레이 0개 |
| 콘솔 상태 | 통과(제약 있음) | 앱 오류·경고 0개. Playwright Firefox 내부 Juggler의 강제 레이아웃 경고 1건만 발생 |
| 스크린샷 | 통과 | `docs/screenshots/`의 데스크톱·모바일·메뉴·필터 캡처 13개 |
| 상호작용 증거 | 통과 | 필터·Escape·스킵 링크·양방향 포커스 순환 통과 |

## 기능·접근성·반응형 결과

| 검사항목 | 결과 | 관찰 |
| --- | --- | --- |
| `/`, `/projects`, 대표 상세, `/activity`, `/about` | 통과 | 모두 200, H1 1개, header/main/footer 존재 |
| `/healthz` | 통과 | 200, 본문 `ok\n`, 외부 의존성 없음 |
| 404/500 | 통과 | pytest로 사용자 친화적 템플릿과 상태 코드 확인 |
| 검색 필터 | 통과 | `SQLite` → 1개, 생성형 AI 계정 운영 도구 |
| 주제 필터 | 통과 | `프론트엔드` → 1개, AI 수업 설계 웹 프레젠테이션 |
| 상태 필터 | 통과 | `구현·검증` → 2개 |
| 빈 결과 | 통과 | 0개와 안내 문구 표시, URL 쿼리 동기화 |
| 서버 기반 필터 | 통과 | JavaScript 비활성화 후 검색+주제 폼 제출 → 1개 |
| JavaScript 없는 핵심 링크 | 통과 | 390px에서도 상시 탐색이 보이고 실제 href로 이동 가능 |
| 모바일 메뉴 | 통과 | 열기·첫 링크 포커스·Tab/Shift+Tab 순환·Escape·토글 복귀·스크롤 잠금 정상 |
| 스킵 링크 | 통과 | 첫 Tab에 가시적 3px 포커스, Enter 후 `main#main-content` 포커스 |
| 외부 링크 rel | 통과 | 유효한 HTTPS GitHub 설정에서 `noopener noreferrer` 확인 |
| reduced motion | 통과 | 미디어 쿼리 일치, smooth scroll 제거, 전환 0.00001초 |
| 터치 대상 | 통과 | 메뉴 46×46px, 주요 버튼 350×62px |
| 가로 오버플로 | 통과 | 1440, 390, 360에서 0px |
| 이미지 대체 텍스트 | 해당 없음 | 배포 화면에 `<img>` 없음; 장식 SVG는 `aria-hidden` |

## 콘텐츠 사실성

- 공개 JSON의 네 항목은 `docs/REPOSITORY_VERIFICATION.md`가 허용한 네 후보와 일치한다.
- 보류 항목은 화면과 공개 JSON에서 제외돼 있다.
- 입시 상담 보조 시스템은 FastAPI가 아니라 Flask로 표기돼 있다.
- 60장·100분, 3장 시험 제작·60장 Slides 등 숫자는 검증 문서 범위와 일치한다.
- 외부 성과율, 사용자 수, 고객명, 경력 연도, 임의 타임라인은 만들지 않았다.
- 활동 다섯 축은 `docs/ACTIVITY_SOURCES.md`와 일치한다.
- 외부 프로젝트 링크와 원본 자산은 권리·공유 검토 전이라 노출하지 않는 설명과 실제 데이터가 일치한다.

## 성능 관찰

- 페이지당 DOM 요소 수는 84~144개로 작다.
- CSS와 JavaScript는 동일 출처 정적 파일 각 1개이며 외부 CDN 요청은 없다.
- 데스크톱·모바일에서 레이아웃 오버플로와 오류 오버레이는 없다.
- 자체 SVG 파비콘이 200으로 로드돼 반복 실패 요청이 사라졌다.
- `route.fulfill` 경로이므로 LCP, 실제 네트워크 지연, 압축, Gunicorn 처리량 수치는 신뢰할 수 없어 측정 완료로 주장하지 않는다.

## 콘셉트 대조

`view_image`로 모든 데스크톱 콘셉트와 실제 캡처, 모바일 핵심 콘셉트와 실제 모바일 캡처를 대조했다.

1. 따뜻한 종이색, 짙은 잉크, 코발트, 제한적 시트론 팔레트가 일치한다.
2. 카드 격자 대신 열린 프로젝트 행, 얇은 구분선, 넓은 여백, 짙은 푸터를 사용해 편집형 계층을 보존했다.
3. 홈의 큰 제목·두 CTA·3단계 블루프린트·전체 폭 코발트 밴드 순서가 콘셉트와 일치한다.
4. 상세 페이지의 2열 설명과 오른쪽 판단 레일, 활동 페이지의 교차 레일, 소개의 3열 하단 구조가 핵심 정보 계층을 보존한다.
5. 모바일은 단일 열 재배치, 20px 여백, 전체 폭 CTA, 열린 프로젝트 행, 왼쪽 활동 레일과 전체 화면 메뉴를 구현했다.
6. 차이: 실제 홈 영웅은 콘셉트보다 세로 여백과 제목 줄바꿈이 크고, 판단 레일 아이콘은 콘셉트 SVG보다 단순 문자 기호다.
7. 차이: 모바일 프로젝트 콘셉트의 접이식 필터 대신 항상 보이는 두 `select`를 사용한다. 서버 폼의 점진적 향상을 우선한 의도적 차이로 기능은 정상이다.
8. 수정 전 캡처에서 보였던 푸터 아래 페이지명은 최종 캡처에서 제거되어 콘셉트의 문서 종료 구조와 일치한다.

## 실행 명령과 결과

```text
PYTHONPATH=. "$VERIFICATION_VENV/bin/pytest" -q
→ 30 passed

PYTHONPATH=. "$VERIFICATION_VENV/bin/ruff" check .
→ 통과

"$VERIFICATION_VENV/bin/ruff" format --check .
→ 통과: 12 files already formatted

PORTFOLIO_GITHUB_URL=... PYTHONPATH=... flask --app 'app:create_app()' run --host 127.0.0.1 --port 8055
→ 실패: PermissionError: [Errno 1] Operation not permitted

node /tmp/portfolio_qa.cjs
→ Playwright Firefox 렌더링·상호작용·스크린샷 성공
```

프로젝트 자체 `.venv`에는 의존성이 설치되지 않은 상태였고 `uv sync --offline --dev`는 Gunicorn 23.0.0 캐시 부재로 해결되지 않았다. 검수는 동일 Python 3.12·Flask 3.1.3 환경을 읽기 전용으로 재사용했다. 이 제약은 새 환경 설치 검증을 대체하지 않는다.

## 스크린샷

- `docs/screenshots/desktop-home.png`
- `docs/screenshots/desktop-projects.png`
- `docs/screenshots/desktop-project-detail.png`
- `docs/screenshots/desktop-activity.png`
- `docs/screenshots/desktop-about.png`
- `docs/screenshots/desktop-projects-empty-filter.png`
- `docs/screenshots/mobile-home.png`
- `docs/screenshots/mobile-projects.png`
- `docs/screenshots/mobile-project-detail.png`
- `docs/screenshots/mobile-activity.png`
- `docs/screenshots/mobile-about.png`
- `docs/screenshots/mobile-menu-open.png`
- `docs/screenshots/mobile-360-projects.png`

## 남은 환경 제약

- QA-01~04는 동일 브라우저·정적 검사 흐름으로 해결을 확인했다. 알려진 미해결 앱 결함은 없다.
- 실제 TCP 서버, Gunicorn 신호 처리, Chrome/Safari, 리버스 프록시, 외부 네트워크 성능은 미검증이다.
- HTTP 소켓 권한이 있는 환경의 재실행 예:

```bash
uv sync --dev
npm ci
npm run css:build
uv run pytest
uv run flask --app 'app:create_app()' run --host 127.0.0.1 --port 8000
```
