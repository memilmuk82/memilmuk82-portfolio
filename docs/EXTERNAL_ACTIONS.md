# 외부 변경 실행 기록

기록일: 2026-07-18 (Asia/Seoul)
실행 모드: `production`
판정: **www.memilmuk82.com Cloudflare 프록시 연결 완료**

## 수행하지 않은 작업

| 영역 | 상태 | 이유·다음 게이트 |
|---|---|---|
| Cloudflare DNS 레코드 조회·변경 | 사용자 수행·공개 검증 | `www`가 Cloudflare IPv4·IPv6 Anycast 주소를 반환 |
| Cloudflare proxy 활성화 | 사용자 수행·공개 검증 | `server: cloudflare`, `cf-ray`, HTTP/2 응답 확인 |
| Cloudflare SSL/TLS 모드 변경 | 사용자 수행·경로 검증 | Full (strict) 설정 완료 통보 및 Cloudflare→원본 HTTPS 정상 응답 확인 |
| Cloudflare API token 생성·검증 | 미수행 | 토큰을 요청하거나 인증하지 않음 |
| `/etc/nginx` 조회·백업·설치·reload | 수행 | 기존 `www` 설정 부재 확인 후 HTTP-01 bootstrap 설치, `nginx -t` 통과 후 reload |
| Certbot 발급·설치·갱신 시험 | 수행 | ECDSA 인증서 발급 및 `renew --dry-run` 성공 |
| 인증서·개인 키 생성 또는 변경 | 수행 | `/etc/letsencrypt/live/www.memilmuk82.com`, 만료 2026-10-16 |
| 방화벽 조회·변경 | 조회만 수행 | INPUT에서 80/443 허용 확인, 규칙 변경 없음 |
| 운영 Compose 실행 | 수행 | `memilmuk82-portfolio-web-1`을 `127.0.0.1:8001`에 기동하고 healthy 확인 |
| 기존 컨테이너 중지·교체 | 미수행 | 기존 8000 서비스와 다른 컨테이너는 유지 |
| 루트 도메인 변경 | 미수행 | 명시적 승인 없는 추론 변경 금지 |

## 2026-07-18 23:41 KST 실행 결과

- 원본 공인 IPv4 `129.154.58.94`와 Cloudflare 네임서버를 확인했다.
- `www.memilmuk82.com`에는 현재 공개 A·AAAA·CNAME 레코드가 없음을 확인했다.
- 포트폴리오 운영 컨테이너를 기존 8000 서비스와 분리해 `127.0.0.1:8001`에 기동했다.
- 컨테이너 내장 헬스체크와 `/healthz` 응답이 정상임을 확인했다.
- `/etc/nginx/sites-available/memilmuk82-portfolio`와 활성 symlink를 새로 설치했다.
- HTTP-01 webroot는 `/var/www/certbot`이며, `www` Host 요청이 bootstrap의 의도된 503 응답을 반환함을 확인했다.
- DNS 전파 후 `www.memilmuk82.com` ECDSA 인증서를 발급하고 HTTPS reverse proxy를 적용했다.
- 기존 bootstrap 설정은 `/var/backups/memilmuk82-portfolio.nginx.20260718T234525+0900`에 보관했다.
- 공개 HTTP→HTTPS 301, HTTPS `/healthz` 응답, 인증서 SAN·발급자·유효기간을 확인했다.
- `certbot renew --dry-run --no-random-sleep-on-renew --cert-name www.memilmuk82.com`이 성공했다.
- Cloudflare API token과 zone ID가 없어 dashboard의 Full (strict) 및 proxy 활성화는 수행하지 않았다.

## 2026-07-18 23:55 KST 최종 전환 검증

- `www` DNS가 Cloudflare IPv4 `104.21.80.249`, `172.67.136.85`와 IPv6 Anycast 주소를 반환했다.
- Cloudflare 경유 홈페이지와 `/healthz`가 HTTP/2 200을 반환했다.
- 응답의 `server: cloudflare`, `cf-ray`와 `cf-cache-status` 헤더로 proxy 경유를 확인했다.
- 공개 Cloudflare edge 인증서는 `memilmuk82.com`과 `*.memilmuk82.com` SAN을 포함했다.
- 원본 IP를 직접 지정한 `www` TLS `/healthz`도 정상 응답해 원본 인증서와 reverse proxy가 유지됨을 확인했다.
- `memilmuk82-portfolio-web-1`은 `127.0.0.1:8001`에서 healthy 상태다.

## 이전 로컬 준비 작업

- 공식 Cloudflare Full (strict), API token, Let’s Encrypt integration, Certbot stable 문서를 웹에서 읽기 전용으로 확인했다.
- 운영 환경 변수 예제, Compose overlay, 인증 전/후 Nginx 템플릿과 정적 검증 스크립트를 프로젝트 안에 작성했다.
- `sh -n deployment/validate-templates.sh`로 셸 문법을 확인했다.
- `deployment/validate-templates.sh`로 대상 호스트명, 루트 도메인 부재, 루프백 proxy, 인증서 경로, 비밀 공란과 Compose 병합을 확인했다.
- 로컬 `nginx -v`, `certbot --version`으로 도구 설치 버전만 확인했다. 시스템 설정은 읽거나 변경하지 않았다.

## 외부 실행 전 사용자 제공값

다음 값은 저장소가 아니라 승인된 운영 셸의 환경 변수로 제공해야 한다.

```text
PORTFOLIO_EXECUTION_MODE=production
PORTFOLIO_ALLOW_PRODUCTION_CHANGES=YES
PORTFOLIO_DOMAIN=www.memilmuk82.com
CLOUDFLARE_ZONE_ID=(대상 zone ID)
CLOUDFLARE_API_TOKEN=(필요한 경우 최소 권한 token)
LETSENCRYPT_EMAIL=(인증서 알림 이메일)
```

값이 제공되어도 자동으로 변경 권한이 생기지는 않는다. 공인 IP, 기존 `www` DNS, 포트 접근성, Nginx·컨테이너 충돌, 백업·롤백 경로를 읽기 전용으로 확인하고 구체적인 변경 계획을 승인받아야 한다.

## 아직 확인하지 않은 외부 상태

- Cloudflare dashboard의 정확한 SSL 설정값은 API 자격 증명이 없어 직접 조회하지 않았으며 사용자 완료 통보와 정상 종단 간 HTTPS로 확인했다.
- 루트 도메인의 현재 동작을 확인하거나 변경했다고 주장하지 않는다.

운영 절차와 롤백은 `docs/DEPLOYMENT.md`에 있으며, 실제 실행 결과가 생기면 명령·시각·이전값·새값·롤백 여부를 이 문서에 추가한다.
