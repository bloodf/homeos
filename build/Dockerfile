FROM debian:trixie-slim

LABEL org.opencontainers.image.title="HomeOS ISO builder" \
      org.opencontainers.image.description="Debian trixie-slim builder with xorriso, syslinux, cpio, rsync, and checksum tools for HomeOS ISO repacking" \
      org.opencontainers.image.source="https://github.com/bloodf/homeos"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      xorriso \
      isolinux \
      syslinux-common \
      dosfstools \
      mtools \
      genisoimage \
      rsync \
      curl \
      ca-certificates \
      gnupg \
      cpio \
      gzip \
      file \
      bsdmainutils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work
ENTRYPOINT []
CMD ["bash"]
