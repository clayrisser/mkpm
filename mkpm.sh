#!/bin/sh
set -e

# File: /mkpm.sh
# Project: mkpm
# File Created: 28-11-2023 13:42:39
# Author: Clay Risser
# BitSpur (c) Copyright 2021 - 2024
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

MKPM_VERSION="<% MKPM_VERSION %>"
DEFAULT_REPO="${DEFAULT_REPO:-https://gitlab.com/bitspur/mkpm/packages.git}"
MKPM_MK_URL="${MKPM_MK_URL:-https://gitlab.com/api/v4/projects/48207162/packages/generic/mkpm/${MKPM_VERSION}/mkpm.mk}"
MKPM_SH_URL="${MKPM_SH_URL:-https://gitlab.com/api/v4/projects/48207162/packages/generic/mkpm/${MKPM_VERSION}/mkpm.sh}"
MKPM_PROXY_SH_URL="${MKPM_PROXY_SH_URL:-https://gitlab.com/api/v4/projects/48207162/packages/generic/mkpm/${MKPM_VERSION}/mkpm-proxy.sh}"
if [ "$REQUIRE_ASDF" = "" ]; then
    REQUIRE_ASDF="$([ "$CI" = "" ] && echo 1 || true)"
fi

if [ "$VSCODE_CLI" = "1" ] && [ "$VSCODE_PID" != "" ] && [ "$VSCODE_CWD" != "" ]; then
    exit 0
fi

__0="$0"
__ARGS="$@"

alias which="command -v"
alias download="$(which curl >/dev/null 2>&1 && echo curl -Lo || echo wget -O)"
alias echo="$([ "$(echo -e)" = "-e" ] && echo "echo" || echo "echo -e")"
alias awk="$(which gawk >/dev/null 2>&1 && echo gawk || echo awk)"
alias sed="$(which gsed >/dev/null 2>&1 && echo gsed || echo sed)"
alias tar="$(which gtar >/dev/null 2>&1 && echo gtar || echo tar)"

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
_SCRIPT_NAME="$(basename "$0")"
_SCRIPT_PATH="$(dirname "$(readlink -f "$0")")/$_SCRIPT_NAME"
_STATE_PATH="${XDG_STATE_HOME:-$HOME/.local/state}/mkpm"
_REPOS_PATH="$_STATE_PATH/repos"
_REPOS_LIST_PATH="$_STATE_PATH/repos.list"
_SUPPORTS_COLORS=$( (which tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]) && echo 1 || true)
export GIT_LFS_SKIP_SMUDGE=1
export LC_ALL=C

if [ "$_SUPPORTS_COLORS" = "1" ]; then
    export C_END='\033[0m'
    export C_WHITE='\033[1;37m'
    export C_BLACK='\033[0;30m'
    export C_RED='\033[31m'
    export C_GREEN='\033[32m'
    export C_YELLOW='\033[33m'
    export C_BLUE='\033[34m'
    export C_PURPLE='\033[35m'
    export C_CYAN='\033[36m'
    export C_LIGHT_GRAY='\033[37m'
    export C_DARK_GRAY='\033[1;30m'
    export C_LIGHT_RED='\033[1;31m'
    export C_LIGHT_GREEN='\033[1;32m'
    export C_LIGHT_YELLOW='\033[1;33m'
    export C_LIGHT_BLUE='\033[1;34m'
    export C_LIGHT_PURPLE='\033[1;35m'
    export C_LIGHT_CYAN='\033[1;36m'
fi

_is_mkpm_proxy_required() {
    while test $# -gt 0; do
        case "$1" in
        -h | --help)
            return 1
            ;;
        -*)
            shift
            ;;
        v | version | init)
            return 1
            ;;
        *)
            break
            ;;
        esac
    done
    [ "$1" = "" ] && return 1 || true
}
_MKPM_PROXY_REQUIRED=$(_is_mkpm_proxy_required "$@" && echo 1 || true)

_debug() { [ "$MKPM_DEBUG" = "1" ] && echo "${C_YELLOW}MKPM [D]:${C_END} $@" || true; }

_echo() { [ "$_SILENT" = "1" ] && true || echo "${C_LIGHT_CYAN}MKPM [I]:${C_END} $@"; }

_error() { echo "${C_RED}MKPM [E]:${C_END} $@" 1>&2; }

_project_root() {
    _ROOT="$1"
    if [ "$_ROOT" = "" ]; then
        _ROOT="$(pwd)"
    fi
    _ROOT="$(readlink -f "$_ROOT")"
    if [ -f "$_ROOT/mkpm.json" ]; then
        echo "$_ROOT"
        return
    fi
    _PARENT="$(dirname "$_ROOT")"
    if ([ "$_PARENT" = "" ] || [ "$_PARENT" = "/" ]); then
        echo "/"
        return
    fi
    echo "$(_project_root "$_PARENT")"
    return
}
if [ "$PROJECT_ROOT" = "" ] || [ "$PROJECT_ROOT" = "/" ]; then
    export PROJECT_ROOT="$(_project_root)"
fi
if [ "$PROJECT_ROOT" = "/" ]; then
    if [ "$_MKPM_PROXY_REQUIRED" = "1" ]; then
        _error "not an mkpm project" && exit 1
    else
        PROJECT_ROOT="$_CWD"
        _IS_MKPM_COMMAND=1
    fi
fi
_rc_config() {
    case "${SHELL##*/}" in
    zsh)
        RC_CONFIG="${ZDOTDIR:-$HOME}/.zshrc"
        ;;
    bash)
        if [ "$PLATFORM" = "darwin" ]; then
            RC_CONFIG="${HOME}/.bash_profile"
        else
            RC_CONFIG="${HOME}/.bashrc"
        fi
        ;;
    fish)
        RC_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish"
        ;;
    *)
        RC_CONFIG="${HOME}/.profile"
        ;;
    esac
    if [ ! -f "$RC_CONFIG" ]; then
        for r in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile"; do
            if [ -f "$r" ]; then
                RC_CONFIG="$r"
                break
            fi
        done
    fi
    if [ -z "$RC_CONFIG" ]; then
        RC_CONFIG="$HOME/.bashrc"
    fi
    echo "$RC_CONFIG"
}
export RC_CONFIG="$(_rc_config)"
_MKPM_ROOT_NAME=".mkpm"
export MKPM_ROOT="$PROJECT_ROOT/$_MKPM_ROOT_NAME"
export MKPM="$MKPM_ROOT/mkpm"
export MKPM_CONFIG="$PROJECT_ROOT/mkpm.json"
export MKPM_BIN="$MKPM/.bin"
export MKPM_TMP="$MKPM/.tmp"
_debug PROJECT_ROOT=\"$PROJECT_ROOT\"
_debug MKPM_CONFIG=\"$MKPM_CONFIG\"
_debug MKPM_ROOT=\"$MKPM_ROOT\"
_debug MKPM_BIN=\"$MKPM_BIN\"
_debug MKPM_TMP=\"$MKPM_TMP\"
export _MKPM_PACKAGES="$MKPM/.pkgs"

