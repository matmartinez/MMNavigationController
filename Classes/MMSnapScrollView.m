//
//  MMSnapPagingScrollView.m
//  MMSnapController
//
//  Created by Matías Martínez on 1/11/15.
//  Copyright (c) 2015 Matías Martínez. All rights reserved.
//

#import "MMSnapScrollView.h"
#import "MMSpringScrollAnimator.h"
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

static NSString *_MMElementCategoryPage = @"PageView";
static NSString *_MMElementCategorySeparator = @"SeparatorView";

typedef NS_ENUM(NSUInteger, _MMSnapScrollViewUpdateAction) {
    _MMSnapScrollViewUpdateActionReload,
    _MMSnapScrollViewUpdateActionDelete,
    _MMSnapScrollViewUpdateActionInsert
};

@interface _MMSnapScrollViewUpdateItem : NSObject

- (instancetype)initWithUpdateAction:(_MMSnapScrollViewUpdateAction)updateAction forPage:(NSInteger)page;

@property (readonly, nonatomic) _MMSnapScrollViewUpdateAction updateAction;

@property (assign, nonatomic) NSInteger page;
@property (assign, nonatomic) NSInteger initialPage;
@property (assign, nonatomic) NSInteger finalPage;

- (NSComparisonResult)comparePages:(_MMSnapScrollViewUpdateItem *)otherItem;
- (NSComparisonResult)inverseComparePages:(_MMSnapScrollViewUpdateItem *)otherItem;

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

@property (strong, nonatomic) NSMutableDictionary *updates;
@property (assign, nonatomic, getter=isUpdating) BOOL updating;

@property (strong, nonatomic) NSMutableDictionary *visibleViewsDictionary;
@property (strong, nonatomic) NSMutableArray *layoutAttributes;

@property (strong, nonatomic) NSMutableDictionary *visibleSeparatorsDictionary;
@property (strong, nonatomic) NSMutableSet *separatorReuseQueue;
@property (assign, nonatomic) CGFloat separatorClassDefinedWidth;

@property (strong, nonatomic) MMSpringScrollAnimator *scrollToAnimator;
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
    _updates = [NSMutableDictionary dictionary];
    
    // Custom animator for content offset updates.
    _scrollToAnimator = [[MMSpringScrollAnimator alloc] initWithTargetScrollView:self];
    _scrollToAnimator.mass = 1;
    _scrollToAnimator.stiffness = 280;
    _scrollToAnimator.damping = 50;
    _scrollToAnimator.delegate = self;
    
    // Adds a snap to page gesture recognizer.
    UITapGestureRecognizer *tapToSnapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_tapToSnapGestureRecognized:)];
    tapToSnapGestureRecognizer.cancelsTouchesInView = NO;
    
    [self addGestureRecognizer:tapToSnapGestureRecognizer];
    
    [self setDecelerationRate:UIScrollViewDecelerationRateFast];
    [self setShowsHorizontalScrollIndicator:NO];
    [self setShowsVerticalScrollIndicator:NO];
    [self setAlwaysBounceHorizontal:YES];
    [self setAlwaysBounceVertical:NO];
    [self setScrollsToTop:NO];
    
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
    if (@available(iOS 11.0, *)) {
        [self setContentInsetAdjustmentBehavior:UIScrollViewContentInsetAdjustmentNever];
    }
#endif
    
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
        
        BOOL showsSeparator = ((page + 1) < self->_numberOfPages);
        
        CGFloat disappearPercent = 0.0f;
        CGRect rect = [self _rectForViewAtPage:page disappearPercent:&disappearPercent];
        
        CGRect separatorRect = CGRectZero;
        if (showsSeparator) {
            CGRect referenceRect = [self _rectForViewAtPage:(page + 1) disappearPercent:NULL];
            separatorRect = [self _separatorRectWithReferenceRect:referenceRect];
        }
        
        // Insert the view if not displaying:
        BOOL isDisplayingViewAtIndex = (view != nil);
        if (!isDisplayingViewAtIndex) {
            view = [dataSource scrollView:self viewAtPage:page];
            
            NSAssert(view != nil, @"view cannot be nil.");
            
            [visibleViewsDictionary setObject:view forKey:key];
            
            UIView *nextView = [visibleViewsDictionary objectForKey:@(page + 1)];
            if (nextView) {
                [self insertSubview:view belowSubview:nextView];
            } else {
                [self addSubview:view];
            }
            
            if (notifyWillDisplayView) {
                [delegate scrollView:self willDisplayView:view atPage:page];
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
    }];
}

