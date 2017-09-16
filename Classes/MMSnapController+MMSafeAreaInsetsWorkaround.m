//
//  MMSnapController+MMSafeAreaInsetsWorkaround.m
//  MMSnapController
//
//  Created by Matías Martínez on 9/15/17.
//  Copyright © 2017 Matías Martínez. All rights reserved.
//

#import "MMSnapController+MMSafeAreaInsetsWorkaround.h"
#import <objc/runtime.h>

@implementation MMSnapController (MMSafeAreaInsetsWorkaround)

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        const BOOL requiresWorkaround = ([UIView instancesRespondToSelector:@selector(safeAreaInsets)]);
        if (requiresWorkaround) {
            NSString *overrideSelectorString = [@[ @"_edgeI", @"nsetsForChildView", @"Controller:insetsAreA", @"bsolute:" ] componentsJoinedByString:@""];
            SEL overrideSelector = NSSelectorFromString(overrideSelectorString);
            
            Method workaroundMethod = class_getInstanceMethod(self, @selector(MM_safeAreaInsetsForChildViewController:insetsAreAbsolute:));
            IMP workaroundImplementation = method_getImplementation(workaroundMethod);
            
            class_addMethod(self, overrideSelector, workaroundImplementation, method_getTypeEncoding(workaroundMethod));
        }
    });
}

- (UIEdgeInsets)MM_safeAreaInsetsForChildViewController:(UIViewController *)childViewController insetsAreAbsolute:(BOOL *)absolute
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
    if (@available(iOS 11.0, *)) {
        if (absolute) {
            *absolute = YES;
        }
        return self.view.safeAreaInsets;
    }
#endif
    return UIEdgeInsetsZero;
}

@end