_MKPM_TEST=$([ -f "$PROJECT_ROOT/mkpm.sh" ] && [ -f "$PROJECT_ROOT/mkpm.mk" ] && [ -f "$PROJECT_ROOT/mkpm-proxy.sh" ] && echo 1 || true)

main() {
    if [ "$_COMMAND" = "install" ]; then
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
        _reset
    elif [ "$_COMMAND" = "init" ]; then
        if [ "$_COMMAND" = "init" ] && [ -f "$MKPM_CONFIG" ]; then
            _error "mkpm already initialized"
            exit 1
        fi
        if [ ! -f "$_CWD/.git/HEAD" ]; then
            _error "init must be run from the root of a git project"
            exit 1
        fi
        _prepare
        _init
    elif [ "$_COMMAND" = "pack" ]; then
        _prepare
        _pack
    elif [ "$_COMMAND" = "publish" ]; then
        _prepare
        _pack
        _publish
    else
        _prepare
        _run "$_TARGET" "$@"
    fi
}

_run() {
    if [ "$1" != "" ]; then
        _TARGET="\"$1\""
    fi
    shift
    _MAKE="$(which remake >/dev/null 2>&1 && echo remake ||
        (which gmake >/dev/null 2>&1 && echo gmake || echo make))"
    _ARGS_ENV_NAME="$(echo "$_TARGET" | sed 's|[^A-Za-z0-9_]|_|g' | tr '[:lower:]' '[:upper:]')_ARGS"
    _MAKEFILE="Mkpmfile"
    if [ ! -f "$_MAKEFILE" ]; then
        _MAKEFILE="Makefile"
    fi
    _debug "$_ARGS_ENV_NAME=\"$@\" $_MAKE -s -C "$PROJECT_ROOT" -f "$_MAKEFILE" $_MAKE_FLAGS $_TARGET"
    eval "$_ARGS_ENV_NAME=\"$@\" $_MAKE $([ "$MKPM_DEBUG" = "1" ] || echo '-s') \
        -C "$PROJECT_ROOT" -f "$_MAKEFILE" $_MAKE_FLAGS $_TARGET"
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
                _v="$(cat mkpm.json | jq -r ".packages.$_r.$p")"
                _install "$_REPO_URI" "$_r" "$p=$_v"
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
    _PACKAGE_VERSION="$(echo $_PACKAGE | sed 's|^[^=]*||g' | sed 's|^=||g')"
    _REPO_PATH="$(_lookup_repo_path $_REPO_URI)"
    cd "$_REPO_PATH" || exit 1
    if [ "$_PACKAGE_VERSION" = "" ]; then
        _PACKAGE_VERSION=$(git tag | grep -E "${_PACKAGE_NAME}/" |
            sed "s|${_PACKAGE_NAME}/||g" |
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
    cat "$MKPM_CONFIG" 2>/dev/null |
        jq ".packages.${_REPO_NAME} += { \"${_PACKAGE_NAME}\": \"${_PACKAGE_VERSION}\" }" |
        _sponge "$MKPM_CONFIG" >/dev/null
    mkdir -p "$_MKPM_PACKAGES/$_PACKAGE_NAME"
    tar -xzf "$_REPO_PATH/$_PACKAGE_NAME/$_PACKAGE_NAME.tar.gz" -C "$_MKPM_PACKAGES/$_PACKAGE_NAME" >/dev/null
    echo 'include $(MKPM)'"/.pkgs/$_PACKAGE_NAME/main.mk" > \
        "$MKPM/$_PACKAGE_NAME"
    echo ".PHONY: $_PACKAGE_NAME-%" >"$MKPM/-$_PACKAGE_NAME"
    echo "$_PACKAGE_NAME-%:" >>"$MKPM/-$_PACKAGE_NAME"
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
            _install "$_REPO_URI" "$_REPO_NAME" "$p"
        done
    else
        _install "$_REPO_URI" "$_REPO_NAME" "$_PACKAGE_NAME"
    fi
}

_reset() {
    rm -rf "$MKPM_ROOT" "${PROJECT_ROOT}/mkpm" 2>/dev/null
    download "${PROJECT_ROOT}/mkpm" "$MKPM_PROXY_SH_URL" >/dev/null
    chmod +x "${PROJECT_ROOT}/mkpm"
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
    cat "$MKPM_CONFIG" 2>/dev/null |
        jq ".repos += { \"${_REPO_NAME}\": \"${_REPO_URI}\" }" |
        _sponge "$MKPM_CONFIG" >/dev/null
    cat "$MKPM_CONFIG" 2>/dev/null |
        jq ".packages.${_REPO_NAME} += {}" |
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
    cat "$MKPM_CONFIG" 2>/dev/null |
        jq "del(.repos.${_REPO_NAME})" |
        _sponge "$MKPM_CONFIG" >/dev/null
    cat "$MKPM_CONFIG" 2>/dev/null |
        jq "del(.packages.${_REPO_NAME})" |
        _sponge "$MKPM_CONFIG" >/dev/null
    _echo "removed repo $_REPO_NAME"
}

