//
//  MMNavigationController.m
//  MMNavigationController
//
//  Created by Matías Martínez on 1/11/15.
//  Copyright (c) 2015 Matías Martínez. All rights reserved.
//

#import "MMNavigationController.h"
#import "MMSnapScrollView.h"
#import "MMNavigationHeaderView.h"
#import "MMNavigationFooterView.h"

@interface MMNavigationController () <MMSnapScrollViewDataSource, MMSnapScrollViewDelegate>
{
    struct {
        unsigned int delegateWillDisplayViewController : 1;
        unsigned int delegateDidEndDisplayingViewController : 1;
        unsigned int delegateCustomWidthForViewController : 1;
        unsigned int delegateWillSnapViewController : 1;
        unsigned int delegateDidSnapViewController : 1;
    } _delegateFlags;
}

@property (readonly, nonatomic) MMSnapScrollView *scrollView;

@property (strong, nonatomic) NSMutableArray *headerFooterViewArray;
@property (strong, nonatomic) Class headerViewClass;
@property (strong, nonatomic) Class footerViewClass;

@end

typedef NS_ENUM(NSUInteger, MMNavigationViewType) {
    MMNavigationViewTypeHeader,
    MMNavigationViewTypeFooter
};

@interface MMNavigationSupplementaryView ()

@property (assign, nonatomic, setter=_setViewType:) MMNavigationViewType _viewType;
@property (weak, nonatomic, readwrite) UIViewController *viewController;
@property (weak, nonatomic, readwrite) MMNavigationController *navigationController;

@end

@implementation MMNavigationController

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
    
    for (UIViewController *vc in _viewControllers) {
        [vc willMoveToParentViewController:nil];
        [vc removeFromParentViewController];
    }
    
    [self _removeSupplementaryViewsForViewControllers:_viewControllers];
    
    _viewControllers = viewControllers;
    
    BOOL isViewLoaded = self.isViewLoaded;
    
    for (UIViewController *vc in viewControllers) {
        [self addChildViewController:vc];
    }
    
    if (isViewLoaded) {
        [self.scrollView reloadData];
        [self _notifyViewControllersDidChange];
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

- (void)setDelegate:(id<MMNavigationControllerDelegate>)delegate
{
    if (delegate == _delegate) {
        return;
    }
    
    _delegate = delegate;
    
    _delegateFlags.delegateCustomWidthForViewController = [delegate respondsToSelector:@selector(navigationController:metricsForViewController:)];
    _delegateFlags.delegateDidEndDisplayingViewController = [delegate respondsToSelector:@selector(navigationController:didEndDisplayingViewController:)];
    _delegateFlags.delegateWillDisplayViewController = [delegate respondsToSelector:@selector(navigationController:willDisplayViewController:)];
    _delegateFlags.delegateWillSnapViewController = [delegate respondsToSelector:@selector(navigationController:willSnapToViewController:)];
    _delegateFlags.delegateDidSnapViewController = [delegate respondsToSelector:@selector(navigationController:didSnapToViewController:)];
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
    BOOL horizontallyCompact = traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassCompact;
    BOOL pagingEnabled = horizontallyCompact;
    
    if (pagingEnabled != self.scrollView.isPagingEnabled) {
        [self.scrollView setPagingEnabled:pagingEnabled];
        [self.scrollView invalidateLayout];
    }
}

- (void)willTransitionToTraitCollection:(UITraitCollection *)newCollection withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super willTransitionToTraitCollection:newCollection withTransitionCoordinator:coordinator];
    [self _configureScrollViewWithTraitCollection:newCollection];
}

#pragma mark - Snap scroll view data source.

