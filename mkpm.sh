#!/bin/sh

MKPM_CORE_URL="https://gitlab.com/api/v4/projects/29276259/packages/generic/mkpm/0.3.0/bootstrap.mk"
DEFAULT_REPO="${DEFAULT_REPO:-https://gitlab.com/risserlabs/community/mkpm-stable.git}"
_MKPM_VERSION="1.0.0"

__0="$0"
__ARGS="$@"

alias gmake="$(gmake --version >/dev/null 2>&1 && echo gmake || echo make)"
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
if [ "$PROJECT_ROOT" = "" ] || [ "$PROJECT_ROOT" = "/" ]; then
    export PROJECT_ROOT="$(_project_root)"
fi
if [ "$PROJECT_ROOT" = "/" ]; then
    _error "not an mkpm project" && exit 1
fi
_MKPM_ROOT_NAME=".mkpm"
export MKPM_ROOT="$PROJECT_ROOT/$_MKPM_ROOT_NAME"
export MKPM="$MKPM_ROOT/mkpm"
export MKPM_CONFIG="$PROJECT_ROOT/mkpm.json"
_debug PROJECT_ROOT=\"$PROJECT_ROOT\"
_debug MKPM_CONFIG=\"$MKPM_CONFIG\"
_debug MKPM_ROOT=\"$MKPM_ROOT\"
export _MKPM_BIN="$MKPM/.bin"
export _MKPM_PACKAGES="$MKPM/.pkgs"
export _MKPM_TMP="$MKPM/.tmp"

main() {
    if [ "$_COMMAND" = "install" ]; then
        if [ ! -f "$MKPM/.prepared" ]; then
            _PREPARE_INSTALLED=1
        fi
        _prepare
        _REPO_NAME="$_PARAM1"
        _PACKAGE="$_PARAM2"
        if [ "$_REPO_NAME" = "" ]; then
            if [ "$_INSTALL_REFCOUNT" = "" ] || [ "$_INSTALL_REFCOUNT" = "0" ]; then
                _install
            fi
        else
            _REPO_URI="$(_lookup_repo_uri $_REPO_NAME)"
            _REPO_PATH="$(_lookup_repo_path $_REPO_URI)"
            if [ "$_REPO_URI" = "" ]; then
                _error "repo $_REPO_NAME is not valid"
                exit 1
            fi
            _update_repo "$_REPO_URI" "$_REPO_PATH" "$_REPO_NAME"
            _install "$_REPO_URI" "$_REPO_NAME" "$_PACKAGE"
        fi
    elif [ "$_COMMAND" = "remove" ]; then
        _prepare
        _remove $_PARAM1
    elif [ "$_COMMAND" = "upgrade" ]; then
        _prepare
        _upgrade $_PARAM1 $_PARAM2
    elif [ "$_COMMAND" = "repo-add" ]; then
        _prepare
        _REPO_NAME=$_PARAM1
        _REPO_URI=$_PARAM2
        _repo_add $_REPO_NAME $_REPO_URI
    elif [ "$_COMMAND" = "repo-remove" ]; then
        _prepare
        _repo_remove $_PARAM1
    elif [ "$_COMMAND" = "reset" ]; then
        _prepare
        _reset
    elif [ "$_COMMAND" = "init" ]; then
        if [ "$_COMMAND" = "init" ] && [ -f "$MKPM_CONFIG" ]; then
            _error "mkpm already initialized"
            exit 1
        fi
        _prepare
        _init
    else
        _prepare
        _run "$_TARGET" "$@"
    fi
}


## COMMANDS ##

_run() {
    _TARGET="$1"
    shift
    _ARGS_ENV_NAME="$(echo "$_TARGET" | sed 's|[^A-Za-z0-9_]|_|g' | tr '[:lower:]' '[:upper:]')_ARGS"
    _MAKEFILE="Mkpmfile"
    if [ ! -f "$_MAKEFILE" ]; then
        _MAKEFILE="Makefile"
    fi
    _debug "$_ARGS_ENV_NAME=\"$@\" gmake -f "$_MAKEFILE" $_MAKE_FLAGS \"$_TARGET\""
    _TMP_PIPE_DIR="$(mktemp -d)"
    _TMP_PIPE="$_TMP_PIPE_DIR/stderr"
    mkfifo "$_TMP_PIPE"
    if [ "$MKPM_DEBUG" = "1" ]; then
        cat < "$_TMP_PIPE" >&2 &
        _PIPE_PID=$!
    else
        grep -v 'warning: overriding recipe for target' < "$_TMP_PIPE" | \
            grep -v 'warning: ignoring old recipe for target' >&2 &
        _PIPE_PID=$!
    fi
    eval "$_ARGS_ENV_NAME=\"$@\" gmake -f "$_MAKEFILE" $_MAKE_FLAGS \"$_TARGET\"" 2> "$_TMP_PIPE"
    _CODE="$?"
    wait "$_PIPE_PID"
    rm -rf "$_TMP_PIPE_DIR"
    exit $_CODE
}

