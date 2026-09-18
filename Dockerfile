# Doom for Enphase IQ Gateway Standard (ARMv7 Cortex-A8 / Debian 7 / glibc 2.13)
#
# Builds doomgeneric (direct Xlib rendering) for ARM and bundles all shared
# libraries + the dynamic linker, so the ancient glibc on the gateway is never used.
#
# Build (on any machine with Docker + QEMU binfmt):
#   docker build --no-cache --platform linux/arm/v7 -t doom-envoy .
#
# Extract the tarball:
#   docker run --rm -v "$(pwd)/output:/output" doom-envoy
#
# The output/doom-envoy.tar.gz unpacks to a self-contained /doom/ directory.

FROM arm32v7/debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    gcc make libx11-dev git xauth \
    && rm -rf /var/lib/apt/lists/*

# Build doomgeneric with the X11 (Xlib) backend
RUN git clone https://github.com/ozkl/doomgeneric /src/doomgeneric

# Patch the Makefile: use gcc instead of clang, replace SDL2 with X11
RUN cd /src/doomgeneric/doomgeneric \
    && sed -i 's/^CC\s*=.*/CC = gcc/' Makefile \
    && sed -i 's/dg_sdl\.c/dg_x11.c/g' Makefile \
    && sed -i 's/-lSDL2_mixer//g' Makefile \
    && sed -i 's/-lSDL2/-lX11/g' Makefile \
    && make CC=gcc

# Bundle the doom binary, xauth, and all required shared libraries
RUN mkdir -p /build/doom/bin /build/doom/lib \
    && cp /src/doomgeneric/doomgeneric/doomgeneric /build/doom/bin/ \
    && cp /usr/bin/xauth /build/doom/bin/ \
    && for bin in /src/doomgeneric/doomgeneric/doomgeneric /usr/bin/xauth; do \
         ldd "$bin" | awk '{print $3}' | grep -v '^$' | while read lib; do \
           [ -f "$lib" ] && cp "$lib" /build/doom/lib/ || true; \
         done; \
       done \
    && cp /lib/arm-linux-gnueabihf/ld-linux-armhf.so.3 /build/doom/lib/

# xauth wrapper — uses hardcoded /tmp/doom paths because it is invoked via a
# symlink (/usr/X11R6/bin/xauth), and dirname "$0" would resolve to the symlink
# directory rather than the bundle directory.
RUN cat > /build/doom/xauth.sh << 'EOF'
#!/bin/sh
exec /tmp/doom/lib/ld-linux-armhf.so.3 --library-path /tmp/doom/lib /tmp/doom/bin/xauth "$@"
EOF
RUN chmod +x /build/doom/xauth.sh

# Doom launcher wrapper
RUN cat > /build/doom/doom.sh << 'EOF'
#!/bin/sh
DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$DIR/lib/ld-linux-armhf.so.3" --library-path "$DIR/lib" "$DIR/bin/doomgeneric" -iwad "$DIR/doom.wad" "$@"
EOF
RUN chmod +x /build/doom/doom.sh

# One-time setup script — run once on the gateway as root after extracting the tarball.
#
# Two Debian 7 quirks handled here:
#   1. OpenSSH on Debian 7 is compiled with XAuthLocation=/usr/X11R6/bin/xauth
#      (not /usr/bin/xauth — confirmed with: sshd -T | grep xauth)
#   2. The 'service' command does not exist; use /etc/init.d/ directly.
RUN cat > /build/doom/setup-x11.sh << 'EOF'
#!/bin/sh
DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p /usr/X11R6/bin
ln -sf "$DIR/xauth.sh" /usr/X11R6/bin/xauth
sed -i 's/X11Forwarding no/X11Forwarding yes/' /etc/ssh/sshd_config
/etc/init.d/ssh restart
echo "Done. Reconnect with: ssh -X -i ~/.ssh/id_ed25519 root@<gateway-ip>"
EOF
RUN chmod +x /build/doom/setup-x11.sh

RUN tar czf /build/doom-envoy.tar.gz -C /build doom

CMD ["sh", "-c", "cp /build/doom-envoy.tar.gz /output/"]
