//
//  ZJJCarouselView.m
//  ZJJCarouselViewExample
//
//  Created by libtinker on 2018/5/3.
//  Copyright © 2018年 libtinker. All rights reserved.
//

#import "TKCarouselView.h"

@interface NSTimer (UnretainCycle)
+ (NSTimer *)tk_ScheduledTimerWithTimeInterval:(NSTimeInterval)inerval
                                       repeats:(BOOL)repeats
                                         block:(void(^)(NSTimer *timer))block;
@end

@implementation NSTimer (UnretainCycle)

+ (NSTimer *)tk_ScheduledTimerWithTimeInterval:(NSTimeInterval)inerval
                                       repeats:(BOOL)repeats
                                         block:(void(^)(NSTimer *timer))block {
    return [NSTimer scheduledTimerWithTimeInterval:inerval target:self selector:@selector(blcokInvoke:) userInfo:[block copy] repeats:repeats];
}

+ (void)blcokInvoke:(NSTimer *)timer {
    void (^block)(NSTimer *timer) = timer.userInfo;
    if (block) block(timer);
}

@end

static const int imageViewCount = 3;

@implementation TKPageControl

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = NO;
        self.dotSpacing = 7.0;
        self.currentPageIndicatorTintColor = [UIColor colorWithRed:255/255.0 green:255/255.0 blue:255/255.0 alpha:1.0];
        self.pageIndicatorTintColor = [UIColor colorWithRed:255/255.0 green:255/255.0 blue:255/255.0 alpha:0.3];
        self.currentDotSize = CGSizeMake(7.0, 7.0);
        self.currentDotRadius = 3.5;
        self.otherDotSize = CGSizeMake(7.0, 7.0);
        self.otherDotRadius = 3.5;
        self.dotAlignmentType = DotAlignmentTypeCenter;
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat marginX = (_otherDotSize.width + _dotSpacing)*(self.numberOfPages-1)+_currentDotSize.width;
    if (self.dotAlignmentType == DotAlignmentTypeCenter) {
        marginX = (self.bounds.size.width - marginX)/2;
    }else if (self.dotAlignmentType == DotAlignmentTypeLeft){
        marginX = 0;
    }else if (self.dotAlignmentType == DotAlignmentTypeRight) {
        marginX = self.bounds.size.width - marginX;
    }
    for (NSUInteger subviewIndex = 0; subviewIndex < self.subviews.count; subviewIndex++) {
        UIView *subview = [self.subviews objectAtIndex:subviewIndex];
        if (subviewIndex == self.currentPage) {
            [subview setFrame:CGRectMake(marginX, subview.frame.origin.y, _currentDotSize.width, _currentDotSize.height)];
            subview.layer.cornerRadius  = _currentDotRadius;
            marginX = _currentDotSize.width + _dotSpacing + marginX;
        }else{
            [subview setFrame:CGRectMake(marginX, subview.frame.origin.y, _otherDotSize.width, _otherDotSize.height)];
            subview.layer.cornerRadius  = _otherDotRadius;
            marginX = _otherDotSize.width + _dotSpacing +marginX;
        }
    }
}

@end

@interface TKCarouselView() <UIScrollViewDelegate>
@property (nonatomic, strong) UIScrollView*scrollView;
@property (nonatomic, assign) NSUInteger imageCount;
@property (nonatomic, weak  ) NSTimer *timer;
@property (nonatomic, copy  ) TKItemAtIndexBlock itemAtIndexBlock;
@property (nonatomic, copy  ) void(^imageClickedBlock) (NSInteger index);
@property (nonatomic, assign) NSInteger currentPageIndex;//The subscript of the current screen
@property (nonatomic, assign) BOOL isMakeScrollViewScrollToIndex;

@end

@implementation TKCarouselView

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self configureDefaultParameters];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self configureDefaultParameters];
    }
    return self;
}

- (void)configureDefaultParameters {
    _autoScrollTimeInterval = 3.0;
    _autoScroll = YES;
    _imageCount = 0;
    _currentPageIndex = 0;
    _isNeedReloadFirstDidScrollCallBack = YES;
    _infiniteLoop = YES;

    for (int i = 0;i < imageViewCount; i++) {
        UIImageView *imageView = [[UIImageView alloc] init];
        imageView.userInteractionEnabled = YES;
        [self.scrollView addSubview:imageView];
    }
}

