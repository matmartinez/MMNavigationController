//
//  MMNavigationPagingScrollView.m
//  MMNavigationController
//
//  Created by Matías Martínez on 1/11/15.
//  Copyright (c) 2015 Matías Martínez. All rights reserved.
//

#import "MMSnapScrollView.h"
#import "MMDecelerationAnimator.h"
#import <QuartzCore/QuartzCore.h>

@interface _MMSnapScrollViewDelegateProxy : NSObject

- (instancetype)initWithDelegate:(id <MMSnapScrollViewDelegate>)delegate scrollView:(MMSnapScrollView *)scrollView;

@property (weak, nonatomic) MMSnapScrollView *scrollView;
@property (weak, nonatomic) id <MMSnapScrollViewDelegate> delegate;

@end

@interface _MMSnapScrollViewLayoutAttributes : NSObject

@property (assign, nonatomic) CGRect frame;
@property (assign, nonatomic) CGPoint center;
@property (assign, nonatomic) CGSize size;

@end

@interface _MMStockSnapViewSeparatorView : UIView <MMSnapViewSeparatorView>

@property (strong, nonatomic) CALayer *thickLayer;
@property (strong, nonatomic) CAGradientLayer *shadowGradientLayer;

@end

static const CGFloat _MMStockSnapViewSeparatorWidth = 10.0f;

@interface MMSnapScrollView () <UIScrollViewDelegate> {
    struct {
        unsigned int delegateWillDisplayView : 1;
        unsigned int delegateDidEndDisplayingView : 1;
        unsigned int delegateWillSnapToPage : 1;
        unsigned int delegateDidSnapToPage : 1;
    } _delegateFlags;
}

@property (strong, nonatomic) _MMSnapScrollViewDelegateProxy *delegateProxy;

@property (assign, nonatomic, readwrite) NSInteger numberOfPages;
@property (assign, nonatomic, getter=isContentSizeInvalidated) BOOL contentSizeInvalidated;
@property (assign, nonatomic) NSInteger snappedPage;
@property (assign, nonatomic) NSInteger deferScrollToPage;
@property (assign, nonatomic) BOOL deferScrollToPageAnimated;

@property (strong, nonatomic) NSMutableDictionary *visibleViewsDictionary;
@property (strong, nonatomic) NSMutableArray *layoutAttributes;

@property (strong, nonatomic) NSMutableDictionary *visibleSeparatorsDictionary;
@property (strong, nonatomic) NSMutableSet *separatorReuseQueue;
@property (assign, nonatomic) CGFloat separatorClassDefinedWidth;

@property (strong, nonatomic) MMDecelerationAnimator *scrollToAnimator;
@property (strong, nonatomic) NSMutableSet *viewsToRemoveAfterScrollAnimation;

@end

@implementation NSIndexSet (Array)

- (NSArray *)array
{
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:self.count];
    [self enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        [array addObject:[NSNumber numberWithInteger:idx]];
    }];
    return array;
}

@end

@implementation MMSnapScrollView

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self _commonInit];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self _commonInit];
    }
    return self;
}

- (void)_commonInit
{
    _visibleViewsDictionary = [NSMutableDictionary dictionary];
    _visibleSeparatorsDictionary = [NSMutableDictionary dictionary];
    _viewsToRemoveAfterScrollAnimation = [NSMutableSet set];
    _separatorReuseQueue = [NSMutableSet set];
    _layoutAttributes = [NSMutableArray array];
    _contentSizeInvalidated = YES;
    _snappedPage = NSNotFound;
    _deferScrollToPage = NSNotFound;
    _separatorClassDefinedWidth = _MMStockSnapViewSeparatorWidth;
    
    // Custom animator for content offset updates.
    _scrollToAnimator = [[MMDecelerationAnimator alloc] initWithTargetScrollView:self];
    _scrollToAnimator.delegate = self;
    
    // Adds a snap to page gesture recognizer.
    UITapGestureRecognizer *tapToSnapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_tapToSnapGestureRecognized:)];
    tapToSnapGestureRecognizer.cancelsTouchesInView = NO;
    
    [self addGestureRecognizer:tapToSnapGestureRecognizer];
    
    [self setDecelerationRate:UIScrollViewDecelerationRateFast];
    [self setShowsHorizontalScrollIndicator:NO];
    [self setShowsVerticalScrollIndicator:NO];
    [self setAlwaysBounceHorizontal:YES];
    [self setScrollsToTop:NO];
    
    // Don't delay touches.
    [self setDelaysContentTouches:NO];
    
    // Delegate ownership.
    [super setDelegate:self];
}