_init() {
    _SED="$(which gsed >/dev/null 2>&1 && echo gsed || echo sed)"
    rm -rf "$MKPM_ROOT"
    printf "add vscode settings [${C_GREEN}Y${C_END}|${C_RED}n${C_END}]: "
    read _RES
    if [ "$(echo "$_RES" | cut -c 1 | tr '[:lower:]' '[:upper:]')" != "N" ]; then
        mkdir -p "${PROJECT_ROOT}/.vscode"
        if [ ! -f "${PROJECT_ROOT}/.vscode/settings.json" ] || [ "$(cat "${PROJECT_ROOT}/.vscode/settings.json" | jq -r '. | type')" != "object" ]; then
            echo '{}' >"${PROJECT_ROOT}/.vscode/settings.json"
        fi
        cat "${PROJECT_ROOT}/.vscode/settings.json" | jq '.["files.associations"] += { "Mkpmfile": "makefile" }' |
            _sponge "${PROJECT_ROOT}/.vscode/settings.json" >/dev/null
        _echo "added vscode settings"
    fi
    printf "add mkpm binary [${C_GREEN}Y${C_END}|${C_RED}n${C_END}]: "
    read _RES
    if [ "$(echo "$_RES" | cut -c 1 | tr '[:lower:]' '[:upper:]')" != "N" ]; then
        download "${PROJECT_ROOT}/mkpm" "$MKPM_PROXY_SH_URL" >/dev/null
        chmod +x "${PROJECT_ROOT}/mkpm"
        _echo added mkpm binary
    fi
    if [ ! -f "$_CWD/Makefile" ] && [ ! -f "$_CWD/Mkpmfile" ]; then
        printf "generate ${C_LIGHT_GREEN}Mkpmfile${C_END} [${C_GREEN}Y${C_END}|${C_RED}n${C_END}]: "
        read _RES
        if [ "$(echo "$_RES" | cut -c 1 | tr '[:lower:]' '[:upper:]')" != "N" ]; then
            cat <<EOF >"$_CWD/Mkpmfile"
include \$(MKPM)/mkpm

.PHONY: hello
hello:
	@\$(ECHO) Hello, world!
EOF
            _echo generated ${C_LIGHT_GREEN}Mkpmfile${C_END}
        fi
        printf "generate ${C_LIGHT_GREEN}Makefile${C_END} [${C_GREEN}Y${C_END}|${C_RED}n${C_END}]: "
        read _RES
        if [ "$(echo "$_RES" | cut -c 1 | tr '[:lower:]' '[:upper:]')" != "N" ]; then
            cat <<EOF >"$_CWD/Makefile"
.ONESHELL:
.POSIX:
.SILENT:
.DEFAULT_GOAL := default
MKPM := $([ -f "${PROJECT_ROOT}/mkpm" ] && echo ./mkpm || echo mkpm)
.PHONY: default
default:
	@\$(MKPM) \$(ARGS)
.PHONY: %
%:
	@\$(MKPM) "\$@" \$(ARGS)
EOF
            _echo generated ${C_LIGHT_GREEN}Makefile${C_END}
        fi
    fi
    printf "store mkpm cache on git [${C_GREEN}Y${C_END}|${C_RED}n${C_END}]: "
    read _RES
    if [ "$(echo "$_RES" | cut -c 1 | tr '[:lower:]' '[:upper:]')" != "N" ]; then
        if [ ! -f "${PROJECT_ROOT}/.gitattributes" ] || ! (cat "${PROJECT_ROOT}/.gitattributes" | grep -qE '^\.mkpm/cache\.tar\.gz filter=lfs diff=lfs merge=lfs -text'); then
            printf "use git lfs when storing mkpm cache [${C_GREEN}Y${C_END}|${C_RED}n${C_END}]: "
            read _RES
            if [ "$(echo "$_RES" | cut -c 1 | tr '[:lower:]' '[:upper:]')" != "N" ]; then
                git lfs track '.mkpm/cache.tar.gz' >/dev/null
            fi
        fi
        if cat "${PROJECT_ROOT}/.gitattributes" | grep -qE '^\.mkpm/cache\.tar\.gz filter=lfs diff=lfs merge=lfs -text'; then
            _echo storing mkpm cache on git using lfs
        else
            _echo storing mkpm cache on git
        fi
    else
        _GITIGNORE_CACHE=1
    fi
    if [ ! -f "${PROJECT_ROOT}/.editorconfig" ] ||
        ! (cat "${PROJECT_ROOT}/.editorconfig" | grep -qE '^\[Mkpmfile\]') ||
        ! (cat "${PROJECT_ROOT}/.editorconfig" | grep -qE '^\[{M,m}akefile{,\.\*}\]') ||
        ! (cat "${PROJECT_ROOT}/.editorconfig" | grep -qE '^\[\*.mk\]'); then
        printf "add ${C_LIGHT_GREEN}.editorconfig${C_END} rules [${C_GREEN}Y${C_END}|${C_RED}n${C_END}]: "
        read _RES
        if [ "$(echo "$_RES" | cut -c 1 | tr '[:lower:]' '[:upper:]')" != "N" ]; then
            echo >>"${PROJECT_ROOT}/.editorconfig"
            if ! (cat "${PROJECT_ROOT}/.editorconfig" | grep -qE '^\[Mkpmfile\]'); then
                cat <<EOF >>"${PROJECT_ROOT}/.editorconfig"
[Mkpmfile]
charset = utf-8
indent_size = 4
indent_style = tab
EOF
            fi
            if ! (cat "${PROJECT_ROOT}/.editorconfig" | grep -qE '^\[{M,m}akefile{,\.\*}\]'); then
                cat <<EOF >>"${PROJECT_ROOT}/.editorconfig"
[{M,m}akefile{,.*}]
charset = utf-8
indent_size = 4
indent_style = tab
EOF
            fi
            if ! (cat "${PROJECT_ROOT}/.editorconfig" | grep -qE '^\[\*.mk\]'); then
                cat <<EOF >>"${PROJECT_ROOT}/.editorconfig"
[*.mk]
charset = utf-8
indent_size = 4
indent_style = tab
EOF
            fi
            $_SED -i ':a;N;$!ba;s/\n\n\+/\n\n/g'i "${PROJECT_ROOT}/.editorconfig"
            $_SED -i '1{/^$/d;}' "${PROJECT_ROOT}/.editorconfig"
        fi
    fi
    if [ ! -f "${PROJECT_ROOT}/.gitignore" ] || ! (cat "${PROJECT_ROOT}/.gitignore" | grep -qE '^\.mkpm/mkpm'); then
        printf "add ${C_LIGHT_GREEN}.gitignore${C_END} rules [${C_GREEN}Y${C_END}|${C_RED}n${C_END}]: "
        read _RES
        if [ "$(echo "$_RES" | cut -c 1 | tr '[:lower:]' '[:upper:]')" != "N" ]; then
            cat <<EOF >>"${PROJECT_ROOT}/.gitignore"

# mkpm
.mkpm/mkpm
EOF
            if [ "$_GITIGNORE_CACHE" = "1" ] && ! (cat ${PROJECT_ROOT}/.gitignore | grep -qE '^\.mkpm/cache\.tar\.gz'); then
                echo ".mkpm/cache.tar.gz" >>"${PROJECT_ROOT}/.gitignore"
            fi
            $_SED -i ':a;N;$!ba;s/\n\n\+/\n\n/g'i "${PROJECT_ROOT}/.gitignore"
            $_SED -i '1{/^$/d;}' "${PROJECT_ROOT}/.gitignore"
            _echo "added ${C_LIGHT_GREEN}.gitignore${C_END} rules"
        fi
    fi
    _validate_mkpm_config
    _reset
    _echo "initialized mkpm project"
}

