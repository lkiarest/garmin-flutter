#!/bin/bash
set -e

# Usage: ./release.sh [version]
# Example: ./release.sh 1.0.2
# Must be run from project root (garmin_flutter/)

VERSION=${1:-}
if [ -z "$VERSION" ]; then
  echo "Usage: ./release.sh <version>"
  echo "Example: ./release.sh 1.0.2"
  exit 1
fi

TAG="v$VERSION"

echo "=== Building arm64 APK ==="
flutter build apk --release --target-platform android-arm64

APK="build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
if [ ! -f "$APK" ]; then
  echo "ERROR: APK not found at $APK"
  exit 1
fi

echo "=== Creating checksums ==="
sha1sum "$APK" > "${APK}.sha1"

echo "=== Creating GitHub Release ==="
gh release create "$TAG" \
  --title "Garmin Navigation $TAG" \
  --generate-notes \
  "$APK" "${APK}.sha1"

echo "=== Done! ==="
echo "Release: https://github.com/lkiarest/garmin-flutter/releases/tag/$TAG"