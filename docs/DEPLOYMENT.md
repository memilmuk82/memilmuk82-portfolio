# 배포 준비 가이드

작성·정적 검증일: 2026-07-18 (Asia/Seoul)
대상 호스트명: `www.memilmuk82.com`
현재 실행 모드: `local`
현재 상태: 템플릿만 준비했으며 운영 환경은 변경하지 않음

## 1. 운영 구조

```text
사용자
  → Cloudflare 프록시(최종 단계에서만 활성화)
  → 원본 Nginx :443
  → 127.0.0.1:8001
  → 비루트 Gunicorn/Flask 컨테이너
```

애플리케이션 포트는 Compose에서 루프백에만 바인딩한다. Nginx만 원본 애플리케이션에 접근하며 컨테이너에 인증서나 Cloudflare 토큰을 전달하지 않는다.

루트 도메인 `memilmuk82.com`은 이 배포의 대상이 아니다. 현재 DNS·서비스·리디렉션 상태를 읽기 전용으로 확인할 수는 있지만, 별도 승인 없이는 레코드, Nginx `server_name`, 인증서 SAN 또는 리디렉션에 추가하지 않는다.

## 2. 준비된 파일

| 파일 | 목적 |
|---|---|
| `deployment/.env.production.example` | 변수 이름만 있는 운영 환경 예제 |
| `deployment/compose.production.yaml` | 기본 Compose에 restart·로그 제한을 더하는 운영 overlay |
| `deployment/nginx-www-bootstrap.conf.example` | HTTP-01 발급 전 ACME 경로만 제공하는 80번 bootstrap |
| `deployment/nginx-www.conf.example` | 인증서 발급 후 HTTPS reverse proxy와 HTTP→HTTPS 전환 |
| `deployment/validate-templates.sh` | 도메인·루프백·비밀 공란·Compose 병합을 변경 없이 검사 |

실제 운영 환경 파일 `deployment/.env.production`과 `deployment/*.secret`은 Git 제외 대상이다. Cloudflare API 토큰과 인증서 개인 키는 저장소나 Compose 환경에 넣지 않는다.

## 3. 공식 문서에서 확인한 전제

