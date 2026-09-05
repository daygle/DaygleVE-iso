# Security hardening

## Runtime identity

The appliance runs the DaygleVE API as the dedicated `daygleve` system account,
not as root. The account has no login shell, no password, and no unrestricted
sudo rule. The boot-time `daygleve-prepare-state.service` runs once as root to
create or migrate `/var/lib/daygleve`, then exits before the API starts.

The current backend still directly controls several host subsystems. Its
supplementary groups and capabilities are therefore intentionally narrow for
this architecture:

- `libvirt` and `kvm` for the system libvirt connection and KVM device
- `lxd` for LXC metadata/tooling on hosts that provide that group
- `CAP_SYS_ADMIN`/`CAP_SYS_RAWIO` for the current ZFS, namespace, and vfio paths
- `CAP_NET_ADMIN` for bridge/VLAN operations

The root-only preparation unit performs state migration, so the API does not
retain `CAP_CHOWN`, `CAP_DAC_OVERRIDE`, `CAP_DAC_READ_SEARCH`, or `CAP_FOWNER`.
These are deliberately absent from the service capability bounding set.
`CAP_SYS_ADMIN` and direct PCI sysfs writes are high-risk and are not equivalent
to a complete least-privilege design. The next security milestone should split
LXC, mount, ZFS mutation, networking, and vfio operations into a small,
root-owned broker with a narrow authenticated local protocol. Until that split
is deployed, the systemd and AppArmor controls below reduce but do not remove
the impact of a backend compromise.

## Service sandbox

`daygleve-backend.service` applies:

- `ProtectSystem=strict` and `ProtectHome=read-only`
- explicit writable paths for DaygleVE state, LXC metadata, and required sysfs
- `PrivateTmp`, `NoNewPrivileges`, `RestrictSUIDSGID`, and locked personality
- restricted address families and denial of cloud metadata IP `169.254.169.254`
- a capability bounding set and ambient capability set
- explicit `/dev/kvm`, `/dev/vfio/*`, and `/dev/zvol/*` access
- a syscall allowlist that excludes reboot and swap operations

The service requires `daygleve-prepare-state.service`, so a missing or
unusable state directory prevents normal startup instead of causing the API to
fall back to a root-created directory with permissive ownership.

## Mandatory access control

The ISO includes AppArmor and ships
`/etc/apparmor.d/usr.bin.daygleve-backend`. The profile permits only the fixed
host tools used by the backend, DaygleVE's state tree, libvirt sockets/config,
required kernel interfaces, and the explicitly delegated devices. Verify the
profile is loaded after boot:

```sh
sudo aa-status
sudo journalctl -u daygleve-backend.service -b
```

If AppArmor is unavailable in a custom kernel, treat the host as not meeting
the appliance security baseline. Do not disable the systemd sandbox to work
around a denied operation; add a reviewed rule or implement the broker split.

### Real-host validation still required

The sandbox and MAC controls cannot be fully verified on this development
workstation. Before treating the appliance as production hardened, exercise
the full stack on a disposable Linux host and confirm:

- `systemctl show daygleve-backend` reports `User=daygleve` and the expected
  capability, device, syscall, and filesystem restrictions;
- `daygleve` cannot obtain a login shell, run `sudo`, or read unrelated secrets
  under `/root`, `/home`, and `/etc/shadow`;
- VM, LXC, ZFS, bridge/VLAN, share, backup, and GPU workflows all complete and
  produce no unexpected AppArmor denials or systemd audit messages;
- the command wrapper is the only path through which host tools are invoked, and
  no new tool has been added without an explicit allowlist entry;
- the broker split is implemented before untrusted tenants or the public internet
  are given access to the control plane.

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

That removes PATH/loader/shell-based control surfaces for the current
architecture, but it does **not** remove the privilege boundary. The backend still
runs with the capability and device access required to invoke libvirt, ZFS, LXC,
PCI sysfs, and networking/mount tooling.

Arguments remain argv elements and are validated by each service before use; there
is no shell interpolation. The split between *command safety* and *privilege
separation* is documented in the backend service layer: the current direct path is
explicit, not implicit.

### Residual privilege surface

The following host actions are still performed directly by the backend and remain on
the broker split list:

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

The next hardening milestone should move these operations into a small,
root-owned broker with a narrow authenticated local protocol. Until that broker is
deployed, the service-layer documentation explicitly treats the current
implementation as temporary.

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
7. Replace the direct privileged operations with a root-owned broker before
   exposing the control plane to untrusted tenants or the public internet.

This hardening improves the default appliance boundary but does not yet provide
multi-tenant isolation or a formally audited privilege-separation design.
