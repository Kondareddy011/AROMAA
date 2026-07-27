#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "=== Downloading Flutter SDK ==="
# Download stable Flutter SDK if not present
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

# Add Flutter to PATH
export PATH="$PATH:$(pwd)/flutter/bin"

echo "=== Checking Flutter Version ==="
flutter --version

echo "=== Enabling Web Build ==="
flutter config --enable-web

echo "=== Resolving Dependencies ==="
flutter pub get

echo "=== Building Web Application ==="
flutter build web --release

echo "=== Build Completed Successfully ==="