- (CGRect)_rectForViewAtPage:(NSInteger)page disappearPercent:(CGFloat *)disappearPercent
{
    _MMSnapScrollViewLayoutAttributes *layoutAttributes = [self _layoutAttributesForPage:page];
    CGRect rect = [layoutAttributes frame];
    
    CGRect bounds = self.bounds;
    CGPoint contentOffset = self.contentOffset;
    
    // Add parallax offset if:
    // a. This page should be disappearing because of the content offset.
    // b. This page can completely dissapear.
    const BOOL isBehindContentOffset = (CGRectGetMinX(rect) < contentOffset.x);
    const BOOL canDisappear = CGRectGetMaxX(rect) <= self.contentSize.width - CGRectGetWidth(bounds);
    
    if (canDisappear && isBehindContentOffset) {
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
    
    [self _validateLayoutIfNeeded];
    
    // Note validation.
    self.contentSizeInvalidated = NO;
}

- (void)_validateLayoutIfNeeded
{
    id dataSource = self.dataSource;
    
    [_layoutAttributes removeAllObjects];
    
    CGRect rect = UIEdgeInsetsInsetRect(self.bounds, self.contentInset);
    
    CGFloat origin = 0;
    for (NSInteger idx = 0; idx < _numberOfPages; idx++) {
        rect.origin.y = 0;
        rect.origin.x = origin;
        rect.size.width = [dataSource scrollView:self widthForViewAtPage:idx];
        
        _MMSnapScrollViewLayoutAttributes *layoutAttributes = [[_MMSnapScrollViewLayoutAttributes alloc] init];
        layoutAttributes.frame = rect;
        
        [_layoutAttributes addObject:layoutAttributes];
        
        origin = CGRectGetMaxX(rect);
    }
    
    // Update with new content size.
    CGSize contentSize = CGSizeMake(origin, CGRectGetHeight(rect));
    [self _setContentSize:contentSize];
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
    
    // Enqueue separators.
    for (UIView <MMSnapViewSeparatorView> *separatorView in _visibleSeparatorsDictionary.allValues) {
        [self _enqueueSeparatorView:separatorView];
    }
    [_visibleSeparatorsDictionary removeAllObjects];
    
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

#pragma mark - Scroll to.

- (void)scrollToPage:(NSInteger)page animated:(BOOL)animated
{
    animated = animated && [UIView areAnimationsEnabled];
    
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
                [self.scrollToAnimator animateScrollToContentOffset:contentOffset duration:0.55];
            } else {
                [self setContentOffset:contentOffset];
            }
        }
    }
}

#pragma mark - Batch operations.

- (void)reloadPages:(NSIndexSet *)pages animated:(BOOL)animated
{
    [self _updatePages:pages withAction:_MMSnapScrollViewUpdateActionReload animated:animated];
}

- (void)insertPages:(NSIndexSet *)pages animated:(BOOL)animated
{
    [self _updatePages:pages withAction:_MMSnapScrollViewUpdateActionInsert animated:animated];
}

- (void)deletePages:(NSIndexSet *)pages animated:(BOOL)animated
{
    [self _updatePages:pages withAction:_MMSnapScrollViewUpdateActionDelete animated:animated];
}

- (void)_updatePages:(NSIndexSet *)pages withAction:(_MMSnapScrollViewUpdateAction)action animated:(BOOL)animated
{
    if (pages.count == 0) {
        return;
    }
    
    BOOL updating = self.isUpdating;
    if (!updating) {
        [self _beginUpdates];
    }
    
    NSMutableArray *updates = [self _updatesArrayForAction:action];
    
    [pages enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        _MMSnapScrollViewUpdateItem *update = [[_MMSnapScrollViewUpdateItem alloc] initWithUpdateAction:action forPage:idx];
        [updates addObject:update];
    }];
    
    if (!updating) {
        [self _endUpdatesAnimated:animated];
    }
}

- (void)performBatchUpdates:(dispatch_block_t)updates completion:(void (^)(BOOL))completion
{
    NSParameterAssert(updates);
    
    [self _beginUpdates];
    
    updates();
    
    BOOL didUpdate = [self _endUpdatesAnimated:YES];
    
    if (completion) {
        completion(didUpdate);
    }
}

- (void)_beginUpdates
{
    if (self.isUpdating) {
        return;
    }
    
    self.updating = YES;
}

