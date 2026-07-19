import pytest
from flask import abort

from app import create_app


def _create_test_app(**overrides):
    config = {
        "TESTING": True,
        "PORTFOLIO_EXECUTION_MODE": "local",
        "SECRET_KEY": "test-only-secret",
    }
    config.update(overrides)
    return create_app(config)


@pytest.mark.parametrize(
    ("path", "expected"),
    [
        ("/", "56개 프로젝트를"),
        ("/projects", "56개 프로젝트"),
        ("/projects/junior-college-admission", "해결하려던 문제"),
        ("/activity", "검증과 품질"),
        ("/about", "작업 방식"),
    ],
)
def test_public_routes(client, path, expected):
    response = client.get(path)
    assert response.status_code == 200
    assert expected in response.get_data(as_text=True)


def test_healthz_is_small_and_dependency_free(client):
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.get_data(as_text=True) == "ok\n"


def test_favicon_is_available(client):
    response = client.get("/favicon.ico")
    assert response.status_code == 200
    assert response.mimetype == "image/svg+xml"


def test_server_side_project_filters(client):
    response = client.get("/projects?group=site&q=프레젠테이션")
    body = response.get_data(as_text=True)
    assert "AI 수업 설계 웹 프레젠테이션" in body
    assert "생성형 AI 계정 운영 도구" not in body


def test_filtered_inventory_keeps_native_form_submission(client):
    body = client.get("/projects?group=subdomain").get_data(as_text=True)
    assert 'data-total-count="56"' in body
    assert body.count("data-project-row") == 9

    script = client.get("/static/js/site.js").get_data(as_text=True)
    assert "if (hasCompleteInventory)" in script
    assert "projectRows.length === Number(filterForm.dataset.totalCount)" in script


def test_teaching_evolution_is_visible():
    activity = _create_test_app().test_client().get("/activity").get_data(as_text=True)
    assert "2020—2021" in activity
    assert "2026" in activity
    assert "AI 활용에서 설계·검증으로" in activity

    about = _create_test_app().test_client().get("/about").get_data(as_text=True)
    assert "2020년부터 2026년까지" in about


def test_error_pages(client):
    assert client.get("/missing").status_code == 404

    error_app = _create_test_app(
        PROPAGATE_EXCEPTIONS=False,
        GITHUB_PROFILE_URL="",
    )

    @error_app.get("/_test/500")
    def force_error():
        abort(500)

    response = error_app.test_client().get("/_test/500")
    assert response.status_code == 500
    assert "잠시 문제가 생겼습니다" in response.get_data(as_text=True)


def test_security_headers(client):
    response = client.get("/")
    assert "frame-ancestors 'none'" in response.headers["Content-Security-Policy"]
    assert response.headers["X-Content-Type-Options"] == "nosniff"
    assert response.headers["X-Frame-Options"] == "DENY"
    assert response.headers["Referrer-Policy"] == "strict-origin-when-cross-origin"
    assert "camera=()" in response.headers["Permissions-Policy"]


def test_navigation_and_progressive_enhancement_contract(client):
    body = client.get("/projects").get_data(as_text=True)
    assert 'method="get"' in body
    assert 'aria-live="polite"' in body
    assert 'href="/activity"' in body
    assert 'target="_blank" rel="noopener noreferrer"' in body


def test_brand_and_static_site_result_links_are_rendered(client):
    home = client.get("/").get_data(as_text=True)
    projects = client.get("/projects?group=site").get_data(as_text=True)

    assert "MEMILMUK82" in home
    assert "MILIM" not in home
    assert 'href="https://memilmuk82.github.io/draw/"' in projects
    assert 'href="https://memilmuk82.github.io/senschool-google-edu-plus/"' in projects
    assert 'href="https://memilmuk82.github.io/test_260613/"' in projects


def test_page_name_is_not_rendered_after_document(client):
    body = client.get("/activity").get_data(as_text=True)
    assert body.rstrip().endswith("</html>")
    assert "현재: <strong>활동</strong>" in body


def test_mobile_menu_script_traps_focus(client):
    script = client.get("/static/js/site.js").get_data(as_text=True)
    assert 'event.key !== "Tab"' in script
    assert "focusableElements.at(-1)?.focus()" in script
    assert "focusableElements[0].focus()" in script


def test_valid_github_profile_url_is_rendered_safely():
    profile_url = "https://github.com/memilmuk82"
    app = _create_test_app(GITHUB_PROFILE_URL=profile_url)
    body = app.test_client().get("/about").get_data(as_text=True)
    assert f'href="{profile_url}"' in body
    assert 'target="_blank" rel="noopener noreferrer"' in body


@pytest.mark.parametrize(
    "profile_url",
    [
        "http://github.com/memilmuk82",
        "javascript:alert(1)",
        "//github.com/memilmuk82",
        "https://user:secret@github.com/memilmuk82",
        "https:///missing-host",
    ],
)
def test_invalid_github_profile_url_is_not_rendered(profile_url):
    app = _create_test_app(GITHUB_PROFILE_URL=profile_url)
    body = app.test_client().get("/about").get_data(as_text=True)
    assert profile_url not in body
    assert "소유권과 공개 범위를 확인한 연결만 제공합니다." in body
