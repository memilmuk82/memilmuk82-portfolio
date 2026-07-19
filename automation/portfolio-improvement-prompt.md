# MEMILMUK82 포트폴리오 2026 개선 프롬프트

## 역할과 최종 목표

당신은 `memilmuk82/memilmuk82-portfolio`를 실제 운영 가능한 한국어 교사·개발자 포트폴리오로 개선하는 총괄 디자이너이자 엔지니어다.

이 사이트의 목적은 GitHub 프로필을 꾸미는 것이 아니다. 방문자가 `https://www.memilmuk82.com` 또는 `https://memilmuk82.com`에 접속했을 때 다음 두 내용을 짧은 시간 안에 이해하게 만드는 것이 목적이다.

1. 2020년부터 2026년까지 수업 내용과 기술 활용이 어떻게 바뀌었는가.
2. 수업·연수·교육 업무와 연결된 GitHub 프로젝트가 무엇이며, 코드나 실행 결과를 어디에서 볼 수 있는가.

현재 Flask·Jinja·Tailwind CSS·Vanilla JavaScript 구조를 유지한다. 프레임워크를 바꾸는 전면 재작성은 하지 않는다. 단순 보고로 끝내지 말고, 저장소 안에서 안전하게 고칠 수 있는 내용은 직접 구현하고 검증한다.

## 작업 방식

1. 저장소 루트와 하위 경로의 `AGENTS.md`가 있다면 먼저 읽는다.
2. `git status --short`를 확인하고 기존 변경을 사용자 소유로 간주한다.
3. 현재 코드, JSON, 템플릿, 테스트, README, 배포 문서를 읽은 뒤 최소한의 일관된 구조로 개선한다.
4. `/opt/apps`에 인벤토리 대상 프로젝트가 있다면 이번 작업 범위에 포함한다. 읽기 감사 후 담당 트랙이 배정되고 worktree가 깨끗한 저장소만 게시 준비에 필요한 최소 파일을 수정한다. 인벤토리에 없는 저장소는 수정하지 않는다.
5. GitHub 또는 외부 URL은 현재 코드·README·설정에서 확인된 것만 사용한다. URL을 추측하지 않는다.
6. 질문을 기다리느라 중단하지 않는다. 아래 확정 기준 안에서 보수적으로 판단하고, 판단 근거와 제약을 최종 보고서에 남긴다.
7. 실행 프롬프트 끝에 `RUN_DIR`, `STATE_FILE`, `RUN_STATE_JSON`, `RUN_LOG`, `FINAL_REPORT`가 제공되면 실제 진행 단계마다 사람이 읽는 `STATE_FILE`과 기계 판정용 `RUN_STATE_JSON`을 함께 갱신한다.
8. `EXECUTION_SCOPE`가 `all`이 아니면 다음 범위만 수정하고 나머지는 읽기 근거로만 사용한다: `gpt-vercel`은 해당 저장소와 포트폴리오의 관련 설명, `static-sites`는 포트폴리오 본체와 `ai-teaching-deck`, `portfolio`는 포트폴리오 저장소 내부만 해당한다.

## 멀티에이전트 하네스와 루프 — 필수

이 작업은 한 에이전트가 56개 저장소를 차례대로 훑는 방식으로 수행하지 않는다. 루트 에이전트는 요구사항, 상태, 결과 계약과 최종 통합만 소유하고, 직접 하위 에이전트 세 개를 병렬로 배정한다. 하위 에이전트는 다시 에이전트를 만들지 않는다.

### 역할 배정

1. `inventory-evidence`
   - 읽기 중심 역할이다.
   - 56개 이름, 실제 소스·README·잠금 파일·배포 설정, 기존 URL과 현재 Git 상태를 확인한다.
   - 프로젝트별 근거와 권장 배포 방식을 `deployment-plan.json`에 반영할 수 있는 요약으로 반환한다.
   - 다른 역할이 구현을 시작하기 전에 충돌, 중복, 내용 없음, 기존 운영 여부를 식별한다.
2. `container-track`
   - `docker-postgresql`, `docker-sqlite`, `docker-nodb` 프로젝트만 담당한다.
   - 서로 다른 저장소만 순차 수정하며 같은 파일을 다른 에이전트와 동시에 편집하지 않는다.
   - Dockerfile·Compose·환경 변수 예·healthcheck·영속 볼륨·운영 문서를 실제 코드와 맞춘다.
3. `serverless-static-track`
   - `vercel-supabase`, `vercel-firebase`, `vercel-single`, `github-pages`, `external-platform`을 담당한다.
   - Vercel 진입점, 정적 빌드 경로, GitHub Pages workflow, 환경 변수 이름과 수동 설정을 준비한다.
   - Supabase·Vercel·GitHub Pages 콘솔 작업이 필요하면 수행했다고 가정하지 않고 수동 게이트에 등록한다.
   - `gpt-vercel`은 `gpt-manager`를 읽기 전용 기준으로 비교하되 writer는 `gpt-vercel` 하나만 가진다. 기존 Vercel+Firebase 구현을 유지하며 아래의 전용 완성 계약만 수행한다.

루트 에이전트는 세 결과를 모두 기다린 후에만 포트폴리오 JSON·화면·문서를 통합한다. 포트폴리오 저장소의 통합 파일은 루트만 수정한다.

### 상태 머신

아래 단계를 순서대로 실행하고 `STATE_FILE`에 현재 상태를 기록한다.

1. `discovering`: 저장소 목록, dirty worktree, 현재 commit, 설정과 URL 확인
2. `planning`: 프로젝트별 배포 계획과 근거 확정
3. `preparing`: 세 트랙이 서로 겹치지 않는 저장소를 수정하고 검증
4. `awaiting_manual`: 콘솔·계정·도메인·비밀값 설정이 필요해 사람을 기다림
5. `verifying_links`: 수동 완료가 확인된 뒤 실제 HTTPS 응답과 앱 동작 확인
6. `integrating_portfolio`: 검증된 링크와 새 분류를 포트폴리오에 반영
7. `qa`: 콘텐츠·테스트·브라우저·문서 정합성 검사
8. `completed` 또는 `blocked`

현재 실행 정보에 `EXECUTION_MODE: prepare`가 있으면 `awaiting_manual`까지 수행할 수 있다. `EXECUTION_MODE: resume`가 있으면 이전 실행의 `manual-actions.json`과 사용자의 완료 확인을 읽은 뒤 `verifying_links`부터 재개한다. 완료 확인이 없는 외부 작업을 추측해 건너뛰지 않는다.

### 하네스 산출물 계약

`RUN_DIR` 아래에 비밀값을 포함하지 않는 다음 파일을 유지한다.

