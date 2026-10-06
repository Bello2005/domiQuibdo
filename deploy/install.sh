#!/usr/bin/env bash
# Instala/levanta el backend de DomiQuibdó en un Ubuntu con Docker.
#
#   ./deploy/install.sh                 # por IP, solo HTTP
#   ./deploy/install.sh api.midominio.com   # con dominio: HTTPS automático (el DNS debe apuntar al servidor)
#
# Es seguro correrlo más de una vez: conserva deploy/.env y la base de datos.
set -euo pipefail

cd "$(dirname "$0")"
ENV_FILE=.env

say() { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  command -v sudo >/dev/null || die "Corre este script como root o instala sudo."
  SUDO="sudo"
fi

if ! command -v docker >/dev/null; then
  say "Instalando Docker (script oficial de Docker)…"
  curl -fsSL https://get.docker.com | $SUDO sh
fi
docker compose version >/dev/null 2>&1 || $SUDO docker compose version >/dev/null 2>&1 \
  || die "Falta el plugin 'docker compose'. En Ubuntu: sudo apt-get install -y docker-compose-plugin"

# Si el usuario aún no está en el grupo docker, usa sudo para los comandos de docker.
DOCKER="docker"
docker info >/dev/null 2>&1 || DOCKER="$SUDO docker"

if [ ! -f "$ENV_FILE" ]; then
  say "Creando deploy/.env con claves nuevas…"
  command -v openssl >/dev/null || die "Falta openssl (sudo apt-get install -y openssl)."

  TARGET="${1:-}"
  if [ -z "$TARGET" ]; then
    # IP pública si se puede saber; si no, la local.
    TARGET="$(curl -fsS -m 5 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')"
  fi

  if [[ "$TARGET" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    SITE_ADDRESS=":80"
    APP_URL="http://$TARGET"
  else
    SITE_ADDRESS="$TARGET"
    APP_URL="https://$TARGET"
  fi

  umask 077
  cat > "$ENV_FILE" <<ENV
SITE_ADDRESS=$SITE_ADDRESS
APP_URL=$APP_URL
APP_KEY=base64:$(openssl rand -base64 32)
DB_DATABASE=domiquibdo
DB_USERNAME=domiquibdo
DB_PASSWORD=$(openssl rand -hex 24)
APP_DEMO=true
PHP_WORKERS=4
ENV
fi

mkdir -p public/apk

say "Construyendo y levantando los contenedores (la primera vez tarda unos minutos)…"
$DOCKER compose up -d --build

say "Esperando a que el backend responda…"
for _ in $(seq 1 60); do
  if curl -fsS -m 3 http://localhost/up >/dev/null 2>&1; then OK=1; break; fi
  sleep 3
done
[ "${OK:-0}" = 1 ] || { $DOCKER compose logs --tail=40 app; die "El backend no respondió en /up. Revisa los logs de arriba."; }

APP_URL="$(grep '^APP_URL=' "$ENV_FILE" | cut -d= -f2-)"
say "Listo. Backend funcionando."
cat <<MSG

  API:            $APP_URL/api
  Verificación:   curl $APP_URL/up
  Cuentas demo:   cliente@demo.co · repartidor@demo.co · restaurante@demo.co · admin@demo.co  (contraseña: password)

  Siguiente paso, generar el APK apuntando a este servidor:
    ./deploy/build-apk.sh $APP_URL/api

  Actualizar después de cambios en el repo:  ./deploy/update.sh
MSG
