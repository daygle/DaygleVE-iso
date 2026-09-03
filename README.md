# DaygleVE-iso

Builds the **DaygleVE appliance ISO** - a bootable Debian trixie live image for
amd64 that runs the [DaygleVE](https://github.com/daygle) single-node
virtualization platform (KVM/QEMU + LXC + ZFS + Linux networking) out of the box.

This repository is **build tooling only** - it assembles release artifacts from
the app repos; it contains no application source. That keeps the three app
repos (`schema`, `backend`, `frontend`) clean and independent.

## What it assembles

For a given `DAYGLEVE_VERSION` (an immutable git tag), the ISO bundles:

| Component | Source (release asset) | Where it lands |
| --------- | ---------------------- | -------------- |
| Backend engine + API | `DaygleVE-backend` -> `daygleve-backend-<tag>-x86_64-unknown-linux-gnu.tar.gz` | `/usr/bin/daygleve-backend` |
| Frontend (static SPA) | `DaygleVE-frontend` -> `daygleve-frontend-<tag>.tar.gz` | `/usr/share/daygleve/web` |
| systemd unit + config | this repo | `/etc/systemd/system`, `/etc/daygleve` |
| Calamares installer branding | this repo | `/etc/calamares/branding/daygleve` |

The backend serves both the REST API and the frontend SPA on port `8080`, so the
appliance runs as a single service.

## Installer

The live image boots into a minimal X/Openbox session that launches the
DaygleVE-branded Calamares installer. The installer uses the live filesystem as
the source for the target system and installs GRUB for the boot mode in which
the ISO was started.

The ISO includes the generic and unsigned GRUB packages in its local package
pool for offline bootloader installation:

- `config/package-lists/daygleve-bootloader-efi.list.binary` stages UEFI GRUB.
- `config/package-lists/daygleve-bootloader-bios.list.binary` stages BIOS GRUB.
- `config/package-lists/daygleve.list.chroot` contains the GRUB support needed by
the live installer session.

The installer still needs access to the ISO media while installing. Internet
access is not required for the Calamares bootloader step or for the bundled
application artifacts.

## Reproducibility and versioning

`versions.env` pins the backend and frontend release artifacts to
`DAYGLEVE_VERSION`. The Debian suite (`trixie`) and architecture (`amd64`) are
also defined there. Debian archive contents can change within a suite, so the
result is not bit-for-bit reproducible unless the configured Debian mirror is
pinned to a snapshot.

## Building locally

### Prerequisites

Run on Debian or Ubuntu with:

- `live-build`
- `xorriso`
- `debootstrap`
- `gh` (GitHub CLI)
- `librsvg2-bin` (`rsvg-convert`)
- root access, either directly or through `sudo`

The GitHub CLI must be able to download the backend and frontend release assets.
The repositories are public, so the GitHub Actions workflow can use its built-in
`GITHUB_TOKEN`; local builds should authenticate `gh` or provide a suitable
`GH_TOKEN`.

```sh
sudo apt-get install -y live-build xorriso debootstrap gh librsvg2-bin
export GH_TOKEN=<token with read access to the backend + frontend repos>
./build.sh
# -> daygleve-v1.0.0-amd64.iso
```

`build.sh` fetches the pinned application artifacts, regenerates the GRUB and
Syslinux splash PNGs from `splash.svg`, configures live-build, and builds the
ISO. It re-executes itself through `sudo` when necessary. Building does not
require KVM; booting and testing the resulting ISO can be done in a VM or on
physical hardware.

## CI builds

The `Build ISO` workflow runs on:

- pushes of `v*` tags; the tag becomes `DAYGLEVE_VERSION`
- manual dispatches with an optional `version` input

It uploads the ISO as a workflow artifact and attaches it to a GitHub Release
for tag builds. The workflow installs the current Debian `live-build` package
on the Ubuntu runner before building.

## Layout

```
versions.env                     # pinned component versions and Debian target
auto/config                      # live-build configuration
config/package-lists/            # live-image and ISO package-pool lists
config/includes.chroot/          # files baked into the rootfs
config/hooks/normal/             # chroot and binary-stage hooks
scripts/fetch-artifacts.sh       # pull pinned backend/frontend release assets
build.sh                         # fetch, configure, and build orchestration
.github/workflows/build-iso.yml  # CI: build and publish the ISO
docs/BUILD.md                    # release and build runbook
```

See [`docs/BUILD.md`](docs/BUILD.md) for the coordinated release process and
additional build notes.

## License

Licensed under the [Apache License 2.0](LICENSE).

See [SECURITY.md](SECURITY.md) for reporting security vulnerabilities.
