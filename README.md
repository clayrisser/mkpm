# mkpm

> makefile package manager

## Usage

1. Create a file called `mkpm.mk` in the root of your project
   with the following content. This file contains the mkpm
   configuration for a given project, such as the list of
   mkpm packages.

   _mkpm.mk_

   ```mk
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
   ```

2. Add mkpm packages to the `MKPM_PACKAGES` config. Below is an example.

   ```mk
   MKPM_PACKAGES := \
       hello=0.0.1
   ```

3. To include packages in a _Makefile_, simply prefix them with the `MKPM`
   variable. They MUST be included after the `mkpm.mk` file. Below is an
   example.

   _Makefile_

   ```mk
   include mkpm.mk
   include $(MKPM)/hello.mk
   ```
