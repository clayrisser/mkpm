# File: /mkpm.mk
# Project: mkpm
# File Created: 26-09-2021 00:44:57
# Author: Clay Risser
# -----
# Last Modified: 20-06-2022 09:12:27
# Modified By: Clay Risser
# -----
# Risser Labs LLC (c) Copyright 2021
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

export MKPM_PACKAGES_DEFAULT := \
	hello=0.0.4 \
	gnu=0.0.3

export MKPM_REPO_DEFAULT := \
	https://gitlab.com/risserlabs/community/mkpm-stable.git

############# MKPM BOOTSTRAP SCRIPT BEGIN #############
MKPM_BOOTSTRAP := https://risserlabs.gitlab.io/community/mkpm/bootstrap.mk
export PROJECT_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
NULL := /dev/null
TRUE := true
ifneq ($(patsubst %.exe,%,$(SHELL)),$(SHELL))
	NULL = nul
	TRUE = type nul
endif
include $(PROJECT_ROOT)/.mkpm/.bootstrap.mk
$(PROJECT_ROOT)/.mkpm/.bootstrap.mk: bootstrap.mk .mkpm/.bin/mkpm
ifeq ($(OS),Windows_NT)
	@type $< > $@
else
	@cp $< $@
endif
.mkpm/.bin/mkpm: mkpm.sh
	@mkdir -p .mkpm/.bin 2>$(NULL) || $(TRUE)
	@cp $< $@
	@chmod +x $@
############## MKPM BOOTSTRAP SCRIPT END ##############
