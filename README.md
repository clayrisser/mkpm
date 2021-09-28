# mkpm

> makefile package manager

You can find an example project using mkpm at the link below

https://gitlab.com/bitspur/community/mkpm-example

## Usage

1. Create a file called `mkpm.mk` in the root of your project
   with the following content. This file contains the mkpm
   configuration for a given project, such as the list of
   mkpm packages.

   _mkpm.mk_

   ```makefile
   MKPM_PACKAGES := \
       hello=0.0.2

   MKPM_REPOS := \
       https://gitlab.com/bitspur/community/mkpm-stable.git

   MKPM_PACKAGE_DIR := .mkpm

   NUMPROC := 1

   ############# MKPM BOOTSTRAP SCRIPT BEGIN #############
   MKPM_BOOTSTRAP := https://bitspur.gitlab.io/community/mkpm/bootstrap.mk
   NULL := /dev/null
   define mkdir_p
   mkdir -p $1
   endef
   ifeq ($(OS),Windows_NT)
   	NULL = nul
   	SHELL := cmd.exe
   define mkdir_p
   set P=$1 & set P=%P:/=\% & mkdir %P%
   endef
   endif
   -include $(MKPM_PACKAGE_DIR)/.bootstrap.mk
   $(MKPM_PACKAGE_DIR)/.bootstrap.mk:
   	@$(call mkdir_p,$(MKPM_PACKAGE_DIR))
   	@cd $(MKPM_PACKAGE_DIR) && \
   		$(shell curl --version >$(NULL) 2>$(NULL) && \
   			echo curl -L -o || \
   			echo wget --content-on-error -O) \
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
   Also make sure you wrap the file with `ifneq (,$(MKPM))` and `endif` to
   prevent code from executing before mkpm is loaded.

   _Makefile_

   ```makefile
   include mkpm.mk # load mkpm
   ifneq (,$(MKPM)) # prevent code from executing before mkpm is loaded
   -include $(MKPM)/hello # import an mkpm package

   # makefile logic here . . .
   .DEFAULT_GOAL := hello # calls a target from the hello package

   endif
   ```
