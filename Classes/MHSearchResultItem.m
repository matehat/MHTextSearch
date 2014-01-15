//
//  MHSearchResultItem.m
//  
//
//  Created by Mathieu D'Amours on 1/14/14.
//
//

#import "MHSearchResultItem.h"

@implementation MHSearchResultItem {
    NSMutableArray *_resultTokens;
    __weak MHObjectGetter _getter;
    __strong id _object;
}

- (id)init {
    self = [super init];
    if (self) {
        _resultTokens = [NSMutableArray array];
    }
    return self;
}

+ (instancetype)searchResultItemWithIdentifier:(NSData *)identifier andObjectGetter:(MHObjectGetter)getter {
    MHSearchResultItem *item = [[self alloc] init];
    item->_identifier = [identifier copy];
    item->_getter = getter;
    return item;
}

- (void)addResultToken:(MHResultToken)token {
    NSParameterAssert(strncmp(token.identifier, _identifier.bytes, MIN(token.length, _identifier.length)) == 0);
    [_resultTokens addObject:[NSIndexPath mh_searchResultindexPathForString:token.stringIndex word:token.wordIndex token:token.tokenIndex]];
}

- (id)object {
    if (!_object) {
        _object = _getter(self.identifier);
    }
    return _object;
}

@end

@implementation NSIndexPath (MHSearchResult)

+ (NSIndexPath *)mh_searchResultindexPathForString:(NSUInteger)string word:(NSUInteger)word token:(NSUInteger)token {
    NSUInteger indices[3] = {string, word, token};
    return [self indexPathWithIndexes:indices length:3];
}

- (NSUInteger)mh_string {
    return [self indexAtPosition:0];
}
- (NSUInteger)mh_token {
    return [self indexAtPosition:2];
}
- (NSUInteger)mh_word {
    return [self indexAtPosition:1];
}

@end