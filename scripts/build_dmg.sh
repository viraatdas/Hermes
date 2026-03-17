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

VERSION="${VERSION:-}"
if [[ -z "${VERSION}" ]]; then
  if [[ -n "${GITHUB_REF_NAME:-}" ]]; then
    VERSION="${GITHUB_REF_NAME}"
  else
    VERSION="dev"
  fi
fi

DMG_NAME="${DMG_NAME:-Hermes-${VERSION}.dmg}"

xcodebuild \
  -project "${PROJECT_PATH}" \
  -scheme "${SCHEME}" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "${ARCHIVE_PATH}" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  archive

APP_PATH="${ARCHIVE_PATH}/Products/Applications/Hermes.app"
if [[ ! -d "${APP_PATH}" ]]; then
  echo "Expected app not found at: ${APP_PATH}" >&2
  exit 1
fi

DMG_STAGE="${BUILD_DIR}/dmg-stage"
mkdir -p "${DMG_STAGE}"
cp -R "${APP_PATH}" "${DMG_STAGE}/"

# Optional codesign for distribution (Developer ID Application)
if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  echo "Signing app with identity: ${CODESIGN_IDENTITY}"
  /usr/bin/codesign --force --options runtime --timestamp --entitlements "${ROOT_DIR}/Hermes/Hermes.entitlements" --sign "${CODESIGN_IDENTITY}" "${DMG_STAGE}/Hermes.app"
  /usr/bin/codesign --verify --deep --strict --verbose=2 "${DMG_STAGE}/Hermes.app"
else
  echo "No CODESIGN_IDENTITY provided; building unsigned DMG."
fi

# Create styled DMG using appdmg (works headless in CI — no AppleScript needed)
DMG_PATH="${DIST_DIR}/${DMG_NAME}"
npx appdmg "${ROOT_DIR}/scripts/dmg-config.json" "${DMG_PATH}"

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  echo "Signing DMG with identity: ${CODESIGN_IDENTITY}"
  /usr/bin/codesign --force --timestamp --sign "${CODESIGN_IDENTITY}" "${DMG_PATH}"
  /usr/bin/codesign --verify --verbose=2 "${DMG_PATH}"
fi

# Optional notarization (apple-id flow)
if [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" ]]; then
  echo "Submitting DMG for notarization..."
  xcrun notarytool submit "${DMG_PATH}" --apple-id "${APPLE_ID}" --team-id "${APPLE_TEAM_ID}" --password "${APPLE_APP_PASSWORD}" --wait
  xcrun stapler staple "${DMG_PATH}" || true
fi

echo "${DMG_PATH}"
