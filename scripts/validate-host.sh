#!/usr/bin/env bash
# Validate the installed DaygleVE broker boundary on a disposable Linux host.
# This script never mutates host state; it only inspects services, permissions,
# profiles, and optionally runs the read-only broker posture endpoint check.
set -euo pipefail

fail=0
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "FAIL: missing command: $1" >&2; fail=1; }
}
check_eq() {
  local label=$1 actual=$2 expected=$3
  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL: $label: expected '$expected', got '$actual'" >&2
    fail=1
  else
    echo "PASS: $label=$actual"
  fi
}

for cmd in systemctl aa-status stat getent id; do require_cmd "$cmd"; done
(( fail == 0 )) || exit 1

for unit in daygleve-broker.service daygleve-backend.service; do
  systemctl is-enabled --quiet "$unit" || { echo "FAIL: $unit is not enabled" >&2; fail=1; }
  systemctl is-active --quiet "$unit" || { echo "FAIL: $unit is not active" >&2; fail=1; }
done

backend_user=$(systemctl show -p User --value daygleve-backend.service)
broker_user=$(systemctl show -p User --value daygleve-broker.service)
broker_group=$(systemctl show -p Group --value daygleve-broker.service)
check_eq "backend User" "$backend_user" "daygleve"
check_eq "broker User" "$broker_user" "root"
check_eq "broker Group" "$broker_group" "daygleve"

backend_caps=$(systemctl show -p CapabilityBoundingSet --value daygleve-backend.service)
backend_devices=$(systemctl show -p DevicePolicy --value daygleve-backend.service)
[[ -z "$backend_caps" ]] || { echo "FAIL: backend has capabilities: $backend_caps" >&2; fail=1; }
check_eq "backend DevicePolicy" "$backend_devices" "closed"

broker_uid=$(id -u daygleve)
env_uid=$(sed -n 's/^DAYGLEVE_BROKER_UID=//p' /etc/daygleve/daygleve.env)
check_eq "daygleve UID" "$broker_uid" "$env_uid"

socket=/run/daygleve/broker.sock
if [[ ! -S "$socket" ]]; then
  echo "FAIL: broker socket is missing or not a Unix socket: $socket" >&2
  fail=1
else
  socket_mode=$(stat -c '%a' "$socket")
  socket_owner=$(stat -c '%U' "$socket")
  socket_group=$(stat -c '%G' "$socket")
  check_eq "broker socket mode" "$socket_mode" "660"
  check_eq "broker socket owner" "$socket_owner" "root"
  check_eq "broker socket group" "$socket_group" "daygleve"
fi

if ! aa-status --enabled >/dev/null 2>&1; then
  echo "FAIL: AppArmor is not enabled" >&2
  fail=1
else
  for profile in /usr/bin/daygleve-backend /usr/bin/daygleve-broker; do
    aa-status --profiled 2>/dev/null | grep -Fxq "$profile" || {
      echo "FAIL: AppArmor profile is not loaded: $profile" >&2
      fail=1
    }
  done
fi

# Ensure the backend cannot use the old root-equivalent account/groups.
if id daygleve | grep -Eq 'libvirt|kvm|lxc|netdev|video|render|disk'; then
  echo "FAIL: daygleve still has a host-operation supplementary group" >&2
  fail=1
else
  echo "PASS: daygleve has no legacy host-operation groups"
fi

if (( fail != 0 )); then
  echo "Host validation FAILED; do not expose the control plane." >&2
  exit 1
fi
if [[ -n "${DAYGLEVE_API_URL:-}" && -n "${DAYGLEVE_API_TOKEN:-}" ]]; then
  require_cmd curl
  curl --fail --silent --show-error \
    -H "Authorization: Bearer ${DAYGLEVE_API_TOKEN}" \
    "${DAYGLEVE_API_URL%/}/api/v1/system/broker-split" >/tmp/daygleve-broker-split.json
  grep -q '"current_execution":"broker"' /tmp/daygleve-broker-split.json || {
    echo "FAIL: broker posture endpoint did not report broker execution" >&2
    exit 1
  }
  echo "PASS: broker posture endpoint reports delegated execution"
fi

echo "Host validation PASSED. Run the workflow smoke tests from docs/SECURITY-HARDENING.md next."
