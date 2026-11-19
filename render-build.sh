#!/usr/bin/env bash
set -e

echo "=== Preparando compilación de Flutter Web ==="

# Instalar Flutter si no existe
if [ ! -d "$HOME/flutter" ]; then
  echo "Descargando Flutter SDK (stable)..."
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
fi

export PATH="$PATH:$HOME/flutter/bin"
flutter config --enable-web

echo "=== Compilando aplicacion Flutter ==="
cd usuarios
flutter pub get
flutter build web --release

echo "=== Actualizando carpeta public para despliegue ==="
cd ..
rm -rf public
cp -r usuarios/build/web public

echo "=== Compilacion finalizada exitosamente ==="
