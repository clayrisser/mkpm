#!/bin/sh

MKPM_SH_URL="${MKPM_BINARY:-https://example.com}"
alias download="$(curl --version >/dev/null 2>&1 && echo curl -Lo || echo wget -O)"
_is_ci() {
    for v in "JENKINS_URL TRAVIS CIRCLECI GITHUB_ACTIONS GITLAB_CI TF_BUILD BITBUCKET_PIPELINE_UUID TEAMCITY_VERSION"; do
        if [ "$v" != "" ] && [ "$v" != "0" ] && [ "$(echo $v | tr '[:upper:]' '[:lower:]')" != "false" ]; then
            return 1
        fi
    done
    return
}
_CI="$(_is_ci && echo 1 || true)"
_CWD="$(pwd)"
if [ "$_CI" = "" ]; then
    export NOCOLOR='\e[0m'
    export RED='\e[0;31m'
    export YELLOW='\e[0;33m'
fi
_error() {
    echo "${RED}MKPM [E]:${NOCOLOR} $@" 1>&2
}
_debug() {
    [ "$MKPM_DEBUG" = "1" ] && echo "${YELLOW}MKPM [D]:${NOCOLOR} $@" || true
}
_project_root() {
    _ROOT="$1"
    if [ "$_ROOT" = "" ]; then
        _ROOT="$(pwd)"
    fi
    if [ -f "$_ROOT/mkpm.json" ]; then
        echo "$_ROOT"
        return
    fi
    _PARENT="$(echo "$_ROOT" | sed 's|\/[^\/]\+$||g')"
    if ([ "$_PARENT" = "" ] || [ "$_PARENT" = "/" ]); then
        echo "/"
        return
    fi
    echo "$(_project_root $_PARENT)"
    return
}
_is_mkpm_proxy() {
    ([ "$1" = "init" ] || [ "$1" = "" ]) && exit 1
    while test $# -gt 0; do
        case "$1" in
            -h|--help)
                exit 1
            ;;
            -*)
                shift
            ;;
            *)
                break
            ;;
        esac
    done
}
export PROJECT_ROOT="$(_project_root)"
if [ "$PROJECT_ROOT" = "/" ]; then
    if _is_mkpm_proxy "$@"; then
        _error "not an mkpm project" && exit 1
    else
        PROJECT_ROOT="$_CWD"
    fi
fi
_MKPM_ROOT="$PROJECT_ROOT/.mkpm"
_MKPM="$_MKPM_ROOT/mkpm"
_MKPM_BIN="$MKPM/.bin"
if [ ! -f "$_MKPM_BIN/mkpm" ]; then
    mkdir -p "$_MKPM_BIN"
    if [ -f "$_MKPM_ROOT/cache.tar.gz" ]; then
        mkdir -p "$_MKPM"
        cd "$_MKPM"
        tar -xzf "$_MKPM_ROOT/cache.tar.gz"
        cd "$_CWD"
        _debug restored cache
    else
        download "$_MKPM_BIN/mkpm" "$MKPM_SH_URL" >/dev/null
        _debug downloaded mkpm.sh
    fi
    chmod +x "$_MKPM_BIN/mkpm"
fi
_ensure_mkpm_sh
exec "$_MKPM_BIN/mkpm" "$@"
