//
//  MMSnapController.h
//  MMSnapController
//
//  Created by Matías Martínez on 1/11/15.
//  Copyright (c) 2015 Matías Martínez. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MMSnapController;

/**
 *  Defines the available presentations for the view controllers in the snap controller.
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
 *  Defines the available scroll modes for the snap controller interface.
 */
typedef NS_ENUM(NSUInteger, MMSnapScrollMode){
    /**
     *  The scrolling stops on multiples of the view's bounds.
     */
    MMSnapScrollModePaging,
    /**
     *  The scrolling stops on the nearest snap point.
     */
    MMSnapScrollModeNearestSnapPoint
};

/**
 *  Defines the view controller metrics used by the snap controller and provides a set of notifications when
 *  views become visible.
 */
@protocol MMSnapControllerDelegate <NSObject>
@optional

/**
 *  Returns the supported metrics by a certain view controller, as determined by the delegate.
 *
 *  @param snapController The snap controller.
 *  @param viewController The view controller located in the snap controller.
 *
 *  @return The determined view controller metrics.
 */
- (MMViewControllerMetrics)snapController:(MMSnapController *)snapController metricsForViewController:(UIViewController *)viewController;

/**
 *  The snap controller calls this method before changing its @c scrollMode property. Use the provided coordinator object 
 *  to animate any changes you make.
 *
 *  @param snapController The snap controller.
 *  @param scrollMode     The scroll mode applied to the interface.
 *  @param coordinator    The transition coordinator object managing the change. You can use this object to animate any changes or
 *                        to get information about the transition that is in progress.
 *
 *  @note This method is called in response to a trait collection change.
 *
 */
- (void)snapController:(MMSnapController *)snapController willTransitionToScrollMode:(MMSnapScrollMode)scrollMode transitionCoordinator:(id <UIViewControllerTransitionCoordinatorContext>)coordinator;

/**
 *  Called just before the snap controller displays a view controller's view.
 *
 *  @param snapController The snap controller.
 *  @param viewController The view controller being displayed.
 */
- (void)snapController:(MMSnapController *)snapController willDisplayViewController:(UIViewController *)viewController;

/**
 *  Called after the snap controller removes a view controller's view.
 *
 *  @param snapController The snap controller.
 *  @param viewController The view controller being hidden.
 */
- (void)snapController:(MMSnapController *)snapController didEndDisplayingViewController:(UIViewController *)viewController;

/**
 *  Called just before a view controller is snapped in the interface.
 *
 *  @param snapController The snap controller.
 *  @param viewController The view controller being snapped.
 */
- (void)snapController:(MMSnapController *)snapController willSnapToViewController:(UIViewController *)viewController;

/**
 *  Called after the snap controller has snapped a view controller in the interface.
 *
 *  @param snapController The snap controller.
 *  @param viewController The view controller that was snapped.
 */
- (void)snapController:(MMSnapController *)snapController didSnapToViewController:(UIViewController *)viewController;

@end

@interface MMSnapController : UIViewController

/**
 *  Initializes and returns a newly created snap controller that uses your custom bar subclasses.
 *
 *  @param headerViewClass A @c MMSnapSupplementaryView subclass or nil to use the default header class.
 *  @param footerViewClass A @c MMSnapSupplementaryView subclass or nil to use the default footer class.
 *
 *  @return The initialized snap controller object or nil if there was a problem initializing the object.
 */
- (instancetype)initWithHeaderViewClass:(Class)headerViewClass footerViewClass:(Class)footerViewClass;

/**
 *  Initializes and returns a newly created snap controller.
 *
 *  @param viewController The view controller that resides at the bottom of the view controller stack.
 *
 *  @return The initialized snap controller object or nil if there was a problem initializing the object.
 */
- (instancetype)initWithRootViewController:(UIViewController *)viewController;

/**
 *  Initializes and returns a newly created snap controller.
 *
 *  @param viewControllers An array of view controllers.
 *
 *  @return The initialized snap controller object or nil if there was a problem initializing the object.
 */
- (instancetype)initWithViewControllers:(NSArray <__kindof UIViewController *> *)viewControllers;

/**
 *  The view controllers currently on the view controller stack.
 */
@property (copy, nonatomic) NSArray <__kindof UIViewController *> *viewControllers;

/**
 *  The view controllers currently visible on the interface.
 */
@property (readonly, copy, nonatomic) NSArray <__kindof UIViewController *> *visibleViewControllers;

/**
 *  Returns if any, a view controller that's partially visible.
 *
 *  @note This property will always return @c nil when using the paging scroll mode.
 */
@property (readonly, nonatomic) UIViewController *partiallyVisibleViewController;

/**
 *  The delegate of the snap controller object.
 */
@property (weak, nonatomic) id <MMSnapControllerDelegate> delegate;

/**
 *  The current scroll mode for the interface.
 */
@property (readonly, nonatomic) MMSnapScrollMode scrollMode;

/**
 *  Scrolls the interface to the specified view controller.
 *
 *  @param viewController A view controller part of the view controller stack.
 *  @param animated       Specify @c YES if you want to animate the scrolling.
 */
- (void)scrollToViewController:(UIViewController *)viewController animated:(BOOL)animated;

/**
 *  Pushes a view controller into the view controller stack.
 *
 *  @param viewController The view controller that's being pushed.
 *  @param animated       Specify @c YES if you want to animate the transition.
 */
- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated;

/**
 *  Pops the top view controller from the stack.
 *
 *  @param animated Specify @c YES if you want to animate the transition.
 *
 *  @return The view controller that was popped from the stack or nil.
 */
- (UIViewController *)popViewControllerAnimated:(BOOL)animated;

/**
 *  Pops view controllers until the specified view controller is at the top of the stack.
 *
 *  @param viewController The view controller that you want to be at the top of the stack. This view controller must currently be on the stack.
 *  @param animated       Specify @c YES if you want to animate the transition.
 *
 *  @return An array containing the view controllers that were popped from the stack.
 */
- (NSArray <__kindof UIViewController *> *)popToViewController:(UIViewController *)viewController animated:(BOOL)animated;

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
 *  method will return the previously instantiated header view as long as the view controller is part of the stack.
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
 *  method will return the previously instantiated header view as long as the view controller is part of the stack.
 */
- (id)footerViewForViewController:(UIViewController *)viewController;

@end

@interface MMSnapSupplementaryView : UIView

/**
 *  Called just before the snap controller displays the view controller's view associated to this supplementary view.
 */
- (void)snapControllerWillDisplayViewController;

/**
 *  Called just before a view controller will be snapped in the interface.
 *
 *  @param viewController The view controller that will be snapped.
 */
- (void)snapControllerWillSnapToViewController:(UIViewController *)viewController;

/**
 *  Called just before the supplementary view is removed from the snap controller.
 */
- (void)willMoveFromSnapController;

/**
 *  Called after the supplementary view is added to the snap controller.
 */
- (void)didMoveToSnapController;

/**
 *  Called after the snap controller has updated its stack.
 */
- (void)snapControllerViewControllersDidChange;

/**
 *  The snap controller of the recipient.
 */
@property (weak, nonatomic, readonly) MMSnapController *snapController;

/**
 *  The view controller associated to the recipient.
 */
@property (weak, readonly, nonatomic) UIViewController *viewController;

/**
 *  A convenience method that returns the previous view controller in the stack.
 */
@property (readonly, nonatomic) UIViewController *previousViewController;

@end
