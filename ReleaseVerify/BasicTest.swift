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
    var repl: Replicator!

    override func setUp() {
//        Database.log.console.level = .debug
//        Database.log.console.domains = .all
        
        try! Database.delete(withName: dbName, inDirectory: nil)
        
        db = try! Database(name: dbName, config: DatabaseConfiguration.init())
        NSLog("Database: %@", db.path!)
    }
    
    override func tearDown() {
        repl = nil

        try! db.close()
        db = nil
    }

    func test() {
        let doc = MutableDocument()
        NSLog("Document: %@", doc.id)
        doc.setValue("Pasin", forKey: "firstname")
        doc.setValue("Suriyentrakorn", forKey: "lastname")
        
        let str = "CouchbaseLite 2.0"
        let data = str.data(using: .utf8)
        doc.setValue(Blob(contentType: "text/plain", data: data!), forKey: "blob")
        
        do {
            try db.saveDocument(doc)
            NSLog("Successfully saving the document")
        } catch let error as NSError {
            NSLog("Error saving document: %@", error)
        }
        
        runReplicator()
    }
    
    func runReplicator() {
        let x = self.expectation(description: "change")
        let endpoint = URLEndpoint.init(url: URL.init(string: "ws://localhost:4984/\(dbName)")!)
        let replConfig = ReplicatorConfiguration.init(database: db, target: endpoint)
        repl = Replicator.init(config: replConfig)
        
        let token = repl.addChangeListener { (change) in
            let status = change.status
            if status.activity == .stopped {
                x.fulfill()
            }
        }
        
        repl.start()
        wait(for: [x], timeout: 10.0)
        
        repl.removeChangeListener(withToken: token)
    }

}
