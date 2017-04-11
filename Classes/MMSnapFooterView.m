//
//  MMSnapFooterView.m
//  MMSnapController
//
//  Created by Matías Martínez on 1/27/15.
//  Copyright (c) 2015 Matías Martínez. All rights reserved.
//

#import "MMSnapFooterView.h"

@interface MMSnapFooterView ()

@property (strong, nonatomic) UIView *separatorView;

@end

const CGFloat MMSnapFooterFlexibleWidth = CGFLOAT_MAX;

@implementation MMSnapFooterView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.clipsToBounds = NO;
        
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
    }
    return self;
}

#pragma mark - Layout.

static const NSString *MMSnapFooterInfoObjectKey = @"Object";
static const NSString *MMSnapFooterInfoSizeKey = @"Size";

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect bounds = (CGRect){
        .size = self.bounds.size
    };
    
    static const CGFloat pad = 8.0f;
    static const CGFloat spacing = 8.0f;
    
    const CGFloat maximumContentWidth = CGRectGetWidth(bounds) - (pad * 2.0f);
    const CGSize maximumItemSize = CGSizeMake(maximumContentWidth, CGRectGetHeight(bounds));
    
    CGFloat contentWidth = 0.0f;
    NSUInteger flexibleItemsCount = 0;
    
    NSArray *items = self.items;
    NSMutableArray *itemsToLayout = [NSMutableArray arrayWithCapacity:items.count];
    
    for (id item in items) {
        // Find out size for this item.
        CGSize itemSize = CGSizeZero;
        
        if ([item isKindOfClass:[UIView class]]) {
            itemSize = [(UIView *)item sizeThatFits:maximumItemSize];
            itemSize.width = MIN(itemSize.width, maximumItemSize.width);
            
        } else if ([item isKindOfClass:[MMSnapFooterSpace class]]) {
            CGFloat width = [(MMSnapFooterSpace *)item width];
            
            if (width == MMSnapFooterFlexibleWidth) {
                flexibleItemsCount++;
            } else {
                itemSize = CGSizeMake(width, 0);
            }
        }
        
        NSDictionary *info = @{ MMSnapFooterInfoSizeKey : [NSValue valueWithCGSize:itemSize],
                                MMSnapFooterInfoObjectKey : item };
        
        [itemsToLayout addObject:info];
    }
    
    const NSInteger actualItemsCount = itemsToLayout.count - flexibleItemsCount;
    const NSInteger interSeparationCount = (itemsToLayout.count - 1);
    
    CGFloat interSeparationWidth = actualItemsCount == 1 ? 0.0f : interSeparationCount * spacing;
    
    NSUInteger idx = 0;
    for (NSDictionary *info in itemsToLayout.copy) {
        CGSize itemSize = [info[MMSnapFooterInfoSizeKey] CGSizeValue];
        
        CGFloat proposedContentWidth = contentWidth + itemSize.width + interSeparationWidth;
        if (proposedContentWidth > maximumContentWidth) {
            [itemsToLayout removeObjectsInRange:NSMakeRange(idx, itemsToLayout.count - idx)];
            break;
        }
        
        contentWidth += itemSize.width;
        idx++;
    }
    
    CGFloat flexibleUnitWidth = 0.0f;
    if (flexibleItemsCount > 0) {
        flexibleUnitWidth = ((maximumContentWidth - contentWidth - interSeparationWidth) / flexibleItemsCount);
    }
    
    // Layout.
    CGFloat contentOffset = pad;
    
    for (NSDictionary *info in itemsToLayout) {
        id item = info[MMSnapFooterInfoObjectKey];
        CGSize itemSize = [info[MMSnapFooterInfoSizeKey] CGSizeValue];
        
        if ([item isKindOfClass:[MMSnapFooterSpace class]]) {
            CGFloat width = [(MMSnapFooterSpace *)item width];
            
            if (width == MMSnapFooterFlexibleWidth) {
                itemSize = CGSizeMake(flexibleUnitWidth, 0);
            }
        }
        
        CGRect rect = (CGRect){
            .origin.x = roundf(contentOffset),
            .origin.y = roundf((CGRectGetHeight(bounds) - itemSize.height) / 2.0f),
            .size = itemSize
        };
        
        if ([item isKindOfClass:[UIView class]]) {
            [(UIView *)item setFrame:rect];
        }
        
        contentOffset = CGRectGetMaxX(rect);
        
        if (interSeparationWidth > 0.0f) {
            contentOffset += spacing;
        }
    }
    
    // Hide items that won't fit.
    for (id item in items) {
        if ([item isKindOfClass:[UIView class]]) {
            NSUInteger idx = [itemsToLayout indexOfObjectPassingTest:^BOOL(NSDictionary *info, NSUInteger idx, BOOL *stop) {
                return (info[MMSnapFooterInfoObjectKey] == item);
            }];
            
            [item setHidden:(idx == NSNotFound)];
        }
    }
    
    const CGFloat separatorHeight = 1.0f / [UIScreen mainScreen].scale;
    
    CGRect separatorRect = (CGRect){
        .origin.y = -separatorHeight,
        .size.width = CGRectGetWidth(bounds),
        .size.height = separatorHeight,
    };
    
    CGRect backgroundRect = bounds;
    
    _separatorView.frame = separatorRect;
    _backgroundView.frame = backgroundRect;
}

- (CGSize)sizeThatFits:(CGSize)size
{
    size.height = 44.0f;
    
    return size;
}

#pragma mark - Properties.

- (void)setItems:(NSArray *)items
{
    [self setItems:items animated:NO];
}

- (void)setItems:(NSArray *)items animated:(BOOL)animated
{
    if ([items isEqualToArray:_items]) {
        return;
    }
    
    for (id item in _items) {
        if ([item isKindOfClass:[UIView class]]) {
            [item removeFromSuperview];
        }
    }
    
    _items = items;
    
    for (id item in items) {
        if ([item isKindOfClass:[UIView class]]) {
            [self addSubview:item];
        }
    }
    
    if (animated) {
        [self layoutIfNeeded];
        
        [UIView transitionWithView:self duration:0.25f options:UIViewAnimationOptionAllowAnimatedContent | UIViewAnimationOptionTransitionCrossDissolve animations:^{
            [self.layer setNeedsDisplay];
        } completion:NULL];
    } else {
        [self setNeedsLayout];
    }
}

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

@end

@implementation MMSnapFooterSpace

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.width = 44.0f;
    }
    return self;
}

@end
