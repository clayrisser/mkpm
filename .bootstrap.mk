# File: /.bootstrap.mk
# Project: mkpm
# File Created: 04-12-2021 02:15:12
# Author: Clay Risser
# -----
# Last Modified: 28-07-2023 05:41:44
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

export MKPM_BOOTSTRAP_VERSION := 0.3.0
export EXPECTED_MKPM_CLI_VERSION := 0.3.0
export MKPM_DIR := .mkpm
export MKPM_CLI_URI := \
	https://gitlab.com/api/v4/projects/29276259/packages/generic/mkpm/$(EXPECTED_MKPM_CLI_VERSION)/mkpm.sh

export LC_ALL=C
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
export DU := du
export ECHO := echo
export EXIT := exit
export EXPORT := export
export FALSE := false
export HEAD := head
export MKDIR := mkdir
export RM := rm
export SORT := sort
export TOUCH := touch
export TR := tr
export TRUE := true
export UNIQ := uniq
export WHICH := command -v





export MKPM_GIT_CLEAN_FLAGS := $(call git_clean_flags,$(MKPM_DIR))
export MKPM_CLEANED := $(MKPM)/.cleaned
define MKPM_CLEAN
$(TOUCH) -m $(MKPM)/.cleaned
endef







i

define _mkpm_failed
($(TOUCH) $(MKPM)/.failed && $(EXIT) 1)
endef

define requires_pkg
$(ECHO) "$(YELLOW)"'the package $1 is required'"$(NOCOLOR)" && \
	$(ECHO) && \
	$(ECHO) "you can get \033[1m$1\033[0m at \033[3m$2\033[0m" && \
	$(ECHO) && \
	$(ECHO) or you can try to install $1 with the following command && \
	$(ECHO) && \
	([ "$3" != "" ] && $(call echo_command,$3) || $(call echo_command,$(call pkg_manager_install,$1))) && \
	$(ECHO) && \
	$(call _mkpm_failed)
endef

ifneq ($(PROJECT_ROOT),$(CURDIR))
ifneq (,$(wildcard $(PROJECT_ROOT)/$(MKPM_DIR)/.bootstrap))
_COPY_MKPM := 1
endif
endif

include $(MKPM)/.a
include $(MKPM)/.z
ifeq ($(INCLUDE_ORDER),ASC)
ifneq ($(TRUE),$(TAR))
-include $(MKPM)/.cache
endif
include $(MKPM)/.preflight
-include $(MKPM)/.bootstrap
include $(MKPM)/.ready
endif
ifeq ($(INCLUDE_ORDER),DESC)
include $(MKPM)/.ready
-include $(MKPM)/.bootstrap
include $(MKPM)/.preflight
ifneq ($(TRUE),$(TAR))
-include $(MKPM)/.cache
endif
endif
$(MKPM)/.a:
	@$(MKDIR) -p $(MKPM)
	@[ -f $(MKPM)/.a ] || $(ECHO) 'export INCLUDE_ORDER ?= ASC' > $@
$(MKPM)/.z:
	@$(MKDIR) -p $(MKPM)
	@[ -f $(MKPM)/.a ] || $(ECHO) 'export INCLUDE_ORDER ?= DESC' > $(MKPM)/.a
	@$(TOUCH) $@

ifneq ($(TRUE),$(TAR))
$(MKPM)/.cache: $(PROJECT_ROOT)/mkpm.mk
	@$(MKDIR) -p $(MKPM)
	@([ -f $(MKPM)/.cache ] && [ "$(_LOAD_MKPM_FROM_CACHE)" = "" ]) && $(RM) -rf $(MKPM)/.cache.tar.gz || $(TRUE)
	@$(ECHO) 'ifneq (,$$(wildcard $$(MKPM)/.cache.tar.gz))' > $(MKPM)/.cache
	@$(ECHO) 'ifeq (0,$$(shell $(DU) -k $$(MKPM)/.cache.tar.gz | $(CUT) -f1))' >> $(MKPM)/.cache
	@$(ECHO) 'export _LOAD_MKPM_FROM_CACHE := 0' >> $(MKPM)/.cache
	@$(ECHO) 'else' >> $(MKPM)/.cache
	@$(ECHO) 'export _LOAD_MKPM_FROM_CACHE := 1' >> $(MKPM)/.cache
	@$(ECHO) 'endif' >> $(MKPM)/.cache
	@$(ECHO) 'else' >> $(MKPM)/.cache
	@$(ECHO) 'export _LOAD_MKPM_FROM_CACHE := 0' >> $(MKPM)/.cache
	@$(ECHO) 'endif' >> $(MKPM)/.cache
endif

$(MKPM)/.bootstrap: $(PROJECT_ROOT)/mkpm.mk $(MKPM_CLI)
	@$(RM) -f $(MKPM)/.failed
	@[ ! -f $(MKPM)/.preflight ] && $(EXIT) 1 || $(TRUE)
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
	@$(ECHO) 'Risser Labs LLC (c) Copyright 2021 - 2022'
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
		$(TAR) -xzf .cache.tar.gz || $(call _mkpm_failed)
	@$(ECHO) MKPM: loaded from cache
else
	@$(MKPM_CLI) _install || $(call _mkpm_failed)
endif
endif
	@$(TOUCH) -m "$@"

$(MKPM)/.ready:
	@[ -f $(MKPM)/.failed ] && $(EXIT) 1 || $(TRUE)
	@[ -f $(MKPM)/.preflight ] && $(TOUCH) -m "$@" || $(EXIT) 1

NODE ?= node
PRETTIER ?= $(call ternary,node_modules/.bin/prettier -v,node_modules/.bin/prettier,$(call ternary,$(PROJECT_ROOT)/node_modules/.bin/prettier -v,$(PROJECT_ROOT)/node_modules/.bin/prettier,$(call ternary,prettier -v,prettier,)))
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

.PHONY: mkpm
mkpm: ;

define MKPM_READY
$(shell ([ -f $(MKPM)/.preflight ] && \
	[ -f $(MKPM)/.ready ] && \
	[ -f $(MKPM)/.bootstrap ]) && \
	$(ECHO) 1 || $(TRUE))
endef

$(MKPM_CLI):
	@$(MKDIR) -p $(@D)
	@[ ! -f $(MKPM)/.cache.tar.gz ] && \
		([ -f $(PROJECT_ROOT)/$(MKPM_DIR)/.bin/mkpm ] && \
			$(CP) $(PROJECT_ROOT)/$(MKPM_DIR)/.bin/mkpm $@ || \
			($(DOWNLOAD) $@ $(MKPM_CLI_URI) && $(CHMOD) +x $@)) || $(TRUE)

ifneq ($(patsubst %.exe,%,$(SHELL)),$(SHELL))
include cmd.exe
cmd.exe:
	@$(ECHO) cmd.exe not supported 1>&2
	@$(ECHO) if you are on Windows, please use WSL (Windows Subsystem for Linux) 1>&2
	@$(ECHO) https://docs.microsoft.com/windows/wsl
	@$(EXIT) 1
endif
