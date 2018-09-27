//
//  MMSnapController.m
//  MMSnapController
//
//  Created by Matías Martínez on 1/11/15.
//  Copyright (c) 2015 Matías Martínez. All rights reserved.
//

#import "MMSnapController.h"
#import "MMSnapScrollView.h"
#import "MMSnapHeaderView.h"
#import "MMSnapFooterView.h"

@interface MMSnapController () <MMSnapScrollViewDataSource, MMSnapScrollViewDelegate>
{
    struct {
        unsigned int delegateWillDisplayViewController : 1;
        unsigned int delegateDidEndDisplayingViewController : 1;
        unsigned int delegateCustomWidthForViewController : 1;
        unsigned int delegateWillSnapViewController : 1;
        unsigned int delegateDidSnapViewController : 1;
        unsigned int delegateWillTransitionToScrollMode : 1;
    } _delegateFlags;
}

@property (readonly, nonatomic) MMSnapScrollView *scrollView;

@property (strong, nonatomic) NSMutableArray *headerFooterViewArray;
@property (strong, nonatomic) Class headerViewClass;
@property (strong, nonatomic) Class footerViewClass;

@end

typedef NS_ENUM(NSUInteger, MMSnapViewType) {
    MMSnapViewTypeHeader,
    MMSnapViewTypeFooter
};

@interface MMSnapSupplementaryView ()

@property (assign, nonatomic, setter=_setViewType:) MMSnapViewType _viewType;
@property (weak, nonatomic, readwrite) UIViewController *viewController;
@property (weak, nonatomic, readwrite) MMSnapController *snapController;

@end

@implementation MMSnapController

#pragma mark - Init.

- (instancetype)init
{
    return [self initWithViewControllers:nil];
}

- (instancetype)initWithHeaderViewClass:(Class)headerViewClass footerViewClass:(Class)footerViewClass
{
    self = [self initWithViewControllers:nil];
    if (self) {
        self.headerViewClass = headerViewClass;
        self.footerViewClass = footerViewClass;
    }
    return self;
}

- (instancetype)initWithRootViewController:(UIViewController *)controlller
{
    NSArray *viewControllers = nil;
    if (controlller) {
        viewControllers = @[ controlller ];
    }
    return [self initWithViewControllers:viewControllers];
}

- (instancetype)initWithViewControllers:(NSArray *)viewControllers
{
    self = [super init];
    if (self) {
        self.viewControllers = [viewControllers copy];
    }
    return self;
}

#pragma mark - Containment.

- (void)setViewControllers:(NSArray *)viewControllers
{
    if ([viewControllers isEqualToArray:_viewControllers]) {
        return;
    }
    
    NSIndexSet *removedIndexes = [_viewControllers indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        UIViewController *vc = obj;
        
        return ![viewControllers containsObject:vc];
    }];
    
    NSIndexSet *insertedIndexes = [viewControllers indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        UIViewController *vc = obj;
        
        return ![_viewControllers containsObject:vc];
    }];
    
    NSArray *inserted = [viewControllers objectsAtIndexes:insertedIndexes];
    NSArray *removed = [_viewControllers objectsAtIndexes:removedIndexes];
    
    // Supplementary views.
    [self _removeSupplementaryViewsForViewControllers:removed];
    [self _insertSupplementaryViewsForViewControllers:inserted];
    
    // Begin transaction.
    [removed makeObjectsPerformSelector:@selector(willMoveToParentViewController:) withObject:nil];
    [inserted makeObjectsPerformSelector:@selector(willMoveToParentViewController:) withObject:self];
    
    _viewControllers = viewControllers;
    
    // End transaction.
    [removed makeObjectsPerformSelector:@selector(removeFromParentViewController)];
    [inserted makeObjectsPerformSelector:@selector(didMoveToParentViewController:) withObject:self];
    
    BOOL isViewLoaded = self.isViewLoaded;
    
    for (UIViewController *vc in viewControllers) {
        if (vc.parentViewController != self) {
            [self addChildViewController:vc];
        }
    }
    
    // Update the UI.
    if (isViewLoaded) {
        [self.scrollView performBatchUpdates:^{
            [self.scrollView deletePages:removedIndexes animated:YES];
            [self.scrollView insertPages:insertedIndexes animated:YES];
        } completion:^(BOOL changesWereMade) {
            if (changesWereMade) {
                [self _notifyViewControllersDidChange];
            }
        }];
    }
}

- (BOOL)shouldAutomaticallyForwardAppearanceMethods
{
    return NO;
}

