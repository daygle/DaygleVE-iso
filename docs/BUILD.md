# DaygleVE release & ISO build runbook

DaygleVE ships as a single ISO assembled from tagged releases of the three app
repos. Because everything is pinned to immutable tags, a given
`DAYGLEVE_VERSION` reproduces the same image.

## Cutting a release (the coordinated tag dance)

Tags must be cut **in order**, because backend/frontend consume the schema by
tag and the ISO consumes backend/frontend by tag.

1. **Schema** - tag `DaygleVE-schema` at the release, e.g.:
   ```sh
   git -C DaygleVE-schema tag v1.0.0 && git -C DaygleVE-schema push origin v1.0.0
   ```
   Its `Release` workflow verifies the crate and publishes the TS bindings.

2. **Repoint app pins to the schema tag** (once per major/minor, not every build):
   - Backend `Cargo.toml`: `daygleve-schema = { git = "…", tag = "v1.0.0" }`
   - Frontend `package.json`: `"@daygleve/schema": "github:daygle/DaygleVE-schema#v1.0.0"`
   Commit these, then continue.

3. **Backend** - tag `DaygleVE-backend` `v1.0.0` and push. Its `Release`
   workflow builds `daygleve-backend-v1.0.0-x86_64-unknown-linux-gnu.tar.gz`.

4. **Frontend** - tag `DaygleVE-frontend` `v1.0.0` and push. Its `Release`
   workflow builds `daygleve-frontend-v1.0.0.tar.gz` (the static site).

5. **ISO** - set `DAYGLEVE_VERSION="v1.0.0"` in `versions.env`, commit, then
   tag this repo `v1.0.0` and push (or run the **Build ISO** workflow with the
   version input). The workflow fetches the backend + frontend assets and
   builds the ISO.

## Credentials

The ISO build downloads release assets from the **backend** and **frontend**
repos. Those repos are **public**, so the workflow's built-in `GITHUB_TOKEN`
can read their releases and **no secret is required**.

Only if you later make the app repos **private** do you need to set a secret:

- `DAYGLEVE_ARTIFACTS_TOKEN` - a fine-grained PAT (or GitHub App token) with
  **Contents: read** on `DaygleVE-backend` and `DaygleVE-frontend`.

The workflow uses that secret when present and otherwise falls back to
`GITHUB_TOKEN`.

## Building locally

```sh
sudo apt-get install -y live-build xorriso debootstrap gh librsvg2-bin
export GH_TOKEN=<token as above>
./build.sh          # -> daygleve-v1.0.0-amd64.iso
```

`build.sh` re-execs under `sudo` because live-build debootstraps and mounts a
chroot. The build runs entirely on the host (no KVM needed); booting the
resulting ISO does need virtualization.

## Reproducibility notes

- Component bits are pinned by tag (immutable). For bit-for-bit Rust builds,
  also commit `Cargo.lock` in the backend and build the release with
  `--locked` (a follow-up once the schema pin moves from a branch to a tag).
- The Debian suite is pinned in `versions.env` (`DEBIAN_SUITE`). Debian's
  archive still moves within a suite; add `--apt-options`/snapshot pinning in
  `auto/config` if you need archive-level reproducibility.

## Status

The image build runs on a privileged Linux runner (the CI workflow provides
one); ZFS is built via DKMS against the shipped kernel. The live image boots
into the **Calamares** graphical installer (a live-only systemd service
launches a minimal openbox/X session), which installs the DaygleVE system to disk
via calamares-settings-debian. CI only verifies the image builds - the installer
flow itself is validated by booting the ISO. Remaining hardening: drop the
backend from root to scoped capabilities, trim installer packages from the
target, and re-enable the Debian security suite with the correct
`trixie-security` name.

## Branding

DaygleVE branding replaces Debian's defaults on two surfaces:

- **Boot menu** - `config/bootloaders/isolinux/splash.svg` (BIOS/syslinux) is
  the single source for the branded background. The build regenerates the
  `splash.png` files consumed by syslinux/GRUB, keeping the cube below GRUB's
  heading and the generated menu band clear; the Syslinux menu is also shifted
  down slightly during the binary stage. The build requires `rsvg-convert`
  from `librsvg2-bin` so a stale raster image can never be baked into a new ISO.
- **Installer** - `config/includes.chroot/etc/calamares/branding/daygleve/`
  is a Calamares branding component (`branding.desc` + `mark.svg`/`icon.svg`).
  The chroot hook repoints `/etc/calamares/settings.conf`
  (`branding: debian` → `branding: daygleve`) so the installer shows the
  DaygleVE name, logo and palette, and names the installed bootloader entry
  "DaygleVE".

The generated live entries are relabeled to "DaygleVE", "DaygleVE (fail-safe
mode)", and "DaygleVE utilities..." during the binary build; kernel paths and
boot parameters are left unchanged.
