# syntax=docker/dockerfile:1.7

ARG NODE_IMAGE=node:22-alpine
ARG PYTHON_IMAGE=python:3.12-slim-bookworm

FROM ${NODE_IMAGE} AS assets
WORKDIR /build

COPY package.json package-lock.json ./
RUN npm ci --ignore-scripts --no-audit --no-fund

COPY tailwind.config.js ./
COPY app/templates ./app/templates
COPY app/static/css/input.css ./app/static/css/input.css
COPY app/static/js ./app/static/js
RUN npm run css:build

FROM ${PYTHON_IMAGE} AS dependencies
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1
WORKDIR /build

COPY requirements.lock ./
RUN python -m venv /app/.venv \
    && /app/.venv/bin/python -m pip install --requirement requirements.lock

FROM ${PYTHON_IMAGE} AS runtime

ENV PATH=/app/.venv/bin:${PATH} \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000

RUN groupadd --gid 10001 portfolio \
    && useradd --uid 10001 --gid portfolio --no-create-home --shell /usr/sbin/nologin portfolio

WORKDIR /app
COPY --from=dependencies --chown=portfolio:portfolio /app/.venv /app/.venv
COPY --chown=portfolio:portfolio app /app/app
COPY --from=assets --chown=portfolio:portfolio /build/app/static/css/site.css /app/app/static/css/site.css
COPY --chown=portfolio:portfolio wsgi.py /app/wsgi.py

USER portfolio:portfolio
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/healthz', timeout=2).read()"]

CMD ["gunicorn", "--bind=0.0.0.0:8000", "--workers=2", "--threads=2", "--timeout=30", "--access-logfile=-", "--error-logfile=-", "wsgi:app"]
