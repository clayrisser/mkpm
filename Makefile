# File: /Makefile
# Project: mkpm
# File Created: 26-09-2021 00:47:48
# Author: Clay Risser
# -----
# Last Modified: 26-09-2021 04:26:00
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

test-bootstrap:
	@echo FLAVOR: $(FLAVOR)
	@echo GREP: $(GREP)
	@echo NPROC: $(NPROC)
	@echo NULL: $(NULL)
	@echo NUMPROC: $(NUMPROC)
	@echo PLATFORM: $(PLATFORM)
	@echo SED: $(SED)
	@echo SHELL: $(SHELL)