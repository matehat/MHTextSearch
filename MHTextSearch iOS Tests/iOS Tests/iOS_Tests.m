//
//  iOS_Tests.m
//  iOS Tests
//
//  Created by Mathieu D'Amours on 1/14/14.
//
//

#import <XCTest/XCTest.h>
#import <BlocksKit.h>
#import <MHTextSearch.h>

@interface iOS_Tests : XCTestCase

@end

@implementation iOS_Tests {
    MHTextIndex *nameIndex;
    NSMutableArray *names;
    
    MHTextIndex *textIndex;
    NSMutableArray *texts;
    NSMutableArray *textPaths;
}

- (void)setUp {
    [super setUp];
    
    texts = [NSMutableArray arrayWithCapacity:2000];
    textPaths = [NSMutableArray arrayWithCapacity:2000];
}
- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    [nameIndex deleteFromDisk];
}

- (void)indexAllNames {
    static NSUInteger dbInstanceNum = 0;
    
    NSString *dbName = [NSString stringWithFormat:@"nameIndex-%lu", (unsigned long)dbInstanceNum++];
    nameIndex = [MHTextIndex textIndexInLibraryWithName:dbName];
    [nameIndex deleteFromDisk];
    
    nameIndex = [MHTextIndex textIndexInLibraryWithName:dbName];
    
    __weak iOS_Tests *_wself = self;
    
    NSString *path = [[NSBundle bundleForClass:[iOS_Tests class]] pathForResource:@"Names" ofType:@"txt"];
    NSString *namesRaw = [NSString stringWithContentsOfFile:path
                                                   encoding:NSUTF8StringEncoding
                                                      error:NULL];
    
    names = [[namesRaw componentsSeparatedByString:@"\n"] mutableCopy];
    
    [nameIndex setIdentifier:^NSData *(id object){
        NSUInteger indexVal = [object integerValue];
        return [NSData dataWithBytes:&indexVal length:sizeof(NSUInteger)];
    }];
    [nameIndex setObjectGetter:^id(NSData *identifier){
        NSUInteger nameIdx = 0;
        [identifier getBytes:&nameIdx];
        __strong iOS_Tests *_sself = _wself;
        return _sself->names[nameIdx];
    }];
    [nameIndex setIndexer:^MHIndexedObject *(id object, NSData *key){
        __strong iOS_Tests *_sself = _wself;
        MHIndexedObject *frag = [MHIndexedObject new];
        NSString *name = [_sself->names objectAtIndex:[object integerValue]];
        
        frag.identifier = key;
        frag.strings = @[name];
        frag.weight = [object floatValue];
        frag.context = @{@"name": name};
        
        return frag;
    }];
    
    CFAbsoluteTime t1 = CFAbsoluteTimeGetCurrent();
    [names enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [nameIndex indexObject:@(idx)];
    }];
    [nameIndex.indexingQueue waitUntilAllOperationsAreFinished];
    NSLog(@"Indexing %lu names happened in %f seconds", (unsigned long)names.count, CFAbsoluteTimeGetCurrent() - t1);
}
- (BOOL)indexTextFiles:(BOOL)uniquely {
    NSString *textsDirPath = [[[NSBundle bundleForClass:[iOS_Tests class]] bundlePath] stringByAppendingPathComponent:@"texts"];
    if (!textsDirPath) return NO;
    
    if (textIndex) {
        [textIndex close];
        [texts removeAllObjects];
        [textPaths removeAllObjects];
    }
    NSString *dbName = [NSString stringWithFormat:@"textIndex-%i", uniquely];
    textIndex = [MHTextIndex textIndexInLibraryWithName:dbName];
    [textIndex deleteFromDisk];
    
    textIndex = [MHTextIndex textIndexInLibraryWithName:dbName];
    textIndex.discardDuplicateTokens = uniquely;
    
    __weak iOS_Tests *_wself = self;
    [textIndex setIdentifier:^NSData *(id object){
        NSUInteger indexVal = [object integerValue];
        return [NSData dataWithBytes:&indexVal length:sizeof(NSUInteger)];
    }];
    [textIndex setObjectGetter:^id(NSData *identifier){
        NSUInteger nameIdx = 0;
        [identifier getBytes:&nameIdx];
        __strong iOS_Tests *_sself = _wself;
        return _sself->textPaths[nameIdx];
    }];
    [textIndex setIndexer:^MHIndexedObject *(id object, NSData *key){
        __strong iOS_Tests *_sself = _wself;
        MHIndexedObject *frag = [MHIndexedObject new];
        NSUInteger idx = [object integerValue];
        frag.identifier = key;
        NSString *childPath = _sself->textPaths[idx];
        frag.strings = @[ [NSString stringWithContentsOfFile:childPath
                                                    encoding:NSUTF8StringEncoding
                                                       error:NULL] ];
        frag.context = @{ @"path": childPath };
        return frag;
    }];
    
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:textsDirPath];
    NSString *childPath;
    NSUInteger totalSize = 0, count = 0;
    CFAbsoluteTime t1 = CFAbsoluteTimeGetCurrent();
    
    for (id child in enumerator) {
        if ([child hasSuffix:@".txt"]) {
            NSError *error;
            childPath = [textsDirPath stringByAppendingPathComponent:child];
            NSString *textContent = [NSString stringWithContentsOfFile:childPath
                                                              encoding:NSUTF8StringEncoding
                                                                 error:&error];
            if (error) {
                continue;
            } else {
                [textPaths addObject:childPath];
                [textIndex indexObject:@(count)];
                
                count++;
                totalSize += [textContent lengthOfBytesUsingEncoding:[textContent fastestEncoding]];
                
                if (totalSize > 1500000) {
                    break;
                }
            }
        }
    }
    
    NSLog(@"Total bytes for %lu files: %lu", (unsigned long)count, (unsigned long)totalSize);
    
    [textIndex.indexingQueue waitUntilAllOperationsAreFinished];
    NSLog(@"Indexing %lu texts happened in %f seconds", (unsigned long)textPaths.count, CFAbsoluteTimeGetCurrent() - t1);
    
    return YES;
}

