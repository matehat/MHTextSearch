//
//  MHSearchResultItem.h
//  
//
//  Created by Mathieu D'Amours on 1/14/14.
//
//

#import <Foundation/Foundation.h>
#import "MHTextIndex.h"

@interface MHSearchResultItem : NSObject

@property CGFloat weight;
@property NSUInteger rank;
@property (readonly) id object;
@property (strong) NSDictionary *context;

@property (strong, readonly) NSData *identifier;
@property (strong, readonly) NSArray *resultTokens;

+ (instancetype) searchResultItemWithIdentifier:(NSData *)identifier
                                andObjectGetter:(MHObjectGetter)getter;

- (void) addResultToken:(MHResultToken)token;

@end

@interface NSIndexPath (MHSearchResult)

@property (readonly) NSUInteger mh_string;
@property (readonly) NSUInteger mh_word;
@property (readonly) NSUInteger mh_token;

+ (NSIndexPath *)mh_searchResultindexPathForString:(NSUInteger)string
                                              word:(NSUInteger)word
                                             token:(NSUInteger)token;

@end