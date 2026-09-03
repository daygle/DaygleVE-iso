#!/usr/bin/env bash
#
# Build the DaygleVE appliance ISO.
#
#   1. Fetch the pinned backend binary + frontend site (scripts/fetch-artifacts.sh).
#   2. Run live-build to produce a bootable hybrid ISO.
#
# Requirements (Debian/Ubuntu host or CI runner, run as root or via sudo):
#   live-build, xorriso, debootstrap, librsvg2-bin, and the GitHub CLI (`gh`).
# live-build needs root because it debootstraps and mounts a chroot.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
# shellcheck disable=SC1091
source "$ROOT/versions.env"

if [ "$(id -u)" -ne 0 ]; then
  echo "!! live-build must run as root; re-exec with sudo…" >&2
  exec sudo --preserve-env=GH_TOKEN,DAYGLEVE_VERSION "$0" "$@"
fi

echo "== DaygleVE ISO build : ${DAYGLEVE_VERSION} (${DEBIAN_SUITE}/${ARCH}) =="

# 1. Stage the release artifacts into config/includes.chroot.
"$ROOT/scripts/fetch-artifacts.sh"

# 2. Refresh the raster images used by GRUB/syslinux from the single SVG
#    source. Do not build with stale PNGs: the corrected layout must reach the
#    ISO even when this is a local build rather than the CI workflow.
SPLASH_SOURCE="$ROOT/config/bootloaders/isolinux/splash.svg"
if ! command -v rsvg-convert >/dev/null 2>&1; then
  echo "!! rsvg-convert is required to render the boot splash (install librsvg2-bin)" >&2
  exit 1
fi

echo ">> rendering boot splash..."
rsvg-convert -w 640 -h 480 "$SPLASH_SOURCE" \
  -o "$ROOT/config/bootloaders/isolinux/splash.png"
cp "$ROOT/config/bootloaders/isolinux/splash.png" \
  "$ROOT/config/bootloaders/grub-pc/splash.png"

# 3. Configure + build the image.
export DAYGLEVE_VERSION DEBIAN_SUITE ARCH
lb clean --purge
lb config
lb build

# 4. Name the output deterministically, failing fast if live-build produced no
#    ISO (or renamed it) so CI never "succeeds" with no artifact.
OUT="daygleve-${DAYGLEVE_VERSION}-${ARCH}.iso"
if [ -f "live-image-${ARCH}.hybrid.iso" ]; then
  mv -f "live-image-${ARCH}.hybrid.iso" "$OUT"
elif [ -f live-image-amd64.hybrid.iso ]; then
  mv -f live-image-amd64.hybrid.iso "$OUT"
else
  echo "!! expected live-build ISO not found (looked for live-image-${ARCH}.hybrid.iso)" >&2
  echo "   ISOs present:" >&2
  ls -1 ./*.iso 2>/dev/null >&2 || echo "   (none)" >&2
  exit 1
fi
echo "== built: ${OUT} =="
