#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_dir=$(CDPATH= cd -- "${script_dir}/.." && pwd)
domain=${PORTFOLIO_DOMAIN:-www.memilmuk82.com}

if [ "${domain}" != "www.memilmuk82.com" ]; then
    echo "PORTFOLIO_DOMAIN must be exactly www.memilmuk82.com" >&2
    exit 1
fi

for template in \
    "${script_dir}/nginx-www-bootstrap.conf.example" \
    "${script_dir}/nginx-www.conf.example"
do
    grep -Eq 'server_name[[:space:]]+www\.memilmuk82\.com;' "${template}"
    if grep -Eq 'server_name[[:space:]]+memilmuk82\.com([[:space:];])' "${template}"; then
        echo "Root domain must not be configured: ${template}" >&2
        exit 1
    fi
done

grep -Fq 'proxy_pass http://127.0.0.1:8001;' \
    "${script_dir}/nginx-www.conf.example"
grep -Fq '/etc/letsencrypt/live/www.memilmuk82.com/fullchain.pem' \
    "${script_dir}/nginx-www.conf.example"
grep -Fq '127.0.0.1:8000:8000' "${project_dir}/compose.yaml"
grep -Fq '127.0.0.1:8001:8000' "${project_dir}/deployment/compose.production.yaml"

if awk -F= '
    /^(PORTFOLIO_SECRET_KEY|LETSENCRYPT_EMAIL|CLOUDFLARE_ZONE_ID|CLOUDFLARE_API_TOKEN)=/ {
        if (length($2) != 0) exit 1
    }
' "${script_dir}/.env.production.example"; then
    :
else
    echo "Secret or deployment-specific values must remain blank in the example" >&2
    exit 1
fi

PORTFOLIO_SECRET_KEY=static-validation-only \
PORTFOLIO_IMAGE=memilmuk82-portfolio:local \
docker compose \
    --project-directory "${project_dir}" \
    -f "${project_dir}/compose.yaml" \
    -f "${script_dir}/compose.production.yaml" \
    config -q

echo "Deployment templates: PASS"
