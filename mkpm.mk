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

ifneq ($(NIX_ENV),true)
	ifeq ($(PLATFORM),darwin)
		export FIND ?= $(call ternary,gfind --version,gfind,find)
		export GREP ?= $(call ternary,ggrep --version,ggrep,grep)
		export SED ?= $(call ternary,gsed --version,gsed,sed)
	endif
endif

export GIT ?= $(call ternary,git --version,git,true)
export AWK ?= awk
export GREP ?= grep
export JQ ?= jq
export READLINE ?= readline
export SED ?= sed
export TAR ?= tar
export TIME ?= time

# SHELL
export CD ?= cd
export DO ?= do
export DONE ?= done
export EVAL := eval
export FI ?= fi
export EXIT := exit
export FOR ?= for
export IF ?= if
export READ ?= read
export THEN ?= then
export WHICH := command -v
export WHILE ?= while

# COREUTILS
export BASENAME ?= basename
export CAT ?= cat
export CHMOD ?= chmod
export CHOWN ?= chown
export CHROOT ?= chroot
export COMM ?= comm
export CP ?= cp
export CUT ?= cut
export DATE ?= date
export DD ?= dd
export DF ?= df
export DIRNAME ?= dirname
export DU ?= du
export ECHO ?= echo
export ENV ?= env
export EXPAND ?= expand
export FALSE ?= false
export FMT ?= fmt
export FOLD ?= fold
export GROUPS ?= groups
export HEAD ?= head
export HOSTNAME ?= hostname
export ID ?= id
export JOIN ?= join
export LN ?= ln
export LS ?= ls
export MD5SUM ?= md5sum
export MKDIR ?= mkdir
export MV ?= mv
export NICE ?= nice
export PASTE ?= paste
export PR ?= pr
export PRINTF ?= printf
export PWD ?= pwd
export RM ?= rm
export RMDIR ?= rmdir
export SEQ ?= seq
export SLEEP ?= sleep
export SORT ?= sort
export SPLIT ?= split
export SU ?= su
export TAIL ?= tail
export TEE ?= tee
export TEST ?= test
export TOUCH ?= touch
export TR ?= tr
export TRUE ?= true
export UNAME ?= uname
export UNEXPAND ?= unexpand
export UNIQ ?= uniq
export WC ?= wc
export WHO ?= who
export WHOAMI ?= whoami
export YES ?= yes

# FINDUTILS
export FIND ?= find
export LOCATE ?= locate
export UPDATEDB ?= updatedb
export XARGS ?= xargs

# PROCPS
export KILL ?= kill
export PS ?= ps
export TOP ?= top

# INFOZIP
export ZIP ?= zip
export UNZIP ?= unzip

# COMPOSITIONS
export BANG := \!
export NULL := /dev/null
export NOFAIL := 2>$(NULL) || $(TRUE)
export NOOUT := >$(NULL) 2>&1

define make
$(shell C="$$([ "$1" = "" ] && $(TRUE) || $(ECHO) "C \"$1\"")" && \
	[ -f "$(CURDIR)/$$($(EVAL) $(ECHO) $$($(ECHO) $$C | $(CUT) -d' ' -f2))/Mkpmfile" ] && \
	$(ECHO) $(MAKE) -s$$C -f Mkpmfile || $(ECHO) $(MAKE) -s$$C)
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

define system_package_install
export _SYSTEM_PACKAGE_INSTALL_COMMAND="$1"; \
export _SYSTEM_BINARY="$2"; \
export _SYSTEM_PACKAGE_NAME="$$([ "$3" = "" ] && $(ECHO) "$3" || $(ECHO) "$2")"; \
$(ECHO) "$(C_RED)MKPM [E]:$(C_END) $$_SYSTEM_BINARY is not installed on your system" 1>&2; \
$(PRINTF) "you can install $$_SYSTEM_BINARY on $(FLAVOR) with the following command \
\n\n    $(C_GREEN)$$_SYSTEM_PACKAGE_INSTALL_COMMAND$(C_END) \
\n\ninstall for me [$(C_GREEN)Y$(C_END)|$(C_RED)n$(C_END)]: "; \
$(READ) _RES; \
if [ "$$($(ECHO) "$$_RES" | $(CUT) -c 1 | $(TR) '[:lower:]' '[:upper:]')" != "N" ]; then \
	$(EVAL) $$_SYSTEM_PACKAGE_INSTALL_COMMAND; \
else
	$(EXIT) 1; \
fi
endef

.PHONY: _mkpm_cleanup
_mkpm_cleanup:
	@true $(MKPM_CLEANUP)

.PHONY: force __force
force: __force
__force: ;
