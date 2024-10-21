#!/bin/bash

set -e

mkdir -p review
docker build --tag shim_build . 2>&1 | tee review/build-log.txt

# for review
sudo docker run --rm -v $(pwd)/review:/mnt shim_build bash -c "find /work/output/ -type f -name 'shim*.efi' -exec cp -av {} /mnt \; && sha256sum /mnt/shim*.efi > /mnt/hashs.txt"
