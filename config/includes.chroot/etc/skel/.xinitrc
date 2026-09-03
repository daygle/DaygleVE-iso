#!/bin/sh
# DaygleVE installer session.
#
# Started by daygleve-live-session.service via `startx` as the live `user`.
# Calamares must run as root, so we (a) let root connect to this user-owned X
# server and (b) launch it under sudo. If Calamares fails to start or crashes,
# we surface its log on screen instead of leaving a black display.
set -u

LOG="${HOME:-/home/user}/calamares.log"

# Paint the brand background so "X is up but the installer failed" is visibly
# different from "X never started" (a truly black screen).
xsetroot -solid "#0f172a" 2>/dev/null || true

# Calamares runs as root; allow the root user to connect to this X server
# regardless of how XAUTHORITY propagates through sudo.
xhost +si:localuser:root 2>/dev/null || true

# Minimal window manager for decorations/placement.
openbox &

# Launch the installer as root, capturing all output for diagnosis.
sudo -n /usr/bin/calamares -d >"$LOG" 2>&1
rc=$?

# Clean finish -> end the session.
[ "$rc" -eq 0 ] && exit 0

# Otherwise, don't leave a black screen: show the failure so it can be read
# (or photographed) on real hardware and in VMs.
if command -v xterm >/dev/null 2>&1; then
  exec xterm -e sh -c \
    "printf 'DaygleVE installer exited (code %s).\n\nRecent log:\n\n' '$rc'; tail -n 80 '$LOG' 2>/dev/null; printf '\n\nPress Enter for a shell.\n'; read _; exec sh"
fi

# No terminal available: keep the WM (and brand background) up rather than dying.
wait
