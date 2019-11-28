#!/bin/bash

set -e

function usage
{
  echo "Usage: ${0} -v <Version>"
}

while [[ $# -gt 0 ]]
do
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

if [ -z "$VERSION" ]
then
  echo "Error: Please include version"
  usage
  exit 4
fi

# ------------------------------
echo "Starting to verify $VERSION..."

BASEDIR=$(dirname "$0")
PROJ_PREFIX="ReleaseVerify-cocoapod"

# combinations
declare -a langs=("swift" "objc")
declare -a editions=("enterprise" "community")
declare -a destinations=("ios" "macos")

declare -a reports # for printing report at end
for LANGUAGE in "${langs[@]}"
do
  for EDITION in "${editions[@]}"
  do
    for DESTIN in "${destinations[@]}"
    do

      # all variables
      PROJECT_NAME="$PROJ_PREFIX"
      PROJECT_PATH="${BASEDIR}/../ReleaseVerify/$PROJECT_NAME"
      XCWORKSPACE=$PROJECT_PATH/$PROJECT_NAME.xcworkspace/
      XCSCHEME="${PROJECT_NAME}-$DESTIN-$LANGUAGE-tests"
      PODFILE="$PROJECT_PATH/Podfile"
      
      # create product name
      PRODUCT="CouchbaseLite"
      if [[ "$LANGUAGE" == "swift" ]]
      then
        PRODUCT="$PRODUCT-Swift"
      fi
      
      if [[ "$EDITION" == "enterprise" ]]
      then
        PRODUCT="$PRODUCT-Enterprise"
      fi
      
      # destination
      if [[ "$DESTIN" == "ios" ]]
      then
        DESTINATION="platform=iOS Simulator,name=iPhone 8"
      else
        DESTINATION="generic/platform=OS X"
      fi
      
      # platform
      if [[ "$DESTIN" == "ios" ]]
      then
        PLATFORM="ios, '13.0'"
      else
        PLATFORM="osx, '10.11'"
      fi
      
      # create and populate Podfile
      rm -rf $PODFILE
      echo "  platform :$PLATFORM " >> $PODFILE
      echo "target '$XCSCHEME' do" >> $PODFILE
      echo "  use_frameworks!" >> $PODFILE
      echo "  pod '$PRODUCT', '$VERSION'" >> $PODFILE
      echo "end" >> $PODFILE
      
      # pod install
      pushd $PROJECT_PATH
      pod install
      popd
      
      xcodebuild test -workspace $XCWORKSPACE -scheme $XCSCHEME -destination "$DESTINATION" "ONLY_ACTIVE_ARCH=NO" "BITCODE_GENERATION_MODE=bitcode" "CODE_SIGNING_REQUIRED=NO" "CODE_SIGN_IDENTITY=" "-quiet"
      
      if [[ $? == 0 ]]
      then
          reports+=( "\xE2\x9C\x94 ${DESTIN}-${LANGUAGE}-${EDITION}" )
      else
          echo "Test Failed!!!"
          reports+=( "x ${DESTIN}-${LANGUAGE}-${EDITION}" )
      fi
      
      # remove artifacts
      rm -rf $PODFILE
      rm -rf "$PODFILE.lock"
      rm -rf $PROJECT_PATH/Pods
      rm -rf $XCWORKSPACE
    done
  done
done

echo "-------------------------------"
echo "Cocoapod Verification Complete"
echo "VERSION: $VERSION"
echo "Cocoapod: $(pod --version)"
echo "Xcode: $(xcodebuild -version)"
printf '%b\n' "${reports[@]}"
