# 56개 프로젝트 게시 준비 마스터 프롬프트 (이전 버전)

> 현재 멀티에이전트·수동 설정·재개 기준은 `automation/portfolio-improvement-prompt.md`와 `scripts/portfolio-agent.sh`를 사용합니다. 이 문서는 과거 프로젝트별 판정 근거를 확인하기 위한 참고 자료입니다.

## 목표

현재 저장소 하나를 실제 코드와 운영 근거에 맞춰 게시 가능한 상태로 정리한다. 이 작업은 `/opt/apps` 아래 56개 저장소를 순차 처리하는 오케스트레이터에서 저장소별로 독립 실행된다.

현재 실행은 **게시 준비 단계**다. 코드·설정·테스트·문서는 수정할 수 있지만 GitHub/Vercel/Firebase/Supabase/DNS/운영 Docker 등 외부 상태는 변경하지 않는다. 커밋, push, 저장소 공개 전환, 프로젝트 생성, 유료 리소스 생성, 실제 배포도 하지 않는다.

## 프로젝트별 입력

프롬프트 끝의 `프로젝트 컨텍스트`에는 다음 값이 제공된다.

- 저장소 이름과 slug
- 포트폴리오의 현재 분류, 기술 스택, 목적지, 요약
- 1차 권장 게시 방식
- 외부 배포 허용 여부(준비 단계에서는 항상 false)

1차 권장 게시 방식은 힌트일 뿐이다. 실제 코드를 읽고 더 정확한 방식이 확인되면 변경할 수 있으며, 최종 JSON에 근거를 남긴다.

## 공통 작업 순서

1. 저장소 루트와 하위 경로의 `AGENTS.md`를 먼저 읽고 적용한다.
2. `git status --short`, 주요 소스, README, 패키지/잠금 파일, 테스트, 기존 배포 설정을 읽는다.
3. 코드가 실제로 사용하는 런타임·DB·파일 저장·인증·외부 API를 확인한다. README나 포트폴리오 설명과 다르면 코드를 기준으로 판정하고 불일치를 기록한다.
4. 이미 정상 운영되는 서비스는 런타임 구조를 갈아엎지 않는다. 필요한 검증·문서·안전한 설정 보완만 한다.
5. 중복·초기 학습본·빈 저장소는 억지로 서비스화하지 않는다. 대표 프로젝트와의 관계를 README에 명확히 하고 `repository-only` 또는 `excluded`로 판정한다.
6. 선택한 게시 방식에 필요한 최소 변경만 구현한다.
7. 가능한 범위에서 lint, format, test, build 또는 설정 검증을 실행한다. 네트워크나 비밀값이 없어 실행하지 못한 검증은 실패로 꾸미지 말고 blocker로 기록한다.
8. 마지막 응답은 CLI가 전달한 JSON Schema를 정확히 따라야 한다.

## 게시 방식 선택 규칙

### `existing-live`

- 이미 운영 URL과 검증된 배포가 있는 프로젝트.
- 운영 환경, DB, 도메인, 컨테이너를 변경하지 않는다.
- README의 실행·검증·롤백 절차, health endpoint, `.env.example` 누락만 보완한다.

### `docker`

- 장기 실행 서버, WebSocket/Socket.IO, 로컬 파일·SQLite 영속성, PostgreSQL과 함께 실행하는 서비스, 기존 Docker 구조가 핵심인 앱.
- `Dockerfile`과 Compose는 재현 가능해야 하고 비밀값을 포함하지 않아야 한다.
- 가능하면 non-root, healthcheck, restart 정책, 명시적 volume, 루프백 포트 바인딩, `.dockerignore`를 적용한다.
- SQLite는 파일 경로를 명시하고 volume에 둔다. PostgreSQL 비밀번호와 연결 문자열은 환경 변수로 이동한다.

### `github-pages`

- 순수 HTML/CSS/JavaScript, 정적 Vite 결과물, 안전하게 정적 문서로 빌드 가능한 프로젝트.
- 저장소 하위 경로에서도 asset URL과 SPA routing이 동작하게 한다.
- 필요하면 GitHub Pages용 Actions workflow를 준비하되 실제 Pages 설정/API 변경은 하지 않는다.
- 사용자 데이터·서버 비밀값·쓰기 DB가 필요한 기능을 정적 사이트인 것처럼 위장하지 않는다.

### `vercel-stateless`

- 짧은 HTTP 요청으로 끝나는 FastAPI/Flask/Express/API이며 영구 서버 상태가 필요 없는 프로젝트.
- 메모리 dict/list가 데모 상태임을 문서화한다. 영속성이 제품 요구가 아니면 DB를 억지로 추가하지 않는다.
- Vercel 진입점, requirements/package 설정, 환경 변수, health route를 최소한으로 준비한다.

