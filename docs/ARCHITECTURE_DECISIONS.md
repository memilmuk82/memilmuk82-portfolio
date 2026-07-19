# 아키텍처 결정

최종 갱신: 2026-07-18

## ADR-001 — Flask 애플리케이션 팩토리와 Blueprint

앱은 `create_app()` 팩토리로 생성하고 공개 페이지와 상태 확인을 Blueprint로 분리한다. 테스트가 설정을 주입하고 각 기능의 URL·템플릿 책임을 분명히 할 수 있기 때문이다.

## ADR-002 — 파일 기반 공개 콘텐츠

MVP는 데이터베이스 없이 검증된 JSON을 읽는다. 콘텐츠 편집 빈도가 낮고 로그인·관리 화면 요구가 없으며, 공개 게이트를 테스트하기 쉽다. 원본 분류 로그와 참고 초안의 source JSON은 런타임·Git 산출물에 포함하지 않는다.

## ADR-003 — 서버 렌더링 우선 필터

`/projects?group=...&q=...`가 JavaScript 없이 동작한다. Vanilla JavaScript는 모바일 메뉴, 필터 자동 적용과 포커스 같은 점진적 향상만 담당한다.

## ADR-004 — Tailwind 빌드와 소규모 컴포넌트 CSS

Tailwind CSS CLI로 템플릿 사용 클래스를 빌드해 로컬 정적 파일로 제공한다. CDN은 사용하지 않는다. 반복되는 편집형 행·블루프린트처럼 클래스 조합이 긴 패턴은 `@layer components`에 의미 있는 클래스로 모은다.

## ADR-005 — 용도가 명시된 외부 링크

인벤토리의 외부 링크는 `repository_url`, `live_url`, `artifact_url`로 용도를 분리하고 HTTPS·무자격증명 URL만 허용한다. 56개 저장소의 로컬 Git remote와 현재 운영 URL을 대조해 확인된 연결만 표시하며, 제외 항목에는 외부 링크를 제공하지 않는다.

## ADR-006 — 운영 경계

Gunicorn이 고정 포트 8000에서 앱을 제공하고 Compose는 `127.0.0.1`에만 바인딩한다. Nginx, TLS, DNS는 저장소의 예제와 문서로만 준비하며 local 모드에서 운영 시스템을 변경하지 않는다.