- (NSIndexSet *)pagesForViewsInRect:(CGRect)rect
{
    NSArray *layoutAttributes = self.layoutAttributes;
    NSArray *array = [self _layoutAttributesForElementsInRect:rect];
    
    NSIndexSet *indexSet = [layoutAttributes indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        if ([array containsObject:obj]) {
            return YES;
        }
        return NO;
    }];
    
    return indexSet;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    // Validate layout if needed.
    if (self.isContentSizeInvalidated) {
        [self _validateLayout];
        [self _validateContentOffset];
    }
    
    // Perform the layout.
    [self _performLayout];
    
    // Notify snap if layout affected snap point.
    [self _notifySnapIfNeeded];
}

- (void)_performLayout
{
    NSMutableDictionary *visibleViewsDictionary = self.visibleViewsDictionary;
    NSMutableDictionary *visibleSeparatorsDictionary = self.visibleSeparatorsDictionary;
    
    id <MMSnapScrollViewDataSource> dataSource = self.dataSource;
    id <MMSnapScrollViewDelegate> delegate = self.delegate;
    
    BOOL notifyWillDisplayView = _delegateFlags.delegateWillDisplayView;
    BOOL notifyDidEndDisplayingView = _delegateFlags.delegateDidEndDisplayingView;
    
    CGRect visibleRect = self.bounds;
    visibleRect.origin = self.contentOffset;
    
    // Calculate visible indexes.
    NSIndexSet *visiblePages = [self pagesForViewsInRect:visibleRect];
    
    // Remove views that should be hidden.
    NSMutableIndexSet *removedIndexes = [NSMutableIndexSet indexSet];
    
    [visibleViewsDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSInteger page = [key integerValue];
        UIView *view = obj;
        UIView <MMSnapViewSeparatorView> *separatorView = visibleSeparatorsDictionary[key];
        
        if (![visiblePages containsIndex:page]) {
            [view removeFromSuperview];
            
            if (notifyDidEndDisplayingView) {
                [delegate scrollView:self didEndDisplayingView:view atPage:page];
            }
            
            [self _enqueueSeparatorView:separatorView];
            
            [removedIndexes addIndex:page];
        }
    }];
    
    NSArray *removeIndexesArray = removedIndexes.array;
    [visibleViewsDictionary removeObjectsForKeys:removeIndexesArray];
    [visibleSeparatorsDictionary removeObjectsForKeys:removeIndexesArray];
    
    // Insert views that should be visible.
    [visiblePages enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        NSInteger page = idx;
        id key = @(page);
        
        UIView *view = [visibleViewsDictionary objectForKey:key];
        UIView <MMSnapViewSeparatorView> *separatorView = [visibleSeparatorsDictionary objectForKey:key];
        
        BOOL showsSeparator = ((page + 1) < _numberOfPages);
        
        CGFloat disappearPercent = 0.0f;
        CGRect rect = [self _rectForViewAtPage:page disappearPercent:&disappearPercent];
        
        CGRect separatorRect = CGRectZero;
        if (showsSeparator) {
            CGRect referenceRect = [self _rectForViewAtPage:(page + 1) disappearPercent:NULL];
            separatorRect = [self _separatorRectWithReferenceRect:referenceRect];
        }
        
        BOOL isDisplayingViewAtIndex = (view != nil);
        if (!isDisplayingViewAtIndex) {
            // Don't animate insertion.
            [CATransaction begin];
            //[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
            
            // Insert view.
            view = [dataSource scrollView:self viewAtPage:page];
            
            NSAssert(view != nil, @"view cannot be nil.");
            
            if (notifyWillDisplayView) {
                [delegate scrollView:self willDisplayView:view atPage:page];
            }
            
            [visibleViewsDictionary setObject:view forKey:key];
            
            UIView *nextView = [visibleViewsDictionary objectForKey:@(page + 1)];
            if (nextView) {
                [self insertSubview:view belowSubview:nextView];
            } else {
                [self addSubview:view];
            }
            
            // Insert separator view.
            separatorView = [self _dequeueSeparatorForPage:page];
            
            [visibleSeparatorsDictionary setObject:separatorView forKey:key];
            
            [self addSubview:separatorView];
        }
        
        // Update view frame.
        [view setFrame:rect];
        
        // Update separator frame.
        [separatorView setFrame:separatorRect];
        [separatorView setPercentDisappeared:disappearPercent];
        
        // Commit view insertion transaction.
        if (!isDisplayingViewAtIndex) {
            [CATransaction commit];
        }
    }];
}

