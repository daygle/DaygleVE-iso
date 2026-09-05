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

## Command execution boundary

The backend command wrapper now:

1. allows only the known host programs (`virsh`, `zfs`, `zpool`, `lxc-*`,
   `ip`, `bridge`, `mount`, and `umount`);
2. resolves each program to an absolute appliance path rather than searching
   `PATH`; and
3. clears the inherited environment, retaining only a fixed `PATH` and
   `LC_ALL=C`.

Arguments remain argv elements and are validated by each service before use;
there is no shell interpolation.

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