- (UIViewController *)childViewControllerForStatusBarHidden
{
    return self.visibleViewControllers.firstObject ?: self.viewControllers.firstObject;
}

- (UIViewController *)childViewControllerForStatusBarStyle
{
    return self.visibleViewControllers.firstObject ?: self.viewControllers.firstObject;
}

- (NSArray *)visibleViewControllers
{
    if (!self.isViewLoaded) {
        return nil;
    }
    
    NSIndexSet *pages = self.scrollView.pagesForVisibleViews;
    if (pages.count == 0) {
        return nil;
    }
    
    NSArray *viewControllers = self.viewControllers;
    NSMutableArray *visibleViewControllers = [NSMutableArray arrayWithCapacity:pages.count];
    
    [pages enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        UIViewController *vc = viewControllers[idx];
        [visibleViewControllers addObject:vc];
    }];
    
    return visibleViewControllers;
}

- (UIViewController *)partiallyVisibleViewController
{
    if (!self.isViewLoaded || self.scrollMode == MMSnapScrollModePaging) {
        return nil;
    }
    
    UIViewController *lastVisibleViewController = self.visibleViewControllers.lastObject;
    if (!CGRectContainsRect(self.view.bounds, lastVisibleViewController.view.frame)) {
        return lastVisibleViewController;
    }
    
    return nil;
}

#pragma mark - View.

- (void)loadView
{
    MMSnapScrollView *scrollView = [[MMSnapScrollView alloc] initWithFrame:CGRectZero];
    scrollView.dataSource = self;
    scrollView.delegate = self;
    
    self.view = scrollView;
}

- (MMSnapScrollView *)scrollView
{
    return (MMSnapScrollView *)self.view;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if ([UITraitCollection class]) {
        [self _configureScrollViewWithTraitCollection:self.traitCollection];
    } else {
        self.scrollView.pagingEnabled = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone);
    }
}

#pragma mark - Delegate.

- (void)setDelegate:(id<MMSnapControllerDelegate>)delegate
{
    if (delegate == _delegate) {
        return;
    }
    
    _delegate = delegate;
    
    _delegateFlags.delegateCustomWidthForViewController = [delegate respondsToSelector:@selector(snapController:metricsForViewController:)];
    _delegateFlags.delegateDidEndDisplayingViewController = [delegate respondsToSelector:@selector(snapController:didEndDisplayingViewController:)];
    _delegateFlags.delegateWillDisplayViewController = [delegate respondsToSelector:@selector(snapController:willDisplayViewController:)];
    _delegateFlags.delegateWillSnapViewController = [delegate respondsToSelector:@selector(snapController:willSnapToViewController:)];
    _delegateFlags.delegateDidSnapViewController = [delegate respondsToSelector:@selector(snapController:didSnapToViewController:)];
    _delegateFlags.delegateWillTransitionToScrollMode = [delegate respondsToSelector:@selector(snapController:willTransitionToScrollMode:transitionCoordinator:)];
}

#pragma mark - Scroll to.

- (void)scrollToViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    NSUInteger idx = [self.viewControllers indexOfObject:viewController];
    
    // No can do.
    if (idx == NSNotFound) {
        return;
    }
    
    [self.scrollView scrollToPage:idx animated:animated];
}

- (MMSnapScrollMode)scrollMode
{
    if (self.scrollView.isPagingEnabled) {
        return MMSnapScrollModePaging;
    }
    return MMSnapScrollModeNearestSnapPoint;
}

#pragma mark - Operations.

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    // No can do.
    if ([self.viewControllers containsObject:viewController]) {
        return;
    }
    
    // Add as child.
    [self addChildViewController:viewController];
    
    // Update data source.
    _viewControllers = [_viewControllers arrayByAddingObject:viewController];
    
    // Now the data source is updated, just commit the operations.
    NSInteger page = self.viewControllers.count - 1;
    
    [self.scrollView insertPages:[NSIndexSet indexSetWithIndex:page] animated:animated];
    [self.scrollView scrollToPage:page animated:animated];
    
    // Note update.
    [self _notifyViewControllersDidChange];
}

