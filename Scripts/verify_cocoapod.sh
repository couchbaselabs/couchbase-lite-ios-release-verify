#!/bin/bash

set -e

function usage
{
  echo "Usage: "
  echo "\t${0} -v <Version> [--excludeArch]"
  echo "\t${0} -spec <path to local podspec> [--excludeArch]"
  echo "\n  --excludeArch\t:\t Excludes the arm64 from the iphone simulator architecture. Remove this when switch to XCFramework"
  echo "\n"
}

while [[ $# -gt 0 ]]
do
  key=${1}
  case $key in
      -v)
      VERSION=${2}
      shift
      ;;
      -spec)
      SPEC=${2}
      shift
      ;;
      --excludeArch)
      EXCLUDE_ARCH=YES
      ;;
      *)
      usage
      exit 3
      ;;
  esac
  shift
done

# require any of these params
if [[ -z "$VERSION" ]] && [[ -z "$SPEC" ]]
then
  usage
  exit 4
fi

# ------------------------------
echo "Starting to verify $VERSION / $SPEC"

echo "Updating repo(pod repo update)..."
pod repo update

BASEDIR=$(dirname "$0")
PROJ_PREFIX="ReleaseVerify-cocoapod"

declare -a reports # for printing report at end

function verify_cocoapod
{
  LANGUAGE=${1}
  EDITION=${2}
  DESTIN=${3}
  
  # all variables
  PROJECT_NAME="$PROJ_PREFIX"
  PROJECT_PATH="${BASEDIR}/../ReleaseVerify/$PROJECT_NAME"
  XCWORKSPACE=$PROJECT_PATH/$PROJECT_NAME.xcworkspace/
  XCSCHEME="${PROJECT_NAME}-$DESTIN-$LANGUAGE-tests"
  PODFILE="$PROJECT_PATH/Podfile"
  TEST_SIMULATOR=$(xcrun xctrace list devices 2>&1 | grep -oE 'iPhone.*?[^\(]+' | head -1 | sed 's/Simulator//g' | awk '{$1=$1;print}')
  
  function cleanup
  {
    # since cocoapod will make changes to the project file, revert it once done.
    git checkout -- $PROJECT_PATH/ReleaseVerify-cocoapod.xcodeproj/project.pbxproj
   
    # remove artifacts
    rm -rf $PROJECT_PATH/Pods
    rm -rf $XCWORKSPACE
    rm -rf $PODFILE
    rm -rf "$PODFILE.lock"
    rm -rf ReleaseVerify/ReleaseVerify-cocoapod/ReleaseVerify-cocoapod.xcodeproj/xcuserdata/
  }
  # in case error happened, do cleanup during exit
  trap cleanup EXIT
  
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
    DESTINATION="platform=iOS Simulator,name=${TEST_SIMULATOR}"
  else
    DESTINATION="platform=macOS,arch=x86_64"
  fi
  
  # platform
  if [[ "$DESTIN" == "ios" ]]
  then
  PLATFORM="ios, '11.0'"
  else
  PLATFORM="macos, '10.14'"
  fi
  
  # create and populate Podfile
  rm -rf $PODFILE
  echo "platform :$PLATFORM " >> $PODFILE
  echo " " >> $PODFILE
  echo "target '$XCSCHEME' do" >> $PODFILE
  echo "  use_frameworks!" >> $PODFILE
  if [[ -z "$SPEC" ]]
  then
    echo "  pod '$PRODUCT', '$VERSION'" >> $PODFILE
  else
    echo "  pod '$PRODUCT', :podspec => '$SPEC'" >> $PODFILE
  fi
  echo "end" >> $PODFILE
  echo " " >> $PODFILE
  
  if [[ ! -z "$EXCLUDE_ARCH" ]]
  then
    echo "post_install do |installer|" >> $PODFILE
    echo "  installer.pods_project.build_configurations.each do |config|" >> $PODFILE
    echo "    config.build_settings[\"EXCLUDED_ARCHS[sdk=iphonesimulator*]\"] = \"arm64\"" >> $PODFILE
    echo "  end" >> $PODFILE
    echo "end" >> $PODFILE
  fi
  
  # pod install
  pushd $PROJECT_PATH
  pod install
  popd
  
  xcodebuild test \
    -workspace $XCWORKSPACE \
    -scheme $XCSCHEME \
    -destination "$DESTINATION" \
    "BITCODE_GENERATION_MODE=bitcode" \
    "CODE_SIGNING_REQUIRED=NO" "CODE_SIGN_IDENTITY=" "-quiet"
  
  if [[ $? == 0 ]]
  then
    reports+=( "\xE2\x9C\x94 ${DESTIN}-${LANGUAGE}-${EDITION}" )
  else
    echo "Test Failed!!!"
    reports+=( "x ${DESTIN}-${LANGUAGE}-${EDITION}" )
  fi
  
  cleanup
}

# verify all combination
verify_cocoapod "swift" "enterprise" "ios"
verify_cocoapod "swift" "enterprise" "macos"
verify_cocoapod "swift" "community" "ios"
verify_cocoapod "swift" "community" "macos"
verify_cocoapod "objc" "enterprise" "ios"
verify_cocoapod "objc" "enterprise" "macos"
verify_cocoapod "objc" "community" "ios"
verify_cocoapod "objc" "community" "macos"

echo "-------------------------------"
echo "Cocoapod Verification Complete"
echo "VERSION: $VERSION"
echo "Cocoapod: $(pod --version)"
echo "Xcode: $(xcodebuild -version)"
printf '%b\n' "${reports[@]}"
