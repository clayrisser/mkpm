# File: /bootstrap.mk
# Project: mkpm
# File Created: 04-12-2021 02:15:12
# Author: Clay Risser
# -----
# Last Modified: 24-05-2022 11:29:01
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

export MKPM_BOOTSTRAP_VERSION := 0.1.0
export MKPM_BINARY_VERSION := 0.0.2
export MKPM_DIR := .mkpm
export MKPM_PACKAGES ?=
export MKPM_REPOS ?=
export MKPM := $(abspath $(CURDIR)/$(MKPM_DIR))

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

export AWK ?= awk
export CUT ?= cut
export SORT ?= sort
export TR ?= tr
export UNIQ ?= uniq

export BANG := \!
export CD := cd
export CP_R := cp -r
export ECHO := echo
export EXIT := exit
export EXPORT := export
export FALSE := false
export MAKESHELL ?= $(SHELL)
export NULL := /dev/null
export RM_RF := rm -rf
export STATUS := $$?
export TRUE := true
export WHICH := command -v
ifneq ($(patsubst %.exe,%,$(SHELL)),$(SHELL)) # CMD SHIM
	export .SHELLFLAGS = /q /v /c
	BANG = !
	CP_R = xcopy /e /k /h /i
	EXPORT = set
	FALSE = cmd /c "exit /b 1"
	NULL = nul
	STATUS = %errorlevel%
	TRUE = type nul
	WHICH = where
define cat
cmd.exe /q /v /c "set p=$1 & type !p:/=\!"
endef
define rm_rf
cmd.exe /q /v /c "rmdir /s /q $1 2>nul || set p=$1 & del !p:/=\! 2>nul || echo >nul"
endef
define mkdir_p
cmd.exe /q /v /c "set p=$1 & mkdir !p:/=\! 2>nul || echo >nul"
endef
define mv
cmd.exe /q /v /c "set a=$1 & set b=$2 & move !a:/=\! !b:/=\! >/nul"
endef
define mv_f
cmd.exe /q /v /c "set a=$1 & set b=$2 & move /y !a:/=\! !b:/=\! >/nul"
endef
define touch
if exist $1 ( type nul ) else ( type nul > $1 )
endef
define touch_m
if exist $1 ( \
	$(call mkdir_p,"%TEMP%\__mkpm") && \
	$(call cat,$1) > "%TEMP%\__mkpm\touch_m" && \
	$(call cat,"%TEMP%\__mkpm\touch_m") > $1 && \
	$(call rm_rf,%TEMP%\__mkpm\touch_m) \
) else ( type nul > $1 )
endef
else
define cat
cat $1
endef
define rm_rf
rm -rf $1
endef
define mkdir_p
mkdir -p $1
endef
define touch_m
touch -m $1
endef
define mv
mv $1 $2
endef
define mv_f
mv -f $1 $2
endef
define touch
touch $1
endef
endif
export NOFAIL := 2>$(NULL) || $(TRUE)
export NOOUT := >$(NULL) 2>$(NULL)
export MKPM_TMP := $(MKPM)/.tmp

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
				ifeq ($(shell cat /etc/os-release 2>$(NULL) | grep -qE "^ID=alpine$$"),ID=alpine)
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

ifneq ($(patsubst %.exe,%,$(SHELL)),$(SHELL))
define for
(for %%$1 in ($2) do (
endef
define for_i
%%$1
endef
define for_end
))
endef
else
define for
for $1 in $2; do
endef
define for_i
$$$1
endef
define for_end
; done
endef
endif

define ternary
$(shell $1 $(NOOUT) && $(ECHO) $2|| $(ECHO) $3)
endef

ifeq ($(PKG_MANAGER),unknown)
	PKG_MANAGER = $(call ternary,apt-get,apt-get,$(call ternary,apk,apk,$(call ternary,yum,yum,$(call ternary,brew,brew,unknown))))
endif

