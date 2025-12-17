#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${ROOT_DIR}/Hermes.xcodeproj"
SCHEME="Hermes"

BUILD_DIR="${ROOT_DIR}/build"
DIST_DIR="${ROOT_DIR}/dist"

rm -rf "${BUILD_DIR}" "${DIST_DIR}"
mkdir -p "${BUILD_DIR}" "${DIST_DIR}"

ARCHIVE_PATH="${BUILD_DIR}/Hermes.xcarchive"

xcodebuild \
  -project "${PROJECT_PATH}" \
  -scheme "${SCHEME}" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "${ARCHIVE_PATH}" \
  archive

APP_PATH="${ARCHIVE_PATH}/Products/Applications/Hermes.app"
if [[ ! -d "${APP_PATH}" ]]; then
  echo "Expected app not found at: ${APP_PATH}" >&2
  exit 1
fi

DMG_STAGE="${BUILD_DIR}/dmg-stage"
mkdir -p "${DMG_STAGE}"
cp -R "${APP_PATH}" "${DMG_STAGE}/"
ln -s /Applications "${DMG_STAGE}/Applications"

DMG_PATH="${DIST_DIR}/Hermes.dmg"
hdiutil create \
  -volname "Hermes" \
  -srcfolder "${DMG_STAGE}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

echo "${DMG_PATH}"

