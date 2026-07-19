from pathlib import Path

import pytest

from app import DEFAULT_LOCAL_SECRET, create_app

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def test_unset_execution_mode_defaults_to_local(monkeypatch):
    monkeypatch.delenv("PORTFOLIO_EXECUTION_MODE", raising=False)
    monkeypatch.delenv("PORTFOLIO_SECRET_KEY", raising=False)

    app = create_app({"TESTING": True})

    assert app.config["PORTFOLIO_EXECUTION_MODE"] == "local"
    assert app.config["SECRET_KEY"] == DEFAULT_LOCAL_SECRET


@pytest.mark.parametrize("secret", [None, "", DEFAULT_LOCAL_SECRET, "change-me"])
def test_production_rejects_missing_or_known_local_secret(monkeypatch, secret):
    monkeypatch.setenv("PORTFOLIO_EXECUTION_MODE", "production")
    if secret is None:
        monkeypatch.delenv("PORTFOLIO_SECRET_KEY", raising=False)
    else:
        monkeypatch.setenv("PORTFOLIO_SECRET_KEY", secret)

    with pytest.raises(RuntimeError, match="PORTFOLIO_SECRET_KEY"):
        create_app({"TESTING": True})


def test_production_accepts_explicit_non_default_secret(monkeypatch):
    monkeypatch.setenv("PORTFOLIO_EXECUTION_MODE", " Production ")
    monkeypatch.setenv("PORTFOLIO_SECRET_KEY", "test-production-secret")

    app = create_app({"TESTING": True})

    assert app.config["PORTFOLIO_EXECUTION_MODE"] == "production"
    assert app.config["SECRET_KEY"] == "test-production-secret"


def test_production_compose_sets_execution_mode():
    overlay = (PROJECT_ROOT / "deployment" / "compose.production.yaml").read_text()

    assert "PORTFOLIO_EXECUTION_MODE: production" in overlay
