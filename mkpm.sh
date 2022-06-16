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
        _install $_PARAM $_REPO
    elif [ "$_COMMAND" = "remove" ]; then
        _remove $_PARAM
    elif [ "$_COMMAND" = "dependencies" ]; then
        _dependencies $_PARAM
    fi
}

_install() {
    _PACKAGE=$1
    _PACKAGE_NAME=$(echo $_PACKAGE | cut -d'=' -f1)
    _PACKAGE_VERSION=$(echo $_PACKAGE | cut -d'=' -f2)
    _REPO=$2
    _REPO_PATH=$(_repo_path $_REPO)
    _update_repo $_REPO $_REPO_PATH
    _run cd "$_REPO_PATH"
    _DEFAULT_BRANCH=$(cd "$_REPO_PATH" && git branch --show-current)
    git add . >/dev/null
    git reset --hard >/dev/null
    git checkout $_DEFAULT_BRANCH >/dev/null 2>/dev/null
    git config advice.detachedHead false >/dev/null
    git checkout $_PACKAGE_NAME/$_PACKAGE_VERSION >/dev/null 2>/dev/null
    _run git lfs pull
    _run rm -rf "$_CWD/.mkpm/.pkgs/$_PACKAGE_NAME"
    _run mkdir -p "$_CWD/.mkpm/.pkgs/$_PACKAGE_NAME"
    tar -xzvf "$_REPO_PATH/$_PACKAGE_NAME/$_PACKAGE_NAME.tar.gz" -C "$_CWD/.mkpm/.pkgs/$_PACKAGE_NAME" >/dev/null
    git checkout $_DEFAULT_BRANCH >/dev/null 2>/dev/null
    _echo installed $1
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
        _run cd "$_REPO_PATH"
        git pull >/dev/null
    else
        git clone $1 "$_REPO_PATH" >/dev/null
    fi
}

_repo_path() {
    echo $_REPOS_PATH/$(echo $1 | md5sum | cut -d ' ' -f1)
}

_echo() {
    if [ "$_SILENT" != "1" ]; then
        echo $@
    fi
}

_get_default_branch() {
    git branch -r --points-at refs/remotes/origin/HEAD | grep '\->' | cut -d' ' -f5 | cut -d/ -f2
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
            echo "    i install <PACKAGE> <REPO>    install a package from git repo"
            echo "    r remove <PACKAGE>            remove a package"
            echo "    d dependencies <PACKAGE>      dependencies required by package"
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
            export _PARAM=$1
            shift
        else
            echo "no package specified" 1>&2
            exit 1
        fi
        if test $# -gt 0; then
            export _REPO=$1
            shift
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
    *)
        echo "invalid command $1" 1>&2
        exit 1
    ;;
esac

main
