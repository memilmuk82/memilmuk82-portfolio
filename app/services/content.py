"""Validated public content loading and filtering."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from importlib.resources import files
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit

SLUG_PATTERN = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
REQUIRED_BOOLEAN_FIELDS = (
    "public",
    "security_reviewed",
    "privacy_reviewed",
    "rights_reviewed",
    "links_reviewed",
)
REQUIRED_TEXT_FIELDS = (
    "slug",
    "title",
    "summary",
    "problem",
    "decision",
    "contribution",
    "result",
    "maturity",
    "last_verified",
)

INVENTORY_GROUPS = {
    "subdomain": "서브도메인 웹앱",
    "site": "정적 사이트",
    "source": "소스·프로젝트 소개",
    "excluded": "비공개·제외",
}
INVENTORY_REQUIRED_TEXT_FIELDS = (
    "slug",
    "name",
    "title",
    "summary",
    "group",
    "stack",
    "destination",
)


class ContentValidationError(ValueError):
    """Raised when public content does not match the safe schema."""


@dataclass(frozen=True)
class ContentRepository:
    """Read-only public project repository."""

    projects: tuple[dict[str, Any], ...]
    inventory: tuple[dict[str, Any], ...] = ()

    @classmethod
    def from_package(cls) -> ContentRepository:
        content_root = files("app.content")
        project_path = Path(str(content_root.joinpath("projects.json")))
        inventory_path = Path(str(content_root.joinpath("project_inventory.json")))
        project_repository = cls.from_path(project_path)
        inventory_payload = json.loads(inventory_path.read_text(encoding="utf-8"))
        if not isinstance(inventory_payload, list):
            raise ContentValidationError(
                "프로젝트 인벤토리의 최상위 값은 배열이어야 합니다."
            )
        inventory = tuple(_validate_inventory_item(item) for item in inventory_payload)
        inventory_slugs = [item["slug"] for item in inventory]
        if len(inventory_slugs) != len(set(inventory_slugs)):
            raise ContentValidationError("인벤토리 slug는 중복될 수 없습니다.")
        inventory_names = [item["name"] for item in inventory]
        if len(inventory_names) != len(set(inventory_names)):
            raise ContentValidationError("인벤토리 저장소 이름은 중복될 수 없습니다.")
        return cls(project_repository.projects, inventory)

    @classmethod
    def from_path(cls, path: Path) -> ContentRepository:
        payload = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(payload, list):
            raise ContentValidationError(
                "프로젝트 콘텐츠의 최상위 값은 배열이어야 합니다."
            )
        validated = tuple(_validate_project(item) for item in payload)
        slugs = [item["slug"] for item in validated]
        if len(slugs) != len(set(slugs)):
            raise ContentValidationError("프로젝트 slug는 중복될 수 없습니다.")
        return cls(validated)

    def all_projects(self) -> list[dict[str, Any]]:
        return [dict(project) for project in self.projects if project["public"]]

    def get_project(self, slug: str) -> dict[str, Any] | None:
        return next(
            (dict(project) for project in self.projects if project["slug"] == slug),
            None,
        )

    def all_inventory(self) -> list[dict[str, Any]]:
        group_order = {group: index for index, group in enumerate(INVENTORY_GROUPS)}
        ordered = sorted(self.inventory, key=lambda item: group_order[item["group"]])
        return [dict(item) for item in ordered]

    def inventory_groups(self) -> list[dict[str, Any]]:
        counts = {
            group: sum(1 for item in self.inventory if item["group"] == group)
            for group in INVENTORY_GROUPS
        }
        return [
            {"value": group, "label": label, "count": counts[group]}
            for group, label in INVENTORY_GROUPS.items()
        ]

    def filter_inventory(
        self, *, query: str = "", group: str = ""
    ) -> list[dict[str, Any]]:
        normalized_query = query.casefold()
        results: list[dict[str, Any]] = []
        for item in self.all_inventory():
            searchable = " ".join(
                (
                    item["name"],
                    item["title"],
                    item["summary"],
                    item["stack"],
                    item["destination"],
                )
            ).casefold()
            if normalized_query and normalized_query not in searchable:
                continue
            if group and item["group"] != group:
                continue
            item["group_label"] = INVENTORY_GROUPS[item["group"]]
            results.append(item)
        return results

    def topics(self) -> list[str]:
        return sorted(
            {topic for project in self.projects for topic in project["topics"]}
        )

    def maturities(self) -> list[str]:
        return sorted({project["maturity"] for project in self.projects})

    def filter_projects(
        self, *, query: str = "", topic: str = "", maturity: str = ""
    ) -> list[dict[str, Any]]:
        normalized_query = query.casefold()
        results: list[dict[str, Any]] = []
        for project in self.all_projects():
            searchable = " ".join(
                (
                    project["title"],
                    project["summary"],
                    " ".join(project["technologies"]),
                    " ".join(project["topics"]),
                )
            ).casefold()
            if normalized_query and normalized_query not in searchable:
                continue
            if topic and topic not in project["topics"]:
                continue
            if maturity and maturity != project["maturity"]:
                continue
            results.append(project)
        return results


def _validate_project(raw: Any) -> dict[str, Any]:
    if not isinstance(raw, dict):
        raise ContentValidationError("각 프로젝트는 객체여야 합니다.")
    unexpected_sensitive_fields = {
        "internal_notes",
        "source_path",
        "private_repo",
    } & raw.keys()
    if unexpected_sensitive_fields:
        raise ContentValidationError(
            "내부 검토 필드는 공개 콘텐츠에 포함할 수 없습니다."
        )
    for field in REQUIRED_TEXT_FIELDS:
        if not isinstance(raw.get(field), str) or not raw[field].strip():
            raise ContentValidationError(
                f"{field}에는 비어 있지 않은 문자열이 필요합니다."
            )
    if not SLUG_PATTERN.fullmatch(raw["slug"]):
        raise ContentValidationError("slug 형식이 올바르지 않습니다.")
    for field in REQUIRED_BOOLEAN_FIELDS:
        if not isinstance(raw.get(field), bool):
            raise ContentValidationError(f"{field}에는 불리언 값이 필요합니다.")
    if raw["public"] is not True:
        raise ContentValidationError(
            "공개 콘텐츠 파일에는 승인된 항목만 둘 수 있습니다."
        )
    for field in ("technologies", "topics"):
        values = raw.get(field)
        if (
            not isinstance(values, list)
            or not values
            or not all(isinstance(value, str) and value.strip() for value in values)
        ):
            raise ContentValidationError(f"{field}에는 문자열 배열이 필요합니다.")
    if "links" in raw:
        raise ContentValidationError(
            "외부 링크는 용도가 명시된 URL 필드로만 제공해야 합니다."
        )
    for field in ("repository_url", "live_url", "artifact_url"):
        value = raw.get(field)
        if value is not None and not _is_safe_external_url(value):
            raise ContentValidationError(f"{field}가 안전한 HTTPS URL이 아닙니다.")
    return dict(raw)


def _validate_inventory_item(raw: Any) -> dict[str, Any]:
    if not isinstance(raw, dict):
        raise ContentValidationError("각 인벤토리 항목은 객체여야 합니다.")
    unexpected_sensitive_fields = {
        "internal_notes",
        "source_path",
        "private_repo",
    } & raw.keys()
    if unexpected_sensitive_fields:
        raise ContentValidationError(
            "내부 검토 필드는 공개 인벤토리에 포함할 수 없습니다."
        )
    if "links" in raw:
        raise ContentValidationError(
            "인벤토리 외부 링크는 용도가 명시된 URL 필드로만 제공해야 합니다."
        )
    for field in INVENTORY_REQUIRED_TEXT_FIELDS:
        if not isinstance(raw.get(field), str) or not raw[field].strip():
            raise ContentValidationError(
                f"인벤토리 {field}에는 비어 있지 않은 문자열이 필요합니다."
            )
    if not SLUG_PATTERN.fullmatch(raw["slug"]):
        raise ContentValidationError("인벤토리 slug 형식이 올바르지 않습니다.")
    if raw["group"] not in INVENTORY_GROUPS:
        raise ContentValidationError("알 수 없는 프로젝트 분류입니다.")
    if not isinstance(raw.get("featured"), bool):
        raise ContentValidationError("featured에는 불리언 값이 필요합니다.")
    for field in ("repository_url", "live_url", "artifact_url"):
        value = raw.get(field)
        if value is not None and not _is_safe_external_url(value):
            raise ContentValidationError(f"인벤토리 {field}가 안전하지 않습니다.")
    if raw["group"] == "excluded" and any(
        field in raw for field in ("repository_url", "live_url", "artifact_url")
    ):
        raise ContentValidationError(
            "비공개·제외 항목에는 외부 링크를 제공할 수 없습니다."
        )
    return dict(raw)


def _is_safe_external_url(value: Any) -> bool:
    if not isinstance(value, str) or not value:
        return False
    try:
        parsed = urlsplit(value)
    except ValueError:
        return False
    return (
        parsed.scheme == "https"
        and bool(parsed.hostname)
        and parsed.username is None
        and parsed.password is None
    )