ifneq ($(patsubst %.exe,%,$(SHELL)),$(SHELL))
define join_path
$(shell cmd.exe /q /v /c " \
	(if "$1"=="" ( \
		set "one=/" \
	) else ( \
		set "one=$1" \
	)) && \
	(if "$2"=="" ( \
		set "two=!one!" \
	) else ( \
		set "two=$2" \
	)) && \
	set "one=!one: =!" && \
	set "two=!two: =!" && \
	set "one=!one:\=/!" && \
	set "two=!two:\=/!" && \
	(if "!one:~-1!"=="/" ( \
		(if "!one!"!==!"/" ( \
			set "one=!one:~0,-1!" \
		)) \
	)) && \
	(if "!one:~0,1!"=="/" ( \
		set "one=C:!one!" \
	)) && \
	(if "!two:~0,1!"=="/" ( \
		echo C:!two! \
	) else ( \
		(if "!two:~1,2!"==":/" ( \
			echo !two! \
		) else ( \
			(if "!one:~-1!"=="/" ( \
				echo !one!!two! \
			) else ( \
				echo !one!/!two! \
			)) \
		)) \
	)) \
")
endef
else
define join_path
$(shell [ "$$(echo "$2" | $(CUT) -c 1-1)" = "/" ] && true || \
	(echo $1 | $(SED) 's|\/$$||g'))$(shell \
	[ "$$(echo "$2" | $(CUT) -c 1-1)" = "/" ] && true || echo "/")$(shell \
	[ "$2" = "" ] && true || echo "$2")
endef
endif

export COLUMNS := 0
ifeq ($(patsubst %.exe,%,$(SHELL)),$(SHELL))
	COLUMNS = $(shell tput cols 2>$(NULL) || (eval $(resize 2>$(NULL)) 2>$(NULL) && echo $$COLUMNS))
define columns
$(call ternary,[ "$(COLUMNS)" -$1 "$2" ],1)
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

export MKPM_GIT_CLEAN_FLAGS := $(call git_clean_flags,$(MKPM_DIR))
export MKPM_CLEANED := $(MKPM)/.cleaned
define MKPM_CLEAN
$(call touch_m,$(MKPM)/.cleaned)
endef

ifneq ($(patsubst %.exe,%,$(SHELL)),$(SHELL))
	export NIX_ENV :=
else
	export NIX_ENV := $(call ternary,echo '$(PATH)' | grep -q ":/nix/store",1)
endif
export DOWNLOAD	?= $(call ternary,curl --version,curl -L -o,wget -O)

ifneq ($(NIX_ENV),1)
	ifeq ($(PLATFORM),darwin)
		export GREP ?= $(call ternary,ggrep --version,ggrep,grep)
		export SED ?= $(call ternary,gsed --version,gsed,sed)
	endif
endif
export GREP ?= grep
export SED ?= sed
export GIT ?= git
export TAR ?= $(call ternary,$(WHICH) tar,$(shell $(WHICH) tar 2>$(NULL)),$(TRUE))

export ROOT ?= $(patsubst %/,%,$(dir $(abspath $(firstword $(MAKEFILE_LIST)))))
ifneq ($(patsubst %.exe,%,$(SHELL)),$(SHELL))
export PROJECT_ROOT ?= $(strip $(shell cmd.exe /q /v /c " \
	set "paths=$(shell cmd.exe /q /v /c " \
		set "root=$(ROOT)" && \
		set "root=!root:/= !" && \
		set "p= " && \
		set "paths= " && \
		(for %%i in (!root!) do ( \
			(if "!p!"==" " ( \
				set "p=%%i" \
			) else ( \
				set "p=!p!/%%i" \
			)) && \
			(if "!paths!"==" " ( \
				set "paths=!p!" \
			) else ( \
				set "paths=!p! !paths!" \
			)) \
		)) && \
		echo !paths! \
	")" && \
	set "root=/" && \
	(for %%j in (!paths!) do set "root=%%j") && \
	(for %%i in (!paths!) do ( \
		(if exist %%i/mkpm.mk ( \
			set "root=%%i" \
		)) \
	)) && \
	echo !root! \
"))
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
	NPROC = $(shell nproc $(NOOUT) && nproc || $(GREP) -c -E "^processor" /proc/cpuinfo 2>$(NULL) || echo 1)
