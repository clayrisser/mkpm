# File: /Makefile
# Project: mkpm
# File Created: 26-09-2021 00:47:48
# Author: Clay Risser
# -----
# Last Modified: 28-07-2023 07:01:41
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

include $(MKPM_CORE)
# include $(MKPM)/gnu
# include $(MKPM)/hello
# include $(MKPM)/mkchain

export USER ?= nobody
export EMAIL ?= clayrisser@gmail.com
PKG_NAME ?= mkpm
PKG_VERSION ?= 0.3.0
PKG_STRICT ?= 0
# include $(MKPM)/pkg

.PHONY: inspect
inspect: ##
	@echo ARCH: $(ARCH)
	@echo DOWNLOAD: $(DOWNLOAD)
	@echo FLAVOR: $(FLAVOR)
	@echo GREP: $(GREP)
	@echo MKPM: $(MKPM)
	@echo NIX_ENV: $(NIX_ENV)
	@echo NPROC: $(NPROC)
	@echo NULL: $(NULL)
	@echo NUMPROC: $(NUMPROC)
	@echo PKG_MANAGER: $(PKG_MANAGER)
	@echo PLATFORM: $(PLATFORM)
	@echo ROOT: $(ROOT)
	@echo SED: $(SED)
	@echo SHELL: $(SHELL)
	@echo WHICH: $(WHICH)

ACTIONS += build ##
$(ACTION)/build: $(call git_deps,.)
	@$(MKDIR) -p build
	@$(CP) mkpm.sh build/mkpm
	@$(CHMOD) +x build/mkpm
	@$(call done,build)

.PHONY: install
install: | sudo \
	/usr/local/bin/mkpm
/usr/local/bin/mkpm:
	@$(SUDO) $(CP) mkpm.sh $@
	@$(SUDO) $(CHMOD) +x $@

.PHONY: uninstall
uninstall: | sudo
	@$(SUDO) $(RM) -f \
		/usr/local/bin/mkpm

.PHONY: reinstall
reinstall: | uninstall install

.PHONY: clean
clean: ##
	@$(GIT) clean -fXd \
		$(MKPM_GIT_CLEAN_FLAGS)

.PHONY: purge
purge: clean ##
	@$(GIT) clean -fXd

-include $(call actions)
