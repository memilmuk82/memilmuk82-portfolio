"""Portfolio application factory."""

from __future__ import annotations

import os
from collections.abc import Mapping
from typing import Any
from urllib.parse import urlsplit

from flask import Flask, render_template, request

from app.routes.health import health_blueprint
from app.routes.public import public_blueprint
from app.services.content import ContentRepository

DEFAULT_LOCAL_SECRET = "local-not-a-secret"
UNSAFE_PRODUCTION_SECRETS = frozenset({"", DEFAULT_LOCAL_SECRET, "change-me"})


def create_app(test_config: Mapping[str, Any] | None = None) -> Flask:
    """Create and configure the Flask application."""
    app = Flask(__name__, instance_relative_config=True)
    app.config.from_mapping(
        PORTFOLIO_EXECUTION_MODE=os.environ.get("PORTFOLIO_EXECUTION_MODE"),
        SECRET_KEY=os.environ.get("PORTFOLIO_SECRET_KEY", DEFAULT_LOCAL_SECRET),
        GITHUB_PROFILE_URL=os.environ.get("PORTFOLIO_GITHUB_URL", ""),
    )
    if test_config:
        app.config.from_mapping(test_config)
    app.config["PORTFOLIO_EXECUTION_MODE"] = _normalized_execution_mode(
        app.config["PORTFOLIO_EXECUTION_MODE"]
    )
    app.config["GITHUB_PROFILE_URL"] = _validated_profile_url(
        app.config["GITHUB_PROFILE_URL"]
    )
    _validate_runtime_config(app.config)

    app.extensions["content_repository"] = ContentRepository.from_package()
    app.register_blueprint(public_blueprint)
    app.register_blueprint(health_blueprint)

    @app.context_processor
    def inject_global_template_values() -> dict[str, str]:
        return {
            "github_profile_url": app.config["GITHUB_PROFILE_URL"],
            "current_path": request.path,
        }

    @app.after_request
    def set_security_headers(response):  # type: ignore[no-untyped-def]
        response.headers["Content-Security-Policy"] = "; ".join(
            (
                "default-src 'self'",
                "base-uri 'self'",
                "connect-src 'self'",
                "font-src 'self'",
                "form-action 'self'",
                "frame-ancestors 'none'",
                "img-src 'self' data:",
                "object-src 'none'",
                "script-src 'self'",
                "style-src 'self'",
            )
        )
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["Permissions-Policy"] = (
            "camera=(), geolocation=(), microphone=(), payment=(), usb=()"
        )
        return response

    @app.errorhandler(404)
    def not_found(_error):  # type: ignore[no-untyped-def]
        return render_template("errors/404.html"), 404

    @app.errorhandler(500)
    def internal_server_error(_error):  # type: ignore[no-untyped-def]
        return render_template("errors/500.html"), 500

    return app


def _normalized_execution_mode(raw_mode: object) -> str:
    """Normalize an unset or blank execution mode to local."""
    if not isinstance(raw_mode, str):
        return "local"
    return raw_mode.strip().lower() or "local"


def _validate_runtime_config(config: Mapping[str, Any]) -> None:
    """Reject known development secrets in production mode."""
    if config["PORTFOLIO_EXECUTION_MODE"] != "production":
        return
    secret = config.get("SECRET_KEY")
    if not isinstance(secret, str) or secret.strip() in UNSAFE_PRODUCTION_SECRETS:
        raise RuntimeError(
            "PORTFOLIO_SECRET_KEY must be set to a non-default value "
            "when PORTFOLIO_EXECUTION_MODE=production."
        )


def _validated_profile_url(raw_url: object) -> str:
    """Return only a credential-free absolute HTTPS profile URL."""
    if not isinstance(raw_url, str) or not raw_url:
        return ""
    try:
        parsed = urlsplit(raw_url)
        hostname = parsed.hostname
        username = parsed.username
        password = parsed.password
    except ValueError:
        return ""
    if (
        parsed.scheme != "https"
        or not hostname
        or username is not None
        or password is not None
    ):
        return ""
    return raw_url
