#!/bin/bash

# paranoid mode
set -eu

# some vars
ORG=metwork-framework
REPO=common_makefiles
PREFIX=/usr/local
GIT="${GIT:-git}"
GIT_CLONE_DEPTH_1="${GIT} clone --depth 1"
COMMON_MAKEFILES_GIT_URL="https://github.com/${ORG}/${REPO}.git"

mkdir -p .common_makefiles.tmp
cd .common_makefiles.tmp
${GIT_CLONE_DEPTH_1} "${COMMON_MAKEFILES_GIT_URL}"
rm -Rf ../.common_makefiles
cp -Rf common_makefiles/dist ../.common_makefiles
cd ..
rm -Rf .common_makefiles.tmp
echo
echo "=> OK: common makefiles installed in .common_makefiles"