- (BOOL)_endUpdatesAnimated:(BOOL)animated
{
    NSArray *removeUpdateItems = [[self _updatesArrayForAction:_MMSnapScrollViewUpdateActionDelete]
                                  sortedArrayUsingSelector:@selector(inverseComparePages:)];
    
    NSArray *insertUpdateItems = [[self _updatesArrayForAction:_MMSnapScrollViewUpdateActionInsert]
                                  sortedArrayUsingSelector:@selector(comparePages:)];
    
    NSMutableArray *layoutUpdateItems = [NSMutableArray array];
    [layoutUpdateItems addObjectsFromArray:removeUpdateItems];
    [layoutUpdateItems addObjectsFromArray:insertUpdateItems];
    
    NSArray *categories = @[ _MMElementCategoryPage, _MMElementCategorySeparator ];
    NSMutableDictionary *newVisibleViews = [NSMutableDictionary dictionaryWithCapacity:categories.count];
    for (NSString *category in categories) {
        newVisibleViews[category] = [self _orderedViewsWithElementCategory:category].mutableCopy;
    }
    
    for (_MMSnapScrollViewUpdateItem *updateItem in layoutUpdateItems) {
        for (NSMutableArray *array in newVisibleViews.allValues) {
            switch (updateItem.updateAction) {
                case _MMSnapScrollViewUpdateActionDelete:
                    [array removeObjectAtIndex:updateItem.initialPage];
                    break;
                case _MMSnapScrollViewUpdateActionInsert:
                    [array insertObject:[NSNull null] atIndex:updateItem.finalPage];
                    break;
                default:
                    break;
            }
        }
    }
    
    // Update number of pages.
    const NSInteger numberOfPages = (_numberOfPages - removeUpdateItems.count + insertUpdateItems.count);
    
    // Assert if data source is wrong.
    if (numberOfPages != [_dataSource numberOfPagesInScrollView:self]) {
        [NSException raise:@"invalid number of pages" format:@"attempt to insert (%lu) and delete (%lu) pages, but there are only %ld pages after the update.", (unsigned long)insertUpdateItems.count, (unsigned long)removeUpdateItems.count, (long)_numberOfPages];
    }
    
    _numberOfPages = numberOfPages;
    
    // Validate layout.
    [self _validateLayoutIfNeeded];
    
    // Update visible views dict.
    NSMutableSet *viewsToRemove = [NSMutableSet set];
    
    [newVisibleViews enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSString *category = key;
        NSArray *array = obj;
        
        NSMutableDictionary *dict = nil;
        if ([category isEqualToString:_MMElementCategoryPage]) {
            dict = self->_visibleViewsDictionary;
        } else if ([category isEqualToString:_MMElementCategorySeparator]) {
            dict = self->_visibleSeparatorsDictionary;
        } else {
            [[NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"Invalid element category named `%@`", category] userInfo:nil] raise];
        }
        
        // Snapshot before.
        NSSet *visibleViewsBeforeUpdate = [NSSet setWithArray:dict.allValues];
        
        // Remove existing entries.
        [dict removeAllObjects];
        
        // Update with new order.
        [array enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            UIView *view = (obj != [NSNull null]) ? obj : nil;
            NSInteger page = idx;
            
            if (view) {
                [dict setObject:view forKey:@(page)];
            }
        }];
        
        // Remove what's left.
        NSMutableSet *unused = visibleViewsBeforeUpdate.mutableCopy;
        [unused minusSet:[NSSet setWithArray:dict.allValues]];
        
        [viewsToRemove unionSet:unused];
    }];
    
    // Animate views.
    if (viewsToRemove.count > 0) {
        NSTimeInterval duration = (animated ? 0.25 : 0);
        
        [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
            for (UIView *view in viewsToRemove) {
                [view setAlpha:0.0f];
            }
        } completion:^(BOOL finished) {
            for (UIView *view in viewsToRemove) {
                [view removeFromSuperview];
                [view setAlpha:1.0f];
                
                if ([view conformsToProtocol:@protocol(MMSnapViewSeparatorView)]) {
                    [self _enqueueSeparatorView:(UIView <MMSnapViewSeparatorView> *)view];
                }
            }
        }];
    }
    
    // Layout.
    [self setNeedsLayout];
    
    // Clear the updates.
    [self.updates removeAllObjects];
    
    // Set flag.
    self.updating = NO;
    
    return (layoutUpdateItems.count > 0);
}

