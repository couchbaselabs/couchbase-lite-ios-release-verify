#!/bin/bash
#
# This script will validate XCFramework zip

set -e

BASEDIR=$(dirname "$0")

source ${BASEDIR}/utils.sh
XCHOME="$RV_HOME/ReleaseVerify-xcframework/"

function usage
{
  echo "Usage: sh verify_xc.sh [options]"
  echo "\nMandatory Options: "
  echo "  -l\t Language. Values= 'swift', 'objc'"
  echo "  -arch\t Architecture. Values= 'x86_64', 'arm64'"
  echo "  -sdk\t SDK. Values=  'iphonesimulator', 'macosx'"
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
      -l)
      LANGUAGE=${2}
      shift
      ;;
      -arch)
      ARCH=${2}
      shift
      ;;
      -sdk)
      SDK=${2}
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

if [ -z "$LANGUAGE" ]; then
  echo "Error: Please include language"
  usage
  exit 4
fi

if [ -z "$SDK" ]; then
  echo "Error: Please include SDK"
  usage
  exit 4
fi

if [ -z "$ARCH" ]; then
  echo "Error: Please include ARCH"
  usage
  exit 4
fi

echo "Verifying XCFramework => $LANGUAGE + $SDK + $ARCH"

# TODO: verify plist version

SCHEME="ReleaseVerify-xcframework-${LANGUAGE}"
if [[ "$SDK" == "iphonesimulator" ]]; then
  DESTINATION="$IOS_SIMULATOR_DEST"
  SCHEME="${SCHEME}-ios"
elif [[ "$SDK" == "macosx" ]]; then
  DESTINATION="platform=macOS,arch=$ARCH"
  SCHEME="${SCHEME}-macosx"
fi

echo "Testing on $DESTINATION..."
XCPATH="$XCHOME/ReleaseVerify-xcframework.xcodeproj"
XCARGS="CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= -quiet"
xcodebuild clean test \
  -project $XCPATH \
  -scheme $SCHEME \
  -destination "$DESTINATION" \
  $XCARGS

############  CATALYST
if [[ "$SDK" == "iphonesimulator" ]]; then
  echo "Testing on Catalyst-$IOS_SIMULATOR_DEST..."
  xcodebuild clean test \
    -project $XCPATH \
    -scheme "$SCHEME-catalyst" \
    -destination "$IOS_SIMULATOR_DEST" \
    $XCARGS

  echo "Testing on Catalyst-platform=macOS,arch=$ARCH..."
  xcodebuild clean test \
    -project $XCPATH \
    -scheme "$SCHEME-catalyst" \
    -destination "platform=macOS,arch=$ARCH" \
    $XCARGS
fi
