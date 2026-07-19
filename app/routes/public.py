"""Server-rendered public portfolio routes."""

from __future__ import annotations

from flask import Blueprint, abort, current_app, render_template, request

from app.services.content import ContentRepository

public_blueprint = Blueprint("public", __name__)

ACTIVITIES = (
    {
        "title": "교육 현장 관찰",
        "description": "반복되는 업무와 판단 지점을 관찰하고 문제의 경계를 기록합니다.",
    },
    {
        "title": "Flask 웹앱 설계",
        "description": "역할과 데이터 흐름을 작은 서버 렌더링 서비스로 구조화합니다.",
    },
    {
        "title": "자동화 워크플로",
        "description": (
            "입력·승인·실패 조건을 명확히 나누고 재현 가능한 절차로 남깁니다."
        ),
    },
    {
        "title": "인프라와 배포",
        "description": (
            "애플리케이션과 리버스 프록시의 경계를 분명히 하고 배포를 준비합니다."
        ),
    },
    {
        "title": "검증과 품질",
        "description": "테스트와 접근성 검수로 결과를 확인하고 개선 근거를 축적합니다.",
    },
)

TEACHING_EVOLUTION = (
    {
        "period": "2020—2021",
        "title": "프로그래밍과 웹의 기초",
        "description": (
            "문법과 HTML·CSS·JavaScript를 익히고, 작은 결과를 직접 만들며 "
            "동작 원리를 설명하는 수업에 집중했습니다."
        ),
    },
    {
        "period": "2022—2023",
        "title": "서버·API·데이터로 확장",
        "description": (
            "Flask·Django·Express의 요청 흐름, CRUD와 데이터베이스, 공공·지도 "
            "데이터를 프로젝트와 연결했습니다."
        ),
    },
    {
        "period": "2024—2025",
        "title": "서비스와 에듀테크",
        "description": (
            "인증·배포·운영의 맥락을 더하고, 생성형 AI와 에듀테크를 수업 활동과 "
            "교육자료 제작에 적용하기 시작했습니다."
        ),
    },
    {
        "period": "2026",
        "title": "AI 활용에서 설계·검증으로",
        "description": (
            "Python·Flask 기초를 유지하면서 프롬프트 설계, 수업자료 자동화, "
            "테스트와 배포까지 하나의 프로젝트 흐름으로 가르칩니다."
        ),
    },
)


def _repository() -> ContentRepository:
    return current_app.extensions["content_repository"]


@public_blueprint.get("/favicon.ico")
def favicon():  # type: ignore[no-untyped-def]
    return current_app.send_static_file("images/favicon.svg")


@public_blueprint.get("/")
def home():  # type: ignore[no-untyped-def]
    repository = _repository()
    projects = repository.all_projects()
    return render_template(
        "home.html",
        featured_projects=projects[:3],
        activities=ACTIVITIES[:3],
    )


@public_blueprint.get("/projects")
def projects():  # type: ignore[no-untyped-def]
    repository = _repository()
    query = request.args.get("q", "").strip()
    group = request.args.get("group", "").strip()
    valid_groups = {item["value"] for item in repository.inventory_groups()}
    if group not in valid_groups:
        group = ""
    filtered = repository.filter_inventory(query=query, group=group)
    return render_template(
        "projects.html",
        projects=filtered,
        groups=repository.inventory_groups(),
        detail_slugs={project["slug"] for project in repository.all_projects()},
        filters={"q": query, "group": group},
    )


@public_blueprint.get("/projects/<slug>")
def project_detail(slug: str):  # type: ignore[no-untyped-def]
    repository = _repository()
    project = repository.get_project(slug)
    if project is None:
        abort(404)
    related = [item for item in repository.all_projects() if item["slug"] != slug][:2]
    return render_template(
        "project_detail.html", project=project, related_projects=related
    )


@public_blueprint.get("/activity")
def activity():  # type: ignore[no-untyped-def]
    return render_template(
        "activity.html",
        activities=ACTIVITIES,
        teaching_evolution=TEACHING_EVOLUTION,
    )


@public_blueprint.get("/about")
def about():  # type: ignore[no-untyped-def]
    return render_template("about.html", teaching_evolution=TEACHING_EVOLUTION)
