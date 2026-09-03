# DaygleVE live image: on the console, auto-start the graphical installer
# session. Mirrors .bash_profile so the installer also launches when the live
# user's login shell is dash (which reads .profile, not .bash_profile); bash
# reads .bash_profile in preference and ignores this file. Runs only for the
# auto-logged-in live user on tty1; any other tty (or once X is up) gets a
# normal shell.
if [ -z "${DISPLAY:-}" ] && [ "$(tty)" = "/dev/tty1" ] && [ -x /usr/bin/startx ]; then
  exec /usr/bin/startx -- -nolisten tcp vt1
fi
