#!/usr/bin/env bash
#
# Download the pinned DaygleVE release artifacts and stage them into the
# live-build include tree so `lb build` bakes them into the image.
#
# Requires the GitHub CLI (`gh`) authenticated with read access to the backend
# and frontend repos. In CI set `GH_TOKEN` to a token that can read releases in
# both (a fine-grained PAT or an app token with Contents:read on those repos).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/versions.env"

INCLUDE="$ROOT/config/includes.chroot"
BIN_DEST="$INCLUDE/usr/bin/daygleve-backend"
WEB_DEST="$INCLUDE/usr/share/daygleve/web"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

echo ">> DaygleVE ${DAYGLEVE_VERSION}"
echo ">> backend:  ${BACKEND_REPO}"
echo ">> frontend: ${FRONTEND_REPO}"

# --- backend binary -------------------------------------------------------
echo ">> fetching backend binary…"
gh release download "$DAYGLEVE_VERSION" \
  --repo "$BACKEND_REPO" \
  --pattern 'daygleve-backend-*-x86_64-unknown-linux-gnu.tar.gz' \
  --dir "$STAGE"
tar -xzf "$STAGE"/daygleve-backend-*.tar.gz -C "$STAGE"
install -Dm0755 "$STAGE/daygleve-backend" "$BIN_DEST"
echo "   -> $BIN_DEST"

# --- frontend static site -------------------------------------------------
echo ">> fetching frontend site…"
gh release download "$DAYGLEVE_VERSION" \
  --repo "$FRONTEND_REPO" \
  --pattern 'daygleve-frontend-*.tar.gz' \
  --dir "$STAGE"
rm -rf "${WEB_DEST:?}/"* 2>/dev/null || true
mkdir -p "$WEB_DEST"
tar -xzf "$STAGE"/daygleve-frontend-*.tar.gz -C "$WEB_DEST"
echo "   -> $WEB_DEST"

echo ">> artifacts staged."
