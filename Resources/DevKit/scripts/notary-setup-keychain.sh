#!/bin/zsh

set -euo pipefail

# Usage:
#   NOTARY_TOOLBOX_ZIP_BASE64=... NOTARY_TOOLBOX_PASSWORD=... \
#   ./notary-setup-keychain.sh <github_output_file> <github_env_file>
#
# The script will:
# - Decode the provided base64 zip into a temp dir
# - Locate the keychain file inside
# - Unlock the keychain and extract signing identities and notary profile
# - Emit outputs (for workflow) and append exports (for local use)

OUTPUT_FILE="${1:-}"
ENV_FILE="${2:-}"

log() {
  echo "[notary-setup] $*"
}

fatal() {
  echo "[-] $*" >&2
  exit 1
}

if [[ -z "${NOTARY_TOOLBOX_ZIP_BASE64:-}" ]]; then
  fatal "NOTARY_TOOLBOX_ZIP_BASE64 is not set"
fi

if [[ -z "${NOTARY_TOOLBOX_PASSWORD:-}" ]]; then
  fatal "NOTARY_TOOLBOX_PASSWORD is not set"
fi

TEMP_DIR=$(mktemp -d)
trap "rm -rf '$TEMP_DIR'" EXIT

ZIP_PATH="$TEMP_DIR/toolbox.zip"
log "decoding toolbox zip"
echo "${NOTARY_TOOLBOX_ZIP_BASE64}" | base64 -D > "$ZIP_PATH"

log "unpacking toolbox"
unzip -qo "$ZIP_PATH" -d "$TEMP_DIR/unpacked"

KEYCHAIN_PATH=$(find "$TEMP_DIR/unpacked" -type f -name "*.keychain*" | head -n 1)
if [[ -z "$KEYCHAIN_PATH" ]]; then
  fatal "no keychain file found after unpacking"
fi

KEYCHAIN_PATH=$(realpath "$KEYCHAIN_PATH")
log "found keychain at: $KEYCHAIN_PATH"

KEYCHAIN_DB="$KEYCHAIN_PATH"
KEYCHAIN_PASSWORD="$NOTARY_TOOLBOX_PASSWORD"

log "adding keychain to user search list"
CURRENT_KEYCHAINS=$(security list-keychains -d user | sed 's/"//g' | tr '\n' ' ')
security list-keychains -d user -s "$KEYCHAIN_DB" $CURRENT_KEYCHAINS

log "unlocking keychain"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_DB"

security set-keychain-settings -t 3600 -l "$KEYCHAIN_DB"

log "reading signing identity"
CODE_SIGNING_CONTENTS=$(security find-identity -v -p codesigning "$KEYCHAIN_DB")
DEVELOPER_ID_LINE=$(echo "$CODE_SIGNING_CONTENTS" | grep "Developer ID Application" | head -n 1)
CODE_SIGNING_IDENTITY=$(echo "$DEVELOPER_ID_LINE" | sed 's/.*"\(.*\)".*/\1/')
CODE_SIGNING_IDENTITY_HASH=$(echo "$DEVELOPER_ID_LINE" | awk '{print $2}')
CODE_SIGNING_TEAM=$(echo "$DEVELOPER_ID_LINE" | sed 's/.*(\(.*\)).*/\1/')

if [[ -z "$CODE_SIGNING_IDENTITY" || -z "$CODE_SIGNING_IDENTITY_HASH" || -z "$CODE_SIGNING_TEAM" ]]; then
  fatal "failed to extract signing identity/team from keychain"
fi

log "identity: $CODE_SIGNING_IDENTITY"
log "identity hash: $CODE_SIGNING_IDENTITY_HASH"
log "team: $CODE_SIGNING_TEAM"

log "reading notary profile"
NOTARIZE_KEYCHAIN_PROFILE=$(
  security dump-keychain -r "$KEYCHAIN_DB" | \
  strings | \
  grep "com.apple.gke.notary.tool.saved-creds" | \
  head -n 1 | \
  awk -F. '{print $NF}' | \
  tr -d '"'
)

if [[ -z "$NOTARIZE_KEYCHAIN_PROFILE" ]]; then
  fatal "failed to extract notary profile from keychain"
fi

log "notary profile: $NOTARIZE_KEYCHAIN_PROFILE"

# Prefer using the hash as signing identity for deterministic behavior
CODE_SIGNING_IDENTITY="$CODE_SIGNING_IDENTITY_HASH"

emit_output() {
  local key="$1"
  local value="$2"
  if [[ -n "$OUTPUT_FILE" ]]; then
    echo "${key}=${value}" >> "$OUTPUT_FILE"
  fi
}

emit_env() {
  local key="$1"
  local value="$2"
  if [[ -n "$ENV_FILE" ]]; then
    echo "${key}=${value}" >> "$ENV_FILE"
  fi
}

emit_output "keychain_db" "$KEYCHAIN_DB"
emit_output "code_signing_identity" "$CODE_SIGNING_IDENTITY"
emit_output "code_signing_team" "$CODE_SIGNING_TEAM"
emit_output "notarize_keychain_profile" "$NOTARIZE_KEYCHAIN_PROFILE"

emit_env "KEYCHAIN_DB" "$KEYCHAIN_DB"
emit_env "CODE_SIGNING_IDENTITY" "$CODE_SIGNING_IDENTITY"
emit_env "CODE_SIGNING_TEAM" "$CODE_SIGNING_TEAM"
emit_env "NOTARIZE_KEYCHAIN_PROFILE" "$NOTARIZE_KEYCHAIN_PROFILE"

log "setup completed successfully"