endif
ifeq ($(PLATFORM),darwin)
	NPROC = $(shell sysctl hw.ncpu | $(CUT) -d " " -f 2 2>$(NULL) || echo 1)
endif
export NUMPROC ?= $(NPROC)
export MAKEFLAGS += "-j $(NUMPROC)"

ifeq (,$(MKPM_BINARY))
	ifneq ($(call ternary,mkpm -V,1),1)
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
			HOME_MKPM_BINARY := $(HOME)\.mkpm\bin\mkpm.exe
			export MKPM_BINARY := $(HOME_MKPM_BINARY)
		endif
	endif
endif
export MKPM_BINARY ?= mkpm

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

ifneq ($(patsubst %.exe,%,$(SHELL)),$(SHELL))
define requires_pkg
echo.
endef
else
define requires_pkg
echo "$(YELLOW)"'the package $1 is required'"$(NOCOLOR)" && \
	echo && \
	echo "you can get \e[1m$1\e[0m at $2" && \
	echo && \
	echo or you can try to install $1 with the following command && \
	echo && \
	([ "$3" != "" ] && echo "$(GREEN)    $3$(NOCOLOR)" || echo "$(GREEN)    $(call pkg_manager_install,$1)$(NOCOLOR)") && \
	echo && \
	$(EXIT) 9009
endef
endif

ifneq ($(PROJECT_ROOT),$(CURDIR))
ifneq (,$(wildcard $(PROJECT_ROOT)/$(MKPM_DIR)/.bootstrap))
_COPY_MKPM := 1
endif
endif
ifeq ($(patsubst %.exe,%,$(SHELL)),$(SHELL))
ifneq ($(TRUE),$(TAR))
MKPM_CACHE_SUPPORTED := 1
endif
endif
-include $(MKPM)/.bootstrap
ifeq ($(patsubst %.exe,%,$(SHELL)),$(SHELL))
ifneq ($(TRUE),$(TAR))
-include $(MKPM)/.cache
$(MKPM)/.cache: $(call join_path,$(PROJECT_ROOT),mkpm.mk)
	@$(call mkdir_p,$(MKPM))
	@[ -f $(MKPM)/.cache ] && $(call rm_rf,$(call join_path,$(MKPM),.cache.tar.gz)) || true
	@echo 'ifneq (,$$(wildcard $$(MKPM)/.cache.tar.gz))' > $(MKPM)/.cache
	@echo 'export _LOAD_MKPM_FROM_CACHE := 1' >> $(MKPM)/.cache
	@echo 'else' >> $(MKPM)/.cache
	@echo 'export _LOAD_MKPM_FROM_CACHE := 0' >> $(MKPM)/.cache
	@echo 'endif' >> $(MKPM)/.cache
endif
endif
$(MKPM)/.bootstrap: $(call join_path,$(PROJECT_ROOT),mkpm.mk)
ifeq ($(patsubst %.exe,%,$(SHELL)),$(SHELL))
ifeq ($(CURDIR),$(PROJECT_ROOT))
	@$(call cat,$(PROJECT_ROOT)/.gitignore) | $(GREP) -E '^\.mkpm/$$' $(NOOUT) && \
		$(SED) -i '/^\.mkpm\/$$/d' $(PROJECT_ROOT)/.gitignore || \
		$(TRUE)
	@$(call cat,$(PROJECT_ROOT)/.gitignore) | $(GREP) -E '^\.mkpm/\*$$' $(NOOUT) && $(TRUE) || \
		$(ECHO) '.mkpm/*' >> $(PROJECT_ROOT)/.gitignore
	@$(call cat,$(PROJECT_ROOT)/.gitignore) | $(GREP) -E '^\*\*\/\.mkpm/\*$$' $(NOOUT) && $(TRUE) || \
		$(ECHO) '**/.mkpm/*' >> $(PROJECT_ROOT)/.gitignore
