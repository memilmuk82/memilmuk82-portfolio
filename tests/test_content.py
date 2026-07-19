import json
from importlib.resources import files

import pytest

from app.services.content import (
    ContentRepository,
    ContentValidationError,
    _validate_inventory_item,
)

APPROVED_SLUGS = {
    "junior-college-admission",
    "gpt-manager",
    "ai-teaching-deck",
    "whalespace-training",
}


def test_only_approved_projects_are_public():
    repository = ContentRepository.from_package()
    assert {project["slug"] for project in repository.all_projects()} == APPROVED_SLUGS
    assert all(
        project.get("repository_url", "").startswith("https://github.com/memilmuk82/")
        for project in repository.all_projects()
    )


def test_all_56_repositories_are_classified_without_duplicates():
    repository = ContentRepository.from_package()
    inventory = repository.all_inventory()
    assert len(inventory) == 56
    assert len({item["slug"] for item in inventory}) == 56
    assert len({item["name"] for item in inventory}) == 56
    assert {item["value"]: item["count"] for item in repository.inventory_groups()} == {
        "subdomain": 9,
        "site": 7,
        "source": 28,
        "excluded": 12,
    }


def test_manual_classification_decisions_are_applied():
    inventory = {
        item["slug"]: item for item in ContentRepository.from_package().all_inventory()
    }
    assert inventory["noom"]["group"] == "subdomain"
    assert "무DB" in inventory["noom"]["stack"]
    assert inventory["junior-college-admission"]["stack"].startswith("Flask ·")
    curriculum = inventory["curriculum-subject-overlap-check"]
    assert curriculum["group"] == "excluded"
    link_fields = {"repository_url", "live_url", "artifact_url"}
    assert not link_fields & curriculum.keys()
    assert all(
        not link_fields & item.keys()
        for item in inventory.values()
        if item["group"] == "excluded"
    )


def test_public_static_sites_include_verified_result_links():
    inventory = {
        item["slug"]: item for item in ContentRepository.from_package().all_inventory()
    }
    expected_live_urls = {
        "2025-aiedutech-seoul": "https://memilmuk82.github.io/2025_AIEdutech_Seoul/",
        "ai-teaching-deck": "https://ai-teaching.memilmuk82.com",
        "draw": "https://memilmuk82.github.io/draw/",
        "memilmuk82-tour-jap-webapp": "https://memilmuk82.github.io/memilmuk82-tour_Jap_Webapp/",
        "senschool-google-edu-plus": "https://memilmuk82.github.io/senschool-google-edu-plus/",
        "test-260613": "https://memilmuk82.github.io/test_260613/",
        "tourism-japanese-ai-quiz": "https://memilmuk82.github.io/tourism-japanese-ai-quiz/",
    }
    assert {
        slug: inventory[slug]["live_url"] for slug in expected_live_urls
    } == expected_live_urls


def test_review_flags_are_explicit_and_not_overclaimed():
    for project in ContentRepository.from_package().all_projects():
        assert project["public"] is True
        assert project["security_reviewed"] is False
        assert project["privacy_reviewed"] is False
        assert project["rights_reviewed"] is False
        assert project["links_reviewed"] is True


def test_public_content_excludes_sensitive_markers():
    forbidden = (
        "/opt/apps",
        "projects.source.json",
        "internal_notes",
        "private-project-placeholder",
        "PRIVATE KEY",
        "localhost",
    )
    for filename in ("projects.json", "project_inventory.json"):
        raw = files("app.content").joinpath(filename).read_text(encoding="utf-8")
        assert not any(marker in raw for marker in forbidden)


def test_schema_rejects_external_links(tmp_path):
    project = ContentRepository.from_package().all_projects()[0]
    project["links"] = ["http://example.com"]
    path = tmp_path / "invalid.json"
    path.write_text(json.dumps([project]), encoding="utf-8")
    with pytest.raises(ContentValidationError):
        ContentRepository.from_path(path)


def test_inventory_schema_rejects_private_links_and_sensitive_fields():
    inventory = {
        item["slug"]: item for item in ContentRepository.from_package().all_inventory()
    }
    curriculum = inventory["curriculum-subject-overlap-check"]

    with pytest.raises(ContentValidationError):
        _validate_inventory_item(
            {**curriculum, "repository_url": "https://example.com/private"}
        )
    with pytest.raises(ContentValidationError):
        _validate_inventory_item({**curriculum, "source_path": "/private/path"})
