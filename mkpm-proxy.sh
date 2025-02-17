#!/bin/sh
set -e

# File: /mkpm-proxy.sh
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
MKPM_SH_URL="${MKPM_SH_URL:-https://gitlab.com/api/v4/projects/48207162/packages/generic/mkpm/${MKPM_VERSION}/mkpm.sh}"
alias download="$(curl --version >/dev/null 2>&1 && echo curl -Lo || echo wget -O)"
alias echo="$([ "$(echo -e)" = "-e" ] && echo "echo" || echo "echo -e")"
_SUPPORTS_COLORS=$( (which tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]) && echo 1 || true)
_CWD="$(pwd)"
if [ "$_SUPPORTS_COLORS" = "1" ]; then
    export C_END='\033[0m'
    export C_GREEN='\033[32m'
    export C_RED='\033[31m'
    export C_YELLOW='\033[33m'
fi
_is_ci() {
    _CI_ENVS="JENKINS_URL TRAVIS CIRCLECI GITHUB_ACTIONS GITLAB_CI TF_BUILD BITBUCKET_PIPELINE_UUID TEAMCITY_VERSION"
    for k in $_CI_ENVS; do
        eval v=\$$k
        if [ "$v" != "" ] && [ "$v" != "0" ] && [ "$(echo $v | tr '[:upper:]' '[:lower:]')" != "false" ]; then
            echo "1"
            break
        fi
    done
}
_CI="$(_is_ci)"
_error() { echo "${C_RED}MKPM [E]:${C_END} $@" 1>&2; }
_debug() { [ "$MKPM_DEBUG" = "1" ] && echo "${C_YELLOW}MKPM [D]:${C_END} $@" || true; }
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
MKPM_BIN="$MKPM/.bin"
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
_PKG_MANAGER_SUDO="$(which sudo >/dev/null 2>&1 && echo sudo || true) "
_lookup_system_package_install_command() {
    _PACKAGE="$1"
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
if [ "$PLATFORM" = "darwin" ]; then
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
                (echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> $HOME/.zprofile
                eval "$(/opt/homebrew/bin/brew shellenv)"
            else
                exit 1
            fi
        fi
    fi
fi
_require_system_binary() {
    _SYSTEM_BINARY="$1"
    if ! which $_SYSTEM_BINARY >/dev/null 2>&1; then
        _SYSTEM_PACKAGE_INSTALL_COMMAND="$(_lookup_system_package_install_command $_SYSTEM_BINARY)"
        _error $_SYSTEM_BINARY is not installed on your system
        printf "you can install $_SYSTEM_BINARY on $FLAVOR with the following command

        ${C_GREEN}$_SYSTEM_PACKAGE_INSTALL_COMMAND${C_END}

install for me [${C_GREEN}Y${C_END}|${C_RED}n${C_END}]: "
        read _RES
        if [ "$(echo "$_RES" | cut -c 1 | tr '[:lower:]' '[:upper:]')" != "N" ]; then
            $_SYSTEM_PACKAGE_INSTALL_COMMAND
        else
            exit 1
        fi
    fi
}
_require_system_binary git
_require_system_binary git-lfs
if [ "$_CI" != "1" ] && [ "$(git config --global --get-regexp 'filter.lfs')" = "" ]; then
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
if [ ! -f "$MKPM_BIN/mkpm" ]; then
    mkdir -p "$MKPM_BIN"
    if [ -f "$MKPM_ROOT/cache.tar.gz" ]; then
        mkdir -p "$MKPM"
        cd "$MKPM"
        tar -xzf "$MKPM_ROOT/cache.tar.gz"
        cd "$_CWD"
        _debug restored cache
    else
        download "$MKPM_BIN/mkpm" "$MKPM_SH_URL" >/dev/null
        _debug downloaded mkpm.sh
    fi
    chmod +x "$MKPM_BIN/mkpm"
fi
exec "$MKPM_BIN/mkpm" "$@"
