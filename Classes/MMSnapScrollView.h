//
//  MMSnapPagingScrollView.h
//  MMSnapController
//
//  Created by Matías Martínez on 1/11/15.
//  Copyright (c) 2015 Matías Martínez. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MMSnapScrollView;

/**
 *  A @c MMSnapScrollViewDataSource object is used to provide layout information and views in a @c MMSnapScrollView.
 */
@protocol MMSnapScrollViewDataSource <NSObject>
@required

/**
 *  Asks the data source to return the number of pages in the scroll view.
 *
 *  @param scrollView The scroll view requesting this information.
 *
 *  @return The number of pages in @c scrollView.
 */
- (NSInteger)numberOfPagesInScrollView:(MMSnapScrollView *)scrollView;

/**
 *  Asks the data source for the width to use for a page in a specified location.
 *
 *  @param scrollView The scroll view requesting this information.
 *  @param page       A page that locates a view in @c scrollView.
 *
 *  @return A nonnegative floating-point value that specifies the height (in points) that page should be.
 */
- (CGFloat)scrollView:(MMSnapScrollView *)scrollView widthForViewAtPage:(NSInteger)page;

/**
 *  Asks the data source for a view object to insert at a specified location of the scroll view.
 *
 *  @param scrollView The scroll view requesting this information.
 *  @param page       A page that locates the view in @c scrollView.
 *
 *  @return A view object to be used for the specified page. An assertion is raised if you return nil.
 */
- (UIView *)scrollView:(MMSnapScrollView *)scrollView viewAtPage:(NSInteger)page;

@end

/**
 *  A @c MMSnapScrollViewDelegate object can be used to track the views in a @c MMSnapScrollView, as well to use the inherited methods
 *  declared in the @c UIScrollViewDelegate protocol.
 */
@protocol MMSnapScrollViewDelegate <UIScrollViewDelegate>
@optional

/**
 *  Tells the delegate the scroll view is about to display a view for a particular page.
 *
 *  @param scrollView The scroll view.
 *  @param view       The view being displayed.
 *  @param page       A page that locates the view in @c scrollView.
 */
- (void)scrollView:(MMSnapScrollView *)scrollView willDisplayView:(UIView *)view atPage:(NSInteger)page;

/**
 *  Tells the delegate the scroll view is about to end displaying a view for a particular page.
 *
 *  @param scrollView The scroll view.
 *  @param view       The view about to end being displayed.
 *  @param page       A page that locates the view in @c scrollView.
 */
- (void)scrollView:(MMSnapScrollView *)scrollView didEndDisplayingView:(UIView *)view atPage:(NSInteger)page;

/**
 *  Tells the delegate the scroll view is about to snap to a view for a particular page.
 *
 *  @param scrollView The scroll view.
 *  @param view       The view being snapped.
 *  @param page       A page that locates the view in @c scrollView.
 */
- (void)scrollView:(MMSnapScrollView *)scrollView willSnapToView:(UIView *)view atPage:(NSInteger)page;

/**
 *  Tells the delegate the scroll view has finished snapping to a view for a particular page.
 *
 *  @param scrollView The scroll view.
 *  @param view       The view being snapped.
 *  @param page       A page that locates the view in @c scrollView.
 */
- (void)scrollView:(MMSnapScrollView *)scrollView didSnapToView:(UIView *)view atPage:(NSInteger)page;

@end

@interface MMSnapScrollView : UIScrollView

/**
 *  The delegate of the scroll view object.
 */
@property (weak, nonatomic) id <MMSnapScrollViewDelegate> delegate;

/**
 *  The data source of the scroll view object.
 */
@property (weak, nonatomic) id <MMSnapScrollViewDataSource> dataSource;

/**
 *  Reloads the pages of the receiver.
 *
 *  @note Call this method to reload all the data that is used to construct scroll view. For efficiency, the scroll view
 *  redisplays only those pages that are visible. It adjusts offsets if the scroll view shrinks as a result of the reload.
 */
- (void)reloadData;

/**
 *  Invalidates the layout information of the scroll view.
 *
 *  @note Call this method if you need to change the size of the pages in the scroll view. Data like the number of pages
 *  is not invalidated after calling this method. Use @c -reloadData instead.
 */
- (void)invalidateLayout;

