#!/bin/sh

MKPM_CORE_URL="https://gitlab.com/api/v4/projects/29276259/packages/generic/mkpm/0.3.0/bootstrap.mk"

__0="$0"
__ARGS="$@"

alias gsed="$(gsed --version >/dev/null 2>&1 && echo gsed || echo sed)"
alias which="command -v"

_is_ci() {
    _CI_ENVS="JENKINS_URL TRAVIS CIRCLECI GITHUB_ACTIONS GITLAB_CI TF_BUILD BITBUCKET_PIPELINE_UUID TEAMCITY_VERSION"
    for v in $_CI_ENVS; do
        if [ "$v" != "" ] && [ "$v" != "0" ] && [ "$(echo $v | tr '[:upper:]' '[:lower:]')" != "false" ]; then
            return 1
        fi
    done
    return
}

_CWD="$(pwd)"
_USER_ID=$(id -u $USER)
_TMP_PATH="${XDG_RUNTIME_DIR:-$([ -d "/run/user/$_USER_ID" ] && \
    echo "/run/user/$_USER_ID" || echo ${TMP:-${TEMP:-/tmp}})}/mkpm/$$"
_STATE_PATH="${XDG_STATE_HOME:-$HOME/.local/state}/mkpm"
_REPOS_PATH="$_STATE_PATH/repos"
_REPOS_LIST_PATH="$_STATE_PATH/repos.list"
_CI="$(_is_ci && echo 1 || true)"
export GIT_LFS_SKIP_SMUDGE=1
export LC_ALL=C

if [ "$_CI" = "" ]; then
    export NOCOLOR='\e[0m'
    export WHITE='\e[1;37m'
    export BLACK='\e[0;30m'
    export RED='\e[0;31m'
    export GREEN='\e[0;32m'
    export YELLOW='\e[0;33m'
    export BLUE='\e[0;34m'
    export PURPLE='\e[0;35m'
    export CYAN='\e[0;36m'
    export LIGHT_GRAY='\e[0;37m'
    export DARK_GRAY='\e[1;30m'
    export LIGHT_RED='\e[1;31m'
    export LIGHT_GREEN='\e[1;32m'
    export LIGHT_YELLOW='\e[1;33m'
    export LIGHT_BLUE='\e[1;34m'
    export LIGHT_PURPLE='\e[1;35m'
    export LIGHT_CYAN='\e[1;36m'
fi

main() {
    _prepare "$@"
    _run "$_TARGET" "$@"
}


## COMMANDS ##

_run() {
    _TARGET="$1"
    shift
    _ARGS_ENV_NAME="$(echo "$_TARGET" | sed 's|[^A-Za-z0-9_]|_|g' | tr '[:lower:]' '[:upper:]')_ARGS"
    eval "$_ARGS_ENV_NAME=\"$@\" make \"$_TARGET\""
    _CODE="$?"
    exit $_CODE
}

