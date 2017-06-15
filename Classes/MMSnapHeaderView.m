//
//  MMSnapHeaderView.m
//  MMSnapController
//
//  Created by Matías Martínez on 1/27/15.
//  Copyright (c) 2015 Matías Martínez. All rights reserved.
//

#import "MMSnapHeaderView.h"

@interface MMSnapHeaderView () {
    struct {
        unsigned int usingMultilineHeading : 1;
        unsigned int usingCustomTitleView : 1;
        unsigned int showsRightButton : 1;
        unsigned int showsLeftButton : 1;
        unsigned int showsBackButton : 1;
        unsigned int usingRegularBackButton : 1;
        unsigned int showsLargeTitle: 1;
        unsigned int showsHeading: 1;
    } _configurationOptions;
    
    CGSize _largeTitleSize;
}

@property (strong, nonatomic) UILabel *titleLabel;
@property (strong, nonatomic) UILabel *largeTitleLabel;
@property (strong, nonatomic) UILabel *subtitleLabel;
@property (strong, nonatomic) UIView *headingContainer;

@property (strong, nonatomic) UIButton *regularBackButton;
@property (strong, nonatomic) UIButton *compactBackButton;
@property (assign, nonatomic) BOOL backActionAvailable;

@property (readonly, nonatomic) BOOL pagingEnabled;
@property (assign, nonatomic) BOOL rotatesBackButton;
@property (assign, nonatomic) CGFloat interSpacing;
@property (assign, nonatomic) CGFloat barButtonSpacing;
@property (assign, nonatomic) CGFloat backButtonSpacing;

@property (strong, nonatomic) UIView *separatorView;
@property (strong, nonatomic) UIView *largeHeaderContainer;
@property (strong, nonatomic) UIView *largeHeaderSeparatorView;

@property (assign, nonatomic, readonly) CGFloat regularHeight;
@property (assign, nonatomic, readonly) CGFloat largeHeaderHeight;

@end

@interface _MMSnapHeaderContainerView : UIView

@end

@implementation MMSnapHeaderView

#define UIKitLocalizedString(key) [[NSBundle bundleWithIdentifier:@"com.apple.UIKit"] localizedStringForKey:key value:@"" table:nil]

