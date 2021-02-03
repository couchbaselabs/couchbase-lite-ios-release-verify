#!/bin/bash
#
# Utility functions to share across multiple scripts

set -e

LATESTBUILDS_URL="http://latestbuilds.service.couchbase.com/builds/latestbuilds/couchbase-lite-ios"
DOWNLOADS_URL="https://packages.couchbase.com/releases/couchbase-lite-ios"

IOS_SIMULATOR_DEST="platform=iOS Simulator,name=iPhone 12"

#######################################
# Downloads and unzips the frameworks if necessary
# Args:
#   1: URL to download
#   2: Output directory
#######################################
download_unzip()
{
  URL=${1}
  OUT=${2}
  FILENAME=$(basename $URL ".zip")
  # >>>> Unzip
  echo "Downloading $URL to $OUT"
  mkdir "${OUT}"
  curl -O $URL -o $OUT
  
  echo "Unzipping..."
  unzip ${OUT}/${FILENAME}.zip -d ${OUT}
  rm -rf ${OUT}/${FILENAME}.zip
  
  mv ${OUT}/${FILENAME}/* ${OUT}/
}