endif
endif
ifeq (1,$(MKPM_CACHE_SUPPORTED))
ifeq ($(patsubst %.exe,%,$(SHELL)),$(SHELL))
ifeq (1,$(_LOAD_MKPM_FROM_CACHE))
	@[ ! -f $(MKPM)/.cache.tar.gz ] && exit 1 || true
endif
	@if [ $(MKPM)/.cache -nt $(MKPM)/.cache.tar.gz ]; then \
		$(call touch_m,$(MKPM)/.cache.tar.gz) && \
		exit 1; \
	fi
ifeq ($(CURDIR),$(PROJECT_ROOT))
	@$(GIT) lfs track '.mkpm/.cache.tar.gz' '.mkpm/.bootstrap.mk' >$(NULL)
	@$(call cat,$(PROJECT_ROOT)/.gitignore) | $(GREP) -E '^!\/\.mkpm/\.cache\.tar\.gz$$' $(NOOUT) && $(TRUE) || \
		$(ECHO) '!/.mkpm/.cache.tar.gz' >> $(PROJECT_ROOT)/.gitignore
	@$(call cat,$(PROJECT_ROOT)/.gitignore) | $(GREP) -E '^!\/\.mkpm/\.bootstrap\.mk$$' $(NOOUT) && $(TRUE) || \
		$(ECHO) '!/.mkpm/.bootstrap.mk' >> $(PROJECT_ROOT)/.gitignore
endif
else
	@$(ECHO) caching not supported on windows 1>&2
	@exit 1
endif
endif
ifeq ($(MAKELEVEL),0)
ifeq ($(call columns,lt,62),1)
ifneq ($(patsubst %.exe,%,$(SHELL)),$(SHELL))
	@echo.
	@echo MKPM
	@echo.
	@echo Risser Labs LLC (c) Copyright 2022
	@echo.
else
	@echo
	@echo "$(LIGHTBLUE)MKPM$(NOCOLOR)"
	@echo
	@echo 'Risser Labs LLC (c) Copyright 2022'
	@echo
endif
else
ifneq ($(patsubst %.exe,%,$(SHELL)),$(SHELL))
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
	@echo Risser Labs LLC (c) Copyright 2022
	@echo.
else
	@echo
	@echo "$(LIGHTBLUE)"'                    88'
	@echo '                    88'
	@echo '                    88'
	@echo '88,dPYba,,adPYba,   88   ,d8   8b,dPPYba,   88,dPYba,,adPYba,'
	@echo "88P'   "'"88"    "8a  88 ,a8"    88P'"'    "'"8a  88P'"'   "'"88"    "8a'
	@echo '88      88      88  8888[      88       d8  88      88      88'
	@echo '88      88      88  88`"Yba,   88b,   ,a8"  88      88      88'
	@echo '88      88      88  88   `Y8a  88`YbbdP"'"'   88      88      88"
	@echo '                               88'
	@echo '                               88'"$(NOCOLOR)"
	@echo
	@echo 'Risser Labs LLC (c) Copyright 2022'
	@echo
