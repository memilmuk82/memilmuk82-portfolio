# GitHub 게시 준비 상태

검토일: 2026-07-18 (Asia/Seoul)
실행 모드: `local`
예정 원격: `memilmuk82/memilmuk82-portfolio`
예정 기본 브랜치: `main`
현재 판정: **외부 게시 불가 / 대체 로컬 Git 저장소와 로컬 커밋 완료**

## 1. 이번 실행에서 지킨 경계

- GitHub 저장소 생성, 원격 조회, `origin` 연결, push와 PR 생성을 수행하지 않았다.
- `gh auth status`, `gh api`, `gh repo view`도 호출하지 않았다. 현재 모드는 `local`이고 게시 허용 게이트가 닫혀 있어 인증·원격 상태 확인이 불필요하기 때문이다.
- 읽기 전용 `.git/` mount는 보존하고 `.git-local/`을 명시적으로 사용하는 독립 대체 저장소를 `main` 브랜치로 초기화했다. 파일별 검토 뒤 로컬 커밋까지 수행했다.
- 다른 프로젝트와 상위 디렉터리의 Git 설정을 변경하지 않았다.

## 2. 게시 게이트 상태

| 게이트 | 현재 확인값 | 판정 |
|---|---|---|
| 실행 모드 | `local` | 실패 — `github` 또는 `production` 필요 |
| 게시 명시 승인 | `PORTFOLIO_ALLOW_GITHUB_PUBLISH=NO` | 실패 — 정확히 `YES` 필요 |
| GitHub 소유자 | `memilmuk82` | 형식 일치 |
| GitHub 저장소명 | `memilmuk82-portfolio` | 형식 일치 |
| visibility | 미지정 | 실패 — `public` 또는 `private`를 사용자가 명시해야 함 |
| `gh` 설치 | 2.45.0 확인 | 통과 |
| `gh` 인증 | 확인하지 않음 | 대기 — 게시 게이트가 열린 실행에서만 확인 |
| 인증 계정 | 확인하지 않음 | 대기 — `gh api user --jq .login` 결과가 `memilmuk82`여야 함 |
| 로컬 Git 저장소 | `.git-local/`, `main`, 커밋 `7a2f882` | 명시적 `--git-dir` 사용 시 통과 |
| Ruff·포맷·pytest | pytest 30개 포함 통과 | 통과 |
| 콘텐츠·비밀 표식 | 공개 범위 검사 통과 | 통과(전용 이력 스캐너는 미실행) |
| Tailwind | 오프라인 `npm ci`와 CSS 빌드 통과 | 통과 |
| Docker | Compose 정적 검증 통과, 이미지 빌드는 소켓 권한 거부 | 환경 제약, 재실행 필요 |

위 조건 중 하나라도 실패하면 저장소 생성이나 push를 시도하지 않는다. 현재는 다수 조건이 실패하므로 외부 게시가 명시적으로 금지된다.

## 3. 로컬 Git 상태

프로젝트 루트의 `.git/`는 내용이 없는 읽기 전용 tmpfs mount다. 삭제·이동·덮어쓰지 않고 보존했다. 따라서 옵션 없는 다음 명령은 계속 `not a git repository`로 실패한다.

```bash
git rev-parse --is-inside-work-tree
git status -sb
git remote -v
```

이 제약을 우회하기 위해 프로젝트 내부 `.git-local/`을 Git metadata 전용 디렉터리로 초기화했다.

```bash
git --git-dir=.git-local --work-tree=. init --initial-branch=main
```

현재 읽기 전용 확인 결과:

```bash
git --git-dir=.git-local --work-tree=. rev-parse --is-inside-work-tree
# true
git --git-dir=.git-local --work-tree=. branch --show-current
# main
git --git-dir=.git-local --work-tree=. status --short --branch
# 7a2f882 feat: Flask 기반 포트폴리오 웹앱 구축
```

`origin`과 staged·unstaged 파일은 없으며 첫 커밋은 `7a2f882947bf999645872f54a4e550ba6205b8a6`이다. 이후 모든 로컬 Git 명령은 옵션 없는 `git`이 아니라 `git --git-dir=.git-local --work-tree=.` 형식을 사용해야 한다. `.git-local/`은 프로젝트 안에 둔 대체 Git metadata 디렉터리이며 `.gitignore`로 커밋 대상에서 제외했다.

## 4. 현재 변경 범위와 공개 위험

