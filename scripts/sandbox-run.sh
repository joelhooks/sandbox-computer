#!/usr/bin/env bash
# Zero-footprint sandbox launcher: mount any directory into the sandbox
# without scaffolding template files into it. Use this for ad-hoc cleanroom
# work; use sandbox-init.sh when the project should own its sandbox setup.
#
# Auth/state lives in the same fixed-name Docker volumes the compose
# template uses (sandbox-pi, sandbox-claude, ...), so one login per machine
# covers both this script and every compose-scaffolded project.
#
# Usage: sandbox-run.sh [shell|pi|herdr] [project_dir]
#   project_dir defaults to $PWD.
#
# Env passthrough: SANDBOX_ENV is a space- or comma-separated list of variable
# NAMES to pass from your shell into the container, e.g.
#   SANDBOX_ENV="ANTHROPIC_BASE_URL ANTHROPIC_API_KEY" sandbox-run.sh pi .
# Each becomes `docker run -e NAME`, so Docker reads the value from this
# process's environment: values never appear on the command line, in a file,
# or in the image. Unset names are skipped with a warning.
set -euo pipefail

env_args=()
sandbox_env="${SANDBOX_ENV:-}"
read -r -a env_names <<<"${sandbox_env//,/ }"
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

mode="${1:-shell}"
project_dir="$(cd "${2:-$PWD}" && pwd)"
image="${SANDBOX_IMAGE:-ghcr.io/joelhooks/sandbox-computer:latest}"

if ! docker image inspect "${image}" >/dev/null 2>&1; then
  echo "Pulling the sandbox image..."
  if ! docker pull "${image}"; then
    echo "Could not pull ${image}. Build it locally from the sandbox-computer repo:" >&2
    echo "  bash scripts/docker-compose.sh build sandbox" >&2
    exit 1
  fi
fi

docker_args=(
  docker run --rm -it
  -e SHELL=/usr/bin/zsh
  -e TERM=xterm-256color
  ${env_args[@]+"${env_args[@]}"}
  -v "${project_dir}:/workspace"
  -v sandbox-pi:/home/sandbox/.pi
  -v sandbox-claude:/home/sandbox/.claude
  -v sandbox-codex:/home/sandbox/.codex
  -v sandbox-opencode:/home/sandbox/.opencode
  -v sandbox-herdr:/home/sandbox/.config/herdr
  -v sandbox-pnpm-store:/home/sandbox/.local/share/pnpm/store
  -w /workspace
  "${image}"
)

case "${mode}" in
  shell)
    exec "${docker_args[@]}" zsh
    ;;
  pi)
    exec "${docker_args[@]}" zsh -lc "pi; echo; echo 'Pi exited. Dropping into a shell.'; exec \${SHELL:-/usr/bin/zsh} -l"
    ;;
  herdr)
    exec "${docker_args[@]}" zsh -lc 'herdr --session sandbox'
    ;;
  *)
    echo "Unknown mode: ${mode}" >&2
    echo "Usage: $0 [shell|pi|herdr] [project_dir]" >&2
    exit 1
    ;;
esac
