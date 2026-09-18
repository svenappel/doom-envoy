# doom-envoy

Run Doom on an Enphase IQ Gateway Standard via SSH X11 forwarding.

**Hardware:** TI Sitara AM335x (ARMv7 Cortex-A8), 512 MB RAM, Debian 7 (Wheezy), glibc 2.13, no package manager, no compiler.

**Strategy:** cross-compile [doomgeneric](https://github.com/ozkl/doomgeneric) inside a `arm32v7/debian:bookworm` Docker container, bundle all `.so` libraries and `ld-linux-armhf.so.3`, ship a self-contained tarball. The bundled dynamic linker bypasses the gateway's ancient glibc entirely.

## Prerequisites

- Root SSH access to the gateway (see [my previous post](https://your-blog-url/enphase-root) for the serial console procedure)
- XQuartz (macOS) or any X server

## Deploy

```sh
git clone https://github.com/svenappel/doom-envoy
cd doom-envoy

scp -i ~/.ssh/id_ed25519 doom-envoy.tar.gz root@<gateway-ip>:/tmp/
ssh -i ~/.ssh/id_ed25519 root@<gateway-ip> \
  "cd /tmp && tar xzf doom-envoy.tar.gz && /tmp/doom/setup-x11.sh"
scp -i ~/.ssh/id_ed25519 freedoom1.wad root@<gateway-ip>:/tmp/doom/doom.wad
```

## Play

With XQuartz (macOS) open, connect from your regular terminal:

```sh
ssh -X -i ~/.ssh/id_ed25519 root@<gateway-ip>
/tmp/doom/doom.sh
```

A Doom window appears on your Mac. Controls: arrow keys to move, Ctrl to shoot, Space to open doors.

## Notes

- The bundle lives in `/tmp/doom/` and disappears on reboot. Re-run the deploy steps after a gateway restart.
- The setup script patches `/etc/ssh/sshd_config` (sets `X11Forwarding yes`) and creates a symlink at `/usr/X11R6/bin/xauth` — the path Debian 7's OpenSSH is compiled against.
- CPU load while playing: ~25% user + ~58% sys. The gateway keeps managing your panels without complaint.
- [Freedoom](https://freedoom.github.io/) is included under its BSD licence. To use the original Doom WAD instead, place it at `/tmp/doom/doom.wad`.

## Build from source

If you want to rebuild the bundle yourself (requires Docker with QEMU binfmt support):

```sh
docker build --no-cache --platform linux/arm/v7 -t doom-envoy .
mkdir -p output
docker run --rm -v "$(pwd)/output:/output" doom-envoy
# → output/doom-envoy.tar.gz
```
