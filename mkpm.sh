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
        _install $_PARAM
    elif [ "$_COMMAND" = "remove" ]; then
        _remove $_PARAM
    elif [ "$_COMMAND" = "dependencies" ]; then
        _dependencies $_PARAM
    elif [ "$_COMMAND" = "available" ]; then
        _available
    elif [ "$_COMMAND" = "repo-add" ]; then
        _repo_add $_PARAM
    elif [ "$_COMMAND" = "repo-remove" ]; then
        _repo_remove $_PARAM
    elif [ "$_COMMAND" = "repo-list" ]; then
        _repo_list
    fi
}

_install() {
    _update_repos
    for r in $(ls $_REPOS_PATH); do
        cd $_REPOS_PATH/$r
        git checkout $(echo $1 | cut -d'=' -f2) 2>/dev/null
        git lfs pull
        if [ "$?" != "0" ]; then
            continue
        fi
        _NAME=$(echo $1 | cut -d'=' -f1)
        mkdir -p $_CWD/.mkpm/.pkgs/$_NAME
        tar -xzvf $_NAME/$_NAME.tar.gz -C $_CWD/.mkpm/.pkgs/$_NAME
    done
    echo install $1
}

_remove() {
    echo remove $1
}

_dependencies() {
    _update_repos
    echo dependencies $1
}

_available() {
    _update_repos
    echo available
}

_repo_add() {
    if [ ! -f "$_REPOS_LIST_PATH" ]; then
        touch $_REPOS_LIST_PATH
    fi
    echo "$(_repo_list)
$1" | sort | uniq > $_REPOS_LIST_PATH.tmp
    mv $_REPOS_LIST_PATH.tmp $_REPOS_LIST_PATH
    echo added repo $1
    _update_repos
}

_repo_remove() {
    for r in $(_repo_list); do
        if [ "$r" != "$1" ]; then
            echo $r
        fi
    done | sort | uniq > $_REPOS_LIST_PATH.tmp
    mv $_REPOS_LIST_PATH.tmp $_REPOS_LIST_PATH
    echo removed repo $1
}

_repo_list() {
    cat $_REPOS_LIST_PATH | sed '/^$/d' | sort | uniq
}

_prepare() {
    if [ ! -f "$_REPOS_PATH" ]; then
        mkdir -p "$_REPOS_PATH"
    fi
}

_update_repos() {
    for r in $(cat $_REPOS_LIST_PATH); do
        _REPO_PATH="$(_repo_path $r)"
        if [ -d "$_REPO_PATH" ]; then
            cd "$_REPO_PATH" && git pull
        else
            git clone $r "$_REPO_PATH"
        fi
    done
}

_repo_path() {
    echo $_REPOS_PATH/$(echo $1 | md5sum | cut -d ' ' -f1)
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
            echo "    -h, --help                  show brief help"
            echo " "
            echo "commands:"
            echo "    i install <PACKAGE>         install a package"
            echo "    r remove <PACKAGE>          remove a package"
            echo "    d dependencies <PACKAGE>    dependencies required by package"
            echo "    a available                 list available packages"
            echo "    ra repo-add <REPO>          add a repo"
            echo "    rr remove-repo <REPO>       remove a repo"
            echo "    rl repo-list                list repos"
            exit 0
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
        fi
    ;;
    r|remove)
        shift
        if test $# -gt 0; then
            export _COMMAND=remove
            export _PARAM=$1
        else
            echo "no package specified" 1>&2
            exit 1
        fi
        shift
    ;;
    d|dependencies)
        shift
        if test $# -gt 0; then
            export _COMMAND=dependencies
            export _PARAM=$1
        else
            echo "no package specified" 1>&2
            exit 1
        fi
        shift
    ;;
    a|available)
        shift
        export _COMMAND=available
    ;;
    ra|repo-add)
        shift
        if test $# -gt 0; then
            export _COMMAND=repo-add
            export _PARAM=$1
        else
            echo "no repo specified" 1>&2
            exit 1
        fi
    ;;
    rr|repo-remove)
        shift
        if test $# -gt 0; then
            export _COMMAND=repo-remove
            export _PARAM=$1
        else
            echo "no repo specified" 1>&2
            exit 1
        fi
    ;;
    rl|repo-list)
        shift
        export _COMMAND=repo-list
    ;;
    update) # DEPRICATED: remove in the future
        shift
        exit 0
    ;;
    *)
        echo "invalid command $1" 1>&2
        exit 1
    ;;
esac

main
