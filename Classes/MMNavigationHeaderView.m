//
//  MMNavigationHeaderView.m
//  MMNavigationController
//
//  Created by Matías Martínez on 1/27/15.
//  Copyright (c) 2015 Matías Martínez. All rights reserved.
//

#import "MMNavigationHeaderView.h"

@interface MMNavigationHeaderView () {
    struct {
        unsigned int usingMultilineHeading : 1;
        unsigned int usingCustomTitleView : 1;
        unsigned int showsRightButton : 1;
        unsigned int showsLeftButton : 1;
        unsigned int showsBackButton : 1;
        unsigned int usingRegularBackButton : 1;
    } _configurationOptions;
}

@property (strong, nonatomic) UILabel *titleLabel;
@property (strong, nonatomic) UILabel *subtitleLabel;

@property (strong, nonatomic) UIButton *regularBackButton;
@property (strong, nonatomic) UIButton *compactBackButton;
@property (assign, nonatomic) BOOL backActionAvailable;

@property (readonly, nonatomic) BOOL pagingEnabled;
@property (assign, nonatomic) BOOL rotatesBackButton;
@property (assign, nonatomic) CGFloat interSpacing;
@property (assign, nonatomic) CGFloat barButtonSpacing;
@property (assign, nonatomic) CGFloat backButtonSpacing;

@property (strong, nonatomic) UIView *separatorView;

@end

@implementation MMNavigationHeaderView

#define UIKitLocalizedString(key) [[NSBundle bundleWithIdentifier:@"com.apple.UIKit"] localizedStringForKey:key value:@"" table:nil]

