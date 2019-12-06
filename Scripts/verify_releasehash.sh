#!/bin/bash

set -e

SEPERATOR="##"

#######################################
# Fetches the lite core branchws and SHAs.
# Globals:
#   LITE_CORE_SHA
# Arguments:
#   $1: Path to lite core source code
#######################################
fetch_lite_core_sha()
{
  pushd $1
  branches=($(git branch -r | grep 'origin/release/[a-z]'))
  LITE_CORE_SHA=()
  for branch in "${branches[@]}"; do
    LITE_CORE_SHA+=("$branch$SEPERATOR$(git rev-parse $branch)")
  done
  popd
}

#######################################
# Fetches the platform source code release branches and SHAs.
# Globals:
#   SUBMODULE_LITE_CORE_SHA
# Arguments:
#   $1: Path to platform source code
#######################################
fetch_platform_submodules()
{
  pushd $1
  branches=($(git branch -r | grep 'origin/release/[a-z]*$'))
  SUBMODULE_LITE_CORE_SHA=()
  for branch in "${branches[@]}"; do
    # switch to the release branch
    git checkout $branch
    if [[ $? != 0 ]]; then
      # if branch not exists locally, get it from remote
      git checkout --track $branch
    fi
  
    git submodule update --init vendor/couchbase-lite-core
    
    SUBMOD=$(git submodule status | grep "couchbase-lite-core" | cut -d' ' -f2)
  
    SUBMODULE_LITE_CORE_SHA+=("$branch$SEPERATOR$SUBMOD")
  done
  popd
}

#######################################
# Removes the cloned directories
# Used:
#   PLATFORM_CODE
#   LITE_CORE_CODE
#######################################
cleanup()
{
  rm -rf $PLATFORM_CODE
  rm -rf $LITE_CORE_CODE
}

#######################################
# validates the repo
# Arguments:
#   $1 - GIT URL
#######################################
validate()
{
  # clones the repos
  git clone $1 $PLATFORM_CODE
  git clone "https://github.com/couchbase/couchbase-lite-core.git" $LITE_CORE_CODE
  
  #fetches the SHAs from platform and lite core codes
  fetch_platform_submodules $PLATFORM_CODE
  fetch_lite_core_sha $LITE_CORE_CODE
  
  # compares the SHAs
  for i in ${!SUBMODULE_LITE_CORE_SHA[@]}; do
    echo "1>> ${SUBMODULE_LITE_CORE_SHA[$i]}"
    echo "2>> ${LITE_CORE_SHA[$i]}"
    if [ "${SUBMODULE_LITE_CORE_SHA[$i]}" != "${LITE_CORE_SHA[$i]}" ]; then
        echo "SHA Mismatch! ${SUBMODULE_LITE_CORE_SHA[$i]} & ${LITE_CORE_SHA[$i]}"
        exit 4
    fi
  done
  
  echo "Validated $1"
  cleanup
}

#######################################
# Start of script
#######################################
echo "Script starting..."

PLATFORM_CODE="platform-code"
LITE_CORE_CODE="couchbase-lite-core"
rm -rf $PLATFORM_CODE
rm -rf $LITE_CORE_CODE

validate "https://github.com/couchbase/couchbase-lite-ios.git"
validate "https://github.com/couchbase/couchbase-lite-net.git"

echo "Verification completed."
