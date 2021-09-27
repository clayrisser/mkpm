# mkpm

> makefile package manager

## Usage

1. Create a file called `mkpm.mk` in the root of your project
   with the following content. This file contains the mkpm
   configuration for a given project, such as the list of
   mkpm packages.

   _mkpm.mk_

   ```makefile
   MKPM_PACKAGES := \
       blackmagic=0.0.1

   MKPM_SOURCES := \
       https://gitlab.com/bitspur/community/blackmagic.git

   MKPM_PACKAGE_DIR := .mkpm

   NUMPROC := 1

   ############# MKPM BOOTSTRAP SCRIPT BEGIN #############
   MKPM_BOOTSTRAP := https://bitspur.gitlab.io/community/mkpm/bootstrap.mk
   NULL := /dev/null
   MKDIR_P := mkdir -p
   ifeq ($(OS),Windows_NT)
       MKDIR_P = mkdir
       NULL = nul
       SHELL := cmd.exe
   endif
   -include $(MKPM_PACKAGE_DIR)/.bootstrap.mk
   $(MKPM_PACKAGE_DIR)/.bootstrap.mk:
       @$(MKDIR_P) $(MKPM_PACKAGE_DIR)
       @cd $(MKPM_PACKAGE_DIR) && \
           $(shell curl --version >$(NULL) 2>$(NULL) && \
               echo curl -Ls -o || \
               echo wget -q --content-on-error -O) \
           .bootstrap.mk $(MKPM_BOOTSTRAP) >$(NULL)
   ############## MKPM BOOTSTRAP SCRIPT END ##############
   ```

2. Add mkpm packages to the `MKPM_PACKAGES` config. Below is an example.

   ```makefile
   MKPM_PACKAGES := \
       blackmagic=0.0.1
   ```

3. To include packages in a _Makefile_, simply prefix them with the `MKPM`
   variable. They MUST be included after the `mkpm.mk` file. Below is an
   example. Make sure you prefix the include statement with a dash `-include`
   to prevent the Makefile from crashing before the packages are installed.

   _Makefile_

   ```makefile
   include mkpm.mk
   -include $(MKPM)/blackmagic
   ```
