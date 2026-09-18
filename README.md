# doom-envoy

Run Doom on an Enphase IQ Gateway Standard via SSH X11 forwarding.

**Hardware:** TI Sitara AM335x (ARMv7 Cortex-A8), 512 MB RAM, Debian 7 (Wheezy), glibc 2.13, no package manager, no compiler.

**Strategy:** cross-compile [doomgeneric](https://github.com/ozkl/doomgeneric) inside a `arm32v7/debian:bookworm` Docker container, bundle all `.so` libraries and `ld-linux-armhf.so.3`, ship a self-contained tarball. The bundled dynamic linker bypasses the gateway's ancient glibc entirely.

## Prerequisites

- Root SSH access to the gateway (see [my previous post](https://your-blog-url/enphase-root) for the serial console procedure)
- Docker with QEMU binfmt support (`docker buildx` or `tonistiigi/binfmt`)
- A WAD file — [Freedoom](https://freedoom.github.io/) works great (free and open)
- XQuartz (macOS) or any X server

## Build

```sh
git clone https://github.com/YOUR_USERNAME/doom-envoy
cd doom-envoy
docker build --no-cache --platform linux/arm/v7 -t doom-envoy .
mkdir -p output
docker run --rm -v "$(pwd)/output:/output" doom-envoy
# → output/doom-envoy.tar.gz
```

## Deploy

```sh
# Copy the bundle
scp -i ~/.ssh/id_ed25519 output/doom-envoy.tar.gz root@192.168.178.40:/tmp/

# Extract and run the one-time setup (enables X11 forwarding, installs xauth)
ssh -i ~/.ssh/id_ed25519 root@192.168.178.40 \
  "cd /tmp && rm -rf doom && tar xzf doom-envoy.tar.gz && /tmp/doom/setup-x11.sh"

# Copy your WAD file
scp -i ~/.ssh/id_ed25519 /path/to/freedoom1.wad root@192.168.178.40:/tmp/doom/doom.wad
```

## Play

With XQuartz (macOS) open, connect from your regular terminal:

```sh
ssh -X -i ~/.ssh/id_ed25519 root@192.168.178.40
/tmp/doom/doom.sh
```

A Doom window appears on your Mac. Controls: arrow keys to move, Ctrl to shoot, Space to open doors.

## Notes

- The bundle is extracted to `/tmp/doom/` — it disappears on reboot. Re-extract after a gateway restart; the WAD survives if you put it somewhere persistent.
- The setup script patches `/etc/ssh/sshd_config` (sets `X11Forwarding yes`) and creates a symlink at `/usr/X11R6/bin/xauth` — that is the path Debian 7's OpenSSH is compiled against, not `/usr/bin/xauth`.
- CPU load while playing: ~25 % user + ~58 % sys. The gateway keeps managing your panels fine alongside it.
