# File: /bootstrap.mk
# Project: mkpm
# File Created: 04-12-2021 02:15:12
# Author: Clay Risser
# -----
# Last Modified: 23-06-2022 11:45:08
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

.POSIX:
.SILENT:

export MKPM_BOOTSTRAP_VERSION := 0.1.1
export EXPECTED_MKPM_CLI_VERSION := 0.2.0
export MKPM_DIR := .mkpm
export MKPM_CLI_URI := \
	https://gitlab.com/api/v4/projects/29276259/packages/generic/mkpm/$(EXPECTED_MKPM_CLI_VERSION)/mkpm.sh

export MAKESHELL ?= $(SHELL)
export MKPM := $(abspath $(CURDIR)/$(MKPM_DIR))
export MKPM_CLI := $(MKPM)/.bin/mkpm
export MKPM_TMP := $(MKPM)/.tmp

export NOCOLOR=\033[0m
export RED=\033[0;31m
export GREEN=\033[0;32m
export ORANGE=\033[0;33m
export BLUE=\033[0;34m
export PURPLE=\033[0;35m
export CYAN=\033[0;36m
export LIGHTGRAY=\033[0;37m
export DARKGRAY=\033[1;30m
export LIGHTRED=\033[1;31m
export LIGHTGREEN=\033[1;32m
export YELLOW=\033[1;33m
export LIGHTBLUE=\033[1;34m
export LIGHTPURPLE=\033[1;35m
export LIGHTCYAN=\033[1;36m
export WHITE=\033[1;37m

export BANG := \!
export NOFAIL := 2>$(NULL) || $(TRUE)
export NOOUT := >$(NULL) 2>$(NULL)
export NULL := /dev/null

export CAT := cat
export CD := cd
export CHMOD := chmod
export CP := cp
export CUT := cut
export ECHO := echo
export EXIT := exit
export EXPORT := export
export FALSE := false
export MKDIR := mkdir
export RM := rm
export SORT := sort
export TOUCH := touch
export TR := tr
export TRUE := true
export UNIQ := uniq
export WHICH := command -v

export ARCH := unknown
export FLAVOR := unknown
export PKG_MANAGER := unknown
export PLATFORM := unknown
ifeq ($(OS),Windows_NT)
	export HOME := $(HOMEDRIVE)$(HOMEPATH)
	PLATFORM = win32
	FLAVOR = win64
	ARCH = $(PROCESSOR_ARCHITECTURE)
	PKG_MANAGER = choco
	ifeq ($(ARCH),AMD64)
		ARCH = amd64
	endif
	ifeq ($(ARCH),ARM64)
		ARCH = arm64
	endif
	ifeq ($(PROCESSOR_ARCHITECTURE),x86)
		ARCH = amd64
		ifeq (,$(PROCESSOR_ARCHITEW6432))
			ARCH = x86
			FLAVOR := win32
		endif
	endif
else
	PLATFORM = $(shell uname 2>$(NULL) | $(TR) '[:upper:]' '[:lower:]' 2>$(NULL))
	ARCH = $(shell (dpkg --print-architecture 2>$(NULL) || uname -m 2>$(NULL) || arch 2>$(NULL) || echo unknown) | $(TR) '[:upper:]' '[:lower:]' 2>$(NULL))
	ifeq ($(ARCH),i386)
		ARCH = 386
	endif
	ifeq ($(ARCH),i686)
		ARCH = 386
	endif
	ifeq ($(ARCH),x86_64)
		ARCH = amd64
	endif
	ifeq ($(PLATFORM),linux) # LINUX
		ifneq (,$(wildcard /system/bin/adb))
			ifneq ($(shell getprop --help >$(NULL) 2>$(NULL) && echo 1 || echo 0),1)
				PLATFORM = android
			endif
		endif
		ifeq ($(PLATFORM),linux)
			FLAVOR = $(shell lsb_release -si 2>$(NULL) | $(TR) '[:upper:]' '[:lower:]' 2>$(NULL))
			ifeq (,$(FLAVOR))
				FLAVOR = unknown
				ifneq (,$(wildcard /etc/redhat-release))
					FLAVOR = rhel
				endif
				ifneq (,$(wildcard /etc/SuSE-release))
					FLAVOR = suse
				endif
				ifneq (,$(wildcard /etc/debian_version))
					FLAVOR = debian
				endif
				ifeq ($(shell cat /etc/os-release 2>$(NULL) | grep -E "^ID=alpine$$"),ID=alpine)
					FLAVOR = alpine
				endif
			endif
			ifeq ($(FLAVOR),rhel)
				PKG_MANAGER = yum
			endif
			ifeq ($(FLAVOR),suse)
				PKG_MANAGER = zypper
			endif
			ifeq ($(FLAVOR),debian)
				PKG_MANAGER = apt-get
			endif
			ifeq ($(FLAVOR),ubuntu)
				PKG_MANAGER = apt-get
			endif
			ifeq ($(FLAVOR),alpine)
				PKG_MANAGER = apk
			endif
		endif
	else
		ifneq (,$(findstring CYGWIN,$(PLATFORM))) # CYGWIN
			PLATFORM = win32
			FLAVOR = cygwin
		endif
		ifneq (,$(findstring MINGW,$(PLATFORM))) # MINGW
			PLATFORM = win32
			FLAVOR = msys
			PKG_MANAGER = mingw-get
		endif
		ifneq (,$(findstring MSYS,$(PLATFORM))) # MSYS
			PLATFORM = win32
			FLAVOR = msys
			PKG_MANAGER = pacman
		endif
	endif
	ifeq ($(PLATFORM),darwin)
		PKG_MANAGER = brew
	endif
endif

define ternary
$(shell $1 $(NOOUT) && $(ECHO) $2|| $(ECHO) $3)
endef

ifeq ($(PKG_MANAGER),unknown)
	PKG_MANAGER = $(call ternary,apt-get,apt-get,$(call ternary,apk,apk,$(call ternary,yum,yum,$(call ternary,brew,brew,unknown))))
endif

export COLUMNS := $(shell tput cols 2>$(NULL) || (eval $(resize 2>$(NULL)) 2>$(NULL) && $(ECHO) $$COLUMNS))
define columns
$(call ternary,[ "$(COLUMNS)" -$1 "$2" ],1)
endef

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

export MKPM_GIT_CLEAN_FLAGS := $(call git_clean_flags,$(MKPM_DIR))
export MKPM_CLEANED := $(MKPM)/.cleaned
define MKPM_CLEAN
$(TOUCH) -m $(MKPM)/.cleaned
endef

export NIX_ENV := $(call ternary,$(ECHO) '$(PATH)' | grep -q ":/nix/store",1)
export DOWNLOAD	?= $(call ternary,curl --version,curl -L -o,wget -O)

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

export ROOT ?= $(patsubst %/,%,$(dir $(abspath $(firstword $(MAKEFILE_LIST)))))
export PROJECT_ROOT ?= $(shell \
	project_root() { \
		root=$$1 && \
		if [ -f "$$root/mkpm.mk" ]; then \
			$(ECHO) $$root && \
			return 0; \
		fi && \
		parent=$$($(ECHO) $$root | $(SED) 's|\/[^\/]\+$$||g') && \
		if ([ "$$parent" = "" ] || [ "$$parent" = "/" ]); then \
			$(ECHO) "/" && \
			return 0; \
		fi && \
		$(ECHO) $$(project_root $$parent) && \
		return 0; \
	} && \
	$(ECHO) $$(project_root $(ROOT)) \
)
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

ifeq ($(PKG_MANAGER),yum)
define pkg_manager_install
sudo yum install -y $1
endef
endif
ifeq ($(PKG_MANAGER),apt-get)
define pkg_manager_install
sudo apt-get install -y $1
endef
endif
ifeq ($(PKG_MANAGER),apk)
define pkg_manager_install
apk add --no-cache $1
endef
endif
ifeq ($(PKG_MANAGER),brew)
define pkg_manager_install
brew install $1
endef
endif
ifeq ($(PKG_MANAGER),choco)
define pkg_manager_install
choco install /y $1
endef
endif

define requires_pkg
$(ECHO) "$(YELLOW)"'the package $1 is required'"$(NOCOLOR)" && \
	$(ECHO) && \
	$(ECHO) "you can get \e[1m$1\e[0m at $2" && \
	$(ECHO) && \
	$(ECHO) or you can try to install $1 with the following command && \
	$(ECHO) && \
	([ "$3" != "" ] && $(ECHO) "$(GREEN)    $3$(NOCOLOR)" || $(ECHO) "$(GREEN)    $(call pkg_manager_install,$1)$(NOCOLOR)") && \
	$(ECHO) && \
	$(EXIT) 9009
endef

define _mkpm_failed
($(TOUCH) $(MKPM)/.failed && $(EXIT) 1)
endef

ifneq ($(PROJECT_ROOT),$(CURDIR))
ifneq (,$(wildcard $(PROJECT_ROOT)/$(MKPM_DIR)/.bootstrap))
_COPY_MKPM := 1
endif
endif
include $(MKPM)/.ready
-include $(MKPM)/.bootstrap
ifneq ($(TRUE),$(TAR))
-include $(MKPM)/.cache
$(MKPM)/.cache: $(PROJECT_ROOT)/mkpm.mk
	@$(MKDIR) -p $(MKPM)
	@([ -f $(MKPM)/.cache ] && [ "$(_LOAD_MKPM_FROM_CACHE)" = "" ]) && $(RM) -rf $(MKPM)/.cache.tar.gz || $(TRUE)
	@$(ECHO) 'ifneq (,$$(wildcard $$(MKPM)/.cache.tar.gz))' > $(MKPM)/.cache
	@$(ECHO) 'export _LOAD_MKPM_FROM_CACHE := 1' >> $(MKPM)/.cache
	@$(ECHO) 'else' >> $(MKPM)/.cache
	@$(ECHO) 'export _LOAD_MKPM_FROM_CACHE := 0' >> $(MKPM)/.cache
	@$(ECHO) 'endif' >> $(MKPM)/.cache
endif
$(MKPM)/.ready:
	@[ -f $(MKPM)/.failed ] && $(EXIT) 1 || $(TRUE)
	@$(TOUCH) $@
$(MKPM)/.bootstrap: $(PROJECT_ROOT)/mkpm.mk $(MKPM_CLI)
	@$(RM) -f $(MKPM)/.failed
ifeq (1,$(_LOAD_MKPM_FROM_CACHE))
	@[ ! -f $(MKPM)/.cache.tar.gz ] && $(EXIT) 1 || $(TRUE)
endif
	@if [ $(MKPM)/.cache -nt $(MKPM)/.cache.tar.gz ]; then \
		$(TOUCH) -m $(MKPM)/.cache.tar.gz && \
		$(EXIT) 1; \
	fi
ifeq ($(MAKELEVEL),0)
ifeq ($(call columns,lt,62),1)
	@$(ECHO)
	@$(ECHO) "$(LIGHTBLUE)MKPM$(NOCOLOR)"
	@$(ECHO)
	@$(ECHO) 'Risser Labs LLC (c) Copyright 2022'
	@$(ECHO)
else
	@$(ECHO)
	@$(ECHO) "$(LIGHTBLUE)"'                    88'
	@$(ECHO) '                    88'
	@$(ECHO) '                    88'
	@$(ECHO) '88,dPYba,,adPYba,   88   ,d8   8b,dPPYba,   88,dPYba,,adPYba,'
	@$(ECHO) "88P'   "'"88"    "8a  88 ,a8"    88P'"'    "'"8a  88P'"'   "'"88"    "8a'
	@$(ECHO) '88      88      88  8888[      88       d8  88      88      88'
	@$(ECHO) '88      88      88  88`"Yba,   88b,   ,a8"  88      88      88'
	@$(ECHO) '88      88      88  88   `Y8a  88`YbbdP"'"'   88      88      88"
	@$(ECHO) '                               88'
	@$(ECHO) '                               88'"$(NOCOLOR)"
	@$(ECHO)
	@$(ECHO) 'Risser Labs LLC (c) Copyright 2022'
	@$(ECHO)
endif
endif
ifneq ($(call ternary,git --version,1),1)
	@$(call requires_pkg,git,https://git-scm.com)
endif
ifneq ($(call ternary,git lfs --version,1),1)
	@$(call requires_pkg,git-lfs,https://git-lfs.github.com)
endif
ifneq ($(call ternary,tar --version,1),1)
	@$(call requires_pkg,tar,https://www.gnu.org/software/tar)
endif
ifeq ($(CURDIR),$(PROJECT_ROOT))
	@[ -f $(PROJECT_ROOT)/.gitignore ] || $(TOUCH) $(PROJECT_ROOT)/.gitignore
	@$(CAT) $(PROJECT_ROOT)/.gitignore | $(GREP) -E '^\.mkpm/$$' $(NOOUT) && \
		$(SED) -i '/^\.mkpm\/$$/d' $(PROJECT_ROOT)/.gitignore || \
		$(TRUE)
	@$(CAT) $(PROJECT_ROOT)/.gitignore | $(GREP) -E '^\.mkpm/\*$$' $(NOOUT) && $(TRUE) || \
		$(ECHO) '.mkpm/*' >> $(PROJECT_ROOT)/.gitignore
	@$(CAT) $(PROJECT_ROOT)/.gitignore | $(GREP) -E '^\*\*\/\.mkpm/\*$$' $(NOOUT) && $(TRUE) || \
		$(ECHO) '**/.mkpm/*' >> $(PROJECT_ROOT)/.gitignore
	@$(CAT) $(PROJECT_ROOT)/.gitignore | $(GREP) -E '^!\/\.mkpm/\.cache\.tar\.gz$$' $(NOOUT) && $(TRUE) || \
		$(ECHO) '!/.mkpm/.cache.tar.gz' >> $(PROJECT_ROOT)/.gitignore
	@$(CAT) $(PROJECT_ROOT)/.gitignore | $(GREP) -E '^!\/\.mkpm/\.bootstrap\.mk$$' $(NOOUT) && $(TRUE) || \
		$(ECHO) '!/.mkpm/.bootstrap.mk' >> $(PROJECT_ROOT)/.gitignore
	@$(GIT) lfs track '.mkpm/.cache.tar.gz' '.mkpm/.bootstrap.mk' >$(NULL)
endif
ifneq (,$(_COPY_MKPM))
	@$(RM) -rf $(MKPM) $(NOFAIL)
	@$(CP) -r $(PROJECT_ROOT)/$(MKPM_DIR) $(MKPM)
	@$(RM) -rf $(MKPM_TMP) $(NOFAIL)
else
ifeq (1,$(_LOAD_MKPM_FROM_CACHE))
	@$(CD) $(MKPM) && \
		$(TAR) -xzf .cache.tar.gz . || $(call _mkpm_failed)
	@$(ECHO) MKPM: loaded from cache
else
	@$(MKPM_CLI) _install || $(call _mkpm_failed)
endif
endif
	@$(TOUCH) -m "$@"

NODE ?= node
PRETTIER ?= $(call ternary,prettier -v,prettier,$(call ternary,$(PROJECT_ROOT)/node_modules/.bin/prettier -v,$(PROJECT_ROOT)/node_modules/.bin/prettier,$(call ternary,node_modules/.bin/prettier -v,node_modules/.bin/prettier,)))
HELP_GENERATE_TABLE ?= $(NODE) -e 'var a=console.log;a("|command|description|");a("|-|-|");require("fs").readFileSync(0,"utf-8").replace(/\u001b\[\d*?m/g,"").split("\n").map(e=>e.split(/\s+(.+)/).map(e=>e.trim())).map(e=>{var r=e[0];if(e&&r)a("|","`make "+r+"`","|",e.length>1?e[1]:"","|")})'
HELP_PREFIX ?=
HELP_SPACING ?= 32
export MKPM_HELP ?= _mkpm_help
export HELP ?= $(MKPM_HELP)
$(MKPM_HELP):
	@$(CAT) $(CURDIR)/Makefile | \
		$(GREP) -E '^[a-zA-Z0-9][^ 	%*]*:.*##' | \
		$(SORT) | \
		$(AWK) 'BEGIN {FS = ":[^#]*([ 	]+##[ 	]*)?"}; {printf "\033[36m%-$(HELP_SPACING)s  \033[0m%s\n", "$(HELP_PREFIX)"$$1, $$2}' | \
		$(UNIQ)
.PHONY: help-generate-table
help-generate-table:
ifeq (,$(PRETTIER))
	@$(call requires_pkg,prettier,https://prettier.io,npm install -g prettier)
else
ifneq ($(HELP),help-generate-table)
	@$(MAKE) -s $(HELP)
endif
	@$(MKDIR) -p $(MKPM_TMP)
	@$(EXPORT) HELP_TABLE=$(MKPM_TMP)/help-table.md && \
		$(MAKE) -s $(HELP) | \
		$(HELP_GENERATE_TABLE) > $$HELP_TABLE && \
		$(PRETTIER) $$HELP_TABLE
endif

ifeq (,$(.DEFAULT_GOAL))
.DEFAULT_GOAL = $(HELP)
endif
ifeq ($(findstring .mkpm/.bootstrap,$(.DEFAULT_GOAL)),.mkpm/.bootstrap)
.DEFAULT_GOAL = $(HELP)
endif
ifeq ($(findstring .mkpm/.cache,$(.DEFAULT_GOAL)),.mkpm/.cache)
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

.PHONY: mkpm
mkpm: ;

define MKPM_READY
$(wildcard $(MKPM)/.bootstrap)
endef

export GLOBAL_MK := $(wildcard $(PROJECT_ROOT)/global.mk)
export LOCAL_MK := $(wildcard $(CURDIR)/local.mk)
ifneq (,$(MKPM_READY))
ifneq (,$(GLOBAL_MK))
-include $(GLOBAL_MK)
endif
ifneq (,$(LOCAL_MK))
-include $(LOCAL_MK)
endif
endif

$(MKPM_CLI):
	@$(MKDIR) -p $(@D)
	@$(DOWNLOAD) $@ $(MKPM_CLI_URI)
	@$(CHMOD) +x $@

ifneq ($(patsubst %.exe,%,$(SHELL)),$(SHELL))
include cmd.exe
cmd.exe:
	@$(ECHO) cmd.exe not supported 1>&2
	@$(EXIT) 1
endif
