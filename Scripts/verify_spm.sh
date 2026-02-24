#!/bin/bash
#
# Validate Couchbase Lite Swift Package Manager.

set -e
set -o pipefail

usage() {
  echo "Usage: ${0} -v <CBL Version> [-vs <VS Version>] [--ce|--ee]"
  echo "NOTE: If neither --ce nor --ee is specified, both will run."
}

CBL_VERSION=""
VS_VERSION=""
TEST_CE=false
TEST_EE=false

# -------------------------------
# Parse Arguments
# -------------------------------
while [[ $# -gt 0 ]]; do
  case $1 in
    -v)
      CBL_VERSION=$2
      shift
      ;;
    -vs)
      VS_VERSION=$2
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

# -------------------------------
# Validate Arguments
# -------------------------------
if [[ -z "$CBL_VERSION" ]]; then
  echo "Error: You must specify -v <CBL Version>."
  usage
  exit 1
fi

if [[ "$TEST_EE" = true && -z "$VS_VERSION" ]]; then
  echo "Error: You must specify -vs <VS Version> when testing EE."
  usage
  exit 1
fi

BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CE_SRC_DIR="${BASEDIR}/../ReleaseVerify/ReleaseVerify-SPM-CE"
EE_SRC_DIR="${BASEDIR}/../ReleaseVerify/ReleaseVerify-SPM-EE"

FAIL_COUNT=0
declare -a reports

# -------------------------------
# Determine Editions
# -------------------------------
if [ "$TEST_CE" = true ]; then
  EDITIONS=("CE")
elif [ "$TEST_EE" = true ]; then
  EDITIONS=("EE")
else
  EDITIONS=("CE" "EE")
fi

# -------------------------------
# Modify Package.swift
# -------------------------------
modify_package() {
  local EDITION=$1

  if [ "$EDITION" = "CE" ]; then
    sed "s|__CBL_VERSION__|$CBL_VERSION|g" \
      Package.swift.template > Package.swift
  else
    sed \
      -e "s|__CBL_VERSION__|$CBL_VERSION|g" \
      -e "s|__VS_VERSION__|$VS_VERSION|g" \
      Package.swift.template > Package.swift
  fi
}

# -------------------------------
# Test Runner
# -------------------------------
test_edition() {
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

  # Properly reset SwiftPM state to avoid nested xcframework warnings
  swift package reset

  if swift test; then
    reports+=( "✔ ${LABEL}" )
  else
    reports+=( "✘ ${LABEL}" )
    ((FAIL_COUNT++))
  fi

  popd > /dev/null
}

# -------------------------------
# Update Package.swift First
# -------------------------------
for EDITION in "${EDITIONS[@]}"; do
  if [ "$EDITION" = "CE" ]; then
    SRC_DIR="${CE_SRC_DIR}"
  else
    SRC_DIR="${EE_SRC_DIR}"
  fi

  pushd "${SRC_DIR}" > /dev/null
  modify_package "$EDITION"
  popd > /dev/null
done

# -------------------------------
# Run Tests
# -------------------------------
for EDITION in "${EDITIONS[@]}"; do
  test_edition "$EDITION"
done

# -------------------------------
# Results
# -------------------------------
echo "--------------------------------------"
echo "Verification Results"
echo "FROM: SPM"
echo "CBL VERSION: ${CBL_VERSION}"
echo "VECTOR SEARCH VERSION: ${VS_VERSION:-N/A}"
echo "$(xcodebuild -version)"
printf '%s\n' "${reports[@]}"

# Fail CI if any edition failed
if [[ $FAIL_COUNT -gt 0 ]]; then
  echo "Verification failed: At least one edition failed."
  exit 1
fi