_INSTALL_REFCOUNT=0
_install() {
    _validate_mkpm_config
    if [ "$1" = "" ]; then
        for r in $(_list_repos); do
            _REPO_URI="$(_lookup_repo_uri $r)"
            if [ "$_REPO_URI" = "" ]; then
                continue
            fi
            _REPO_PATH=$(_lookup_repo_path $_REPO_URI)
            _update_repo "$_REPO_URI" "$_REPO_PATH" "$r"
            _r=$r
            for p in $(_list_packages "$r"); do
                _install "$_REPO_URI" "$_r" "$p"
            done
        done
        _INSTALL_REFCOUNT=$(expr $_INSTALL_REFCOUNT + 1)
        return
    elif [ "$2" != "" ] && [ "$3" = "" ]; then
        _REPO_URI="$1"
        _REPO_NAME="$2"
        _REPO_PATH=$(_lookup_repo_path $_REPO_URI)
        _update_repo "$_REPO_URI" "$_REPO_PATH" "$_REPO_NAME"
        for p in $(_list_packages "$_REPO_NAME"); do
            _install "$_REPO_URI" "$_REPO_NAME" "$p"
        done
        return
    fi
    _REPO_URI="$1"
    _REPO_NAME="$2"
    _PACKAGE="$3"
    _PACKAGE_NAME="$(echo $_PACKAGE | cut -d'=' -f1)"
    _PACKAGE_VERSION="$(echo $_PACKAGE | gsed 's|^[^=]*||g' | gsed 's|^=||g')"
    _REPO_PATH="$(_lookup_repo_path $_REPO_URI)"
    cd "$_REPO_PATH" || exit 1
    if [ "$_PACKAGE_VERSION" = "" ]; then
        _PACKAGE_VERSION=$(git tag | grep -E "${_PACKAGE_NAME}/" | \
            gsed "s|${_PACKAGE_NAME}/||g" | \
            sort -t "." -k1,1n -k2,2n -k3,3n | tail -n1)
    fi
    if [ "$_PACKAGE_VERSION" = "" ]; then
        _error "package $_PACKAGE_NAME does not exist"
        exit 1
    fi
    if ! git checkout -f "$_PACKAGE_NAME/$_PACKAGE_VERSION" >/dev/null 2>/dev/null; then
        _error "package ${_PACKAGE_NAME}=${_PACKAGE_VERSION} does not exist"
        exit 1
    fi
    git lfs pull --include "$_PACKAGE_NAME/$_PACKAGE_NAME.tar.gz"
    if [ ! -f "$_REPO_PATH/$_PACKAGE_NAME/$_PACKAGE_NAME.tar.gz" ]; then
        _error "package ${_PACKAGE_NAME}=${_PACKAGE_VERSION} does not exist"
        exit 1
    fi
    _remove_package "$_PACKAGE_NAME"
    cat "$MKPM_CONFIG" | \
        jq ".packages.${_REPO_NAME} += { \"${_PACKAGE_NAME}\": \"${_PACKAGE_VERSION}\" }" | \
        _sponge "$MKPM_CONFIG" >/dev/null
    mkdir -p "$_MKPM_PACKAGES/$_PACKAGE_NAME"
    tar -xzf "$_REPO_PATH/$_PACKAGE_NAME/$_PACKAGE_NAME.tar.gz" -C "$_MKPM_PACKAGES/$_PACKAGE_NAME" >/dev/null
    echo 'include $(MKPM)'"/.pkgs/$_PACKAGE_NAME/main.mk" > \
        "$MKPM/$_PACKAGE_NAME"
    echo ".PHONY: $_PACKAGE_NAME-%" > "$MKPM/-$_PACKAGE_NAME"
    echo "$_PACKAGE_NAME-%:" >> "$MKPM/-$_PACKAGE_NAME"
    echo '	@$(MAKE) -s -f $(MKPM)/.pkgs/'"$_PACKAGE_NAME/main.mk "'$(subst '"$_PACKAGE_NAME-,,$"'@)' >> \
        "$MKPM/-$_PACKAGE_NAME"
    _create_cache
    cd "$_CWD"
    _echo "installed ${_PACKAGE_NAME}=${_PACKAGE_VERSION}"
}

