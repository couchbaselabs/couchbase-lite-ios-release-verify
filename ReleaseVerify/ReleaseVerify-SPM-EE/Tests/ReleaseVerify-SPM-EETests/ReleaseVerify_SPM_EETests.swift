import XCTest
import CouchbaseLiteSwift

@testable import ReleaseVerify_SPM_EE

final class ReleaseVerify_SPM_EETests: XCTestCase {
    let directory = NSTemporaryDirectory().appending("CBLSPMTest-EE")
    let dbName = "release-verification"
    var db: Database!

    override func setUp() {
        let dir = self.directory
        if FileManager.default.fileExists(atPath: dir) {
            try! FileManager.default.removeItem(atPath: dir)
        }
        FileManager.default.fileExists(atPath: dir)
        
        try! Extension.enableVectorSearch()

        var config = DatabaseConfiguration()
        config.directory = dir
        try! db = Database.init(name: "db", config: config)
        
        NSLog("Database: %@", db.path!)
    }
    
    override func tearDown() {
        try! db.close()
        db = nil
    }

    func testSave() {
        let doc = MutableDocument()
        doc.setValue("John", forKey: "firstname")
        doc.setValue("Doe", forKey: "lastname")
        
        let str = "CouchbaseLite Database"
        let data = str.data(using: .utf8)
        doc.setValue(Blob(contentType: "text/plain", data: data!), forKey: "blob")
        
        do {
            try db.defaultCollection().save(document: doc)
        } catch let error as NSError {
            XCTFail("Error Saving Document \(error.localizedDescription)");
        }
    }
}