- Cloudflare는 가능한 경우 Full (strict)를 권장하며, 원본은 443을 허용하고 인증서가 유효 기간 내이며 공개 신뢰 CA 또는 Origin CA가 발급했고 요청 호스트명과 일치해야 한다. 이 조건이 없으면 526 오류가 날 수 있다. [Cloudflare Full (strict) 공식 문서](https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/full-strict/)
- Cloudflare API 토큰은 작업에 필요한 permission과 resource만 선택하고 필요하면 IP·TTL 제한을 적용한다. secret은 생성 시 한 번만 보이므로 평문 저장소에 보관하지 않는다. [Cloudflare API token 공식 문서](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/)
- Let’s Encrypt HTTP-01은 인바운드 80이 필요하고 ACME 클라이언트는 아웃바운드 443이 필요하다. DNS-01을 쓰면 오래된 TXT를 정리해야 하며, 인증서·키는 컨테이너 재생성 때마다 재발급하지 않고 지속 저장해야 한다. [Let’s Encrypt Integration Guide](https://letsencrypt.org/docs/integration-guide/)
- Certbot Nginx 사용 전 설정 백업을 권장하며, 향후 갱신은 `certbot renew --dry-run`으로 시험할 수 있다. webroot 방식은 `/.well-known/acme-challenge`가 실제 웹서버에서 제공되어야 한다. [Certbot User Guide](https://eff-certbot.readthedocs.io/en/stable/using.html)

검토한 공식 문서의 최신 표시 버전은 Cloudflare 문서 2026년 갱신본과 Certbot stable 5.7.0이었다. 실제 운영 실행 시에는 위 링크를 다시 확인한다.

## 4. 외부 변경 게이트

다음 조건을 모두 만족하기 전에는 이 문서의 `sudo`, Certbot, Cloudflare API와 운영 Compose 명령을 실행하지 않는다.

1. `PORTFOLIO_EXECUTION_MODE=production`
2. `PORTFOLIO_ALLOW_PRODUCTION_CHANGES=YES`
3. `PORTFOLIO_DOMAIN=www.memilmuk82.com`
4. `CLOUDFLARE_ZONE_ID`와 `LETSENCRYPT_EMAIL`이 정확히 제공됨
5. Cloudflare API가 필요하면 한 zone·필요 동작에만 제한된 `CLOUDFLARE_API_TOKEN`이 환경 변수로 제공됨
6. 현재 호스트가 대상 서버인지, 공인 IP·DNS·80/443 접근성·기존 Nginx 사이트·포트·컨테이너 충돌을 읽기 전용으로 확인함
7. 변경 파일과 이전 DNS/Cloudflare 값, 백업 경로, 롤백 명령, 예상 중단 시간을 작업 기록에 고정함
8. 로컬 테스트, 콘텐츠 검증, Docker 헬스체크가 통과했거나 승인된 예외만 남음

`local`과 `github` 모드에서는 아래 절차를 실행하지 않는다.

## 5. 로컬 정적 검증

이번 실행에서 실제 수행한 명령:

```bash
sh -n deployment/validate-templates.sh
deployment/validate-templates.sh
```

결과: 통과.

- 두 Nginx 템플릿의 `server_name`이 `www.memilmuk82.com`인지 확인
- 루트 도메인 `server_name` 부재 확인
- TLS proxy가 운영 전용 `127.0.0.1:8001`만 향하는지 확인
- 인증서 경로가 대상 호스트명과 일치하는지 확인
- 운영 예제의 secret·배포별 값이 비어 있는지 확인
- 기본 Compose와 운영 overlay 병합이 유효한지 확인

로컬 Nginx 1.24.0과 Certbot 2.9.0의 설치 여부만 읽기 전용으로 확인했다. 완전한 `nginx -t`는 실제 인증서 파일과 대상 서버의 전체 Nginx 컨텍스트가 필요하므로 실행하지 않았다. 운영에서는 설치·reload 전에 반드시 수행한다.

## 6. 승인 후 운영 절차

### 6.1 사전 조사와 백업

현재 상태를 기록하고 기존 값은 덮어쓰지 않는다.

```bash
date -Is
hostname --fqdn
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}'
sudo nginx -T
sudo ss -ltnp
dig +short A www.memilmuk82.com
dig +short AAAA www.memilmuk82.com
```

공인 IP와 대상 DNS가 일치하는지 별도로 확인한다. 위 출력에는 내부 운영 정보가 포함될 수 있으므로 저장소에 커밋하지 않는다. 기존 Nginx 대상 파일이 있으면 timestamp가 붙은 `/var/backups` 사본을 먼저 만든다. 관련 없는 사이트는 수정하지 않는다.

### 6.2 운영 환경과 컨테이너

```bash
cp deployment/.env.production.example deployment/.env.production
chmod 600 deployment/.env.production
```

사용자가 로컬 편집기로 `PORTFOLIO_SECRET_KEY`, 선택적 GitHub 프로필 URL과 이미지 이름을 채운다. Cloudflare 토큰은 이 파일에 두지 않는 편을 권장하며, DNS/API 작업 셸의 일시적 환경 변수로만 주입한다.

```bash
docker compose \
  --env-file deployment/.env.production \
  -f compose.yaml \
  -f deployment/compose.production.yaml \
  up --build --detach

    curl --fail http://127.0.0.1:8001/healthz
```

헬스체크 실패 시 Nginx 단계로 넘어가지 않고 이 프로젝트 Compose만 내린다.

### 6.3 HTTP-01 bootstrap

DNS가 실제 원본에 도달하고 외부에서 80번 접근이 가능하다는 승인을 받은 뒤에만 bootstrap 템플릿을 대상 사이트 파일로 설치한다. 기존 파일이 있으면 백업 후 `nginx -t`를 통과시킨 다음 대상 Nginx만 reload한다.

```bash
sudo install -d -m 0755 /var/www/certbot/.well-known/acme-challenge
sudo install -m 0644 deployment/nginx-www-bootstrap.conf.example \
  /etc/nginx/sites-available/memilmuk82-portfolio
sudo ln -s /etc/nginx/sites-available/memilmuk82-portfolio \
  /etc/nginx/sites-enabled/memilmuk82-portfolio
sudo nginx -t
sudo systemctl reload nginx
```

기존 symlink나 파일이 있으면 `ln -s`를 재실행하거나 강제로 덮어쓰지 않는다. 현재 상태를 조사해 별도 변경 계획을 작성한다.

### 6.4 인증서 발급

이 앱은 단일 호스트명만 요청한다.

```bash
sudo certbot certonly \
  --webroot \
  --webroot-path /var/www/certbot \
  --domain www.memilmuk82.com \
  --email "$LETSENCRYPT_EMAIL" \
  --agree-tos \
  --non-interactive
```

HTTP-01 조건이 맞지 않으면 명령을 반복하지 않는다. Cloudflare DNS-01 플러그인과 최소 권한 토큰을 검토하되, 플러그인 설치·토큰 파일 형식·권한을 해당 시점의 공식 Certbot/Cloudflare 문서로 다시 확인한다.

### 6.5 TLS reverse proxy

인증서 호스트명·체인·만료를 확인한 뒤 TLS 템플릿으로 대상 파일만 교체한다.

```bash
sudo install -m 0644 deployment/nginx-www.conf.example \
  /etc/nginx/sites-available/memilmuk82-portfolio
sudo nginx -t
sudo systemctl reload nginx

curl --fail --silent --show-error https://www.memilmuk82.com/healthz
sudo certbot renew --dry-run
```

HSTS는 초기 배포에서 활성화하지 않는다. 인증서 갱신·롤백·호스트 동작을 충분히 검증한 뒤 별도 승인으로 판단한다.

### 6.6 Cloudflare

원본 HTTPS가 올바른 호스트명·체인·만료로 응답한 뒤에만 Cloudflare SSL/TLS 모드를 Full (strict)로 바꾼다. `Flexible`은 사용하지 않는다. API를 사용할 때는 토큰이 활성 상태인지 공식 verify endpoint로 확인하되 토큰 값을 로그에 남기지 않는다.

```bash
curl --fail-with-body \
  --request PATCH \
  "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/settings/ssl" \
  --header "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  --header "Content-Type: application/json" \
  --data '{"value":"strict"}'
```

이 명령은 운영 게이트와 현재 zone 소유권, 이전 SSL 모드 백업을 확인한 경우에만 실행한다. 그 다음에만 `www` 레코드의 프록시를 활성화하고 외부에서 리디렉션, TLS 체인, 핵심 경로, 보안 헤더와 헬스체크를 재검증한다. 루트 도메인 레코드는 조회 외 어떤 변경도 하지 않는다.

## 7. 롤백 절차

문제 발생 시 새 변경을 더하지 않고 다음 순서로 복구한다.

1. Cloudflare 변경을 했다면 기록해 둔 이전 `www` proxy 상태와 SSL 모드로 되돌린다. 루트 도메인은 건드리지 않는다.
2. 대상 Nginx 사이트 파일을 timestamp 백업으로 복원하고 `sudo nginx -t` 통과 후 reload한다.
3. 새 컨테이너가 원인이면 이 프로젝트 파일 조합으로만 `docker compose down`한다. 기존 무관 컨테이너와 volume은 유지한다.
4. DNS를 바꿨다면 사전에 기록한 `www` 레코드 값으로만 복원하고 전파를 확인한다.
5. 새 인증서는 즉시 삭제하지 않는다. Nginx가 이전 구성으로 복구된 것을 먼저 확인하고, 불필요 인증서 정리는 별도 승인으로 처리한다.

```bash
docker compose \
  --env-file deployment/.env.production \
  -f compose.yaml \
  -f deployment/compose.production.yaml \
  down

sudo nginx -t
sudo systemctl reload nginx
```

예상 중단 시간과 실제 복구 시간, 실패 원인과 남은 외부 상태를 운영 기록에 남긴다.
