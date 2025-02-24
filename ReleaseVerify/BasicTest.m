//
//  BasicTest.m
//  ReleaseVerify-iOS-ObjCTests
//
//  Created by Jayahari Vavachan on 6/24/19.
//  Copyright © 2019 Couchbase Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <CouchbaseLite/CouchbaseLite.h>

@interface BasicTest : XCTestCase

@property(nonatomic, strong) CBLDatabase* db;

@end

NSString* dbName = @"release-verification";

@implementation BasicTest

- (void)setUp {
    NSError *error;
    [CBLDatabase deleteDatabase: dbName inDirectory: nil error: &error];
    
    _db = [[CBLDatabase alloc] initWithName: dbName
                                     config: [[CBLDatabaseConfiguration alloc] init]
                                      error: nil];
    
    if (self.db) {
        NSLog(@"Successfully creating database: %@", self.db.path);
    } else {
        NSLog(@"Error Creating database: %@", error);
        return;
    }
}
    
- (void) tearDown {
    NSError* error;
    [self.db close: &error];
    
    _db = nil;
}

- (void) testSave {
    NSError* error;
    CBLCollection* defaultColl = [self.db defaultCollection: &error];
    
    CBLMutableDocument *doc = [[CBLMutableDocument alloc] init];
    NSLog(@"Document: %@", doc.id);
    
    [doc setValue:@"John" forKey:@"firstname"];
    [doc setValue:@"Doe" forKey:@"lastname"];
    
    NSString* str = @"CouchbaseLite Database";
    NSData* data = [str dataUsingEncoding:NSUTF8StringEncoding];
    [doc setValue:[[CBLBlob alloc] initWithContentType:@"text/plain" data:data] forKey:@"blob"];
    
    
    if ([defaultColl saveDocument: doc error: &error]) {
        NSLog(@">>> Successfully saving the document");
    } else {
        NSLog(@"Error saving a document: %@", error);
    }
}

@end
