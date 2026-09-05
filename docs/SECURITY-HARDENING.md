# Security hardening

## Runtime identity

The appliance runs the DaygleVE API as the dedicated `daygleve` system account,
not as root. The account has no login shell, no password, and no unrestricted
sudo rule. The boot-time `daygleve-prepare-state.service` runs once as root to
create or migrate `/var/lib/daygleve`, then exits before the API starts.

The high-risk host-operation boundary is provided by the separate
`daygleve-broker.service`, which runs as root and accepts only authenticated
local Unix-socket requests from the fixed `daygleve` UID. The API is ordered after
and requires the broker; when `DAYGLEVE_BROKER_SOCKET` is configured, command
routing fails rather than silently falling back to direct execution.

The backend is configured to use the root-owned `daygleve-broker` for host
operations. The backend has no ambient capabilities, no direct device access,
and no host-operation supplementary groups. The broker is the only service that
should hold the following privileges:

- `libvirt` and `kvm` for the system libvirt connection and KVM device
- `lxc` for container tooling and cgroup operations
- `CAP_SYS_ADMIN`/`CAP_SYS_RAWIO` for ZFS, namespace, mount, and vfio paths
- `CAP_NET_ADMIN` for bridge/VLAN operations

The root-only preparation unit performs state migration, so the API does not
retain `CAP_CHOWN`, `CAP_DAC_OVERRIDE`, `CAP_DAC_READ_SEARCH`, or `CAP_FOWNER`.
These are deliberately absent from the service capability bounding set.
The broker still has a concentrated root-equivalent surface by design. It is
therefore a separate trust boundary, not a claim that arbitrary host operations
are safe: the protocol allowlist, fixed paths, systemd policy, AppArmor profile,
and real-host validation below are all required. The backend must never receive
the broker's capabilities or socket group outside the documented service path.

## Service sandbox

`daygleve-backend.service` applies:

- `ProtectSystem=strict` and `ProtectHome=read-only`
- explicit writable paths for DaygleVE state only
- `PrivateTmp`, `NoNewPrivileges`, `RestrictSUIDSGID`, and locked personality
- restricted address families and denial of cloud metadata IP `169.254.169.254`
- empty capability bounding and ambient capability sets
- `DevicePolicy=closed`, with KVM/VFIO/zvol access isolated in the broker
- a syscall allowlist that excludes reboot and swap operations

The service requires `daygleve-prepare-state.service`, so a missing or
unusable state directory prevents normal startup instead of causing the API to
fall back to a root-created directory with permissive ownership.

## Mandatory access control

The ISO includes AppArmor and ships
`/etc/apparmor.d/usr.bin.daygleve-backend` and
`/etc/apparmor.d/usr.bin.daygleve-broker`. The backend profile permits only
read/state/API access; the broker profile contains the deliberately narrow host
tool and kernel write rules. Verify both profiles are loaded after boot:

```sh
sudo aa-status
sudo journalctl -u daygleve-backend.service -b
sudo journalctl -u daygleve-broker.service -b
```

If AppArmor is unavailable in a custom kernel, treat the host as not meeting
the appliance security baseline. Do not disable the systemd sandbox to work
around a denied operation; add a reviewed rule or implement the broker split.

### Real-host validation still required

The sandbox and MAC controls cannot be fully verified on this development
workstation. Before treating the appliance as production hardened, exercise
the full stack on a disposable Linux host and confirm:

- `systemctl show daygleve-backend` reports `User=daygleve`, empty capabilities,
  `DevicePolicy=closed`, and the expected syscall/filesystem restrictions;
- `systemctl show daygleve-broker` reports `User=root`, `Group=daygleve`, the
  expected capability set, and a mode-0660 socket at `/run/daygleve/broker.sock`;
- `daygleve` cannot obtain a login shell, run `sudo`, or read unrelated secrets
  under `/root`, `/home`, and `/etc/shadow`;