- (CGRect)_rectForViewAtPage:(NSInteger)page disappearPercent:(CGFloat *)disappearPercent
{
    _MMSnapScrollViewLayoutAttributes *layoutAttributes = [self _layoutAttributesForPage:page];
    CGRect rect = [layoutAttributes frame];
    
    CGRect bounds = self.bounds;
    CGPoint contentOffset = self.contentOffset;
    
    // Add parallax offset if:
    // a. This is not the last page.
    // b. Page is fading away from the left edge.
    if (page != (_numberOfPages - 1) && CGRectGetMinX(rect) < contentOffset.x) {
        CGFloat distance = CGRectGetMinX(bounds) - CGRectGetMinX(rect);
        CGFloat maximum = CGRectGetWidth(rect);
        
        CGFloat percent = MAX(MIN(distance / maximum, 1.0f), 0.0f);
        CGFloat offset = percent * (maximum / 2);
        
        rect.origin.x = -offset + contentOffset.x;
        
        if (disappearPercent) {
            *disappearPercent = percent;
        }
    }
    
    return rect;
}

- (void)_validateLayout
{
    if (!self.isContentSizeInvalidated) {
        return;
    }
    
    id dataSource = self.dataSource;
    
    [_layoutAttributes removeAllObjects];
    
    CGFloat origin = 0;
    for (NSInteger idx = 0; idx < _numberOfPages; idx++) {
        CGRect rect = self.bounds;
        rect.origin.y = 0;
        rect.origin.x = origin;
        rect.size.width = [dataSource scrollView:self widthForViewAtPage:idx];
        
        _MMSnapScrollViewLayoutAttributes *layoutAttributes = [[_MMSnapScrollViewLayoutAttributes alloc] init];
        layoutAttributes.frame = rect;
        
        [_layoutAttributes addObject:layoutAttributes];
        
        origin = CGRectGetMaxX(rect);
    }
    
    // Update with new content size.
    CGSize contentSize = CGSizeMake(origin, CGRectGetHeight(self.bounds));
    [self _setContentSize:contentSize];
    
    // Note validation.
    self.contentSizeInvalidated = NO;
}

- (void)_validateContentOffset
{
    if (_deferScrollToPage != NSNotFound) {
        [self scrollToPage:_deferScrollToPage animated:_deferScrollToPageAnimated];
        _deferScrollToPage = NSNotFound;
    } else {
        // Update scrolling offset accordingly.
        [self scrollToPage:self.pagesForVisibleViews.firstIndex animated:NO];
    }
}

- (void)_notifySnapIfNeeded
{
    if (!self.isTracking && !self.isDecelerating) {
        if (_numberOfPages > 0 && _snappedPage != self.pagesForVisibleViews.firstIndex) {
            CGPoint contentOffset = self.contentOffset;
            
            [self _notifySnapToTargetContentOffset:contentOffset completed:NO];
            
            if (self.layer.animationKeys) {
                [CATransaction setCompletionBlock:^{
                    [self _notifySnapToTargetContentOffset:contentOffset completed:YES];
                }];
            } else {
                [self _notifySnapToTargetContentOffset:contentOffset completed:YES];
            }
        }
    }
}