_install() {
    if [ "$1" = "" ]; then
        for r in $(_list_repos); do
            _REPO_URI="$(_lookup_repo_uri $r)"
            if [ "$_REPO_URI" = "" ]; then
                continue
            fi
            _REPO_PATH=$(_lookup_repo_path $_REPO_URI)
            _update_repo "$_REPO_URI" "$_REPO_PATH"
            for p in $(_list_packages "$r"); do
                _install $p "$_REPO_URI" $r
            done
        done
        _create_cache
        return
    fi
    _PACKAGE="$1"
    _PACKAGE_NAME="$(echo $_PACKAGE | cut -d'=' -f1)"
    _PACKAGE_VERSION="$(echo $_PACKAGE | gsed 's|^[^=]*||g' | gsed 's|^=||g')"
    _REPO_URI="$2"
    _REPO_PATH="$(_lookup_repo_path $_REPO_URI)"
    _REPO_NAME="$3"
    cd "$_REPO_PATH" || exit 1
    if [ "$_PACKAGE_VERSION" = "" ]; then
        _PACKAGE_VERSION=$(git tag | grep -E "${_PACKAGE_NAME}/" | \
            gsed "s|${_PACKAGE_NAME}/||g" | \
            sort -t "." -k1,1n -k2,2n -k3,3n | tail -n1)
    fi
    if [ "$_PACKAGE_VERSION" = "" ]; then
        _echo "package $_PACKAGE_NAME does not exist" 1>&2
        exit 1
    fi
    if ! git checkout -f "$_PACKAGE_NAME/$_PACKAGE_VERSION" >/dev/null 2>/dev/null; then
        _echo "package ${_PACKAGE_NAME}=${_PACKAGE_VERSION} does not exist" 1>&2
        exit 1
    fi
    git lfs pull --include "$_PACKAGE_NAME/$_PACKAGE_NAME.tar.gz"
    if [ ! -f "$_REPO_PATH/$_PACKAGE_NAME/$_PACKAGE_NAME.tar.gz" ]; then
        _echo "package ${_PACKAGE_NAME}=${_PACKAGE_VERSION} does not exist" 1>&2
        exit 1
    fi
    _remove $_PACKAGE_NAME
    # echo 'include $(MKPM)'"/.pkgs/$_PACKAGE_NAME/main.mk" > \
    #     "$_CWD/.mkpm/$_PACKAGE_NAME"
    # echo ".PHONY: $_PACKAGE_NAME-%" > "$_CWD/.mkpm/-$_PACKAGE_NAME"
    # echo "$_PACKAGE_NAME-%:" >> "$_CWD/.mkpm/-$_PACKAGE_NAME"
    # echo '	@$(MAKE) -s -f $(MKPM)/.pkgs/'"$_PACKAGE_NAME/main.mk "'$(subst '"$_PACKAGE_NAME-,,$"'@)' >> \
    #     "$_CWD/.mkpm/-$_PACKAGE_NAME"
    mkdir -p "$_MKPM_PACKAGES/$_PACKAGE_NAME"
    tar -xzf "$_REPO_PATH/$_PACKAGE_NAME/$_PACKAGE_NAME.tar.gz" -C "$_MKPM_PACKAGES/$_PACKAGE_NAME" >/dev/null
    _create_cache
    cd "$_CWD"
    _echo "installed ${_PACKAGE_NAME}=${_PACKAGE_VERSION}"
}

_remove() {
    _PACKAGE_NAME="$1"
    rm -rf \
        "$MKPM/$_PACKAGE_NAME" \
        "$MKPM/-$_PACKAGE_NAME" \
        "$_MKPM_PACKAGES/$_PACKAGE_NAME" 2>/dev/null || true
}


## PREPARE ##

_prepare() {
    export PROJECT_ROOT="$(_project_root)"
    export MKPM_CONFIG="$PROJECT_ROOT/mkpm.json"
    export MKPM_ROOT_NAME=".mkpm"
    export MKPM_ROOT="$PROJECT_ROOT/$MKPM_ROOT_NAME"
    export MKPM="$MKPM_ROOT/mkpm"
    _debug PROJECT_ROOT=\"$PROJECT_ROOT\"
    _debug MKPM_CONFIG=\"$MKPM_CONFIG\"
    _debug MKPM_ROOT=\"$MKPM_ROOT\"
    export _MKPM_BIN="$MKPM/.bin"
    export _MKPM_CACHE="$MKPM_ROOT/cache"
    export _MKPM_PACKAGES="$MKPM/.pkgs"
    export _MKPM_TMP="$MKPM/.tmp"
    if [ "$_MKPM_RESET_CACHE" = "1" ] || \
        ([ -f "$PROJECT_ROOT/mkpm.mk" ] && [ "$PROJECT_ROOT/mkpm.mk" -nt "$MKPM/mkpm" ]); then
        _reset_cache
        exit $?
    fi
    if [ ! -f "$MKPM/.prepared" ]; then
        _require_system_binary awk
        _require_system_binary git
        _require_system_binary git-lfs
        _require_system_binary grep
        _require_system_binary jq
        _require_system_binary make
        _require_system_binary tar
        if [ "$PLATFORM" = "darwin" ]; then
            _require_system_binary gsed --version
        else
            _require_system_binary sed --version
        fi
        _ensure_dirs
        if [ ! -d "$_MKPM_PACKAGES" ]; then
            if [ -f "$_MKPM_CACHE/cache.tar.gz" ]; then
                _restore_from_cache
            else
                _install
            fi
        fi
        _ensure_mkpm_mk
        touch "$MKPM/.prepared"
    fi
}

