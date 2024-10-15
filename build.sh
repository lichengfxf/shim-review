#!/bin/bash

set -e

mkdir -p output review
docker build --tag shim_build . 2>&1 | tee review/build-log.txt

# for name in $(find ./output/ -type f -name "shim*.efi"); do cp -av $name ./review; done 
# ( cd review && sha256sum shim*.efi > hashs.txt )

