//
//  MMDecelerationAnimator.m
//  MMNavigationController
//
//  Created by Matías Martínez on 2/2/15.
//  Copyright (c) 2015 Matías Martínez. All rights reserved.
//

#import "MMDecelerationAnimator.h"

@interface MMDecelerationAnimator ()

@property (weak, nonatomic, readwrite) UIScrollView *scrollView;

@property (strong, nonatomic) CADisplayLink *displayLink;

@property (assign, nonatomic) CGPoint contentOffset;
@property (assign, nonatomic) CGPoint destinationContentOffset;

@end

@implementation MMDecelerationAnimator

- (instancetype)initWithTargetScrollView:(UIScrollView *)scrollView
{
    self = [super init];
    if (self) {
        self.scrollView = scrollView;
        self.decelerationRate = 0.83f;
    }
    return self;
}

- (id<UIScrollViewDelegate>)delegate
{
    return _delegate ?: self.scrollView.delegate;
}

- (void)animateScrollToContentOffset:(CGPoint)contentOffset
{
    self.contentOffset = self.scrollView.contentOffset;
    
    if (CGPointEqualToPoint(contentOffset, self.contentOffset)) {
        return;
    }
    
    [self setDestinationContentOffset:contentOffset];
    
    if (!self.displayLink) {
        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateContentOffset:)];
        self.displayLink.frameInterval = 1;
        [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    } else {
        self.displayLink.paused = NO;
    }
}

- (void)updateContentOffset:(CADisplayLink *)displayLink
{
    const CGFloat decelerationRate = self.decelerationRate;
    const CGPoint destinationOffset = self.destinationContentOffset;
    
    CGPoint o = self.contentOffset;
    CGPoint lastOffset = o;
    o.x = o.x * decelerationRate + destinationOffset.x * (1-decelerationRate);
    o.y = o.y * decelerationRate + destinationOffset.y * (1-decelerationRate);
    
    [self setContentOffset:o];
    
    if ((fabs(o.x - lastOffset.x) < 0.1) && (fabs(o.y - lastOffset.y) < 0.1)) {
        [self stopAnimation];
        [self.scrollView setContentOffset:destinationOffset];
    } else {
        [self.scrollView setContentOffset:o];
    }
}

- (void)stopAnimation
{
    self.displayLink.paused = YES;
    
    id <UIScrollViewDelegate> delegate = self.delegate;
    
    if ([delegate respondsToSelector:@selector(scrollViewDidEndScrollingAnimation:)]) {
        [delegate scrollViewDidEndScrollingAnimation:self.scrollView];
    }
}

- (void)cancelAnimation
{
    self.displayLink.paused = YES;
}

- (BOOL)isAnimating
{
    if (self.displayLink) {
        return !self.displayLink.isPaused;
    }
    return NO;
}

@end