- `deployment-plan.json`: 56개 프로젝트의 근거, 방식, 현재 상태, 목표 URL, 담당 트랙
- `writer-map.json`: 저장소별 단일 writer와 읽기 전용 reviewer. 같은 저장소에 writer가 둘 이상이면 구현 전에 차단
- `results/<slug>.json`: 프로젝트별 수정 파일, 검사, 차단 사항, 수동 작업, 링크 검증 결과
- `results/gpt-vercel-feature-gap.md`: `gpt-manager` 대비 `이미 구현됨 / 이번에 구현 / 서버리스 제약으로 보류` 기능표
- `results/gpt-vercel-parity.json`: 기능별 `equivalent`, `adapted_for_serverless`, `intentionally_not_ported`, `blocked` 상태와 근거
- `manual-actions.json`: 사람이 수행해야 하는 작업의 구조화 목록
- `manual-actions.md`: 이메일과 터미널에서 읽을 수 있는 같은 내용의 한국어 안내
- `state.md`: 현재 단계와 완료·실패 수
- `run-state.json`: 하네스가 완료 여부를 판정하는 단일 기계 상태
- `final.md`: 통합 결과

`run-state.json`은 최소한 `state`, `required_results`, `checks`, `pending_manual_actions`, `updated_at`을 가진다. `state`는 `discovering`, `planning`, `preparing`, `validating_local`, `awaiting_manual`, `verifying_external`, `integrating_portfolio`, `qa`, `completed`, `blocked` 중 하나다. 완료 시 필수 결과 파일과 검사의 실제 상태를 기록하며, 단순히 최종 문장을 출력했다는 이유로 `completed`를 쓰지 않는다.

`deployment-plan.json`의 각 항목은 최소한 다음 값을 가진다.

- `name`, `slug`, `local_path`, `commit_sha`
- `evidence`
- `deployment_method`
- `relationship`, `related_years`
- `repository_url`
- `current_live_url`, `target_live_url`
- `owner_agent`
- `status`: `planned`, `prepared`, `awaiting_manual`, `verified`, `blocked`, `repository_only`, `excluded`
- `attempts`

동일한 `commit_sha`, 프롬프트 버전과 계획으로 이미 `verified`된 항목은 재실행하지 않는다.

### 제한된 수정 루프

각 프로젝트는 실행 정보의 `MAX_FIX_LOOPS` 이내에서만 `근거 확인 → 최소 수정 → 관련 검사 → 판정` 루프를 돈다. 기본값은 2, 허용 범위는 1~3이다.

- 첫 검사에서 통과하면 즉시 종료하며 횟수를 채우기 위해 다시 실행하지 않는다.
- 다음 루프는 실제 실패가 있고 최소 수정으로 해결할 수 있을 때만 수행한다.
- 같은 실패 fingerprint와 같은 diff가 두 번 반복되면 더 넓게 고치지 말고 `blocked`로 기록한다.
- 읽기 감사, 미수정 저장소, `repository-only`, `excluded`에는 빌드·테스트 루프를 실행하지 않는다.
- 한 저장소의 통합 writer는 한 명뿐이며 다른 에이전트는 읽기 검토만 한다.

루프 한도 뒤에도 실패하면 변경을 확대하지 말고 `blocked`로 기록한다. 무한 재시도, 플랫폼 전환 반복, 무관한 리팩터링을 하지 않는다.

dirty worktree가 있는 저장소는 변경하지 않고 `blocked`로 기록한다. 사용자가 명시적으로 허용한 경우에도 기존 diff를 먼저 기록하고 그 파일을 덮어쓰지 않는 변경만 수행한다. 각 writer는 시작 commit SHA, 시작 dirty diff hash, 준비 후 diff hash와 변경 파일을 결과 JSON에 기록한다. `resume`에서는 이전 실행이 기록한 준비 후 diff와 정확히 같은 변경만 하네스 소유로 인정한다. 새 사용자 변경이 섞였으면 해당 저장소만 차단하고 reset·stash·clean하지 않는다.

## 수동 설정·이메일·재개 게이트

Supabase, Vercel, GitHub Pages, DNS, OAuth, 운영 환경 변수처럼 계정 소유자의 콘솔 작업이 필요하면 다음 절차를 따른다.

1. 실행을 실패로 꾸미지 말고 해당 프로젝트 상태를 `awaiting_manual`로 변경한다.
2. `manual-actions.json`과 `manual-actions.md`를 작성한다.
3. 안내 수신자는 실행 정보의 `MANUAL_CONTACT`를 사용한다. 값이 없으면 전송을 가장하지 말고 안내 파일만 생성한다.
4. 비밀값 자체는 이메일·로그·JSON에 쓰지 않고, 설정해야 할 환경 변수 이름과 콘솔 경로만 설명한다.
5. 백그라운드 실행을 종료하고 사용자가 완료 확인 후 `resume`하도록 한다.
6. 재개 실행에서는 실제 링크와 최소 동작을 확인한 뒤에만 포트폴리오에 URL을 추가한다.

`manual-actions.json` 형식은 다음 계약을 따른다.

```json
{
  "gate_id": "run-id-manual-1",
  "status": "awaiting_manual",
  "recipient": "${MANUAL_CONTACT}",
  "subject": "[MEMILMUK82] 포트폴리오 배포 수동 설정 안내",
  "actions": [
    {
      "id": "project-provider-action",
      "project": "repository-name",
      "provider": "supabase",
      "title": "수동 작업 제목",
      "instructions": ["비밀값 없이 따라 할 수 있는 단계"],
      "required_environment_variables": ["DATABASE_URL"],
      "completion_evidence": ["확인해야 할 콘솔 상태 또는 HTTPS URL"]
    }
  ],
  "resume_command": "bash scripts/portfolio-agent.sh resume --confirm-all"
}
```

Supabase 안내에는 해당되는 경우 다음을 포함한다.

- 프로젝트 생성과 Region 선택
- 스키마 또는 migration 적용 순서
- 서버 런타임이 사용할 pooled `DATABASE_URL`의 환경 변수 등록
- 브라우저 직접 접근이 있을 때만 publishable URL·key와 RLS 정책
- service-role key를 클라이언트에 넣지 않는다는 주의
- Vercel 프로젝트 연결, Preview·Production 환경 변수 구분, 재배포
- health endpoint와 CRUD 영속성으로 완료를 확인하는 방법

사람이 완료했다고 확인하기 전에는 Supabase 프로젝트, DB, Vercel 프로젝트, 도메인 연결이 존재한다고 가정하지 않는다.

## 공개 범위와 출처 — 확정 기준

- 2026-07-19 GitHub 확인 기준 계정에는 저장소가 57개 있다.
- 포트폴리오 저장소 자체를 제외한 프로젝트 인벤토리 대상은 56개다.
- 계정 전체에서 공개 53개, 비공개 4개다.
- 비공개 4개는 내용이 거의 없는 `test`, `subway_time`, `ChatGPT_api`, `BardAPI_test`다.
- 예전 문서의 `서브도메인 9·정적 7·소스 28·제외 12`는 더 이상 변경 불가 수치가 아니다. 실제 코드·README·배포 상태로 다시 계산하고, 테스트와 문서도 새 결과에 맞춘다.
- 내용이 없는 저장소, 중복 스캐폴드, 실행 근거가 없는 자리표시자는 방문자용 전시에서 제외할 수 있다. 그러나 전체 인벤토리의 누락과 중복은 없어야 한다.
- 다음 저장소는 소유자가 공개를 허용했다. 민감정보 우려를 이유로 자동 제외하지 않는다.
  - `DjangoBlog`, `do_it_django`, `DjangoBlog2`, `MapTime`, `School_Map`
  - `BardAPI_test2`, `OpenAPI_project`, `ToDo`, `skel_web_env`, `chatbot`