- (void)testNameWithAccents {
    MHTextIndex *index = [MHTextIndex textIndexInLibraryWithName:@"testNameWithAccents"];
    [index deleteFromDisk];
    
    index = [MHTextIndex textIndexInLibraryWithName:@"testNameWithAccents"];
    NSData *data = [@"100001334281213" dataUsingEncoding:NSUTF8StringEncoding];
    [index setIdentifier:^id(id obj) { return data; }];
    [index setIndexer:^MHIndexedObject *(id obj, id key){
        MHIndexedObject *idx = [MHIndexedObject new];
        idx.strings = @[@"Marc-André Jenkins"];
        idx.context = @{@"name": idx.strings[0]};
        return idx;
    }];
    [[index indexObject:[NSNull null]] waitUntilFinished];
    
    [index enumerateResultForKeyword:@"a"
                             options:0
                           withBlock:^(MHSearchResultItem *resultItem, NSUInteger rank, NSUInteger count, BOOL *stop) {
                               XCTAssertNotNil(resultItem.context, @"Context should be found");
                               XCTAssertEqualObjects(resultItem.context[@"name"], @"Marc-André Jenkins", @"Name should be correct");
                           }];
}

- (void)testNameMatching {
    [self indexAllNames];
    
    CFAbsoluteTime t2 = CFAbsoluteTimeGetCurrent();
    NSArray *results = [nameIndex searchResultForKeyword:@"ja" options:0];
    NSLog(@"Search over %lu names happened in %f seconds", (unsigned long)names.count, CFAbsoluteTimeGetCurrent() - t2);
    
    XCTAssert(results.count == 8, @"The search should yield exactly 8 results.");
    [results bk_each:^(MHSearchResultItem *item) {
        NSString *name = item.object;
        NSIndexPath *tokenIndex = item.resultTokens[0];
        XCTAssert([[[name substringFromIndex:tokenIndex.mh_token + tokenIndex.mh_word] lowercaseString] hasPrefix:@"ja"],
                  @"All result should have the searched token at the specified index");
        XCTAssert([[[name substringWithRange:[item rangeOfTokenInString:tokenIndex]] lowercaseString] isEqualToString:@"ja"],
                  @"-[MHSearchResultItem rangeOfTokenInString] result should yield the precise range of the found token");
    }];
}
- (void)testNameOrdering {
    [self indexAllNames];
    
    NSArray *results = [nameIndex searchResultForKeyword:@"er" options:0];
    
    [results bk_reduce:@(CGFLOAT_MAX) withBlock:^(NSNumber *previousWeight, MHSearchResultItem *item) {
        XCTAssert(item.weight < [previousWeight floatValue], @"Results should be ordered with decreasing weight");
        return @(item.weight);
    }];
}
- (void)testNameContext {
    [self indexAllNames];
    
    NSArray *results = [nameIndex searchResultForKeyword:@"th" options:0];
    
    [results bk_each:^(MHSearchResultItem *item) {
        XCTAssert([item.context[@"name"] isEqualToString:item.object],
                  @"An item's context should contain the string it was used for indexing");
    }];
}

