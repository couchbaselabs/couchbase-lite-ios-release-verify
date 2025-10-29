#!/bin/bash
#
# Validate Couchbase Lite Swift Package Manager.

function usage {
  echo "Usage: ${0} [-v <Version> | -b <Branch>] [-vs <VS Version> | -vb <VS Branch>] [--ce|--ee]"
  echo "NOTE: If neither --ce nor --ee is specified, both will run."
}

VERSION=""
BRANCH=""
VS_VERSION=""
VS_BRANCH=""
TEST_CE=false
TEST_EE=false

# -------------------------------
# Parse Arguments
# -------------------------------
while [[ $# -gt 0 ]]; do
  key=${1}
  case $key in
    -v)
      VERSION=${2}; shift ;;
    -b)
      BRANCH=${2}; shift ;;
    -vs)
      VS_VERSION=${2}; shift ;;
    -vb)
      VS_BRANCH=${2}; shift ;;
    --ce)
      TEST_CE=true ;;
    --ee)
      TEST_EE=true ;;
    *)
      usage; exit 3 ;;
  esac
  shift
done

# -------------------------------
# Validate Arguments
# -------------------------------
if [[ -n "$VERSION" && -n "$BRANCH" ]]; then
  echo "Error: You must specify either -v <Version> or -b <Branch> for the CBL package."
  usage
  exit 1
fi

if [[ -n "$VS_VERSION" && -n "$VS_BRANCH" ]]; then
  echo "Error: You must specify either -vs <Version> or -vb <Branch> for the VS package."
  usage
  exit 1
fi

BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CE_SRC_DIR="${BASEDIR}/../ReleaseVerify/ReleaseVerify-SPM-CE"
EE_SRC_DIR="${BASEDIR}/../ReleaseVerify/ReleaseVerify-SPM-EE"
FAIL_COUNT=0
declare -a reports

# Determine edition
declare -a EDITIONS=()
if [ "$TEST_CE" = true ]; then
  EDITIONS=("CE")
elif [ "$TEST_EE" = true ]; then
  EDITIONS=("EE")
else
  EDITIONS=("CE" "EE")
fi

# Set dependency helper method
function modify_dependency {
  local PACKAGE_NAME=$1
  local VALUE=$2
  local TYPE=$3

  if [ "$TYPE" == "exact" ]; then
    sed -i '' "s|\(couchbase/${PACKAGE_NAME}.*\", exact: \"\)[^\"]*\(\"\)|\1${VALUE}\2|" Package.swift
  elif [ "$TYPE" == "branch" ]; then
    sed -i '' "s|\(couchbase/${PACKAGE_NAME}.*\", branch: \"\)[^\"]*\(\"\)|\1${VALUE}\2|" Package.swift
  fi
}

# Modify Package.swift helper method
function modify_package {
  local EDITION=$1
  local MODE=$2   # "version" or "branch"
  local MAIN_PACKAGE VALUE_TYPE MAIN_VALUE VS_VALUE

  # Select package name based on edition
  if [ "$EDITION" = "CE" ]; then
    MAIN_PACKAGE="couchbase-lite-swift"
  else
    MAIN_PACKAGE="couchbase-lite-swift-ee"
  fi

  # Select modification mode
  if [ "$MODE" = "version" ]; then
    VALUE_TYPE="exact"
    MAIN_VALUE="$VERSION"
    VS_VALUE="$VS_VERSION"
  else
    VALUE_TYPE="branch"
    MAIN_VALUE="$BRANCH"
    VS_VALUE="$VS_BRANCH"
  fi

  # Backup Package.swift
  if [ -f "Package.swift.bak" ]; then
    echo "Script previously run - restoring backup..."
    mv Package.swift.bak Package.swift
  fi
  cp Package.swift Package.swift.bak

  # Apply updates
  if [ -n "$MAIN_VALUE" ]; then
    modify_dependency "$MAIN_PACKAGE" "$MAIN_VALUE" "$VALUE_TYPE"
  fi
  if [ -n "$VS_VALUE" ]; then
    modify_dependency "couchbase-lite-vector-search-spm" "$VS_VALUE" "$VALUE_TYPE"
  fi
}

# -------------------------------
# Test Runner
# -------------------------------
function test_edition {
  local EDITION=$1
  local SRC_DIR LABEL

  if [ "$EDITION" = "CE" ]; then
    SRC_DIR="${CE_SRC_DIR}"
    LABEL="Community Edition"
  else
    SRC_DIR="${EE_SRC_DIR}"
    LABEL="Enterprise Edition"
  fi

  echo "Testing ${LABEL} ..."
  pushd "${SRC_DIR}" > /dev/null
  swift test
  if [[ $? == 0 ]]; then
    reports+=( "\xE2\x9C\x94 ${LABEL}" )
  else
    reports+=( "x ${LABEL}" )
    ((FAIL_COUNT++))
  fi
  popd > /dev/null
}

for EDITION in "${EDITIONS[@]}"; do
  if [ "$EDITION" = "CE" ]; then
    SRC_DIR="${CE_SRC_DIR}"
  else
    SRC_DIR="${EE_SRC_DIR}"
  fi

  pushd "${SRC_DIR}" > /dev/null
  if [ -n "$BRANCH" ]; then
    modify_package "$EDITION" "branch"
  else
    modify_package "$EDITION" "version"
  fi
  popd > /dev/null
done

# -------------------------------
# Results
# -------------------------------
for EDITION in "${EDITIONS[@]}"; do
  test_edition "$EDITION"
done

echo "--------------------------------------"
echo "Verification Results"
echo "FROM: SPM"

if [ -n "$BRANCH" ]; then
  echo "BRANCH: ${BRANCH}"
  echo "VECTOR SEARCH BRANCH: ${VS_BRANCH:-N/A}"
else
  echo "VERSION: ${VERSION}"
  echo "VECTOR SEARCH VERSION: ${VS_VERSION:-N/A}"
fi

echo "$(xcodebuild -version)"
printf '%b\n' "${reports[@]}"

# Fail Jenkins if script fails
if [[ -n "$JENKINS_HOME" && $FAIL_COUNT -gt 0 ]]; then
  echo "Verification failed: At least one failed."
  exit 1
fi