_require_brew() {
    if ! which brew >/dev/null 2>&1; then
        eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null)" >/dev/null 2>&1
        if ! which brew >/dev/null 2>&1; then
            _error brew is not installed on your system
            printf "you can install brew on $FLAVOR with the following command

    ${C_GREEN}/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"${C_END}
    ${C_GREEN}(echo; echo 'eval \"\$(/opt/homebrew/bin/brew shellenv)\"') >> $HOME/.zprofile${C_END}
    ${C_GREEN}eval \"\$(/opt/homebrew/bin/brew shellenv)\"${C_END}

install for me [${C_GREEN}Y${C_END}|${C_RED}n${C_END}]: "
            read _RES
            if [ "$(echo "$_RES" | cut -c 1 | tr '[:lower:]' '[:upper:]')" != "N" ]; then
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                (
                    echo
                    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"'
                ) >>$HOME/.zprofile
                eval "$(/opt/homebrew/bin/brew shellenv)"
            else
                exit 1
            fi
        fi
    fi
}

_require_asdf() {
    if ! which asdf >/dev/null 2>&1; then
        if [ "$PLATFORM" = "darwin" ]; then
            export ASDF_DIR="$(brew --prefix asdf)/libexec"
        else
            export ASDF_DIR="$HOME/.asdf"
        fi
        if [ -f "$ASDF_DIR/asdf.sh" ]; then
            . "$ASDF_DIR/asdf.sh"
        fi
        if ! grep -E '^[^#]*asdf.*/asdf.sh' "$RC_CONFIG" >/dev/null 2>&1; then
            _UPDATE_RC_CONFIG=1
        fi
        if ! which asdf >/dev/null 2>&1; then
            _error asdf is not installed on your system
            echo "you can install asdf on $FLAVOR with the following command"
            if [ "$PLATFORM" = "darwin" ]; then
                echo "
    ${C_GREEN}brew install asdf${C_END}"
                if [ "$_UPDATE_RC_CONFIG" = "1" ]; then
                    echo "    ${C_GREEN}printf '\\\\n. \"$ASDF_DIR/asdf.sh\"\\\\n' >> \"$RC_CONFIG\"${C_END}"
                fi
                echo
            else
                echo "
    ${C_GREEN}git clone https://github.com/asdf-vm/asdf.git $HOME/.asdf --branch v0.14.0${C_END}"
                if [ "$_UPDATE_RC_CONFIG" = "1" ]; then
                    echo "    ${C_GREEN}printf '\\\\n. \"\$HOME/.asdf/asdf.sh\"\\\\n' >> \"$RC_CONFIG\"${C_END}"
                fi
                echo
            fi
            printf "install for me [${C_GREEN}Y${C_END}|${C_RED}n${C_END}]: "
            read _RES
            if [ "$PLATFORM" = "darwin" ]; then
                if [ "$(echo "$_RES" | cut -c 1 | tr '[:lower:]' '[:upper:]')" != "N" ]; then
                    brew install asdf
                    if [ "$_UPDATE_RC_CONFIG" = "1" ]; then
                        printf "\n. \"$ASDF_DIR/asdf.sh\"\n" >>"$RC_CONFIG"
                    fi
                else
                    exit 1
                fi
            else
                if [ "$(echo "$_RES" | cut -c 1 | tr '[:lower:]' '[:upper:]')" != "N" ]; then
                    git clone https://github.com/asdf-vm/asdf.git $HOME/.asdf --branch v0.14.0
                    if [ "$_UPDATE_RC_CONFIG" = "1" ]; then
                        printf '\n. "$HOME/.asdf/asdf.sh"\n' >>"$RC_CONFIG"
                    fi
                else
                    exit 1
                fi
            fi
            . "$ASDF_DIR/asdf.sh"
        fi
    fi
    for p in $(echo "$(cat "$PROJECT_ROOT/.tool-versions" | cut -d' ' -f1 | uniq)" | tr ' ' '\n' | sort | uniq -u); do
        asdf plugin add $p
    done
    asdf install
}

_require_binaries() {
    jq -r '.binaries // {} | keys[]' "$MKPM_CONFIG" | while IFS= read -r _SYSTEM_BINARY; do
        if ! which $_SYSTEM_BINARY >/dev/null 2>&1; then
            _SYSTEM_PACKAGE_INSTALL_COMMAND="$(jq -r --compact-output ".binaries.\"$_SYSTEM_BINARY\" // \"\"" "$MKPM_CONFIG")"
            if [ "$(echo "$_SYSTEM_PACKAGE_INSTALL_COMMAND" | cut -c 1)" = "{" ]; then
                _SYSTEM_PACKAGE_INSTALL_COMMAND="$(jq -r ".binaries.\"$_SYSTEM_BINARY\".$FLAVOR // \"\"" "$MKPM_CONFIG")"
                if [ "$_SYSTEM_PACKAGE_INSTALL_COMMAND" = "" ]; then
                    _SYSTEM_PACKAGE_INSTALL_COMMAND="$(jq -r ".binaries.\"$_binary\".$PLATFORM // \"\"" "$MKPM_CONFIG")"
                fi
            fi
            if [ "$_SYSTEM_PACKAGE_INSTALL_COMMAND" != "" ]; then
                _error $_SYSTEM_BINARY is not installed on your system
                printf "you can install $_SYSTEM_BINARY on $FLAVOR with the following command

    ${C_GREEN}$_SYSTEM_PACKAGE_INSTALL_COMMAND${C_END}

