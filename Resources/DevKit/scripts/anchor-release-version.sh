#!/bin/zsh

set -euo pipefail

VERSION="${VERSION:-}"

if [[ -z "$VERSION" ]]; then
  echo "[-] VERSION is not set (expected tag version like x.x.x)" >&2
  exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

PLISTS=(
  "$PROJECT_ROOT/FlowDown/Resources/InfoPlist/Info-Catalyst.plist"
  "$PROJECT_ROOT/FlowDown/Resources/InfoPlist/Info-iOS.plist"
)

for plist in "${PLISTS[@]}"; do
  if [[ ! -f "$plist" ]]; then
    echo "[anchor-version] skip missing plist: $plist"
    continue
  fi

  echo "[anchor-version] updating $plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion 0" "$plist"

  NEW_VER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$plist" 2>/dev/null || echo "")
  NEW_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$plist" 2>/dev/null || echo "")

  if [[ "$NEW_VER" != "$VERSION" ]]; then
    echo "[-] version mismatch in $plist (got $NEW_VER, expected $VERSION)" >&2
    exit 1
  fi
  if [[ "$NEW_BUILD" != "0" ]]; then
    echo "[-] build number mismatch in $plist (got $NEW_BUILD, expected 0)" >&2
    exit 1
  fi

  echo "[anchor-version] set version=$NEW_VER build=$NEW_BUILD"
done

echo "[anchor-version] completed"

