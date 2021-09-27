# File: /bootstrap.mk
# Project: mkpm
# File Created: 26-09-2021 01:25:12
# Author: Clay Risser
# -----
# Last Modified: 27-09-2021 03:05:12
# Modified By: Jam Risser
# -----
# BitSpur Inc (c) Copyright 2021
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

export MKPM_BINARY_VERSION ?= 0.0.1
export MKPM_PACKAGES ?=
export MKPM_PACKAGE_DIR ?= .mkpm
export MKPM_SOURCES ?=

export MKPM := $(abspath $(shell pwd)/$(MKPM_PACKAGE_DIR))
export ROOT := $(patsubst %/,%,$(dir $(abspath $(firstword $(MAKEFILE_LIST)))))
export PLATFORM := unknown
export FLAVOR := unknown
export ARCH := unknown
export BANG := \!
export NULL := /dev/null

ifneq (,$(findstring :,$(PATH))) # POSIX
	PLATFORM = $(shell uname | awk '{print tolower($$0)}')
	ARCH = $(shell (dpkg --print-architecture 2>$(NULL) || uname -m 2>$(NULL) || arch 2>$(NULL) || echo unknown) | awk '{print tolower($$0)}')
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
			ifneq (,$(shell getprop --help >$(NULL) 2>$(NULL))) # ANDROID
				PLATFORM = android
			endif
		endif
		ifeq ($(PLATFORM),linux)
			FLAVOR = $(shell lsb_release -si 2>$(NULL) | awk '{print tolower($$0)}')
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
		endif
		ifneq (,$(findstring MSYS,$(PLATFORM))) # MSYS
			PLATFORM = win32
			FLAVOR = msys
		endif
	endif
else
	ifeq ($(OS),Windows_NT) # WINDOWS
		PLATFORM = win32
		FLAVOR := win64
		SHELL := cmd.exe
		ARCH = $(PROCESSOR_ARCHITECTURE)
		ifeq ($(ARCH),AMD64)
			ARCH = amd64
		endif
		ifeq ($(ARCH),ARM64)
			ARCH = arm64
		endif
		ifeq ($(PROCESSOR_ARCHITECTURE),X86)
			ARCH = x86
			ifeq (,$(PROCESSOR_ARCHITEW6432))
				FLAVOR := win32
			endif
		endif
	endif
endif

export WHICH := command -v

ifeq ($(SHELL),cmd.exe)
	BANG = !
	NULL = nul
	WHICH = where
endif
export NOOUT := >$(NULL) 2>$(NULL)
export NOFAIL := 2>$(NULL) || true

define ternary
$(shell $1 $(NOOUT) && echo $2 || echo $3)
endef

export DOWNLOAD	?= $(call ternary,curl --version,curl -Ls -o,wget -q --content-on-error -O)
export NIX_ENV := $(call ternary,echo $(PATH) | grep -q ":/nix/store",true,false)

ifneq ($(NIX_ENV),true)
	ifeq ($(PLATFORM),darwin)
		export GREP ?= $(call ternary,ggrep --version,ggrep,grep)
		export SED ?= $(call ternary,gsed --version,gsed,sed)
	endif
endif
export GREP ?= grep
export SED ?= sed

export NPROC := 1
ifeq ($(PLATFORM),linux)
	NPROC = $(shell nproc $(NOOUT) && nproc || $(GREP) -c -E "^processor" /proc/cpuinfo 2>$(NULL) || echo 1)
endif
ifeq ($(PLATFORM),darwin)
	NPROC = $(shell sysctl hw.ncpu | awk '{print $$2}' || echo 1)
endif
export NUMPROC ?= $(NPROC)
export MAKEFLAGS += "-j $(NUMPROC)"

ifeq (,$(MKPM_BINARY))
	ifeq ($(call ternary,mkpm -V,true,false),true)
		export MKPM_BINARY := mkpm
	else
		ifeq ($(PLATFORM),linux)
			MKPM_BINARY_DOWNLOAD ?= https://gitlab.com/api/v4/projects/29276259/packages/generic/mkpm/$(MKPM_BINARY_VERSION)/mkpm-$(MKPM_BINARY_VERSION)-$(PLATFORM)-$(ARCH)
		endif
		ifeq ($(PLATFORM),darwin)
			MKPM_BINARY_DOWNLOAD ?= https://gitlab.com/api/v4/projects/29276259/packages/generic/mkpm/$(MKPM_BINARY_VERSION)/mkpm-$(MKPM_BINARY_VERSION)-$(PLATFORM)-$(ARCH)
		endif
		ifeq (,$(MKPM_BINARY_DOWNLOAD))
			export MKPM_BINARY := mkpm
		else
			export MKPM_BINARY = $(MKPM)/.mkpm
		endif
	endif
endif

-include $(MKPM)/.bootstrapping
$(MKPM)/.bootstrapping: $(ROOT)/mkpm.mk
	@echo ⌛ bootstrapping . . .
ifneq (,$(MKPM_BINARY_DOWNLOAD))
	@$(MKPM_BINARY) -V $(NOOUT) && true || ( \
		$(DOWNLOAD) $(MKPM)/.mkpm $(MKPM_BINARY_DOWNLOAD) && \
		chmod +x $(MKPM)/.mkpm \
	)
endif
	@$(MKPM_BINARY) update
	@for p in $(MKPM_PACKAGES); do \
			export PKG="$$(echo $$p | $(SED) 's|=.*$$||g')" && \
			rm -rf "$(MKPM)/.pkgs/$$PKG" $(NOFAIL) && \
			mkdir -p "$(MKPM)/.pkgs/$$PKG" && \
			$(MKPM_BINARY) install $$p --prefix "$(MKPM)/.pkgs/$$PKG" && \
			echo 'include $$(MKPM)'"/.pkgs/$$PKG/main.mk" > "$(MKPM)/$$PKG"; \
		done
	@touch -m $@
