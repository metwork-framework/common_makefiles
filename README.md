# common_makefiles

## What is it?

These are some common Makefiles, not specific to MetWork Framework.

## How to install them?

As regular user, in your project root:

```
bash -c "$(curl -fsSLk https://raw.githubusercontent.com/metwork-framework/common_makefiles/master/install.sh)"
```

Then, create your Makefile with (for example):

```
include .common_makefiles/python_makefile.mk

APP_DIRS={your app directory name}
TEST_DIRS={your tests directory name}
```

Note: you can let `APP_DIRS` or `TEST_DIRS` empty depending on your context.

Then, `make help` should work.

## How to update them?

`make refresh_common_makefiles`
