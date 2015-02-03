//
//  ViewController.m
//  MMNavigationController
//
//  Created by Matías Martínez on 1/11/15.
//  Copyright (c) 2015 Matías Martínez. All rights reserved.
//

#import "ViewController.h"
#import "MMNavigationHeaderView.h"

@interface ViewController ()

@property (strong, nonatomic) MMNavigationHeaderView *headerView;

@end

@interface Mesh : UIView

@end

@implementation ViewController

- (void)setColor:(UIColor *)color
{
    _color = color;
    
    if (self.isViewLoaded) {
        [self.view setBackgroundColor:color];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Nav bar.
    MMNavigationHeaderView *headerView = (id)[(id)self.parentViewController headerViewForViewController:self];
    headerView.tintColor = self.color;
    headerView.title = @"View";
    headerView.rightButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
    headerView.backgroundView.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.6f];
    headerView.separatorColor = [UIColor colorWithWhite:0.0f alpha:0.5f];
    headerView.titleTextAttributes = @{ NSForegroundColorAttributeName : [UIColor whiteColor] };
    
    self.headerView = headerView;
    
    [self.view addSubview:headerView];
    
    self.view.backgroundColor = self.color;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    CGRect bounds = self.view.bounds;
    CGRect headerRect = (CGRect){
        .origin.y = self.parentViewController.topLayoutGuide.length,
        .size.width = CGRectGetWidth(bounds),
        .size.height = [self.headerView sizeThatFits:bounds.size].height,
    };
    
    self.headerView.frame = headerRect;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (void)thingTouchUpInside:(id)sender
{
    ViewController *controllerCopy = [[ViewController alloc] init];
    controllerCopy.color = self.color;
    
    [self showViewController:controllerCopy sender:self];
}

- (void)loadView
{
    self.view = [Mesh new];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    NSLog(@"viewDidAppear:%@", animated ? @"YES" : @"NO");
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    NSLog(@"viewDidDisappear:%@", animated ? @"YES" : @"NO");
}

@end

@implementation Mesh

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

static inline void MMDrawLineInContext(CGContextRef ctx, CGPoint a, CGPoint b){
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, a.x, a.y);
    CGPathAddLineToPoint(path, NULL, b.x, b.y);
    CGPathCloseSubpath(path);
    CGContextAddPath(ctx, path);
    CGContextStrokePath(ctx);
    CGPathRelease(path);
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    CGContextSetLineWidth(ctx, 1.0f);
    
    const CGRect bounds = self.bounds;
    
    static const NSInteger perX = 4;
    static const NSInteger perY = 8;
    
    const CGSize perSize = { rintf(CGRectGetWidth(bounds) / perX), rintf(CGRectGetHeight(bounds) / perY) };
    
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:0.0f alpha:0.05f].CGColor);
    
    for (NSInteger x = 1; x < perX; x++) {
        for (NSInteger y = 1; y < perY; y++) {
            MMDrawLineInContext(ctx, CGPointMake(0, perSize.height * y), CGPointMake(CGRectGetMaxX(bounds), perSize.height * y));
            MMDrawLineInContext(ctx, CGPointMake(perSize.width * x, 0), CGPointMake(perSize.width * x, CGRectGetMaxY(bounds)));
        }
    }
    
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:0.0f alpha:0.2f].CGColor);
    
    MMDrawLineInContext(ctx, CGPointZero, CGPointMake(CGRectGetMaxX(bounds), CGRectGetMaxY(bounds)));
    MMDrawLineInContext(ctx, CGPointMake(CGRectGetMaxX(bounds), 0), CGPointMake(CGRectGetMinX(bounds), CGRectGetMaxY(bounds)));
}

@end