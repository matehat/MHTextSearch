//
//  MHTextIndex.m
//
//
//  Created by Mathieu D'Amours on 1/14/14.
//
//

#import "MHTextIndex.h"
#import "MHSearchResultItem.h"
#import "bloom-filter.h"
#import "hash-string.h"
#import <Objective-LevelDB/LDBWritebatch.h>
#import <Objective-LevelDB/LDBSnapshot.h>

static const uint64_t reversePrefix = 0;
static const uint64_t directPrefix  = 1;
static const uint64_t objectPrefix  = 2;

static const NSUInteger stringFoldingOptions = NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch|NSWidthInsensitiveSearch;

static const size_t uint64_sz = sizeof(uint64_t);
static const size_t uint32_sz = sizeof(uint32_t);

NSSet *stopWords() {
    static NSSet *stopWords;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        stopWords = [NSSet setWithObjects:@"a's", @"able", @"about", @"above", @"according", @"accordingly", @"across", @"actually", @"after", @"afterwards", @"again", @"against", @"ain't", @"all", @"allow", @"allows", @"almost", @"alone", @"along", @"already", @"also", @"although", @"always", @"am", @"among", @"amongst", @"an", @"and", @"another", @"any", @"anybody", @"anyhow", @"anyone", @"anything", @"anyway", @"anyways", @"anywhere", @"apart", @"appear", @"appreciate", @"appropriate", @"are", @"aren't", @"around", @"as", @"aside", @"ask", @"asking", @"associated", @"at", @"available", @"away", @"awfully", @"be", @"became", @"because", @"become", @"becomes", @"becoming", @"been", @"before", @"beforehand", @"behind", @"being", @"believe", @"below", @"beside", @"besides", @"best", @"better", @"between", @"beyond", @"both", @"brief", @"but", @"by", @"c'mon", @"c's", @"came", @"can", @"can't", @"cannot", @"cant", @"cause", @"causes", @"certain", @"certainly", @"changes", @"clearly", @"co", @"com", @"come", @"comes", @"concerning", @"consequently", @"consider", @"considering", @"contain", @"containing", @"contains", @"corresponding", @"could", @"couldn't", @"course", @"currently", @"definitely", @"described", @"despite", @"did", @"didn't", @"different", @"do", @"does", @"doesn't", @"doing", @"don't", @"done", @"down", @"downwards", @"during", @"each", @"edu", @"eg", @"eight", @"either", @"else", @"elsewhere", @"enough", @"entirely", @"especially", @"et", @"etc", @"even", @"ever", @"every", @"everybody", @"everyone", @"everything", @"everywhere", @"ex", @"exactly", @"example", @"except", @"far", @"few", @"fifth", @"first", @"five", @"followed", @"following", @"follows", @"for", @"former", @"formerly", @"forth", @"four", @"from", @"further", @"furthermore", @"get", @"gets", @"getting", @"given", @"gives", @"go", @"goes", @"going", @"gone", @"got", @"gotten", @"greetings", @"had", @"hadn't", @"happens", @"hardly", @"has", @"hasn't", @"have", @"haven't", @"having", @"he", @"he's", @"hello", @"help", @"hence", @"her", @"here", @"here's", @"hereafter", @"hereby", @"herein", @"hereupon", @"hers", @"herself", @"hi", @"him", @"himself", @"his", @"hither", @"hopefully", @"how", @"howbeit", @"however", @"i'd", @"i'll", @"i'm", @"i've", @"ie", @"if", @"ignored", @"immediate", @"in", @"inasmuch", @"inc", @"indeed", @"indicate", @"indicated", @"indicates", @"inner", @"insofar", @"instead", @"into", @"inward", @"is", @"isn't", @"it", @"it'd", @"it'll", @"it's", @"its", @"itself", @"just", @"keep", @"keeps", @"kept", @"know", @"known", @"knows", @"last", @"lately", @"later", @"latter", @"latterly", @"least", @"less", @"lest", @"let", @"let's", @"like", @"liked", @"likely", @"little", @"look", @"looking", @"looks", @"ltd", @"mainly", @"many", @"may", @"maybe", @"me", @"mean", @"meanwhile", @"merely", @"might", @"more", @"moreover", @"most", @"mostly", @"much", @"must", @"my", @"myself", @"name", @"namely", @"nd", @"near", @"nearly", @"necessary", @"need", @"needs", @"neither", @"never", @"nevertheless", @"new", @"next", @"nine", @"no", @"nobody", @"non", @"none", @"noone", @"nor", @"normally", @"not", @"nothing", @"novel", @"now", @"nowhere", @"obviously", @"of", @"off", @"often", @"oh", @"ok", @"okay", @"old", @"on", @"once", @"one", @"ones", @"only", @"onto", @"or", @"other", @"others", @"otherwise", @"ought", @"our", @"ours", @"ourselves", @"out", @"outside", @"over", @"overall", @"own", @"particular", @"particularly", @"per", @"perhaps", @"placed", @"please", @"plus", @"possible", @"presumably", @"probably", @"provides", @"que", @"quite", @"qv", @"rather", @"rd", @"re", @"really", @"reasonably", @"regarding", @"regardless", @"regards", @"relatively", @"respectively", @"right", @"said", @"same", @"saw", @"say", @"saying", @"says", @"second", @"secondly", @"see", @"seeing", @"seem", @"seemed", @"seeming", @"seems", @"seen", @"self", @"selves", @"sensible", @"sent", @"serious", @"seriously", @"seven", @"several", @"shall", @"she", @"should", @"shouldn't", @"since", @"six", @"so", @"some", @"somebody", @"somehow", @"someone", @"something", @"sometime", @"sometimes", @"somewhat", @"somewhere", @"soon", @"sorry", @"specified", @"specify", @"specifying", @"still", @"sub", @"such", @"sup", @"sure", @"t's", @"take", @"taken", @"tell", @"tends", @"th", @"than", @"thank", @"thanks", @"thanx", @"that", @"that's", @"thats", @"the", @"their", @"theirs", @"them", @"themselves", @"then", @"thence", @"there", @"there's", @"thereafter", @"thereby", @"therefore", @"therein", @"theres", @"thereupon", @"these", @"they", @"they'd", @"they'll", @"they're", @"they've", @"think", @"third", @"this", @"thorough", @"thoroughly", @"those", @"though", @"three", @"through", @"throughout", @"thru", @"thus", @"to", @"together", @"too", @"took", @"toward", @"towards", @"tried", @"tries", @"truly", @"try", @"trying", @"twice", @"two", @"un", @"under", @"unfortunately", @"unless", @"unlikely", @"until", @"unto", @"up", @"upon", @"us", @"use", @"used", @"useful", @"uses", @"using", @"usually", @"value", @"various", @"very", @"via", @"viz", @"vs", @"want", @"wants", @"was", @"wasn't", @"way", @"we", @"we'd", @"we'll", @"we're", @"we've", @"welcome", @"well", @"went", @"were", @"weren't", @"what", @"what's", @"whatever", @"when", @"whence", @"whenever", @"where", @"where's", @"whereafter", @"whereas", @"whereby", @"wherein", @"whereupon", @"wherever", @"whether", @"which", @"while", @"whither", @"who", @"who's", @"whoever", @"whole", @"whom", @"whose", @"why", @"will", @"willing", @"wish", @"with", @"within", @"without", @"won't", @"wonder", @"would", @"wouldn't", @"yes", @"yet", @"you", @"you'd", @"you'll", @"you're", @"you've", @"your", @"yours", @"yourself", @"yourselves", @"zero", nil];
    });
    return stopWords;
}

