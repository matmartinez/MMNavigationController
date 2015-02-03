//
//  MMNavigationHeaderView.h
//  MMNavigationController
//
//  Created by Matías Martínez on 1/27/15.
//  Copyright (c) 2015 Matías Martínez. All rights reserved.
//

#import "MMNavigationController.h"

typedef NS_ENUM(NSUInteger, MMNavigationHeaderAction) {
    MMNavigationHeaderActionScroll = 0,
    MMNavigationHeaderActionPop
};

@interface MMNavigationHeaderView : MMNavigationSupplementaryView

@property (copy, nonatomic) NSString *title;
@property (copy, nonatomic) NSString *subtitle;

@property (copy, nonatomic) NSString *backButtonTitle;
@property (assign, nonatomic) BOOL hidesBackButton;
@property (assign, nonatomic) MMNavigationHeaderAction backButtonAction;

@property (strong, nonatomic) UIButton *leftButton;
@property (strong, nonatomic) UIButton *rightButton;

// Appearance.
@property (nonatomic, copy) NSDictionary *titleTextAttributes UI_APPEARANCE_SELECTOR;
@property (nonatomic, copy) NSDictionary *subtitleTextAttributes UI_APPEARANCE_SELECTOR;
@property (strong, nonatomic) UIColor *separatorColor UI_APPEARANCE_SELECTOR;

@property (strong, nonatomic) UIView *backgroundView;

@end
