# File: /Makefile
# Project: mkpm
# File Created: 26-09-2021 00:47:48
# Author: Clay Risser
# -----
# Last Modified: 17-06-2022 11:24:11
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

-include mkpm.mk
ifneq (,$(MKPM_READY))
include $(MKPM)/gnu
include $(MKPM)/hello

CARGO ?= cargo
CD ?= cd
CHOWN ?= chown
CURL ?= curl
DOCKER ?= docker
DU ?= du
GIT ?= git
SUDO ?= sudo
TOUCH ?= touch

.DEFAULT_GOAL := hello # this is an example

SUDO := $(call ternary,sudo --version,sudo,true)

.PHONY: test-bootstrap
test-bootstrap: ##
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

.PHONY: clean
clean: ##
	@$(GIT) submodule foreach git add .
	@$(GIT) submodule foreach git reset --hard
	@$(GIT) clean -fXd \
		$(MKPM_GIT_CLEAN_FLAGS) \
		-e $(BANG)/target \
		-e $(BANG)/target/ \
		-e $(BANG)/target/**/*
	@$(TOUCH) -m $(MKPM)/.cleaned
$(MKPM)/.cleaned:
	@$(TOUCH) -m $@

.PHONY: purge
purge: clean ##
	@$(GIT) submodule deinit --all -f
	@$(GIT) clean -fXd

endif

.PHONY: build
ifneq ($(call ternary,$(DOCKER) --version,true,false),true)
build: build-musl build-darwin ##
else
build: ##
	@$(DOCKER) run --rm -it \
		-v $(PWD):/root/src \
		joseluisq/rust-linux-darwin-builder:1.55.0 \
		make build
endif

.PHONY: build-musl
build-musl: sudo gpm/cargo.toml ##
	@$(CD) gpm && $(CARGO) build --release --target x86_64-unknown-linux-musl $(ARGS)
	@$(DU) -sh gpm/target/x86_64-unknown-linux-musl/release/gpm
	@$(MAKE) -s fix-permissions

.PHONY: build-darwin
build-darwin: sudo gpm/cargo.toml ##
	@$(CD) gpm && CC=o64-clang \
		CXX=o64-clang++ \
		LIBZ_SYS_STATIC=1 \
		$(CARGO) build --release --target x86_64-apple-darwin
	@$(CD) gpm && $(DU) -sh tests/hello-world/target/x86_64-apple-darwin/release/mkpm
	@$(MAKE) -s fix-permissions

.PHONY: fix-permissions
fix-permissions: sudo ##
	@$(SUDO) $(CHOWN) -R $$(stat -c '%u:%g' mkpm.mk) gpm/target

.PHONY: run
run: ##
	@RUST_LOG=debug RUST_BACKTRACE=1 $(CARGO) run -- $(ARGS)

.PHONY: submodules
SUBMODULES := gpm/cargo.toml
submodules: $(SUBMODULES) ##
.SECONDEXPANSION: $(SUBMODULES)
$(SUBMODULES): .git/modules/$$(@D)/HEAD $(MKPM)/.cleaned
	@$(GIT) submodule update --init --remote --recursive $(@D)
	@[ -f $(@D).branch ] && (cd $(@D) && $(GIT) checkout $$(cat ../$(@D).branch)) || true
	@[ -f $(@D).patch ] && (cd $(@D) && $(GIT) apply ../$(@D).patch) || true
	@$(TOUCH) -m $@
.git/%: ;

.PHONY: publish
publish: ##
	@$(CURL) --request POST --header "Private-Token: $(GITLAB_TOKEN)" \
		--form "file=@" \
		https://gitlab.com/api/v4/projects/29276259/uploads

.PHONY: %
%: ;
