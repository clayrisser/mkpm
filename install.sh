#!/bin/sh

_USER_ID=$(id -u $USER)
_TMP_PATH="${XDG_RUNTIME_DIR:-$([ -d "/run/user/$_USER_ID" ] && \
    echo "/run/user/$_USER_ID" || echo ${TMP:-${TEMP:-/tmp}})}/mkpm/$$"

sudo true
mkdir -p $_TMP_PATH
cd $_TMP_PATH
curl -LO https://gitlab.com/risserlabs/community/mkpm/-/archive/main/mkpm-main.tar.gz
tar -xzf mkpm-main.tar.gz
sudo cp mkpm-main/mkpm.sh /usr/local/bin/mkpm
sudo chmod +x /usr/local/bin/mkpm
rm -rf $_TMP_PATH