install for me [${C_GREEN}Y${C_END}|${C_RED}n${C_END}]: "
                read _RES </dev/tty
                if [ "$(echo "$_RES" | cut -c 1 | tr '[:lower:]' '[:upper:]')" != "N" ]; then
                    eval $_SYSTEM_PACKAGE_INSTALL_COMMAND
                else
                    exit 1
                fi
            fi
        fi
    done
}

_require_git_lfs() {
    _require_system_binary git-lfs
    if [ "$(git config --global --get-regexp 'filter.lfs')" = "" ]; then
        _error git-lfs is not configured on your system
        printf "you can configure git-lfs on $FLAVOR with the following command

    ${C_GREEN}git lfs install${C_END}
    ${C_GREEN}git lfs pull${C_END}

configure for me [${C_GREEN}Y${C_END}|${C_RED}n${C_END}]: "
        read _RES
        if [ "$(echo "$_RES" | cut -c 1 | tr '[:lower:]' '[:upper:]')" != "N" ]; then
            git lfs install
            git lfs pull
        else
            exit 1
        fi
    fi
    _ensure_dirs
    _validate_mkpm_config
    if [ ! -d "$_MKPM_PACKAGES" ]; then
        if [ -f "$MKPM_ROOT/cache.tar.gz" ]; then
            _restore_from_cache
        else
            _install
        fi
    fi
}

_prepare() {
    if [ "$_MKPM_RESET_CACHE" = "1" ] ||
        ([ "$_MKPM_TEST" = "1" ] && [ -f "$MKPM/mkpm" ] && [ "$PROJECT_ROOT/mkpm.mk" -nt "$MKPM/mkpm" ]); then
        _reset_cache
        exit $?
    fi
    if [ ! -f "$MKPM/.ready" ]; then
        if [ "$PLATFORM" = "darwin" ]; then
            _require_brew
        fi
        if [ "REQUIRE_ASDF" = "1" ] && [ -f "$PROJECT_ROOT/.tool-versions" ]; then
            _require_asdf
        fi
        _require_system_binary curl
        _require_system_binary git
        _require_system_binary grep
        _require_system_binary jq
        if [ "$PLATFORM" = "darwin" ]; then
            _require_system_binary gawk --version
            _require_system_binary gsed --version
            _require_system_binary gtar --version
            _require_system_binary remake --version
        else
            if ! awk 2>&1 | grep -q BusyBox; then
                _require_system_binary awk -Wversion
            fi
            _require_system_binary make --version
            _require_system_binary sed --version
            _require_system_binary tar --version
        fi
        _require_git_lfs
        _ensure_mkpm_mk
        _require_binaries
        touch -m "$MKPM/.ready"
    elif [ "REQUIRE_ASDF" = "1" ] && [ "$PROJECT_ROOT/.tool-versions" -nt "$MKPM/.ready" ]; then
        _require_asdf
        touch -m "$MKPM/.ready"
    fi
}

_lookup_system_package_name() {
    _BINARY="$1"
    case "$_BINARY" in
    awk)
        case "$PKG_MANAGER" in
        apt-get)
            echo gawk
            ;;
        *)
            echo "$_BINARY"
            ;;
        esac
        ;;
    gmake)
        case "$PKG_MANAGER" in
        brew)
            echo make
            ;;
        *)
            echo "$_BINARY"
            ;;
        esac
        ;;
    gtar)
        case "$PKG_MANAGER" in
        brew)
            echo gnu-tar
            ;;
        *)
            echo "$_BINARY"
            ;;
        esac
        ;;
    python3)
        case "$PKG_MANAGER" in
        brew)
            echo python
            ;;
        apt-get)
            echo python3-minimal
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

_pack() {
    _PACKAGE_NAME=$(cat "$MKPM_CONFIG" 2>/dev/null | jq -r '.name // ""')
    if [ "$_PACKAGE_NAME" = "" ]; then
        _error missing mkpm package name
        exit 1
    fi
    if [ "$(cat "$MKPM_CONFIG" 2>/dev/null | jq -r '.version // ""')" = "" ]; then
        _error missing mkpm package version
        exit 1
    fi
    if [ "$(cat "$MKPM_CONFIG" 2>/dev/null | jq -r '.description // ""')" = "" ]; then
        _error missing mkpm package description
        exit 1
    fi
    if [ "$(cat "$MKPM_CONFIG" 2>/dev/null | jq -r '.author // ""')" = "" ]; then
        _error missing mkpm package author
        exit 1
    fi
    if [ "$(cat "$MKPM_CONFIG" 2>/dev/null | jq -r '.repo // ""')" = "" ]; then
        _error missing mkpm package repo
        exit 1
    fi
    if [ "$(cat "$MKPM_CONFIG" 2>/dev/null | jq -r '.source // ""')" = "" ]; then
        _error missing mkpm package source
        exit 1
    fi
    if [ ! -f "$PROJECT_ROOT/main.mk" ]; then
        _error missing main.mk
        exit 1
    fi
    _PACK_DIR="$(mktemp -d)"
    rm -rf "$PROJECT_ROOT/$_PACKAGE_NAME.tar.gz"
    cp "$MKPM_CONFIG" "$_PACK_DIR/mkpm.json"
    if [ -f "$PROJECT_ROOT/LICENSE" ]; then
        cp "$PROJECT_ROOT/LICENSE" "$_PACK_DIR/LICENSE"
    fi
    for f in $(cat "$MKPM_CONFIG" 2>/dev/null | jq -r '(.files // [])[]'); do
        if [ -f "$PROJECT_ROOT/$f" ]; then
            mkdir -p "$_PACK_DIR/$f"
            rm -rf "$_PACK_DIR/$f"
            cp "$PROJECT_ROOT/$f" "$_PACK_DIR/$f"
        fi
    done
    cp "$PROJECT_ROOT/main.mk" "$_PACK_DIR/main.mk"
    tar -cvzf "$PROJECT_ROOT/$_PACKAGE_NAME.tar.gz" -C "$_PACK_DIR" . |
        sed 's|^\.\/||g' | sed '/^$/d' >$([ "$_SILENT" = "1" ] && echo '/dev/null' || echo '/dev/stdout')
    rm -rf "$_PACK_DIR"
    _echo "packaged $_PACKAGE_NAME.tar.gz"
}