_lookup_system_package_name() {
    _BINARY="$1"
    case "$_BINARY" in
        make)
            case "$PKG_MANAGER" in
                brew)
                    echo remake
                ;;
                *)
                    echo "$_BINARY"
                ;;
            esac
        ;;
        *)
            echo "$_BINARY"
        ;;
    esac
}

_PKG_MANAGER_SUDO="$(which sudo >/dev/null 2>&1 && echo sudo || true) "
_lookup_system_package_install_command() {
    _BINARY="$1"
    _PACKAGE="$([ "$2" = "" ] && echo "$_BINARY" || "$2")"
    case "$PKG_MANAGER" in
        apk)
            echo "$PKG_MANAGER add --no-cache $_PACKAGE"
        ;;
        brew)
            echo "$PKG_MANAGER install $_PACKAGE"
        ;;
        choco)
            echo "$PKG_MANAGER install /y $_PACKAGE"
        ;;
        *)
            echo "${_PKG_MANAGER_SUDO}$PKG_MANAGER install -y $_PACKAGE"
        ;;
    esac
}

_require_system_binary() {
    _SYSTEM_BINARY="$1"
    shift
    _ARGS="$@"
    _SYSTEM_PACKAGE_NAME="$(_lookup_system_package_name "$_SYSTEM_BINARY")"
    _SYSTEM_PACKAGE_INSTALL_COMMAND="$(_lookup_system_package_install_command "$_SYSTEM_PACKAGE_NAME")"
    if ! ([ "$_ARGS" = "" ] && which "$_SYSTEM_BINARY" || "$_SYSTEM_BINARY" "$_ARGS") >/dev/null 2>&1; then
        _echo $_SYSTEM_BINARY is not installed on your system >&2
        printf "you can install $_SYSTEM_BINARY on $FLAVOR with the following command

    ${GREEN}$_SYSTEM_PACKAGE_INSTALL_COMMAND${NOCOLOR}

install for me [${GREEN}Y${NOCOLOR}|${RED}n${NOCOLOR}]: "
        read _RES
        if [ "$(echo "$_RES" | cut -c 1 | tr '[:lower:]' '[:upper:]')" != "N" ]; then
            $_SYSTEM_PACKAGE_INSTALL_COMMAND
            _CODE="$?"
            [ "$_CODE" = "0" ] && true || exit $_CODE
        fi
    else
        _debug system binary $_SYSTEM_BINARY found
    fi
}

_ensure_dirs() {
    if [ ! -d "$MKPM" ]; then
        mkdir -p "$MKPM"
    fi
}

_ensure_mkpm_mk() {
    if [ -f "$PROJECT_ROOT/mkpm.mk" ]; then
        if [ ! -f "$MKPM/mkpm" ] || [ "$PROJECT_ROOT/mkpm.mk" -nt "$MKPM/mkpm" ]; then
            cp "$PROJECT_ROOT/mkpm.mk" "$MKPM/mkpm"
            _debug downloaded mkpm.mk
            _create_cache
        fi
    elif [ ! -f "$MKPM/mkpm" ]; then
        download "$MKPM/mkpm" "$MKPM/mkpm_URL" >/dev/null
        _debug downloaded mkpm.mk
        _create_cache
    fi
}


## CACHE ##

_create_cache() {
    mkdir -p "$_MKPM_CACHE"
    cd "$MKPM"
    touch "$_MKPM_CACHE/cache.tar.gz"
    tar -czf "$_MKPM_CACHE/cache.tar.gz" \
        --exclude '.cache' \
        --exclude '.failed' \
        --exclude '.preflight' \
        --exclude '.ready' \
        --exclude '.prepared' \
        --exclude '.tmp' \
        .
    cd "$_CWD"
    _debug created cache
}

_restore_from_cache() {
    if [ -f "$_MKPM_CACHE/cache.tar.gz" ]; then
        mkdir -p "$MKPM"
        cd "$MKPM"
        tar -xzf "$_MKPM_CACHE/cache.tar.gz" >/dev/null
        cd "$_CWD"
        _debug restored cache
    fi
}

