#!/bin/bash
#
# Validate the Couchbase iOS builds from various sources

function usage
{
  echo "Usage for Validating from Jenkins build: ${0} -v <Version> -b <Build>"
  echo "Usage for Validating from Downloads Page: ${0} -v <Version> --downloads"
  echo "Usage for Validating from Carthage: ${0} -v <Version> --carthage"
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
      --downloads)
      DOWNLOADS="YES"
      ;;
      --carthage)
      CARTHAGE="YES"
      ;;
      *)
      usage
      exit 3
      ;;
  esac
  shift
done

if [ -z "$VERSION" ]; then
  echo "Error: Please include version"
  usage
  exit 4
fi

if [ -z "$BUILD" ] && [ -z "$DOWNLOADS" ] && [ -z "$CARTHAGE" ]; then
  echo "Error: Please include build number or download flag or carthage flag"
  usage
  exit 4
fi

BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

if [[ "$DOWNLOADS" == "YES" ]]; then
  FROM="Downloads Page"
elif [[ "$CARTHAGE" == "YES" ]]; then
  FROM="Carthage"
else
  FROM="Jenkins(http://172.23.120.24/builds/latestbuilds/couchbase-lite-ios/)"
fi

#######################################
# Downloads and unzips the frameworks if necessary
# Arguments:
#   LANGUAGE
#   EDITION
# Globals:
#   FILENAME
#   URL
# Used:
#   DOWNLOADS
#   BASEDIR
#   VERSION
#   BUILD
#######################################
download_unzip()
{
  # >>>> Fetch Downloads URL / Framework Path
  if [[ "$DOWNLOADS" == "YES" ]]; then
    # From the Downloads page
    FILENAME=couchbase-lite-${1}_xc_${2}_${VERSION}
    URL=https://packages.couchbase.com/releases/couchbase-lite-ios/$VERSION/${FILENAME}.zip
  else
    # From the Jenkins location
    FILENAME=couchbase-lite-${1}_xc_${2}_${VERSION}-${BUILD}
    URL=http://latestbuilds.service.couchbase.com/builds/latestbuilds/couchbase-lite-ios/$VERSION/$BUILD/${FILENAME}.zip
  fi
  
  # >>>> Unzip
  echo "Downloading: $URL"
  curl -O $URL
  echo "Unzipping..."
  mkdir "${BASEDIR}/../$FILENAME"
  unzip ${FILENAME}.zip -d ${BASEDIR}/../$FILENAME
  rm -rf ${FILENAME}.zip
}

#######################################
# Verify the info plist version number, from the iOS build.
# Arguments:
#   PLIST_PATH
# Used:
#   BASEDIR
#   FILENAME
#   FRAMEWORK_NAME
#   VERSION
#   DEVICE_SUBFOLDER_NAME
#######################################
verify_version()
{
  echo "Verifying Info Plist : $1"
  local info_ver=$(plutil -extract CFBundleShortVersionString xml1 -o - $1 | sed -n "s/.*<string>\(.*\)<\/string>.*/\1/p")
  if [[ (-z $info_ver) || ("$info_ver" != "$VERSION") ]]; then
    echo "Version Mismatch! extracted($info_ver) & expected($VERSION) => path $1"
    exit 4
  fi
  echo "Successfully verified the version!"
}

#######################################
# Create Cartfile, update carthage and copies framework to Frameworks folder
# Globals:
#   CART_BIN_PATH
# Used:
#   PROJECT_PATH
#   EDITION
#   VERSION
#   DEVICE
#   FRAMEWORK_NAME
#######################################
update_carthage_and_copy()
{
  # create and update carthage
  local cartfile="${PROJECT_PATH}/Cartfile"
  rm -rf $cartfile
  local json="CouchbaseLite-Community.json"
  if [[ "$EDITION" == "enterprise" ]]; then
    json="CouchbaseLite-Enterprise.json"
  fi
  #cloudfront managed packages.couchbase.com might not have the latest immediately, when json is released
  #thus, download from s3 directly to avoid this issue
  curl -O "http://packages.couchbase.com.s3.amazonaws.com/releases/couchbase-lite-ios/carthage/$json"
  echo "binary \"${PWD}/${json}\" == $VERSION" >> $cartfile
  pushd ${PROJECT_PATH}
  carthage update
  popd
  
  # copies the binary to Framework folder
  local subfolder="Mac"
  if [[ "$DEVICE" == "ios" ]]; then
    subfolder="iOS"
  fi
  
  CART_BIN_PATH="${PROJECT_PATH}/Carthage/Build/"
  mkdir -p ${PROJECT_PATH}/Frameworks
  cp -Rv "${CART_BIN_PATH}" "${PROJECT_PATH}/Frameworks/"
}