- (void)reloadImageCount:(NSUInteger)imageCount itemAtIndexBlock:(TKItemAtIndexBlock)itemAtIndexBlock imageClickedBlock:(void(^)(NSInteger index))imageClickedBlock {
    NSAssert(imageCount >= 0 && imageCount <100, @"The number of images is not safe");
    NSParameterAssert(itemAtIndexBlock);
    NSParameterAssert(imageClickedBlock);

    self.placeholderImageView.hidden = imageCount == 0 ? NO : YES;

    _imageCount = imageCount;
    _imageClickedBlock = imageClickedBlock;
    _itemAtIndexBlock = itemAtIndexBlock;

    self.scrollView.hidden = imageCount >0 ? NO : YES;
    self.scrollView.scrollEnabled = imageCount > 1 ? YES : NO ;

    self.pageControl.hidden = imageCount>1 ? NO : YES;
    self.pageControl.numberOfPages = imageCount;
    self.pageControl.currentPage = 0;

    [self setContent];
    [self startTimer];
    if (self.itemDidScrollOperationBlock && self.isNeedReloadFirstDidScrollCallBack) self.itemDidScrollOperationBlock(self.pageControl.currentPage);
    if (_delegate && [_delegate respondsToSelector:@selector(cycleScrollView:didScrollToIndex:)] && self.isNeedReloadFirstDidScrollCallBack) {
        [_delegate cycleScrollView:self didScrollToIndex:self.pageControl.currentPage];
    }

}

- (void)makeScrollViewScrollToIndex:(NSInteger)index {
    if (index >= _pageControl.numberOfPages) {
        return;
    }
    _isMakeScrollViewScrollToIndex = YES;
    [self startTimer];
    _pageControl.currentPage = index;
    [self updateDisplayContent];
    if (self.itemDidScrollOperationBlock) self.itemDidScrollOperationBlock(index);
    if (_delegate && [_delegate respondsToSelector:@selector(cycleScrollView:didScrollToIndex:)]) {
        [_delegate cycleScrollView:self didScrollToIndex:index];
    }
}

- (void)pageControlHidden:(BOOL)isHidden {
    self.pageControl.hidden = isHidden;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    _scrollView.frame = self.bounds;
    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;
    _scrollView.contentSize = CGSizeMake(width*imageViewCount, 0);

    for (int i=0; i<_scrollView.subviews.count; i++) {
        UIImageView *imageView = self.scrollView.subviews[i];
        imageView.frame = CGRectMake(i*width, 0, width, height);
    }

    //Show the middle image
    self.scrollView.contentOffset = CGPointMake(width, 0);
}


//Set display content
- (void)setContent {
    for (int i=0; i<self.scrollView.subviews.count; i++) {
        NSInteger index = _pageControl.currentPage;
        UIImageView *imageView = self.scrollView.subviews[i];
        if (i == 0) {
            index--;
        }else if (i == 2){
            index++;
        }
        if (index<0) {
            index = _pageControl.numberOfPages == 0 ? 0 : _pageControl.numberOfPages-1;
        }else if (index == _pageControl.numberOfPages) {
            index = 0;
        }
        imageView.tag = index;
        self.currentPageIndex = imageView.tag;
        if (self.itemAtIndexBlock) self.itemAtIndexBlock(imageView,index);
    }
}

- (void)updateDisplayContent {
    CGFloat width = self.bounds.size.width;
    [self setContent];
    self.scrollView.contentOffset = CGPointMake(width, 0);
}

