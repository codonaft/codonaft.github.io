#!/usr/bin/env sh

if [ $# -lt 3 ] ; then
  echo "Build aquatic_ws using Alpine Linux podman container"
  echo "Usage: $0 <aquatic_version> <alpine_version> <target_cpu>
       $0 0.9.0 3.20.3 native
       $0 0.9.0 3.20 \$(ssh REMOTE_HOST 'rustc --print target-cpus' | grep native | sed 's!.* (currently !!;s!)\\.!!')"
  exit 1
fi

set -x

AQUATIC_VERSION="$1"
ALPINE_VERSION="$2"
TARGET_CPU="$3"

BINDGEN_VERSION="0.70.1"

DISABLE_AVX512=$(rustc --print target-features | grep '    avx512' | grep -v 'avx512fp16' | awk '{print $1}'  | sed 's/^/-C target-feature=-/' | xargs)

podman run --rm -it -v "$(pwd):/build" "alpine:${ALPINE_VERSION}" /bin/sh -c "
set -x

apk add --update --no-cache cargo clang17-libclang cmake g++ git linux-headers liburing make rust

export RUSTFLAGS='-C target-cpu=${TARGET_CPU} ${DISABLE_AVX512} -C force-frame-pointers=y'
export CFLAGS='-D_GNU_SOURCE -march=${TARGET_CPU} -O3'
export PATH=\"\${HOME}/.cargo/bin:\${PATH}\"

cargo install --force --locked bindgen-cli --version '${BINDGEN_VERSION}'
cargo install --force --locked aquatic_ws --version '${AQUATIC_VERSION}'
mv ~/.cargo/bin/aquatic_ws /build"