_remove() {
    _PACKAGE_NAME="$1"
    _remove_package "$_PACKAGE_NAME"
    _echo "removed package $_PACKAGE_NAME"
}

_upgrade() {
    _REPO_NAME="$1"
    _PACKAGE_NAME="$2"
    _REPO_URI=$(_lookup_repo_uri $_REPO_NAME)
    _REPO_PATH=$(_lookup_repo_path $_REPO_URI)
    if [ "$_REPO_URI" = "" ]; then
        _error "repo name $_REPO_NAME is not valid"
        exit 1
    fi
    if _is_repo_uri "$_REPO_NAME"; then
        _error "repo name $_REPO_NAME is not valid"
        exit 1
    fi
    _update_repo "$_REPO_URI" "$_REPO_PATH" "$_REPO_NAME"
    if [ "$_PACKAGE_NAME" = "" ]; then
        for p in $(_list_packages "$_REPO_NAME"); do
            echo _install "$_REPO_URI" "$_REPO_NAME" "$p"
            _install "$_REPO_URI" "$_REPO_NAME" "$p"
        done
    else
        _install "$_REPO_URI" "$_REPO_NAME" "$_PACKAGE_NAME"
    fi
}

_reset() {
    rm -rf "$_MKPM_ROOT" 2>/dev/null
    _ensure_mkpm_sh
    _prepare
    if [ "$_INSTALL_REFCOUNT" = "" ] || [ "$_INSTALL_REFCOUNT" = "0" ]; then
        _install
    fi
}

_repo_add() {
    _REPO_NAME="$1"
    _REPO_URI="$2"
    _REPO_PATH="$(_lookup_repo_path $_REPO_URI)"
    if [ "$(_lookup_repo_uri $_REPO_NAME)" != "" ]; then
        _error "repo $_REPO_NAME already exists"
        exit 1
    fi
    if ! _is_repo_uri "$_REPO_URI"; then
        _error "invalid repo uri $_REPO_URI"
        exit 1
    fi
    cat "$MKPM_CONFIG" | \
        jq ".repos += { \"${_REPO_NAME}\": \"${_REPO_URI}\" }" | \
        _sponge "$MKPM_CONFIG" >/dev/null
    cat "$MKPM_CONFIG" | \
        jq ".packages.${_REPO_NAME} += {}" | \
        _sponge "$MKPM_CONFIG" >/dev/null
    _echo "added repo $_REPO_NAME"
    _install "$_REPO_URI" "$_REPO_NAME"
}

_repo_remove() {
    _REPO_NAME=$1
    if [ "$(_lookup_repo_uri $_REPO_NAME)" = "" ]; then
        _error "repo $_REPO_NAME does not exist"
        exit 1
    fi
    for p in $(_list_packages "$_REPO_NAME"); do
        _remove_package "$p"
    done
    cat "$MKPM_CONFIG" | \
        jq "del(.repos.${_REPO_NAME})" | \
        _sponge "$MKPM_CONFIG" >/dev/null
    cat "$MKPM_CONFIG" | \
        jq "del(.packages.${_REPO_NAME})" | \
        _sponge "$MKPM_CONFIG" >/dev/null
    _echo "removed repo $_REPO_NAME"
}

