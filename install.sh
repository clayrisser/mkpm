#!/bin/sh

MKPM_VERSION="${MKPM_VERSION:-<% MKPM_VERSION %>}"

sudo true
sudo curl -L -o /usr/local/bin/mkpm \
    https://gitlab.com/api/v4/projects/48207162/packages/generic/mkpm/${MKPM_VERSION}/mkpm.sh
sudo chmod +x /usr/local/bin/mkpm
