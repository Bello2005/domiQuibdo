#!/usr/bin/env bash
# Trae lo último de la rama actual y reconstruye el backend (las migraciones corren solas al arrancar).
set -euo pipefail
cd "$(dirname "$0")"

git pull --ff-only
DOCKER="docker"
docker info >/dev/null 2>&1 || DOCKER="sudo docker"
$DOCKER compose up -d --build
$DOCKER compose ps
