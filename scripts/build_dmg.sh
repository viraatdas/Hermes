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
ln -s /Applications "${DMG_STAGE}/Applications"

ICONSET_DIR="${BUILD_DIR}/Hermes.iconset"
ICNS_PATH="${BUILD_DIR}/Hermes.icns"
mkdir -p "${ICONSET_DIR}"

# Reuse existing app icon PNGs to create a DMG volume icon.
cp -f "${ROOT_DIR}/Hermes/Assets.xcassets/AppIcon.appiconset/"icon_*.png "${ICONSET_DIR}/" 2>/dev/null || true
if compgen -G "${ICONSET_DIR}/icon_*.png" > /dev/null; then
  iconutil -c icns "${ICONSET_DIR}" -o "${ICNS_PATH}" >/dev/null 2>&1 || true
fi

# Copy pre-made DMG background image (gold arrow, Hermes branding)
DMG_BG_DIR="${DMG_STAGE}/.background"
mkdir -p "${DMG_BG_DIR}"
cp "${ROOT_DIR}/scripts/dmg-background.png" "${DMG_BG_DIR}/background.png"

# Optional codesign for distribution (Developer ID Application)
if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  echo "Signing app with identity: ${CODESIGN_IDENTITY}"
  /usr/bin/codesign --force --options runtime --timestamp --entitlements "${ROOT_DIR}/Hermes/Hermes.entitlements" --sign "${CODESIGN_IDENTITY}" "${DMG_STAGE}/Hermes.app"
  /usr/bin/codesign --verify --deep --strict --verbose=2 "${DMG_STAGE}/Hermes.app"
else
  echo "No CODESIGN_IDENTITY provided; building unsigned DMG."
fi

# Create initial DMG (read-write) so we can customize the window
DMG_PATH="${DIST_DIR}/${DMG_NAME}"
TMP_DMG="${BUILD_DIR}/tmp-rw.dmg"

hdiutil create \
  -volname "Hermes" \
  -srcfolder "${DMG_STAGE}" \
  -ov \
  -format UDRW \
  "${TMP_DMG}"

# Mount and apply Finder window customization
MOUNT_DIR="${BUILD_DIR}/mnt"
mkdir -p "${MOUNT_DIR}"
DEVICE=$(hdiutil attach -readwrite -noverify -nobrowse -mountpoint "${MOUNT_DIR}" "${TMP_DMG}" | awk 'NR==1{print $1}')

# Set volume icon
if [[ -f "${ICNS_PATH}" ]]; then
  cp -f "${ICNS_PATH}" "${MOUNT_DIR}/.VolumeIcon.icns"
  xcrun SetFile -a C "${MOUNT_DIR}" || true
fi

# Apply Finder view settings via AppleScript for the drag-to-Applications layout
osascript <<APPLESCRIPT || true
tell application "Finder"
    tell disk "Hermes"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 760, 500}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 96
        set background picture of viewOptions to file ".background:background.png"
        set position of item "Hermes.app" of container window to {170, 200}
        set position of item "Applications" of container window to {490, 200}
        close
        open
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT

# Hide the background directory
xcrun SetFile -a V "${MOUNT_DIR}/.background" || true

hdiutil detach "${DEVICE}" -quiet || hdiutil detach "${MOUNT_DIR}" -quiet || true

# Convert to compressed read-only DMG
hdiutil convert "${TMP_DMG}" -format UDZO -o "${DMG_PATH}" -ov >/dev/null

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
