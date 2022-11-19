#!/bin/sh

sudo true

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
				PKG_MANAGER=yum
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

if [ "$PLATFORM" = "darwin" ]; then
    brew install \
        coreutils \
        gnu-sed \
        grep \
        jq \
        make \
        yq
    curl -L https://gitlab.com/api/v4/projects/29276259/packages/generic/mkpm/0.3.0/mkpm.sh | \
        sudo tee /usr/local/bin/mkpm >/dev/null
    sudo chmod +x /usr/local/bin/mkpm
else
    echo "platform $PLATFORM not supported" 1>&2
    exit 1
fi
