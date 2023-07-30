#!/bin/sh

MKPM_VERSION="<% MKPM_VERSION %>"
MKPM_SH_URL="${MKPM_SH_URL:-https://gitlab.com/api/v4/projects/33018371/packages/generic/mkpm/${MKPM_VERSION}/mkpm.sh}"
alias download="$(curl --version >/dev/null 2>&1 && echo curl -Lo || echo wget -O)"
for v in "JENKINS_URL TRAVIS CIRCLECI GITHUB_ACTIONS GITLAB_CI TF_BUILD BITBUCKET_PIPELINE_UUID TEAMCITY_VERSION"; do
    if [ "$v" != "" ] && [ "$v" != "0" ] && [ "$(echo $v | tr '[:upper:]' '[:lower:]')" != "false" ]; then
        _CI=1
        break
    fi
done
_CWD="$(pwd)"
if [ "$_CI" = "" ]; then
    export NOCOLOR='\e[0m'
    export RED='\e[0;31m'
    export YELLOW='\e[0;33m'
fi
_error() { echo "${RED}MKPM [E]:${NOCOLOR} $@" 1>&2; }
_debug() { [ "$MKPM_DEBUG" = "1" ] && echo "${YELLOW}MKPM [D]:${NOCOLOR} $@" || true; }
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
_is_mkpm_proxy_required() {
    _ARGS="$@"
    _1="$(echo "$_ARGS" | cut -d' ' -f1)"
    while test $# -gt 0; do
        case "$_1" in
            -h|--help)
                return 1
            ;;
            -*)
                _ARGS=$(echo "$_ARGS" | sed 's|^[^ ]\+ \?||g')
                _1="$(echo "$_ARGS" | cut -d' ' -f1)"
            ;;
            v|version|init)
                return 1
            ;;
            *)
                break
            ;;
        esac
    done
    [ "$_1" = "" ] && return 1 || true
}
export PROJECT_ROOT="$(_project_root)"
if [ "$PROJECT_ROOT" = "/" ]; then
    if _is_mkpm_proxy_required "$@"; then
        _error "not an mkpm project" && exit 1
    else
        PROJECT_ROOT="$_CWD"
    fi
fi
MKPM_ROOT="$PROJECT_ROOT/.mkpm"
MKPM="$MKPM_ROOT/mkpm"
_MKPM_BIN="$MKPM/.bin"
if [ ! -f "$_MKPM_BIN/mkpm" ]; then
    mkdir -p "$_MKPM_BIN"
    if [ -f "$MKPM_ROOT/cache.tar.gz" ]; then
        mkdir -p "$MKPM"
        cd "$MKPM"
        tar -xzf "$MKPM_ROOT/cache.tar.gz"
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
