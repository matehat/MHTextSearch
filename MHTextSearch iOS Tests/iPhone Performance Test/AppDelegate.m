//
//  AppDelegate.m
//  iPhone Performance Test
//
//  Created by Mathieu D'Amours on 1/14/14.
//
//

#import <MHTextSearch/MHTextIndex.h>
#import "AppDelegate.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    
    MHTextIndex *index;
    NSArray *names;
    
    index = [MHTextIndex textIndexInLibraryWithName:@"testIndex"];
    [index deleteFromDisk];
    
    index = [MHTextIndex textIndexInLibraryWithName:@"testIndex"];
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"Names" ofType:@"txt"];
    NSString *namesRaw = [NSString stringWithContentsOfFile:path
                                                   encoding:NSUTF8StringEncoding
                                                      error:NULL];
    names = [namesRaw componentsSeparatedByString:@"\n"];
    
    [index setIdentifier:^NSData *(id object){
        NSUInteger indexVal = [object integerValue];
        return [NSData dataWithBytes:&indexVal length:sizeof(NSUInteger)];
    }];
    [index setObjectGetter:^id(NSData *identifier){
        NSUInteger nameIndex = 0;
        [identifier getBytes:&nameIndex];
        return names[nameIndex];
    }];
    [index setFragmenter:^MHTextFragment *(id object, NSData *key){
        MHTextFragment *frag = [MHTextFragment new];
        frag.identifier = key;
        frag.indexedStrings = @[[names objectAtIndex:[object integerValue]]];
        return frag;
    }];
    
    CFAbsoluteTime t1 = CFAbsoluteTimeGetCurrent();
    [names enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [index indexObject:@(idx) error:NULL];
    }];
    [index.indexingQueue waitUntilAllOperationsAreFinished];
    NSLog(@"Indexing %lu names happened in %f seconds", (unsigned long)names.count, CFAbsoluteTimeGetCurrent() - t1);
    
    CFAbsoluteTime t2 = CFAbsoluteTimeGetCurrent();
    NSArray *results = [index searchResultForKeyword:@"ja" options:0];
    NSLog(@"Search over %lu names happened in %f seconds", (unsigned long)names.count, CFAbsoluteTimeGetCurrent() - t2);
    
    NSAssert(results.count == 8, @"The search should yield exactly 8 results.");
    
//    [index deleteFromDisk];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
