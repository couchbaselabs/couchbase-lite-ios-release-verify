#!/bin/bash
#
# Validate Couchbase Liste Swift Package Manager.

function usage
{
  echo "Usage: ${0} [-v <Version> | -b <Branch>] [-ce|-ee]"
  echo "NOTE 1: When the version or branch is specified, the script will replace the existing version in Package.swift with the specified version before running the script."
  echo "NOTE 2: When neither flavour is specified, the script will run both CE and EE."
}

VERSION=""
BRANCH=""
TEST_CE=false
TEST_EE=false

while [[ $# -gt 0 ]]; do
  key=${1}
  case $key in
    -v)
      VERSION=${2}
      shift
      ;;
    -b)
      BRANCH=${2}
      shift
      ;;
    -ce)
      TEST_CE=true
      ;;
    -ee)
      TEST_EE=true
      ;;
    *)
      usage
      exit 3
      ;;
  esac
  shift
done

if ! $TEST_CE && ! $TEST_EE; then
  TEST_CE=true
  TEST_EE=true
fi

# Validate the arguments
if [[ -n "$VERSION" && -n "$BRANCH" ]]; then
  echo "Error: You can only specify either -v or -b flag, not both."
  usage
  exit 1
fi

BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CE_SRC_DIR="${BASEDIR}/../ReleaseVerify/ReleaseVerify-SPM-CE"
EE_SRC_DIR="${BASEDIR}/../ReleaseVerify/ReleaseVerify-SPM-EE"

if [ -n "$VERSION" ]; then
  echo "Verifying with version: ${VERSION}"
elif [ -n "$BRANCH" ]; then
  echo "Verifying with branch: ${BRANCH}"
else
  echo "Verifying with current Package.swift, version: ${VERSION}"
fi

function modify_package_version
{
  if [ -f "Package.swift.bak" ]; then
      # If .bak is already existing, the script has been run previously... cleanup is needed because on how we parse - see below
      echo "Script has been previously run - cleaning up..."
      mv Package.swift.bak Package.swift
      cp Package.swift Package.swift.bak
    else
      cp Package.swift Package.swift.bak
    fi
    sed -i '' "s/exact: \".*\"/exact: \"${VERSION}\"/" Package.swift
}

function modify_package_branch
{
  if [ -f "Package.swift.bak" ]; then
      # If .bak is already existing, the script has been run previously... cleanup is needed because on how we parse - see below
      mv Package.swift.bak Package.swift
      cp Package.swift Package.swift.bak
    else
      cp Package.swift Package.swift.bak
    fi
    sed -i '' "s/exact: \".*\"/branch: \"${BRANCH}\"/" Package.swift
}

function test_ce
{
  swift test
  if [[ $? == 0 ]]; then
    reports+=( "\xE2\x9C\x94 Community Edition" )
  else
    reports+=( "x Community Edition" )
  fi
}

function test_ee
{
  swift test
  if [[ $? == 0 ]]; then
    reports+=( "\xE2\x9C\x94 Enterprise Edition" )
  else
    reports+=( "x Enterprise Edition" )
  fi
}

if [ -n "$BRANCH" ]; then
  if [ "$TEST_CE" = true ]; then
    pushd "${CE_SRC_DIR}" > /dev/null
    modify_package_branch
    popd > /dev/null
  elif [ "$TEST_EE" = true ]; then
    pushd "${EE_SRC_DIR}" > /dev/null
    modify_package_branch
    popd > /dev/null
  else
  pushd "${CE_SRC_DIR}" > /dev/null
  modify_package_branch
  popd > /dev/null

  pushd "${EE_SRC_DIR}" > /dev/null
  modify_package_branch
  popd > /dev/null
  fi
else
  if [ "$TEST_CE" = true ]; then
    pushd "${CE_SRC_DIR}" > /dev/null
    modify_package_version
    popd > /dev/null
  elif [ "$TEST_EE" = true ]; then
    pushd "${EE_SRC_DIR}" > /dev/null
    modify_package_version
    popd > /dev/null
  else
  pushd "${CE_SRC_DIR}" > /dev/null
  modify_package_version
  popd > /dev/null

  pushd "${EE_SRC_DIR}" > /dev/null
  modify_package_version
  popd > /dev/null
  fi
fi

declare -a reports

echo "--------------------------------------"
echo "Verification Complete"

if [ "$TEST_CE" = true ]; then
  echo "Community Edition Test ..."
  pushd "${CE_SRC_DIR}" > /dev/null
  test_ce
  popd > /dev/null
fi

if [ "$TEST_EE" = true ]; then
  echo "Enterprise Edition Test ..."
  pushd "${EE_SRC_DIR}" > /dev/null
  test_ee
  popd > /dev/null
fi

if [ -z "$TEST_CE" ] && [ -z "$TEST_EE" ]; then
  echo "Running both Community Edition and Enterprise Edition tests ..."

  echo "Community Edition Test ..."
  pushd "${CE_SRC_DIR}" > /dev/null
  test_ce
  popd > /dev/null

  echo "Enterprise Edition Test ..."
  pushd "${EE_SRC_DIR}" > /dev/null
  test_ee
  popd > /dev/null
fi

echo "--------------------------------------"
echo "Verification Complete"
echo "FROM: SPM"
if [ -n "$BRANCH" ]; then
  if [ "$TEST_CE" = true ]; then
    echo "BRANCH: CE" $BRANCH
  elif [ "$TEST_EE" = true ]; then
    echo "BRANCH: EE" $BRANCH
  else
    echo "BRANCH: CE+EE" $BRANCH
  fi
else
  if [ "$TEST_CE" = true ]; then
    echo "VERSION: CE" $VERSION
  elif [ "$TEST_EE" = true ]; then
    echo "VERSION: EE" $VERSION
  else
    echo "VERSION: CE+EE" $VERSION
  fi
fi

echo "$(xcodebuild -version)"
printf '%b\n' "${reports[@]}"