- `whalespace-training`, `2026-python-workbook`은 공개 자료를 기반으로 만들었으며 소유자가 공개와 포트폴리오 활용을 허용했다.
- 위 확인은 `외부 보안·법률 검증 완료`가 아니라 `소유자 확인으로 공개 허용`이라는 뜻이다. 화면에서 과장된 검증 문구를 만들지 않는다.
- Notion은 내부 참고 자료일 뿐이다. Notion URL, 페이지 ID, 원문, 캡처, 첨부 파일, 내부 메모를 공개 코드·JSON·HTML·문서뿐 아니라 `RUN_DIR`, 로그, 이메일, 결과 JSON, 최종 보고서에도 넣지 않는다.
- 활동 출처를 표시해야 한다면 `회고 기반 정리`, `이수 기록 확인`, `GitHub 저장소 확인`처럼 일반적인 설명만 사용한다.
- 실제 학생, 계정, 상담, 예약, 이메일, 연락처, 학교 내부 데이터는 표시하지 않는다.

## 문체와 콘텐츠 원칙

- 한국어를 기본으로 한다.
- 자랑이나 홍보 문구보다 사실 중심의 짧은 개조식 문장을 사용한다.
- 근거 없는 학생 성과, 수치, 학교명, 직함, 경력 기간, 서비스 이용량을 만들지 않는다.
- 연수는 세부 교육과정이나 시간표를 길게 옮기지 않고 “그해 어떤 영역을 학습했는가” 수준으로만 적는다.
- 프로젝트 설명은 저장소 이름만 풀어쓰지 말고 README와 실제 구현을 기준으로 한 문장으로 요약한다.
- 수업과 프로젝트의 관계를 `학생 수업`, `수업 준비`, `연수 연계`, `교육 업무`, `개인 실험` 중 하나 이상으로 명확히 표시한다.

## 2020–2026 활동 페이지의 사실 기준

기존의 네 시기 요약만 보여 주는 활동 화면을 연도별 7개 구간으로 바꾼다. 각 연도는 `수업`, `연수·학습`, `연결 프로젝트`를 짧은 목록으로 제공하되, 근거가 없는 항목은 빈 섹션을 억지로 만들지 않는다.

### 2020

- 수업: C언어 기초 문법
- 수업: 웹디자인개발기능사 준비를 위한 HTML, CSS, JavaScript, jQuery
- 연수·학습: 인공지능 관련 연수
- 출처 성격: 소유자 회고

### 2021

- 수업: 파이썬 기초 문법
- 수업 준비: Cisco 라우터·스위치·AP·IP 전화기를 활용한 스위칭, 라우팅, VoIP 학습 자료
- 수업 준비: 장비 펌웨어 설정부터 VoIP 연결까지 네트워크 수업 기초 기술 정리
- 연수·학습: 인공지능 연수, AWS 강사 온라인 연수
- `2021학년도 겨울 연수 · 실제 이수 2022.01`로 구분해 Google Cloud, Docker·Kubernetes, Django 웹 서비스와 AWS 배포, EVE-NG 기반 파이썬 네트워크 가상화를 간략히 표시
- 출처 성격: 소유자 회고와 이수 기록 확인

### 2022

- 수업: 스토리보드와 서비스 기획
- 수업: Hyper-V에서 Ubuntu·Rocky Linux를 사용한 웹·메일·클라우드·가상 네트워크 실습
- 수업: WSL2 Ubuntu·Rocky Linux와 VS Code 개발 환경 구성
- 수업: Vue.js 및 Node.js 기반 방과후 프로젝트
- `noom`: Node.js·Express·Socket.IO로 만든 방 기반 익명 실시간 텍스트 채팅. 방 입장·퇴장 알림과 메시지 전달을 구현한 앱
- `noom`을 영상 회의, Zoom 복제, WebRTC 앱으로 설명하지 않는다. 실제 구현은 텍스트 채팅이다.

### 2023

- 수업: Django 개발 환경, 프론트엔드 기초, Git·GitHub, 블로그의 글·댓글·검색·인증·테스트·배포
- 수업: Google Bard API 응답 처리와 공개 API 활용
- 수업: Flutter 미니 앱 — 시작 화면, 블로그 웹뷰, 이미지 전환, D-day, 주사위 등
- 연수·학습: 클라우드 환경의 컨테이너와 리눅스 운영
- 연결 저장소 후보: `DjangoBlog`, `do_it_django`, `DjangoBlog2`, `BardAPI_test2`, `OpenAPI_project`, Flutter 저장소

### 2024

- 수업: 파이썬 기초
- 수업: Node.js·Express의 HTTP 서버, Router, 템플릿 엔진
- 수업: PostgreSQL·MongoDB 연동, SNS 서비스와 웹 API 서버
- 연수·학습: AWS, Docker 기반 프론트엔드·백엔드, TensorFlow 딥러닝, 컨테이너·리눅스 운영
- 연수·학습: ChatGPT와 SQL을 활용한 데이터 분석
- 연결 저장소 후보: `learn-express`, `Router_express.js`, `learn-sequelize`, `learn-mongoose`, `nodebird`, `nodebird-api`, `nodecat`

### 2025

- 수업: 응용 프로그래밍과 빅데이터 프로그래밍
- 수업: WSL2·VS Code 개발 환경
- 수업: FastAPI 요청·응답 스키마와 검증
- 수업: 메모리 기반 CRUD에서 DB를 사용하는 ToDo API까지 확장
- 연결 저장소 후보: `fastapi_crud`, `ToDo`, `demo-app`, `RestfulServer`
- `2025_AIEdutech_Seoul`은 저장소 이름만으로 2025년 수업 근거라고 단정하지 않는다.

### 2026

- 수업: Flask 기반 응용 프로그래밍
- 수업: WSL2, 가상환경, VS Code, Git 개발 흐름
- 수업: 프로필 API, Python 데이터의 HTML·Jinja 출력, list·for·if
- 수업: HTML form과 Flask request
- 수업: list CRUD → dict CRUD → ID CRUD → SQLite 영속화
- 수업: README와 프로젝트 문서 작성, 개인 웹 서비스 프로젝트
- 연수·강의 연결: 생성형 AI 프롬프트와 SEN GPT, Google Workspace for Education Plus, SEN스쿨·웨일스페이스 활용. 세부 강의안이나 내부 자료를 옮기지 않고 주제 수준으로만 표시한다.
- 연결 저장소 후보: `hello_flask`, `python_flask_2026`, `flask-template`, `2026-python-workbook`
- 연수·강의 연결 저장소 후보: `ai-teaching-deck`, `senschool-google-edu-plus`, `whalespace-training`

