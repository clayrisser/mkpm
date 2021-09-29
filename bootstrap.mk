# File: /bootstrap.mk
# Project: mkpm
# File Created: 26-09-2021 01:25:12
# Author: Clay Risser
# -----
# Last Modified: 29-09-2021 05:47:27
# Modified By: Clay Risser
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
export MKPM_REPOS ?=

export BANG := \!
export CAT := cat
export EXPORT := export
export FALSE := false
export NULL := /dev/null
export RM_RF := rm -rf
export STATUS := $$?
export TRUE := true
export WHICH := command -v
ifeq ($(SHELL),cmd.exe) # CMD SHIM
	BANG = !
	CAT = type
	EXPORT = set
	FALSE = cmd /c "exit /b 1"
	NULL = nul
	RM_RF = rmdir /s /q
	STATUS = %errorlevel%
	TRUE = type nul
	WHICH = where
	export MKPM := $(abspath $(shell echo %cd%)/$(MKPM_PACKAGE_DIR))
define mkdir_p
cmd.exe /v /c "set p=$1 & mkdir !p:/=\! 2>nul || echo >nul"
endef
define touch
if exist $1 ( type nul ) else ( type nul > $1 )
endef
define touch_m
if exist $1 ( \
	$(call mkdir_p,%TEMP%\__mkpm) && \
	type $1 > %TEMP%\__mkpm\touch_m && \
	type %TEMP%\__mkpm\touch_m > $1 && \
	$(RM_RF) %TEMP%\__mkpm\touch_m \
) else ( type nul > $1 )
endef
else
	export MKPM := $(abspath $(shell pwd 2>$(NULL))/$(MKPM_PACKAGE_DIR))
define mkdir_p
mkdir -p $1
endef
define touch_m
touch -m $1
endef
define touch
touch $1
endef
endif
export NOFAIL := 2>$(NULL) || $(TRUE)
export NOOUT := >$(NULL) 2>$(NULL)
export MKPM_TMP := $(MKPM)/.tmp

export PLATFORM := unknown
export FLAVOR := unknown
export ARCH := unknown
ifeq ($(OS),Windows_NT)
	export HOME := $(shell echo %%CD:~0,2%%)/Users/$(USERNAME)
	PLATFORM = win32
	FLAVOR := win64
	ARCH = $(PROCESSOR_ARCHITECTURE)
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
	PLATFORM = $(shell uname 2>$(NULL) | awk '{print tolower($$0)}' 2>$(NULL))
	ARCH = $(shell (dpkg --print-architecture 2>$(NULL) || uname -m 2>$(NULL) || arch 2>$(NULL) || echo unknown) | awk '{print tolower($$0)}' 2>$(NULL))
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
			ifneq (,$(shell getprop --help >$(NULL) 2>$(NULL))) # TODO: finish this ANDROID
				PLATFORM = android
			endif
		endif
		ifeq ($(PLATFORM),linux)
			FLAVOR = $(shell lsb_release -si 2>$(NULL) | awk '{print tolower($$0)}' 2>$(NULL))
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
endif

ifeq ($(SHELL),cmd.exe)
define for
for %%$1 in ($2) do (
endef
define rof
)
endef
else
define for
for $1 in $2; do 
endef
define rof
; done
endef
endif

define ternary
$(shell $1 $(NOOUT) && echo $2 || echo $3)
endef

ifeq ($(SHELL),cmd.exe)
define join_path # TODO: improve cmd support for join_path
$(shell echo $2)
endef
else
define join_path
$(shell [ "$$(expr substr "$2" 1 1)" = "/" ] && true || (echo $1 | $(SED) 's|\/$$||g'))$(shell [ "$$(expr substr "$2" 1 1)" = "/" ] && true || echo "/")$(shell [ "$2" = "" ] && true || echo "$2")
endef
endif

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

export MKPM_GIT_CLEAN_FLAGS := $(call git_clean_flags,$(MKPM_PACKAGE_DIR))