#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v) \
([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.clipsToBounds = NO;
        
        // Metrics.
        const BOOL UINavigationBarUsesLongerEdges = SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"10.0");
        
        _backButtonSpacing = 8.0f;
        _barButtonSpacing = UINavigationBarUsesLongerEdges ? 16.0f : 8.0f;
        _interSpacing = 5.0;
        
        // Defaults.
        _separatorColor = [UIColor colorWithWhite:0.0f alpha:0.2f];
        
        // Background view.
        UIView *backgroundView = [[UIView alloc] initWithFrame:CGRectZero];
        backgroundView.backgroundColor = [UIColor whiteColor];
        backgroundView.userInteractionEnabled = NO;
        
        _backgroundView = backgroundView;
        
        [self addSubview:backgroundView];
        
        // Separator view.
        UIView *separatorView = [[UIView alloc] initWithFrame:CGRectZero];
        separatorView.backgroundColor = _separatorColor;
        separatorView.userInteractionEnabled = NO;
        
        _separatorView = separatorView;
        
        [self addSubview:separatorView];
        
        // Title label.
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        
        _titleLabel = titleLabel;
        
        [self addSubview:titleLabel];
        
        // Subtitle label.
        UILabel *subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        
        _subtitleLabel = subtitleLabel;
        
        [self addSubview:subtitleLabel];
        
        // Buttons.
        UIButton *regularBackButton = [UIButton buttonWithType:UIButtonTypeSystem];
        UIButton *compactBackButton = [UIButton buttonWithType:UIButtonTypeSystem];
        
        UIImage *backButtonImage = [[UIImage imageNamed:@"MMNavigationBackIndicatorDefault.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        backButtonImage.accessibilityLabel = UIKitLocalizedString(@"Back");
        
        for (UIButton *backButton in @[ regularBackButton, compactBackButton ]) {
            [backButton setImage:backButtonImage forState:UIControlStateNormal];
            [backButton addTarget:self action:@selector(_backButtonTouchUpInside:) forControlEvents:UIControlEventTouchUpInside];
        }
        
        static const CGFloat chevronTitleSpacing = 6.0f;
        [regularBackButton setTitleEdgeInsets:UIEdgeInsetsMake(0, chevronTitleSpacing, 0, -chevronTitleSpacing)];
        [regularBackButton setContentEdgeInsets:UIEdgeInsetsMake(0, 0, 0, chevronTitleSpacing)];
        
        _regularBackButton = regularBackButton;
        _compactBackButton = compactBackButton;
        
        [self addSubview:regularBackButton];
        [self addSubview:compactBackButton];
        
        // Assign fonts.
        [self _assignFonts];
        
        // Size.
        [self sizeToFit];
    }
    return self;
}

- (void)_assignFonts
{
    static const CGFloat headingPointSize = 17.0f;
    static const CGFloat subheadingPointSize = 14.0f;
    
    _configurationOptions.usingMultilineHeading = (self.subtitle.length > 0 && self.title.length > 0);
    
    if (_configurationOptions.usingMultilineHeading) {
        _titleLabel.font = self.titleTextAttributes[NSFontAttributeName] ?: [UIFont boldSystemFontOfSize:subheadingPointSize];
        _subtitleLabel.font = self.subtitleTextAttributes[NSFontAttributeName] ?: [UIFont systemFontOfSize:subheadingPointSize];
    } else {
        _titleLabel.font = self.titleTextAttributes[NSFontAttributeName] ?: [UIFont boldSystemFontOfSize:headingPointSize];
    }
    
    _regularBackButton.titleLabel.font = [UIFont systemFontOfSize:headingPointSize];
}

#pragma mark - Actions.

- (void)_backButtonTouchUpInside:(id)sender
{
    MMNavigationHeaderAction backButtonAction = self.backButtonAction;
    
    MMNavigationController *navigationController = self.navigationController;
    UIViewController *viewController = self.viewController;
    
    BOOL isFirstVisibleViewController = (navigationController.visibleViewControllers.firstObject == viewController);
    if (isFirstVisibleViewController) {
        UIViewController *previousViewController = self.previousViewController;
        if (backButtonAction == MMNavigationHeaderActionPop) {
            [navigationController popToViewController:previousViewController animated:YES];
        } else if (backButtonAction == MMNavigationHeaderActionScroll) {
            [navigationController scrollToViewController:previousViewController animated:YES];
        }
    } else {
        [navigationController scrollToViewController:viewController animated:YES];
    }
}

#pragma mark - Layout.

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    const CGFloat backEdgeSpacing = _backButtonSpacing;
    const CGFloat edgeSpacing = _barButtonSpacing;
    const CGFloat interSpacing = _interSpacing;
    
    // Rects to calculate.
    UIView *actualLeftButton = nil;
    
    // First, what we should display here?
    BOOL pagingEnabled = self.pagingEnabled;
    BOOL isLastViewController = self.navigationController.viewControllers.lastObject == self.viewController;
    BOOL isHiddenInLastColumn = !pagingEnabled && isLastViewController;
    
    BOOL showsLeftButton = _leftButton != nil;
    BOOL showsRightButton = _rightButton != nil;
    BOOL showsBackButton = !isHiddenInLastColumn && !showsLeftButton && !_hidesBackButton && _backActionAvailable;
    BOOL usesMultilineHeading = _configurationOptions.usingMultilineHeading;
    BOOL usesCustomTitleView = _titleView != nil;
    
    UIEdgeInsets contentInset;
    if (showsBackButton) {
        contentInset = (UIEdgeInsets){ .left = backEdgeSpacing, .right = edgeSpacing };
    } else {
        contentInset = (UIEdgeInsets){ .left = edgeSpacing, .right = edgeSpacing };
    }
    
    const CGRect bounds = (CGRect){ .size = self.bounds.size };
    const CGRect contentRect = UIEdgeInsetsInsetRect(bounds, contentInset);
    const CGSize fit = contentRect.size;
    
    // Calculate title width.
    CGSize sizeNeededToFitTitle = CGSizeZero;
    CGSize tSize = CGSizeZero;
    CGSize sSize = CGSizeZero;
    
    if (usesCustomTitleView) {
        sizeNeededToFitTitle = [_titleView sizeThatFits:fit];
    } else {
        tSize = [_titleLabel sizeThatFits:fit];
        sSize = [_subtitleLabel sizeThatFits:fit];
        
        if (usesMultilineHeading) {
            sizeNeededToFitTitle = CGSizeMake(MAX(tSize.width, sSize.width), tSize.height + sSize.height);
        } else {
            sizeNeededToFitTitle = tSize;
        }
    }
    
    // Calculate back button.
    BOOL useRegularBackButton = NO;
    if (showsBackButton) {
        if (pagingEnabled) {
            CGFloat rightCompression = 0.0f;
            if (showsRightButton) {
                rightCompression = [_rightButton sizeThatFits:fit].width;
            }
            
            CGFloat availableTitleBackWidth = CGRectGetWidth(contentRect) - rightCompression - edgeSpacing;
            CGFloat regularBackButtonWidth = [_regularBackButton sizeThatFits:fit].width;
            
            useRegularBackButton = (regularBackButtonWidth + interSpacing + sizeNeededToFitTitle.width < availableTitleBackWidth);
            if (useRegularBackButton) {
                actualLeftButton = _regularBackButton;
            } else {
                actualLeftButton = _compactBackButton;
            }
        } else {
            actualLeftButton = _compactBackButton;
        }
    } else {
        actualLeftButton = _leftButton;
    }
    
    // Layout for once!
    CGSize leftButtonSize = [actualLeftButton sizeThatFits:fit];
    CGRect leftButtonRect = (CGRect){
        .origin.x = CGRectGetMinX(contentRect),
        .origin.y = ceilf((CGRectGetHeight(bounds) - leftButtonSize.height) / 2.0f),
        .size = leftButtonSize
    };
    
    CGSize rightButtonSize = [_rightButton sizeThatFits:fit];
    CGRect rightButtonRect = (CGRect){
        .origin.x = CGRectGetMaxX(contentRect) - rightButtonSize.width,
        .origin.y = ceilf((CGRectGetHeight(bounds) - rightButtonSize.height) / 2.0f),
        .size = rightButtonSize
    };
    
    // Title.
    CGRect titleAlignmentRect = UIEdgeInsetsInsetRect(contentRect, (UIEdgeInsets){
        .left = leftButtonSize.width + interSpacing,
        .right = rightButtonSize.width + interSpacing
    });
    
    // Align components.
    const CGFloat titleAlignmentHeight = sizeNeededToFitTitle.height;
    
    CGRect titleLabelRect = CGRectZero;
    CGRect subtitleLabelRect = CGRectZero;
    CGRect titleViewRect = CGRectZero;
    
    if (usesCustomTitleView) {
        titleViewRect = (CGRect){
            .origin.y = ceilf((CGRectGetHeight(bounds) - titleAlignmentHeight) / 2),
            .size.width = MIN(sizeNeededToFitTitle.width, CGRectGetWidth(titleAlignmentRect)),
            .size.height = sizeNeededToFitTitle.height
        };
        
        if (((NSInteger)(CGRectGetWidth(bounds) - sizeNeededToFitTitle.width) / 2.0f) > CGRectGetMinX(titleAlignmentRect)) {
            titleViewRect.origin.x = ceilf((CGRectGetWidth(bounds) - CGRectGetWidth(titleViewRect)) / 2.0f);
        } else {
            titleViewRect.origin.x = ceilf(CGRectGetMinX(titleAlignmentRect));
        }
    } else {
        titleLabelRect = (CGRect){
            .origin.y = ceilf((CGRectGetHeight(bounds) - titleAlignmentHeight) / 2),
            .size.width = MIN(tSize.width, CGRectGetWidth(titleAlignmentRect)),
            .size.height = tSize.height
        };
        
        subtitleLabelRect = (CGRect){
            .origin.y = ceilf(CGRectGetMaxY(titleLabelRect)),
            .size.width = MIN(sSize.width, CGRectGetWidth(titleAlignmentRect)),
            .size.height = sSize.height
        };
        
        if (((NSInteger)(CGRectGetWidth(bounds) - sizeNeededToFitTitle.width) / 2.0f) > CGRectGetMinX(titleAlignmentRect)) {
            titleLabelRect.origin.x = ceilf((CGRectGetWidth(bounds) - CGRectGetWidth(titleLabelRect)) / 2.0f);
            subtitleLabelRect.origin.x = ceilf((CGRectGetWidth(bounds) - CGRectGetWidth(subtitleLabelRect)) / 2.0f);
        } else {
            titleLabelRect.origin.x = ceilf(CGRectGetMinX(titleAlignmentRect) + ((sizeNeededToFitTitle.width - tSize.width) / 2.0f));
            subtitleLabelRect.origin.x = ceilf(CGRectGetMinX(titleAlignmentRect) + ((sizeNeededToFitTitle.width - sSize.width) / 2.0f));
        }
    }
    
    // Background & separator.
    CGRect separatorRect = (CGRect){
        .origin.y = CGRectGetHeight(bounds),
        .size.width = CGRectGetWidth(bounds),
        .size.height = 1.0f / [UIScreen mainScreen].scale,
    };
    
    CGRect backgroundRect = UIEdgeInsetsInsetRect(bounds, (UIEdgeInsets){
        .top = -20.0f
    });
    
    // Apply computed properties.
    [CATransaction begin];
    [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
    actualLeftButton.frame = leftButtonRect;
    [CATransaction commit];
    
    _rightButton.frame = rightButtonRect;
    _titleLabel.frame = titleLabelRect;
    _subtitleLabel.frame = subtitleLabelRect;
    _titleView.frame = titleViewRect;
    _titleLabel.hidden = usesCustomTitleView;
    _subtitleLabel.hidden = usesCustomTitleView;
    _separatorView.frame = separatorRect;
    _backgroundView.frame = backgroundRect;
    
    // Use alpha instead of hidden, so clients can get a fade animation when needed.
    _regularBackButton.alpha = !useRegularBackButton || !showsBackButton ? 0.0f : 1.0f;
    _compactBackButton.alpha = useRegularBackButton || !showsBackButton ? 0.0f : 1.0f;
    
    // Save configuration.
    _configurationOptions.showsBackButton = showsBackButton;
    _configurationOptions.showsLeftButton = showsLeftButton;
    _configurationOptions.showsBackButton = showsBackButton;
    _configurationOptions.usingRegularBackButton = useRegularBackButton;
    _configurationOptions.usingCustomTitleView = usesCustomTitleView;
}

- (CGSize)sizeThatFits:(CGSize)size
{
    size.height = 44.0f;
    
    return size;
}

#pragma mark - Updates.

- (void)navigationControllerWillDisplayViewController
{
    UIViewController *previousViewController = self.previousViewController;
    if (previousViewController) {
        MMNavigationHeaderView *headerView = (MMNavigationHeaderView *)[self.navigationController headerViewForViewController:previousViewController];
        NSString *backTitle = headerView.backButtonTitle ?: headerView.title ?: previousViewController.title;
        
        [self.regularBackButton setTitle:backTitle forState:UIControlStateNormal];
        
        [self setBackActionAvailable:(previousViewController != nil)];
        [self setNeedsLayout];
    }
}

- (void)didMoveToNavigationController
{
    if (!self.pagingEnabled) {
        BOOL firstVisibleViewController = (self.navigationController.visibleViewControllers.firstObject == self.viewController);
        
        [self setRotatesBackButton:!firstVisibleViewController];
    }
}

- (void)navigationControllerWillSnapToViewController:(UIViewController *)viewController
{
    if (!self.pagingEnabled) {
        [self setRotatesBackButton:(viewController != self.viewController)];
    }
}

- (void)navigationControllerViewControllersDidChange
{
    [self setNeedsLayout];
}

#pragma mark - Back rotation.

- (void)setRotatesBackButton:(BOOL)rotatesBackButton
{
    if (rotatesBackButton != _rotatesBackButton) {
        _rotatesBackButton = rotatesBackButton;
        
        CGAffineTransform t = rotatesBackButton ? CGAffineTransformMakeRotation(M_PI) : CGAffineTransformIdentity;
        
        BOOL animated = self.window != nil;
        if (animated) {
            [UIView animateWithDuration:0.5f delay:0 usingSpringWithDamping:0.9f initialSpringVelocity:1.0f options:UIViewAnimationOptionBeginFromCurrentState animations:^{
                _compactBackButton.transform = t;
            } completion:NULL];
        } else {
            _compactBackButton.transform = t;
        }
    }
}

- (BOOL)pagingEnabled
{
    return self.navigationController.scrollMode == MMNavigationScrollModePaging;
}

#pragma mark - Hit testing.

- (BOOL)_pointInside:(CGPoint)point withEvent:(UIEvent *)event proposedButton:(UIButton *)button
{
    UIView *hitTest = [super hitTest:button.center withEvent:event];
    if ([hitTest isDescendantOfView:button]) {
        CGRect rect = CGRectZero;
        rect.origin.x = CGRectGetMinX(button.frame);
        rect.size.width = CGRectGetWidth(button.frame);
        rect.size.height = CGRectGetHeight(self.bounds);
        
        CGRect targetPointInsideHeaderRect = CGRectInset(rect, -15.0f, -15.0f);
        
        return CGRectContainsPoint(targetPointInsideHeaderRect, point);
    }
    return NO;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *hitTest = [super hitTest:point withEvent:event];
    if (!hitTest || hitTest == self || hitTest == self.backgroundView) {
        for (UIView *subview in self.subviews) {
            UIButton *button = (UIButton *)subview;
            if ([self _pointInside:point withEvent:event proposedButton:button]) {
                return button;
            }
        }
    }
    return hitTest;
}

#pragma mark - Props.

- (void)setTitle:(NSString *)title
{
    if (![title isEqualToString:self.title]) {
        _title = title;
        _titleLabel.text = title;
        
        [self _assignFonts];
        [self setNeedsLayout];
    }
}

- (void)setSubtitle:(NSString *)subtitle
{
    if (![subtitle isEqualToString:self.subtitle]) {
        _subtitle = subtitle;
        _subtitleLabel.text = subtitle;
        
        [self _assignFonts];
        [self setNeedsLayout];
    }
}

- (void)setTitleView:(UIView *)titleView
{
    if (titleView != _titleView) {
        [_titleView removeFromSuperview];
        
        _titleView = titleView;
        
        if (titleView) {
            [self addSubview:titleView];
            [self setNeedsLayout];
        }
    }
}

- (void)setHidesBackButton:(BOOL)hidesBackButton
{
    if (hidesBackButton != self.hidesBackButton) {
        [self setNeedsLayout];
    }
}

- (void)setLeftButton:(UIButton *)leftButton
{
    if (leftButton != self.leftButton) {
        [_leftButton removeFromSuperview];
        
        _leftButton = leftButton;
        
        [self addSubview:leftButton];
        [self setNeedsLayout];
    }
}

- (void)setRightButton:(UIButton *)rightButton
{
    if (rightButton != self.rightButton) {
        [_rightButton removeFromSuperview];
        
        _rightButton = rightButton;
        
        [self addSubview:rightButton];
        [self setNeedsLayout];
    }
}

#pragma mark - Appearance.

- (void)setBackgroundView:(UIView *)backgroundView
{
    if (backgroundView != _backgroundView) {
        [_backgroundView removeFromSuperview];
        
        _backgroundView = backgroundView;
        
        [self insertSubview:backgroundView atIndex:0];
        [self setNeedsLayout];
    }
}

- (void)setSeparatorColor:(UIColor *)separatorColor
{
    if (separatorColor != _separatorColor) {
        _separatorColor = separatorColor;
        _separatorView.backgroundColor = separatorColor;
    }
}

- (void)setTitleTextAttributes:(NSDictionary *)titleTextAttributes
{
    if (![titleTextAttributes isEqualToDictionary:_titleTextAttributes]) {
        _titleTextAttributes = titleTextAttributes;
        
        [self _applyTextAttribures:titleTextAttributes toTextLabel:_titleLabel];
        [self _assignFonts];
    }
}

- (void)setSubtitleTextAttributes:(NSDictionary *)subtitleTextAttributes
{
    if (![subtitleTextAttributes isEqualToDictionary:_subtitleTextAttributes]) {
        _subtitleTextAttributes = subtitleTextAttributes;
        
        [self _applyTextAttribures:subtitleTextAttributes toTextLabel:_subtitleLabel];
        [self _assignFonts];
    }
}

- (void)_applyTextAttribures:(NSDictionary *)textAttributes toTextLabel:(UILabel *)textLabel
{
    [textAttributes enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSString *attribute = key;
        
        if ([attribute isEqualToString:NSForegroundColorAttributeName]) {
            [textLabel setTextColor:obj];
        } else if ([attribute isEqualToString:NSFontAttributeName]) {
            [textLabel setFont:obj];
        } else if ([attribute isEqualToString:NSShadowAttributeName]) {
            NSShadow *textShadow = obj;
            
            [textLabel setShadowColor:textShadow.shadowColor];
            [textLabel setShadowOffset:textShadow.shadowOffset];
        }
    }];
}

@end