### `vercel-supabase`

- Vercel에서 영속 CRUD가 실제 요구이고 관계형 모델이 적합한 프로젝트.
- SQLite 파일이나 프로세스 메모리 저장을 운영 저장소로 사용하지 않는다.
- Supabase PostgreSQL을 사용하되 서버 측 ORM이면 pooled `DATABASE_URL`만으로 연결하고 service-role key를 불필요하게 도입하지 않는다.
- 브라우저 직접 접근이면 RLS를 기본 거부에서 시작하고 최소 권한 정책을 migration으로 둔다. service-role key는 클라이언트에 노출하지 않는다.
- `supabase/migrations`와 ORM migration을 동시에 진실의 원천으로 만들지 않는다. 하나만 선택해 README에 명시한다.

### `vercel-firebase`

- Firebase Auth/Firestore가 이미 구현된 Vercel 앱.
- Supabase로 재작성하지 않는다.
- 인증 토큰 전달, 사용자별 소유권, Firestore Rules, timeout, 오류 처리를 점검한다.
- 실제 Firebase project/rules 배포는 하지 않는다.

### `external-platform`

- Apps Script, Google Slides/Canva 산출물, 모바일 앱, 외부 플랫폼이 결과물의 본체인 프로젝트.
- 검증된 artifact URL과 실행/열람 방법을 문서화한다. 억지로 Vercel 앱으로 바꾸지 않는다.

### `repository-only`

- 학습 소스, CLI/배치 도구, 템플릿, 프롬프트·Markdown, 중복 프로젝트.
- 설치·실행·입출력 예와 현재 한계를 README에 보완한다.
- 실행 가능한 웹 결과물이 없으면 live URL을 만들었다고 주장하지 않는다.

### `excluded`

- 빈 저장소, 자리표시자, 미구현, 민감 자료, 공개 근거가 부족한 프로젝트.
- 구현이나 성과를 창작하지 않는다. 제외 이유와 재검토 조건만 명확히 한다.
- 비공개 정보, 내부 경로, 비밀값을 외부 링크나 문서에 추가하지 않는다.

## 이미 합의된 대표·중복 관계

- `DjangoBlog`가 Django 블로그 대표 배포본이다.
- `do_it_django`와 `DjangoBlog2`는 중복·학습 단계이므로 별도 서비스로 배포하지 않고 대표본 관계를 문서화한다.
- 기존 Docker 운영 프로젝트는 다른 플랫폼으로 이전하지 않는다.
- `gpt-vercel`, `todo_260613`, `chatbot`은 기존 Firebase 계열을 유지한다.
- 정적 사이트는 기존 GitHub Pages가 정상이라면 플랫폼을 옮기지 않는다.

## 금지 사항

- 비밀값, 서비스 계정 JSON, 실제 `.env`, DB 덤프, 개인·학생 데이터를 생성하거나 커밋하지 않는다.
- 하드코딩된 비밀값을 새 설정 파일로 복사하지 않는다. 발견하면 환경 변수화하고 blocker에 기록한다.
- 기존 사용자 변경을 reset, checkout, clean, stash, 삭제하지 않는다.
- 테스트를 통과시키기 위해 동작을 제거하거나 검증을 약화하지 않는다.
- 외부 URL을 추측하거나 아직 배포하지 않은 URL을 `live_url`로 확정하지 않는다.
- `git commit`, `git push`, `gh`, `vercel --prod`, `firebase deploy`, `supabase db push`, DNS/API mutation, 운영 `docker compose up/down`을 실행하지 않는다.

## 저장소에 남길 게시 계약

기존 구조와 충돌하지 않는다면 다음을 준비한다.

- README의 `배포 방식`, `환경 변수`, `검증`, `현재 한계` 섹션
- 비밀값 없는 `.env.example`
- 선택한 플랫폼의 최소 설정 파일
- 재현 가능한 테스트/빌드 명령
- `docs/PUBLISHING.md` 또는 기존 배포 문서
- 외부 변경을 실제 수행하지 않는 `scripts/verify-publish.sh`

작은 학습 저장소에 불필요한 디렉터리와 거대한 운영 프레임워크를 강제하지 않는다. 기존 README에 간결하게 합치는 편이 낫다면 그렇게 한다.

## 완료 기준

- 게시 방식이 실제 코드와 일치한다.
- 영구 상태와 임시 상태가 구분돼 있다.
- 필요한 환경 변수가 문서화되고 비밀값은 없다.
- 가능한 검증이 실행됐고 결과가 사실대로 기록돼 있다.
- 남은 외부 작업은 사람이 검토 가능한 구체적 명령/대상으로만 보고된다.
- 마지막 출력은 지정 JSON Schema를 만족한다.
