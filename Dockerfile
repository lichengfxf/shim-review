FROM debian:bookworm-slim as builder

ENV DEBIAN_FRONTEND=noninteractive

RUN mkdir -p /work && \
    apt-get update -y && \
    apt-get install -y \
      ca-certificates openssl coreutils bash curl tar xz-utils bzip2 git sed diffutils patch make pesign \
      libelf-dev \
      binutils-x86-64-linux-gnu gcc \
      binutils-aarch64-linux-gnu gcc-aarch64-linux-gnu

ARG SHIM_ARCHIVE_URL=https://github.com/rhboot/shim/releases/download/15.8/shim-15.8.tar.bz2
ARG SHIM_ARCHIVE_FILE=shim-15.8.tar.bz2
ARG SHIM_ARCHIVE_SHA256=a79f0a9b89f3681ab384865b1a46ab3f79d88b11b4ca59aa040ab03fffae80a9

COPY [ "shenxinda_uefi.der", "sbat.csv", "/tmp/" ]
RUN cd /tmp && \
    set -x  && \
    curl -L -o "/tmp/${SHIM_ARCHIVE_FILE}" "${SHIM_ARCHIVE_URL}" && \
    echo "${SHIM_ARCHIVE_SHA256} ${SHIM_ARCHIVE_FILE}" | sha256sum -c

WORKDIR /work

RUN mkdir -p /work/output && \
    dpkg -l | tee /work/output/builder-packages.txt

ARG EFIDIR=shenxinda
RUN tar --strip-components=1 -xf "/tmp/${SHIM_ARCHIVE_FILE}" && \
    mkdir -p \
      build-x86_64/data \
      build-ia32/data \
      build-aarch64/data \
      output/x86_64 \
      output/ia32 \
      output/aarch64 && \
    cp -f /tmp/sbat.csv data/sbat.csv && \
    cp /tmp/sbat.csv build-x86_64/data/sbat.csv && \
    cp /tmp/sbat.csv build-ia32/data/sbat.csv && \
    cp /tmp/sbat.csv build-aarch64/data/sbat.csv

RUN make -C build-x86_64 TOPDIR=.. ARCH=x86_64 VENDOR_CERT_FILE=/tmp/shenxinda_uefi.der  EFIDIR=${EFIDIR} DESTDIR=/work/output/x86_64 ENABLE_SHIM_HASH=true -f ../Makefile install
RUN make -C build-ia32 TOPDIR=.. ARCH=ia32 VENDOR_CERT_FILE=/tmp/shenxinda_uefi.der  EFIDIR=${EFIDIR} DESTDIR=/work/output/ia32 ENABLE_SHIM_HASH=true -f ../Makefile install
RUN make -C build-aarch64 TOPDIR=.. ARCH=aarch64 CROSS_COMPILE=aarch64-linux-gnu- VENDOR_CERT_FILE=/tmp/shenxinda_uefi.der EFIDIR=${EFIDIR} DESTDIR=/work/output/aarch64 ENABLE_SHIM_HASH=true -f ../Makefile install
RUN objcopy -j .sbat -O binary /work/output/x86_64/boot/efi/EFI/shenxinda/shimx64.efi /tmp/shimx64-sbat.csv && sed -i 's/\x0//g' /tmp/shimx64-sbat.csv && \
    objcopy -j .sbat -O binary /work/output/ia32/boot/efi/EFI/shenxinda/shimia32.efi /tmp/shimia32-sbat.csv && sed -i 's/\x0//g' /tmp/shimia32-sbat.csv && \
    aarch64-linux-gnu-objcopy -j .sbat -O binary /work/output/aarch64/boot/efi/EFI/shenxinda/shimaa64.efi /tmp/shimaa64-sbat.csv && sed -i 's/\x0//g' /tmp/shimaa64-sbat.csv && \
    diff /tmp/shimx64-sbat.csv /tmp/sbat.csv && \
    diff /tmp/shimia32-sbat.csv /tmp/sbat.csv && \
    diff /tmp/shimaa64-sbat.csv /tmp/sbat.csv \
    || ( >&2 echo "SBAT IS NOT APPLIED CORRECTLY"; exit 1 )

RUN for name in $(find /work/output/ -type f -name "shim*.efi"); do echo "PESIGN($name): "; pesign --hash --padding --in=$name; echo "SHA256SUM:"; sha256sum $name; echo; done

# REVIEW
RUN echo "::review hash-start" && \
    for name in $(find /work/output/ -type f -name "shim*.efi"); do sha256sum $name; done && \
    echo "::review hash-end"