- (NSArray *)popToViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    NSUInteger idx = [self.viewControllers indexOfObject:viewController];
    
    // Don't do anything if view controller is nowhere to be found.
    if (idx == NSNotFound) {
        return nil;
    }
    
    // No can do.
    if (self.viewControllers.count == 1) {
        return nil;
    }
    
    NSRange range = NSMakeRange(idx + 1, (self.viewControllers.count - 1) - idx);
    NSArray *popViewControllers = [self.viewControllers subarrayWithRange:range];
    
    // Remove from parent.
    for (UIViewController *vc in popViewControllers) {
        [vc willMoveToParentViewController:nil];
        [vc removeFromParentViewController];
    }
    
    // Update data source.
    _viewControllers = [_viewControllers subarrayWithRange:NSMakeRange(0, range.location)];
    
    // Now the data source is updated, just commit the operations.
    [self.scrollView deletePages:[NSIndexSet indexSetWithIndexesInRange:range] animated:animated];
    
    // Remove supplementary views.
    [self _removeSupplementaryViewsForViewControllers:popViewControllers];
    
    // Note update.
    [self _notifyViewControllersDidChange];
    
    return popViewControllers;
}

- (NSArray *)popToRootViewControllerAnimated:(BOOL)animated
{
    // No can do.
    if (self.viewControllers.count == 0 || self.visibleViewControllers.firstObject == self.viewControllers.firstObject) {
        return nil;
    }
    
    return [self popToViewController:self.viewControllers.firstObject animated:animated];
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated
{
    UIViewController *topViewController = self.viewControllers.lastObject;
    if (topViewController) {
        NSUInteger pop = [self.viewControllers indexOfObject:topViewController] - 1;
        
        if (pop < self.viewControllers.count) {
            return [self popToViewController:self.viewControllers[pop] animated:animated].firstObject;
        }
    }
    return nil;
}

#pragma mark - Size classes.

- (void)_configureScrollViewWithTraitCollection:(UITraitCollection *)traitCollection
{
    [self _configureScrollViewWithTraitCollection:traitCollection transitionCoordinator:nil];
}

- (void)_configureScrollViewWithTraitCollection:(UITraitCollection *)traitCollection transitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    BOOL horizontallyCompact = traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassCompact;
    BOOL pagingEnabled = horizontallyCompact;
    
    if (pagingEnabled != self.scrollView.isPagingEnabled) {
        MMSnapScrollMode scrollMode = pagingEnabled ? MMSnapScrollModePaging : MMSnapScrollModeNearestSnapPoint;
        
        if (_delegateFlags.delegateWillTransitionToScrollMode) {
            [self.delegate snapController:self willTransitionToScrollMode:scrollMode transitionCoordinator:coordinator];
        }
        
        [self.scrollView setPagingEnabled:pagingEnabled];
        [self.scrollView invalidateLayout];
    }
}

- (void)willTransitionToTraitCollection:(UITraitCollection *)newCollection withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super willTransitionToTraitCollection:newCollection withTransitionCoordinator:coordinator];
    [self _configureScrollViewWithTraitCollection:newCollection transitionCoordinator:coordinator];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    [self _configureScrollViewWithTraitCollection:self.traitCollection];
}

#pragma mark - Snap scroll view data source.

- (CGFloat)scrollView:(MMSnapScrollView *)scrollView widthForViewAtPage:(NSInteger)page
{
    const CGRect bounds = self.view.bounds;
    
    if (_delegateFlags.delegateCustomWidthForViewController) {
        UIViewController *viewController = [self _viewControllerAtPage:page];
        
        const MMViewControllerMetrics metrics = [self.delegate snapController:self metricsForViewController:viewController];
        
        if (metrics == MMViewControllerMetricsFullscreen) {
            return CGRectGetWidth(bounds);
        }
        
        BOOL pagingEnabled;
        if ([UITraitCollection class]) {
            BOOL horizontallyCompact = self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassCompact;
            pagingEnabled = horizontallyCompact;
        } else {
            pagingEnabled = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone;
        }
        
        if (!pagingEnabled) {
            UIUserInterfaceIdiom userInterfaceIdiom;
            if ([UITraitCollection class]) {
                userInterfaceIdiom = self.traitCollection.userInterfaceIdiom;
            } else {
                userInterfaceIdiom = UI_USER_INTERFACE_IDIOM();
            }
            
            CGFloat compactWidth = 320.0f;
            
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
            if (@available(iOS 11.0, *)) {
                const UIEdgeInsets safeAreaInsets = self.view.safeAreaInsets;
                const CGFloat estimatedMargin = MAX(safeAreaInsets.left, safeAreaInsets.right);
                
                compactWidth += estimatedMargin;
            }
#endif
            
            if (metrics == MMViewControllerMetricsCompact) {
                return compactWidth;
            } else if (metrics == MMViewControllerMetricsLarge) {
                if (CGRectGetWidth(bounds) > CGRectGetHeight(bounds)) {
                    return CGRectGetWidth(bounds) - compactWidth;
                } else {
                    return CGRectGetWidth(bounds);
                }
            }
        }
    }
    return CGRectGetWidth(bounds);
}

