# File: /mkpm.mk
# Project: mkpm
# File Created: 26-09-2021 00:44:57
# Author: Clay Risser
# -----
# Last Modified: 26-09-2021 01:35:20
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

MKPM_PACKAGE_DIR := .mkpm

MKPM_PACKAGES := \

############# MKPM BOOTSTRAP SCRIPT BEGIN #############
MKPM_BOOTSTRAP := https://example.com
NULL := /dev/null
MKDIRP := mkdir -p
ifeq ($(SHELL),cmd.exe)
	NULL = nul
	MKDIRP = mkdir
endif
-include $(MKPM_PACKAGE_DIR)/bootstrap.mk
$(MKPM_PACKAGE_DIR)/bootstrap.mk:
	@$(MKDIRP) $(MKPM_PACKAGE_DIR)
	@cd $(MKPM_PACKAGE_DIR) && \
		$(shell curl --version >$(NULL) 2>$(NULL) && \
			echo curl -Ls -o bootstrap.mk|| \
			echo wget -q --content-on-error -O bootstrap.mk) \
		$(MKPM_BOOTSTRAP) >$(NULL)
export MKPM := $(shell pwd)/$(MKPM_PACKAGE_DIR)
############## MKPM BOOTSTRAP SCRIPT END ##############