_reset_cache() {
    rm -rf \
        "$_MKPM_CACHE" \
        "$MKPM/.prepared" \
        "$MKPM/mkpm" 2>/dev/null || true
    unset _MKPM_RESET_CACHE
    _debug reset cache
    exec "$__0" "$__ARGS"
}


## REPOS ##

_list_repos() {
    cat "$MKPM_CONFIG" | jq -r '(.repos | keys)[]'
}

_lookup_repo_uri() {
    _REPO="$1"
    shift
    cat "$MKPM_CONFIG" | jq -r ".repos.$_REPO"
}

_lookup_repo_path() {
    echo "$_REPOS_PATH/$(echo "$1" | md5sum | cut -d ' ' -f1)"
}

_update_repo() {
    _REPO_URI="$1"
    shift
    _REPO_PATH="$1"
    shift
    _echo "updating repo $_REPO_URI"
    if [ ! -d "$_REPO_PATH" ]; then
        git clone -q --depth 1 "$_REPO_URI" "$_REPO_PATH" || exit 1
    fi
    cd "$_REPO_PATH"
    git config advice.detachedHead false >/dev/null
    git config lfs.locksverify true >/dev/null
    git fetch -q --depth 1 --tags || exit 1
    cd "$_CWD"
}


## PACKAGES ##

_list_packages() {
    _REPO="$1"
    shift
    for p in $(cat "$MKPM_CONFIG" | jq -r "(.packages.${_REPO} | keys)[]"); do
        echo "$p"
    done
}


## UTIL ##

_echo() {
    echo "${LIGHT_CYAN}MKPM [I]:${NOCOLOR} $@"
}

_debug() {
    [ "$MKPM_DEBUG" = "1" ] && echo "${YELLOW}MKPM [D]:${NOCOLOR} $@" || true
}

_error() {
    echo "${RED}MKPM [E]:${NOCOLOR} $@" 1>&2
}

_project_root() {
    _ROOT=$1
    if [ "$_ROOT" = "" ]; then
        _ROOT="$(pwd)"
    fi
    if [ -f "$_ROOT/mkpm.json" ]; then
        echo $_ROOT
        return
    fi
    _PARENT=$(echo $_ROOT | sed 's|\/[^\/]\+$||g')
    if ([ "$_PARENT" = "" ] || [ "$_PARENT" = "/" ]); then
        echo "/"
        return
    fi
    echo $(_project_root $_PARENT)
    return
}

export ARCH=unknown
export FLAVOR=unknown
export PKG_MANAGER=unknown
export PLATFORM=unknown
if [ "$OS" = "Windows_NT" ]; then
	export HOME="${HOMEDRIVE}${HOMEPATH}"
	PLATFORM=win32
	FLAVOR=win64
	ARCH="$PROCESSOR_ARCHITECTURE"
	PKG_MANAGER=choco
    if [ "$ARCH" = "AMD64" ]; then
		ARCH=amd64
    elif [ "$ARCH" = "ARM64" ]; then
		ARCH=arm64
    fi
    if [ "$PROCESSOR_ARCHITECTURE" = "x86" ]; then
		ARCH=amd64
        if [ "$PROCESSOR_ARCHITEW6432" = "" ]; then
			ARCH=x86
			FLAVOR=win32
        fi
    fi
