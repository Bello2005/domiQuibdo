#!/usr/bin/env bash
# Genera el APK de DomiQuibdó en Ubuntu, apuntando al backend que le indiques.
#
#   ./deploy/build-apk.sh http://IP_DEL_SERVIDOR/api
#   ./deploy/build-apk.sh https://api.midominio.com/api
#
# Instala lo que falte (Java 17, Android SDK, Flutter), firma el APK con una llave propia
# y lo deja en deploy/public/apk/domiquibdo.apk (descargable en https://TU_SERVIDOR/apk/domiquibdo.apk).
set -euo pipefail

API_URL="${1:-}"
[ -n "$API_URL" ] || { echo "Uso: $0 http://IP_DEL_SERVIDOR/api"; exit 1; }
API_URL="${API_URL%/}"

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="$HOME/.domiquibdo-tools"
KEYS="$HOME/.domiquibdo-keys"
FLUTTER_DIR="$TOOLS/flutter"
ANDROID_HOME="$TOOLS/android-sdk"
export ANDROID_HOME ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$FLUTTER_DIR/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
export CI=true FLUTTER_SUPPRESS_ANALYTICS=true

say() { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }

SUDO=""
[ "$(id -u)" -eq 0 ] || SUDO="sudo"

say "Instalando dependencias del sistema (Java 17, git, unzip…)"
$SUDO apt-get update -qq
$SUDO apt-get install -y -qq openjdk-17-jdk-headless git curl unzip xz-utils zip libglu1-mesa >/dev/null
JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"
export JAVA_HOME

mkdir -p "$TOOLS" "$KEYS"
chmod 700 "$KEYS"

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  say "Descargando Flutter (stable)…"
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi

if [ ! -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]; then
  say "Descargando Android SDK (command-line tools)…"
  mkdir -p "$ANDROID_HOME/cmdline-tools"
  TMP="$(mktemp -d)"
  curl -fsSL -o "$TMP/tools.zip" https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
  unzip -q "$TMP/tools.zip" -d "$TMP"
  mv "$TMP/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
  rm -rf "$TMP"
fi

say "Aceptando licencias de Android…"
yes | sdkmanager --licenses >/dev/null 2>&1 || true
sdkmanager "platform-tools" >/dev/null
flutter config --android-sdk "$ANDROID_HOME" >/dev/null

# Gradle por defecto pide 8 GB de memoria; en servidores pequeños eso mata el build.
MEM_GB=$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)
if [ "$MEM_GB" -lt 8 ]; then
  say "Servidor con ~${MEM_GB} GB de RAM: limito la memoria de Gradle."
  mkdir -p "$HOME/.gradle"
  grep -q 'org.gradle.jvmargs' "$HOME/.gradle/gradle.properties" 2>/dev/null \
    || echo "org.gradle.jvmargs=-Xmx2g -XX:MaxMetaspaceSize=1g" >> "$HOME/.gradle/gradle.properties"
  [ "$MEM_GB" -ge 3 ] || echo "AVISO: con menos de 3 GB de RAM el build puede fallar; crea swap (sudo fallocate -l 4G /swapfile …)."
fi

# Llave de firma propia: se crea una sola vez y se reutiliza para poder actualizar la app después.
KEYSTORE="$KEYS/domiquibdo-release.jks"
PROPS="$REPO/app/android/key.properties"
if [ ! -f "$KEYSTORE" ]; then
  say "Creando la llave de firma (guárdala: sin ella no podrás actualizar la app instalada)…"
  PASS="$(openssl rand -hex 16)"
  keytool -genkeypair -v -keystore "$KEYSTORE" -alias domiquibdo -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass "$PASS" -keypass "$PASS" -dname "CN=DomiQuibdo, OU=UNICLARETIANA, O=DomiQuibdo, C=CO" >/dev/null 2>&1
  umask 077
  printf 'storePassword=%s\nkeyPassword=%s\nkeyAlias=domiquibdo\nstoreFile=%s\n' "$PASS" "$PASS" "$KEYSTORE" > "$KEYS/key.properties"
fi
cp "$KEYS/key.properties" "$PROPS"   # está en .gitignore, nunca se sube al repo

cd "$REPO/app"
say "Descargando dependencias de Flutter…"
flutter pub get

say "Compilando el APK (la primera vez tarda 10-20 min)…"
flutter build apk --release --dart-define=API_BASE_URL="$API_URL"

OUT="$REPO/deploy/public/apk"
mkdir -p "$OUT"
cp build/app/outputs/flutter-apk/app-release.apk "$OUT/domiquibdo.apk"

say "APK listo"
ls -lh "$OUT/domiquibdo.apk"
BASE="${API_URL%/api}"
cat <<MSG

  Archivo:      $OUT/domiquibdo.apk
  Descarga:     $BASE/apk/domiquibdo.apk   (ábrelo desde el celular e instala; hay que permitir "apps desconocidas")
  Backend:      $API_URL

  Respalda la llave de firma:  $KEYS
MSG