## 프로젝트 전시 구조

`/projects`를 모든 것을 같은 무게로 나열하는 화면이 아니라 “대표 결과 + 전체 아카이브” 구조로 개선한다.

### 대표 프로젝트

- 홈에는 가장 설명력이 높은 4개 안팎만 보여 준다.
- 대표 여부는 하드코딩한 배열 순서가 아니라 `featured`와 명시적 정렬 값으로 결정한다.
- 각 대표 항목은 문제, 실제 구현, 수업·교육 업무와의 관계, 기술, 공개 저장소, 확인된 실행 결과를 보여 준다.
- 상세 사례가 없는 저장소에 존재하지 않는 성과를 만들어 내지 않는다.

### 전체 아카이브

- 대상 56개 저장소 이름의 누락과 중복이 없어야 한다.
- 내용이 있는 공개 저장소에는 GitHub 링크를 제공한다.
- 내용이 없거나 중복 단계라면 제외·보관 이유를 짧게 표시하고 실행 결과를 만들지 않는다.
- 검색과 필터는 JavaScript 없이도 GET 요청으로 동작해야 한다.
- 권장 필터: 연도, 수업 연계, 결과 형태, 배포 방식, 상태. 화면이 복잡해지면 연도와 결과 형태를 우선한다.
- 한 항목의 권장 필드:
  - 저장소 이름, 방문자용 제목, 한 문장 요약
  - 관련 연도와 관계 유형
  - 기술 스택
  - 결과 형태: 웹앱, 정적 사이트, 모바일 앱, API, CLI·배치, 문서·자료, 소스만
  - 배포 방식과 상태
  - `repository_url`, 확인된 경우에만 `live_url` 또는 `artifact_url`

### 대표·중복 관계 — 변경 금지

- `DjangoBlog`만 Django 블로그 대표 웹앱으로 전시·배포한다.
- `do_it_django`, `DjangoBlog2`는 같은 학습 흐름의 소스 저장소로 남기고 별도 웹앱으로 배포하지 않는다.
- `DjangoBlog`의 대표 전시는 OCI 컨테이너 추가를 뜻하지 않는다. 검증된 별도 배포가 없으면 저장소 대표 링크만 제공한다.
- `noom`이 실제 구현을 대표한다.
- `CloneCoding_Noom`은 초기 방 입장 실습, `noom1`은 중복·초기 골격으로 분류한다.

## 배포 방식 분류 기준

배포는 프로젝트의 실제 구조에 맞춰 분류하며, 모든 저장소를 억지로 웹앱으로 만들지 않는다.

- 순수 HTML·CSS·JavaScript 또는 정적 빌드: GitHub Pages 우선
- Flask·Django·FastAPI·Express처럼 장기 실행 서버, WebSocket, SQLite 파일, 자체 백엔드가 필요한 앱: Docker 기반 배포와 OCI 계열 운영을 우선
- 이미 Vercel 구조가 있는 짧은 요청 기반 앱: Vercel 유지
- 이미 Firebase Auth·Firestore를 사용하는 앱: Vercel + Firebase 유지
- 새 프로젝트에서 관리형 PostgreSQL·인증이 실제로 필요한 경우에만 Vercel + Supabase 검토
- Netlify는 기존 구성이 있거나 Forms·Functions가 구체적으로 필요한 프로젝트에만 사용
- 모바일 앱, 학습 저장소, 중복본, CLI·배치, 문서 자료: 저장소 또는 산출물 소개
- GitHub Pages에서 서버 앱이 실행되는 것처럼 표현하지 않는다.
- 아직 배포하지 않은 URL을 예상해 `live_url`로 넣지 않는다.

### 배포 방식 enum과 판정 근거

주요 전시·게시 분류는 다음 값을 사용한다.

- `docker-postgresql`: Dockerfile 또는 Compose, PostgreSQL 드라이버·연결 설정, migration 근거가 모두 있음
- `docker-sqlite`: Dockerfile, 실제 SQLite 접근, 운영 DB 경로와 영속 volume 근거가 있음
- `vercel-supabase`: Vercel 진입점과 Supabase 또는 pooled PostgreSQL 연결, 하나의 migration 진실 원천이 있음
- `vercel-single`: 짧은 무상태 요청으로 끝나며 WebSocket·상시 worker·로컬 영속 파일이 없음
- `github-pages`: 정적 소스 또는 정적 빌드 결과와 base path·Pages 설정이 확인됨

실제 구조를 거짓으로 바꾸지 않기 위해 다음 예외도 허용한다.

- `docker-nodb`: `noom`처럼 WebSocket 서버지만 DB가 필요 없음
- `vercel-firebase`: 이미 Firebase Auth·Firestore를 사용하는 앱
- `existing-live`: 기존 운영 방식과 URL이 확인된 앱
- `external-platform`: Apps Script, Google Slides·Canva, 모바일 결과물
- `repository-only`: 학습 소스, CLI·배치, 중복 프로젝트
- `excluded`: 내용 없음, 미구현, 중복 스캐폴드

현재 상태와 목표를 한 필드에 섞지 않는다. 각 항목에는 `current_deployment_method`, `target_deployment_method`, `migration_status`, `deployment_status`를 둔다. 상태는 `planned`, `prepared`, `awaiting_manual`, `deployed_unverified`, `verified`, `blocked`, `repository_only`, `excluded` 중 하나다. 목표 목적지가 있다는 이유만으로 `verified`나 `live_url`을 부여하지 않는다.

가능하면 저장 모델은 조합 가능한 두 축도 함께 둔다.

- `deployment_host`: `docker`, `vercel`, `github-pages`, `external`, `repository-only`, `excluded`
- `deployment_database`: `postgresql`, `supabase`, `sqlite`, `firebase`, `none`

화면의 `Docker + PostgreSQL`, `Vercel + Supabase`, `Docker + SQLite`, `Vercel 단일`, `GitHub Pages` 표시는 두 값을 조합해 만든다.

### 소유자가 확정한 호스팅 우선순위

아래 결정은 자동 추천보다 우선한다. 코드 근거가 달라져 실행이 불가능한 경우에만 `manual-actions`에 차이와 대안을 적고 기다린다.

