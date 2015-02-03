//
//  AppDelegate.m
//  MMNavigationController
//
//  Created by Matías Martínez on 1/11/15.
//  Copyright (c) 2015 Matías Martínez. All rights reserved.
//

#import "AppDelegate.h"
#import "MMNavigationController.h"
#import "ViewController.h"

@interface AppDelegate () <MMNavigationControllerDelegate>

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSArray *colors = @[ [UIColor colorWithRed:0.501 green:0.447 blue:0.928 alpha:1],
                         [UIColor colorWithRed:0 green:0.81 blue:0.988 alpha:1],
                         [UIColor colorWithRed:1 green:0.809 blue:0 alpha:1],
                         [UIColor colorWithRed:0 green:0.854 blue:0.352 alpha:1] ];
    
    NSMutableArray *viewControllers = [NSMutableArray arrayWithCapacity:colors.count];
    for (UIColor *color in colors) {
        ViewController *vc = [ViewController new];
        vc.color = color;
        
        [viewControllers addObject:vc];
    }
    
    MMNavigationController *navigationController = [[MMNavigationController alloc] initWithViewControllers:viewControllers];
    navigationController.delegate = self;
    
    UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    window.rootViewController = navigationController;
    
    [window makeKeyAndVisible];
    
    self.window = window;
    
    return YES;
}

- (MMViewControllerMetrics)navigationController:(MMNavigationController *)nc metricsForViewController:(UIViewController *)viewController
{
    if (nc.viewControllers.lastObject == viewController) {
        return MMViewControllerMetricsLarge;
    }
    return MMViewControllerMetricsDefault;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
