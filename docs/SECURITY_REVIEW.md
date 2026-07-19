# 보안 검토 보고서

최종 갱신: 2026-07-18
범위: Flask 애플리케이션, Jinja 템플릿, 공개 콘텐츠 JSON, 정적 JavaScript, 배포 예제의 읽기 전용 검토
판정: **최종 통과 — 초기 2건 해결, 외부 환경 검증은 별도**

## 요약

현재 앱은 읽기 전용 공개 페이지이며 인증, 데이터베이스, 파일 업로드, 상태 변경 API가 없다. CSP를 포함한 필수 헤더가 모든 정상·오류 응답에 적용되고, Jinja 자동 이스케이프와 외부 링크의 `noopener noreferrer`가 확인됐다. 공개 데이터는 네 개의 승인된 설명만 포함하고 외부 프로젝트 URL과 민감 필드를 제거했다.

초기 검수에서 발견한 외부 프로필 URL 검증 부재와 알려진 production 기본 비밀값 문제는 수정 루프에서 해결됐다. 무효 URL은 링크에서 제거되고 production은 안전하지 않은 비밀값으로 시작하지 않는다. 현재 로컬 앱 범위에서 알려진 미해결 보안 결함은 없다.

## 발견 사항

### SEC-01 — 중간 — 해결됨 — 외부 프로필 URL 스킴 검증 부재

**영향**
`PORTFOLIO_GITHUB_URL`은 신뢰된 운영 설정이라는 전제만 있고, 애플리케이션에서 HTTPS·호스트·자격 증명 포함 여부를 검증하지 않는다. 값이 잘못 주입되면 방문자에게 `javascript:` 링크, 프로토콜 상대 외부 링크, 평문 HTTP 링크를 제공할 수 있다. CSP의 `default-src`는 사용자가 클릭하는 최상위 링크 이동을 막는 대책이 아니다.

**재현**

1. `create_app({"GITHUB_PROFILE_URL": "javascript:alert(document.domain)"})`로 앱을 만든다.
2. `/about`을 요청한다.
3. 응답에 해당 값이 `href`로 그대로 존재함을 확인한다.

검수에서는 `javascript:`, `//evil.example/path`, `http://github.com/...`가 모두 링크로 렌더링되는 것을 확인했다. Jinja가 HTML 특수문자를 이스케이프하는 것과 URL 스킴 안전성은 별개다.

**수정·재검증**

- `urllib.parse.urlsplit`로 절대 HTTPS, 유효 호스트, URL 내 자격 증명 부재를 검사한다.
- `javascript:`, 프로토콜 상대, HTTP, 자격 증명 포함 HTTPS, 호스트 없는 HTTPS 입력은 모두 링크에서 제거됐다.
- 유효한 `https://github.com/memilmuk82`는 렌더링되고 `noopener noreferrer`가 유지됐다.
- 현재 값은 운영자만 설정하는 프로필 URL이므로 임의 HTTPS 호스트 자체는 허용하되, 실행 가능한 스킴·평문 전송·URL 자격 증명을 차단하는 경계를 적용했다.

### SEC-02 — 낮음 — 해결됨 — production의 알려진 기본 `SECRET_KEY`

`SECRET_KEY` 기본값은 `local-not-a-secret`이며 실행 모드에 따른 강제 검증이 없다. 현재 앱은 세션·CSRF·서명 토큰을 사용하지 않아 즉각적인 공격 경로는 없지만, 추후 세션 기능을 추가하거나 오류로 운영 환경 변수를 누락하면 알려진 키가 사용된다.

**수정·재검증**
실행 모드의 기본값을 `local`로 정규화하고, `production`에서 비어 있거나 `local-not-a-secret`, `change-me`인 키는 `RuntimeError`로 시작을 거부한다. local/testing 동작은 유지되고 해당 음성 테스트가 통과했다.

## 보안 통제 검증