- (UIView *)scrollView:(MMSnapScrollView *)scrollView viewAtPage:(NSInteger)page
{
    return [self _viewControllerAtPage:page].view;
}

- (NSInteger)numberOfPagesInScrollView:(MMSnapScrollView *)scrollView
{
    return self.viewControllers.count;
}

#pragma mark - Snap scroll view delegate.

- (void)scrollView:(MMSnapScrollView *)scrollView willDisplayView:(UIView *)view atPage:(NSInteger)page
{
    UIViewController *viewController = [self _viewControllerAtPage:page];
    if (viewController) {
        [viewController beginAppearanceTransition:YES animated:(scrollView.isDecelerating || scrollView.isTracking)];
        [viewController endAppearanceTransition];
        
        for (MMSnapSupplementaryView *view in self.headerFooterViewArray) {
            if (view.viewController == viewController) {
                [view snapControllerWillDisplayViewController];
                break;
            }
        }
        
        if (_delegateFlags.delegateWillDisplayViewController) {
            [self.delegate snapController:self willDisplayViewController:viewController];
        }
    }
}

- (void)scrollView:(MMSnapScrollView *)scrollView didEndDisplayingView:(UIView *)view atPage:(NSInteger)page
{
    UIViewController *viewController = [self _viewControllerAtPage:page];
    if (viewController) {
        [viewController beginAppearanceTransition:NO animated:(scrollView.isDecelerating || scrollView.isTracking)];
        [viewController endAppearanceTransition];
        
        if (_delegateFlags.delegateDidEndDisplayingViewController) {
            [self.delegate snapController:self didEndDisplayingViewController:viewController];
        }
    }
}

- (void)scrollView:(MMSnapScrollView *)scrollView willSnapToView:(UIView *)view atPage:(NSInteger)page
{
    UIViewController *viewController = [self _viewControllerAtPage:page];
    if (viewController) {
        if (_delegateFlags.delegateWillSnapViewController) {
            [self.delegate snapController:self willSnapToViewController:viewController];
        }
        
        for (MMSnapSupplementaryView *view in self.headerFooterViewArray) {
            [view snapControllerWillSnapToViewController:viewController];
        }
    }
}

- (void)scrollView:(MMSnapScrollView *)scrollView didSnapToView:(UIView *)view atPage:(NSInteger)page
{
    UIViewController *viewController = [self _viewControllerAtPage:page];
    if (_delegateFlags.delegateDidSnapViewController) {
        [self.delegate snapController:self didSnapToViewController:viewController];
    }
}

#pragma mark - Scroll view delegate.

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    static BOOL invalidateSafeAreaInvocationNeeded;
    static SEL invalidateSafeAreaSelector;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *invalidateSafeAreaSelectorString = [@[ @"_updateCont", @"entOverlayInsetsF", @"orSelfAndChildren" ] componentsJoinedByString:@""];
        
        invalidateSafeAreaSelector = NSSelectorFromString(invalidateSafeAreaSelectorString);
        invalidateSafeAreaInvocationNeeded = [self respondsToSelector:invalidateSafeAreaSelector];
    });
    
    if (invalidateSafeAreaInvocationNeeded) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:invalidateSafeAreaSelector];
#pragma clang diagnostic pop
    }
}

#pragma mark - View controller action support.

- (void)showViewController:(UIViewController *)vc sender:(id)sender
{
    if (vc) {
        if ([self.viewControllers containsObject:vc]) {
            [self scrollToViewController:vc animated:YES];
        } else {
            [self pushViewController:vc animated:YES];
        }
    }
}

#pragma mark - Header / footer support.

- (NSMutableArray *)headerFooterViewArray
{
    if (!_headerFooterViewArray) {
        _headerFooterViewArray = [NSMutableArray array];
    }
    return _headerFooterViewArray;
}

- (UIView *)headerViewForViewController:(UIViewController *)viewController
{
    return [self _supplementaryViewWithType:MMSnapViewTypeHeader forViewForViewController:viewController];
}

- (UIView *)footerViewForViewController:(UIViewController *)viewController
{
    return [self _supplementaryViewWithType:MMSnapViewTypeFooter forViewForViewController:viewController];
}