_publish() {
    _require_system_binary python3
    _require_system_binary pandoc
    _exit() {
        cd "$_CWD"
        rm -rf "$_REPO_PATH" 2>/dev/null
        exit $1
    }
    _PACKAGE_NAME=$(cat "$MKPM_CONFIG" 2>/dev/null | jq -r '.name // ""')
    _PACKAGE_VERSION=$(cat "$MKPM_CONFIG" 2>/dev/null | jq -r '.version // ""')
    _PACKAGE_REPO=$(cat "$MKPM_CONFIG" 2>/dev/null | jq -r '.repo // ""')
    _PACKAGE_SOURCE=$(cat "$MKPM_CONFIG" 2>/dev/null | jq -r '.source // ""')
    _PACKAGE_DESCRIPTION=$(cat "$MKPM_CONFIG" 2>/dev/null | jq -r '.description // ""')
    _PACKAGE_AUTHOR=$(cat "$MKPM_CONFIG" 2>/dev/null | jq -r '.author // ""')
    if [ "$_PACKAGE_NAME" = "" ]; then
        _error missing mkpm package name
        exit 1
    fi
    if [ "$_PACKAGE_VERSION" = "" ]; then
        _error missing mkpm package version
        exit 1
    fi
    if [ "$_PACKAGE_REPO" = "" ]; then
        _error missing mkpm package repo
        exit 1
    fi
    if [ "$_PACKAGE_SOURCE" = "" ]; then
        _error missing mkpm package source
        exit 1
    fi
    if [ "$_PACKAGE_DESCRIPTION" = "" ]; then
        _error missing mkpm package description
        exit 1
    fi
    if [ "$_PACKAGE_AUTHOR" = "" ]; then
        _error missing mkpm package author
        exit 1
    fi
    _REPO_PATH="$(mktemp -d)/repo"
    _echo "publishing package $_PACKAGE_NAME=$_PACKAGE_VERSION to repo $_PACKAGE_REPO"
    if [ ! -d "$_REPO_PATH" ]; then
        git clone -q --depth 1 "$_PACKAGE_REPO" "$_REPO_PATH" || _exit 1
    fi
    cd "$_REPO_PATH"
    git config advice.detachedHead false >/dev/null
    git config lfs.locksverify true >/dev/null
    git fetch -q --depth 1 --tags || _exit 1
    mkdir -p "$_PACKAGE_NAME"
    cp "$PROJECT_ROOT/$_PACKAGE_NAME.tar.gz" "$_PACKAGE_NAME/$_PACKAGE_NAME.tar.gz"
    _write_package_to_readme "$_REPO_PATH/README.md" "$_PACKAGE_NAME" "$_PACKAGE_SOURCE" "$_PACKAGE_VERSION" "$_PACKAGE_DESCRIPTION" "$_PACKAGE_AUTHOR"
    git add "$_PACKAGE_NAME/$_PACKAGE_NAME.tar.gz"
    git add "$_REPO_PATH/README.md"
    git commit -m "Publish $_PACKAGE_NAME version $_PACKAGE_VERSION" || _exit 1
    git tag "$_PACKAGE_NAME/$_PACKAGE_VERSION" || _exit 1
    git push || _exit 1
    git push --tags || _exit 1
    _exit
}

_PKG_MANAGER_SUDO="$(which sudo >/dev/null 2>&1 && echo sudo || true) "
_lookup_system_package_install_command() {
    _BINARY="$1"
    _PACKAGE="$([ "$2" = "" ] && echo "$_BINARY" || echo "$2")"
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
    _SYSTEM_PACKAGE_INSTALL_COMMAND="$(_lookup_system_package_install_command "$_SYSTEM_BINARY" "$_SYSTEM_PACKAGE_NAME")"
    if ! ([ "$_ARGS" = "" ] && which "$_SYSTEM_BINARY" || "$_SYSTEM_BINARY" "$_ARGS") >/dev/null 2>&1; then
        _error $_SYSTEM_BINARY is not installed on your system
        printf "you can install $_SYSTEM_BINARY on $FLAVOR with the following command

    ${C_GREEN}$_SYSTEM_PACKAGE_INSTALL_COMMAND${C_END}

install for me [${C_GREEN}Y${C_END}|${C_RED}n${C_END}]: "
        read _RES
        if [ "$(echo "$_RES" | cut -c 1 | tr '[:lower:]' '[:upper:]')" != "N" ]; then
            eval $_SYSTEM_PACKAGE_INSTALL_COMMAND
        else
            exit 1
        fi
    else
        _debug system binary $_SYSTEM_BINARY found
    fi
}

_ensure_dirs() {
    if [ ! -d "$MKPM/.bin" ]; then
        mkdir -p "$MKPM/.bin"
    fi
    if [ ! -d "$MKPM/.tmp" ]; then
        mkdir -p "$MKPM/.tmp"
    fi
}

_ensure_mkpm_mk() {
    if [ "$_MKPM_TEST" = "1" ]; then
        if [ ! -f "$MKPM/mkpm" ] || [ "$PROJECT_ROOT/mkpm.mk" -nt "$MKPM/mkpm" ]; then
            cp "$PROJECT_ROOT/mkpm.mk" "$MKPM/mkpm"
            _debug downloaded mkpm.mk
            _create_cache
        fi
    elif [ ! -f "$MKPM/mkpm" ]; then
        download "$MKPM/mkpm" "$MKPM_MK_URL" >/dev/null
        _debug downloaded mkpm.mk
        _create_cache
    fi
}

_ensure_mkpm_sh() {
    if [ "$_MKPM_TEST" = "1" ]; then
        mkdir -p "$MKPM_BIN"
        if [ ! -f "$MKPM_BIN/mkpm" ]; then
            if [ -f "$MKPM_ROOT/cache.tar.gz" ]; then
                _restore_from_cache
            else
                cp "$PROJECT_ROOT/mkpm.sh" "$MKPM_BIN/mkpm"
                _debug downloaded mkpm.sh
            fi
        fi
        chmod +x "$MKPM_BIN/mkpm"
    elif [ ! -f "$MKPM_BIN/mkpm" ]; then
        mkdir -p "$MKPM_BIN"
        if [ -f "$MKPM_ROOT/cache.tar.gz" ]; then
            _restore_from_cache
        fi
        if [ ! -f "$MKPM_BIN/mkpm" ]; then
            download "$MKPM_BIN/mkpm" "$MKPM_SH_URL" >/dev/null
            _debug downloaded mkpm.sh
        fi
        chmod +x "$MKPM_BIN/mkpm"
    fi
}