- `junior-college-admission`은 OCI의 Docker + PostgreSQL 운영을 유지한다.
- `gpt-manager`는 OCI의 Docker + SQLite 운영을 유지한다. 현재 DB 컨테이너 없이 웹 컨테이너 하나와 SQLite 영속 볼륨만 사용한다. SQLite 백업·복원, 관리자 테스트 실행, OAuth, 기존 암호화 데이터 이전 비용을 감수하면서 Vercel + Supabase로 바꾸지 않는다. 소유자가 이 결정을 다시 열기 전에는 Supabase 수동 작업도 만들지 않는다.
- `gpt-vercel`은 `gpt-manager`의 운영 대체가 아니라 같은 요구를 Vercel + Firebase로 구현하는 독립 버전이다. 기존 Firebase Auth·Firestore·Vercel 구조를 유지하며 남은 핵심 기능만 완성한다. 두 앱의 운영 DB를 연결하거나 SQLite 데이터를 자동 이전·동기화하지 않는다.
- `ai-teaching-deck`은 정적 Vite 결과를 GitHub Pages로 옮기는 것을 우선한다. Pages의 빌드·다운로드·이미지 fallback·custom domain 검증을 통과할 수 없을 때만 Vercel 정적 배포를 대안으로 사용하며 OCI 컨테이너를 유지 대상으로 삼지 않는다.
- 포트폴리오 본체는 Flask/Jinja 콘텐츠를 빌드 시 정적 HTML로 생성해 GitHub Pages에 게시하는 방향을 우선한다. 검색·필터·상세 경로·404·접근성·canonical URL을 정적 환경에서 보존할 수 없을 때만 OCI 운영을 임시 대안으로 둔다.
- OCI의 기본 잔류 범위는 `junior-college-admission`의 web+PostgreSQL과 `gpt-manager` web이다. 공용 reverse proxy는 기존 호스트 구성을 재사용하고 프로젝트별 프록시를 중복 기동하지 않는다.
- GitHub Pages 전환과 실제 HTTPS 확인이 끝나기 전에는 기존 `ai-teaching-deck` 컨테이너를 자동 중단하거나 삭제하지 않는다.

### 현재 코드 감사에서 확인한 분류 시작점

아래 목록은 기존 인벤토리의 하드코딩보다 우선하는 조사 시작점이다. `현재 코드`와 `목표 배포`를 구분하며, 각 저장소를 다시 읽은 근거가 다르면 결과 JSON에 이유를 기록하고 조정한다.

- 현재 Docker + PostgreSQL 근거 있음 — `junior-college-admission`, `DjangoBlog`
- 현재 Docker + SQLite 근거 있음 — `gpt-manager`
- 현재 Docker 정적 Nginx 근거 있음 — `ai-teaching-deck`; 목표는 GitHub Pages
- PostgreSQL 백엔드 코드가 있지만 Docker 배포 미구성 — `nodebird`, `nodebird-api`, `ToDo`
- SQLite 백엔드 코드가 있지만 Docker 배포 미구성 — `hello_flask`
- Node.js·Socket.IO 앱이지만 Docker 배포 미구성 — `noom`
- `vercel-single` — `demo-app`, `fastapi_crud`, `My_Dashboard`, `RestfulServer`, `Router_express.js`
- `vercel-firebase` — `gpt-vercel`, `todo_260613`, `chatbot`
- `github-pages` — `2025_AIEdutech_Seoul`, `draw`, `memilmuk82-tour_Jap_Webapp`, `senschool-google-edu-plus`, `test_260613`, `tourism-japanese-ai-quiz`
- `external-platform` — `gpt-pro-shared-reservation-apps-script`, `whalespace-training`, `splash_screen`, `u_and_i`
- `repository-only` — `do_it_django`, `DjangoBlog2`, `2026-python-workbook`, `BardAPI_test2`, `CloneCoding_Noom`, `MapTime`, `School_Map`, `OpenAPI_project`, `andrej-karpathy-skills`, `chatgpt_image`, `gpt-share-manager`, `learn-express`, `learn-mongoose`, `learn-sequelize`, `nodecat`, `python_flask_2026`, `skel_web_env`, `curriculum-subject-overlap-check`
- `excluded` — `BardAPI_test`, `ChatGPT_api`, `Node.js_PostgreSQL`, `bambamti`, `flask-template`, `image_carousel`, `noom1`, `random_dice`, `subway_time`, `test`, `ui-practice`

현재 구현에서 바로 확정할 수 있는 `vercel-supabase` 프로젝트는 없다.

- `fastapi_crud`는 메모리 CRUD다.
- `My_Dashboard`는 전역 메모리 목록을 사용한다.
- `RestfulServer`는 인메모리 사용자 객체를 사용한다.

이 세 프로젝트에 영속성이 제품 요구가 아니라면 Supabase를 억지로 추가하지 않고 `vercel-single`로 유지한다. Supabase 사례를 새로 만들 필요가 있다면 `ToDo`가 PostgreSQL CRUD를 이미 사용해 기술적으로 가장 가까운 후보지만, 기존 `docker-postgresql` 방향을 바꾸는 결정이므로 자동 전환하지 않는다. `manual-actions`에 선택 근거와 영향을 적고 소유자 확인을 기다린다.

추가 정정 근거:

- `DjangoBlog`는 로컬 기본값만 보면 SQLite지만 Docker Compose 운영 구성은 PostgreSQL이다.
- `ToDo`의 SQLite는 테스트용이며 실제 실행 DB는 PostgreSQL이지만 Dockerfile·Compose는 확인되지 않았다.
- `ai-teaching-deck`은 정적 콘텐츠지만 현재 운영 근거는 Docker·Nginx·OCI와 custom URL이다.
- `BardAPI_test2`, `OpenAPI_project`는 표준 출력 기반 실험이므로 Vercel 앱으로 만들지 않는다.
- `nodecat`은 세션과 외부 NodeBird API 비밀값에 의존하므로 저장소 소개가 맞다.
- `curriculum-subject-overlap-check`는 현재 공개 허용된 저장소이지만 서비스 배포 대상은 아니다.

현재 인벤토리의 `do_it_django`는 `subdomain`이지만 사용자 확정은 `repository-only`이므로 명시적 수정 대상이다.

## `gpt-vercel` 전용 완성 계약

`gpt-vercel`은 빈 골격으로 가정하지 않는다. 현재 `main`에는 Vercel Python Runtime, Flask/Jinja, Firebase Auth session cookie, Firestore 서비스 계층, 예약·사용 기록·Gemini 프롬프트 점검·사용자 승인 흐름이 구현되어 있고 운영 URL 기록도 있다. README의 완료 문구만 신뢰하지 말고 실제 route, service, rule, test와 배포 smoke 근거를 대조한다.

### 비교와 수정 순서

1. `gpt-manager@master`는 기능 의미를 확인하는 읽기 전용 기준으로만 사용한다.
2. `gpt-vercel@main`에서 `구현됨 / 이번에 구현 / 서버리스 제약으로 보류` 기능표를 먼저 작성한다.
3. 이미 구현된 기능은 재작성하지 않고 호환성과 보안 경계만 확인한다.
4. 아래 P0를 한 항목씩 최소 수정하고 해당 기능의 관련 검사만 실행한다.
5. P0가 모두 통과하고 수동 게이트가 없을 때만 P1에서 실제 사용 가치가 높은 항목 최대 두 개를 고른다. 기능 수를 채우기 위해 구현하지 않는다.

### 유지할 현재 구조

