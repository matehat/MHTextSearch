//
//  MHTextIndex.h
//  
//
//  Created by Mathieu D'Amours on 1/14/14.
//
//

#import <Foundation/Foundation.h>
#import <Objective-LevelDB/LevelDB.h>
#import "MHTextFragment.h"

@class MHSearchResultItem;

typedef MHTextFragment *(^MHFragmentBlock)(id object, NSData *identifier);
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

@property (strong, readonly) NSString * path;
@property (strong, readonly) NSString * name;

@property (strong, readonly) NSOperationQueue * indexingQueue;

@property (strong, nonatomic) MHFragmentBlock fragmenter;
@property (strong, nonatomic) MHIdentifyBlock identifier;
@property (strong, nonatomic) MHObjectGetter objectGetter;

+ (instancetype) textIndexWithName:(NSString *)name path:(NSString *)path options:(LevelDBOptions)options;
+ (instancetype) textIndexInLibraryWithName:(NSString *)name;
- (instancetype) initWithName:(NSString *)name path:(NSString *)path options:(LevelDBOptions)options;

- (NSOperation *) indexObject:(id)object
                        error:(NSError * __autoreleasing *)error;
- (NSOperation *) updateIndexForObject:(id)object
                                 error:(NSError * __autoreleasing *)error;
- (NSOperation *) removeIndexForObject:(id)object
                                 error:(NSError * __autoreleasing *)error;

- (NSArray *)searchResultForKeyword:(NSString *)keyword
                            options:(NSEnumerationOptions)options;
- (void) enumerateObjectsForKeyword:(NSString *)keyword
                          withBlock:(void(^)(MHSearchResultItem *resultItem, NSUInteger rank, NSUInteger count, BOOL *stop))block;

- (NSData *) getIdentifierForObject:(id)object;
- (MHTextFragment *) getFragmentForObject:(id)object;
- (MHTextFragment *) getFragmentForObject:(id)object andIdentifier:(NSData *)identifier;

- (void) close;
- (void) deleteFromDisk;

@end