_create_cache() {
    _TAR="$(which gtar >/dev/null 2>&1 && echo gtar || echo tar)"
    cd "$MKPM"
    touch "$MKPM_ROOT/cache.tar.gz"
    $_TAR --format=gnu --sort=name --mtime='1970-01-01 00:00:00 UTC' -czf "$MKPM_ROOT/cache.tar.gz" \
        --exclude '.ready' \
        --exclude '.tmp' \
        .
    cd "$_CWD"
    _debug created cache
}

_restore_from_cache() {
    if [ -f "$MKPM_ROOT/cache.tar.gz" ]; then
        rm -rf "$MKPM"
        mkdir -p "$MKPM"
        cd "$MKPM"
        tar -xzf "$MKPM_ROOT/cache.tar.gz" >/dev/null
        cd "$_CWD"
        _debug restored cache
    fi
}

_reset_cache() {
    rm -rf \
        "$MKPM_ROOT/cache.tar.gz" \
        "$MKPM/.prepared" \
        "$MKPM/mkpm" 2>/dev/null
    if [ -f "$PROJECT_ROOT/mkpm.mk" ]; then
        cp "$PROJECT_ROOT/mkpm.mk" "$MKPM/mkpm"
    fi
    unset _MKPM_RESET_CACHE
    _debug reset cache
    exec "$__0" $__ARGS
}

_is_repo_uri() {
    echo "$1" | grep -E '^(\w+://.+)|(git@.+:.+)$' >/dev/null 2>&1
}

_lookup_default_repo() {
    for r in $(_list_repos); do
        echo "$r"
        return
    done
}

_list_repos() {
    cat "$MKPM_CONFIG" 2>/dev/null | jq -r '(.repos | keys)[]'
}

_lookup_repo_uri() {
    _REPO="$1"
    cat "$MKPM_CONFIG" 2>/dev/null | jq -r ".repos.$_REPO // \"\""
}

_lookup_repo_path() {
    echo "$_REPOS_PATH/$(echo "$1" | (md5sum 2>/dev/null || md5) | cut -d ' ' -f1)"
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

_list_packages() {
    _REPO="$1"
    for p in $(cat "$MKPM_CONFIG" 2>/dev/null | jq -r "(.packages.${_REPO} | keys)[]"); do
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
        cat "$MKPM_CONFIG" 2>/dev/null |
            jq "del(.packages.${r}.${_PACKAGE_NAME})" |
            _sponge "$MKPM_CONFIG" >/dev/null
    done
}

_validate_mkpm_config() {
    if [ ! -f "$MKPM_CONFIG" ] || [ "$(cat "$MKPM_CONFIG" 2>/dev/null | jq -r '. | type')" != "object" ]; then
        echo '{}' >"$MKPM_CONFIG"
    fi
    cat "$MKPM_CONFIG" 2>/dev/null |
        jq ".packages += {}" |
        _sponge "$MKPM_CONFIG" >/dev/null
    cat "$MKPM_CONFIG" 2>/dev/null |
        jq ".repos += {}" |
        _sponge "$MKPM_CONFIG" >/dev/null
    if [ "$(cat "$MKPM_CONFIG" 2>/dev/null | jq '.repos | length')" = "0" ]; then
        cat "$MKPM_CONFIG" 2>/dev/null |
            jq ".repos += {\"default\": \"${DEFAULT_REPO}\"}" |
            _sponge "$MKPM_CONFIG" >/dev/null
    fi
    for r in $(_list_repos); do
        cat "$MKPM_CONFIG" 2>/dev/null |
            jq ".packages.${r} += {}" |
            _sponge "$MKPM_CONFIG" >/dev/null
    done
    _ERR=
    for r in $(echo "$(_list_repos) $(cat "$MKPM_CONFIG" 2>/dev/null | jq -r '(.packages | keys)[]')" | tr ' ' '\n' |
        sort | uniq -c | grep -E "^\s+1\s" | sed 's|\s\+[0-9]\+\s||g'); do
        _PACKAGES="$(_list_packages "$r")"
        if [ "$_PACKAGES" = "" ]; then
            cat "$MKPM_CONFIG" 2>/dev/null |
                jq "del(.packages.${r})" |
                _sponge "$MKPM_CONFIG" >/dev/null
        else
            for p in $_PACKAGES; do
                _error "package ${C_LIGHT_CYAN}$p${C_END} missing ${C_LIGHT_CYAN}$r${C_END} repo"
                _ERR=1
            done
        fi
    done
    for p in $(cat "$MKPM_CONFIG" 2>/dev/null | jq -r '.packages[] | keys[]' | sort | uniq -c | grep -vE "^\s+1\s" | sed 's|\s\+[0-9]\+\s||g'); do
        _error "package ${C_LIGHT_CYAN}$p${C_END} exists more than once"
        _ERR=1
    done
    if [ "$_ERR" = "1" ]; then
        exit 1
    fi
}

_write_package_to_readme() {
    _README_MD="$1"
    _PACKAGE_NAME="$2"
    _PACKAGE_SOURCE="$3"
    _PACKAGE_VERSION="$4"
    _PACKAGE_DESCRIPTION="$5"
    _PACKAGE_AUTHOR="$6"
    if [ ! -f "$_README_MD" ]; then
        cat <<EOF >"$_README_MD"
# mkpm packages

> mkpm packages
EOF
    fi
    if ! (cat "$_README_MD" | grep -qE '^\|[^|]*Package[^|]*\|[^|]*Version[^|]*\|[^|]*Description[^|]*\|[^|]*Author[^|]*\|'); then
        echo "
## Packages

| Package | Version | Description | Author |
| ------- | ------- | ----------- | ------ |
" >>"$_README_MD"
    fi
    if cat "$_README_MD" | grep -qE "^\|[^|]*${_PACKAGE_NAME}[^|]*\|[^|]*\|[^|]*\|[^|]*\|"; then
        sed -i "s/^|[^|]*${_PACKAGE_NAME}[^|]*|[^|]*|[^|]*|[^|]*|/| [${_PACKAGE_NAME}]($(echo "${_PACKAGE_SOURCE}" | sed 's|/|\\\/|g')) | ${_PACKAGE_VERSION} | ${_PACKAGE_DESCRIPTION} | ${_PACKAGE_AUTHOR} |/g" "$_README_MD"
    else
        python3 -c "
import re
filename = '$_README_MD'
new_row = '| [${_PACKAGE_NAME}](${_PACKAGE_SOURCE}) | ${_PACKAGE_VERSION} | ${_PACKAGE_DESCRIPTION} | ${_PACKAGE_AUTHOR} |'
with open(filename, 'r') as file:
    lines = file.readlines()
in_table = False
table = []
for i, line in enumerate(lines):
    if re.match(r'\|.*\|', line.strip()):
        if not in_table:
            in_table = True
        table.append(line)
    else:
        if in_table:
            lines[i] = new_row + '\n' + line
            in_table = False
            table = []
if in_table:
    lines.append(new_row + '\n')
with open(filename, 'w') as file:
    file.writelines(lines)
"
    fi
    pandoc -f markdown -t gfm -o "$_README_MD" "$_README_MD"
    sed -i 's/|-/| /g' "$_README_MD"
    sed -i 's/-|/ |/g' "$_README_MD"
}

_sponge() {
    if which sponge >/dev/null 2>&1; then
        sponge "$@"
    else
        if [ -p /dev/stdin ]; then
            _TMP_FILE=$(mktemp)
            cat >"$_TMP_FILE"
            cat "$_TMP_FILE" >"$1"
            rm -f "$_TMP_FILE"
        fi
        cat "$1"
    fi
}

_help() {
    echo "mkpm - makefile package manager"
    echo
    echo "mkpm [options] <TARGET> [...ARGS]"
    echo "mkpm [options] - <COMMAND> [...ARGS]"
    echo
    echo "options:"
    echo "    -h, --help                            show brief help"
    echo "    -s, --silent                          silent output"
    echo "    -d, --debug                           debug output"
    echo
    echo "commands:"
    echo "    u|upgrade                             upgrade all packages from default git repo"
    echo "    u|upgrade <REPO>                      upgrade all packages from git repo"
    echo "    u|upgrade <REPO> <PACKAGE>            upgrade a package from git repo"
    echo "    v|version                             mkpm version"
    echo "    i|install                             install all packages"
    echo "    i|install <PACKAGE>                   install a package from default git repo"
    echo "    i|install <REPO> <PACKAGE>            install a package from git repo"
    echo "    rm|remove <PACKAGE>                   remove a package"
    echo "    ra|repo-add <REPO_NAME> <REPO_URI>    add repo"
    echo "    rr|repo-remove <REPO_NAME>            remove repo"
    echo "    reset                                 reset mkpm"
    echo "    init                                  initialize mkpm"
    echo "    pack                                  pack mkpm module"
    echo "    publish                               pack and publish mkpm module"
}

export ARCH=unknown
export FLAVOR=unknown
export PKG_MANAGER=unknown
export PLATFORM=unknown
PLATFORM=$(uname 2>/dev/null | tr '[:upper:]' '[:lower:]' 2>/dev/null)
ARCH=$( (dpkg --print-architecture 2>/dev/null || uname -m 2>/dev/null || arch 2>/dev/null || echo unknown) |
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
            PKG_MANAGER=$(which microdnf >/dev/null 2>&1 && echo microdnf ||
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
if [ "$FLAVOR" = "unknown" ]; then
    FLAVOR="$PLATFORM"
fi

if [ "$_SCRIPT_PATH" != "${MKPM_BIN}/mkpm" ]; then
    if [ -f "${MKPM_BIN}/mkpm" ] || [ "$_MKPM_PROXY_REQUIRED" = "1" ]; then
        if [ ! -f "$MKPM_BIN/mkpm" ]; then
            mkdir -p "$MKPM_BIN"
            if [ -f "$MKPM_ROOT/cache.tar.gz" ]; then
                _restore_from_cache
            fi
            if [ ! -f "$MKPM_BIN/mkpm" ]; then
                download "$MKPM_BIN/mkpm" "$MKPM_SH_URL" >/dev/null
                _debug downloaded mkpm.sh
            fi
            chmod +x "$MKPM_BIN/mkpm"
        fi
        _ensure_mkpm_sh
        _debug "proxied ${C_LIGHT_GREEN}$MKPM_BIN/mkpm $@${C_END}"
        exec "$MKPM_BIN/mkpm" "$@"
    fi
fi

while test $# -gt 0; do
    case "$1" in
    -)
        _IS_MKPM_COMMAND=1
        shift
        ;;
    -h | --help)
        _help
        exit
        ;;
    -s | --silent)
        if [ "$MKPM_DEBUG" != "1" ]; then
            _SILENT=1
        fi
        _MAKE_FLAGS="-s"
        shift
        ;;
    -d | --debug)
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

