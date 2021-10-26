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
       hello=0.0.4

   MKPM_REPOS := \
       https://gitlab.com/bitspur/community/mkpm-stable.git

   ############# MKPM BOOTSTRAP SCRIPT BEGIN #############
   MKPM_BOOTSTRAP := https://bitspur.gitlab.io/community/mkpm/bootstrap.mk
   NULL := /dev/null
   TRUE := true
   ifeq ($(OS),Windows_NT)
   	NULL = nul
   	TRUE = type nul
   endif
   -include .mkpm/.bootstrap.mk
   .mkpm/.bootstrap.mk:
   	@mkdir .mkpm 2>$(NULL) || $(TRUE)
   	@cd .mkpm && \
   		$(shell curl --version >$(NULL) 2>$(NULL) && \
   			echo curl -L -o || \
   			echo wget --content-on-error -O) \
   		.bootstrap.mk $(MKPM_BOOTSTRAP) >$(NULL)
   ############## MKPM BOOTSTRAP SCRIPT END ##############
   ```

2. Add mkpm packages to the `MKPM_PACKAGES` config. Below is an example.

```makefile
MKPM_PACKAGES := \
    hello=0.0.4
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
