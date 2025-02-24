//
//  BasicTest.swift
//  ReleaseVerify-iOS-SwiftTests
//
//  Created by Jayahari Vavachan on 6/24/19.
//  Copyright © 2019 Couchbase Inc. All rights reserved.
//

import XCTest
import CouchbaseLiteSwift

class BasicTest: XCTestCase {
    let dbName = "release-verification"
    var db: Database!

    override func setUp() {
        try! Database.delete(withName: dbName, inDirectory: nil)
        
        db = try! Database(name: dbName, config: DatabaseConfiguration.init())
        NSLog("Database: %@", db.path!)
    }
    
    override func tearDown() {
        try! db.close()
        db = nil
    }

    func testSave() {
        let defaultColl = try! self.db.defaultCollection()
        let doc = MutableDocument()
        doc.setValue("John", forKey: "firstname")
        doc.setValue("Doe", forKey: "lastname")
        
        let str = "CouchbaseLite Database"
        let data = str.data(using: .utf8)
        doc.setValue(Blob(contentType: "text/plain", data: data!), forKey: "blob")
        
        do {
            try defaultColl.save(document: doc)
            NSLog(">>>>>> Successfully saving the document");
        } catch let error as NSError {
            XCTFail("Error Saving Document \(error.localizedDescription)");
        }
    }
}
