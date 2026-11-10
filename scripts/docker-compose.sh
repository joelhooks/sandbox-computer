#!/usr/bin/env bash
# Run Docker Compose (v2 plugin or legacy docker-compose).
#
# Env passthrough: for `run`, SANDBOX_ENV is a space- or comma-separated list
# of variable NAMES to pass from your shell into the container, e.g.
#   SANDBOX_ENV="ANTHROPIC_BASE_URL" bash scripts/docker-compose.sh run --rm sandbox
# Each becomes `-e NAME`, so Compose reads the value from this process's
# environment: values never appear on the command line or in a file.
set -euo pipefail

if [[ "${1:-}" == "run" && -n "${SANDBOX_ENV:-}" ]]; then
  env_args=()
  read -r -a env_names <<<"${SANDBOX_ENV//,/ }"
  for name in ${env_names[@]+"${env_names[@]}"}; do
    if [[ ! "${name}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      echo "SANDBOX_ENV: '${name}' is not a valid variable name; skipping." >&2
      continue
    fi
    if [[ -z "${!name+x}" ]]; then
      echo "SANDBOX_ENV: ${name} is not set in this shell; skipping." >&2
      continue
    fi
    env_args+=(-e "${name}")
  done
  shift
  set -- run ${env_args[@]+"${env_args[@]}"} "$@"
fi

if ! command -v docker >/dev/null 2>&1; then
  cat >&2 <<'EOF'
Docker is required for the sandbox container path.

Install Docker Desktop or OrbStack, reopen your terminal, then retry.
EOF
  exit 127
fi

if docker compose version >/dev/null 2>&1; then
  exec docker compose "$@"
fi

if command -v docker-compose >/dev/null 2>&1; then
  exec docker-compose "$@"
fi

cat >&2 <<'EOF'
Docker Compose is required, but this machine does not have a Compose command available.

Checked both supported command shapes:

  docker compose version      # Docker Compose v2 plugin
  docker-compose version      # legacy standalone Compose

Fix options:

- Install or update Docker Desktop / OrbStack so `docker compose version` works.
- Or install the Docker Compose plugin for your Docker engine.
- Or install legacy `docker-compose` if that is the package your OS provides.
EOF
exit 127
