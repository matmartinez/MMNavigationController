//
//  MMSnapHeaderView.h
//  MMSnapController
//
//  Created by Matías Martínez on 1/27/15.
//  Copyright (c) 2015 Matías Martínez. All rights reserved.
//

#import "MMSnapController.h"

typedef NS_ENUM(NSUInteger, MMSnapHeaderAction) {
    MMSnapHeaderActionScroll = 0,
    MMSnapHeaderActionPop
};

@interface MMSnapHeaderView : MMSnapSupplementaryView

@property (copy, nonatomic) NSString *title;
@property (copy, nonatomic) NSString *subtitle;
@property (strong, nonatomic) UIView *titleView;

@property (copy, nonatomic) NSString *backButtonTitle;
@property (assign, nonatomic) BOOL hidesBackButton;
@property (assign, nonatomic) MMSnapHeaderAction backButtonAction;

@property (strong, nonatomic) UIButton *leftButton;
@property (strong, nonatomic) UIButton *rightButton;

// Appearance.
@property (nonatomic, copy) NSDictionary *titleTextAttributes UI_APPEARANCE_SELECTOR;
@property (nonatomic, copy) NSDictionary *subtitleTextAttributes UI_APPEARANCE_SELECTOR;
@property (strong, nonatomic) UIColor *separatorColor UI_APPEARANCE_SELECTOR;

@property (strong, nonatomic) UIView *backgroundView;

@end
