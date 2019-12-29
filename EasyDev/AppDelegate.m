//
//  AppDelegate.m
//  EasyDev
//
//  Created by hcb on 2019/12/13.
//  Copyright © 2019 cb. All rights reserved.
//

#import "AppDelegate.h"
#import "EasyDev.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    
    NSString *sc = [[NSString alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Es.py" ofType:nil] encoding:NSUTF8StringEncoding error:nil];
//    po [[NSString alloc] initWithContentsOfFile:@"/private/var/containers/Bundle/Application/68FBDD25-7C9A-46D5-A2D3-DB38D0BD13B6/test.app/ES.py" encoding:4 error:nil];
    self.window.rootViewController = [[UIViewController alloc] init];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[EasyDev share] loadSrc:sc agr:nil];        
    });
    [self.window makeKeyAndVisible];
    return YES;
}


@end
