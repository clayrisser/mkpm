#!/bin/bash
#
# Usage: ./build-release
#
# The latest version of this script is available at
# https://github.com/emk/rust-musl-builder/blob/master/examples/build-release
#
# Called by `.travis.yml` to build release binaries.  We use
# ekidd/rust-musl-builder to make the Linux binaries so that we can run
# them unchanged on any distro, including tiny distros like Alpine (which
# is heavily used for Docker containers).  Other platforms get regular
# binaries, which will generally be dynamically linked against libc.
#
# If you have a platform which supports static linking of libc, and this
# would be generally useful, please feel free to submit patches.

set -euo pipefail

case `uname -s` in
    Linux)
        echo "Building static binaries using ekidd/rust-musl-builder"
        docker build -t build-mkpm-image .
        docker run --name build-mkpm build-mkpm-image
        docker cp build-mkpm:/home/rust/src/target/x86_64-unknown-linux-musl/release/mkpm mkpm
        docker rm build-mkpm
        docker rmi build-mkpm-image
        strip mkpm
        docker run --rm -w $PWD -v $PWD:$PWD aerysinnovation/upx:latest --best --lzma mkpm
        ;;
    *)
        echo "Building standard release binaries"
        cargo build --release
        ;;
esac
