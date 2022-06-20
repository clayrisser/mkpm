#!/bin/sh

export MKPM_CLI_VERSION=0.2.0
export _CWD=$(pwd)
export _USER_ID=$(id -u $USER)
export _TMP_PATH="${XDG_RUNTIME_DIR:-$([ -d "/run/user/$_USER_ID" ] && echo "/run/user/$_USER_ID" || echo ${TMP:-${TEMP:-/tmp}})}/mkpm/$$"
export _STATE_PATH="${XDG_STATE_HOME:-$HOME/.local/state}/mkpm"
export _REPOS_PATH="$_STATE_PATH/repos"
export _REPOS_LIST_PATH="$_STATE_PATH/repos.list"

main() {
    _prepare
    if [ "$_COMMAND" = "install" ]; then
        if [ "$_PARAM1" = "" ] && [ "$_PARAM2" = "" ]; then
            _install
            return
        fi
        local _REPO=$_PARAM1
        local _PACKAGE=$_PARAM2
        local _REPO_URI=$(_lookup_repo_uri $_REPO)
        if [ "$_REPO_URI" = "" ]; then
            echo "repo $_REPO is not valid"
            exit 1
        fi
        if ! _is_repo_uri "$_REPO"; then
            local _REPO_NAME="$(echo $_REPO | tr '[:lower:]' '[:upper:]')"
        fi
        _install $_PACKAGE $_REPO_URI $_REPO_NAME
    elif [ "$_COMMAND" = "remove" ]; then
        _remove $_PARAM1
    elif [ "$_COMMAND" = "dependencies" ]; then
        _dependencies $_PARAM1
    elif [ "$_COMMAND" = "repo-add" ]; then
        local _REPO_NAME=$_PARAM1
        local _REPO_URI=$_PARAM2
        _repo_add $_REPO_NAME $_REPO_URI
    elif [ "$_COMMAND" = "repo-remove" ]; then
        _repo_remove $_PARAM1
    fi
}

_install() {
    if [ "$1" = "" ]; then
        for r in $(_lookup_repos); do
            for p in $(eval $(echo "echo \$MKPM_PACKAGES_$(echo $r | tr '[:lower:]' '[:upper:]')")); do
                _install $p $(_lookup_repo_uri $r) $r
            done
        done
        exit 1
        return
    fi
    local _PACKAGE=$1
    local _PACKAGE_NAME=$(echo $_PACKAGE | cut -d'=' -f1)
    local _PACKAGE_VERSION=$(echo $_PACKAGE | sed 's|^[^=]\+\=\?||g')
    local _REPO=$2
    local _REPO_PATH=$(_repo_path $_REPO)
    local _REPO_NAME=$3
    _update_repo $_REPO $_REPO_PATH
    cd "$_REPO_PATH" || exit 1
    git add . >/dev/null
    git reset --hard >/dev/null
    git config advice.detachedHead false >/dev/null
    if [ "$_PACKAGE_VERSION" = "" ]; then
        _PACKAGE_VERSION=$(git tag | grep -E "${_PACKAGE_NAME}/" | sed "s|${_PACKAGE_NAME}/||g" | tail -n1)
    fi
    if [ "$_PACKAGE_VERSION" = "" ]; then
        echo "package $_PACKAGE_NAME does not exist" 1>&2
        exit 1
    fi
    if ! git checkout $_PACKAGE_NAME/$_PACKAGE_VERSION >/dev/null 2>/dev/null; then
        echo "package ${_PACKAGE_NAME}=${_PACKAGE_VERSION} does not exist" 1>&2
        exit 1
    fi
    git lfs pull
    if [ ! -f "$_REPO_PATH/$_PACKAGE_NAME/$_PACKAGE_NAME.tar.gz" ]; then
        echo "package ${_PACKAGE_NAME}=${_PACKAGE_VERSION} does not exist" 1>&2
        exit 1
    fi
    rm -rf "$_CWD/.mkpm/.pkgs/$_PACKAGE_NAME"
    mkdir -p "$_CWD/.mkpm/.pkgs/$_PACKAGE_NAME"
    tar -xzvf "$_REPO_PATH/$_PACKAGE_NAME/$_PACKAGE_NAME.tar.gz" -C "$_CWD/.mkpm/.pkgs/$_PACKAGE_NAME" >/dev/null
    if [ "$MKPM" = "" ] && [ "$_REPO_NAME" != "" ]; then
        sed -i "/^\(\s{4}\|\t\)${_PACKAGE_NAME}=[0-9]\(\.[0-9]\)*\s*\\\\\?\s*$/d" "$_CWD/mkpm.mk"
        _LINE_NUMBER=$(expr $(cat -n "$_CWD/mkpm.mk" | grep "MKPM_PACKAGES_${_REPO_NAME} := \\\\" | grep -oE '[0-9]+') + 1)
        sed -i "${_LINE_NUMBER}i\\	${_PACKAGE_NAME}=${_PACKAGE_VERSION} \\\\" "$_CWD/mkpm.mk"
        _trim_mkpm_file
    fi
    echo installed ${_PACKAGE_NAME}=${_PACKAGE_VERSION}
}

