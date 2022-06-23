# File: /mkpm.mk
# Project: mkpm
# File Created: 26-09-2021 00:44:57
# Author: Clay Risser
# -----
# Last Modified: 23-06-2022 11:52:56
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
	hello=0.1.0 \
	gnu=0.0.3 \
	mkchain=0.1.0 \
	pkg=0.0.1

export MKPM_REPO_DEFAULT := \
	https://gitlab.com/risserlabs/community/mkpm-stable.git

############# MKPM BOOTSTRAP SCRIPT BEGIN #############
MKPM_BOOTSTRAP := https://gitlab.com/api/v4/projects/29276259/packages/generic/mkpm/0.2.0/bootstrap.mk
export PROJECT_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
NULL := /dev/null
TRUE := true
ifneq ($(patsubst %.exe,%,$(SHELL)),$(SHELL))
	NULL = nul
	TRUE = type nul
endif
include $(PROJECT_ROOT)/.mkpm/.bootstrap.mk
$(PROJECT_ROOT)/.mkpm/.bootstrap.mk: bootstrap.mk mkpm.mk
ifeq ($(OS),Windows_NT)
	@mkdir .mkpm
	@type $< > $@
else
	@mkdir -p .mkpm/.bin
	@cp $< $@
	@cp mkpm.sh .mkpm/.bin/mkpm
	@chmod +x .mkpm/.bin/mkpm
endif
############## MKPM BOOTSTRAP SCRIPT END ##############
