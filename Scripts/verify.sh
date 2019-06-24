#!/bin/bash

function usage
{
  echo "Usage: ${0} -v <Version> -b <Build>"
}


while getopts v:b: option
do
  case "${option}"
    in
    v) VERSION=${OPTARG};;
    b) BUILD=${OPTARG};;
  esac
done


if [ -z "$VERSION" ]
then
  echo "Error: Please include version"
  usage
  exit 4
fi

if [ -z "$BUILD" ]
then
  echo "Error: Please include build"
  usage
  exit 4
fi

# ------------------------------

echo "Starting to verify..."
declare -a langs=("swift" "objc")
declare -a edition=("enterprise" "community")
declare -a reports
for LANG in "${langs[@]}"
do
  for EDITION in "${edition[@]}"
  do
    FILE=couchbase-lite-${LANG}_${EDITION}_${VERSION}-${BUILD}
    URL=http://172.23.120.24/builds/latestbuilds/couchbase-lite-ios/$VERSION/$BUILD/${FILE}.zip

#    echo "Downloading: $URL"
#    curl -O $URL
#    echo "Unzipping..."
#    mkdir $FILE
#    unzip ${FILE}.zip -d ${PWD}/${FILE}

# ------------------------------ VERIFY INFO PLIST
    echo "Verifying Info Plist"

    if [[ "$LANG" == "swift" ]]
    then
      EXTRACTED_VERSION=$(plutil -extract CFBundleShortVersionString xml1 -o - ${PWD}/$FILE/iOS/CouchbaseLiteSwift.framework/Info.plist | sed -n "s/.*<string>\(.*\)<\/string>.*/\1/p")
    else
      EXTRACTED_VERSION=$(plutil -extract CFBundleShortVersionString xml1 -o - ${PWD}/$FILE/iOS/CouchbaseLite.framework/Info.plist | sed -n "s/.*<string>\(.*\)<\/string>.*/\1/p")
    fi

    if [[ (-z $EXTRACTED_VERSION) || ("$EXTRACTED_VERSION" != "$VERSION") ]]
    then
      echo "Version Mismatch Error!!! Extracted as $EXTRACTED_VERSION but expected $VERSION"
    exit 4
    fi
    echo "Successfully verified the version!"


# ------------------------------ RELEASE VERIFICATION PROJECT
    echo "Verifying release verification project"
    declare -a devices=("ios" "macos")
    for DEVICE in "${devices[@]}"
    do
        if [[ "$DEVICE" == "ios" ]]
        then
          DESTINATION="platform=iOS Simulator,name=iPhone 7"
        else
          DESTINATION="platform=OS X"
        fi


        PROJECT="${PWD}/ReleaseVerify/ReleaseVerify-${DEVICE}-${LANG}/ReleaseVerify-${DEVICE}-${LANG}.xcodeproj"
        SCHEME="ReleaseVerify-${DEVICE}-${LANG}Tests"

        RESULT=$(xcodebuild test -project $PROJECT -scheme $SCHEME -destination "$DESTINATION")
        if (( !$RESULT ))
        then
          echo "Test Failed!!!"
          exit 4
        else
          reports+=( "${DEVICE}-${LANG}-${EDITION}" )
        fi
    done

# ------------------------------ REMOVE ALL RELATED FILES
    echo "Removing: ${FILE} and ${FILE}.zip"
    rm -rf $FILE
    rm -rf ${FILE}.zip
  done
done

echo "Finished verifying!"
printf '\xE2\x9C\x94 %b\n' "${reports[@]}"
