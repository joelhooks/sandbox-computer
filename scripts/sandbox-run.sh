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
set -euo pipefail

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