_init() {
    if [ ! -f "$_CWD/.git/HEAD" ]; then
        _error "init must be run from the root of a git project"
        exit 1
    fi
    rm -rf "$MKPM_ROOT"
    _validate_mkpm_config
    if [ ! -f "$_CWD/Makefile" ] && [ ! -f "$_CWD/Mkpmfile" ]; then
        echo "generate ${LIGHT_GREEN}Mkpmfile${NOCOLOR} [${GREEN}Y${NOCOLOR}|${RED}n${NOCOLOR}]: "
        read _RES
        if [ "$(echo "$_RES" | cut -c 1 | tr '[:lower:]' '[:upper:]')" != "N" ]; then
            cat <<EOF > "$_CWD/Mkpmfile"
include \$(MKPM)/mkpm

.PHONY: hello
hello:
	@\$(ECHO) Hello, world!
EOF
            _echo generated ${LIGHT_GREEN}Mkpmfile${NOCOLOR}
        fi
    fi
    printf "add cache to git [${GREEN}Y${NOCOLOR}|${RED}n${NOCOLOR}]: "
    read _RES
    if [ "$(echo "$_RES" | cut -c 1 | tr '[:lower:]' '[:upper:]')" != "N" ]; then
        if [ ! -f "${PROJECT_ROOT}/.gitattributes" ] || ! (cat "${PROJECT_ROOT}/.gitattributes" | grep -qE '^\.mkpm/\.cache\.tar\.gz filter=lfs diff=lfs merge=lfs -text'); then
            printf "store cache on git with lfs [${GREEN}Y${NOCOLOR}|${RED}n${NOCOLOR}]: "
            read _RES
            if [ "$(echo "$_RES" | cut -c 1 | tr '[:lower:]' '[:upper:]')" != "N" ]; then
                git lfs track '.mkpm/cache.tar.gz' >/dev/null
            fi
        fi
    else
        _GITIGNORE_CACHE=1
    fi
    if [ ! -f "${PROJECT_ROOT}/.gitignore" ] || ! (cat "${PROJECT_ROOT}/.gitignore" | grep -qE '^\.mkpm/mkpm'); then
        printf "add ${LIGHT_GREEN}.gitignore${NOCOLOR} rules [${GREEN}Y${NOCOLOR}|${RED}n${NOCOLOR}]: "
        read _RES
        if [ "$(echo "$_RES" | cut -c 1 | tr '[:lower:]' '[:upper:]')" != "N" ]; then
            cat <<EOF >> "${PROJECT_ROOT}/.gitignore"

# mkpm
.mkpm/mkpm
EOF
            if [ "$_GITIGNORE_CACHE" = "1" ] && ! (cat ${PROJECT_ROOT}/.gitignore | grep -qE '^\.mkpm/cache\.tar\.gz'); then
                echo ".mkpm/cache.tar.gz" >> "${PROJECT_ROOT}/.gitignore"
            fi
            sed -i ':a;N;$!ba;s/\n\n\+/\n\n/g'i "${PROJECT_ROOT}/.gitignore"
            _echo "added ${LIGHT_GREEN}.gitignore${NOCOLOR} rules"
        fi
    fi
}


## PREPARE ##

_prepare() {
    if [ "$_MKPM_RESET_CACHE" = "1" ] || \
        ([ -f "$PROJECT_ROOT/mkpm.mk" ] && [ "$PROJECT_ROOT/mkpm.mk" -nt "$MKPM/mkpm" ]); then
        _reset_cache
        exit $?
    fi
    if [ ! -f "$MKPM/mkpm" ]; then
        _require_system_binary awk
        _require_system_binary git
        _require_system_binary git-lfs
        _require_system_binary grep
        _require_system_binary jq
        _require_system_binary tar
        if [ "$PLATFORM" = "darwin" ]; then
            _require_system_binary gmake --version
        else
            _require_system_binary make --version
        fi
        if [ "$PLATFORM" = "darwin" ]; then
            _require_system_binary gsed --version
        else
            _require_system_binary sed --version
        fi
        _ensure_dirs
        _validate_mkpm_config
        if [ ! -d "$_MKPM_PACKAGES" ]; then
            if [ -f "$_MKPM_ROOT/cache.tar.gz" ]; then
                _restore_from_cache
            else
                _install
            fi
        fi
        _ensure_mkpm_mk
    fi
}

_lookup_system_package_name() {
    _BINARY="$1"
    case "$_BINARY" in
        gmake)
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
        _error $_SYSTEM_BINARY is not installed on your system
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
    if [ ! -d "$MKPM/.bin" ]; then
        mkdir -p "$MKPM/.bin"
    fi
    if [ ! -d "$MKPM/.pkgs" ]; then
        mkdir -p "$MKPM/.pkgs"
    fi
    if [ ! -d "$MKPM/.tmp" ]; then
        mkdir -p "$MKPM/.tmp"
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

