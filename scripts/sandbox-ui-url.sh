#!/usr/bin/env bash
# The sandbox container serves the app; the host owns reachable URLs.
#
# Never ask a demo to build its own tunnel from inside Docker. Publish the
# port on the host (`docker compose run --service-ports sandbox`), then run
# this script on the host to print a local, tailnet, or public URL.
#
# Usage:
#   sandbox-ui-url.sh [--port PORT] [--serve] [--status]
#   SANDBOX_PUBLIC=1 sandbox-ui-url.sh --port PORT --serve   # Tailscale Funnel, opt-in only
set -euo pipefail

port="${SANDBOX_UI_PORT:-3000}"
mode="print"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --port)
      port="$2"
      shift 2
      ;;
    --serve)
      mode="serve"
      shift
      ;;
    --status)
      mode="status"
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

echo "Local:   http://localhost:${port}"

if [[ "${mode}" == "print" ]]; then
  echo
  echo "For a tailnet or public URL, rerun with --serve (needs \`tailscale\` on this host, not in the container)."
  exit 0
fi

if ! command -v tailscale >/dev/null 2>&1; then
  echo "tailscale is not installed on this host. Local URL above is the only one available." >&2
  exit 1
fi

if [[ "${mode}" == "status" ]]; then
  exec tailscale serve status
fi

if [[ "${SANDBOX_PUBLIC:-0}" == "1" ]]; then
  echo "Starting Tailscale Funnel (public) for port ${port}..."
  echo "Treat this as a temporary operator/demo surface, not a permanent public API."
  tailscale funnel --bg "${port}"
else
  echo "Starting Tailscale Serve (tailnet-only) for port ${port}..."
  tailscale serve --bg "${port}"
fi

tailscale serve status
