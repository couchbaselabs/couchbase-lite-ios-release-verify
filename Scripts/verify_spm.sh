#!/bin/bash
#
# Validate Couchbase Liste Swift Package Manager.

function usage
{
  echo "Usage: ${0} [-v <Version> | -b <Branch>] [-vs <VS Version> | -vb <VS Branch>] [--ce|--ee]"
  echo "NOTE 1: If neither --ce NOR --ee is specified, both will run."
}

VERSION=""
BRANCH=""
VS_VERSION=""
VS_BRANCH=""
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
    -vs)
      VS_VERSION=${2}
      shift
      ;;
    -vb)
      VS_BRANCH=${2}
      shift
      ;;
    --ce)
      TEST_CE=true
      ;;
    --ee)
      TEST_EE=true
      ;;
    *)
      usage
      exit 3
      ;;
  esac
  shift
done

# Validate the arguments
if [[ -n "$VERSION" && -n "$BRANCH" ]]; then
  echo "Error: You must specify either -v <Version> or -b <Branch> for the CBL package (couchbase-lite-swift-ee)."
  usage
  exit 1
fi

if [[ -n "$VS_VERSION" && -n "$VS_BRANCH" ]]; then
  echo "Error: You must specify either -vs <Version> or -vb <Branch> for the VS package (couchbase-lite-vector-search-spm)."
  usage
  exit 1
fi

BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CE_SRC_DIR="${BASEDIR}/../ReleaseVerify/ReleaseVerify-SPM-CE"
EE_SRC_DIR="${BASEDIR}/../ReleaseVerify/ReleaseVerify-SPM-EE"

function modify_dependency
{
  PACKAGE_NAME=$1
  VALUE=$2
  TYPE=$3
  
  if [ "$TYPE" == "exact" ]; then
    sed -i '' "s|\(com/couchbase/${PACKAGE_NAME}.*\", exact: \"\)[^\"]*\(\"\)|\1${VALUE}\2|" Package.swift
  elif [ "$TYPE" == "branch" ]; then
    sed -i '' "s|\(com/couchbase/${PACKAGE_NAME}.*\", branch: \"\)[^\"]*\(\"\)|\1${VALUE}\2|" Package.swift
  fi
}

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
  
  if [ -n "$VERSION" ]; then
    modify_dependency "couchbase-lite-swift-ee" "${VERSION}" "exact"
  fi
  if [ -n "$VS_BRANCH" ]; then
    modify_dependency "couchbase-lite-vector-search-spm" "${VERSION}" "exact"
  fi
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
    
  if [ -n "$VS_VERSION" ]; then
    modify_dependency "couchbase-lite-swift-ee" "${BRANCH}" "branch"
  fi
  if [ -n "$VS_BRANCH" ]; then
    modify_dependency "couchbase-lite-vector-search-spm" "${VS_BRANCH}" "branch"
  fi
}

function test_ce
{
  echo "Community Edition Test ..."
  pushd "${CE_SRC_DIR}" > /dev/null
  swift test
  if [[ $? == 0 ]]; then
    reports+=( "\xE2\x9C\x94 Community Edition" )
  else
    reports+=( "x Community Edition" )
  fi
  popd > /dev/null
}

function test_ee
{
  echo "Enterprise Edition Test ..."
  pushd "${EE_SRC_DIR}" > /dev/null
  swift test
  if [[ $? == 0 ]]; then
    reports+=( "\xE2\x9C\x94 Enterprise Edition" )
  else
    reports+=( "x Enterprise Edition" )
  fi
  popd > /dev/null
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
  test_ce
elif [ "$TEST_EE" = true ]; then
  test_ee
else
  test_ce
  test_ee
fi

echo "--------------------------------------"
echo "Verification Results"
echo "FROM: SPM"
if [ -n "$BRANCH" ]; then
  if [ "$TEST_CE" = true ]; then
    echo "BRANCH: CE" $BRANCH
  elif [ "$TEST_EE" = true ]; then
    echo "BRANCH: EE" $BRANCH
    echo "VECTOR SEARCH BRANCH: $VS_VERSION"
  else
    echo "BRANCH: CE+EE" $BRANCH
    echo "VECTOR SEARCH BRANCH: $VS_VERSION"
  fi
else
  if [ "$TEST_CE" = true ]; then
    echo "VERSION: CE" $VERSION
  elif [ "$TEST_EE" = true ]; then
    echo "VERSION: EE" $VERSION
    echo "VECTOR SEARCH VERSION: $VS_VERSION"
  else
    echo "VERSION: CE+EE" $VERSION
    echo "VECTOR SEARCH VERSION: $VS_VERSION"
  fi
fi

echo "$(xcodebuild -version)"
printf '%b\n' "${reports[@]}"