export DOWNLOAD	?= $(call ternary,curl --version,curl -L -o,wget --content-on-error -O)
export NIX_ENV := $(call ternary,echo $(PATH) | grep -q ":/nix/store",true,false)

export ROOT := $(patsubst %/,%,$(dir $(abspath $(firstword $(MAKEFILE_LIST)))))
ifeq ($(SHELL),cmd.exe) # TODO: add cmd support for PROJECT_ROOT
export PROJECT_ROOT ?= $(ROOT)
else
export PROJECT_ROOT ?= $(shell \
	project_root() { \
		root=$$1 && \
		if [ -f "$$root/mkpm.mk" ]; then \
			echo $$root && \
			return 0; \
		fi && \
		parent=$$(echo $$root | $(SED) 's|\/[^\/]\+$$||g') && \
		if ([ "$$parent" = "" ] || [ "$$parent" = "/" ]); then \
			echo "/" && \
			return 0; \
		fi && \
		echo $$(project_root $$parent) && \
		return 0; \
	} && \
	echo $$(project_root $(ROOT)) \
)
endif

ifneq ($(NIX_ENV),true)
	ifeq ($(PLATFORM),darwin)
		export FIND ?= $(call ternary,gfind --version,gfind,find)
		export GREP ?= $(call ternary,ggrep --version,ggrep,grep)
		export SED ?= $(call ternary,gsed --version,gsed,sed)
	endif
endif
ifeq ($(PLATFORM),win32)
SED_DOWNLOAD ?= https://bitbucket.org/xoviat/chocolatey-packages/raw/4ce05f43ec7fcb21be34221c79198df3aae81f54/sed/4.8/tools/install/sed-windows-master/sed-4.8-x64.exe
SED_BINARY := $(HOME)/.mkpm/bin/sed
export SED ?= $(SED_BINARY)
GREP_DOWNLOAD ?= https://bitbucket.org/xoviat/chocolatey-packages/raw/4ce05f43ec7fcb21be34221c79198df3aae81f54/grep/2.10.05082020/tools/install/bin/grep.exe
GREP_BINARY := $(HOME)/.mkpm/bin/grep
export GREP ?= $(GREP_BINARY)
endif
export FIND ?= find
export GREP ?= grep
export SED ?= sed

export NPROC := 1
ifeq ($(PLATFORM),linux)
	NPROC = $(shell nproc $(NOOUT) && nproc || $(GREP) -c -E "^processor" /proc/cpuinfo 2>$(NULL) || echo 1)
endif
ifeq ($(PLATFORM),darwin)
	NPROC = $(shell sysctl hw.ncpu | awk '{print $$2}' 2>$(NULL) || echo 1)
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
		ifneq (,$(MKPM_BINARY_DOWNLOAD))
			HOME_MKPM_BINARY := $(HOME)/.mkpm/bin/mkpm
			export MKPM_BINARY := $(HOME_MKPM_BINARY)
		endif
		ifeq ($(PLATFORM),win32)
			MKPM_BINARY_DOWNLOAD ?= https://gitlab.com/api/v4/projects/29276259/packages/generic/mkpm/$(MKPM_BINARY_VERSION)/mkpm-$(MKPM_BINARY_VERSION)-$(PLATFORM)-$(ARCH).exe
			HOME_MKPM_BINARY := $(HOME)/.mkpm/bin/mkpm.exe
			export MKPM_BINARY := $(HOME_MKPM_BINARY)
		endif
		ifeq (,$(MKPM_BINARY_DOWNLOAD))
			export MKPM_BINARY := mkpm
		endif
	endif
endif