- Firebase Web SDK 로그인·가입 → ID token → Firebase Admin session cookie
- Firebase auth cookie와 Flask flash/session cookie 분리
- Firestore의 `users`, `aiResources`, `reservations`, `usageLogs`, `userApiKeys`, `promptReviews`
- 예약 충돌을 막는 Firestore transaction과 사용자 소유권 검사
- 사용자별 Gemini API key의 서버 측 암호화 저장과 마스킹
- Flask/Jinja SSR, Vercel Python entrypoint, `/healthz`, 이용 안내·약관·개인정보 문서
- 관리자·보조관리자·일반 사용자 역할과 승인·대기·정지 상태

### P0 — 운영 마감에 필요한 최소 범위

- cookie 인증을 사용하는 상태 변경 POST에 CSRF 방어를 적용하고 정상 요청과 거부 요청을 각각 검증한다.
- production에서 `APP_ENCRYPTION_KEY`, Firebase Admin 자격 증명, 안전한 `SECRET_KEY`가 없으면 조용히 fallback하지 말고 시작 단계에서 실패한다.
- `E2E_TEST_MODE`와 모든 `E2E_TEST_*` 우회 설정이 production에서 활성화될 수 없게 한다.
- 관리자가 `aiResources`를 생성·수정·비활성화할 수 있는 최소 CRUD 또는 동등한 안전한 seed 절차를 제공한다. Firestore Console 수동 입력만이 정상 운영 절차가 되지 않게 한다.
- `/settings/api-key/test`는 단순 복호화 확인이 아니라 제한된 실제 Gemini 연결 검증으로 동작하게 하되 키 값·응답 원문을 로그에 남기지 않는다.
- 기존 예약 생성·충돌·완료 → 사용 기록 작성 → Gemini 프롬프트 점검 흐름이 깨지지 않게 한다.
- README와 전환 문서에는 실제 확인한 상태만 기록하고 `gpt-manager`와의 관계, 구현·보류 항목, 필요한 수동 설정을 갱신한다.

### P1 — P0 뒤에만 검토

- 월간 예약 보기와 최소 검색·상태 필터
- 프롬프트 점검 결과 검색 또는 Markdown 다운로드

개인 프로필, 월간 KPI, 다중 AI provider, 대규모 통계·보고서, 감사 로그 전체 UI는 실제 요구가 확인되기 전에는 구현하지 않는다.

### 이식하지 않을 항목

- SQLite 파일·최근 백업 20개·백업 복원·다운로드 UI
- SQLAlchemy·Alembic과 SQLite 데이터의 자동 이전·양방향 동기화
- Docker Compose, Gunicorn, Nginx, OCI 운영 파일
- 관리자 HTTP 요청 안에서 서버 전체 pytest를 실행하는 기능
- 자유 채팅형 챗봇, 공용 계정 ID·비밀번호 저장, 학생 개인정보

### Firebase·Vercel 수동 게이트

코드로 실제 상태를 확인할 수 없거나 콘솔 변경이 필요할 때만 `manual-actions`를 만든다. 기존 설정이 이미 검증되었다면 같은 작업을 다시 요구하지 않는다.

- Firebase Authentication의 Google 또는 실제 사용하는 provider 활성화
- Authorized domains에 Vercel 기본 도메인과 custom domain 등록
- Firestore DB·region, client 전면 deny를 유지하는 rules와 필요한 index 배포
- Firebase Web 설정과 Admin 자격 증명의 Preview·Production Vercel 환경 변수 분리
- `ALLOWED_GOOGLE_DOMAIN`, `ADMIN_EMAILS`, `APP_ENCRYPTION_KEY`와 cookie 환경 변수 이름 확인
- production에서 `E2E_TEST_MODE=false`이고 테스트 우회 변수가 등록되지 않았는지 확인
- 실제 허용 계정 한 개로 로그인·승인·예약·사용 기록·Gemini key 검증을 수행하는 최소 수동 smoke

비밀값, service account JSON, API key, session cookie는 이메일·로그·결과 파일에 쓰지 않는다. `gpt-manager`의 운영 데이터는 읽거나 복사하지 않는다.

## 실제 링크 검증과 포트폴리오 반영

각 프로젝트는 다음 순서를 통과해야 한다.

1. 인벤토리의 이름과 공개 GitHub `owner/name` 확인
2. 대상 저장소의 실제 코드·README·배포 설정 확인
3. 로컬 게시 준비와 프로젝트별 결과 JSON 작성
4. 필요한 수동 콘솔 작업 완료
5. 실제 HTTPS 링크 확인
6. 검증 결과만 포트폴리오 콘텐츠에 병합
7. 포트폴리오 테스트와 브라우저 검수

링크 검증 규칙은 다음과 같다.

- URL을 추측하지 않는다.
- HEAD가 불완전할 수 있으므로 필요하면 GET을 사용한다.
- 연결 시간 제한을 두고 리다이렉트를 추적하며 최대 한 번만 재시도한다.
- GitHub URL은 공개 접근과 정확한 `memilmuk82/<repository>` 이름을 확인한다.
- live·artifact URL은 최종 HTTPS URL과 최종 응답을 확인한다.
- 로그인형 앱은 로그인 진입 화면까지만 확인했다고 범위를 표시한다.
- 기본 Vercel 404, GitHub Pages 404, soft 404, 빈 placeholder를 성공으로 보지 않는다.
- Docker 앱은 가능한 경우 루트와 `/healthz`를 함께 확인한다.
- 네트워크 불가, 403, timeout은 `unverified`다. 통과로 기록하거나 `live_url`을 새로 공개하지 않는다.
- 결과에는 `checked_at`, `status_code`, `final_url`, `check_scope`, `result`를 기록한다.

인벤토리에는 실제 구조와 충돌하지 않는 범위에서 다음 필드를 도입한다.

- `current_deployment_method`, `target_deployment_method`, `migration_status`, `deployment_status`
- `related_years`, `relationship`
- `repository_url`, 확인된 경우에만 `live_url`·`artifact_url`
- `verification_status`, `verified_at`, `verification_note`

## GitHub Pages 정적 배포 계약

### 포트폴리오 본체

- Flask/Jinja는 빌드 시 콘텐츠를 검증하고 정적 HTML을 생성하는 도구로 사용할 수 있지만 GitHub Pages에서 Python 서버가 실행되는 것처럼 구성하지 않는다.
- 정적 출력 디렉터리와 한 개의 재현 가능한 build 명령을 둔다.
- 최소 출력은 `/index.html`, `/projects/index.html`, 공개 상세별 `/projects/<slug>/index.html`, `/activity/index.html`, `/about/index.html`, `/404.html`, 정적 CSS·JS·이미지다.
- JavaScript가 없어도 전체 아카이브와 상세 페이지를 읽고 저장소·실제 결과 링크로 이동할 수 있어야 한다. 검색·필터는 query string과 History API를 사용하는 점진적 향상 기능이어도 된다.
- Pages에서는 `/healthz`를 완료 조건으로 요구하지 않는다. 루트, 대표 상세, 404, CSS·JS asset의 정적 존재와 배포 응답을 확인한다. `/healthz`는 OCI Flask fallback에서만 유지한다.
- GitHub Actions는 정적 생성·필수 검사·Pages artifact 업로드만 담당하고 빌드 결과를 소스 브랜치에 반복 커밋하지 않는다.
- `www.memilmuk82.com` custom domain, apex 연결, HTTPS를 수동 게이트로 제공한다. Pages가 기본안이면 Nginx 예제는 OCI fallback 문서로 내린다.

