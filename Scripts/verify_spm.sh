#!/bin/bash
#
# Validate Couchbase Liste Swift Package Manager.

function usage
{
  echo "Usage : ${0} [-v <Version>] [-ce|-ee]"
  echo "NOTE 1: When the version is specified, the script will replace the existing version in Package.swift with the specified version before running the script."
  echo "NOTE 2: When neither flavour is specified, the script will run both CE and EE."
}

while [[ $# -gt 0 ]]; do
  key=${1}
  case $key in
    -v)
      VERSION=${2}
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

function cleanup {
  pushd "${CE_SRC_DIR}" > /dev/null
  cp Package.swift.bak Package.swift
  popd > /dev/null

  pushd "${EE_SRC_DIR}" > /dev/null
  cp Package.swift.bak Package.swift
  popd > /dev/null
}

BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CE_SRC_DIR="${BASEDIR}/../ReleaseVerify/ReleaseVerify-SPM-CE"
EE_SRC_DIR="${BASEDIR}/../ReleaseVerify/ReleaseVerify-SPM-EE"

if [ -z "$VERSION" ]; then
  echo "Verifying with the version specified in Package.swift ..."
else
  trap cleanup EXIT
  echo "Verifying with version : ${VERSION}"

  if [ "$TEST_CE" = true ] || [ -z "$TEST_CE" ]; then
    pushd "${CE_SRC_DIR}" > /dev/null
    cp Package.swift Package.swift.bak
    sed -i '' "s/exact: \".*\"/exact: \"${VERSION}\"/" Package.swift
    popd > /dev/null
  fi

  if [ "$TEST_EE" = true ] || [ -z "$TEST_EE" ]; then
    pushd "${EE_SRC_DIR}" > /dev/null
    cp Package.swift Package.swift.bak
    sed -i '' "s/exact: \".*\"/exact: \"${VERSION}\"/" Package.swift
    popd > /dev/null
  fi
fi

declare -a reports

echo "--------------------------------------"
echo "Verification Complete"

if [ "$TEST_CE" = true ]; then
  echo "Community Edition Test ..."
  pushd "${CE_SRC_DIR}" > /dev/null
  CE_VERSION=$(grep -o "exact: \".*\"" Package.swift | sed 's/.*"\(.*\)\".*/\1/')
  swift test
  if [[ $? == 0 ]]; then
    reports+=( "\xE2\x9C\x94 Community Edition" )
  else
    reports+=( "x Community Edition" )
  fi
  popd > /dev/null
fi

if [ "$TEST_EE" = true ]; then
  echo "Enterprise Edition Test ..."
  pushd "${EE_SRC_DIR}" > /dev/null
  EE_VERSION=$(grep -o "exact: \".*\"" Package.swift | sed 's/.*"\(.*\)\".*/\1/')
  swift test
  if [[ $? == 0 ]]; then
    reports+=( "\xE2\x9C\x94 Enterprise Edition" )
  else
    reports+=( "x Enterprise Edition" )
  fi
  popd > /dev/null
fi

if [ "$TEST_CE" != true ] && [ "$TEST_EE" != true ]; then
  echo "Running both Community Edition and Enterprise Edition tests ..."

  echo "Community Edition Test ..."
  pushd "${CE_SRC_DIR}" > /dev/null
  CE_VERSION=$(grep -o "exact: \".*\"" Package.swift | sed 's/.*"\(.*\)\".*/\1/')
  swift test
  if [[ $? == 0 ]]; then
    reports+=( "\xE2\x9C\x94 Community Edition" )
  else
    reports+=( "x Community Edition" )
  fi
  popd > /dev/null

  echo "Enterprise Edition Test ..."
  pushd "${EE_SRC_DIR}" > /dev/null
  EE_VERSION=$(grep -o "exact: \".*\"" Package.swift | sed 's/.*"\(.*\)\".*/\1/')
  swift test
  if [[ $? == 0 ]]; then
    reports+=( "\xE2\x9C\x94 Enterprise Edition" )
  else
    reports+=( "x Enterprise Edition" )
  fi
  popd > /dev/null
fi

echo "--------------------------------------"
echo "Verification Complete"
echo "FROM: SPM"
if [ "$TEST_CE" = true ]; then
  echo "VERSION: CE-${CE_VERSION}"
fi
if [ "$TEST_EE" = true ]; then
  echo "VERSION: CE-${EE_VERSION}"
fi
if [ "$TEST_CE" != true ] && [ "$TEST_EE" != true ]; then
  echo echo "VERSION: CE-${CE_VERSION}, EE-${EE_VERSION}"
fi
echo "$(xcodebuild -version)"
printf '%b\n' "${reports[@]}"
