//
//  MHTextIndex.h
//  
//
//  Created by Mathieu D'Amours on 1/14/14.
//
//

#import <Foundation/Foundation.h>
#import <Objective-LevelDB/LevelDB.h>
#import "MHIndexedObject.h"

@class MHSearchResultItem;

typedef MHIndexedObject *(^MHIndexerBlock)(id object, NSData *identifier);
typedef NSData *(^MHIdentifyBlock)(id object);
typedef id (^MHObjectGetter)(NSData *identifier);

typedef struct {
    uint32_t stringIndex;
    uint32_t wordIndex;
    uint32_t tokenIndex;
    NSRange tokenRange;
    
    char * identifier;
    size_t length;
} MHResultToken;

@interface MHTextIndex : NSObject

@property NSSortOptions sortOptions;
@property NSUInteger minimalTokenLength;
@property BOOL skipStopWords;

@property (strong, readonly) NSString * path;
@property (strong, readonly) NSString * name;

@property (strong, readonly) NSOperationQueue * indexingQueue;

@property (strong, nonatomic) MHIndexerBlock indexer;
@property (strong, nonatomic) MHIdentifyBlock identifier;
@property (strong, nonatomic) MHObjectGetter objectGetter;

+ (instancetype) textIndexWithName:(NSString *)name path:(NSString *)path options:(LevelDBOptions)options;
+ (instancetype) textIndexInLibraryWithName:(NSString *)name;
- (instancetype) initWithName:(NSString *)name path:(NSString *)path options:(LevelDBOptions)options;

- (NSOperation *) indexObject:(id)object;
- (NSOperation *) updateIndexForObject:(id)object;
- (NSOperation *) removeIndexForObject:(id)object;

- (NSArray *)searchResultForKeyword:(NSString *)keyword
                            options:(NSEnumerationOptions)options;
- (void) enumerateResultForKeyword:(NSString *)keyword
                            options:(NSEnumerationOptions)options
                          withBlock:(void(^)(MHSearchResultItem *resultItem, NSUInteger rank, NSUInteger count, BOOL *stop))block;

- (NSData *) getIdentifierForObject:(id)object;
- (MHIndexedObject *) getIndexInfoForObject:(id)object;
- (MHIndexedObject *) getIndexInfoForObject:(id)object andIdentifier:(NSData *)identifier;

- (void) close;
- (void) deleteFromDisk;

@end