if [ "$_IS_MKPM_COMMAND" = "1" ]; then
    case "$1" in
    i | install)
        export _COMMAND=install
        shift
        if test $# -gt 0; then
            export _PARAM1="$1"
            shift
            if test $# -gt 0; then
                export _PARAM2="$1"
                shift
            else
                export _PARAM2="$_PARAM1"
                export _PARAM1="$(_lookup_default_repo)"
            fi
        fi
        ;;
    rm | remove)
        export _COMMAND=remove
        shift
        if test $# -gt 0; then
            export _PARAM1="$1"
            shift
        else
            _error "no package specified"
            exit 1
        fi
        ;;
    u | upgrade)
        export _COMMAND=upgrade
        shift
        if test $# -gt 0; then
            export _PARAM1="$1"
            shift
        else
            export _PARAM1="$(_lookup_default_repo)"
        fi
        if test $# -gt 0; then
            export _PARAM2="$1"
            shift
        fi
        ;;
    ra | repo-add)
        export _COMMAND=repo-add
        shift
        if test $# -gt 0; then
            export _PARAM1="$1"
            shift
        else
            _error "no repo name specified"
            exit 1
        fi
        if test $# -gt 0; then
            export _PARAM2="$1"
            shift
        else
            _error "no repo uri specified"
            exit 1
        fi
        ;;
    rr | repo-remove)
        export _COMMAND=repo-remove
        shift
        if test $# -gt 0; then
            export _PARAM1="$1"
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
    v | version)
        _echo "$MKPM_VERSION"
        exit
        ;;
    pack)
        export _COMMAND=pack
        shift
        ;;
    publish)
        export _COMMAND=publish
        shift
        ;;
    *)
        _help
        exit
        ;;
    esac
else
    export _COMMAND=run
    export _TARGET="$1"
    if [ "$_TARGET" != "" ]; then
        shift
    fi
fi

main "$@"
