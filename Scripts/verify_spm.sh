#!/bin/bash
#
# Validate Couchbase Liste Swift Package Manager.

function usage
{
  echo "Usage : ${0} [-v <Version>]"
  echo "NOTE: When the version is specified, the script will replace the existing version is Package.swift with the specified version before running the script."
}

while [[ $# -gt 0 ]]; do
  key=${1}
  case $key in
      -v)
      VERSION=${2}
      shift
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
    
    pushd "${CE_SRC_DIR}" > /dev/null
    cp Package.swift Package.swift.bak
    sed -i '' "s/exact: \".*\"/exact: \"${VERSION}\"/" Package.swift
    popd > /dev/null

    pushd "${EE_SRC_DIR}" > /dev/null
    cp Package.swift Package.swift.bak
    sed -i '' "s/exact: \".*\"/exact: \"${VERSION}\"/" Package.swift
    popd > /dev/null
fi

declare -a reports

echo "Community Edition Test ..."
pushd "${CE_SRC_DIR}" > /dev/null
CE_VERSION=`grep -o "exact: \".*\"" Package.swift | sed 's/.*"\(.*\)\".*/\1/'`
swift test
if [[ $? == 0 ]]; then
  reports+=( "\xE2\x9C\x94 Cummunity Edition" )
else
  reports+=( "x Cummunity Edition" )
fi
popd > /dev/null

echo "Enterprise Edition Test ..."
pushd "${EE_SRC_DIR}" > /dev/null
EE_VERSION=`grep -o "exact: \".*\"" Package.swift | sed 's/.*"\(.*\)\".*/\1/'`
swift test
if [[ $? == 0 ]]; then
  reports+=( "\xE2\x9C\x94 Enterprise Edition" )
else
  reports+=( "x Enterprise Edition" )
fi
popd > /dev/null

echo "--------------------------------------"
echo "Verification Complete"
echo "FROM: SPM"
echo "VERSION: CE-${CE_VERSION}, EE-${EE_VERSION}"
echo "$(xcodebuild -version)"
printf '%b\n' "${reports[@]}"