- (void)reloadData
{
    id dataSource = self.dataSource;
    
    // Update number of pages.
    _numberOfPages = [dataSource numberOfPagesInScrollView:self];
    
    // Clean up visible views.
    [_visibleViewsDictionary.allValues makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [_visibleViewsDictionary removeAllObjects];
    
    // Clean snap page.
    _snappedPage = NSNotFound;
    _deferScrollToPage = NSNotFound;
    
    // Invalidate layout.
    [self invalidateLayout];
}

- (void)invalidateLayout
{
    if (self.isContentSizeInvalidated) {
        return;
    }
    
    [self setContentSizeInvalidated:YES];
    [self setNeedsLayout];
}

#pragma mark - Separator views.

- (Class)_inheritedSeparatorClass
{
    return _separatorViewClass ?: [_MMStockSnapViewSeparatorView class];
}

- (CGRect)_separatorRectWithReferenceRect:(CGRect)rect
{
    CGFloat separatorWidth = _separatorClassDefinedWidth;
    CGRect separatorRect = (CGRect){
        .origin.x = CGRectGetMinX(rect) - separatorWidth,
        .size.width = separatorWidth,
        .size.height = CGRectGetHeight(rect),
    };
    
    return separatorRect;
}

- (UIView <MMSnapViewSeparatorView> *)_dequeueSeparatorForPage:(NSInteger)page
{
    UIView <MMSnapViewSeparatorView> *separatorView = [_separatorReuseQueue anyObject];
    if (!separatorView) {
        Class separatorClass = [self _inheritedSeparatorClass];
        separatorView = [[separatorClass alloc] initWithFrame:CGRectZero];
    }
    
    [separatorView setUserInteractionEnabled:NO];
    [separatorView setShowsAsColumnSeparator:!self.pagingEnabled];
    
    [_separatorReuseQueue removeObject:separatorView];
    
    return separatorView;
}

- (void)_enqueueSeparatorView:(UIView <MMSnapViewSeparatorView> *)separatorView
{
    if (separatorView) {
        [_separatorReuseQueue addObject:separatorView];
        [separatorView removeFromSuperview];
    }
}

#pragma mark - Scroll to / insertion / deletion.

- (_MMSnapScrollViewLayoutAttributes *)_layoutAttributesForPage:(NSInteger)page
{
    if (page < _numberOfPages) {
        BOOL hasAttributes = (page < _layoutAttributes.count);
        if (!hasAttributes) {
            [self _validateLayout];
        }
        return _layoutAttributes[page];
    }
    return nil;
}

- (void)scrollToPage:(NSInteger)page animated:(BOOL)animated
{
    if (page < _numberOfPages) {
        if (!self.window || _layoutAttributes.count < page) {
            _deferScrollToPage = page;
            _deferScrollToPageAnimated = animated;
            return;
        }
        
        _MMSnapScrollViewLayoutAttributes *attributes = [self _layoutAttributesForPage:page];
        CGRect frame = attributes.frame;
        
        CGRect bounds = self.bounds;
        CGSize contentSize = self.contentSize;
        
        CGFloat maximumContentOffsetX = contentSize.width - CGRectGetWidth(bounds);
        CGPoint contentOffset = CGPointMake(MIN(maximumContentOffsetX, frame.origin.x), 0);
        
        if (!CGPointEqualToPoint(contentOffset, self.contentOffset)) {
            if (_delegateFlags.delegateWillSnapToPage) {
                [self _notifySnapToTargetContentOffset:contentOffset completed:NO];
            }
            
            if (animated) {
                [self.scrollToAnimator animateScrollToContentOffset:contentOffset];
            } else {
                [self setContentOffset:contentOffset];
            }
        }
    }
}

- (void)insertPages:(NSIndexSet *)insertedPages animated:(BOOL)animated
{
    if (insertedPages.count == 0) {
        return;
    }
    
    const NSUInteger numberOfPagesBeforeUpdate = _numberOfPages;
    const NSUInteger numberOfPagesRequiredAfterUpdate = numberOfPagesBeforeUpdate + insertedPages.count;
    
    _numberOfPages = [self.dataSource numberOfPagesInScrollView:self];
    
    if (numberOfPagesBeforeUpdate != numberOfPagesRequiredAfterUpdate) {
        [NSException raise:@"Invalid number of pages" format:@"attempt to insert (%ld) pages (there are only %ld pages after the update)", (long)insertedPages.count, (long)_numberOfPages];
    }
    
    // Invalidate the layout.
    [self invalidateLayout];
    
    // Perform layout.
    [self layoutIfNeeded];
    
    // If animated, let's fade in the new views that are now visible.
    if (animated) {
        NSIndexSet *visiblePages = self.pagesForVisibleViews;
        NSMutableSet *viewsToFade = [NSMutableSet setWithCapacity:insertedPages.count];
        
        [insertedPages enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
            NSUInteger page = idx;
            if ([visiblePages containsIndex:page]) {
                UIView *view = [self viewAtPage:page];
                if (view) {
                    [viewsToFade addObject:view];
                }
            }
        }];
        
        if (viewsToFade.count > 0) {
            for (UIView *view in viewsToFade) {
                [view setAlpha:0.0f];
            }
            
            [UIView animateWithDuration:0.25f animations:^{
                for (UIView *view in viewsToFade) {
                    [view setAlpha:1.0f];
                }
            }];
        }
    }
}