- (NSArray *)_orderedViewsWithElementCategory:(NSString *)elementCategory
{
    NSDictionary *storage = nil;
    if ([elementCategory isEqualToString:_MMElementCategoryPage]) {
        storage = _visibleViewsDictionary;
    } else if ([elementCategory isEqualToString:_MMElementCategorySeparator]) {
        storage = _visibleSeparatorsDictionary;
    }
    
    const NSInteger numberOfPages = _numberOfPages;
    
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:numberOfPages];
    for (NSUInteger page = 0; page < numberOfPages; page++) {
        id key = @(page);
        [array addObject:storage[key] ?: [NSNull null]];
    }
    
    return array;
}

- (NSMutableArray *)_updatesArrayForAction:(_MMSnapScrollViewUpdateAction)action
{
    id key = @(action);
    
    NSMutableArray *array = _updates[key];
    if (!array) {
        array = [NSMutableArray array];
        
        _updates[key] = array;
    }
    
    return array;
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

- (void)setContentInset:(UIEdgeInsets)contentInset
{
    if (!UIEdgeInsetsEqualToEdgeInsets(contentInset, self.contentInset)) {
        self.contentSizeInvalidated = YES;
        
        [super setContentInset:contentInset];
        [self setNeedsLayout];
    }
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

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    id <MMSnapScrollViewDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(scrollViewDidScroll:)]) {
        [delegate scrollViewDidScroll:scrollView];
    }
}

#pragma mark - Scrolling behavior.

- (void)_notifySnapToTargetContentOffset:(CGPoint)targetContentOffset completed:(BOOL)completed
{
    id <MMSnapScrollViewDelegate> delegate = self.delegate;
    
    CGRect proposedRect = self.bounds;
    proposedRect.origin.x = MIN(ceil(targetContentOffset.x), self.contentSize.width - CGRectGetWidth(proposedRect));
    proposedRect.origin.y = ceil(targetContentOffset.y);
    
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
                    NSInteger newPage = page;
                    
                    if (newPage != pagesInRect.firstIndex) {
                        newPage = pagesInRect.firstIndex + 1;
                    }
                    
                    [self scrollToPage:newPage animated:YES];
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

@implementation _MMSnapScrollViewUpdateItem

- (instancetype)initWithUpdateAction:(_MMSnapScrollViewUpdateAction)updateAction forPage:(NSInteger)page
{
    self = [super init];
    if (self) {
        if (updateAction == _MMSnapScrollViewUpdateActionInsert)
            return [self initWithInitialPage:NSNotFound finalPage:page updateAction:updateAction];
        else if (updateAction == _MMSnapScrollViewUpdateActionDelete)
            return [self initWithInitialPage:page finalPage:NSNotFound updateAction:updateAction];
        else if (updateAction == _MMSnapScrollViewUpdateActionReload)
            return [self initWithInitialPage:page finalPage:page updateAction:updateAction];
    }
    return self;
}

- (id)initWithInitialPage:(NSInteger)initialPage finalPage:(NSInteger)finalPage updateAction:(_MMSnapScrollViewUpdateAction)updateAction
{
    self = [super init];
    if (self) {
        _initialPage = initialPage;
        _finalPage = finalPage;
        _updateAction = updateAction;
    }
    return self;
}

- (NSInteger)page
{
    return _initialPage;
}

- (NSComparisonResult)comparePages:(_MMSnapScrollViewUpdateItem *)otherItem
{
    NSNumber *selfIndex = nil;
    NSNumber *otherIndex = nil;
    
    switch (_updateAction) {
        case _MMSnapScrollViewUpdateActionInsert:
            selfIndex = @(_finalPage);
            otherIndex = @([otherItem initialPage]);
            break;
        case _MMSnapScrollViewUpdateActionDelete:
            selfIndex = @(_initialPage);
            otherIndex = @([otherItem page]);
        default: break;
    }
    
    return [selfIndex compare:otherIndex];
}

- (NSComparisonResult)inverseComparePages:(_MMSnapScrollViewUpdateItem *)otherItem
{
    return (NSComparisonResult)([self comparePages:otherItem] * -1);
}

- (NSString *)description
{
    const _MMSnapScrollViewUpdateAction update = _updateAction;
    const NSInteger page = _page;
    
    NSString *action = nil;
    if (update == _MMSnapScrollViewUpdateActionReload) {
        action = @"Reload";
    } else if (update == _MMSnapScrollViewUpdateActionInsert) {
        action = @"Insert";
    } else if (update == _MMSnapScrollViewUpdateActionDelete) {
        action = @"Delete";
    }
    return [NSString stringWithFormat:@"<%@: %p> action: %@, page: %@", self.class, self, action, @(page)];
}

@end

