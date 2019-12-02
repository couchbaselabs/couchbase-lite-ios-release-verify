#!/bin/bash

set -e

function usage
{
  echo "Usage for validating Jenkins build: ${0} -v <Version> -b <Build>"
  echo "Usage for Downloads Page: ${0} -v <Version> -d"
  echo "Usage for Already downloaded builds: ${0} -p <path to builds> -v <Version> -b <Build>"
}

while [[ $# -gt 0 ]]
do
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
      -d)
      DOWNLOADS="YES"
      ;;
      -p)
      FRAMEWORK_PATH=${2}
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

if [ -z "$BUILD" ] && [ -z "$DOWNLOADS" ] && [ -z "$FRAMEWORK_PATH" ]
then
  echo "Error: Please include build number or download flag"
  usage
  exit 4
fi

download_unzip()
{
  # >>>> Fetch Downloads URL / Framework Path
  if [[ "$DOWNLOADS" == "YES" ]]
  then
    # From the Downloads page
    FOLDER=couchbase-lite-${LANG}_${EDITION}_${VERSION}
    URL=https://packages.couchbase.com/releases/couchbase-lite-ios/$VERSION/${FOLDER}.zip
    
  elif [ -z "$FRAMEWORK_PATH" ]
  then
    # From the Jenkins location
    FOLDER=couchbase-lite-${LANG}_${EDITION}_${VERSION}-${BUILD}
    URL=http://172.23.120.24/builds/latestbuilds/couchbase-lite-ios/$VERSION/$BUILD/${FOLDER}.zip
  else
    # From the path
    if [[ "$EDITION" == "community" ]]
    then
      # skip the community since, we end up not verifying the community version
      continue
    fi
    FOLDER=couchbase-lite-${LANG}_${EDITION}_${VERSION}-${BUILD}
    URL=$FRAMEWORK_PATH/${FOLDER}.zip
  fi

  # >>>> Unzip
  if [ -z "$FRAMEWORK_PATH" ]
  then
    echo "Downloading: $URL"
    curl -O $URL
    echo "Unzipping..."
    mkdir ${BASEDIR}/../$FOLDER
    unzip ${FOLDER}.zip -d ${BASEDIR}/../${FOLDER}
    rm -rf ${FOLDER}.zip
  else
    mkdir ${BASEDIR}/../$FOLDER
    unzip ${URL} -d ${BASEDIR}/../${FOLDER}
  fi
}

verify_version()
{
  echo "Verifying Info Plist"
  EXTRACTED_VERSION=$(plutil -extract CFBundleShortVersionString xml1 -o - ${BASEDIR}/../$FOLDER/iOS/${FRAMEWORK_NAME}/Info.plist | sed -n "s/.*<string>\(.*\)<\/string>.*/\1/p")
  if [[ (-z $EXTRACTED_VERSION) || ("$EXTRACTED_VERSION" != "$VERSION") ]]
  then
  echo "Version Mismatch Error!!! Extracted as $EXTRACTED_VERSION but expected $VERSION => path is ${BASEDIR}/../$FOLDER/${DEVICE_SUBFOLDER_NAME}/${FRAMEWORK_NAME}/Info.plist"
  exit 4
  fi
  echo "Successfully verified the version!"
}

# ------------------------------
# START SCRIPT HERE
# ------------------------------
echo "Starting to verify..."

BASEDIR=$(dirname "$0")
declare -a langs=("swift" "objc")
declare -a edition=("enterprise" "community")

declare -a reports
for LANG in "${langs[@]}"
do
  for EDITION in "${edition[@]}"
  do
  
    # download and unzip if necessary
    download_unzip

    # variable declaration
    PROJECT_NAME="ReleaseVerify-binary"
    PROJECT_PATH="${BASEDIR}/../ReleaseVerify/${PROJECT_NAME}"
    
    declare -a devices=("ios" "macos")
    for DEVICE in "${devices[@]}"
    do
      
      # >>>> Product Name
      FRAMEWORK_NAME="CouchbaseLite.framework"
      if [[ "$LANG" == "swift" ]]
      then
        FRAMEWORK_NAME="CouchbaseLiteSwift.framework"
      fi

      # set destination and verify version
      DEVICE_SUBFOLDER_NAME="macOS"
      DESTINATION="platform=OS X"
      if [[ "$DEVICE" == "ios" ]]
      then
        DESTINATION="platform=iOS Simulator,name=iPhone 11"
        DEVICE_SUBFOLDER_NAME="iOS"
        
        verify_version
      fi

      # VERIFY THROUGH RELEASE-PROJECT
      XCPROJECT="${PROJECT_PATH}/${PROJECT_NAME}.xcodeproj"
      XCSCHEME="${PROJECT_NAME}-${LANG}-${DEVICE}-tests"
  
      # COPY FRAMEWORKS TO PROJECT
      rm -rf "${PROJECT_PATH}/Frameworks/${FRAMEWORK_NAME}"
      cp -Rv "${BASEDIR}/../$FOLDER/${DEVICE_SUBFOLDER_NAME}/${FRAMEWORK_NAME}" \
        "${PROJECT_PATH}/Frameworks/${FRAMEWORK_NAME}"
  
      # XCODE TEST!!
      xcodebuild test \
        -project $XCPROJECT \
        -scheme $XCSCHEME \
        -destination "$DESTINATION" \
        "ONLY_ACTIVE_ARCH=NO" "BITCODE_GENERATION_MODE=bitcode" \
        "CODE_SIGNING_REQUIRED=NO" "CODE_SIGN_IDENTITY=" "-quiet"
      if [[ $? == 0 ]]
      then
          reports+=( "\xE2\x9C\x94 ${DEVICE}-${LANG}-${EDITION}" )
      else
          echo "Test Failed!!!"
          reports+=( "x ${DEVICE}-${LANG}-${EDITION}" )
      fi
    done
    
    # REMOVE ALL RELATED FILES
    rm -rf ${FOLDER}
    rm -rf ${BASEDIR}/../${FOLDER}
    rm -rf "${PROJECT_PATH}/Frameworks/${FRAMEWORK_NAME}"
  done
done

if [[ "$DOWNLOADS" == "YES" ]]
then
   FROM="Downloads Page"
elif [ -z "$FRAMEWORK_PATH" ]
then
  FROM="Jenkins(http://172.23.120.24/builds/latestbuilds/couchbase-lite-ios/)"
else
  FROM="Folder."
fi

echo "--------------------------------------"
echo "Completed Verifying"
echo "FROM: $FROM"
echo "VERSION: $VERSION"
echo "BUILD: $BUILD"
echo "$(xcodebuild -version)"

printf '%b\n' "${reports[@]}"
