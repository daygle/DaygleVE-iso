# DaygleVE live image: on the console, auto-start the graphical installer
# session. This runs for the auto-logged-in live user on tty1; on any other
# tty (or once X is up) it does nothing, so a normal shell still works.
if [ -z "${DISPLAY:-}" ] && [ "$(tty)" = "/dev/tty1" ]; then
  exec startx
fi
