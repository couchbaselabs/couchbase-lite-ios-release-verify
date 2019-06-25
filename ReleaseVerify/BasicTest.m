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

@property(nonatomic, strong) CBLReplicator* repl;
@property(nonatomic, strong) CBLDatabase* db;

@end

NSString* dbName = @"release-verification";

@implementation BasicTest

- (void)setUp {
//    CBLDatabase.log.console.level = kCBLLogLevelDebug;
    
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

- (void) test {
    CBLMutableDocument *doc = [[CBLMutableDocument alloc] init];
    NSLog(@"Document: %@", doc.id);
    
    [doc setValue:@"Pasin" forKey:@"firstname"];
    [doc setValue:@"Suriyentrakorn" forKey:@"lastname"];
    
    NSString* str = @"CouchbaseLite 2.0";
    NSData* data = [str dataUsingEncoding:NSUTF8StringEncoding];
    [doc setValue:[[CBLBlob alloc] initWithContentType:@"text/plain" data:data] forKey:@"blob"];
    
    NSError* error;
    if ([self.db saveDocument: doc error: &error]) {
        NSLog(@"Successfully saving the document");
    } else {
        NSLog(@"Error saving a document: %@", error);
    }
    
    [self run];
}

- (SecCertificateRef) sslCert {
    NSData* certData = [self dataFromResource: @"SelfSigned" ofType: @"cer"];
    SecCertificateRef cert = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)certData);
    return (SecCertificateRef)CFAutorelease(cert);
}

- (NSData*) dataFromResource: (NSString*)res ofType: (NSString*)type {
    NSString* path = [[NSBundle bundleForClass: [self class]] pathForResource: res
                                                                       ofType: type];
    NSData* contents = [NSData dataWithContentsOfFile: path
                                              options: 0
                                                error: NULL];
    return contents;
}

- (void) run {
    XCTestExpectation* x = [self expectationWithDescription: @"Replicator Stopped"];
    CBLURLEndpoint *endpoint = [[CBLURLEndpoint alloc] initWithURL: [NSURL URLWithString: @"ws://localhost:4984/release-verification"]];
    CBLReplicatorConfiguration *config = [[CBLReplicatorConfiguration alloc] initWithDatabase: self.db
                                                                                       target: endpoint];
    _repl = [[CBLReplicator alloc] initWithConfig: config];
    id token = [_repl addChangeListener: ^(CBLReplicatorChange* change) {
        if (change.status.activity == kCBLReplicatorStopped) {
            [x fulfill];
        }
    }];
    
    [_repl start];
    
    [self waitForExpectations: @[x] timeout: 5.0];
}

@end