typedef enum IndexObjectKeyType : NSUInteger {
    IndexedObjectKeyTypeStrings = 0,
    IndexedObjectKeyTypeMeta = 1
} IndexedObjectKeyType;

// Given an object identifier, return the index key that yield the JSON encoded list of indexed strings
NSData *indexKeyForIndexedObject(NSData *ident, IndexedObjectKeyType type) {
    size_t size = ident.length + uint64_sz + sizeof(type);
    char *key = malloc(size);
    uint64_t *typePtr = (uint64_t *)key;
    *typePtr = objectPrefix;
    [ident getBytes:key + uint64_sz];
    IndexedObjectKeyType *keyType = (IndexedObjectKeyType *)(key + uint64_sz + ident.length);
    *keyType = type;
    return [NSData dataWithBytesNoCopy:key length:size];
}

// Given an object identifier, return the index key prefix for the index region containing all indexed word keys
NSData *indexKeyPrefixForObjectWords(NSData *ident) {
    size_t size = ident.length + uint64_sz;
    char *key = malloc(size);
    uint64_t *typePtr = (uint64_t *)key;
    *typePtr = reversePrefix;
    [ident getBytes:key + uint64_sz];
    return [NSData dataWithBytesNoCopy:key length:size];
}

// Given an object identifier and the index of the indexed string therein, return the index kex prefix for the index region
// containing all corresponding indexed word keys
NSData *indexKeyPrefixForObjectStringAtIndex(NSData *ident, NSUInteger idx) {
    size_t size = ident.length + uint64_sz + uint32_sz;
    char *key = malloc(size);
    char *keyPtr = key;
    
    uint64_t *typePtr = (uint64_t *)key;
    *typePtr = reversePrefix;
    keyPtr += uint64_sz;
    
    [ident getBytes:key + uint64_sz];
    keyPtr += ident.length;
    
    uint32_t *positionPtr = (uint32_t *)keyPtr;
    positionPtr[0] = idx;
    
    return [NSData dataWithBytesNoCopy:key length:size];
}