- VM, LXC, ZFS, bridge/VLAN, share, backup, and GPU workflows all complete through
  the broker and produce no unexpected AppArmor denials or systemd audit messages;
- the command wrapper is the only path through which host tools are invoked, and
  no new tool has been added without an explicit allowlist entry;
- the backend's `GET /api/v1/system/broker-split` reports broker execution only
  after the broker service is healthy, and all host workflows produce no
  unexpected AppArmor denials;

If any of these validations fail, treat the appliance as **not** production-ready
for the affected workload and do not disable the sandbox or profile to work around
the failure.

Last revised: 2026-09-05.

## Command execution boundary

The backend command wrapper constrains *how* host commands launch: it allows only
the known host programs (`virsh`, `zfs`, `zpool`, `lxc-*`, `ip`, `bridge`,
`mount`, and `umount`), resolves each program to an absolute appliance path rather
than searching `PATH`, clears the inherited environment, retains only a fixed `PATH`
and `LC_ALL=C`, and applies timeouts.

That removes PATH/loader/shell-based control surfaces. On the appliance the
backend does not receive the capabilities or device access required for those
operations; it sends validated requests to the broker. The broker remains a
concentrated root-equivalent boundary and must be treated as a separate trusted
component.

Arguments remain argv elements and are validated by each service before use; there
is no shell interpolation. The split between *command safety* and *privilege separation* is documented in the backend service layer: the development direct fallback is explicit and the appliance path is broker-mediated.

### Residual privilege surface

The following host actions are broker-mediated by the appliance path and remain on
the broker's reviewed allowlist:

- libvirt system instance: VM define/start/destroy/undefine, nvram, console VNC,
  and live state queries via `virsh` under `qemu:///system`
- ZFS: dataset/snapshot/zvol mutation, send/receive during backup/restore,
  volume provisioning, and retention deletes
- LXC: container create/start/stop/destroy, cgroup limit writes, and config
  mutation with ZFS-backed rootfs writes
- GPU/vfio: PCI sysfs bind/unbind and driver overrides that can rebind an IOMMU
  group to `vfio-pci`
- Network: bridge/VLAN creation and modifications via `ip`/`bridge`, including
  namespace and cgroup usage by containers
- Shares/mounts: `mount`/`umount` for network shares and mount table mutation
- Backup/restore: long-running ZFS send/receive and restore target replacement

Lower-risk read-heavy or state-local concerns are not broker blockers today:
JSON record stores, auth/password state, ISO/library enumeration, metrics, the
operations journal, and API housekeeping.

The broker split is now wired into the appliance path. The backend refuses direct
command construction for streaming operations when the broker is configured, and
all allowlisted unary commands, backup streams, PCI writes, and LXC config writes
use the broker. Real-host validation remains mandatory before this is called
production hardened; development environments may still use the explicit direct
fallback when `DAYGLEVE_BROKER_SOCKET` is unset.

## Operational checklist

Before production use on a real Linux host:

1. Install the generated ISO and verify `systemctl show daygleve-backend` reports
   `User=daygleve` and the expected capability/device restrictions.
2. Confirm `daygleve` cannot run `sudo`, obtain a login shell, or read unrelated
   secrets under `/root`, `/home`, and `/etc/shadow`.
3. Exercise VM, LXC, ZFS, bridge/VLAN, share, backup, and GPU workflows on
   disposable resources.
4. Inspect AppArmor denials and systemd audit logs during each workflow.
5. Confirm the API is reachable only on the intended interface/firewall port;
   use TLS directly or a properly configured TLS reverse proxy.
6. Test service restart, state migration, backup restore, and failure recovery.
7. Confirm the broker is healthy and the broker-split endpoint reports delegated
   execution before exposing the control plane to untrusted tenants or the public
   internet.

This hardening improves the default appliance boundary but does not yet provide
multi-tenant isolation or a formally audited privilege-separation design.
