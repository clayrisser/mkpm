# File: /mkpm.mk
# Project: mkpm
# File Created: 04-12-2021 02:15:12
# Author: Clay Risser
# -----
# Last Modified: 03-08-2023 05:33:04
# Modified By: Clay Risser
# -----
# BitSpur (c) Copyright 2021
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

.ONESHELL:
.POSIX:
.SILENT:

export MKPM_VERSION := <% MKPM_VERSION %>

export LC_ALL := C
export MAKESHELL ?= $(SHELL)

export ECHO := echo
export TRUE := true
export WHICH := command -v

export BANG := \!
export NULL := /dev/null
export NOFAIL := 2>$(NULL) || $(TRUE)
export NOOUT := >$(NULL) 2>&1

define ternary
$(shell $1 $(NOOUT) && $(ECHO) $2|| $(ECHO) $3)
endef

export COLUMNS := $(shell tput cols 2>$(NULL) || (eval $(resize 2>$(NULL)) 2>$(NULL) && $(ECHO) $$COLUMNS))
define columns
$(call ternary,[ "$(COLUMNS)" -$1 "$2" ],1)
endef
WINDOW_SM=$(call columns,lt,80)

define git_clean_flags
-e $(BANG)$1 \
-e $(BANG)$1/ \
-e $(BANG)$1/**/* \
-e $(BANG)/$1 \
-e $(BANG)/$1/ \
-e $(BANG)/$1/**/* \
-e $(BANG)/**/$1 \
-e $(BANG)/**/$1/ \
-e $(BANG)/**/$1/**/*
endef
export MKPM_GIT_CLEAN_FLAGS := $(call git_clean_flags,$(MKPM_ROOT_NAME))

export MKPM_CLEANED := $(MKPM)/.cleaned
define MKPM_CLEAN
$(TOUCH) -m $(MKPM)/.cleaned
endef

export NIX_ENV := $(call ternary,$(ECHO) '$(PATH)' | grep -q ":/nix/store",1)
ifneq ($(NIX_ENV),1)
	ifeq ($(PLATFORM),darwin)
		export AWK ?= $(call ternary,gawk --version,gawk,awk)
		export GREP ?= $(call ternary,ggrep --version,ggrep,grep)
		export SED ?= $(call ternary,gsed --version,gsed,sed)
	endif
endif
export AWK ?= awk
export GIT ?= git
export GREP ?= grep
export SED ?= sed
export TAR ?= $(call ternary,$(WHICH) tar,$(shell $(WHICH) tar 2>$(NULL)),$(TRUE))
export DOWNLOAD	?= $(call ternary,curl --version,curl -L -o,wget -O)

export ROOT ?= $(patsubst %/,%,$(dir $(abspath $(firstword $(MAKEFILE_LIST)))))
export SUBPROC :=
ifneq ($(ROOT),$(CURDIR))
	SUBPROC = 1
endif
export SUBDIR :=
ifneq ($(PROJECT_ROOT),$(CURDIR))
	SUBDIR = 1
endif

export NPROC := 1
ifeq ($(PLATFORM),linux)
	NPROC = $(shell nproc $(NOOUT) && nproc || $(GREP) -c -E "^processor" /proc/cpuinfo 2>$(NULL) || $(ECHO) 1)
endif
ifeq ($(PLATFORM),darwin)
	NPROC = $(shell sysctl hw.ncpu | $(CUT) -d " " -f 2 2>$(NULL) || $(ECHO) 1)
endif
export NUMPROC ?= $(NPROC)
export MAKEFLAGS += "-j $(NUMPROC)"

ifeq (,$(.DEFAULT_GOAL))
.DEFAULT_GOAL = $(HELP)
endif

export SUDO ?= $(call ternary,$(WHICH) sudo,sudo -E,)
.PHONY: sudo
ifneq (,$(SUDO))
sudo:
	@$(SUDO) $(TRUE)
else
sudo: ;
endif

export SHARED_MK := $(wildcard $(PROJECT_ROOT)/shared.mk)
ifneq (,$(SHARED_MK))
include $(SHARED_MK)
endif

ifneq ($(patsubst %.exe,%,$(SHELL)),$(SHELL))
include cmd.exe
cmd.exe:
	@$(ECHO) cmd.exe not supported 1>&2
	@$(ECHO) if you are on Windows, please use WSL (Windows Subsystem for Linux) 1>&2
	@$(ECHO) https://docs.microsoft.com/windows/wsl 1>&2
	@$(EXIT) 1
endif