_ensure_mkpm_sh() {
    if [ -f "$PROJECT_ROOT/mkpm.sh" ]; then
        mkdir -p "$_MKPM_BIN"
        if [ ! -f "$_MKPM_BIN/mkpm" ]; then
            if [ -f "$_MKPM_ROOT/cache.tar.gz" ]; then
                _restore_from_cache
            else
                cp "$PROJECT_ROOT/mkpm.sh" "$_MKPM_BIN/mkpm"
                _debug downloaded mkpm.sh
            fi
        fi
        chmod +x "$_MKPM_BIN/mkpm"
    elif [ ! -f "$_MKPM_BIN/mkpm" ]; then
        mkdir -p "$_MKPM_BIN"
        if [ -f "$_MKPM_ROOT/cache.tar.gz" ]; then
            _restore_from_cache
        else
            download "$_MKPM_BIN/mkpm" "$MKPM_BINARY" >/dev/null
            _debug downloaded mkpm.sh
        fi
        chmod +x "$_MKPM_BIN/mkpm"
    fi
}


## CACHE ##

_create_cache() {
    cd "$MKPM"
    touch "$_MKPM_ROOT/cache.tar.gz"
    tar --format=gnu --sort=name --mtime='1970-01-01 00:00:00 UTC' -czf "$_MKPM_ROOT/cache.tar.gz" \
        --exclude '.tmp' \
        .
    cd "$_CWD"
    _debug created cache
}

_restore_from_cache() {
    if [ -f "$_MKPM_ROOT/cache.tar.gz" ]; then
        rm -rf "$MKPM"
        mkdir -p "$MKPM"
        cd "$MKPM"
        tar -xzf "$_MKPM_ROOT/cache.tar.gz" >/dev/null
        cd "$_CWD"
        _debug restored cache
    fi
}

_reset_cache() {
    rm -rf \
        "$_MKPM_ROOT/cache.tar.gz" \
        "$MKPM/.prepared" \
        "$MKPM/mkpm" 2>/dev/null
    unset _MKPM_RESET_CACHE
    _debug reset cache
    exec "$__0" $__ARGS
}

_is_repo_uri() {
    echo "$1" | grep -E '^(\w+://.+)|(git@.+:.+)$' >/dev/null 2>&1
}


## REPOS ##

_lookup_default_repo() {
    for r in $(_list_repos); do
        echo "$r"
        return
    done
}

_list_repos() {
    cat "$MKPM_CONFIG" | jq -r '(.repos | keys)[]'
}

_lookup_repo_uri() {
    _REPO="$1"
    cat "$MKPM_CONFIG" | jq -r ".repos.$_REPO // \"\""
}

_lookup_repo_path() {
    echo "$_REPOS_PATH/$(echo "$1" | md5sum | cut -d ' ' -f1)"
}

_update_repo() {
    _REPO_URI="$1"
    _REPO_PATH="$2"
    _REPO_NAME="$3"
    _echo "updating repo $_REPO_NAME $_REPO_URI"
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
    for p in $(cat "$MKPM_CONFIG" | jq -r "(.packages.${_REPO} | keys)[]"); do
        echo "$p"
    done
}

_remove_package() {
    _PACKAGE_NAME="$1"
    rm -rf \
        "$MKPM/$_PACKAGE_NAME" \
        "$MKPM/-$_PACKAGE_NAME" \
        "$_MKPM_PACKAGES/$_PACKAGE_NAME" 2>/dev/null
    for r in $(_list_repos); do
        cat "$MKPM_CONFIG" | \
            jq "del(.packages.${r}.${_PACKAGE_NAME})" | \
            _sponge "$MKPM_CONFIG" >/dev/null
    done
}


## CONFIG ##

_validate_mkpm_config() {
    if [ ! -f "$MKPM_CONFIG" ] || [ "$(cat "$MKPM_CONFIG" | jq -r '. | type')" != "object" ]; then
        echo '{}' > "$MKPM_CONFIG"
    fi
    cat "$MKPM_CONFIG" | \
        jq ".packages += {}" | \
        _sponge "$MKPM_CONFIG" >/dev/null
    cat "$MKPM_CONFIG" | \
        jq ".repos += {}" | \
        _sponge "$MKPM_CONFIG" >/dev/null
    if [ "$(cat "$MKPM_CONFIG" | jq '.repos | length')" = "0" ]; then
        cat "$MKPM_CONFIG" | \
            jq ".repos += {\"default\": \"${DEFAULT_REPO}\"}" | \
            _sponge "$MKPM_CONFIG" >/dev/null
    fi
    for r in $(_list_repos); do
        cat "$MKPM_CONFIG" | \
            jq ".packages.${r} += {}" | \
            _sponge "$MKPM_CONFIG" >/dev/null
    done
    _ERR=
    for r in $(echo "$(_list_repos) $(cat "$MKPM_CONFIG" | jq -r '(.packages | keys)[]')" | tr ' ' '\n' | \
        sort | uniq -c | grep -E "^\s+1\s" | sed 's|\s\+[0-9]\+\s||g'); do
        _PACKAGES="$(_list_packages "$r")"
        if [ "$_PACKAGES" = "" ]; then
            cat "$MKPM_CONFIG" | \
                jq "del(.packages.${r})" | \
                _sponge "$MKPM_CONFIG" >/dev/null
        else
            for p in $_PACKAGES; do
                _error "package ${LIGHT_CYAN}$p${NOCOLOR} missing ${LIGHT_CYAN}$r${NOCOLOR} repo"
                _ERR=1
            done
        fi
    done
    for p in $(cat "$MKPM_CONFIG" | jq -r '.packages[] | keys[]' | sort | uniq -c | grep -vE "^\s+1\s" | sed 's|\s\+[0-9]\+\s||g'); do
        _error "package ${LIGHT_CYAN}$p${NOCOLOR} exists more than once"
        _ERR=1
    done
    if [ "$_ERR" = "1" ]; then
        exit 1
    fi
}