- (void)testRemoval {
    [self indexAllNames];
    
    NSArray *results = [nameIndex searchResultForKeyword:@"th" options:0];
    [results bk_each:^(MHSearchResultItem *obj) {
        [nameIndex removeIndexForObject:@([names indexOfObject:obj.object])];
    }];
    [nameIndex.indexingQueue waitUntilAllOperationsAreFinished];
    
    XCTAssertEqual((NSUInteger)[nameIndex searchResultForKeyword:@"th" options:0].count, (NSUInteger)0,
                   @"After removing every result item of a search from the index, the same search should yield nothing.");
}

- (void) testUpdate {
    [self indexAllNames];
    
    NSArray *results = [nameIndex searchResultForKeyword:@"er" options:0];
    NSMutableSet *resultSet1 = [NSMutableSet setWithArray:[results bk_map:^(MHSearchResultItem *obj) { return obj.object; }]];
    [nameIndex.indexingQueue waitUntilAllOperationsAreFinished];
    
    NSMutableSet *updatedSet = [NSMutableSet set];
    [nameIndex enumerateResultForKeyword:@"et" options:0
                                withBlock:^(MHSearchResultItem *resultItem, NSUInteger rank, NSUInteger count, BOOL *stop) {
                                    NSUInteger nameIdx;
                                    [resultItem.identifier getBytes:&nameIdx length:sizeof(NSUInteger)];
                                    NSString *name = resultItem.object;
                                    [resultSet1 removeObject:name];
                                    names[nameIdx] = [name stringByReplacingCharactersInRange:[resultItem rangeOfTokenInString:resultItem.resultTokens[0]]
                                                                                   withString:@"er"];
                                    
                                    [updatedSet addObject:names[nameIdx]];
                                    [nameIndex updateIndexForObject:@(nameIdx)];
                                }];
    
    [nameIndex.indexingQueue waitUntilAllOperationsAreFinished];
    
    results = [nameIndex searchResultForKeyword:@"er" options:0];
    NSMutableSet *resultSet2 = [NSMutableSet setWithArray:[results bk_map:^(MHSearchResultItem *obj) { return obj.object; }]];
    [resultSet2 minusSet:resultSet1];
    
    XCTAssert([resultSet2 isEqualToSet:updatedSet],
              @"The new items in the search result set should be those that were updated, that now match the search");
}


- (void)testLargeTextIndexing {
    if ([self indexTextFiles:NO]) {
        CFAbsoluteTime t2 = CFAbsoluteTimeGetCurrent();
        NSArray *results = [textIndex searchResultForKeyword:@"hat" options:0];
        NSLog(@"Search over %lu texts (not discarding duplicate tokens) happened in %f seconds", (unsigned long)textPaths.count, CFAbsoluteTimeGetCurrent() - t2);
        XCTAssert(results.count == 11, @"The search should yield 1 result");
    };
}

- (void)testLargeTextIndexingUniquely {
    if ([self indexTextFiles:YES]) {
        CFAbsoluteTime t2 = CFAbsoluteTimeGetCurrent();
        NSArray *results = [textIndex searchResultForKeyword:@"hat" options:0];
        NSLog(@"Search over %lu texts (discarding duplicate tokens) happened in %f seconds", (unsigned long)textPaths.count, CFAbsoluteTimeGetCurrent() - t2);
        XCTAssert(results.count == 11, @"The search should yield 1 result");
    };
}

@end
