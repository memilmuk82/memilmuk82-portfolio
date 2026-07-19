"""Dependency-free health endpoint."""

from flask import Blueprint, Response

health_blueprint = Blueprint("health", __name__)


@health_blueprint.get("/healthz")
def healthz() -> Response:
    """Return a small response without loading external services."""
    return Response("ok\n", status=200, mimetype="text/plain")
