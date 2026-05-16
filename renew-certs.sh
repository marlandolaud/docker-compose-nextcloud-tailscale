#!/bin/bash
set -e
cd "$(dirname "$0")"
set -a
source .env
set +a
docker compose exec -T tailscale tailscale cert \
  --cert-file /tmp/ts.crt \
  --key-file /tmp/ts.key \
  "${NC_DOMAIN}"
docker compose exec -T caddy caddy reload --config /etc/caddy/Caddyfile
