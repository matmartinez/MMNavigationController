//
//  MMNavigationFooterView.m
//  MMNavigationController
//
//  Created by Matías Martínez on 1/27/15.
//  Copyright (c) 2015 Matías Martínez. All rights reserved.
//

#import "MMNavigationFooterView.h"

@interface MMNavigationFooterView ()

@property (strong, nonatomic) UIView *separatorView;

@end

const CGFloat MMNavigationFooterFlexibleWidth = CGFLOAT_MAX;

@implementation MMNavigationFooterView

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

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect bounds = (CGRect){
        .size = self.bounds.size
    };
    
    static const CGFloat pad = 8.0f;
    static const CGFloat spacing = 8.0f;
    
    const CGFloat maximumContentWidth = CGRectGetWidth(bounds) - (pad * 2.0f);
    
    CGFloat contentWidth = 0.0f;
    NSUInteger flexibleItemsCount = 0;
    
    NSArray *items = self.items;
    NSMutableArray *itemsToLayout = [NSMutableArray arrayWithCapacity:items.count];
    NSMutableArray *itemSizes = [NSMutableArray arrayWithCapacity:items.count];
    
    for (id item in items) {
        // Find out size for this item.
        CGSize itemSize = CGSizeZero;
        
        if ([item isKindOfClass:[UIView class]]) {
            itemSize = [(UIView *)item sizeThatFits:bounds.size];
        } else if ([item isKindOfClass:[MMNavigationFooterSpace class]]) {
            CGFloat width = [(MMNavigationFooterSpace *)item width];
            
            if (width == MMNavigationFooterFlexibleWidth) {
                flexibleItemsCount++;
            } else {
                itemSize = CGSizeMake(width, 0);
            }
        }
        
        CGFloat proposedContentWidth = contentWidth + itemSize.width + ((itemsToLayout.count) * spacing);
        if (proposedContentWidth > maximumContentWidth) {
            break;
        }
        
        [itemsToLayout addObject:item];
        [itemSizes addObject:[NSValue valueWithCGSize:itemSize]];
        
        contentWidth += itemSize.width;
    }
    
    CGFloat flexibleUnitWidth = 0.0f;
    if (flexibleItemsCount > 0) {
        CGFloat separatorWidth = (itemsToLayout.count - 1) * spacing;
        
        flexibleUnitWidth = floorf((maximumContentWidth - contentWidth - separatorWidth) / flexibleItemsCount);
    }
    
    // Layout.
    CGFloat contentOffset = pad;
    
    NSUInteger idx = 0;
    for (id item in itemsToLayout) {
        CGSize itemSize = [itemSizes[idx] CGSizeValue];
        
        if ([item isKindOfClass:[MMNavigationFooterSpace class]]) {
            CGFloat width = [(MMNavigationFooterSpace *)item width];
            
            if (width == MMNavigationFooterFlexibleWidth) {
                itemSize = CGSizeMake(flexibleUnitWidth, 0);
            }
        }
        
        CGRect rect = (CGRect){
            .origin.x = contentOffset,
            .origin.y = roundf((CGRectGetHeight(bounds) - itemSize.height) / 2.0f),
            .size = itemSize
        };
        
        if ([item isKindOfClass:[UIView class]]) {
            [(UIView *)item setFrame:rect];
        }
        
        contentOffset = CGRectGetMaxX(rect) + spacing;
        
        idx++;
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
    if (![items isEqualToArray:_items]) {
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

#pragma mark - Interaction.

- (BOOL)_pointInside:(CGPoint)point withButton:(UIButton *)button
{
    CGRect rect = CGRectZero;
    rect.origin.x = CGRectGetMinX(button.frame);
    rect.size.width = CGRectGetWidth(button.frame);
    rect.size.height = CGRectGetHeight(self.bounds);
    
    CGRect targetPointInsideHeaderRect = CGRectInset(rect, -16.0f, -15.0f);
    
    return CGRectContainsPoint(targetPointInsideHeaderRect, point);
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    BOOL pointInside = [super pointInside:point withEvent:event];
    if (!pointInside) {
        for (UIView *subview in self.subviews) {
            UIButton *button = (UIButton *)subview;
            if ([button isEnabled] && [self _pointInside:point withButton:button]) {
                return YES;
            }
        }
    }
    return pointInside;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *hitTest = [super hitTest:point withEvent:event];
    if (!hitTest || hitTest == self || hitTest == self.backgroundView) {
        for (UIView *subview in self.subviews) {
            UIButton *button = (UIButton *)subview;
            if ([button isEnabled] && [self _pointInside:point withButton:button]) {
                return button;
            }
        }
    }
    return hitTest;
}

@end

@implementation MMNavigationFooterSpace

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.width = 44.0f;
    }
    return self;
}

@end
