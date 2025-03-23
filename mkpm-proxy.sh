#!/bin/sh
MKPM_VERSION="<% MKPM_VERSION %>"
MKPM_SH_URL="${MKPM_SH_URL:-https://gitlab.com/api/v4/projects/48207162/packages/generic/mkpm/${MKPM_VERSION}/mkpm.sh}"
export PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
[ -z "$PROJECT_ROOT" ] || [ ! -f "$PROJECT_ROOT/mkpm.json" ] && exit 1
if [ ! -f "$PROJECT_ROOT/.mkpm/mkpm/.bin/mkpm" ]; then
    mkdir -p "$PROJECT_ROOT/.mkpm/mkpm/.bin"
    if [ -f "$PROJECT_ROOT/.mkpm/cache.tar.gz" ]; then
        mkdir -p "$PROJECT_ROOT/.mkpm/mkpm"
        cd "$PROJECT_ROOT/.mkpm/mkpm"
        tar -xzf "$PROJECT_ROOT/.mkpm/cache.tar.gz"
    else
        $(curl --version >/dev/null 2>&1 && echo curl -Lo || echo wget -O) "$PROJECT_ROOT/.mkpm/mkpm/.bin/mkpm" "$MKPM_SH_URL" >/dev/null
    fi
    chmod +x "$PROJECT_ROOT/.mkpm/mkpm/.bin/mkpm"
fi
exec "$PROJECT_ROOT/.mkpm/mkpm/.bin/mkpm" "$@"
