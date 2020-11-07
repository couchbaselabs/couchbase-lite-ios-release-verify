# Couchbase-lite-ios-release-verify
This project can be used to verify the release builds. 

## Jenkins 
- `sh verify.sh -v <Version> -b <buildNumber>`. 

For example, `sh verify.sh -v 2.6.0 -b 137`

## Result
<img width="375" alt="Jenkins" src="https://user-images.githubusercontent.com/10448770/60638763-84e8fd00-9dd4-11e9-859c-4d64d7ba3cd2.png">

## Downloads Page
- `sh verify.sh -v <version> --downloads`. 

For example, `sh verify.sh -v 2.6.3 --downloads`

## Result
![Downloads](https://user-images.githubusercontent.com/10448770/70014284-2d8bbc00-152f-11ea-81b7-85466bdbe0b4.png)

## Cocoapod Verification 
- `sh Scripts/verify_cocoapod.sh -v <version>`. 
- `sh Scripts/verify_cocoapod.sh -spec <folder to all local specs>`. 

#### For example:
* `sh Scripts/verify_cocoapod.sh -v 2.6.3`
* `sh Scripts/verify_cocoapod.sh -v 2.6.3 --excludeArch`
* `sh Scripts/verify_cocoapod.sh -spec ~/Documents/cbl_test/CBL_Test_Framework/`

## Results
<img width="288" alt="cocoapod" src="https://user-images.githubusercontent.com/10448770/69828963-e15d1680-11d2-11ea-9754-c7ddcf3590fa.png">

## Carthage Verification 
- `sh Scripts/verify.sh -v <version> --carthage`. 

For example, `sh Scripts/verify.sh -v 2.6.3 --carthage`

## Results
![carthage](https://user-images.githubusercontent.com/10448770/70013971-39c34980-152e-11ea-90c8-9b277c12e593.png)