/**
 *  Returns the number of pages for the receiver.
 *
 *  @note @c MMSnapScrollView gets the value returned by this method from its data source and caches it.
 */
@property (readonly, nonatomic) NSInteger numberOfPages;

/**
 *  Returns an index set of pages each identifying a visible view in the receiver.
 */
@property (readonly, nonatomic) NSIndexSet *pagesForVisibleViews;

/**
 *  Returns the views that are visible in the receiver.
 */
@property (readonly, nonatomic) NSArray *visibleViews;

/**
 *  An index set of pages each representing a view enclosed by a given rectangle.
 *
 *  @param rect A rectangle defining an area of the scroll view in local coordinates.
 *
 *  @return An index set of pages each representing a view within @c rect. Returns an empty index set if there aren’t any pages to return.
 */
- (NSIndexSet *)pagesForViewsInRect:(CGRect)rect;

/**
 *  Returns an index representing the page for a given view.
 *
 *  @param view A view object in the scroll view.
 *
 *  @return An index representing the page or @c NSNotFound if the index is invalid.
 */
- (NSInteger)pageForView:(UIView *)view;

/**
 *  Returns the view at the specified page.
 *
 *  @param page The page locating the view in the receiver.
 *
 *  @return A view object or @c nil if the page is not visible or the index is out of range.
 */
- (UIView *)viewAtPage:(NSInteger)page;

/**
 *  Scrolls the receiver until a view identified by page is at a particular location on the screen.
 *
 *  @param page     The page locating the view in the receiver.
 *  @param animated @c YES if you want to animate the change in position, @c NO if it should be immediate.
 */
- (void)scrollToPage:(NSInteger)page animated:(BOOL)animated;

/**
 *  Removes the views specified by an index set of pages, with an option to animate the deletion.
 *
 *  @param pages    An index set of pages identifying the views to remove.
 *  @param animated @c YES if you want to animate the deletion, @c NO if it should be immediate.
 */
- (void)deletePages:(NSIndexSet *)pages animated:(BOOL)animated;

/**
 *  Inserts views in the receiver at the locations identified by an index set of pages, with an option to animate the insertion.
 *
 *  @param pages    An index set of pages identifying the views to insert.
 *  @param animated @c YES if you want to animate the insertion, @c NO if it should be immediate.
 */
- (void)insertPages:(NSIndexSet *)pages animated:(BOOL)animated;

/**
 *  The class to use for displaying the separators in the scroll view.
 *
 *  @note The default value of this property is @c nil, which indicates that the scroll view should use the default separator appearance.
 *  Setting this property to a value other than @c nil causes the scroll view to use the specified class to draw the separators. The class
 *  you specify must conform to the @c MMSnapViewSeparatorView protocol.
 */
@property (strong, nonatomic) Class separatorViewClass;

/**
 *  Animates multiple insert and delete operations as a group.
 *
 *  @param updates    The block that performs the relevant insert or delete operations.
 *  @param completion A completion handler block to execute when all of the operations are finished. This block takes a single Boolean parameter that contains the value @c YES if all of the related animations completed successfully or @c NO if they were interrupted. This parameter may be @c nil.
 */
- (void)performBatchUpdates:(dispatch_block_t)updates completion:(void (^)(BOOL))completion;

@end

@protocol MMSnapViewSeparatorView <NSObject>

/**
 *  When the value of this property is set to @c YES, is determined that the separator is being shown in a column-like layout, between
 *  two views appearing simultaneously side-by-side.
 *
 *  @note Use this value to draw appropiate features to divide content. For example, the default separator appearance draws a thin
 *  vertical line when this property is set to @c YES.
 */
@property (nonatomic) BOOL showsAsColumnSeparator;

/**
 *  The amount of the disappear transition (specified as a percentage of the overall duration) that is complete.
 *
 *  @note Use this value to update your separator's drawing accordingly. For example, the default separator appearance draws a shadow
 *  and determines its opacity from the value of this property.
 */
@property (nonatomic) CGFloat percentDisappeared;

/**
 *  The width of the separator (measured in points).
 *
 *  @note Use this method to return the width of your separator. The separator height must be the same for all possible variations
 *  needed to draw its content and must not change.
 */
+ (CGFloat)separatorWidth;

@end