#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v) \
([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.clipsToBounds = NO;
        
        // Metrics.
        _regularHeight = 44.0f;
        _largeHeaderHeight = 52.0f;
        _backButtonSpacing = 8.0f;
        _barButtonSpacing = 8.0f;
        _interSpacing = 5.0;
        
        // Defaults.
        _separatorColor = [UIColor colorWithWhite:0.0f alpha:0.2f];
        _largeTitleSize = CGSizeZero;
        
        // Configuration.
        _configurationOptions.showsHeading = YES;
        
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
        
        // Heading container.
        UIView *headingContainer = [[_MMSnapHeaderContainerView alloc] initWithFrame:CGRectZero];
        
        _headingContainer = headingContainer;
        
        [self addSubview:headingContainer];
        
        // Title label.
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        
        _titleLabel = titleLabel;
        
        [headingContainer addSubview:titleLabel];
        
        // Subtitle label.
        UILabel *subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        
        _subtitleLabel = subtitleLabel;
        
        [headingContainer addSubview:subtitleLabel];
        
        // Large title label.
        if ([self.class _UINavigationBarUsesLargeTitles]) {
            UIView *largeHeaderContainer = [[UIView alloc] initWithFrame:CGRectZero];
            largeHeaderContainer.clipsToBounds = YES;
            
            _largeHeaderContainer = largeHeaderContainer;
            
            [self addSubview:largeHeaderContainer];
            
            UILabel *largeTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
            
            _largeTitleLabel = largeTitleLabel;
            
            [largeHeaderContainer addSubview:largeTitleLabel];
            
            UIView *largeHeaderSeparatorView = [[UIView alloc] initWithFrame:CGRectZero];
            largeHeaderSeparatorView.backgroundColor = [_separatorColor colorWithAlphaComponent:0.1f];
            
            _largeHeaderSeparatorView = largeHeaderSeparatorView;
            
            [largeHeaderContainer addSubview:largeHeaderSeparatorView];
        }
        
        // Buttons.
        UIButton *regularBackButton = [UIButton buttonWithType:UIButtonTypeSystem];
        UIButton *compactBackButton = [UIButton buttonWithType:UIButtonTypeSystem];
        
        UIImage *backButtonImage = [[UIImage imageNamed:@"MMSnapBackIndicatorDefault.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
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
    static const CGFloat largeHeadingPointSize = 32.0f;
    
    _configurationOptions.usingMultilineHeading = (self.subtitle.length > 0 && self.title.length > 0);
    
    if (_configurationOptions.usingMultilineHeading) {
        _titleLabel.font = self.titleTextAttributes[NSFontAttributeName] ?: [UIFont boldSystemFontOfSize:subheadingPointSize];
        _subtitleLabel.font = self.subtitleTextAttributes[NSFontAttributeName] ?: [UIFont systemFontOfSize:subheadingPointSize];
    } else {
        _titleLabel.font = self.titleTextAttributes[NSFontAttributeName] ?: [UIFont boldSystemFontOfSize:headingPointSize];
    }
    
    _regularBackButton.titleLabel.font = [UIFont systemFontOfSize:headingPointSize];
    _largeTitleLabel.font = [UIFont systemFontOfSize:largeHeadingPointSize weight:UIFontWeightBold];
}

#pragma mark - Actions.

- (void)_backButtonTouchUpInside:(id)sender
{
    MMSnapHeaderAction backButtonAction = self.backButtonAction;
    
    MMSnapController *snapController = self.snapController;
    UIViewController *viewController = self.viewController;
    
    BOOL isFirstVisibleViewController = (snapController.visibleViewControllers.firstObject == viewController);
    if (isFirstVisibleViewController) {
        UIViewController *previousViewController = self.previousViewController;
        if (backButtonAction == MMSnapHeaderActionPop) {
            [snapController popToViewController:previousViewController animated:YES];
        } else if (backButtonAction == MMSnapHeaderActionScroll) {
            [snapController scrollToViewController:previousViewController animated:YES];
        }
    } else {
        [snapController scrollToViewController:viewController animated:YES];
    }
}

#pragma mark - Layout.

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    const CGRect bounds = (CGRect){ .size = self.bounds.size };
    
    const CGFloat backEdgeSpacing = _backButtonSpacing;
    const CGFloat interSpacing = _interSpacing;
    
    CGFloat largeTitleSpacing = _barButtonSpacing;
    CGFloat edgeSpacing = _barButtonSpacing;
    
    if ([self.class _UINavigationBarDoubleEdgesRequired]) {
        if (CGRectGetWidth(bounds) > [self.class _UINavigationBarDoubleEdgesThreshold]) {
            edgeSpacing = [self.class _UINavigationBarDoubleEdgesSpacing];
        }
    }
    
    // Rects to calculate.
    UIView *actualLeftButton = nil;
    
    // First, what we should display here?
    BOOL pagingEnabled = self.pagingEnabled;
    BOOL isLastViewController = self.snapController.viewControllers.lastObject == self.viewController;
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
    
    const CGRect contentRect = ({
        CGRect rect = UIEdgeInsetsInsetRect(bounds, contentInset);
        rect.size.height = self.regularHeight;
        rect;
    });
    
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
        .origin.y = ceilf((CGRectGetHeight(contentRect) - leftButtonSize.height) / 2.0f),
        .size = leftButtonSize
    };
    
    CGSize rightButtonSize = [_rightButton sizeThatFits:fit];
    CGRect rightButtonRect = (CGRect){
        .origin.x = CGRectGetMaxX(contentRect) - rightButtonSize.width,
        .origin.y = ceilf((CGRectGetHeight(contentRect) - rightButtonSize.height) / 2.0f),
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
            .origin.y = ceilf((CGRectGetMidY(contentRect) - (titleAlignmentHeight / 2.0f))),
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
            .origin.y = ceilf(CGRectGetMidY(contentRect) - (titleAlignmentHeight / 2.0f)),
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
    
    // Large heading.
    if ([self.class _UINavigationBarUsesLargeTitles]) {
        CGRect largeContentRect = UIEdgeInsetsInsetRect(bounds, (UIEdgeInsets){ .left = largeTitleSpacing, .right = largeTitleSpacing });
        
        const CGFloat regularHeight = self.regularHeight;
        const CGFloat largeHeaderHeight = self.largeHeaderHeight;
        
        CGSize largeHeaderSize = _largeTitleSize;
        
        const BOOL enabled = (largeHeaderSize.width <= CGRectGetWidth(largeContentRect));
        largeHeaderSize.width = MIN(largeHeaderSize.width, CGRectGetWidth(largeContentRect));
        
        CGRect largeHeaderRect = (CGRect){
            .origin.x = CGRectGetMinX(largeContentRect),
            .origin.y = (CGRectGetHeight(largeContentRect) - (regularHeight + largeHeaderHeight)) + roundf((largeHeaderHeight - largeHeaderSize.height) / 2.0f) - 1.0f,
            .size = largeHeaderSize
        };
        
        CGRect largeHeaderContainerRect = UIEdgeInsetsInsetRect(largeContentRect, (UIEdgeInsets){
            .top = regularHeight
        });
        
        CGRect largeHeaderSeparatorRect = (CGRect){
            .origin.x = CGRectGetMinX(largeHeaderRect),
            .size.width = CGRectGetWidth(largeHeaderRect),
            .size.height = 1.0f
        };
        
        const BOOL showsLargeHeaderSeparator = CGRectIntersectsRect(largeHeaderSeparatorRect, CGRectInset(largeHeaderRect, 0.0f, 10.0f));
        
        _largeHeaderSeparatorView.alpha = showsLargeHeaderSeparator;
        _largeHeaderSeparatorView.frame = largeHeaderSeparatorRect;
        _largeHeaderContainer.frame = largeHeaderContainerRect;
        
        const BOOL showsLargeTitle = (enabled) && (CGRectGetHeight(bounds) > regularHeight);
        const BOOL showsHeading = (enabled) && (CGRectGetHeight(bounds) > regularHeight + (interSpacing * 2.0f));
        
        if (showsHeading != _configurationOptions.showsHeading) {
            const BOOL animated = (self.window != nil) && self.contentIsBeingScrolled;
            
            dispatch_block_t animations = ^{
                self.headingContainer.alpha = showsHeading ? 0.0f : 1.0f;
            };
            
            if (animated) {
                [UIView animateWithDuration:0.15f delay:0.0f options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState animations:animations completion:NULL];
            } else {
                animations();
            }
        }
        
        _largeTitleLabel.frame = largeHeaderRect;
        _largeTitleLabel.hidden = !showsLargeTitle;
        
        _configurationOptions.showsLargeTitle = showsLargeTitle;
        _configurationOptions.showsHeading = showsHeading;
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
    _headingContainer.frame = bounds;
    
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
    size.height = self.regularHeight;
    
    if ([self displaysLargeTitleWithSize:size]) {
        size.height += self.largeHeaderHeight;
    }
    
    return size;
}

#pragma mark - Updates.

- (void)snapControllerWillDisplayViewController
{
    UIViewController *previousViewController = self.previousViewController;
    if (previousViewController) {
        MMSnapHeaderView *headerView = (MMSnapHeaderView *)[self.snapController headerViewForViewController:previousViewController];
        NSString *backTitle = headerView.backButtonTitle ?: headerView.title ?: previousViewController.title;
        
        [self.regularBackButton setTitle:backTitle forState:UIControlStateNormal];
        
        [self setBackActionAvailable:(previousViewController != nil)];
        [self setNeedsLayout];
    }
}

- (void)didMoveToSnapController
{
    if (!self.pagingEnabled) {
        BOOL firstVisibleViewController = (self.snapController.visibleViewControllers.firstObject == self.viewController);
        
        [self setRotatesBackButton:!firstVisibleViewController];
    } else {
        [self setRotatesBackButton:NO];
    }
}

- (void)snapControllerWillSnapToViewController:(UIViewController *)viewController
{
    if (!self.pagingEnabled) {
        [self setRotatesBackButton:(viewController != self.viewController)];
    } else {
        [self setRotatesBackButton:NO];
    }
}

- (void)snapControllerViewControllersDidChange
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
    return self.snapController.scrollMode == MMSnapScrollModePaging;
}

#pragma mark - Hit testing.

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *hitTest = [super hitTest:point withEvent:event];
    if (!hitTest || hitTest == self || hitTest == self.backgroundView || hitTest == self.titleView) {
        for (UIView *subview in self.subviews) {
            UIButton *button = (UIButton *)subview;
            
            if ([button isKindOfClass:[UIButton class]]) {
                CGRect rect = CGRectZero;
                rect.origin.x = CGRectGetMinX(button.frame);
                rect.size.width = CGRectGetWidth(button.frame);
                rect.size.height = self.regularHeight;
                
                CGRect targetPointInsideHeaderRect = CGRectInset(rect, -15.0f, -15.0f);
                
                if (CGRectContainsPoint(targetPointInsideHeaderRect, point)) {
                    return button;
                }
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
        _largeTitleLabel.text = title;
        _largeTitleSize = [_largeTitleLabel sizeThatFits:(CGSize){ CGFLOAT_MAX, CGFLOAT_MAX }];
        
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
            [_headingContainer addSubview:titleView];
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
        _largeHeaderSeparatorView.backgroundColor = [separatorColor colorWithAlphaComponent:0.1f];
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

- (void)setDisplaysLargeTitle:(BOOL)displaysLargeTitle
{
    if (![self.class _UINavigationBarUsesLargeTitles]) {
        return;
    }
    
    if (displaysLargeTitle != _displaysLargeTitle) {
        _displaysLargeTitle = displaysLargeTitle;
        
        [self sizeToFit];
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

#pragma mark - Large titles.

- (BOOL)displaysLargeTitleWithSize:(CGSize)size
{
    if (self.displaysLargeTitle) {
        const CGFloat spacing = _barButtonSpacing;
        const CGFloat allowedWidth = size.width - (spacing * 2.0f);
        
        return (_largeTitleSize.width <= allowedWidth);
    }
    return NO;
}

- (CGSize)sizeThatFits:(CGSize)size withVerticalScrollOffset:(CGFloat)offset
{
    const CGSize preferredSize = [self sizeThatFits:size];
    
    if ([self displaysLargeTitleWithSize:size]) {
        size.height = MAX(preferredSize.height + (offset * -1.0f), self.regularHeight);
    } else {
        size.height = preferredSize.height;
    }
    
    return size;
}

- (CGFloat)preferredVerticalScrollOffsetForTargetOffset:(CGFloat)offset withVerticalVelocity:(CGFloat)velocity
{
    if ([self displaysLargeTitleWithSize:self.bounds.size]) {
        const CGFloat collapsableHeight = self.largeHeaderHeight;
        
        if (offset < collapsableHeight) {
            static const CGFloat flickVelocity = 0.3f;
            const BOOL flicked = fabs(velocity) > flickVelocity;
            const BOOL isHalfway = (offset > collapsableHeight / 2.0f);
            
            if (isHalfway && flicked) {
                offset = (velocity > 0.0 ? collapsableHeight : 0.0f);
            } else {
                offset = (isHalfway ? collapsableHeight : 0.0f);
            }
        }
    }
    
    return offset;
}

#pragma mark - UIKit compatibility.

+ (BOOL)_UINavigationBarDoubleEdgesRequired
{
    static BOOL supported;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        supported = SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"10.0");
    });
    return supported;
}

+ (CGFloat)_UINavigationBarDoubleEdgesThreshold
{
    static CGFloat threshold;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"11.0")) {
            threshold = 0.0f;
        } else {
            threshold = 320.0f;
        }
    });
    return threshold;
}

+ (CGFloat)_UINavigationBarDoubleEdgesSpacing
{
    static CGFloat width;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"11.0")) {
            width = 25.0f;
        } else {
            width = 16.0f;
        }
    });
    return width;
}

+ (BOOL)_UINavigationBarUsesLargeTitles
{
    static BOOL use;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        use = (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"11.0"));
    });
    return use;
}

@end

@implementation _MMSnapHeaderContainerView

- (void)setNeedsLayout
{
    [super setNeedsLayout];
    [self.superview setNeedsLayout];
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    const BOOL result = [super pointInside:point withEvent:event];
    if (result) {
        for (UIView *view in self.subviews) {
            if (CGRectContainsPoint(view.frame, point)) {
                return YES;
            }
        }
    }
    return NO;
}

@end