Flask 앱, Jinja 템플릿, 정제 프로젝트 JSON, CSS/JavaScript, 테스트, 배포 템플릿, 보고서와 콘셉트 이미지가 준비됐다. 오프라인 `npm ci`로 생성된 `node_modules/`는 `.gitignore` 대상이며 커밋하지 않는다. DB, 실제 `.env`, PEM과 개인키 파일은 발견되지 않았다.

고신뢰 패턴으로 현재 텍스트 파일을 검사한 결과 개인키 블록, 대표적인 클라우드 키, GitHub 토큰, OpenAI 키와 Google API 키 형태는 발견되지 않았다. 이 결과는 전용 비밀 탐지 도구나 Git 이력 검사를 대체하지 않는다.

`.gitignore`는 현재 다음 민감·생성 항목을 제외한다.

- `.env`
- `.venv/`, `node_modules/`
- Python 바이트코드와 pytest/Ruff 캐시
- `instance/`
- coverage 산출물

`.env.example`에는 환경 변수 이름과 비어 있는 값만 있다. 사용자 화면에 사용되는 `app/` 범위에서는 로컬 절대 경로와 내부 검토 표식이 발견되지 않았다. 정제 프로젝트 JSON은 승인된 4개 공개 설명만 포함하고 외부 URL을 넣지 않았다.

최종 로컬 검증에서 Ruff lint·format, Tailwind CSS, Flask `test_client` 핵심 경로, 콘텐츠·보안 헤더와 pytest 30개가 통과했다. 실제 비밀 파일과 고신뢰 키 패턴도 공개 범위 검사에서 발견되지 않았다. Gunicorn TCP 바인딩과 Docker 이미지는 각각 소켓 정책과 Docker API 권한 때문에 실행 검증하지 못했으며, 환경 제약과 재실행 명령은 최종·Docker 보고서에 남아 있다.

문서에는 감사 정책을 설명하기 위해 `projects.source.json`, `file://`, 분류 자료 같은 금지 문자열의 **이름**이 등장한다. 실제 로컬 절대 경로나 비밀값은 기록하지 않았다. 최종 공개 안전 검사는 사용자 화면·정적 번들뿐 아니라 문서가 비공개 저장소명을 새로 노출하지 않는지도 확인해야 한다.

## 5. 최종 검증 후 로컬 커밋 기록

대체 Git 저장소에서도 자동으로 전체 작업 트리를 staging하지 않았다. 먼저 아래 결과를 파일 단위로 검토했다.

```bash
git --git-dir=.git-local --work-tree=. status --short
find app tests docs deployment -type f -print 2>/dev/null | sort
find . -maxdepth 1 -type f -print | sort
```

그 다음 최종 75개 파일을 명시적으로 `git add -- <파일...>`에 전달했다. `git add -A`, 상위 디렉터리, 참고 프로젝트 경로와 와일드카드 staging은 사용하지 않았다. 대표 명령은 다음과 같다.

```bash
git --git-dir=.git-local --work-tree=. add -- .dockerignore .env.example .gitignore Dockerfile Makefile README.md PROJECT_STATUS.md compose.yaml package-lock.json package.json pyproject.toml requirements.lock tailwind.config.js wsgi.py
git --git-dir=.git-local --work-tree=. add -- app/__init__.py app/routes/__init__.py app/routes/health.py app/routes/public.py app/services/__init__.py app/services/content.py
git --git-dir=.git-local --work-tree=. add -- app/content/__init__.py app/content/projects.json
# 템플릿, 정적 파일, tests, docs, deployment도 검토한 파일명을 명시적으로 이어서 추가한다.

git --git-dir=.git-local --work-tree=. diff --cached --stat
git --git-dir=.git-local --work-tree=. diff --cached --check
git --git-dir=.git-local --work-tree=. status --short
```

최종 검증 문서와 실제 명령 결과, staged 경로, 비밀·로컬 경로 검사와 `diff --check`를 확인한 뒤 다음 메시지로 커밋했다.

```bash
git --git-dir=.git-local --work-tree=. commit -m "feat: Flask 기반 포트폴리오 웹앱 구축"
git --git-dir=.git-local --work-tree=. show --stat --oneline --decorate HEAD
git --git-dir=.git-local --work-tree=. status --short --branch
```

결과: `7a2f882947bf999645872f54a4e550ba6205b8a6`, 75개 파일, 커밋 직후 작업 트리 clean, 원격 0개.

커밋 전 최소 통과 조건은 Ruff/포맷 검사, pytest, Tailwind 프로덕션 빌드, Gunicorn과 핵심 경로 확인, 공개 콘텐츠 검사, 보안 헤더·외부 링크 검사, 가능한 브라우저 QA, Docker 빌드·헬스체크다. 환경 제약으로 미실행한 항목은 해당 보고서에 오류와 재실행 명령이 있어야 하며, 게시 게이트 6번에 따라 예외가 별도로 승인되지 않으면 push하지 않는다.

