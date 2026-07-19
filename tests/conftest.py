import pytest

from app import create_app


@pytest.fixture()
def app():
    return create_app(
        {
            "TESTING": True,
            "PORTFOLIO_EXECUTION_MODE": "local",
            "SECRET_KEY": "test-only-secret",
            "GITHUB_PROFILE_URL": "",
        }
    )


@pytest.fixture()
def client(app):
    return app.test_client()
