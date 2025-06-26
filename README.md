# Couchbase-lite-ios-release-verify
This project can be used to verify the release builds.

## Jenkins (latestbuilds)
- `sh Scripts/verify.sh -v <version> -b <buildno>`. 

## Downloads Page
- `sh Scripts/verify.sh -v <version> --downloads`. 

## Carthage Verification 
- `sh Scripts/verify.sh -v <version> --carthage`.

## Cocoapod Verification 
- `sh Scripts/verify_cocoapod.sh -v <version>`.

## Swift Package Verification
- `sh Scripts/verify_spm.sh [-v <Version> | -b <Branch>] [-vs <Vector Search Version> | -vb <Vector Search Branch>]`

See: http://jenkins.mobiledev.couchbase.com/job/validate-ios/
Additional: https://github.com/couchbaselabs/couchbase-lite-ios-release-verify/wiki/Release-process-and-steps
