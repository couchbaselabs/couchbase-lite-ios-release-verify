#!/bin/sh
#
# Overall test everything for a given version

set -e

BASEDIR=$(dirname "$0")

source ${BASEDIR}/utils.sh

function usage
{
  echo "Usage: sh verify_all.sh [options]"
  echo "\nMandatory Options: "
  echo "  -v\t Version number. e.g., 2.8.0, 3.0.0"
  echo "  -b\t Build number. e.g., 71, 10"
}

while [[ $# -gt 0 ]]; do
  key=${1}
  case $key in
      -v)
      VERSION=${2}
      shift
      ;;
      -b)
      BUILD=${2}
      shift
      ;;
      *)
      usage
      exit 3
      ;;
  esac
  shift
done

########### Validates the arguments

if [ -z "$VERSION" ]; then
  echo "Error: Please include version"
  usage
  exit 4
fi

if [ -z "$BUILD" ]; then
  echo "Error: Please include build"
  usage
  exit 4
fi

declare -a reports
function report
{
  
  if [[ $1 == 0 ]]; then
      reports+=( "\xE2\x9C\x94 ${2}-${3}-${4}" )
  else
      echo "Test Failed!!!"
      reports+=( "x ${2}-${3}-${4}" )
  fi
}

function verify_xc
{
  sh $BASEDIR/verify_xc.sh -v $VERSION -b $BUILD -l swift -arch x86_64 -sdk iphonesimulator
  report $? swift x86_64 iphonesimulator
  
  sh $BASEDIR/verify_xc.sh -v $VERSION -b $BUILD -l objc -arch x86_64 -sdk iphonesimulator
  report $? objc x86_64 iphonesimulator
  
  sh $BASEDIR/verify_xc.sh -v $VERSION -b $BUILD -l swift -arch x86_64 -sdk macosx
  report $? swift x86_64 macosx
    
  sh $BASEDIR/verify_xc.sh -v $VERSION -b $BUILD -l objc -arch x86_64 -sdk macosx
  report $? objc x86_64 macosx
  
  if [[ "$(uname -m)" = "arm64" ]]; then
    sh $BASEDIR/verify_xc.sh -l swift -arch arm64 -v $VERSION -b $BUILD -sdk iphonesimulator
    report $? swift arm64 iphonesimulator
      
    sh $BASEDIR/verify_xc.sh -l objc  -arch arm64 -v $VERSION -b $BUILD -sdk iphonesimulator
    report $? objc arm64 iphonesimulator
  fi
}

function cleanup
{
  rm -rf ${FRAMEWORKS_DIR}/*
  rm -rf ~/Library/Developer/Xcode/DerivedData
}

trap cleanup EXIT

echo "Removing Frameworks directory"
FRAMEWORKS_DIR=${RV_HOME}/ReleaseVerify-xcframework/Frameworks
rm -rf ${FRAMEWORKS_DIR}/*
rm -rf ~/Library/Developer/Xcode/DerivedData

echo "Verifying XCFramework Enterprise Edition"
download_unzip \
  $LATESTBUILDS_URL/$VERSION/$BUILD/couchbase-lite-swift_xc_enterprise_${VERSION}-${BUILD}.zip \
  $FRAMEWORKS_DIR

download_unzip \
  $LATESTBUILDS_URL/$VERSION/$BUILD/couchbase-lite-objc_xc_enterprise_${VERSION}-${BUILD}.zip \
  $FRAMEWORKS_DIR

verify_xc

echo "Verifying XCFramework Community Edition"
download_unzip \
  $LATESTBUILDS_URL/$VERSION/$BUILD/couchbase-lite-swift_xc_community_${VERSION}-${BUILD}.zip \
  $FRAMEWORKS_DIR

download_unzip \
  $LATESTBUILDS_URL/$VERSION/$BUILD/couchbase-lite-objc_xc_community_${VERSION}-${BUILD}.zip \
  $FRAMEWORKS_DIR

verify_xc

echo "--------------------------------------"
echo "Verification Complete"
echo "VERSION: $VERSION"
echo "BUILD: $BUILD"
echo "$(xcodebuild -version)"

printf '%b\n' "${reports[@]}"
