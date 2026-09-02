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

# Preflight: fail with a clear message rather than a generic "command not
# found" partway through, which could leave a half-populated include tree.
if ! command -v gh >/dev/null 2>&1; then
  echo "!! the GitHub CLI (gh) is required but not installed" >&2
  exit 1
fi

INCLUDE="$ROOT/config/includes.chroot"
BIN_DEST="$INCLUDE/usr/bin/daygleve-backend"
WEB_DEST="$INCLUDE/usr/share/daygleve/web"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# Exact asset names for this version, matching the backend/frontend release
# workflows. Pinning the full name (not a wildcard) guarantees exactly one
# asset is selected, so the build is deterministic and never trips over a
# stray same-prefixed asset.
BACKEND_ASSET="daygleve-backend-${DAYGLEVE_VERSION}-x86_64-unknown-linux-gnu.tar.gz"
FRONTEND_ASSET="daygleve-frontend-${DAYGLEVE_VERSION}.tar.gz"

echo ">> DaygleVE ${DAYGLEVE_VERSION}"
echo ">> backend:  ${BACKEND_REPO} (${BACKEND_ASSET})"
echo ">> frontend: ${FRONTEND_REPO} (${FRONTEND_ASSET})"

# --- backend binary -------------------------------------------------------
echo ">> fetching backend binary…"
gh release download "$DAYGLEVE_VERSION" \
  --repo "$BACKEND_REPO" \
  --pattern "$BACKEND_ASSET" \
  --dir "$STAGE"
tar -xzf "$STAGE/$BACKEND_ASSET" -C "$STAGE"
install -Dm0755 "$STAGE/daygleve-backend" "$BIN_DEST"
echo "   -> $BIN_DEST"

# --- frontend static site -------------------------------------------------
echo ">> fetching frontend site…"
gh release download "$DAYGLEVE_VERSION" \
  --repo "$FRONTEND_REPO" \
  --pattern "$FRONTEND_ASSET" \
  --dir "$STAGE"
# Recreate the web root from scratch so nothing from a previous build (dotfiles
# included) is baked into the image. The directory is untracked and created
# here on demand.
rm -rf "${WEB_DEST:?}"
mkdir -p "$WEB_DEST"
tar -xzf "$STAGE/$FRONTEND_ASSET" -C "$WEB_DEST"
echo "   -> $WEB_DEST"

echo ">> artifacts staged."