include $(MKPM)/.bootstrap
$(MKPM)/.bootstrap: $(call join_path,$(PROJECT_ROOT),mkpm.mk)
ifeq ($(SHELL),cmd.exe)
	@echo.
	@echo                     88
	@echo                     88
	@echo                     88
	@echo 88,dPYba,,adPYba,   88   ,d8   8b,dPPYba,   88,dPYba,,adPYba,
	@echo 88P'   "88"    "8a  88 ,a8"    88P'    "8a  88P'   "88"    "8a
	@echo 88      88      88  8888[      88       d8  88      88      88
	@echo 88      88      88  88`"Yba,   88b,   ,a8"  88      88      88
	@echo 88      88      88  88   `Y8a  88`YbbdP"'   88      88      88
	@echo                                88
	@echo                                88
	@echo.
	@echo BitSpur Inc (c) Copyright 2021
	@echo.
else
	@echo
	@echo '                    88'
	@echo '                    88'
	@echo '                    88'
	@echo '88,dPYba,,adPYba,   88   ,d8   8b,dPPYba,   88,dPYba,,adPYba,'
	@echo "88P'   "'"88"    "8a  88 ,a8"    88P'"'    "'"8a  88P'"'   "'"88"    "8a'
	@echo '88      88      88  8888[      88       d8  88      88      88'
	@echo '88      88      88  88`"Yba,   88b,   ,a8"  88      88      88'
	@echo '88      88      88  88   `Y8a  88`YbbdP"'"'   88      88      88"
	@echo '                               88'
	@echo '                               88'
	@echo
	@echo 'BitSpur Inc (c) Copyright 2021'
	@echo
endif
	@$(call mkdir_p,$(HOME)/.mkpm/bin)
	@$(call touch,$(HOME)/.mkpm/repos.list)
# TODO: fix grep
# ifneq (,$(GREP_BINARY))
# 	@$(GREP) --version $(NOOUT) || ( \
# 		$(DOWNLOAD) $(GREP_BINARY) $(GREP_DOWNLOAD) && \
# 		chmod +x $(GREP_BINARY) $(NOFAIL) \
# 	)
# endif
ifneq (,$(SED_BINARY))
	@$(SED) --version $(NOOUT) || ( \
		$(DOWNLOAD) $(SED_BINARY) $(SED_DOWNLOAD) && \
		chmod +x $(SED_BINARY) $(NOFAIL) \
	)
endif
ifneq (,$(HOME_MKPM_BINARY))
	@$(MKPM_BINARY) -V $(NOOUT) || ( \
		$(DOWNLOAD) $(HOME_MKPM_BINARY) $(MKPM_BINARY_DOWNLOAD) && \
		chmod +x $(HOME_MKPM_BINARY) $(NOFAIL) \
	)
endif
ifneq (,$(MKPM_REPOS))
	@$(MKPM_BINARY) update
endif
ifneq (,$(MKPM_PACKAGES))
ifeq ($(SHELL),cmd.exe)
	@$(call for,p,$(MKPM_PACKAGES)) \
			echo %%p \
		$(call rof)
else
	@$(call for,p,$(MKPM_PACKAGES)) \
			$(EXPORT) PKG="$$(echo $$p | $(SED) 's|=.*$$||g')" && \
			$(RM_RF) "$(MKPM)/.pkgs/$$PKG" $(NOFAIL) && \
			$(call mkdir_p,"$(MKPM)/.pkgs/$$PKG") && \
			$(MKPM_BINARY) install $$p --prefix "$(MKPM)/.pkgs/$$PKG" && \
			echo 'include $$(MKPM)'"/.pkgs/$$PKG/main.mk" > "$(MKPM)/$$PKG" && \
			echo '.PHONY: hello-%' > "$(MKPM)/-$$PKG" && \
			echo 'hello-%:' >> "$(MKPM)/-$$PKG" && \
			echo '	@$$(MAKE) -s -f $$(MKPM)/.pkgs/hello/main.mk $$$$(echo $$@ | $$(SED) '"'s|^hello-||g')" >> "$(MKPM)/-$$PKG" \
		$(call rof)
endif
endif
	@$(call touch_m,$@)
