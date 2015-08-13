//
//  MMNavigationController.h
//  MMNavigationController
//
//  Created by Matías Martínez on 1/11/15.
//  Copyright (c) 2015 Matías Martínez. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MMNavigationController;

/**
 *  Defines the available presentations for the view controllers in the navigation controller.
 *
 *  @note View controllers are forced to @c MMViewControllerMetricsFullscreen in compact horizontal size class environments.
 */
typedef NS_ENUM(NSUInteger, MMViewControllerMetrics) {
    /**
     *  The presented view controller is shown in conjuction with a view controller of large metrics
     *  as a master view.
     */
    MMViewControllerMetricsCompact,
    /**
     *  The presented view controller is shown in conjuction with a view controller of compact metrics
     *  as a detail view.
     *
     *  @note On portrait mode, the view controller covers the screen.
     */
    MMViewControllerMetricsLarge,
    /**
     *  The presented view controller covers the screen.
     */
    MMViewControllerMetricsFullscreen,
    /**
     *  The default presentation metrics.
     */
    MMViewControllerMetricsDefault = MMViewControllerMetricsCompact,
};

/**
 *  Defines the available scroll modes for the navigation controller interface.
 */
typedef NS_ENUM(NSUInteger, MMNavigationScrollMode){
    /**
     *  The scrolling stops on multiples of the view's bounds.
     */
    MMNavigationScrollModePaging,
    /**
     *  The scrolling stops on the nearest snap point.
     */
    MMNavigationScrollModeNearestSnapPoint
};

/**
 *  Defines the view controller metrics used by the navigation controller and provides a set of notifications when
 *  views become visible.
 */
@protocol MMNavigationControllerDelegate <NSObject>
@optional

/**
 *  Returns the supported metrics by a certain view controller, as determined by the delegate.
 *
 *  @param nc             The navigation controller.
 *  @param viewController The view controller located in the navigation controller.
 *
 *  @return The determined view controller metrics.
 */
- (MMViewControllerMetrics)navigationController:(MMNavigationController *)nc metricsForViewController:(UIViewController *)viewController;

/**
 *  The navigation controller calls this method before changing its @c scrollMode property. Use the provided coordinator object 
 *  to animate any changes you make.
 *
 *  @param nc          The navigation controller.
 *  @param scrollMode  The scroll mode applied to the navigation interface.
 *  @param coordinator The transition coordinator object managing the change. You can use this object to animate any changes or
 *                     to get information about the transition that is in progress.
 *
 *  @note This method is called in response to a trait collection change.
 *
 */
- (void)navigationController:(MMNavigationController *)nc willTransitionToScrollMode:(MMNavigationScrollMode)scrollMode transitionCoordinator:(id <UIViewControllerTransitionCoordinatorContext>)coordinator;

/**
 *  Called just before the navigation controller displays a view controller's view.
 *
 *  @param nc             The navigation controller.
 *  @param viewController The view controller being displayed.
 */
- (void)navigationController:(MMNavigationController *)nc willDisplayViewController:(UIViewController *)viewController;

/**
 *  Called after the navigation controller removes a view controller's view.
 *
 *  @param nc             The navigation controller.
 *  @param viewController The view controller being hidden.
 */
- (void)navigationController:(MMNavigationController *)nc didEndDisplayingViewController:(UIViewController *)viewController;

/**
 *  Called just before a view controller is snapped in the navigation interface.
 *
 *  @param nc             The navigation controller.
 *  @param viewController The view controller being snapped.
 */
- (void)navigationController:(MMNavigationController *)nc willSnapToViewController:(UIViewController *)viewController;

/**
 *  Called after the navigation controller has snapped a view controller in the navigation interface.
 *
 *  @param nc             The navigation controller.
 *  @param viewController The view controller that was snapped.
 */
- (void)navigationController:(MMNavigationController *)nc didSnapToViewController:(UIViewController *)viewController;

@end

@interface MMNavigationController : UIViewController

/**
 *  Initializes and returns a newly created navigation controller that uses your custom bar subclasses.
 *
 *  @param headerViewClass A @c MMNavigationSupplementaryView subclass or nil to use the default header class.
 *  @param footerViewClass A @c MMNavigationSupplementaryView subclass or nil to use the default footer class.
 *
 *  @return The initialized navigation controller object or nil if there was a problem initializing the object.
 */
- (instancetype)initWithHeaderViewClass:(Class)headerViewClass footerViewClass:(Class)footerViewClass;

/**
 *  Initializes and returns a newly created navigation controller.
 *
 *  @param viewController The view controller that resides at the bottom of the navigation stack.
 *
 *  @return The initialized navigation controller object or nil if there was a problem initializing the object.
 */
