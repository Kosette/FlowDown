#!/bin/zsh

set -euo pipefail

# Archives FlowDown macOS (Catalyst) with xcbeautify output.
# Env:
#   CODE_SIGNING_IDENTITY (optional)
#   CODE_SIGNING_TEAM (optional)
#   KEYCHAIN_DB (optional) -> passed via OTHER_CODE_SIGN_FLAGS

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

cd "$PROJECT_ROOT"

WORKSPACE="FlowDown.xcworkspace"
SCHEME="FlowDown"
ARCHIVE_PATH="${PROJECT_ROOT}/BuildArtifacts/FlowDown-macos.xcarchive"
RESULT_BUNDLE="${PROJECT_ROOT}/BuildArtifacts/macos-notary.xcresult"

mkdir -p "${PROJECT_ROOT}/BuildArtifacts"

ARGS=(
  -workspace "$WORKSPACE"
  -scheme "$SCHEME"
  -configuration Release
  -destination 'platform=macOS,variant=Mac Catalyst'
  archive
  -archivePath "$ARCHIVE_PATH"
  -resultBundlePath "$RESULT_BUNDLE"
  PROVISIONING_PROFILE_SPECIFIER=""
  -skipPackagePluginValidation
  -skipMacroValidation
)

if [[ -n "${CODE_SIGNING_IDENTITY:-}" && -n "${CODE_SIGNING_TEAM:-}" ]]; then
  echo "[*] archiving with code signing"
  ARGS+=(
    CODE_SIGN_STYLE=Manual
    CODE_SIGN_IDENTITY="${CODE_SIGNING_IDENTITY}"
    DEVELOPMENT_TEAM="${CODE_SIGNING_TEAM}"
  )
  if [[ -n "${KEYCHAIN_DB:-}" ]]; then
    ARGS+=(OTHER_CODE_SIGN_FLAGS="--keychain ${KEYCHAIN_DB}")
  fi
else
  echo "[*] archiving without explicit code signing"
  ARGS+=(
    CODE_SIGN_STYLE=Manual
    CODE_SIGNING_ALLOWED=NO
    CODE_SIGN_IDENTITY=""
  )
fi

echo "[*] running xcodebuild (xcbeautify)..."
xcodebuild "${ARGS[@]}" | xcbeautify --is-ci --disable-colored-output --disable-logging

echo "[+] archive generated at $ARCHIVE_PATH"
echo "[+] xcresult at $RESULT_BUNDLE"

