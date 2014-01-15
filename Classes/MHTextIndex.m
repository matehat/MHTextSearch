//
//  MHTextIndex.m
//  
//
//  Created by Mathieu D'Amours on 1/14/14.
//
//

#import "MHTextIndex.h"
#import "MHSearchResultItem.h"
#import <Objective-LevelDB/LDBWritebatch.h>
#import <Objective-LevelDB/LDBSnapshot.h>

static const uint64_t reversePrefix = 0;
static const uint64_t directPrefix  = 1;
static const uint64_t objectPrefix  = 2;

static const NSUInteger stringFoldingOptions = NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch|NSWidthInsensitiveSearch;

static const size_t uint64_sz = sizeof(uint64_t);
static const size_t uint32_sz = sizeof(uint32_t);

typedef enum IndexObjectKeyType : NSUInteger {
    IndexedObjectKeyTypeStrings = 0,
    IndexedObjectKeyTypeMeta = 1
} IndexedObjectKeyType;

// Given an object identifier, return the index key that yield the JSON encoded list of indexed strings
NSData *indexKeyForIndexedObject(NSData *ident, IndexedObjectKeyType type) {
    size_t size = ident.length + uint64_sz + sizeof(type);
    char *key = malloc(size);
    uint64_t *typePtr = key;
    *typePtr = objectPrefix;
    [ident getBytes:key + uint64_sz];
    IndexedObjectKeyType *keyType = key + uint64_sz + ident.length;
    *keyType = type;
    return [NSData dataWithBytesNoCopy:key length:size];
}

// Given an object identifier, return the index key prefix for the index region containing all indexed word keys
NSData *indexKeyPrefixForObjectWords(NSData *ident) {
    size_t size = ident.length + uint64_sz;
    char *key = malloc(size);
    uint64_t *typePtr = key;
    *typePtr = reversePrefix;
    [ident getBytes:key + uint64_sz];
    return [NSData dataWithBytesNoCopy:key length:size];
}

// Given an object identifier and the index of the indexed string therein, return the index kex prefix for the index region
// containing all corresponding indexed word keys
NSData *indexKeyPrefixForObjectStringAtIndex(NSData *ident, NSUInteger idx) {
    size_t size = ident.length + uint64_sz + 2*uint32_sz;
    char *key = malloc(size);
    char *keyPtr = key;
    
    uint64_t *typePtr = key;
    *typePtr = reversePrefix;
    keyPtr += uint64_sz;
    
    [ident getBytes:key + uint64_sz];
    keyPtr += ident.length;
    
    uint32_t *positionPtr = keyPtr;
    positionPtr[0] = idx;
    positionPtr[1] = 0;
    
    return [NSData dataWithBytesNoCopy:key length:size];
}

NSData *indexKeyPrefixForToken(NSString *token) {
    NSStringEncoding encoding = [token fastestEncoding];
    size_t size = [token lengthOfBytesUsingEncoding:encoding] + uint64_sz;
    char *key = malloc(size);
    char *keyPtr = key;
    
    uint64_t *typePtr = key;
    *typePtr = directPrefix;
    keyPtr += uint64_sz;
    
    [token getBytes:keyPtr maxLength:size - uint64_sz
         usedLength:NULL
           encoding:encoding
            options:NSStringEncodingConversionAllowLossy
              range:(NSRange){0, token.length}
     remainingRange:NULL];
    
    return [NSData dataWithBytesNoCopy:key length:size];
}

MHResultToken unpackTokenData(NSData *indexKey, NSData *rangeData) {
    MHResultToken entry;
    [rangeData getBytes:&entry.tokenRange];
    const char * key = indexKey.bytes + uint64_sz;
    
    char * keyPtr = key;
    
    NSUInteger zeroChars = 0;
    NSUInteger idLength = 0;
    uint32_t *indx;
    
    BOOL sep = NO;
    while (keyPtr < key + indexKey.length) {
        if (*keyPtr == 0) {
            zeroChars += 1;
            if (zeroChars == uint32_sz) {
                indx = keyPtr + uint32_sz;
                entry.stringIndex = *indx;
                
                indx += 1;
                entry.wordIndex = *indx;
                
                indx += 1;
                entry.tokenIndex = *indx;
                
                keyPtr += 4 * uint32_sz;
                entry.identifier = keyPtr;
                entry.length = (key + indexKey.length - uint64_sz) - keyPtr;
                break;
            }
        } else {
            keyPtr += 1;
        }
    }
    
    return entry;
}

