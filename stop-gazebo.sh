#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

compose=(docker compose -f docker-compose.yml)
if [[ -f .gazebo/gpu.compose.yml ]]; then
  compose+=(-f .gazebo/gpu.compose.yml)
fi

printf '[gazebo] Stopping containers...\n'
"${compose[@]}" --profile ui down --remove-orphans "$@"
printf '[gazebo] Stopped.\n'
