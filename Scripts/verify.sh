#!/bin/bash
#
# Validate the Couchbase iOS builds from various sources

set -e

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

#######################################
# Downloads and unzips the frameworks if necessary
# Globals:
#   FILENAME
#   URL
# Used:
#   DOWNLOADS
#   BASEDIR
#   LANG
#   EDITION
#   VERSION
#   BUILD
#######################################
download_unzip()
{
  # >>>> Fetch Downloads URL / Framework Path
  if [[ "$DOWNLOADS" == "YES" ]]; then
    # From the Downloads page
    FILENAME=couchbase-lite-${LANG}_${EDITION}_${VERSION}
    URL=https://packages.couchbase.com/releases/couchbase-lite-ios/$VERSION/${FILENAME}.zip
  else
    # From the Jenkins location
    FILENAME=couchbase-lite-${LANG}_${EDITION}_${VERSION}-${BUILD}
    URL=http://172.23.120.24/builds/latestbuilds/couchbase-lite-ios/$VERSION/$BUILD/${FILENAME}.zip
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
  echo "Verifying Info Plist"
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
  echo "binary \"https://packages.couchbase.com/releases/couchbase-lite-ios/carthage/$json\" == $VERSION" >> $cartfile
  pushd ${PROJECT_PATH}
  carthage update
  popd
  
  # copies the binary to Framework folder
  local subfolder="Mac"
  if [[ "$DEVICE" == "ios" ]]; then
    subfolder="iOS"
  fi
  CART_BIN_PATH="${PROJECT_PATH}/Carthage/Build/${subfolder}/${FRAMEWORK_NAME}"
  cp -Rv "${CART_BIN_PATH}" "${PROJECT_PATH}/Frameworks/${FRAMEWORK_NAME}"
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
    rm -rf ${FILENAME}
    rm -rf ${BASEDIR}/../${FILENAME}
  else
    rm -rf ${PROJECT_PATH}/Cartfile
    rm -rf ${PROJECT_PATH}/Cartfile.resolved
    rm -rf ${PROJECT_PATH}/Carthage
  fi
  rm -rf "${PROJECT_PATH}/Frameworks/${FRAMEWORK_NAME}"
}

# ------------------------------
# START SCRIPT HERE
# ------------------------------
echo "Starting to verify..."

BASEDIR=$(dirname "$0")
declare -a langs=("swift" "objc")
declare -a edition=("enterprise" "community")

declare -a reports
for LANG in "${langs[@]}"; do
  for EDITION in "${edition[@]}"; do
  
    # download and unzip if necessary(not if carthage)
    if [ -z "$CARTHAGE" ]; then
      download_unzip
    fi

    # variable declaration
    PROJECT_NAME="ReleaseVerify-binary"
    PROJECT_PATH="${BASEDIR}/../ReleaseVerify/${PROJECT_NAME}"
    
    declare -a devices=("ios" "macos")
    for DEVICE in "${devices[@]}"; do
      
      # Product Name
      FRAMEWORK_NAME="CouchbaseLite.framework"
      if [[ "$LANG" == "swift" ]]; then
        FRAMEWORK_NAME="CouchbaseLiteSwift.framework"
      fi

      # VERIFY THROUGH RELEASE-PROJECT
      XCPROJECT="${PROJECT_PATH}/${PROJECT_NAME}.xcodeproj"
      XCSCHEME="${PROJECT_NAME}-${LANG}-${DEVICE}-tests"
      
      # set destination
      DESTINATION="platform=OS X"
      if [[ "$DEVICE" == "ios" ]]; then
        DESTINATION="platform=iOS Simulator,name=iPhone 11"
      fi
  
      # COPY FRAMEWORKS TO PROJECT
      rm -rf "${PROJECT_PATH}/Frameworks/${FRAMEWORK_NAME}"
      if [ -z "$CARTHAGE" ]; then
        DEVICE_SUBFOLDER_NAME="macOS"
        if [[ "$DEVICE" == "ios" ]]; then
          DEVICE_SUBFOLDER_NAME="iOS"
        fi
      
        PLIST=${BASEDIR}/../$FILENAME/iOS/${FRAMEWORK_NAME}/Info.plist
        verify_version $PLIST
        
        cp -Rv "${BASEDIR}/../$FILENAME/${DEVICE_SUBFOLDER_NAME}/${FRAMEWORK_NAME}" \
          "${PROJECT_PATH}/Frameworks/${FRAMEWORK_NAME}"
      else
        # CARTHAGE
        update_carthage_and_copy
        
        # FIXME: current script is creating Carthage with wrong version
        # PLIST=${CART_BIN_PATH}/Info.plist
        # verify_version $PLIST
      fi
      
  
      # XCODE TEST!!
      xcodebuild test \
        -project $XCPROJECT \
        -scheme $XCSCHEME \
        -destination "$DESTINATION" \
        "ONLY_ACTIVE_ARCH=NO" "BITCODE_GENERATION_MODE=bitcode" \
        "CODE_SIGNING_REQUIRED=NO" "CODE_SIGN_IDENTITY=" "-quiet"
      if [[ $? == 0 ]]; then
          reports+=( "\xE2\x9C\x94 ${DEVICE}-${LANG}-${EDITION}" )
      else
          echo "Test Failed!!!"
          reports+=( "x ${DEVICE}-${LANG}-${EDITION}" )
      fi
    done
    
    cleanup
  done
done

if [[ "$DOWNLOADS" == "YES" ]]; then
  FROM="Downloads Page"
elif [[ "$CARTHAGE" == "YES" ]]; then
  FROM="Carthage"
else
  FROM="Jenkins(http://172.23.120.24/builds/latestbuilds/couchbase-lite-ios/)"
fi

echo "--------------------------------------"
echo "Verification Complete"
echo "FROM: $FROM"
echo "VERSION: $VERSION"
echo "BUILD: $BUILD"
echo "$(xcodebuild -version)"
echo "Carthage: $(carthage version)"

printf '%b\n' "${reports[@]}"