// Enumerate over all word token index keys contained in a packed reversed index
void enumerateKeysFromReverseIndex(NSData *keysData, void(^enumerator)(NSData *indexKey)) {
    if (keysData.length == 0) return;
    
    char *data = [keysData bytes];
    char *dataPtr = data;
    uint64_t *keyLength;
    
    while (dataPtr < (data + keysData.length)) {
        keyLength = dataPtr;
        dataPtr += uint64_sz;
        enumerator([NSData dataWithBytesNoCopy:dataPtr length:*keyLength freeWhenDone:NO]);
        dataPtr += *keyLength;
    }
}

void removeIndexForStringInObject(NSData *ident, NSUInteger stringIdx, LDBWritebatch *wb, LDBSnapshot *snapshot) {
    [snapshot enumerateKeysAndObjectsBackward:NO
                                       lazily:NO
                                startingAtKey:nil
                          filteredByPredicate:nil
                                    andPrefix:indexKeyPrefixForObjectStringAtIndex(ident, stringIdx)
                                   usingBlock:^(LevelDBKey * key, NSData *keysData, BOOL *stop){
                                       enumerateKeysFromReverseIndex(keysData, ^(NSData *tokenKey){
                                           [wb removeObjectForKey:tokenKey];
                                       });
                                   }];
}
void indexWordInObjectTextFragment(NSData *ident, NSStringEncoding encoding, NSUInteger minimalTokenLength,
                                   NSString *wordSubstring, NSRange wordSubstringRange, NSUInteger stringIdx,
                                   LDBWritebatch *wb) {
    
    NSMutableData *keys = [NSMutableData data];
    NSString *indexedString = [wordSubstring stringByFoldingWithOptions:stringFoldingOptions
                                                                 locale:[NSLocale currentLocale]];
    NSData *keyData;
    NSRange subRange,
    globalRange = wordSubstringRange;
    
    uint64_t keyLength;
    uint64_t maxLength = [indexedString maximumLengthOfBytesUsingEncoding:encoding];
    uint32_t usedLength;
    uint64_t * indexPrefixPtr;
    uint32_t * indexPositionPtr;
    
    // We allocate a buffer in memory for holding the largest word suffix key
    char * key = malloc(uint64_sz + maxLength + uint32_sz * 4 + ident.length);
    
    // We set a uint64 of value 1 at the start of the key (prefix for "direct" type)
    // This will be shared among all generated keys
    indexPrefixPtr = key;
    *indexPrefixPtr = directPrefix;
    
    char * keyPtr = key + uint64_sz;
    
    for (subRange = (NSRange){0, wordSubstring.length};
         subRange.length >= MAX(minimalTokenLength, 1);
         
         globalRange.location += 1,
         globalRange.length -= 1,
         subRange.location += 1,
         subRange.length -= 1) {
        
        // We set the position of keyPtr to just after the key prefix
        keyPtr = key + uint64_sz;
        
        // We copy the bytes for the suffix substring into the suffix key
        [indexedString getBytes:keyPtr
                      maxLength:maxLength
                     usedLength:&usedLength
                       encoding:encoding
                        options:NSStringEncodingConversionAllowLossy
                          range:subRange
                 remainingRange:NULL];
        keyPtr += usedLength;
        
        // We insert a separator with value 0 to separate the suffix from the object id
        indexPositionPtr = keyPtr;
        indexPositionPtr[0] = 0;
        
        // ... and set the position of the suffix in the indexed object
        indexPositionPtr[1] = (uint32_t)stringIdx;
        indexPositionPtr[2] = (uint32_t)wordSubstringRange.location;
        indexPositionPtr[3] = (uint32_t)subRange.location;
        keyPtr += (uint32_sz * 4);
        
        // ... and copy the object id bytes following the separator
        [ident getBytes:keyPtr];
        
        keyData = [NSData dataWithBytesNoCopy:key
                                       length:(keyPtr - key) + ident.length
                                 freeWhenDone:NO];
        
        // To the constructed suffix key, we associate the range of the keyword in the
        // indexed string
        [wb setObject:[NSData dataWithBytes:&globalRange
                                     length:sizeof(NSRange)]
               forKey:keyData];
        
        // We get the size of the resulting key, minus the prefixed type 0 (direct)
        keyLength = keyData.length;
        
        // In the key list, we append the size of the upcoming key
        [keys appendBytes:&keyLength length:uint64_sz];
        
        // ... and append the key bytes, without the leading type 0
        [keys appendBytes:key + uint64_sz length:keyLength];
    }
    
    // Finally, for each indexed word, we need to insert a reversed index entry for bookkeeping
    // We can reused our previously allocated buffer
    keyLength = ident.length + uint64_sz + (2 * uint32_sz);
    keyPtr = key;
    
    // This time we set the prefix type to 1 ("reverse" type)
    indexPrefixPtr = keyPtr;
    *indexPrefixPtr = reversePrefix;
    keyPtr += uint64_sz;
    
    // We copy the identifier bytes into the buffer
    [ident getBytes:keyPtr];
    keyPtr += ident.length;
    
    // And set the position of the indexed word as a 2 unsigned 32-bit integer
    indexPositionPtr = keyPtr;
    indexPositionPtr[0] = (uint32_t)stringIdx;                     // The string index
    indexPositionPtr[1] = (uint32_t)wordSubstringRange.location;   // The position of the word in the string
    
    [wb setObject:keys
            forKey:[NSData dataWithBytesNoCopy:key
                                        length:keyLength]];
}

