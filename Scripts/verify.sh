#!/bin/bash

function usage
{
  echo "Usage for validating Jenkins build: ${0} -v <Version> -b <Build>"
  echo "Usage for Downloads Page: ${0} -v <Version> -d"
}


while getopts v:b:d option
do
  case "${option}"
    in
    v) VERSION=${OPTARG};;
    b) BUILD=${OPTARG};;
    d) DOWNLOADS="YES";;
  esac
done

if [ -z "$VERSION" ]
then
  echo "Error: Please include version"
  usage
  exit 4
fi

if [ -z "$BUILD" ] && [ -z "$DOWNLOADS" ]
then
  echo "Error: Please include build number or download flag"
  usage
  exit 4
fi


# ------------------------------
BASEDIR=$(dirname "$0")
echo "Starting to verify..."
declare -a langs=("swift" "objc")
declare -a edition=("enterprise" "community")
declare -a reports
for LANG in "${langs[@]}"
do
  for EDITION in "${edition[@]}"
  do
    if [ -z "$DOWNLOADS" ]
    then
      FOLDER=couchbase-lite-${LANG}_${EDITION}_${VERSION}-${BUILD}
      URL=http://172.23.120.24/builds/latestbuilds/couchbase-lite-ios/$VERSION/$BUILD/${FOLDER}.zip
    else
      FOLDER=couchbase-lite-${LANG}_${EDITION}_${VERSION}
      URL=https://packages.couchbase.com/releases/couchbase-lite-ios/$VERSION/${FOLDER}.zip
    fi

    echo "Downloading: $URL"
    curl -O $URL
    echo "Unzipping..."
    mkdir $FOLDER
    unzip ${FOLDER}.zip -d ${BASEDIR}/../${FOLDER}
    rm -rf ${FOLDER}.zip

    declare -a devices=("ios" "macos")
    for DEVICE in "${devices[@]}"
    do
      if [[ "$LANG" == "swift" ]]
      then
        FRAMEWORK_NAME="CouchbaseLiteSwift.framework"

      else
        FRAMEWORK_NAME="CouchbaseLite.framework"
      fi

      if [[ "$DEVICE" == "ios" ]]
      then
        DESTINATION="platform=iOS Simulator,name=iPhone 7"
        DEVICE_SUBFOLDER_NAME="iOS"

        # ------------------------------ VERIFY INFO PLIST
        echo "Verifying Info Plist"
        EXTRACTED_VERSION=$(plutil -extract CFBundleShortVersionString xml1 -o - ${BASEDIR}/../$FOLDER/iOS/${FRAMEWORK_NAME}/Info.plist | sed -n "s/.*<string>\(.*\)<\/string>.*/\1/p")

        if [[ (-z $EXTRACTED_VERSION) || ("$EXTRACTED_VERSION" != "$VERSION") ]]
        then
        echo "Version Mismatch Error!!! Extracted as $EXTRACTED_VERSION but expected $VERSION => path is ${BASEDIR}/../$FOLDER/${DEVICE_SUBFOLDER_NAME}/${FRAMEWORK_NAME}/Info.plist"
        exit 4
        fi
        echo "Successfully verified the version!"
      else
        DEVICE_SUBFOLDER_NAME="macOS"
        DESTINATION="platform=OS X"
      fi


    # ------------------------------
    # ------------------------------ VERIFY THROUGH RELEASE-PROJECT
    # ------------------------------
      PROJECT="${BASEDIR}/../ReleaseVerify/ReleaseVerify-${DEVICE}-${LANG}/ReleaseVerify-${DEVICE}-${LANG}.xcodeproj"
      SCHEME="ReleaseVerify-${DEVICE}-${LANG}Tests"

    # ------------------------------ COPY FRAMEWORKS TO PROJECT
      cp -Rv "${BASEDIR}/../$FOLDER/${DEVICE_SUBFOLDER_NAME}/${FRAMEWORK_NAME}" ${BASEDIR}/../ReleaseVerify/ReleaseVerify-${DEVICE}-${LANG}/Frameworks/${FRAMEWORK_NAME}

    # ------------------------------ XCODE BUILD TEST PROJECT
      xcodebuild test -project $PROJECT -scheme $SCHEME -destination "$DESTINATION" "ONLY_ACTIVE_ARCH=NO" "BITCODE_GENERATION_MODE=bitcode" "CODE_SIGNING_REQUIRED=NO" "CODE_SIGN_IDENTITY=" "-quiet"
      if [[ $? == 0 ]]
      then
          reports+=( "\xE2\x9C\x94 ${DEVICE}-${LANG}-${EDITION}" )
      else
          echo "Test Failed!!!"
          reports+=( "x ${DEVICE}-${LANG}-${EDITION}" )
      fi
    done
    # ------------------------------ REMOVE ALL RELATED FILES
    rm -rf ${FOLDER}
    rm -rf ${BASEDIR}/../${FOLDER}
    rm -rf ${BASEDIR}/../ReleaseVerify/ReleaseVerify-ios-${LANG}/Frameworks/${FRAMEWORK_NAME}
    rm -rf ${BASEDIR}/../ReleaseVerify/ReleaseVerify-macos-${LANG}/Frameworks/${FRAMEWORK_NAME}
  done
done

if [ -z "$DOWNLOADS" ]
then
  echo "Finished verifying Build: ${VERSION}(${BUILD}) from Jenkins"
else
  echo "Finished verifying Build: ${VERSION} from Downloads page "
fi
printf '%b\n' "${reports[@]}"