- (void)deletePages:(NSIndexSet *)pages animated:(BOOL)animated
{
    if (pages.count == 0) {
        return;
    }
    
    const NSUInteger numberOfPagesBeforeUpdate = _numberOfPages;
    const NSUInteger numberOfPagesRequiredAfterUpdate = numberOfPagesBeforeUpdate - pages.count;
    
    _numberOfPages = [self.dataSource numberOfPagesInScrollView:self];
    
    if (numberOfPagesBeforeUpdate != numberOfPagesRequiredAfterUpdate) {
        [NSException raise:@"Invalid number of pages" format:@"attempt to delete (%ld) pages (there are only %ld pages after the update)", (long)pages.count, (long)_numberOfPages];
    }
    
    // Invalidate the layout.
    [self invalidateLayout];
    
    // Let a layout cycle perform the layout if animations are not required. A regular layout cycle would
    // remove views immediately so animations wouldn't be possible.
    
    NSMutableSet *removedViews = [NSMutableSet setWithCapacity:pages.count];
    NSMutableDictionary *visibleViewsDictionary = self.visibleViewsDictionary;
    
    [visibleViewsDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSInteger page = [key integerValue];
        UIView *view = obj;
        
        if ([pages containsIndex:page]) {
            [self sendSubviewToBack:view];
            [removedViews addObject:view];
        }
    }];
    
    [visibleViewsDictionary removeObjectsForKeys:pages.array];
    [self.layoutAttributes removeObjectsAtIndexes:pages];
    
    if (animated) {
        [_viewsToRemoveAfterScrollAnimation unionSet:removedViews];
        
        // Scroll to last available page.
        [self scrollToPage:(self.numberOfPages - 1) animated:YES];
        
        // If animation is not taking place, removed views right now.
        if (!self.decelerating) {
            [self _removeQueuedViewsToRemove];
        }
    } else {
        [removedViews makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [self layoutIfNeeded];
    }
}

#pragma mark - Boilerplate.

- (void)setDelegate:(id<MMSnapScrollViewDelegate>)delegate
{
    self.delegateProxy = delegate ? [[_MMSnapScrollViewDelegateProxy alloc] initWithDelegate:delegate scrollView:self] : nil;
    
    _delegateFlags.delegateDidEndDisplayingView = [delegate respondsToSelector:@selector(scrollView:didEndDisplayingView:atPage:)];
    _delegateFlags.delegateWillDisplayView = [delegate respondsToSelector:@selector(scrollView:willDisplayView:atPage:)];
    _delegateFlags.delegateWillSnapToPage = [delegate respondsToSelector:@selector(scrollView:willSnapToView:atPage:)];
    _delegateFlags.delegateDidSnapToPage = [delegate respondsToSelector:@selector(scrollView:didSnapToView:atPage:)];
}

- (id<MMSnapScrollViewDelegate>)delegate
{
    return self.delegateProxy.delegate;
}

- (void)setDataSource:(id<MMSnapScrollViewDataSource>)dataSource
{
    if (dataSource == self.dataSource) {
        return;
    }
    
    _dataSource = dataSource;
    
    [self reloadData];
}

- (void)setBounds:(CGRect)bounds
{
    if (!CGRectEqualToRect(bounds, self.bounds)) {
        if (!CGSizeEqualToSize(bounds.size, self.bounds.size)) {
            self.contentSizeInvalidated = YES;
        }
        
        [super setBounds:bounds];
    }
}

- (void)setFrame:(CGRect)frame
{
    if (!CGRectEqualToRect(frame, self.frame)) {
        if (!CGSizeEqualToSize(frame.size, self.frame.size)) {
            self.contentSizeInvalidated = YES;
        }
        
        [super setFrame:frame];
    }
}

- (void)setContentSize:(CGSize)contentSize
{
    // Content size is managed by MMSnapScrollView.
}

- (void)_setContentSize:(CGSize)contentSize
{
    [super setContentSize:contentSize];
}

- (void)setPagingEnabled:(BOOL)pagingEnabled
{
    if (self.isPagingEnabled != pagingEnabled) {
        [super setPagingEnabled:pagingEnabled];
        
        [self.visibleSeparatorsDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            UIView <MMSnapViewSeparatorView> *separatorView = obj;
            
            [separatorView setShowsAsColumnSeparator:!pagingEnabled];
        }];
    }
}

- (BOOL)isDecelerating
{
    return [super isDecelerating] || [self.scrollToAnimator isAnimating];
}

#pragma mark - Layout attributes methods.