//MARK:- UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {

    NSInteger page = 0;
    //To get the minimum offset
    CGFloat minDistance = MAXFLOAT;

    for (int i=0; i<self.scrollView.subviews.count; i++) {
        UIImageView *imageView = self.scrollView.subviews[i];
        CGFloat distance = 0;
        distance = ABS(imageView.frame.origin.x - scrollView.contentOffset.x);
        if (distance<minDistance) {
            minDistance = distance;
            page = imageView.tag;
        }
    }
    _pageControl.currentPage = page;
    self.currentPageIndex = page;

}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self stopTimer];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    [self startTimer];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {

    if (!_infiniteLoop && !_autoScroll) {
        if(self.currentPageIndex == 0) {
            if (self.itemDidScrollOperationBlock) self.itemDidScrollOperationBlock(self.pageControl.currentPage);
            if (_delegate && [_delegate respondsToSelector:@selector(cycleScrollView:didScrollToIndex:)]) {
                [_delegate cycleScrollView:self didScrollToIndex:self.pageControl.currentPage];
            }
            return;
        }

        if(self.currentPageIndex == self.pageControl.numberOfPages - 1) {
            if (self.itemDidScrollOperationBlock) self.itemDidScrollOperationBlock(self.pageControl.currentPage);
            if (_delegate && [_delegate respondsToSelector:@selector(cycleScrollView:didScrollToIndex:)]) {
                [_delegate cycleScrollView:self didScrollToIndex:self.pageControl.currentPage];
            }
            return;
        }
    }

    [self updateDisplayContent];
    if (self.itemDidScrollOperationBlock) self.itemDidScrollOperationBlock(self.pageControl.currentPage);
    if (_delegate && [_delegate respondsToSelector:@selector(cycleScrollView:didScrollToIndex:)]) {
        [_delegate cycleScrollView:self didScrollToIndex:self.pageControl.currentPage];
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {

    [self updateDisplayContent];
    if (self.itemDidScrollOperationBlock) self.itemDidScrollOperationBlock(self.pageControl.currentPage);
    if (_delegate && [_delegate respondsToSelector:@selector(cycleScrollView:didScrollToIndex:)]) {
        [_delegate cycleScrollView:self didScrollToIndex:self.pageControl.currentPage];
    }
}

//MARK:- The timer

- (void)startTimer {
    [self stopTimer];
    if (_autoScroll && _imageCount>1) {
        __weak TKCarouselView *weakSelf = self;
        NSTimer *timer = [NSTimer tk_ScheduledTimerWithTimeInterval:_autoScrollTimeInterval repeats:YES block:^(NSTimer *timer) {
            CGFloat width = weakSelf.bounds.size.width;
            [weakSelf.scrollView setContentOffset:CGPointMake(2 * width, 0) animated:YES];
        }];

        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
        self.timer = timer;
    }
}

- (void)stopTimer {
    if (_timer) {
        [self.timer invalidate];
        self.timer = nil;
    }
}

- (void)imageViewClicked {
    if (self.imageClickedBlock) self.imageClickedBlock(self.currentPageIndex);
    if (_delegate && [_delegate respondsToSelector:@selector(cycleScrollView:didSelectItemAtIndex:)]) {
        [_delegate cycleScrollView:self didSelectItemAtIndex:self.currentPageIndex];
    }
}

//MARK:- getter -

- (UIImageView *)placeholderImageView {
    if (!_placeholderImageView) {
        _placeholderImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height)];
        _placeholderImageView.backgroundColor = UIColor.lightGrayColor;
        _placeholderImageView.userInteractionEnabled = YES;
        [self addSubview:_placeholderImageView];
    }
    return _placeholderImageView;
}

- (UIScrollView *)scrollView {
    if (!_scrollView) {
        _scrollView = [[UIScrollView alloc] init];
        _scrollView.delegate = self;
        _scrollView.showsVerticalScrollIndicator = NO;
        _scrollView.showsHorizontalScrollIndicator = NO;
        _scrollView.pagingEnabled = YES;
        _scrollView.bounces = NO;
        [self insertSubview:_scrollView atIndex:0];
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(imageViewClicked)];
        [_scrollView addGestureRecognizer:tap];
    }
    return _scrollView;
}

- (TKPageControl *)pageControl {
    if (!_pageControl) {
        _pageControl = [[TKPageControl alloc] initWithFrame:CGRectMake(0, self.bounds.size.height - 20, self.frame.size.width, 20)];
        [self addSubview:_pageControl];
    }
    return _pageControl;
}

-(void)dealloc {
    [self stopTimer];
    NSLog(@"dealloc:%@",self.class);
}
@end
