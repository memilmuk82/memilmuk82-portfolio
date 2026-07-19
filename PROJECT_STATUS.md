# PROJECT STATUS

최종 갱신: 2026-07-19

## 현재 콘텐츠 계약과 통합 감사

- `/opt/apps` 직하의 유효한 독립 Git 저장소 56개와 인벤토리 이름 집합이 일치하며, 분류는 서브도메인 9·정적 7·소스 소개 28·비공개·제외 12다.
- `noom`은 Node.js·Socket.IO·Docker·무DB 서브도메인 웹앱으로 분류하며 데이터베이스 의존성을 추가하지 않는다.
- `curriculum-subject-overlap-check`는 비공개·제외이며 저장소·운영·산출물 링크와 교육과정 원문을 공개하지 않는다.
- 교육 변화는 2020—2021 프로그래밍과 웹의 기초, 2022—2023 서버·API·데이터로 확장, 2024—2025 서비스와 에듀테크, 2026 AI 활용에서 설계·검증으로의 네 시기다.
- 2026-07-19 통합 감사에서 JSON, Ruff, pytest 35개, Tailwind 빌드가 통과했다. Playwright Firefox 대체 렌더로 1440×1100·390×844·360×800의 가로 오버플로 0px와 서버 필터에서 전체 56행으로 복귀하는 흐름을 확인했다.
- 외부 제약: 읽기 전용 조사 시 `/opt/apps/noom`에는 Dockerfile·Compose·운영 시작 구성이 없었다. 포트폴리오의 합의된 Docker 분류는 유지하되 실제 컨테이너화는 해당 저장소의 별도 작업이 필요하다. 운영 URL의 현재 응답 여부는 이 실행 환경의 DNS 제한으로 재검증하지 못했다.
- 기존 배포·운영 관련 워크트리 변경은 사용자 소유로 간주해 되돌리거나 덮어쓰지 않았다.

## 최초 로컬 구축 실행 기준 (역사 기록)

> 이 지점부터 문서 끝까지의 단계·수치·역할 기록은 2026-07-18 최초 로컬 구축 당시의 이력이다. 현재 적용 상태는 위의 “현재 콘텐츠 계약과 통합 감사”를 기준으로 한다.

- 실행 모드: `local` (`PORTFOLIO_EXECUTION_MODE` 미설정 시 기본값)
- 최종 런타임: Flask / Jinja / HTML / Tailwind CSS / Vanilla JavaScript
- 참고 자료: 읽기 전용
- 외부 게시·DNS·Nginx·인증서·방화벽·운영 컨테이너 변경: 금지

## 단계

- [x] 프로젝트·참고 자료 조사
- [x] 공개 후보 보수적 재검증
- [x] 홈·프로젝트·상세·활동·소개·모바일 디자인 콘셉트 생성
- [x] 디자인·아키텍처 명세 확정
- [x] Flask/Jinja 앱과 Tailwind 빌드 구현
- [x] 정적 검사와 pytest
- [x] 실제 브라우저 데스크톱·모바일 검수
- [x] Docker 빌드·헬스체크 시도 — Docker 소켓 제약 기록
- [x] 배포·게시 준비 문서 확정
- [x] 최종 실행 검증 — 실행 가능한 로컬 기준 통과, 환경 제약 기록
- [x] 로컬 Git 커밋 — `7a2f882` (`feat: Flask 기반 포트폴리오 웹앱 구축`)

## 최초 로컬 구축 완료 결과 (역사 기록)

- `npm ci --offline --ignore-scripts --no-audit --no-fund`: 통과, 74개 패키지 설치
- Tailwind 3.4.17 프로덕션 빌드: 통과, 생성 CSS 해시 정합
- Ruff 검사·포맷 검사: 통과
- pytest: 30개 통과
- Flask 필수 경로·정적 CSS/JS/favicon·healthz·404/500·보안 헤더: 통과
- Firefox 브라우저 QA: 1440px, 390px, 360px 화면과 메뉴·필터·키보드 흐름 통과
- Compose 병합: `PORTFOLIO_EXECUTION_MODE=production` 전달 확인
- 배포 템플릿 정적 검증: 통과
- 공개 콘텐츠·비밀 표식 검사: 통과

환경 제약은 완료로 추정하지 않고 `docs/FINAL_VERIFICATION.md`에 재실행 명령과 함께 유지한다. 네트워크·캐시 제약으로 `uv.lock`과 새 Python 환경 설치를 확인하지 못했고, TCP 소켓 제약으로 Gunicorn을 바인딩하지 못했으며, Docker 소켓 권한으로 이미지·컨테이너 health를 실행하지 못했다.

## 최초 파동식 역할 위임 기록 (역사 기록)

동시에 세 개를 넘지 않는 하위 에이전트를 재사용한다. 모든 역할은 로컬 범위만 가진다.

| 파동 | 역할 | 담당 | 상태 | 결과·인계 |
| --- | --- | --- | --- | --- |
| 1 | 1. 저장소·프로젝트 검증 | `repository_verification` | 완료 | 독립 저장소 56개를 9·7·28·12로 전량 분류. `noom`은 무DB 웹앱, 교육과정 원문 자료는 비공개로 확정 |
| 1 | 2. 웹앱 제작 | `webapp_builder` | 완료 | Flask 팩토리·Blueprint·Jinja·Tailwind·Vanilla JS·콘텐츠·테스트 구현. 독립 QA 수정 3회 반영 |
| 2 | 3. 웹앱 검수 | `webapp_qa` | 완료 | 기능·접근성·반응형·보안·사실성 검수, Firefox 브라우저 캡처 13개, QA·보안·시각 원장 작성 |
| 3 | 4. GitHub CLI 게시 | `repository_verification` 재위임 | 완료(외부 게시 보류) | local 게이트·공개 안전성·파일별 staging 확인. 로컬 커밋 `7a2f882` 생성, 원격·push·PR 미수행 |
| 3 | 5. Docker 컨테이너 빌드 | `repository_verification` 재위임 | 완료(환경 제약) | 다단계 Dockerfile·비루트·루프백 Compose·잠금 파일 작성. 정적 검증 통과, Docker 소켓 오류 기록 |
| 3 | 6. 웹앱 환경 | `repository_verification` 재위임 | 완료 | 운영 Compose overlay, `www.memilmuk82.com` Nginx 예제, 외부 게이트·롤백·검증 스크립트 작성. 운영 변경 없음 |
| 5 | 7. 최종 웹앱 실행 체크 | `webapp_builder` | 완료 | Node 잠금·production 모드 수정 재검증, Ruff·30 tests·Tailwind·Compose·문서 정합성 최종 확인. `docs/FINAL_VERIFICATION.md` 작성 |

## 초기 제약

프로젝트 루트의 `.git`은 비어 있는 읽기 전용 tmpfs mount라 저장소로 인식되지 않았다. 삭제·덮어쓰기·언마운트하지 않고 프로젝트 내부 `.git-local/`에 독립 Git metadata를 초기화했다. 명시적 `--git-dir=.git-local --work-tree=.` 명령으로 75개 파일을 검토·커밋했으며 자세한 제약과 표준 `.git` 전환 절차는 `docs/PUBLISH_READINESS.md`에 기록했다.
