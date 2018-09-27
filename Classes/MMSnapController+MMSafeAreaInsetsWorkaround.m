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

NS_INLINE void MMSnapOverrideInstanceMethod(Class aClass, SEL overrideSelector, SEL withSelector){
    Method workaroundMethod = class_getInstanceMethod(aClass, withSelector);
    IMP workaroundImplementation = method_getImplementation(workaroundMethod);
    
    class_addMethod(aClass, overrideSelector, workaroundImplementation, method_getTypeEncoding(workaroundMethod));
};

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        const BOOL requiresWorkaround = ([UIView instancesRespondToSelector:@selector(safeAreaInsets)]);
        
        if (requiresWorkaround) {
            NSString *safeAreaForChildOverrideSelectorString = [@[ @"_edgeI", @"nsetsForChildView", @"Controller:insetsAreA", @"bsolute:" ] componentsJoinedByString:@""];
            
            MMSnapOverrideInstanceMethod(self, NSSelectorFromString(safeAreaForChildOverrideSelectorString), @selector(MM_safeAreaInsetsForChildViewController:insetsAreAbsolute:));
            
            NSString *marginForChildOverrideSelectorString = [@[ @"_marginI", @"nfoForChild:lef", @"tMargin:righ" , @"tMargin:" ] componentsJoinedByString:@""];
            
            MMSnapOverrideInstanceMethod(self, NSSelectorFromString(marginForChildOverrideSelectorString), @selector(MM_marginForChildViewController:leftMargin:rightMargin:));
        }
    });
}

- (UIEdgeInsets)MM_safeAreaInsetsForChildViewController:(UIViewController *)childViewController insetsAreAbsolute:(BOOL *)absolute
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
    if (@available(iOS 11.0, *)) {
        if (self.scrollMode == MMSnapScrollModePaging) {
            if (absolute) {
                *absolute = YES;
            }
            return self.view.safeAreaInsets;
        }
    }
#endif
    return UIEdgeInsetsZero;
}

- (void)MM_marginForChildViewController:(UIViewController *)childViewController leftMargin:(inout CGFloat *)left rightMargin:(inout CGFloat *)right
{
    
}

@end
