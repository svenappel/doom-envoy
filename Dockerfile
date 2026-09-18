# Doom voor Enphase IQ Gateway Standard (ARMv7 Cortex-A8)
# Gebruikt doomgeneric met directe Xlib-rendering + gebundeld xauth
# Build: docker build --no-cache --platform linux/arm/v7 -t doom-envoy .
# Run:   docker run --rm -v $(pwd)/output:/output doom-envoy

FROM arm32v7/debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    gcc make libx11-dev git xauth \
    && rm -rf /var/lib/apt/lists/*

# Build doomgeneric met X11 backend
RUN git clone https://github.com/ozkl/doomgeneric /src/doomgeneric

# Patch Makefile: clang -> gcc, SDL2 -> X11
RUN cd /src/doomgeneric/doomgeneric \
    && sed -i 's/^CC\s*=.*/CC = gcc/' Makefile \
    && sed -i 's/dg_sdl\.c/dg_x11.c/g' Makefile \
    && sed -i 's/-lSDL2_mixer//g' Makefile \
    && sed -i 's/-lSDL2/-lX11/g' Makefile \
    && make CC=gcc

# Bundel doom binary + xauth + alle gedeelde libraries in /build/
RUN mkdir -p /build/doom/bin /build/doom/lib \
    && cp /src/doomgeneric/doomgeneric/doomgeneric /build/doom/bin/ \
    && cp /usr/bin/xauth /build/doom/bin/ \
    && for bin in /src/doomgeneric/doomgeneric/doomgeneric /usr/bin/xauth; do \
         ldd "$bin" | awk '{print $3}' | grep -v '^$' | while read lib; do \
           [ -f "$lib" ] && cp "$lib" /build/doom/lib/ || true; \
         done; \
       done \
    && cp /lib/arm-linux-gnueabihf/ld-linux-armhf.so.3 /build/doom/lib/

# xauth wrapper (voor SSH X11 forwarding setup)
RUN cat > /build/doom/xauth.sh << 'EOF'
#!/bin/sh
DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$DIR/lib/ld-linux-armhf.so.3" --library-path "$DIR/lib" "$DIR/bin/xauth" "$@"
EOF
RUN chmod +x /build/doom/xauth.sh

# Doom wrapper
RUN cat > /build/doom/doom.sh << 'EOF'
#!/bin/sh
DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$DIR/lib/ld-linux-armhf.so.3" --library-path "$DIR/lib" "$DIR/bin/doomgeneric" -iwad "$DIR/doom.wad" "$@"
EOF
RUN chmod +x /build/doom/doom.sh

# Installatiescript: zet xauth op de juiste plek en pas sshd_config aan
RUN cat > /build/doom/setup-x11.sh << 'EOF'
#!/bin/sh
# Eenmalig uitvoeren op de gateway als root
DIR="$(cd "$(dirname "$0")" && pwd)"
ln -sf "$DIR/xauth.sh" /usr/bin/xauth
sed -i 's/X11Forwarding no/X11Forwarding yes/' /etc/ssh/sshd_config
service ssh restart
echo "Klaar. Verbind opnieuw met: ssh -X -i ~/.ssh/id_ed25519 root@<gateway>"
EOF
RUN chmod +x /build/doom/setup-x11.sh

RUN tar czf /build/doom-envoy.tar.gz -C /build doom

CMD ["sh", "-c", "cp /build/doom-envoy.tar.gz /output/"]