@implementation MHTextIndex {
    LevelDB *_db;
    dispatch_queue_t _searchQueue;
}

+ (instancetype)textIndexInLibraryWithName:(NSString *)name {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libPath = [paths objectAtIndex:0];
    NSString *dbPath = [libPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.indexdb", name]];
    return [self textIndexWithName:name path:dbPath options:[LevelDB makeOptions]];
}
+ (instancetype)textIndexWithName:(NSString *)name path:(NSString *)path options:(LevelDBOptions)options {
    return [[MHTextIndex alloc] initWithName:name path:path options:options];
}
- (instancetype)initWithName:(NSString *)name path:(NSString *)path options:(LevelDBOptions)options {
    self = [super init];
    if (self) {
        _db = [[LevelDB alloc] initWithPath:path name:name andOptions:options];
        
        _searchQueue = dispatch_queue_create([[NSString stringWithFormat:@"mhtextindex.%@", name] cStringUsingEncoding:NSUTF8StringEncoding],
                                             DISPATCH_QUEUE_CONCURRENT);
        
        _indexingQueue = [[NSOperationQueue alloc] init];
        _indexingQueue.maxConcurrentOperationCount = 10;
        _minimalTokenLength = 2;
        _path = path;
        _name = name;
        
        _sortOptions = NSSortConcurrent | NSSortStable;
    }
    return self;
}

- (void)dealloc {
    [_db close];
}

- (NSComparisonResult)compareResultItem:(MHSearchResultItem *)item1
                               withItem:(MHSearchResultItem *)item2
                               reversed:(BOOL)reversed {
    
    CGFloat diff = item1.weight - item2.weight;
    NSInteger countDiff = item1.resultTokens.count - item2.resultTokens.count;
    
    if (diff > 0 || (diff == 0 && countDiff > 0)) {
        return reversed ? NSOrderedDescending : NSOrderedAscending;
    } else if (diff < 0 || (diff == 0 && countDiff < 0)) {
        return reversed ? NSOrderedAscending : NSOrderedDescending;
    } else {
        return NSOrderedSame;
    }
}

- (NSData *)getIdentifierForObject:(id)object {
    NSAssert(_identifier != nil, @"You need to defined the identifier block before indexing anything");
    return _identifier(object);
}
- (MHIndexedObject *)getIndexInfoForObject:(id)object {
    return [self getIndexInfoForObject:object
                         andIdentifier:[self getIdentifierForObject:object]];
}
- (MHIndexedObject *)getIndexInfoForObject:(id)object andIdentifier:(NSData *)identifier {
    NSAssert(_indexer != nil, @"You need to defined the indexer block before indexing anything");
    return _indexer(object, identifier);
}

- (NSOperation *)indexObject:(id)object {
    
    NSAssert(_db != nil, @"Database is closed");
    NSData *ident = [self getIdentifierForObject:object];
    __block NSError *error;
    __weak MHTextIndex *_wself = self;
    NSBlockOperation *indexingOperation = [NSBlockOperation blockOperationWithBlock:^{
        __strong MHTextIndex *_sself = _wself;
        
        MHIndexedObject *indexedObj = [_sself getIndexInfoForObject:object andIdentifier:ident];
        
        NSData *newIndexedObjectStrings = [NSJSONSerialization dataWithJSONObject:indexedObj.strings
                                                                          options:0
                                                                            error:&error];
        
        NSData *newIndexedObjectMeta = [NSKeyedArchiver archivedDataWithRootObject:@{@"weight": @(indexedObj.weight),
                                                                                     @"ctx": indexedObj.context ?: [NSNull null]}];
        
        if (error != nil) {
            return;
        }
        
        LDBWritebatch *wb = [_sself->_db newWritebatch];
        [indexedObj.strings enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
            NSStringEncoding encoding = [obj fastestEncoding];
            NSParameterAssert([obj isKindOfClass:[NSString class]]);
            [obj enumerateSubstringsInRange:(NSRange){0, obj.length}
                                    options:NSStringEnumerationByWords|NSStringEnumerationLocalized
                                 usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
                                     indexWordInObjectTextFragment(ident, encoding, _sself->_minimalTokenLength, substring, substringRange, idx, wb);
                                 }];
        }];
        
        [wb setObject:newIndexedObjectStrings forKey:indexKeyForIndexedObject(ident, IndexedObjectKeyTypeStrings)];
        [wb setObject:newIndexedObjectMeta forKey:indexKeyForIndexedObject(ident, IndexedObjectKeyTypeMeta)];
        [wb apply];
        wb = nil;
    }];
    
    [_indexingQueue addOperation:indexingOperation];
    return indexingOperation;
}

