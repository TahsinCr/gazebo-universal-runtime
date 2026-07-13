#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

./start-gazebo.sh web

if [[ -f .env ]]; then
  env_web_port="$(awk -F= '$1 == "WEB_PORT" {print $2; exit}' .env 2>/dev/null || true)"
  env_web_profile="$(awk -F= '$1 == "GAZEBO_WEB_PROFILE" {print $2; exit}' .env 2>/dev/null || true)"
fi

if command -v open >/dev/null 2>&1; then
  open "http://localhost:${WEB_PORT:-${env_web_port:-6080}}/?profile=${GAZEBO_WEB_PROFILE:-${env_web_profile:-fast}}"
fi