- (CGFloat)scrollView:(MMSnapScrollView *)scrollView widthForViewAtPage:(NSInteger)page
{
    const CGRect bounds = self.view.bounds;
    
    if (_delegateFlags.delegateCustomWidthForViewController) {
        UIViewController *viewController = self.viewControllers[page];
        
        const MMViewControllerMetrics metrics = [self.delegate navigationController:self metricsForViewController:viewController];
        
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
            
            const CGFloat compactWidth = userInterfaceIdiom == UIUserInterfaceIdiomPad ? 320.0f : 295.0f;
            
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
    return [self.viewControllers[page] view];
}

- (NSInteger)numberOfPagesInScrollView:(MMSnapScrollView *)scrollView
{
    return self.viewControllers.count;
}

#pragma mark - Snap scroll view delegate.

- (void)scrollView:(MMSnapScrollView *)scrollView willDisplayView:(UIView *)view atPage:(NSInteger)page
{
    UIViewController *viewController = self.viewControllers[page];
    if (viewController) {
        [viewController beginAppearanceTransition:YES animated:(scrollView.isDecelerating || scrollView.isTracking)];
        [viewController endAppearanceTransition];
        
        for (MMNavigationSupplementaryView *view in self.headerFooterViewArray) {
            if (view.viewController == viewController) {
                [view navigationControllerWillDisplayViewController];
                break;
            }
        }
        
        if (_delegateFlags.delegateWillDisplayViewController) {
            [self.delegate navigationController:self willDisplayViewController:viewController];
        }
    }
}

- (void)scrollView:(MMSnapScrollView *)scrollView didEndDisplayingView:(UIView *)view atPage:(NSInteger)page
{
    UIViewController *viewController = self.viewControllers[page];
    if (viewController) {
        [viewController beginAppearanceTransition:NO animated:(scrollView.isDecelerating || scrollView.isTracking)];
        [viewController endAppearanceTransition];
        
        if (_delegateFlags.delegateDidEndDisplayingViewController) {
            [self.delegate navigationController:self didEndDisplayingViewController:viewController];
        }
    }
}

- (void)scrollView:(MMSnapScrollView *)scrollView willSnapToView:(UIView *)view atPage:(NSInteger)page
{
    UIViewController *viewController = self.viewControllers[page];
    if (viewController) {
        if (_delegateFlags.delegateWillSnapViewController) {
            [self.delegate navigationController:self willSnapToViewController:viewController];
        }
        
        for (MMNavigationSupplementaryView *view in self.headerFooterViewArray) {
            [view navigationControllerWillSnapToViewController:viewController];
        }
    }
}

- (void)scrollView:(MMSnapScrollView *)scrollView didSnapToView:(UIView *)view atPage:(NSInteger)page
{
    UIViewController *viewController = self.viewControllers[page];
    if (_delegateFlags.delegateDidSnapViewController) {
        [self.delegate navigationController:self didSnapToViewController:viewController];
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
    return [self _supplementaryViewWithType:MMNavigationViewTypeHeader forViewForViewController:viewController];
}

- (UIView *)footerViewForViewController:(UIViewController *)viewController
{
    return [self _supplementaryViewWithType:MMNavigationViewTypeFooter forViewForViewController:viewController];
}

- (UIView *)_supplementaryViewWithType:(MMNavigationViewType)type forViewForViewController:(UIViewController *)viewController
{
    if (![self.viewControllers containsObject:viewController]) {
        return nil;
    }
    
    for (MMNavigationSupplementaryView *view in self.headerFooterViewArray) {
        if (view._viewType == type && view.viewController == viewController) {
            return view;
        }
    }
    
    Class viewClass;
    if (type == MMNavigationViewTypeHeader) {
        viewClass = self.headerViewClass ?: [MMNavigationHeaderView class];
    } else if (type == MMNavigationViewTypeFooter) {
        viewClass = self.footerViewClass ?: [MMNavigationFooterView class];
    }
    
    MMNavigationSupplementaryView *view = [[viewClass alloc] initWithFrame:CGRectZero];
    view.navigationController = self;
    view.viewController = viewController;
    view._viewType = type;
    
    [self.headerFooterViewArray addObject:view];
    
    return view;
}

- (void)_removeSupplementaryViewsForViewControllers:(NSArray *)viewControllers
{
    for (MMNavigationSupplementaryView *view in self.headerFooterViewArray.copy) {
        if ([viewControllers containsObject:view.viewController]) {
            [view setNavigationController:nil];
            [self.headerFooterViewArray removeObject:view];
        }
    }
}

- (void)_notifyViewControllersDidChange
{
    for (MMNavigationSupplementaryView *view in self.headerFooterViewArray.copy) {
        [view navigationControllerViewControllersDidChange];
    }
}

@end

@implementation MMNavigationSupplementaryView

- (UIViewController *)previousViewController
{
    __strong MMNavigationController *navigationController = self.navigationController;
    if (navigationController) {
        NSArray *viewControllers = navigationController.viewControllers;
        NSUInteger idx = [viewControllers indexOfObject:self.viewController];
        if (idx != NSNotFound && idx - 1 < viewControllers.count) {
            return viewControllers[idx - 1];
        }
    }
    return nil;
}

- (void)navigationControllerWillDisplayViewController
{
    
}

- (void)navigationControllerWillSnapToViewController:(UIViewController *)viewController
{
    
}

- (void)setNavigationController:(MMNavigationController *)navigationController
{
    if (navigationController != _navigationController) {
        [self willMoveToNavigationController:navigationController];
        
        _navigationController = navigationController;
        
        [self didMoveToNavigationController];
    }
}

- (void)willMoveToNavigationController:(MMNavigationController *)navigationController
{
    
}

- (void)didMoveToNavigationController
{
    
}

- (void)navigationControllerViewControllersDidChange
{
    
}

@end