## UTIL ##

_echo() {
    [ "$_SILENT" = "1" ] && true || echo "${LIGHT_CYAN}MKPM [I]:${NOCOLOR} $@"
}

_error() {
    echo "${RED}MKPM [E]:${NOCOLOR} $@" 1>&2
}

_sponge() {
    if which sponge >/dev/null 2>&1; then
        sponge "$@"
    else
        if [ -p /dev/stdin ]; then
            _TMP_FILE=$(mktemp)
            cat > "$_TMP_FILE"
            cat "$_TMP_FILE" > "$1"
            rm -f "$_TMP_FILE"
        fi
        cat "$1"
    fi
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
            echo
            echo "mkpm [options] <TARGET> [...ARGS]"
            echo
            echo "options:"
            echo "    -h, --help                            show brief help"
            echo "    -s, --silent                          silent output"
            echo "    -d, --debug                           debug output"
            echo
            echo "commands:"
            echo "    i install                             install all packages"
            echo "    i install <PACKAGE>                   install a package from default git repo"
            echo "    i install <REPO> <PACKAGE>            install a package from git repo"
            echo "    r remove <PACKAGE>                    remove a package"
            echo "    u upgrade                             upgrade all packages from default git repo"
            echo "    u upgrade <REPO>                      upgrade all packages from git repo"
            echo "    u upgrade <REPO> <PACKAGE>            upgrade a package from git repo"
            echo "    ra repo-add <REPO_NAME> <REPO_URI>    add repo"
            echo "    rr repo-remove <REPO_NAME>            remove repo"
            echo "    reset                                 reset mkpm"
            echo "    init                                  initialize mkpm"
            echo "    v version                             mkpm version"
            exit
        ;;
        -s|--silent)
            if [ "$MKPM_DEBUG" != "1" ]; then
                _SILENT=1
            fi
            _MAKE_FLAGS="-s"
            shift
        ;;
        -d|--debug)
            export MKPM_DEBUG=1
            unset _SILENT
            shift
        ;;
        -*)
            _MAKE_FLAGS=
            while [ "$1" != "${1#-}" ]; do
                _MAKE_FLAGS="${_MAKE_FLAGS} $1"
                shift
            done
        ;;
        *)
            break
        ;;
    esac
done

case "$1" in
    i|install)
        export _COMMAND=install
        shift
        if test $# -gt 0; then
            export _PARAM1=$1
            shift
            if test $# -gt 0; then
                export _PARAM2=$1
                shift
            else
                export _PARAM2=$_PARAM1
                export _PARAM1="$(_lookup_default_repo)"
            fi
        fi
    ;;
    r|remove)
        export _COMMAND=remove
        shift
        if test $# -gt 0; then
            export _PARAM1=$1
            shift
        else
            _error "no package specified"
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
            export _PARAM1="$(_lookup_default_repo)"
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
            _error "no repo name specified"
            exit 1
        fi
        if test $# -gt 0; then
            export _PARAM2=$1
            shift
        else
            _error "no repo uri specified"
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
            _error "no repo name specified"
            exit 1
        fi
    ;;
    init)
        export _COMMAND=init
        shift
    ;;
    reset)
        export _COMMAND=reset
        shift
    ;;
    v|version)
        _echo "$_MKPM_VERSION"
        exit
    ;;
    *)
        export _COMMAND=run
        export _TARGET="$1"
        shift
    ;;
esac

main "$@"