else
	PLATFORM=$(uname 2>/dev/null | tr '[:upper:]' '[:lower:]' 2>/dev/null)
	ARCH=$( ( dpkg --print-architecture 2>/dev/null || uname -m 2>/dev/null || arch 2>/dev/null || echo unknown) | \
        tr '[:upper:]' '[:lower:]' 2>/dev/null)
    if [ "$ARCH" = "i386" ] || [ "$ARCH" = "i686" ]; then
		ARCH=386
    elif [ "$ARCH" = "x86_64" ]; then
		ARCH=amd64
    fi
	if [ "$PLATFORM" = "linux" ]; then
        if [ -f /system/bin/adb ]; then
            if [ "$(getprop --help >/dev/null 2>/dev/null && echo 1 || echo 0)" = "1" ]; then
                PLATFORM=android
            fi
        fi
        if [ "$PLATFORM" = "linux" ]; then
            FLAVOR=$(lsb_release -si 2>/dev/null | tr '[:upper:]' '[:lower:]' 2>/dev/null)
            if [ "$FLAVOR" = "" ]; then
                FLAVOR=unknown
                if [ -f /etc/redhat-release ]; then
                    FLAVOR=rhel
                elif [ -f /etc/SuSE-release ]; then
                    FLAVOR=suse
                elif [ -f /etc/debian_version ]; then
                    FLAVOR=debian
                elif (cat /etc/os-release 2>/dev/null | grep -qE '^ID=alpine$'); then
                    FLAVOR=alpine
                fi
            fi
            if [ "$FLAVOR" = "rhel" ]; then
				PKG_MANAGER=$(which microdnf >/dev/null 2>&1 && echo microdnf || \
                    echo $(which dnf >/dev/null 2>&1 && echo dnf || echo yum))
            elif [ "$FLAVOR" = "suse" ]; then
				PKG_MANAGER=zypper
            elif [ "$FLAVOR" = "debian" ]; then
				PKG_MANAGER=apt-get
            elif [ "$FLAVOR" = "ubuntu" ]; then
				PKG_MANAGER=apt-get
            elif [ "$FLAVOR" = "alpine" ]; then
				PKG_MANAGER=apk
            fi
        fi
	elif [ "$PLATFORM" = "darwin" ]; then
		PKG_MANAGER=brew
    else
        if (echo "$PLATFORM" | grep -q 'MSYS'); then
			PLATFORM=win32
			FLAVOR=msys
			PKG_MANAGER=pacman
        elif (echo "$PLATFORM" | grep -q 'MINGW'); then
			PLATFORM=win32
			FLAVOR=msys
			PKG_MANAGER=mingw-get
        elif (echo "$PLATFORM" | grep -q 'CYGWIN'); then
			PLATFORM=win32
			FLAVOR=cygwin
        fi
    fi
fi
if [ "$FLAVOR" = "unknown" ]; then
    FLAVOR="$OS"
fi

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
            echo "    i install <PACKAGE>                   install a package from default git repo"
            echo "    i install <REPO> <PACKAGE>            install a package from git repo"
            echo "    r remove <PACKAGE>                    remove a package"
            echo "    d dependencies <PACKAGE>              dependencies required by package"
            echo "    u upgrade                             upgrade all packages from default git repo"
            echo "    u upgrade <REPO>                      upgrade all packages from git repo"
            echo "    u upgrade <REPO> <PACKAGE>            upgrade a package from git repo"
            echo "    ra repo-add <REPO_NAME> <REPO_URI>    add repo"
            echo "    rr repo-remove <REPO_NAME>            remove repo"
            echo "    reinstall                             reinstal all packages"
            echo "    init                                  initialize mkpm"
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
            _echo "no repo specified" 1>&2
            exit 1
        fi
        if test $# -gt 0; then
            export _PARAM2=$1
            shift
        else
            export _PARAM2=$_PARAM1
            export _PARAM1=default
        fi
    ;;
    r|remove)
        export _COMMAND=remove
        shift
        if test $# -gt 0; then
            export _PARAM1=$1
            shift
        else
            _echo "no package specified" 1>&2
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
            _echo "no package specified" 1>&2
            exit 1
        fi
    ;;
    u|upgrade)
        export _COMMAND=upgrade
        shift
        if test $# -gt 0; then
            export _PARAM1=$1
            shift
        else
            export _PARAM1=default
        fi
        if test $# -gt 0; then
            export _PARAM2=$1
            shift
        fi
    ;;
    ra|repo-add)
        export _COMMAND=repo-add
        shift
        if test $# -gt 0; then
            export _PARAM1=$1
            shift
        else
            _echo "no repo name specified" 1>&2
            exit 1
        fi
        if test $# -gt 0; then
            export _PARAM2=$1
            shift
        else
            _echo "no repo uri specified" 1>&2
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
            _echo "no repo name specified" 1>&2
            exit 1
        fi
    ;;
    init)
        export _COMMAND=init
        shift
    ;;
    reinstall)
        export _COMMAND=reinstall
        shift
    ;;
    *)
        export _COMMAND=run
        export _TARGET="$1"
        shift
    ;;
esac

main "$@"