- (NSOperation *)updateIndexForObject:(id)object {
    
    NSAssert(_db != nil, @"Database is closed");
    NSData *ident = [self getIdentifierForObject:object];
    __block NSError *error;
    
    __weak MHTextIndex *_wself = self;
    NSBlockOperation *indexingOperation = [NSBlockOperation blockOperationWithBlock:^{
        __strong MHTextIndex *_sself = _wself;
        
        MHIndexedObject *indexedObj = [_sself getIndexInfoForObject:object andIdentifier:ident];
        LDBSnapshot *snapshot = [_db newSnapshot];
        
        NSData *previousIndexedObjectStrings = [snapshot objectForKey:indexKeyForIndexedObject(ident, IndexedObjectKeyTypeStrings)];
        NSArray *previousStrings;
        
        if (!previousIndexedObjectStrings) {
            previousStrings = @[];
        } else {
            previousStrings = [NSJSONSerialization JSONObjectWithData:previousIndexedObjectStrings options:0 error:&error];
        }
        if (error) return;
        
        NSData *newIndexedObjectStrings = [NSJSONSerialization dataWithJSONObject:indexedObj.strings
                                                                          options:0
                                                                            error:&error];
        
        NSData *newIndexedObjectMeta = [NSKeyedArchiver archivedDataWithRootObject:@{@"weight": @(indexedObj.weight),
                                                                                     @"ctx": indexedObj.context ?: [NSNull null]}];
        
        if (error) return;
        
        LDBWritebatch *wb = [_sself->_db newWritebatch];
        [indexedObj.strings enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
            if (idx < previousStrings.count) {
                if ([previousStrings[idx] isEqualToString:obj])
                    return;
                else {
                    removeIndexForStringInObject(ident, idx, wb, snapshot);
                }
            }
            
            NSStringEncoding encoding = [obj fastestEncoding];
            NSParameterAssert([obj isKindOfClass:[NSString class]]);
            [obj enumerateSubstringsInRange:(NSRange){0, obj.length}
                                    options:NSStringEnumerationByWords|NSStringEnumerationLocalized
                                 usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
                                     indexWordInObjectTextFragment(ident, encoding, _sself->_minimalTokenLength, substring, substringRange, idx, wb);
                                 }];
        }];
        
        if (previousStrings.count > indexedObj.strings) {
            for (NSUInteger i=indexedObj.strings.count; i<previousStrings.count; i++) {
                removeIndexForStringInObject(ident, i, wb, snapshot);
            }
        }
        
        [wb setObject:newIndexedObjectStrings forKey:indexKeyForIndexedObject(ident, IndexedObjectKeyTypeStrings)];
        [wb setObject:newIndexedObjectMeta forKey:indexKeyForIndexedObject(ident, IndexedObjectKeyTypeMeta)];
        [wb apply];
    }];
    
    [_indexingQueue addOperation:indexingOperation];
    return indexingOperation;
}