- (UIView *)_supplementaryViewWithType:(MMSnapViewType)type forViewForViewController:(UIViewController *)viewController
{
    if (![self.viewControllers containsObject:viewController]) {
        return nil;
    }
    
    MMSnapSupplementaryView *view = nil;
    
    for (MMSnapSupplementaryView *v in self.headerFooterViewArray.copy) {
        if (v._viewType == type && v.viewController == viewController) {
            view = v;
            break;
        }
    }
    
    if (!view) {
        Class viewClass;
        if (type == MMSnapViewTypeHeader) {
            viewClass = self.headerViewClass ?: [MMSnapHeaderView class];
        } else if (type == MMSnapViewTypeFooter) {
            viewClass = self.footerViewClass ?: [MMSnapFooterView class];
        }
        
        view = [[viewClass alloc] initWithFrame:CGRectZero];
        view.snapController = self;
        view.viewController = viewController;
        view._viewType = type;
        
        [view didMoveToSnapController];
        
        if (view) {
            [self.headerFooterViewArray addObject:view];
        }
    }
    
    return view;
}

- (void)_insertSupplementaryViewsForViewControllers:(NSArray *)viewControllers
{
    for (MMSnapSupplementaryView *view in self.headerFooterViewArray.copy) {
        if ([viewControllers containsObject:view.viewController]) {
            [view didMoveToSnapController];
        }
    }
}

- (void)_removeSupplementaryViewsForViewControllers:(NSArray *)viewControllers
{
    for (MMSnapSupplementaryView *view in self.headerFooterViewArray.copy) {
        if ([viewControllers containsObject:view.viewController]) {
            [view willMoveFromSnapController];
        }
    }
}

- (void)_notifyViewControllersDidChange
{
    for (MMSnapSupplementaryView *view in self.headerFooterViewArray.copy) {
        [view snapControllerViewControllersDidChange];
    }
}

#pragma mark - Getter.

- (UIViewController *)_viewControllerAtPage:(NSInteger)page
{
    if (page < self.viewControllers.count) {
        return self.viewControllers[page];
    }
    return nil;
}

@end

@implementation MMSnapController (StateRestoration)

static NSString * MMViewControllerChildrenKey = @"kUIViewControllerChildrenKey";
static NSString * MMViewControllerVisibleViewControllerKey = @"MMViewControllerVisibleViewControllerKey";

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    NSArray *childViewControllers = self.viewControllers;
    NSMutableArray *restoringViewControllers = [NSMutableArray arrayWithCapacity:childViewControllers.count];
    
    for (UIViewController *viewController in childViewControllers) {
        if (!viewController.restorationIdentifier) {
            continue;
        }
        
        [restoringViewControllers addObject:viewController];
    }
    
    if (restoringViewControllers.count > 0) {
        UIViewController *firstVisibleViewController = self.visibleViewControllers.firstObject;
        
        // Ignore snapshot if the visible view controller is not participating in restoration.
        if (!firstVisibleViewController.restorationIdentifier) {
            [[UIApplication sharedApplication] ignoreSnapshotOnNextApplicationLaunch];
        } else {
            [coder encodeObject:firstVisibleViewController forKey:MMViewControllerVisibleViewControllerKey];
        }
        
        // Encode restoring view controllers.
        [coder encodeObject:restoringViewControllers forKey:MMViewControllerChildrenKey];
    }
    
    [super encodeRestorableStateWithCoder:coder];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    NSArray *restoredViewControllers = [coder decodeObjectForKey:MMViewControllerChildrenKey];
    UIViewController *selectedViewController = [coder decodeObjectForKey:MMViewControllerVisibleViewControllerKey];
    
    if (restoredViewControllers && selectedViewController) {
        [self scrollToViewController:selectedViewController animated:NO];
    }
    
    [super decodeRestorableStateWithCoder:coder];
}

@end

@implementation MMSnapSupplementaryView

- (UIViewController *)previousViewController
{
    __strong MMSnapController *snapController = self.snapController;
    if (snapController) {
        NSArray *viewControllers = snapController.viewControllers;
        NSUInteger idx = [viewControllers indexOfObject:self.viewController];
        if (idx != NSNotFound && idx - 1 < viewControllers.count) {
            return viewControllers[idx - 1];
        }
    }
    return nil;
}

- (void)snapControllerWillDisplayViewController
{
    
}

- (void)snapControllerWillSnapToViewController:(UIViewController *)viewController
{
    
}

- (void)willMoveToSnapController:(MMSnapController *)snapController
{
    
}

- (void)willMoveFromSnapController
{
    
}

- (void)didMoveToSnapController
{
    
}

- (void)snapControllerViewControllersDidChange
{
    
}

@end
