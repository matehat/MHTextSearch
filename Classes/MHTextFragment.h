//
//  MHTextFragment.h
//  
//
//  Created by Mathieu D'Amours on 1/14/14.
//
//

#import <Foundation/Foundation.h>

@interface MHTextFragment : NSObject

@property (strong) NSData *     identifier;
@property (strong) NSArray *    indexedStrings;
@property          CGFloat      weight;

@end
