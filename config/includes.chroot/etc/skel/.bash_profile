# DaygleVE live image: on the console, auto-start the graphical installer
# session. This runs for the auto-logged-in live user on tty1; on any other
# tty (or once X is up) it does nothing, so a normal shell still works.
if [ -z "${DISPLAY:-}" ] && [ "$(tty)" = "/dev/tty1" ] && [ -x /usr/bin/startx ]; then
  # Keep the graphical installer as the live image's tty1 session. `xinit` is
  # installed explicitly rather than relying on xorg's recommends, and the
  # executable check leaves a usable console if a minimal rebuild omits it.
  exec /usr/bin/startx -- -nolisten tcp vt1
fi
