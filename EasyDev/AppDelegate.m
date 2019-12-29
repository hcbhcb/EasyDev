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
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];

    NSString *src = [[NSString alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Es.py" ofType:nil] encoding:NSUTF8StringEncoding error:nil];
    [[EasyDev share] loadSrc:src agr:nil];
    return YES;
}


@end
