//
//  MHIndexedObject.h
//  
//
//  Created by Mathieu D'Amours on 1/14/14.
//
//

#import <Foundation/Foundation.h>

@interface MHIndexedObject : NSObject

@property (strong) NSData *     identifier;
@property (strong) NSArray *    strings;
@property          CGFloat      weight;

@property (strong) NSDictionary * context;

@end
