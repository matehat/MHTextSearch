//
//  AppDelegate.m
//  iPhone Performance Test
//
//  Created by Mathieu D'Amours on 1/14/14.
//
//

#import <MHTextSearch.h>
#import "AppDelegate.h"

@implementation AppDelegate {
    
    MHTextIndex *textIndex;
//    NSMutableArray *texts;
    NSMutableArray *textPaths;
}

#define CREATE_NEW_INDEX
#define INDEX_TEXTS
CGFloat sizeOfIndexedTexts = 0;

- (void)measureWithSize:(CGFloat)size {
    
    [textIndex setIdentifier:^NSData *(id object){
        NSUInteger indexVal = [object integerValue];
        return [NSData dataWithBytes:&indexVal length:sizeof(NSUInteger)];
    }];
    
    __weak AppDelegate *_wself = self;
    [textIndex setObjectGetter:^id(NSData *identifier){
        __strong AppDelegate *_sself = _wself;
        NSUInteger nameIdx = 0;
        [identifier getBytes:&nameIdx];
        return _sself->textPaths[nameIdx];
    }];
    [textIndex setIndexer:^MHIndexedObject *(id object, NSData *key){
        MHIndexedObject *frag = [MHIndexedObject new];
        NSUInteger idx = [object integerValue];
        __strong AppDelegate *_sself = _wself;
        frag.identifier = key;
        
        NSString * childPath = _sself->textPaths[idx];
        NSString *textContent = [NSString stringWithContentsOfFile:childPath
                                                          encoding:NSUTF8StringEncoding
                                                             error:NULL];
        frag.strings = @[ textContent ];
        frag.context = @{ @"path": childPath };
        return frag;
    }];

#ifdef INDEX_TEXTS
    NSString *textsDirPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"texts"];
    if (!textsDirPath)
        return;
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:textsDirPath];
    NSString *childPath;
    NSUInteger totalSize = 0, count = 0;
    
    CFAbsoluteTime t1 = CFAbsoluteTimeGetCurrent();
    for (id child in enumerator) {
        if ([child hasSuffix:@".txt"]) {
            NSError *error;
            childPath = [textsDirPath stringByAppendingPathComponent:child];
            NSString *textContent = [NSString stringWithContentsOfFile:childPath
                                                              encoding:NSUTF8StringEncoding
                                                                 error:&error];
            if (error) {
                continue;
            } else {
                
                if (totalSize >= (size + 0.5)*1024*1024) {
                    break;
                } else if (totalSize >= size*1024*1024) {
                    [textPaths addObject:childPath];
                    [textIndex indexObject:@(count)];
                }
                
                count++;
                totalSize += [textContent lengthOfBytesUsingEncoding:[textContent fastestEncoding]];
            }
        }
    }
    
    NSLog(@"Total bytes for %d files: %d", count, totalSize);
    
    [textIndex.indexingQueue waitUntilAllOperationsAreFinished];
    NSLog(@"Indexing %d texts happened in %f seconds", textPaths.count, CFAbsoluteTimeGetCurrent() - t1);
    
    double delayInSeconds = size*2;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
#endif
        CFAbsoluteTime t2;
        CFAbsoluteTime minTime = CGFLOAT_MAX;
        
        NSArray *results;
        for (int i=0; i<20; i++) {
            t2 = CFAbsoluteTimeGetCurrent();
            results = [textIndex searchResultForKeyword:@"hat" options:0];
            minTime = MIN(CFAbsoluteTimeGetCurrent() - t2, minTime);
        }
        NSLog(@"Search yielding %d results, over %d files, happened in %f seconds\n\n", results.count, textPaths.count, minTime);
        
        double delayInSeconds = 0.5;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self measureWithSize:size+0.5];
        });
#ifdef INDEX_TEXTS
    });
#endif
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    
#ifdef CREATE_NEW_INDEX
    textIndex = [MHTextIndex textIndexInLibraryWithName:@"textIndex"];
    [textIndex deleteFromDisk];
#endif
    
    textIndex = [MHTextIndex textIndexInLibraryWithName:@"textIndex"];
    textIndex.indexingQueue.maxConcurrentOperationCount = 2;
    
    textPaths = [NSMutableArray arrayWithCapacity:2000];
    
    double delayInSeconds = 0.1;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self measureWithSize:sizeOfIndexedTexts];
    });
    
    return YES;}

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
