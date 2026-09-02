#!/bin/sh
# Minimal installer session: a lightweight window manager plus the DaygleVE
# (Calamares) installer, launched as root. When the installer exits, X exits
# and the user is returned to the live console.
openbox &
exec sudo calamares
