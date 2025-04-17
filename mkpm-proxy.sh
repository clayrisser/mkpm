#!/bin/sh
MKPM_VERSION="<% MKPM_VERSION %>"
MKPM_SH_URL="${MKPM_SH_URL:-https://gitlab.com/api/v4/projects/48207162/packages/generic/mkpm/${MKPM_VERSION}/mkpm.sh}"
export ROOTDIR="$(git rev-parse --show-toplevel 2>/dev/null)"
[ -z "$ROOTDIR" ] || [ ! -f "$ROOTDIR/mkpm.json" ] && echo "invalid environment" && exit 1
if [ ! -f "$ROOTDIR/.mkpm/mkpm/.bin/mkpm" ]; then
    mkdir -p "$ROOTDIR/.mkpm/mkpm/.bin"
    if [ -f "$ROOTDIR/.mkpm/cache.tar.gz" ]; then
        mkdir -p "$ROOTDIR/.mkpm/mkpm"
        cd "$ROOTDIR/.mkpm/mkpm"
        tar -xzf "$ROOTDIR/.mkpm/cache.tar.gz"
    else
        $(curl --version >/dev/null 2>&1 && echo curl -Lo || echo wget -O) "$ROOTDIR/.mkpm/mkpm/.bin/mkpm" "$MKPM_SH_URL" >/dev/null
    fi
    chmod +x "$ROOTDIR/.mkpm/mkpm/.bin/mkpm"
fi
exec "$ROOTDIR/.mkpm/mkpm/.bin/mkpm" "$@"