- (NSArray *)_layoutAttributesForElementsInRect:(CGRect)rect
{
    NSArray *array = self.layoutAttributes;
    if (array.count == 0) {
        return nil;
    }
    
    NSMutableArray *matches = [NSMutableArray array];
    for (_MMSnapScrollViewLayoutAttributes *layoutAttributes in array) {
        if (CGRectIntersectsRect(rect, layoutAttributes.frame)) {
            [matches addObject:layoutAttributes];
        }
    }
    
    return [matches copy];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    // If user begin dragging, cancel the scroll animation and remove animation views.
    if (self.scrollToAnimator.isAnimating) {
        [self.scrollToAnimator cancelAnimation];
        [self _removeQueuedViewsToRemove];
    }
    
    if ([self.delegate respondsToSelector:@selector(scrollViewWillBeginDragging:)]) {
        [self.delegate scrollViewWillBeginDragging:scrollView];
    }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    // If UIScrollView's paging is off, do our own targetContentOffset calculations.
    if (!self.pagingEnabled) {
        *targetContentOffset = [self _targetContentOffsetForProposedContentOffset:*targetContentOffset withScrollingVelocity:velocity];
    }
    
    // Notify the delegate snapping will happen.
    if (_delegateFlags.delegateWillSnapToPage && !CGPointEqualToPoint(*targetContentOffset, scrollView.contentOffset)) {
        [self _notifySnapToTargetContentOffset:*targetContentOffset completed:NO];
    }
    
    if ([self.delegate respondsToSelector:@selector(scrollViewWillEndDragging:withVelocity:targetContentOffset:)]) {
        [self.delegate scrollViewWillEndDragging:scrollView withVelocity:velocity targetContentOffset:targetContentOffset];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    // Notify the delegate snapping did happen.
    if (_delegateFlags.delegateDidSnapToPage) {
        [self _notifySnapToTargetContentOffset:scrollView.contentOffset completed:YES];
    }
    
    if ([self.delegate respondsToSelector:@selector(scrollViewDidEndDecelerating:)]) {
        [self.delegate scrollViewDidEndDecelerating:scrollView];
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    // Notify the delegate snapping did happen after animation completes.
    if (_delegateFlags.delegateDidSnapToPage) {
        [self _notifySnapToTargetContentOffset:scrollView.contentOffset completed:YES];
    }
    
    // Remove views after a delete animation is complete.
    [self _removeQueuedViewsToRemove];
    
    if ([self.delegate respondsToSelector:@selector(scrollViewDidEndScrollingAnimation:)]) {
        [self.delegate scrollViewDidEndScrollingAnimation:scrollView];
    }
}

#pragma mark - Scrolling behavior.

- (void)_notifySnapToTargetContentOffset:(CGPoint)targetContentOffset completed:(BOOL)completed
{
    id <MMSnapScrollViewDelegate> delegate = self.delegate;
    
    CGRect proposedRect = self.bounds;
    proposedRect.origin.x = MIN(targetContentOffset.x, self.contentSize.width - CGRectGetWidth(proposedRect));
    proposedRect.origin.y = targetContentOffset.y;
    
    NSUInteger page = [self pagesForViewsInRect:proposedRect].firstIndex;
    UIView *view = [self viewAtPage:page];
    
    if (completed) {
        [delegate scrollView:self didSnapToView:view atPage:page];
    } else {
        [delegate scrollView:self willSnapToView:view atPage:page];
    }
    
    _snappedPage = page;
}

- (CGPoint)_targetContentOffsetForProposedContentOffset:(CGPoint)proposedContentOffset withScrollingVelocity:(CGPoint)velocity
{
    CGRect targetRect = CGRectMake(proposedContentOffset.x, 0.0, self.bounds.size.width, self.bounds.size.height);
    
    NSArray *array = [self _layoutAttributesForElementsInRect:targetRect];
    
    CGFloat offsetAdjustment = targetRect.origin.x;
    
    _MMSnapScrollViewLayoutAttributes *first = array.firstObject;
    if (first) {
        CGRect frame = first.frame;
        
        // Go to next/prev one.
        if (CGRectGetMinX(targetRect) > CGRectGetMidX(frame) || fabs(velocity.x) > 0) {
            // Don't go over contentSize (keep this page if so).
            if (CGRectGetMaxX(frame) < self.contentSize.width) {
                offsetAdjustment = CGRectGetMaxX(frame);
            } else {
                offsetAdjustment = CGRectGetMinX(frame);
            }
            
            if (fabs(velocity.x) > 0 && velocity.x < 0) {
                offsetAdjustment = CGRectGetMinX(frame);
            }
        }
        // Or to this one.
        else {
            offsetAdjustment = CGRectGetMinX(frame);
        }
    }
    
    return CGPointMake(offsetAdjustment, proposedContentOffset.y);
}

- (void)_removeQueuedViewsToRemove
{
    NSMutableSet *viewsToRemoveAfterScrollAnimation = _viewsToRemoveAfterScrollAnimation;
    NSMutableSet *visibleViews = [NSMutableSet setWithCapacity:viewsToRemoveAfterScrollAnimation.count];
    
    CGRect visibleRect = self.bounds;
    visibleRect.origin = self.contentOffset;
    
    for (UIView *view in viewsToRemoveAfterScrollAnimation) {
        if (CGRectIntersectsRect(visibleRect, view.frame)) {
            [visibleViews addObject:view];
        } else {
            [view removeFromSuperview];
        }
    }
    
    if (visibleViews.count > 0) {
        [UIView animateWithDuration:0.15f animations:^{
            for (UIView *view in visibleViews) {
                [view setAlpha:0.0f];
            }
        } completion:^(BOOL finished) {
            [viewsToRemoveAfterScrollAnimation makeObjectsPerformSelector:@selector(removeFromSuperview)];
            [viewsToRemoveAfterScrollAnimation removeAllObjects];
        }];
    } else {
        [viewsToRemoveAfterScrollAnimation makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [viewsToRemoveAfterScrollAnimation removeAllObjects];
    }
}

#pragma mark - Touch handling.

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *view = [super hitTest:point withEvent:event];
    
    if (self.pagingEnabled) {
        return view;
    }
    
    CGRect rect = self.bounds;
    rect.origin = self.contentOffset;
    
    for (UIView *visibleView in self.visibleViews) {
        if ([view isDescendantOfView:visibleView]) {
            BOOL completelyVisible = CGRectContainsRect(rect, visibleView.frame);
            
            // Return self because we don't want to deliver touches to this subview.
            if (!completelyVisible) {
                return self;
            }
        }
    }
    return view;
}

- (void)_tapToSnapGestureRecognized:(UITapGestureRecognizer *)gestureRecognizer
{
    if (self.pagingEnabled) {
        return;
    }
    
    if (gestureRecognizer.state == UIGestureRecognizerStateRecognized) {
        CGPoint point = [gestureRecognizer locationInView:self];
        
        CGRect rect = self.bounds;
        rect.origin = self.contentOffset;
        
        NSArray *layoutAttributes = self.layoutAttributes;
        NSIndexSet *pagesInRect = [self pagesForViewsInRect:rect];
        
        [pagesInRect enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
            NSInteger page = idx;
            CGRect frame = [layoutAttributes[idx] frame];
            
            BOOL containsPoint = CGRectContainsPoint(frame, point);
            BOOL completelyVisible = CGRectContainsRect(rect, frame);
            BOOL snaps = (containsPoint && !completelyVisible);
            if (snaps) {
                if (page != NSNotFound) {
                    [self scrollToPage:pagesInRect.firstIndex + 1 animated:YES];
                }
                *stop = YES;
            }
        }];
    }
}

#pragma mark - Public methods.

- (UIView *)viewAtPage:(NSInteger)page
{
    __block UIView *view = nil;
    [_visibleViewsDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if ([key integerValue] == page) {
            view = obj;
            *stop = YES;
        }
    }];
    return view;
}