_is_repo_uri() {
    echo "$1" | grep -E '^(\w+://.+)|(git@.+:.+)$' >/dev/null 2>/dev/null
}

_lookup_repo_uri() {
    local _REPO=$1
    if _is_repo_uri "$_REPO"; then
        echo $_REPO
        return
    fi
    local _REPO_URI=$(eval 'echo $MKPM_REPO_'$(echo "$_REPO" | tr '[:lower:]' '[:upper:]'))
    if [ "$_REPO_URI" = "" ] && [ -f "$_CWD/mkpm.mk" ]; then
        local _LINE=$(cat -n "$_CWD/mkpm.mk" | \
            grep "MKPM_REPO_$(echo "$_REPO" | tr '[:lower:]' '[:upper:]')\s" | head -n1)
        if echo $_LINE | grep -E '\\\s*$' >/dev/null 2>/dev/null; then
            local _LINE_NUMBER="$(expr $(echo $_LINE | \
                grep -oE '[0-9]+') + 1)"
            _REPO_URI=$(cat -n "$_CWD/mkpm.mk" | grep -E "^\s+$_LINE_NUMBER\s+" | \
                sed "s|^\s*[0-9]\+\s\+||g")
        else
            _REPO_URI=$(echo $_LINE | \
                sed "s|^\s*[0-9]\+\s\+MKPM_REPO_\w\+\s\+:=\s\+||g")
        fi
    fi
    if _is_repo_uri "$_REPO_URI"; then
        echo "$_REPO_URI"
    fi
}

_lookup_repos() {
    env | \
        cut -d'=' -f1 | \
        grep -E 'MKPM_REPO_\w+' | \
        sed 's|^MKPM_REPO_||g' | \
        tr '[:upper:]' '[:lower:]'
}

_remove() {
    echo remove $1
}

_dependencies() {
    _update_repo
    echo dependencies $1
}

_prepare() {
    if [ ! -f "$_REPOS_PATH" ]; then
        mkdir -p "$_REPOS_PATH"
    fi
}

_update_repo() {
    _REPO=$1
    _REPO_PATH=$2
    if [ -d "$_REPO_PATH" ]; then
        cd "$_REPO_PATH"
        git fetch --all >/dev/null
    else
        git clone $1 "$_REPO_PATH" >/dev/null
    fi
}

_repo_path() {
    echo $_REPOS_PATH/$(echo $1 | md5sum | cut -d ' ' -f1)
}

_get_default_branch() {
    git branch -r --points-at refs/remotes/origin/HEAD | grep '\->' | cut -d' ' -f5 | cut -d/ -f2
}

_repo_add() {
    if [ "$MKPM" != "" ]; then
        echo repo-add cannot be run from mkpm 1>&2
        exit 1
    fi
    local _REPO_NAME=$1
    local _REPO_URI=$2
    if [ "$(_lookup_repo_uri $_REPO_NAME)" != "" ]; then
        echo "repo $_REPO_NAME already exists" 1>&2
        exit 1
    fi
    if ! _is_repo_uri "$_REPO_URI"; then
        echo "invalid repo uri $_REPO_URI" 1>&2
        exit 1
    fi
    local _BODY="export MKPM_PACKAGES_$(echo $_REPO_NAME | tr '[:lower:]' '[:upper:]') := \\\\\n\nexport MKPM_REPO_$(echo $_REPO_NAME | tr '[:lower:]' '[:upper:]') := \\\\\n	${_REPO_URI}"
    local _LINE_NUMBER=$(cat -n "$_CWD/mkpm.mk" | grep "#\+ MKPM BOOTSTRAP SCRIPT BEGIN" | grep -oE '[0-9]+')
    if [ "$_LINE_NUMBER" = "" ]; then
        sed -i -e "\$a\\\\n${_BODY}" "$_CWD/mkpm.mk"
    else
        sed -i "${_LINE_NUMBER}i\\${_BODY}\n" "$_CWD/mkpm.mk"
    fi
    _trim_mkpm_file
    echo "added repo $_REPO_NAME"
}