## 6. 향후 GitHub 게시 명령

아래는 이번 실행에서 수행하지 않는다. 최종 로컬 커밋과 검증이 완료된 뒤, 사용자가 visibility를 선택하고 새로운 `github` 또는 `production` 실행을 명시적으로 승인했을 때만 사용한다.

### 6.1 환경 게이트와 인증

```bash
export PORTFOLIO_EXECUTION_MODE=github
export PORTFOLIO_ALLOW_GITHUB_PUBLISH=YES
export PORTFOLIO_GITHUB_OWNER=memilmuk82
export PORTFOLIO_GITHUB_REPO=memilmuk82-portfolio
export PORTFOLIO_GITHUB_VISIBILITY=public  # 또는 private: 사용자가 반드시 하나를 선택

test "$PORTFOLIO_EXECUTION_MODE" = github -o "$PORTFOLIO_EXECUTION_MODE" = production
test "$PORTFOLIO_ALLOW_GITHUB_PUBLISH" = YES
test "$PORTFOLIO_GITHUB_OWNER" = memilmuk82
test "$PORTFOLIO_GITHUB_REPO" = memilmuk82-portfolio
case "$PORTFOLIO_GITHUB_VISIBILITY" in public|private) ;; *) exit 1 ;; esac

gh auth status
test "$(gh api user --jq .login)" = memilmuk82
```

인증이 실패하면 자동 로그인을 시도하지 않는다. 사용자가 대화형 로컬 셸에서 `gh auth login`을 마친 뒤 위 두 인증 명령을 다시 실행한다. 토큰을 명령 인수, URL, 로그나 파일에 쓰지 않는다.

### 6.2 같은 원격 저장소 존재 여부 확인

```bash
gh repo view memilmuk82/memilmuk82-portfolio \
  --json nameWithOwner,visibility,defaultBranchRef
```

- 성공하면 `nameWithOwner`가 정확히 `memilmuk82/memilmuk82-portfolio`인지 확인하고 새 저장소를 만들지 않는다.
- `not found`가 명확히 확인된 경우에만 다음 생성 명령을 사용한다.
- 인증, 네트워크, 권한 오류를 저장소 부재로 해석하지 않는다.

```bash
gh repo create memilmuk82/memilmuk82-portfolio \
  "--$PORTFOLIO_GITHUB_VISIBILITY"
```

### 6.3 기존 저장소에 origin 연결

원격이 이미 존재할 때는 현재 `gh` 전송 설정에 맞는 URL을 만들고, 기존 `origin`을 덮어쓰지 않는다.

```bash
case "$(gh config get git_protocol)" in
  ssh) remote_url='git@github.com:memilmuk82/memilmuk82-portfolio.git' ;;
  https) remote_url='https://github.com/memilmuk82/memilmuk82-portfolio.git' ;;
  *) exit 1 ;;
esac

if git --git-dir=.git-local --work-tree=. remote get-url origin >/dev/null 2>&1; then
  test "$(git --git-dir=.git-local --work-tree=. remote get-url origin)" = "$remote_url"
else
  git --git-dir=.git-local --work-tree=. remote add origin "$remote_url"
fi

git --git-dir=.git-local --work-tree=. remote -v
test "$(git --git-dir=.git-local --work-tree=. branch --show-current)" = main
```

기존 URL이 다르면 `git remote set-url`로 자동 교체하지 않는다. 소유권과 의도한 원격을 사용자가 확인한 뒤 별도 승인으로 처리한다.

### 6.4 push

```bash
git --git-dir=.git-local --work-tree=. status --short --branch
git --git-dir=.git-local --work-tree=. log -1 --oneline
git --git-dir=.git-local --work-tree=. push -u origin main
git --git-dir=.git-local --work-tree=. status --short --branch
```

강제 push는 사용하지 않는다. PR 생성은 이번 명세의 후속 최소 단계가 아니며, 사용자가 별도로 요청한 경우에만 진행한다.

## 7. 현재 남은 최소 작업

1. Git metadata가 읽기 전용 mount로 가려지지 않는 일반 환경에서 표준 `.git/` 저장소로 전환한다.
2. 원격 게시를 원할 때만 별도 실행에서 visibility와 게시 게이트를 제공한다.

현재 외부 대기 항목은 GitHub visibility 선택, 유효한 인증, 인증 계정 확인, 원격 존재 여부 확인과 명시적 게시 승인이다.
