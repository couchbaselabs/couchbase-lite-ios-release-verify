pipeline {
    agent any
    parameters {
        string(name: 'VERSION', defaultValue: '1.0.0', description: 'Version number for Carthage, CocoaPods, and Downloads verification')
        booleanParam(name: 'RUN_SPM', defaultValue: false, description: 'Check to run ios-spm-verify')
        string(name: 'VS_VERSION', defaultValue: '', description: 'VS version for ios-spm-verify (ONLY required for ios-spm-verify)')
    }
    stages {
        stage('Carthage Verify') {
            steps { 
                build job: 'ios-carthage-verify', parameters: [string(name: 'VERSION', value: params.VERSION)] 
            }
        }
        stage('CocoaPods Verify') {
            steps { 
                build job: 'ios-cocoapods-verify', parameters: [string(name: 'VERSION', value: params.VERSION)] 
            }
        }
        stage('Downloads Verify') {
            steps { 
                build job: 'ios-downloads-verify', parameters: [string(name: 'VERSION', value: params.VERSION)] 
            }
        }
        stage('SPM Verify (Optional)') {
            when {
                expression { params.RUN_SPM }  // Runs only if RUN_SPM is checked
            }
            steps { 
                build job: 'ios-spm-verify', 
                parameters: [
                    string(name: 'VERSION', value: params.VERSION),
                    string(name: 'VS_VERSION', value: params.VS_VERSION)
                ] 
            }
        }
    }
}
