#!/bin/zsh

set -euo pipefail

log() {
  echo "[select-xcode] $*"
}

APPLICATIONS_DIR="/Applications"

log "scanning $APPLICATIONS_DIR for Xcode installations"
mapfile -t XCODES < <(find "$APPLICATIONS_DIR" -maxdepth 1 -type d -name "Xcode*.app" -print | sort)

if [[ ${#XCODES[@]} -eq 0 ]]; then
  echo "[-] no Xcode installations found under $APPLICATIONS_DIR" >&2
  exit 1
fi

CANDIDATES=()
for xcode_path in "${XCODES[@]}"; do
  INFO_PLIST="$xcode_path/Contents/Info.plist"
  if [[ ! -f "$INFO_PLIST" ]]; then
    log "skipping $xcode_path (no Info.plist)"
    continue
  fi
  VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || true)
  BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST" 2>/dev/null || true)
  if [[ -z "$VERSION" ]]; then
    log "skipping $xcode_path (no version)"
    continue
  fi
  CANDIDATES+=("${VERSION}\t${BUILD}\t${xcode_path}")
done

if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
  echo "[-] no Xcode installations with readable versions found" >&2
  exit 1
fi

printf "%s\n" "${CANDIDATES[@]}" | sort -t $'\t' -k1,1V -k2,2V | tail -n 1 | while IFS=$'\t' read -r VER BUILD PATH; do
  log "selecting Xcode ${VER} (build ${BUILD}) at ${PATH}"
  sudo xcode-select -s "${PATH}/Contents/Developer"
  log "xcode-select set to $(xcode-select -p)"
  xcodebuild -version
done