endif
endif
endif
ifneq ($(call ternary,git --version,1),1)
	@$(call requires_pkg,git,https://git-scm.com)
endif
ifneq ($(call ternary,git lfs --version,1),1)
	@$(call requires_pkg,git-lfs,https://git-lfs.github.com)
endif
	@$(call mkdir_p,$(HOME)/.mkpm/bin)
	@$(call touch,$(HOME)/.mkpm/sources.list)
	@$(call mv_f,$(HOME)/.mkpm/sources.list.backup,$(HOME)/.mkpm/sources.list) $(NOFAIL)
ifneq (,$(MKPM_BINARY_DOWNLOAD))
	@$(MKPM_BINARY) -V $(NOOUT) || ( \
		$(DOWNLOAD) $(MKPM_BINARY) $(MKPM_BINARY_DOWNLOAD) && \
		chmod +x $(MKPM_BINARY) $(NOFAIL) \
	)
endif
# TODO: add lock here
ifneq (1,$(_LOAD_MKPM_FROM_CACHE))
ifneq (,$(MKPM_REPOS))
ifeq (,$(_COPY_MKPM))
	@$(call cat,$(HOME)/.mkpm/sources.list) > $(HOME)/.mkpm/sources.list.backup
	@$(call for,i,$(MKPM_REPOS)) \
			$(ECHO) $(call for_i,i) >> $(HOME)/.mkpm/sources.list \
		$(call for_end)
	@$(ECHO) MKPM: updating mkpm repos
	@$(CD) $(PROJECT_ROOT) && $(MKPM_BINARY) update 1>$(NULL)
endif
endif
endif
ifneq (,$(MKPM_PACKAGES))
ifneq (,$(_COPY_MKPM))
	@$(call rm_rf,$(MKPM)) $(NOFAIL)
	@$(CP_R) $(PROJECT_ROOT)/$(MKPM_DIR) $(MKPM)
	@$(call rm_rf,$(MKPM_TMP)) $(NOFAIL)
else
ifneq ($(patsubst %.exe,%,$(SHELL)),$(SHELL))
	@cd $(PROJECT_ROOT) && $(call for,i,$(subst =,:,$(MKPM_PACKAGES))) \
			cmd.exe /q /v /c " \
				set "pkg=$(call for_i,i)" && \
				set "pkgname=!pkg::= !" && \
				set "pkg=!pkg::==!" && \
				(for /f "usebackq tokens=1" %%j in (`echo !pkgname!`) do ( \
					set "pkgname=%%j" && \
					set "pkgpath="$(MKPM)/.pkgs/!pkgname!"" && \
					(rmdir /s /q !pkgpath! 2>nul || echo 1>nul) && \
					mkdir !pkgpath:/=\! 2>nul && \
					echo MKPM: installing !pkg! && \
					$(MKPM_BINARY) install !pkg! --prefix !pkgpath:/=\! 1>$(NULL) && \
					echo include $$^(MKPM^)/.pkgs/!pkgname!/main.mk > "$(MKPM)/!pkgname!" && \
					echo .PHONY: !pkgname!-%% > "$(MKPM)/-!pkgname!" && \
					echo !pkgname!-%%: >> "$(MKPM)/-!pkgname!" && \
					echo 	@$$^(MAKE^) -s -f $$^(MKPM^)/.pkgs/!pkgname!/main.mk $$^(subst !pkgname!-,,$$@^) >> "$(MKPM)/-!pkgname!" \
				)) \
			" \
		$(call for_end)
else
ifeq (1,$(_LOAD_MKPM_FROM_CACHE))
	@$(CD) $(MKPM) && \
		$(TAR) -xzf .cache.tar.gz .
	@$(ECHO) MKPM: loaded from cache
else
	@cd $(PROJECT_ROOT) && $(call for,i,$(MKPM_PACKAGES)) \
			export PKG=$(call for_i,i) && \
			export PKGNAME="$$(echo $$PKG | $(SED) 's|=.*$$||g')" && \
			export PKGPATH="$(MKPM)/.pkgs/$$PKGNAME" && \
			$(call rm_rf,$$PKGPATH) $(NOFAIL) && \
			$(call mkdir_p,$$PKGPATH) && \
			echo MKPM: installing $$PKG && \
			$(MKPM_BINARY) install $$PKG --prefix $$PKGPATH 1>$(NULL) && \
			echo 'include $$(MKPM)'"/.pkgs/$$PKGNAME/main.mk" > "$(MKPM)/$$PKGNAME" && \
			echo ".PHONY: $$PKGNAME-%" > "$(MKPM)/-$$PKGNAME" && \
			echo "$$PKGNAME-%:" >> "$(MKPM)/-$$PKGNAME" && \
			echo '	@$$(MAKE) -s -f $$(MKPM)/.pkgs/'"$$PKGNAME/main.mk "'$$(subst '"$$PKGNAME-,,$$"'@)' >> "$(MKPM)/-$$PKGNAME" \
		$(call for_end)
endif
endif
endif
endif
	@$(call rm_rf,$(HOME)/.mkpm/sources.list) $(NOFAIL)
	@$(call mv_f,$(HOME)/.mkpm/sources.list.backup,$(HOME)/.mkpm/sources.list) $(NOFAIL)
ifeq ($(patsubst %.exe,%,$(SHELL)),$(SHELL))
ifneq ($(TRUE),$(TAR))
ifneq (1,$(_LOAD_MKPM_FROM_CACHE))
	@$(CD) $(MKPM) && \
		$(TAR) -czf .cache.tar.gz \
			--exclude '.tmp' \
			--exclude '.bootstrap' \
			--exclude '.bootstrap.mk' \
			--exclude '.cache.tar.gz' \
			. $(NOFAIL)
endif
endif
endif
	@$(call touch_m,"$@")

NODE ?= node
PRETTIER ?= $(call ternary,prettier -v,prettier,$(call ternary,$(PROJECT_ROOT)/node_modules/.bin/prettier -v,$(PROJECT_ROOT)/node_modules/.bin/prettier,$(call ternary,node_modules/.bin/prettier -v,node_modules/.bin/prettier,)))
HELP_GENERATE_TABLE ?= $(NODE) -e 'var a=console.log;a("|command|description|");a("|-|-|");require("fs").readFileSync(0,"utf-8").replace(/\u001b\[\d*?m/g,"").split("\n").map(e=>e.split(/\s+(.+)/).map(e=>e.trim())).map(e=>{var r=e[0];if(e&&r)a("|","`make "+r+"`","|",e.length>1?e[1]:"","|")})'
HELP_PREFIX ?=
HELP_SPACING ?= 32
export MKPM_HELP ?= _mkpm_help
export HELP ?= $(MKPM_HELP)
$(MKPM_HELP):
ifneq ($(patsubst %.exe,%,$(SHELL)),$(SHELL))
	@echo $@ only works on unix
else
	@$(call cat,$(CURDIR)/Makefile) | \
		$(GREP) -E '^[a-zA-Z0-9][^ 	%*]*:.*##' | \
		$(SORT) | \
		$(AWK) 'BEGIN {FS = ":[^#]*([ 	]+##[ 	]*)?"}; {printf "\033[36m%-$(HELP_SPACING)s  \033[0m%s\n", "$(HELP_PREFIX)"$$1, $$2}' | \
		$(UNIQ)
endif
.PHONY: help-generate-table
help-generate-table:
ifneq ($(patsubst %.exe,%,$(SHELL)),$(SHELL))
	@echo $@ only works on unix
else
ifeq (,$(PRETTIER))
	@$(call requires_pkg,prettier,https://prettier.io,npm install -g prettier)
else
ifneq ($(HELP),help-generate-table)
	@$(MAKE) -s $(HELP)
endif
	@$(call mkdir_p,$(MKPM_TMP))
	@$(EXPORT) HELP_TABLE=$(MKPM_TMP)/help-table.md && \
		$(MAKE) -s $(HELP) | \
		$(HELP_GENERATE_TABLE) > $$HELP_TABLE && \
		$(PRETTIER) $$HELP_TABLE
endif
endif

ifeq (,$(.DEFAULT_GOAL))
.DEFAULT_GOAL = $(HELP)
endif
ifeq ($(findstring .mkpm/.bootstrap,$(.DEFAULT_GOAL)),.mkpm/.bootstrap)
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

export GLOBAL_MK := $(wildcard $(call join_path,$(PROJECT_ROOT),global.mk))
export LOCAL_MK := $(wildcard $(call join_path,$(CURDIR),local.mk))
ifneq (,$(MKPM_READY))
ifneq (,$(GLOBAL_MK))
-include $(GLOBAL_MK)
endif
ifneq (,$(LOCAL_MK))
-include $(LOCAL_MK)
endif
endif
