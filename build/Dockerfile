FROM debian:trixie-slim

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
