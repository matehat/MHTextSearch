//
//  iOS_Tests.m
//  iOS Tests
//
//  Created by Mathieu D'Amours on 1/14/14.
//
//

#import <XCTest/XCTest.h>
#import <BlocksKit.h>
#import <MHTextSearch/MHSearchResultItem.h>
#import <MHTextSearch/MHTextFragment.h>
#import <MHTextSearch/MHTextIndex.h>

@interface iOS_Tests : XCTestCase

@end

@implementation iOS_Tests {
    MHTextIndex *index;
    NSArray *names;
}

- (void)setUp {
    [super setUp];
    index = [MHTextIndex textIndexInLibraryWithName:@"testIndex"];
    [index deleteFromDisk];
    
    index = [MHTextIndex textIndexInLibraryWithName:@"testIndex"];
    
    NSString *path = [[NSBundle bundleForClass:[iOS_Tests class]] pathForResource:@"Names" ofType:@"txt"];
    NSString *namesRaw = [NSString stringWithContentsOfFile:path
                                                   encoding:NSUTF8StringEncoding
                                                      error:NULL];
    names = [namesRaw componentsSeparatedByString:@"\n"];
    
    __weak iOS_Tests *_wself = self;
    [index setIdentifier:^NSData *(id object){
        NSUInteger indexVal = [object integerValue];
        return [NSData dataWithBytes:&indexVal length:sizeof(NSUInteger)];
    }];
    [index setObjectGetter:^id(NSData *identifier){
        NSUInteger nameIndex = 0;
        [identifier getBytes:&nameIndex];
        __strong iOS_Tests *_sself = _wself;
        return _sself->names[nameIndex];
    }];
    [index setFragmenter:^MHTextFragment *(id object, NSData *key){
        __strong iOS_Tests *_sself = _wself;
        MHTextFragment *frag = [MHTextFragment new];
        frag.identifier = key;
        frag.indexedStrings = @[[_sself->names objectAtIndex:[object integerValue]]];
        return frag;
    }];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    [index deleteFromDisk];
}

- (void)testNameMatching {
    CFAbsoluteTime t1 = CFAbsoluteTimeGetCurrent();
    [names enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [index indexObject:@(idx) error:NULL];
    }];
    [index.indexingQueue waitUntilAllOperationsAreFinished];
    NSLog(@"Indexing %d names happened in %f seconds", names.count, CFAbsoluteTimeGetCurrent() - t1);
    
    CFAbsoluteTime t2 = CFAbsoluteTimeGetCurrent();
    NSArray *results = [index searchResultForKeyword:@"ja" options:0];
    NSLog(@"Search over %d names happened in %f seconds", names.count, CFAbsoluteTimeGetCurrent() - t2);
    
    XCTAssert(results.count == 8, @"The search should yield exactly 8 results.");
    [results bk_each:^(MHSearchResultItem *item) {
        NSString *name = item.object;
        NSIndexPath *tokenIndex = item.resultTokens[0];
        XCTAssert([[[name substringFromIndex:tokenIndex.mh_token + tokenIndex.mh_word] lowercaseString] hasPrefix:@"ja"],
                  @"All result should have the searched token at the specified index");
    }];
}

@end