- (NSOperation *)removeIndexForObject:(id)object {
    
    NSAssert(_db != nil, @"Database is closed");
    NSData *ident = [self getIdentifierForObject:object];
    __block NSError *error;
    
    if (error) return nil;
    __weak MHTextIndex *_wself = self;
    NSBlockOperation *indexingOperation = [NSBlockOperation blockOperationWithBlock:^{
        LDBSnapshot *snapshot = [_db newSnapshot];
        NSData *previousStringsData = [snapshot objectForKey:indexKeyForIndexedObject(ident, IndexedObjectKeyTypeStrings)];
        if (previousStringsData) {
            NSArray *previousStrings = [NSJSONSerialization JSONObjectWithData:previousStringsData options:0 error:&error];
            
            __strong MHTextIndex *_sself = _wself;
            LDBWritebatch *wb = [_sself->_db newWritebatch];
            [previousStrings enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
                removeIndexForStringInObject(ident, idx, wb, snapshot);
            }];
            
            [wb removeObjectForKey:indexKeyForIndexedObject(ident, IndexedObjectKeyTypeStrings)];
            [wb removeObjectForKey:indexKeyForIndexedObject(ident, IndexedObjectKeyTypeMeta)];
            [wb apply];
        }
    }];
    
    [_indexingQueue addOperation:indexingOperation];
    return indexingOperation;
}

- (NSArray *)searchResultForKeyword:(NSString *)keyword
                            options:(NSEnumerationOptions)options {
    
    NSAssert(_db != nil, @"Database is closed");
    __block NSArray *result;
    keyword = [keyword stringByFoldingWithOptions:stringFoldingOptions locale:[NSLocale currentLocale]];
    dispatch_sync(_searchQueue, ^{
        LDBSnapshot *snapshot = [_db newSnapshot];
        NSMutableDictionary *searchResult = [NSMutableDictionary dictionary];
        [snapshot enumerateKeysAndObjectsBackward:NO
                                           lazily:NO
                                    startingAtKey:nil
                              filteredByPredicate:nil
                                        andPrefix:indexKeyPrefixForToken(keyword)
                                       usingBlock:^(LevelDBKey *key, NSData *rangeData, BOOL*stop){
                                           NSData *fullKey = NSDataFromLevelDBKey(key);
                                           MHResultToken indexEntry = unpackTokenData(fullKey, rangeData);
                                           NSData *identifier = [NSData dataWithBytesNoCopy:indexEntry.identifier length:indexEntry.length freeWhenDone:NO];
                                           MHSearchResultItem *resultItem = searchResult[identifier];
                                           if (!resultItem) {
                                               resultItem = searchResult[identifier] = [MHSearchResultItem searchResultItemWithIdentifier:identifier
                                                                                                                          andObjectGetter:_objectGetter];
                                           }
                                           [resultItem addResultToken:indexEntry];
                                       }];
        
        [searchResult enumerateKeysAndObjectsUsingBlock:^(NSData *key, MHSearchResultItem *obj, BOOL *stop) {
            NSData *indexedObjectMetaData = [snapshot objectForKey:indexKeyForIndexedObject(key, IndexedObjectKeyTypeMeta)];
            NSDictionary *indexedObjectMeta = [NSKeyedUnarchiver unarchiveObjectWithData:indexedObjectMetaData];
            obj.weight = [indexedObjectMeta[@"weight"] floatValue];
            obj.context = indexedObjectMeta[@"ctx"];
        }];
        
        result = [[searchResult allValues] sortedArrayWithOptions:_sortOptions
                               usingComparator:^NSComparisonResult(id obj1, id obj2) {
                                   return [self compareResultItem:obj1 withItem:obj2
                                                         reversed:(options & NSEnumerationReverse) == NSEnumerationReverse];
                               }];
    });
    return result;
}
- (void)enumerateResultForKeyword:(NSString *)keyword
                          options:(NSEnumerationOptions)options
                        withBlock:(void (^)(MHSearchResultItem *, NSUInteger, NSUInteger, BOOL *))block {
    
    NSAssert(_db != nil, @"Database is closed");
    NSArray *resultSet = [self searchResultForKeyword:keyword options:options];
    [resultSet enumerateObjectsUsingBlock:^(MHSearchResultItem *item, NSUInteger idx, BOOL *stop) {
        item.rank = idx;
        block(item, idx, resultSet.count, stop);
    }];
}

- (void)close {
    @synchronized(self) {
        [_db close];
        _db = nil;
    }
}
- (void)deleteFromDisk {
    @synchronized(self) {
        [_db deleteDatabaseFromDisk];
        _db = nil;
    }
}

@end