### `ai-teaching-deck`

- `npm run validate`와 `npm run build`가 만든 Vite `dist/`를 GitHub Pages로 게시한다.
- project URL이면 Vite base path를 저장소 경로에 맞추고, `ai-teaching.memilmuk82.com`을 직접 연결하면 root base를 사용할 수 있다. 한 배포에서 두 경로를 모두 된다고 추정하지 않고 실제 선택에 맞춘다.
- hash slide route, 공개 curriculum download, 키보드 이동, 실제 이미지 또는 정적 placeholder를 확인한다. Nginx가 처리하던 누락 WebP fallback을 Pages에서 404가 나지 않는 정적 자산 또는 프론트 fallback으로 바꾼다.
- Pages 빌드·핵심 기능·custom domain이 검증되지 않을 때만 Vercel 정적 배포를 대안으로 준비한다.

## 2026 디자인 방향

### 목표 인상

`교육 기록을 기반으로 실제 서비스를 만드는 사람의 편집형 디지털 아카이브`라는 한 가지 시각적 관점을 사용한다. “개발자 포트폴리오 템플릿”이나 “AI가 만든 SaaS 랜딩 페이지”처럼 보이면 실패다.

### 시각 시스템

- 한국어 본문을 오래 읽어도 편한 타이포그래피 중심 설계
- 첫 화면은 짧은 역할 설명, 2020–2026 범위, `프로젝트 보기`와 `연도별 활동` 두 경로만 명확히 제공
- 데스크톱은 비대칭 편집 그리드와 넓은 여백, 모바일은 자연스러운 단일 열
- 현재의 종이색·잉크·코발트·시트론 정체성은 유지하되 더 깊은 명암과 절제된 사용으로 갱신
- `clamp()` 기반 유동 타이포그래피, `text-wrap: balance/pretty`, CSS Grid, container queries 등 안정적인 현대 CSS를 점진적으로 사용
- 선, 인덱스, 연도 레일, 저장소 상태와 같은 정보 요소를 시그니처 모티프로 사용
- 다크 모드는 시스템 설정을 기본으로 존중한다. 토글을 추가한다면 접근 가능하고 세션 간 상태가 안정적으로 유지될 때만 제공
- 아이콘은 한 계열의 SVG로 통일하고 텍스트 글리프 화살표를 남용하지 않는다.

### 2026다운 상호작용

- 작은 상태 변화, 필터 결과 전환, 링크 이동을 돕는 짧은 마이크로 인터랙션만 사용
- 지원 브라우저에서만 View Transitions 또는 scroll-driven animation을 점진적으로 적용할 수 있다.
- `prefers-reduced-motion`에서는 의미 손실 없이 움직임을 제거한다.
- 스크롤을 방해하는 패럴랙스, 커스텀 커서, 과도한 로딩 화면, 자동 재생 미디어는 사용하지 않는다.

### 피해야 할 상투적 표현

- 모든 콘텐츠를 둥근 카드와 중첩 패널로 감싸는 구성
- 의미 없는 bento grid
- 유리 질감, 네온 글로우, 거대한 그라디언트 구, AI 장식용 오브젝트
- 기술 로고 나열, 가짜 지표, 퍼센트, 숙련도 막대
- 과도한 pill·badge·eyebrow 문구
- 프로젝트마다 같은 카드 템플릿을 반복해 긴 저장소 이름과 설명을 자르는 방식

### 디자인 선행 및 충실도

- 이미지 생성 도구를 사용할 수 있으면 실제 콘텐츠를 사용한 디자인 콘셉트를 먼저 만든다.
- 최소 범위: 홈 데스크톱, 프로젝트 목록 데스크톱, 연도별 활동 데스크톱, 프로젝트 상세 데스크톱, 핵심 모바일 화면.
- 이미지 생성 도구가 없으면 빈 이미지를 만들지 말고 `docs/DESIGN_SPEC_2026.md`에 토큰, 타이포그래피, 그리드, 컴포넌트, 화면별 구조를 먼저 확정한다.
- 콘셉트에 없는 장식과 문구를 구현 단계에서 임의로 추가하지 않는다.
- 구현 후 브라우저 캡처와 콘셉트 또는 명세를 비교한 시각 검수 원장을 남긴다.

## 정보 구조

- `/`: 역할과 방향, 대표 프로젝트 4개 안팎, 2020–2026 변화 요약, 프로젝트 분류로 가는 경로
- `/activity`: 2020–2026 연도별 수업·연수·프로젝트 연결
- `/projects`: 대표 결과와 전체 저장소 아카이브, 검색·필터
- `/projects/<slug>`: 근거가 있는 상세 사례
- `/about`: 짧은 소개, 수업과 프로젝트를 연결하는 방식, GitHub 링크
- `/healthz`: 외부 의존성 없는 상태 확인 유지

헤더는 브랜드, `프로젝트`, `연도별 활동`, `소개`와 필요한 외부 GitHub 링크 정도로 단순하게 유지한다.

## 도메인·SEO·공유

- `https://www.memilmuk82.com`을 canonical로 사용하고 `https://memilmuk82.com`에서도 접근 가능하도록 배포 문서와 Nginx 예제를 정리한다.
- apex 도메인을 canonical 호스트로 301 리다이렉트하는 구성을 기본안으로 삼는다. 실제 DNS·Nginx 적용은 하지 않는다.
- canonical, Open Graph, 기본 Twitter 카드, sitemap, robots, 의미 있는 페이지 제목과 설명을 점검한다.
- 구조화 데이터는 실제 공개 내용만 사용하고 소속·성과를 창작하지 않는다.
- 공유 이미지가 없다면 깨진 URL이나 임시 이미지를 넣지 않는다.

## 접근성·성능

- WCAG 2.2 AA를 기준으로 의미론적 제목, 건너뛰기 링크, 키보드 순서, 포커스 표시, 대비를 검증한다.
- 일반 조작 영역은 모바일에서 44×44 CSS px를 목표로 하고, 최소 24×24 기준과 충분한 간격을 지킨다.
- 필터, 메뉴, 테마 토글은 상태 이름과 키보드 동작이 명확해야 한다.
- 핵심 콘텐츠와 링크는 JavaScript 없이도 사용할 수 있어야 한다.
- LCP·INP·CLS를 해치는 거대한 이미지, 렌더 차단 외부 폰트, 긴 메인 스레드 작업을 만들지 않는다.
- 외부 CDN 없이 운영하는 현재 장점을 우선 보존한다. 폰트를 새로 포함한다면 공개 라이선스, WOFF2, subset, preload 필요성을 함께 검토한다.

## 구현 우선순위

