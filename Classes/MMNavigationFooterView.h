//
//  MMNavigationFooterView.h
//  MMNavigationController
//
//  Created by Matías Martínez on 1/27/15.
//  Copyright (c) 2015 Matías Martínez. All rights reserved.
//

#import "MMNavigationController.h"

extern const CGFloat MMNavigationFooterFlexibleWidth;

@interface MMNavigationFooterView : MMNavigationSupplementaryView

@property (copy, nonatomic) NSArray *items;

@property (strong, nonatomic) UIColor *separatorColor UI_APPEARANCE_SELECTOR;

@property (strong, nonatomic) UIView *backgroundView;

@end

@interface MMNavigationFooterSpace : NSObject

@property (assign, nonatomic) CGFloat width;

@end