- (instancetype)initWithRootViewController:(UIViewController *)viewController;

/**
 *  Initializes and returns a newly created navigation controller.
 *
 *  @param viewControllers An array of view controllers.
 *
 *  @return The initialized navigation controller object or nil if there was a problem initializing the object.
 */
- (instancetype)initWithViewControllers:(NSArray *)viewControllers;

/**
 *  The view controllers currently on the navigation stack.
 */
@property (copy, nonatomic) NSArray *viewControllers;

/**
 *  The view controllers currently visible on the interface.
 */
@property (readonly, copy, nonatomic) NSArray *visibleViewControllers;

/**
 *  Returns if any, a view controller that's partially visible.
 *
 *  @note This property will always return @c nil when using the paging scroll mode.
 */
@property (readonly, nonatomic) UIViewController *partiallyVisibleViewController;

/**
 *  The delegate of the navigation controller object.
 */
@property (weak, nonatomic) id <MMNavigationControllerDelegate> delegate;

/**
 *  The current scroll mode for the navigation interface.
 */
@property (readonly, nonatomic) MMNavigationScrollMode scrollMode;

/**
 *  Scrolls the navigation interface to the specified view controller.
 *
 *  @param viewController A view controller part of the navigation stack.
 *  @param animated       Specify @c YES if you want to animate the scrolling.
 */
- (void)scrollToViewController:(UIViewController *)viewController animated:(BOOL)animated;

/**
 *  Pushes a view controller into the navigation stack.
 *
 *  @param viewController The view controller that's being pushed.
 *  @param animated       Specify @c YES if you want to animate the transition.
 */
- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated;

/**
 *  Pops the top view controller from the navigation stack.
 *
 *  @param animated Specify @c YES if you want to animate the transition.
 *
 *  @return The view controller that was popped from the stack or nil.
 */
- (UIViewController *)popViewControllerAnimated:(BOOL)animated;

/**
 *  Pops view controllers until the specified view controller is at the top of the navigation stack.
 *
 *  @param viewController The view controller that you want to be at the top of the stack. This view controller must currently be on the navigation stack.
 *  @param animated       Specify @c YES if you want to animate the transition.
 *
 *  @return An array containing the view controllers that were popped from the stack.
 */
- (NSArray *)popToViewController:(UIViewController *)viewController animated:(BOOL)animated;

/**
 *  Pops all the view controllers on the stack except the root view controller.
 *
 *  @param animated Specify @c YES if you want to animate the transition.
 *
 *  @return An array containing the view controllers that were popped from the stack.
 */
- (NSArray *)popToRootViewControllerAnimated:(BOOL)animated;

/**
 *  Returns a header view located by its view controller.
 *
 *  @param viewController A view controller identifying the header view.
 *
 *  @return A header view instance.
 *
 *  @note Use this method to instance a header view object and append it to your view controller's view hierarchy. Subsecuent calls to this
 *  method will return the previously instantiated header view as long as the view controller is part of the navigation stack.
 */
- (id)headerViewForViewController:(UIViewController *)viewController;

/**
 *  Returns a footer view located by its view controller.
 *
 *  @param viewController A view controller identifying the footer view.
 *
 *  @return A header view instance.
 *
 *  @note Use this method to instance a footer view object and append it to your view controller's view hierarchy. Subsecuent calls to this
 *  method will return the previously instantiated header view as long as the view controller is part of the navigation stack.
 */
- (id)footerViewForViewController:(UIViewController *)viewController;

@end

@interface MMNavigationSupplementaryView : UIView

/**
 *  Called just before the navigation controller displays the view controller's view associated to this supplementary view.
 */
- (void)navigationControllerWillDisplayViewController;

/**
 *  Called just before a view controller will be snapped in the navigation interface.
 *
 *  @param viewController The view controller that will be snapped.
 */
- (void)navigationControllerWillSnapToViewController:(UIViewController *)viewController;

/**
 *  Called just before the supplementary view is removed from the navigation controller.
 */
- (void)willMoveFromNavigationController;

/**
 *  Called after the supplementary view is added to the navigation controller.
 */
- (void)didMoveToNavigationController;

/**
 *  Called after the navigation controller has updated its navigation stack.
 */
- (void)navigationControllerViewControllersDidChange;

/**
 *  The navigation controller of the recipient.
 */
@property (weak, nonatomic, readonly) MMNavigationController *navigationController;

/**
 *  The view controller associated to the recipient.
 */
@property (weak, readonly, nonatomic) UIViewController *viewController;

/**
 *  A convenience method that returns the previous view controller in the navigation stack.
 */
@property (readonly, nonatomic) UIViewController *previousViewController;

@end
