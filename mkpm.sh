#!/bin/sh

export _CWD=$(pwd)
export _USER_ID=$(id -u $USER)
export _TMP_PATH="${XDG_RUNTIME_DIR:-$([ -d "/run/user/$_USER_ID" ] && echo "/run/user/$_USER_ID" || echo ${TMP:-${TEMP:-/tmp}})}/mkpm/$$"
export _STATE_PATH="${XDG_STATE_HOME:-$HOME/.local/state}/mkpm"
export _REPOS_PATH="$_STATE_PATH/repos"
export _REPOS_LIST_PATH="$_STATE_PATH/repos.list"

main() {
    _prepare
    if [ "$_COMMAND" = "install" ]; then
        local _REPO_URI=$(_lookup_repo_uri $_REPO)
        if [ "$_REPO_URI" = "" ]; then
            echo "repo $_REPO is not valid"
            exit 1
        fi
        if ! _is_repo_uri "$_REPO"; then
            local _REPO_NAME="$(echo $_REPO | tr '[:lower:]' '[:upper:]')"
        fi
        _install $_PARAM $_REPO_URI $_REPO_NAME
    elif [ "$_COMMAND" = "remove" ]; then
        _remove $_PARAM
    elif [ "$_COMMAND" = "dependencies" ]; then
        _dependencies $_PARAM
    elif [ "$_COMMAND" = "repo-add" ]; then
        _repo_add $_REPO_NAME $_REPO_URI
    elif [ "$_COMMAND" = "repo-remove" ]; then
        _repo_remove $_REPO_NAME
    fi
}

_install() {
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
    fi
    echo installed ${_PACKAGE_NAME}=${_PACKAGE_VERSION}
}

_is_repo_uri() {
    echo "$1" | grep -E '^(\w+://.+)|(git@.+:.+)$' >/dev/null 2>/dev/null
}

_lookup_repo_uri() {
    if _is_repo_uri "$_REPO"; then
        echo $_REPO
        return
    fi
    local _REPO_URI=$(eval 'echo $MKPM_REPO_'$(echo "$_REPO" | tr '[:lower:]' '[:upper:]'))
    if [ "$_REPO_URI" = "" ] && [ -f "$_CWD/mkpm.mk" ]; then
        local _LINE=$(cat -n "$_CWD/mkpm.mk" | \
            grep "MKPM_REPO_$(echo "$_REPO" | tr '[:lower:]' '[:upper:]')\s")
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
    env | cut -d'=' -f1 | grep -E 'MKPM_REPO_\w+'
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
    if ! _is_repo_uri "$_REPO_URI"; then
        echo "invalid repo uri $_REPO_URI" 1>&2
        exit 1
    fi
    local _BODY="MKPM_PACKAGES_$(echo $_REPO_NAME | tr '[:lower:]' '[:upper:]') := \\\\\n\nMKPM_REPO_$(echo $_REPO_NAME | tr '[:lower:]' '[:upper:]') := \\\\\n	${_REPO_URI}"
    local _LINE_NUMBER=$(cat -n "$_CWD/mkpm.mk" | grep "#\+ MKPM BOOTSTRAP SCRIPT BEGIN" | grep -oE '[0-9]+')
    if [ "$_LINE_NUMBER" = "" ]; then
        sed -i -e "\$a\\\\n${_BODY}" "$_CWD/mkpm.mk"
    else
        sed -i "${_LINE_NUMBER}i\\${_BODY}\n" "$_CWD/mkpm.mk"
    fi
    echo repo-add $_REPO_NAME $_REPO_URI
}

_repo_remove() {
    if [ "$MKPM" != "" ]; then
        echo repo-remove cannot be run from mkpm 1>&2
        exit 1
    fi
    local _REPO_NAME=$1
    echo repo-remove $_REPO_NAME
}

# _repo_add() {
#     if [ ! -f "$_REPOS_LIST_PATH" ]; then
#         touch $_REPOS_LIST_PATH
#     fi
#     echo "$(_repo_list)
# $1" | sort | uniq > $_REPOS_LIST_PATH.tmp
#     mv $_REPOS_LIST_PATH.tmp $_REPOS_LIST_PATH
#     echo added repo $1
#     _update_repo
# }

# _repo_remove() {
#     for r in $(_repo_list); do
#         if [ "$r" != "$1" ]; then
#             echo $r
#         fi
#     done | sort | uniq > $_REPOS_LIST_PATH.tmp
#     mv $_REPOS_LIST_PATH.tmp $_REPOS_LIST_PATH
#     echo removed repo $1
# }

# _repo_list() {
#     cat $_REPOS_LIST_PATH | sed '/^$/d' | sort | uniq
# }

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
    i|install)
        shift
        export _COMMAND=install
        if test $# -gt 0; then
            export _REPO=$1
            shift
        else
            echo "no repo specified" 1>&2
            exit 1
        fi
        if test $# -gt 0; then
            export _PARAM=$1
            shift
        else
            echo "no package specified" 1>&2
            exit 1
        fi
    ;;
    r|remove)
        shift
        if test $# -gt 0; then
            export _COMMAND=remove
            export _PARAM=$1
            shift
        else
            echo "no package specified" 1>&2
            exit 1
        fi
    ;;
    d|dependencies)
        shift
        if test $# -gt 0; then
            export _COMMAND=dependencies
            export _PARAM=$1
            shift
        else
            echo "no package specified" 1>&2
            exit 1
        fi
    ;;
    ra|repo-add)
        shift
        if test $# -gt 0; then
            export _COMMAND=repo-add
            export _REPO_NAME=$1
            shift
        else
            echo "no repo name specified" 1>&2
            exit 1
        fi
        if test $# -gt 0; then
            export _REPO_URI=$1
            shift
        else
            echo "no repo uri specified" 1>&2
            exit 1
        fi
    ;;
    rr|repo-remove)
        shift
        if test $# -gt 0; then
            export _COMMAND=repo-remove
            export _REPO_NAME=$1
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