1. 기존 고정 수치와 공개 상태를 현재 기준으로 바로잡는다.
2. 활동 데이터를 Python 상수에서 분리해 검증 가능한 콘텐츠 파일로 옮기는 것을 우선 검토한다.
3. 2020–2026 연도별 페이지와 프로젝트 연결을 구현한다.
4. 인벤토리 스키마와 필터를 실제 방문자 관점으로 개선한다.
5. 홈과 프로젝트 상세의 대표 선정·연결 오류를 수정한다.
6. 2026 디자인 시스템으로 템플릿과 CSS를 개선한다.
7. 도메인 canonical, SEO, 접근성, 성능, 오류 화면을 정리한다.
8. README, `PROJECT_STATUS.md`, 활동 출처, QA·배포 문서와 테스트를 새 계약에 맞춘다.

## 금지 사항

- Notion 자료나 URL을 공개하지 않는다.
- 인벤토리에 없는 다른 저장소를 수정하지 않는다.
- 사용자 변경을 reset, checkout, clean, stash 또는 삭제하지 않는다.
- 비밀값, 실제 `.env`, DB 덤프, 서비스 계정, 개인·학생 데이터를 새로 복사하거나 출력하지 않는다.
- 테스트를 통과시키기 위해 검증을 약화하지 않는다.
- 전체 사이트를 React·Next.js로 재작성하지 않는다.
- `prepare` 실행에서는 Git commit, push, PR, 저장소 공개 범위와 모든 외부 서비스를 변경하지 않는다.
- `resume` 실행에서도 사용자가 완료했다고 확인한 설정은 검증만 한다. DNS, Nginx, 인증서, 방화벽, 운영 Docker, GitHub Pages, Vercel, Firebase, Supabase, Netlify의 외부 상태를 추가로 변경하지 않는다.

## 필수 검증

검사는 `변경한 동작을 증명하는 최소 범위`만 실행한다. 가능한 검사를 모두 돌리거나 횟수를 채우기 위해 같은 검사를 반복하지 않는다. 실행하지 않은 검사는 `미실행`과 이유를 기록하며 통과로 꾸미지 않는다.

공통 원칙:

- 미수정 저장소, 읽기 감사, `repository-only`, `excluded`에는 테스트를 실행하지 않는다.
- 새 테스트 프레임워크, 커버리지 목표, 전체 저장소 일괄 빌드, 부하·침투·대량 synthetic data 테스트를 추가하지 않는다.
- 첫 관련 검사 통과 시 해당 루프를 즉시 끝낸다. 실패하면 원인에 직접 관련된 최소 수정 후 실패한 검사만 다시 실행한다.
- 전체 test suite는 테스트 수가 작거나 공통 설정·스키마·라우팅을 바꿔 부분 검사로 회귀 범위를 보장할 수 없을 때만 한 번 실행한다.
- 네트워크 검사는 제한 시간과 최대 한 번의 재시도를 사용한다.

`gpt-vercel`을 수정한 경우:

- Python 구문·모듈 import와 `api.index:app` 진입점 로딩
- 기존 pytest가 작으므로 `uv run pytest -q` 한 번과 새 P0 회귀 테스트
- 미인증 핵심 경로 차단, 승인·정지·역할, 소유권, 예약 충돌 transaction, API key 암호화·마스킹·삭제, 새 CSRF·fail-fast 동작
- 기존 Playwright 핵심 3개는 인증·템플릿·브라우저 흐름을 실제로 바꾼 경우에만 한 번 실행한다. 브라우저를 새로 설치하기 위해 작업을 중단하지 않는다.
- Firebase Emulator는 Firestore transaction·rules를 수정했고 기존 emulator 구성이 실행 가능할 때만 사용한다.
- 실제 OAuth, 운영 Firestore 쓰기, 실제 Gemini 호출은 자동 테스트하지 않고 비밀값 없는 수동 smoke 항목으로 둔다.

포트폴리오 본체를 수정한 경우:

- JSON 변경: 해당 파일 `python -m json.tool`
- Python 콘텐츠·라우팅·정적 exporter 변경: 관련 pytest. 공통 콘텐츠 계약을 바꿨으면 작은 전체 pytest 한 번
- CSS·템플릿 변경: CSS build, 대표 데스크톱 1개와 모바일 1개 smoke
- 404, dark mode, reduced motion, 추가 viewport는 해당 코드를 수정한 경우에만 확인
- GitHub Pages 전환: 정적 build 후 필수 출력 경로와 내부 링크 검사

`ai-teaching-deck`을 수정한 경우:

- `npm run validate`
- `npm run build`
- Pages base path, hash slide 하나, curriculum download 하나, placeholder asset 하나의 정적 smoke

브라우저나 네트워크 제약이 있으면 테스트 클라이언트와 정적 검증으로 대체하고 그 범위를 명시한다.

## 완료 조건과 최종 보고

다음 조건을 모두 만족할 때만 완료로 선언한다.

- 2020–2026의 7개 연도가 사실 기준에 맞게 표시된다.
- `noom`과 Django 중복 관계가 정확하다.
- Notion 원문과 내부 링크가 공개 결과에 없다.
- 공개 추적 파일과 `RUN_DIR` 산출물에 Notion URL hostname이나 page ID가 없다.
- 프로젝트 인벤토리 대상 56개에 누락·중복이 없다.
- 기존 고정 분류 수치와 문서가 새 실제 분류와 일치한다.
- 현재 배포, 목표 배포, 이전 상태가 분리되어 있으며 검증된 URL만 `live_url`에 있다.
- OCI 기본 잔류 범위가 `junior-college-admission` web+PostgreSQL과 `gpt-manager` web의 세 컨테이너이며 다른 앱 컨테이너를 자동 추가하지 않는다.
- `gpt-manager`는 변경되지 않았고 `gpt-vercel`은 단일 writer만 수정했다.
- `gpt-vercel` P0가 관련 최소 검사를 통과했거나 근거 있는 `blocked`이며, 기능표와 서버리스 보류 항목이 남아 있다.
- 수동 설정이 남으면 완료로 꾸미지 않고 `awaiting_manual` 상태와 재개 명령을 제공한다.
- 홈의 대표 프로젝트가 명시적인 대표 기준을 따른다.
- 두 도메인의 canonical 운영안이 코드·문서·배포 예제에 일치한다.
- 포트폴리오와 `ai-teaching-deck`의 Pages 정적 출력이 검증되기 전 기존 운영 서비스를 중단하지 않는다.
- 2026 디자인 방향이 데스크톱과 모바일에 일관되게 적용된다.
- 가능한 자동 검사와 브라우저 검수가 완료된다.

최종 응답과 `FINAL_REPORT`에는 다음을 포함한다.

- 실제 수정 파일과 사용자에게 보이는 변화
- 새 프로젝트 분류 수와 제외 기준
- 연도별 콘텐츠 반영 결과
- 디자인 시스템과 반응형·접근성 결정
- 실행한 검사와 정확한 결과
- 실행하지 못한 검사와 이유
- 외부에서 사람이 수행해야 하는 배포 단계
- 보존한 기존 사용자 변경과 남은 문제
