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
    __weak id (^_getter)(NSData *identifier);
    __strong id _object;
    NSUInteger _length;
}

- (id)init {
    self = [super init];
    if (self) {
        _resultTokens = [NSMutableArray array];
    }
    return self;
}

+ (instancetype)searchResultItemWithIdentifier:(NSData *)identifier
                                       keyword:(NSString *)keyword
                                  objectGetter:(id(^)(NSData *identifier))getter {
    
    MHSearchResultItem *item = [[self alloc] init];
    item->_length = keyword.length;
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

- (NSRange) rangeOfTokenInString:(NSIndexPath *)token {
    return (NSRange){token.mh_token + token.mh_word, _length};
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
- (NSUInteger)mh_word {
    return [self indexAtPosition:1];
}
- (NSUInteger)mh_token {
    return [self indexAtPosition:2];
}

@end