NSData *indexKeyPrefixForToken(NSString *token) {
    NSStringEncoding encoding = [token fastestEncoding];
    size_t size = [token lengthOfBytesUsingEncoding:encoding] + uint64_sz;
    char *key = malloc(size);
    char *keyPtr = key;
    
    uint64_t *typePtr = (uint64_t *)key;
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
    const char * keyPtr = key;
    
    NSUInteger zeroChars = 0;
    uint32_t *indx;
    
    while (keyPtr < key + indexKey.length) {
        if (*keyPtr == 0) {
            zeroChars += 1;
            if (zeroChars == uint32_sz) {
                indx = (uint32_t *)(keyPtr + uint32_sz);
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
    
    const char *data = [keysData bytes];
    const char *dataPtr = data;
    uint64_t *keyLength;
    
    while (dataPtr < (data + keysData.length)) {
        keyLength = (uint64_t *)dataPtr;
        dataPtr += uint64_sz;
        enumerator([NSData dataWithBytesNoCopy:(void *)dataPtr length:(NSUInteger)*keyLength freeWhenDone:NO]);
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
void indexWordInObjectTextFragment(NSData *ident, NSStringEncoding encoding, bloom_filter_s *bloomFilter,
                                   NSUInteger minimalTokenLength, BOOL skipStopWords,
                                   NSString *wordSubstring, NSRange wordSubstringRange, NSUInteger stringIdx,
                                   LDBWritebatch *wb) {
    
    NSMutableData *keys = [NSMutableData data];
    NSString *indexedString = [wordSubstring stringByFoldingWithOptions:stringFoldingOptions
                                                                 locale:[NSLocale currentLocale]];
    
    static NSSet *stopWordList;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        stopWordList = stopWords();
    });
    
    if (skipStopWords && [stopWordList containsObject:indexedString])
        return;
    
    NSData *keyData;
    NSRange subRange,
    globalRange = wordSubstringRange;
    
    uint64_t keyLength;
    uint64_t strLength = [indexedString lengthOfBytesUsingEncoding:encoding];
    NSUInteger usedLength;
    uint64_t * indexPrefixPtr;
    uint32_t * indexPositionPtr;
    
    // We allocate a buffer in memory for holding the largest word suffix key
    char * key = malloc(uint64_sz + (size_t)strLength + uint32_sz * 4 + (size_t)ident.length);
    
    // We set a uint64 of value 1 at the start of the key (prefix for "direct" type)
    // This will be shared among all generated keys
    indexPrefixPtr = (uint64_t *)key;
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
                      maxLength:(NSUInteger)strLength
                     usedLength:&usedLength
                       encoding:encoding
                        options:NSStringEncodingConversionAllowLossy
                          range:subRange
                 remainingRange:NULL];
        
        if (bloomFilter != NULL) {
            if (bloom_filter_query(bloomFilter, keyPtr, usedLength) == 1)
                continue;
            else
                bloom_filter_insert(bloomFilter, keyPtr, usedLength);
        }
        
        keyPtr += usedLength;
        
        // We insert a separator with value 0 to separate the suffix from the object id
        indexPositionPtr = (uint32_t *)keyPtr;
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
        [keys appendBytes:key length:(NSUInteger)keyLength];
    }
    
    // Finally, for each indexed word, we need to insert a reversed index entry for bookkeeping
    // We can reused our previously allocated buffer
    keyLength = ident.length + uint64_sz + (2 * uint32_sz);
    keyPtr = key;
    
    // This time we set the prefix type to 1 ("reverse" type)
    indexPrefixPtr = (uint64_t *)keyPtr;
    *indexPrefixPtr = reversePrefix;
    keyPtr += uint64_sz;
    
    // We copy the identifier bytes into the buffer
    [ident getBytes:keyPtr];
    keyPtr += ident.length;
    
    // And set the position of the indexed word as a 2 unsigned 32-bit integer
    indexPositionPtr = (uint32_t *)keyPtr;
    indexPositionPtr[0] = (uint32_t)stringIdx;                     // The string index
    indexPositionPtr[1] = (uint32_t)wordSubstringRange.location;   // The position of the word in the string
    
    [wb setObject:keys
           forKey:[NSData dataWithBytesNoCopy:key
                                       length:(NSUInteger)keyLength]];
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
        _skipStopWords = YES;
        _discardDuplicateTokens = NO;
        
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
            
            bloom_filter_s *bloomFilter = NULL;
            if (_sself->_discardDuplicateTokens) {
                size_t est_token_count = [obj maximumLengthOfBytesUsingEncoding:encoding];
                size_t table_size = ceil((est_token_count * log(0.0001)) / log(1.0 / (pow(2.0, log(2.0)))));
                size_t num_funcs = round(log(2.0) * table_size / est_token_count);
                
                bloomFilter = bloom_filter_new(table_size, jenkins_nocase_hash, num_funcs);
            }
            
            [obj enumerateSubstringsInRange:(NSRange){0, obj.length}
                                    options:NSStringEnumerationByWords|NSStringEnumerationLocalized
                                 usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
                                     indexWordInObjectTextFragment(ident, encoding, bloomFilter,
                                                                   _sself->_minimalTokenLength, _sself->_skipStopWords,
                                                                   substring, substringRange, idx, wb);
                                 }];
            
            if (_sself->_discardDuplicateTokens)
                bloom_filter_free(bloomFilter);
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
            
            bloom_filter_s *bloomFilter = NULL;
            if (_sself->_discardDuplicateTokens) {
                size_t est_token_count = [obj maximumLengthOfBytesUsingEncoding:encoding];
                size_t table_size = ceil((est_token_count * log(0.0001)) / log(1.0 / (pow(2.0, log(2.0)))));
                size_t num_funcs = round(log(2.0) * table_size / est_token_count);
                
                bloomFilter = bloom_filter_new(table_size, jenkins_nocase_hash, num_funcs);
            }
            
            [obj enumerateSubstringsInRange:(NSRange){0, obj.length}
                                    options:NSStringEnumerationByWords|NSStringEnumerationLocalized
                                 usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
                                     indexWordInObjectTextFragment(ident, encoding, bloomFilter,
                                                                   _sself->_minimalTokenLength, _sself->_skipStopWords,
                                                                   substring, substringRange, idx, wb);
                                 }];
            
            if (_sself->_discardDuplicateTokens)
                bloom_filter_free(bloomFilter);
        }];
        
        if (previousStrings.count > indexedObj.strings.count) {
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
                                           
                                           NSData *identifier = [NSData dataWithBytesNoCopy:(void *)indexEntry.identifier
                                                                                     length:indexEntry.length
                                                                               freeWhenDone:NO];
                                           
                                           MHSearchResultItem *resultItem = searchResult[identifier];
                                           if (!resultItem) {
                                               resultItem = searchResult[identifier] = [MHSearchResultItem searchResultItemWithIdentifier:identifier
                                                                                                                                  keyword:keyword
                                                                                                                             objectGetter:_objectGetter];
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
