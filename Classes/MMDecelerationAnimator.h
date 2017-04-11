//
//  MMDecelerationAnimator.h
//  MMSnapController
//
//  Created by Matías Martínez on 2/2/15.
//  Copyright (c) 2015 Matías Martínez. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MMDecelerationAnimator : NSObject

/**
 *  Returns an animator instance configured with the specified scroll view.
 *
 *  @param scrollView The scroll view that will be the target of the animation.
 *
 *  @return An animator instance.
 */
- (instancetype)initWithTargetScrollView:(UIScrollView *)scrollView;

/**
 *  The scroll view that will be the target of the animation.
 */
@property (weak, nonatomic, readonly) UIScrollView *scrollView;

/**
 *  The scroll view delegate used to notify animation state. By default, @c -scrollView's own delegate.
 */
@property (weak, nonatomic) id <UIScrollViewDelegate> delegate;

/**
 *  Returns YES if currently animating.
 */
@property (readonly, nonatomic) BOOL isAnimating;

/**
 *  Starts the animation an finished at the specified content offset.
 *
 *  @param contentOffset The content offset at which stop animating.
 */
- (void)animateScrollToContentOffset:(CGPoint)contentOffset;

/**
 *  Stops the animation at its current state.
 *
 *  @note Must be called when user starts dragging and animation should stop.
 */
- (void)cancelAnimation;

/**
 *  A deceleration rate for the animation.
 */
@property (assign, nonatomic) CGFloat decelerationRate;

@end