#######################################
# Removes all script artifacts.
# Used:
#   FILENAME
#   BASEDIR
#   PROJECT_PATH
#   FRAMEWORK_NAME
#   CARTFILE
#   PROJECT_PATH
#######################################
cleanup()
{
  if [ -z "$CARTHAGE" ]; then
    rm -rf couchbase-lite-swift_xc*.zip
    rm -rf couchbase-lite-objc_xc*.zip
    rm -rf "${BASEDIR}/.."/couchbase-lite-swift_xc*
    rm -rf "${BASEDIR}/.."/couchbase-lite-objc_xc*
  else
    rm -rf "${PROJECT_PATH}/Cartfile"
    rm -rf "${PROJECT_PATH}/Cartfile.resolved"
    rm -rf "${PROJECT_PATH}/Carthage"
  fi
  rm -rf "${PROJECT_PATH}/Frameworks/${FRAMEWORK_NAME}"
}

# ------------------------------
# START SCRIPT HERE
# ------------------------------
echo "Starting to verify..."

# cleanup in case any error happened in the script
trap cleanup EXIT

declare -a langs=("swift" "objc")
declare -a edition=("enterprise" "community")
declare -a reports

TEST_SIMULATOR=$(xcrun xctrace list devices 2>&1 | grep -oE 'iPhone.*?[^\(]+' | head -1 | sed 's/Simulator//g' | awk '{$1=$1;print}')

for EDITION in "${edition[@]}"; do
  PROJECT_NAME="ReleaseVerify-binary"
  PROJECT_PATH="${BASEDIR}/../ReleaseVerify/${PROJECT_NAME}"
  # download and unzip if necessary(not if carthage)
  if [ -z "$CARTHAGE" ]; then
    FR_PATH="${BASEDIR}/../ReleaseVerify/ReleaseVerify-binary/Frameworks"
    rm -rf "${FR_PATH}/*"
    
    # download and verify version - swift
    echo "downloading swift..."
    download_unzip swift $EDITION
    
    echo "verifying swift version..."
    PLIST="${BASEDIR}/../$FILENAME/CouchbaseLiteSwift.xcframework/ios-arm64/CouchbaseLiteSwift.framework/Info.plist"
    verify_version $PLIST
    
    echo "copying swift..."
    cp -Rv "${BASEDIR}/../$FILENAME/" "${FR_PATH}/"
    
    # download and verify version - objc
    echo "downloading objc..."
    download_unzip objc $EDITION
    
    echo "verifying objc version..."
    PLIST="${BASEDIR}/../$FILENAME/CouchbaseLite.xcframework/ios-arm64/CouchbaseLite.framework/Info.plist"
    verify_version $PLIST
    
    echo "copying objc..."
    cp -Rv "${BASEDIR}/../$FILENAME/" "${FR_PATH}/"
  else
    # CARTHAGE
    update_carthage_and_copy

    # FIXME: current script is creating Carthage with wrong version
    # PLIST=${CART_BIN_PATH}/Info.plist
    # verify_version $PLIST
  fi

  for LANG in "${langs[@]}"; do
    declare -a devices=("ios" "macos")
    for DEVICE in "${devices[@]}"; do
      
      # Product Name
      NAME="CouchbaseLite"
      if [[ "$LANG" == "swift" ]]; then
        NAME="CouchbaseLiteSwift"
      fi
      FRAMEWORK_NAME="${NAME}.xcframework"

      # VERIFY THROUGH RELEASE-PROJECT
      XCPROJECT="${PROJECT_PATH}/${PROJECT_NAME}.xcodeproj"
      XCSCHEME="${PROJECT_NAME}-${LANG}-${DEVICE}-tests"
      
      # set destination
      DESTINATION="platform=OS X"
      if [[ "$DEVICE" == "ios" ]]; then
        DESTINATION="platform=iOS Simulator,name=${TEST_SIMULATOR}"
      fi
  
      # XCODE TEST!!
      xcodebuild test \
        -project $XCPROJECT \
        -scheme $XCSCHEME \
        -destination "$DESTINATION" \
        "CODE_SIGNING_REQUIRED=NO" "CODE_SIGN_IDENTITY=" "-quiet"
        
      if [[ $? == 0 ]]; then
          reports+=( "\xE2\x9C\x94 ${DEVICE}-${LANG}-${EDITION}" )
      else
          echo "Test Failed!!!"
          reports+=( "x ${DEVICE}-${LANG}-${EDITION}" )
      fi
    done
  done
  cleanup
done

echo "--------------------------------------"
echo "Verification Complete"
echo "FROM: $FROM"
echo "VERSION: $VERSION"
echo "BUILD: $BUILD"
echo "$(xcodebuild -version)"
echo "Carthage: $(carthage version)"

printf '%b\n' "${reports[@]}"
