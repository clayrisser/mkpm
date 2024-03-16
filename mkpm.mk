# File: /mkpm.mk
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

.ONESHELL:
.POSIX:
.SILENT:

export MKPM_VERSION := <% MKPM_VERSION %>
export MKPM_MAKE := $(MAKE) -sf Mkpmfile

export LC_ALL := C
export MAKESHELL ?= $(SHELL)

export ECHO := echo
export TRUE := true
export WHICH := command -v

export BANG := \!
export NULL := /dev/null
export NOFAIL := 2>$(NULL) || $(TRUE)
export NOOUT := >$(NULL) 2>&1

define make
$(shell C="$$([ "$1" = "" ] && $(TRUE) || $(ECHO) "C \"$1/\"")" && \
	[ -f "$${C}Mkpmfile" ] && $(ECHO) $(MAKE) -s$$C -f Mkpmfile || $(ECHO) $(MAKE) -s$$C)
endef
ifeq (,$(wildcard $(CURDIR)/Mkpmfile))
MAKEFILE := $(CURDIR)/Makefile
else
MAKEFILE := $(CURDIR)/Mkpmfile
endif

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

export NIX_ENV := $(call ternary,$(ECHO) "$(PATH)" | grep -q ":/nix/store",1)
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

export SHARED_MK := $(wildcard $(PROJECT_ROOT)/shared.mk)
ifneq (,$(SHARED_MK))
include $(SHARED_MK)
endif

NODE ?= node
HELP_GENERATE_TABLE ?= $(NODE) -e 'var a=console.log;a("|command|description|");a("|-|-|");require("fs").readFileSync(0,"utf-8").replace(/\u001b\[\d*?m/g,"").split("\n").map(e=>e.split(/\s+(.+)/).map(e=>e.trim())).map(e=>{var r=e[0];if(e&&r)a("|","`make "+r+"`","|",e.length>1?e[1]:"","|")})'
HELP_PREFIX ?=
HELP_SPACING ?= 32
HELP ?= _mkpm_help
ifeq (,$(.DEFAULT_GOAL))
.DEFAULT_GOAL = $(HELP)
endif
_mkpm_help:
	@$(CAT) $(MAKEFILE) | \
		$(GREP) -E '^[a-zA-Z0-9][^ 	%*]*:.*##' | \
		$(SORT) | \
		$(AWK) 'BEGIN {FS = ":[^#]*([ 	]+##[ 	]*)?"}; {printf "\033[36m%-$(HELP_SPACING)s  \033[0m%s\n", "$(HELP_PREFIX)"$$1, $$2}' | \
		$(UNIQ)
	$(eval PHONY_TARGETS := $(shell $(CAT) $(MAKEFILE) | $(GREP) -C2 -E 'C\s.+\$$\*' | $(GREP) -E '^\.PHONY:\s[a-z].+/%' | $(SED) 's|^.PHONY: ||g' | $(SED) 's|/%$$||g'))
	@$(foreach i,$(PHONY_TARGETS),\
		$(call make,$i); \
	)
.PHONY: help-generate-table
help-generate-table:
	@$(MKDIR) -p $(MKPM_TMP)
	@$(MAKE) -s $(HELP) | \
		$(HELP_GENERATE_TABLE)

export SUDO ?= $(call ternary,$(WHICH) sudo,sudo -E,)
.PHONY: sudo
ifneq (,$(SUDO))
sudo:
	@$(SUDO) $(TRUE)
else
sudo: ;
endif
