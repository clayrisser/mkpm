# File: /Makefile
# Project: mkpm
# File Created: 26-09-2021 00:47:48
# Author: Clay Risser
# -----
# Last Modified: 26-09-2021 20:19:28
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

include mkpm.mk
-include $(MKPM)/blackmagic

CARGO ?= cargo
GIT ?= git

.PHONY: test-bootstrap
test-bootstrap:
	@echo DOWNLOAD: $(DOWNLOAD)
	@echo FLAVOR: $(FLAVOR)
	@echo GREP: $(GREP)
	@echo MKPM: $(MKPM)
	@echo NIX_ENV: $(NIX_ENV)
	@echo NPROC: $(NPROC)
	@echo NULL: $(NULL)
	@echo NUMPROC: $(NUMPROC)
	@echo PLATFORM: $(PLATFORM)
	@echo ROOT: $(ROOT)
	@echo SED: $(SED)
	@echo SHELL: $(SHELL)
	@echo WHICH: $(WHICH)



.PHONY: build
ifneq ($(call ternary,docker --version,true,false),true)
build: build-musl build-darwin
else
build:
	@docker run --rm -it \
		-v $(PWD):/root/src \
		registry.gitlab.com/silicon-hills/community/ci-images/docker-rust:0.0.1 \
		make build
endif

.PHONY: build-musl
build-musl:
	@$(CARGO) build --release --target x86_64-unknown-linux-musl $(ARGS)
	@du -sh target/x86_64-unknown-linux-musl/release/mkpm
	@chown -R $$(stat -c '%u:%g' mkpm.mk) target

.PHONY: build-darwin
build-darwin:
	@CC=o64-clang \
		CXX=o64-clang++ \
		LIBZ_SYS_STATIC=1 \
		$(CARGO) build --release --target x86_64-apple-darwin
	@du -sh tests/hello-world/target/x86_64-apple-darwin/release/mkpm
	@chown -R $$(stat -c '%u:%g' mkpm.mk) target

.PHONY: run
run:
	@RUST_LOG=debug RUST_BACKTRACE=1 $(CARGO) run -- $(ARGS)

.PHONY: clean
clean:
	@$(GIT) clean -fXd \
		-e $(BANG)/target \
		-e $(BANG)/target/ \
		-e $(BANG)/target/**/*