| 항목 | 결과 | 근거 |
| --- | --- | --- |
| Content-Security-Policy | 통과 | `default-src 'self'`, `base-uri 'self'`, `form-action 'self'`, `frame-ancestors 'none'`, `object-src 'none'`, inline script/style 불허 |
| MIME 스니핑 방지 | 통과 | `X-Content-Type-Options: nosniff` |
| 프레이밍 제한 | 통과 | CSP `frame-ancestors 'none'`와 `X-Frame-Options: DENY` |
| Referrer 정책 | 통과 | `strict-origin-when-cross-origin` |
| Permissions Policy | 통과 | camera, geolocation, microphone, payment, usb 비활성화 |
| 오류·헬스 응답 헤더 | 통과 | `/healthz`, 404 및 테스트 500에도 동일 after-request 헤더 적용 |
| 쿼리 XSS | 통과 | `<script>alert(1)</script>` 검색값은 원문 태그 없이 `&lt;script&gt;...`로 출력 |
| inline script | 통과 | 외부 동일 출처 `site.js` 한 개만 사용 |
| 외부 링크 검증·rel | 통과 | 절대 HTTPS·호스트·자격 증명 부재 검증, 새 탭에 `noopener noreferrer` 적용 |
| 외부 자산·CDN | 통과 | CSS·JavaScript 모두 동일 출처, 외부 폰트 요청 없음 |
| 공개 콘텐츠 스키마 | 통과 | 공개=true 강제, 검토 불리언 타입 강제, 내부 필드와 `links` 거부 |
| 민감 프로젝트 제외 | 통과 | 승인된 네 설명만 포함, 보류 대상 미포함 |
| 로컬 경로·비밀 표식 | 통과(범위 제한) | `app/` 사용자 화면과 공개 JSON에서 발견되지 않음 |
| 실제 비밀 파일 | 통과 | 프로젝트 범위에 `.env`, 개인키, PEM 파일 없음; `.env.example`은 이름과 빈 값만 포함 |
| 상태 변경·CSRF | 해당 없음 | 공개 GET 라우트만 존재 |
| SQL/ORM | 해당 없음 | MVP 데이터베이스 없음, 정적 JSON만 읽음 |

## 헤더 실제 값

```text
Content-Security-Policy: default-src 'self'; base-uri 'self'; connect-src 'self'; font-src 'self'; form-action 'self'; frame-ancestors 'none'; img-src 'self' data:; object-src 'none'; script-src 'self'; style-src 'self'
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: camera=(), geolocation=(), microphone=(), payment=(), usb=()
```

## 콘텐츠·링크 검토

- `projects.json`의 검토 불리언은 모두 명시적 `false`이며 검증하지 않은 사실을 참으로 만들지 않았다.
- 상세 페이지는 설명 메타데이터만 공개하고 원본·데모 링크와 자산을 보류한다고 안내한다.
- 외부 GitHub 프로필은 환경 변수로만 선택적으로 노출된다. 현재 데이터 파일에는 URL이 없다.
- 외부 링크가 없는 상태에서도 모든 프로젝트 상세와 탐색이 완전하게 동작한다.
- 테스트의 금지 문자열 목록과 배포 문서의 루프백 주소는 감사·운영 설명이며 사용자 화면에는 노출되지 않는다.

## 배포 경계

- HSTS와 인증서 정책은 Flask가 아니라 승인된 HTTPS 리버스 프록시 단계에서 적용·검증해야 한다.
- 이 local 검수에서는 `/etc/nginx`, 인증서, DNS, Cloudflare, 방화벽, 운영 컨테이너를 변경하지 않았다.
- TCP 소켓이 샌드박스에서 차단돼 실제 Gunicorn/Nginx 헤더 병합과 외부 TLS는 검증하지 못했다.
- `www.memilmuk82.com` 대상 Nginx 예제는 루프백 업스트림을 사용하지만, 운영 적용 전 `nginx -t`, 인증서 호스트명, 기존 사이트 충돌, HTTP→HTTPS 동작을 별도 확인해야 한다.

## 검사 제약

- 전용 Git 이력 비밀 탐지 도구는 새 독립 Git 저장소 초기화 전이라 수행하지 않았다.
- 참고 저장소와 원본 분류 자료는 읽기 전용으로만 사용했다.
- 네트워크가 차단돼 외부 GitHub 프로필의 소유권·응답·리디렉션은 확인하지 않았다.
- 실제 사용자 데이터, 운영 DB, 데모 계정은 범위에 없고 접근하지 않았다.

## 재검증 결과

1. 유효 HTTPS 프로필 렌더링과 다섯 무효 URL 비노출 테스트가 통과했다.
2. production의 알려진 기본 키 fail-fast 테스트가 통과했다.
3. `pytest` 30개, Ruff lint, Ruff format 검사가 모두 통과했다.
4. 원격 게시 전에는 커밋 대상만으로 비밀 탐지와 Git 이력 검사를 수행해야 한다.
