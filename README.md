# mkpm

> makefile package manager

You can find an example project using mkpm at the link below

https://gitlab.com/risserlabs/community/mkpm-example

## Requirements

* [GNU Make](https://www.gnu.org/software/make) >= 4.1
* [Git](https://git-scm.com)
* [Git LFS](https://git-lfs.com)

## Install

The `mkpm` binary is not required to use mkpm. However, it does provides several utilities for
initializing new mkpm projects, installing new mkpm packages and updating mkpm pacakges.

You can install it with the following command.

```sh
$(curl --version >/dev/null 2>/dev/null && echo curl -L || echo wget -O-) https://gitlab.com/risserlabs/community/mkpm/-/raw/main/install.sh 2>/dev/null | sh
```

![](assets/mkpm.png)

## Usage

1. Create a file called `mkpm.mk` in the root of your project
   with the following content. This file contains the mkpm
   configuration for a given project, such as the list of
   mkpm packages.

   _mkpm.mk_

   ```makefile
   export MKPM_PACKAGES_DEFAULT := \
   	hello=0.1.0

   export MKPM_REPO_DEFAULT := \
   	https://gitlab.com/risserlabs/community/mkpm-stable.git

   ############# MKPM BOOTSTRAP SCRIPT BEGIN #############
   MKPM_BOOTSTRAP := https://gitlab.com/api/v4/projects/29276259/packages/generic/mkpm/0.3.0/bootstrap.mk
   export PROJECT_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
   NULL := /dev/null
   TRUE := true
   ifneq ($(patsubst %.exe,%,$(SHELL)),$(SHELL))
   	NULL = nul
   	TRUE = type nul
   endif
   include $(PROJECT_ROOT)/.mkpm/.bootstrap.mk
   $(PROJECT_ROOT)/.mkpm/.bootstrap.mk:
   	@mkdir $(@D) 2>$(NULL) || $(TRUE)
   	@$(shell curl --version >$(NULL) 2>$(NULL) && \
   		echo curl -Lo || echo wget -O) \
   		$@ $(MKPM_BOOTSTRAP) >$(NULL)
   ############## MKPM BOOTSTRAP SCRIPT END ##############
   ```

   _you can also initialize `mkpm.mk` with the mkpm cli instead_

   ```sh
   mkpm init
   ```

2. Add mkpm packages to the `MKPM_PACKAGES_DEFAULT` config. Below is an example.

   ```makefile
   export MKPM_PACKAGES_DEFAULT := \
   	hello=0.1.0
   ```

   _you can also add packages with the mkpm cli instead_

   ```sh
   mkpm install hello
   ```

   _or_

   ```sh
   mkpm i hello
   ```

3. To include packages in a _Makefile_, simply prefix them with the `MKPM`
   variable. Be sure to include `mkpm.mk`. Also wrap the file with `ifneq (,$(MKPM_READY))`
   and `endif` to prevent code from executing before mkpm is loaded. The packages MUST be included
   after the `mkpm.mk` file and after the `MKPM_READY` check. Below is an example.

   _Makefile_

   ```makefile
   include mkpm.mk # load mkpm
   ifneq (,$(MKPM_READY)) # prevent code from executing before mkpm is ready
   include $(MKPM)/hello # import an mkpm package

   # makefile logic here . . .

   endif
   ```

## Repos

The default repo is set to [https://gitlab.com/risserlabs/community/mkpm-stable.git](https://gitlab.com/risserlabs/community/mkpm-stable.git). Feel free to use any mkpm packages from this repo.

```makefile
export MKPM_REPO_DEFAULT := \
	https://gitlab.com/risserlabs/community/mkpm-stable.git
```

However, you can change the repo to point to your own repo, or you can use multiple repos.
For example, if you wanted to use the packages from the risserlabs default repo, but you
also wanted to bring your own packages, you would simply add a new repo with a new name.

For example, you could call it _howdy_.

_mkpm.mk_
```makefile
export MKPM_REPO_HOWDY := \ # the name of the repo must be post-fixed to the end in all caps
	https://gitlab.com/risserlabs/howdy-mkpm-packages.git

export MKPM_PACKAGES_HOWDY := \ # don't forget to also add the packages variable
```

You can then install pacakges from this custom repo by running the following.

```sh
mkpm install <REPO_NAME> <PACKAGE_NAME>
```

For example, let's say you wanted to install the _texas_ package from _howdy_ repo. You would
simply run the following.

```sh
mkpm install howdy texas
```
