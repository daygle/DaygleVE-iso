# DaygleVE-iso

Builds the **DaygleVE appliance ISO** - a bootable Debian live image that runs
the [DaygleVE](https://github.com/daygle) single-node virtualization platform
(KVM/QEMU + LXC + ZFS + Linux networking) out of the box.

This repository is **build tooling only** - it assembles release artifacts from
the app repos; it contains no application source. That keeps the three app
repos (`schema`, `backend`, `frontend`) clean and independent.

## What it assembles

For a given `DAYGLEVE_VERSION` (a git tag), the ISO bundles:

| Component | Source (release asset) | Where it lands |
| --------- | ---------------------- | -------------- |
| Backend engine + API | `DaygleVE-backend` → `daygleve-backend-<tag>-x86_64-unknown-linux-gnu.tar.gz` | `/usr/bin/daygleve-backend` |
| Frontend (static SPA) | `DaygleVE-frontend` → `daygleve-frontend-<tag>.tar.gz` | `/usr/share/daygleve/web` |
| systemd unit + config | this repo | `/etc/systemd/system`, `/etc/daygleve` |

The backend serves both the REST API and the frontend SPA on one port (`8080`),
so the appliance runs as a single service.

## Reproducibility & versioning

`versions.env` pins every component to an **immutable git tag**, so a given
`DAYGLEVE_VERSION` always assembles the exact same bits. Bump the pins together
per release (see [`docs/BUILD.md`](docs/BUILD.md)).

## Building

```sh
# needs: live-build, xorriso, debootstrap, gh, librsvg2-bin, and root
export GH_TOKEN=<token with read access to the backend + frontend repos>
./build.sh
# -> daygleve-<version>-amd64.iso
```

Or push a `v*` tag / run the **Build ISO** workflow to build in CI and attach
the ISO to a GitHub Release.

## Layout

```
versions.env                     # pinned component versions (edit per release)
auto/config                      # live-build configuration
config/package-lists/            # packages baked into the image
config/includes.chroot/          # files baked into the rootfs (unit, env, web, binary)
config/hooks/normal/             # chroot hooks (enable services)
scripts/fetch-artifacts.sh       # pull pinned backend/frontend release assets
build.sh                         # fetch + live-build orchestration
.github/workflows/build-iso.yml  # CI: build + publish the ISO
docs/BUILD.md                    # release + build runbook
```

See [`docs/BUILD.md`](docs/BUILD.md) for the full release runbook.

## License

Apache-2.0.