- (NSInteger)pageForView:(UIView *)view
{
    __block NSNumber *idx = nil;
    [_visibleViewsDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if (view == obj) {
            idx = key;
            *stop = YES;
        }
    }];
    if (idx) {
        return [idx integerValue];
    }
    return NSNotFound;
}

- (NSArray *)visibleViews
{
    NSMutableArray *views = [NSMutableArray new];
    [_visibleViewsDictionary enumerateKeysAndObjectsUsingBlock:^(__unused id key, UIView *obj, BOOL *stop) {
        if ([obj isKindOfClass:[UIView class]] && CGRectIntersectsRect(self.bounds, obj.frame)) {
            [views addObject:obj];
        }
    }];
    return views;
}

- (NSIndexSet *)pagesForVisibleViews
{
    if (_visibleViewsDictionary.count == 0) {
        return nil;
    }
    NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
    for (NSNumber *idx in _visibleViewsDictionary.keyEnumerator) {
        [indexSet addIndex:idx.integerValue];
    }
    return indexSet.copy;
}

- (void)setSeparatorViewClass:(Class)separatorViewClass
{
    NSAssert([separatorViewClass conformsToProtocol:@protocol(MMSnapViewSeparatorView)], @"separator view class does not conform to MMSnapViewSeparatorView protocol.");
    
    if (separatorViewClass != _separatorViewClass) {
        _separatorViewClass = separatorViewClass;
        _separatorClassDefinedWidth = [separatorViewClass separatorWidth];
        
        [self.visibleSeparatorsDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            UIView <MMSnapViewSeparatorView> *separatorView = obj;
            [self _enqueueSeparatorView:separatorView];
        }];
        [self.separatorReuseQueue removeAllObjects];
        [self.visibleSeparatorsDictionary removeAllObjects];
        
        [self setNeedsLayout];
    }
}