_repo_remove() {
    if [ "$MKPM" != "" ]; then
        echo repo-remove cannot be run from mkpm 1>&2
        exit 1
    fi
    local _REPO_NAME=$1
    if [ "$(_lookup_repo_uri $_REPO_NAME)" = "" ]; then
        echo "repo $_REPO_NAME does not exist" 1>&2
        exit 1
    fi
    sed -i -z "s|\s*export[ ]\+MKPM_PACKAGES_$(echo $_REPO_NAME | tr '[:lower:]' '[:upper:]' \
        )"'[ \t]\+:=[ \t]*\\[ \t]*\(\n[ \t]*[^ \t\n=]\+=[^ \t\n]\+\([ \t]\+\\\)\?[ \t]*\)*\s*export[ ]\+MKPM_REPO_'"$( \
            echo $_REPO_NAME | tr '[:lower:]' '[:upper:]' \
        )"'[ \t]\+:=[ \t]*\\[ \t]*\n[ \t]*[^\n]\+\s*|\n\n|' "$_CWD/mkpm.mk"
    _trim_mkpm_file
    echo "removed repo $_REPO_NAME"
}

_trim_mkpm_file() {
    sed -i -z 's|\t\([^ \t\n=]\+=[^ \t\n]\+\)[ \t]\+\\[ \t]*\n\([ \t]*\n[ \t]*\)\+|\t\1\n\n|g' "$_CWD/mkpm.mk"
}

if ! test $# -gt 0; then
    set -- "-h"
fi

while test $# -gt 0; do
    case "$1" in
        -h|--help)
            echo "mkpm - makefile package manager"
            echo " "
            echo "mkpm [options] command <PACKAGE>"
            echo " "
            echo "options:"
            echo "    -h, --help                    show brief help"
            echo "    -s, --silent                  silent output"
            echo " "
            echo "commands:"
            echo "    i install <REPO> <PACKAGE>            install a package from git repo"
            echo "    r remove <PACKAGE>                    remove a package"
            echo "    d dependencies <PACKAGE>              dependencies required by package"
            echo "    ra repo-add <REPO_NAME> <REPO_URI>    add repo"
            echo "    rr repo-remove <REPO_NAME>            remove repo"
            exit 0
        ;;
        -s|--silent)
            export _SILENT=1
            shift
        ;;
        -*)
            echo "invalid option $1" 1>&2
            exit 1
        ;;
        *)
            break
        ;;
    esac
done

case "$1" in
    _install)
        export _COMMAND=install
        shift
    ;;
    i|install)
        export _COMMAND=install
        shift
        if test $# -gt 0; then
            export _PARAM1=$1
            shift
        else
            echo "no repo specified" 1>&2
            exit 1
        fi
        if test $# -gt 0; then
            export _PARAM2=$1
            shift
        else
            echo "no package specified" 1>&2
            exit 1
        fi
    ;;
    r|remove)
        export _COMMAND=remove
        shift
        if test $# -gt 0; then
            export _PARAM1=$1
            shift
        else
            echo "no package specified" 1>&2
            exit 1
        fi
    ;;
    d|dependencies)
        export _COMMAND=dependencies
        shift
        if test $# -gt 0; then
            export _PARAM1=$1
            shift
        else
            echo "no package specified" 1>&2
            exit 1
        fi
    ;;
    ra|repo-add)
        export _COMMAND=repo-add
        shift
        if test $# -gt 0; then
            export _PARAM1=$1
            shift
        else
            echo "no repo name specified" 1>&2
            exit 1
        fi
        if test $# -gt 0; then
            export _PARAM2=$1
            shift
        else
            echo "no repo uri specified" 1>&2
            exit 1
        fi
    ;;
    rr|repo-remove)
        export _COMMAND=repo-remove
        shift
        if test $# -gt 0; then
            export _PARAM1=$1
            shift
        else
            echo "no repo name specified" 1>&2
            exit 1
        fi
    ;;
    *)
        echo "invalid command $1" 1>&2
        exit 1
    ;;
esac

main
