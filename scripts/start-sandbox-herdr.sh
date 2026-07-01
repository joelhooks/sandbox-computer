#!/usr/bin/env bash
# Start Herdr inside the sandbox container, pulling the published image
# first (falling back to a local build if the pull fails).
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

session_name="${SANDBOX_HERDR_SESSION:-sandbox-computer}"
workspace_label="${SANDBOX_HERDR_WORKSPACE_LABEL:-Sandbox}"
tab_label="${SANDBOX_HERDR_TAB_LABEL:-Start Here}"
image="${SANDBOX_IMAGE:-ghcr.io/joelhooks/sandbox-computer:latest}"
compose=(bash scripts/docker-compose.sh)

"${compose[@]}" version >/dev/null

if [[ "${SANDBOX_SKIP_PULL:-0}" != "1" ]]; then
  if docker image inspect "${image}" >/dev/null 2>&1; then
    echo "Checking for a newer sandbox image..."
    if ! "${compose[@]}" pull sandbox; then
      echo "Could not pull a newer image. Continuing with the local image already on this machine." >&2
    fi
  else
    echo "Pulling the sandbox image..."
    if ! "${compose[@]}" pull sandbox; then
      echo "Could not pull the sandbox image. Building it locally instead." >&2
      "${compose[@]}" build sandbox
    fi
  fi
fi

echo "Starting Herdr inside the sandbox container..."
echo "Herdr session: ${session_name}"
echo "Herdr workspace: ${workspace_label}"
echo "Herdr tab: ${tab_label}"

exec "${compose[@]}" run --rm \
  -e HERDR_SESSION="${session_name}" \
  -e HERDR_WORKSPACE_LABEL="${workspace_label}" \
  -e HERDR_TAB_LABEL="${tab_label}" \
  sandbox \
  zsh -lc 'cd /workspace && herdr --session "${HERDR_SESSION}"'
