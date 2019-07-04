# Couchbase-lite-ios-release-verify
This project can be used to verify the release builds. 

## Steps (you need to be on VPN)
1. Clone the repo. 
2. `cd couchbase-lite-ios-release-verify/Scripts`
3. Verify the Jenins/Downloads-page build 
    - Jenkins build: `sh verify.sh -v <Version> -b <buildNumber>`. For example, `sh verify.sh -v 2.6.0 -b 137`
    - Downloads page build: `sh verify.sh -v <version> -d`. For example, `sh verify.sh -v 2.5.2 -d`

## Result
<img width="445" alt="Downloads" src="https://user-images.githubusercontent.com/10448770/60638762-84e8fd00-9dd4-11e9-8b22-6f9e113e18d1.png">
<img width="375" alt="Jenkins" src="https://user-images.githubusercontent.com/10448770/60638763-84e8fd00-9dd4-11e9-859c-4d64d7ba3cd2.png">

