.PHONY: install css lint format-check test check run

install:
	uv sync --dev
	npm ci

css:
	npm run css:build

lint:
	uv run ruff check .

format-check:
	uv run ruff format --check .

test:
	uv run pytest

check: css lint format-check test

run:
	uv run flask --app 'app:create_app()' run --host 127.0.0.1 --port 8000