@end

@implementation _MMStockSnapViewSeparatorView

@synthesize showsAsColumnSeparator = _showsAsColumnSeparator;
@synthesize percentDisappeared = _percentDisappeared;

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.contentMode = UIViewContentModeRedraw;
        self.backgroundColor = [UIColor clearColor];
        
        // Gradient layer.
        CAGradientLayer *gradientLayer = [CAGradientLayer layer];
        gradientLayer.startPoint = CGPointZero;
        gradientLayer.endPoint = CGPointMake(1, 0);
        gradientLayer.colors = @[ (id)[UIColor colorWithWhite:0.0f alpha:0.0f].CGColor,
                                  (id)[UIColor colorWithWhite:0.0f alpha:0.25f].CGColor ];
        
        self.shadowGradientLayer = gradientLayer;
        
        [self.layer addSublayer:gradientLayer];
        
        // Separator layer.
        CALayer *thickLayer = [CALayer layer];
        thickLayer.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.25f].CGColor;
        
        self.thickLayer = thickLayer;
        
        [self.layer addSublayer:thickLayer];
    }
    return self;
}

- (void)setPercentDisappeared:(CGFloat)percentDisappeared
{
    _percentDisappeared = percentDisappeared;
    
    CGFloat alpha = percentDisappeared;
    
    [CATransaction begin];
    [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
    
    _thickLayer.opacity = (1.0f - alpha);
    _shadowGradientLayer.opacity = alpha;
    
    [CATransaction commit];
}

- (void)setShowsAsColumnSeparator:(BOOL)showsAsColumnSeparator
{
    _showsAsColumnSeparator = showsAsColumnSeparator;
    
    [CATransaction begin];
    [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
    
    _thickLayer.hidden = !showsAsColumnSeparator;
    
    [CATransaction commit];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect bounds = (CGRect){
        .size = self.bounds.size
    };
    
    CGFloat separatorWidth = 1.0f / [UIScreen mainScreen].scale;
    
    _thickLayer.frame = (CGRect){
        .origin.x = CGRectGetWidth(bounds) - separatorWidth,
        .size.width = separatorWidth,
        .size.height = CGRectGetHeight(bounds)
    };
    
    _shadowGradientLayer.frame = bounds;
}

+ (CGFloat)separatorWidth
{
    return _MMStockSnapViewSeparatorWidth;
}

@end

@implementation _MMSnapScrollViewLayoutAttributes

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.frame = CGRectZero;
    }
    return self;
}

- (void)setFrame:(CGRect)frame
{
    _frame = frame;
    _size = _frame.size;
    _center = (CGPoint){CGRectGetMidX(_frame), CGRectGetMidY(_frame)};
}

- (void)setCenter:(CGPoint)center
{
    _center = center;
    
    [self _updateRect];
}

- (void)setSize:(CGSize)size
{
    _size = size;
    
    [self _updateRect];
}

- (void)_updateRect
{
    _frame = (CGRect){{ _center.x - _size.width / 2.0f, _center.y - _size.height / 2.0f}, _size };
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p> frame: %@", self.class, self, NSStringFromCGRect(self.frame)];
}

@end

@implementation _MMSnapScrollViewDelegateProxy

- (instancetype)initWithDelegate:(id<MMSnapScrollViewDelegate>)delegate scrollView:(MMSnapScrollView *)scrollView
{
    self = [super init];
    if (self) {
        _delegate = delegate;
        _scrollView = scrollView;
    }
    return self;
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
    if ([self.scrollView respondsToSelector:aSelector] || [self.delegate respondsToSelector:aSelector]){
        return YES;
    }
    return NO;
}

- (id)forwardingTargetForSelector:(SEL)aSelector
{
    id scrollView = self.scrollView;
    id delegate = self.delegate;
    
    if ([scrollView respondsToSelector:aSelector]){
        return scrollView;
    }
    
    if ([delegate respondsToSelector:aSelector]){
        return delegate;
    }
    
    return nil;
}

@end
