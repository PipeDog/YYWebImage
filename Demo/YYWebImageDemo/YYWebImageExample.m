//
//  YYWebImageExample.m
//  YYKitExample
//
//  Created by ibireme on 15/7/19.
//  Copyright (c) 2015 ibireme. All rights reserved.
//

#import "YYWebImageExample.h"
#import "YYWebImage.h"
#import "UIView+YYAdd.h"
#import "CALayer+YYAdd.h"
#import "UIGestureRecognizer+YYAdd.h"

#define kCellHeight ceil((kScreenWidth) * 3.0 / 4.0)
#define kScreenWidth ((UIWindow *)[UIApplication sharedApplication].windows.firstObject).width

@interface YYWebImageExampleCell : UITableViewCell
@property (nonatomic, strong) YYAnimatedImageView *webImageView;
@property (nonatomic, strong) UIActivityIndicatorView *indicator;
@property (nonatomic, strong) CAShapeLayer *progressLayer;
@property (nonatomic, strong) UILabel *label;
@end

@implementation YYWebImageExampleCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    self.backgroundColor = [UIColor clearColor];
    self.contentView.backgroundColor = [UIColor clearColor];
    self.size = CGSizeMake(kScreenWidth, kCellHeight);
    self.contentView.size = self.size;
    _webImageView = [YYAnimatedImageView new];
    _webImageView.size = self.size;
    _webImageView.clipsToBounds = YES;
    _webImageView.contentMode = UIViewContentModeScaleAspectFill;
    _webImageView.backgroundColor = [UIColor whiteColor];
    [self.contentView addSubview:_webImageView];
    
    _indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    _indicator.center = CGPointMake(self.width / 2, self.height / 2);
    _indicator.hidden = YES;
    //[self.contentView addSubview:_indicator]; //use progress bar instead..
    
    _label = [UILabel new];
    _label.size = self.size;
    _label.textAlignment = NSTextAlignmentCenter;
    _label.text = @"Load fail, tap to reload.";
    _label.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    _label.hidden = YES;
    _label.userInteractionEnabled = YES;
    [self.contentView addSubview:_label];
    
    CGFloat lineHeight = 4;
    _progressLayer = [CAShapeLayer layer];
    _progressLayer.size = CGSizeMake(_webImageView.width, lineHeight);
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(0, _progressLayer.height / 2)];
    [path addLineToPoint:CGPointMake(_webImageView.width, _progressLayer.height / 2)];
    _progressLayer.lineWidth = lineHeight;
    _progressLayer.path = path.CGPath;
    _progressLayer.strokeColor = [UIColor colorWithRed:0.000 green:0.640 blue:1.000 alpha:0.720].CGColor;
    _progressLayer.lineCap = kCALineCapButt;
    _progressLayer.strokeStart = 0;
    _progressLayer.strokeEnd = 0;
    [_webImageView.layer addSublayer:_progressLayer];
    
    __weak typeof(self) _self = self;
    UITapGestureRecognizer *g = [[UITapGestureRecognizer alloc] initWithActionBlock:^(id sender) {
        [_self setImageURL:_self.webImageView.yy_imageURL];
    }];
    [_label addGestureRecognizer:g];
    
    return self;
}

- (void)setImageURL:(NSURL *)url {
    _label.hidden = YES;
    _indicator.hidden = NO;
    [_indicator startAnimating];
    __weak typeof(self) _self = self;
    
    [CATransaction begin];
    [CATransaction setDisableActions: YES];
    self.progressLayer.hidden = YES;
    self.progressLayer.strokeEnd = 0;
    [CATransaction commit];

    [_webImageView yy_setImageWithURL:url
                          placeholder:nil
                          options:YYWebImageOptionProgressiveBlur | YYWebImageOptionShowNetworkActivity | YYWebImageOptionSetImageWithFadeAnimation
                          progress:^(NSInteger receivedSize, NSInteger expectedSize) {
                              if (expectedSize > 0 && receivedSize > 0) {
                                  CGFloat progress = (CGFloat)receivedSize / expectedSize;
                                  progress = progress < 0 ? 0 : progress > 1 ? 1 : progress;
                                  if (_self.progressLayer.hidden) _self.progressLayer.hidden = NO;
                                  _self.progressLayer.strokeEnd = progress;
                              }
                          }
                          transform:nil
                          completion:^(UIImage *image, NSURL *url, YYWebImageFromType from, YYWebImageStage stage, NSError *error) {
                              if (stage == YYWebImageStageFinished) {
                                  _self.progressLayer.hidden = YES;
                                  [_self.indicator stopAnimating];
                                  _self.indicator.hidden = YES;
                                  if (!image) _self.label.hidden = NO;
                              }
                         }];
}

- (void)prepareForReuse {
    //nothing
}

@end


@implementation YYWebImageExample {
    NSArray *_imageLinks;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.view.backgroundColor = [UIColor whiteColor];
    
    UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithTitle:@"Reload" style:UIBarButtonItemStylePlain target:self action:@selector(reload)];
    self.navigationItem.rightBarButtonItem = button;
    self.view.backgroundColor = [UIColor colorWithWhite:0.217 alpha:1.000];
    
    NSArray *links = @[
        /*
         You can add your image url here.
         */
        
        // gif
        @"https://timgsa.baidu.com/timg?image&quality=80&size=b9999_10000&sec=1594903992732&di=d15bd46ce87ac0fbee7e0c50efd7c9fa&imgtype=0&src=http%3A%2F%2Ffiles.focusky.com.cn%2Fweb%2Fimages%2Ffeatures%2F05.gif",
        @"https://timgsa.baidu.com/timg?image&quality=80&size=b9999_10000&sec=1594904085133&di=2cf74309450aae5732bb5842341d1244&imgtype=0&src=http%3A%2F%2Fimg.mp.itc.cn%2Fupload%2F20170303%2F6e1f0bfbbcd146eb8349b4b0ba387ec6.gif",
        
        // jpg
        @"https://timgsa.baidu.com/timg?image&quality=80&size=b9999_10000&sec=1594905340110&di=f26a2583cda7ad94d5bece762de412c3&imgtype=0&src=http%3A%2F%2Fimg3.100bt.com%2Fupload%2Fttq%2F20130414%2F1365909046798.jpg",
        @"https://timgsa.baidu.com/timg?image&quality=80&size=b9999_10000&sec=1594902709421&di=5b34339823b914769863d49fe813eda4&imgtype=0&src=http%3A%2F%2Fimage.biaobaiju.com%2Fuploads%2F20180830%2F22%2F1535637647-sSIBadeLyg.jpeg",
        @"https://timgsa.baidu.com/timg?image&quality=80&size=b9999_10000&sec=1594903917873&di=46983fec1a6842eaf9f30a89e6436e42&imgtype=0&src=http%3A%2F%2Fimg4.imgtn.bdimg.com%2Fit%2Fu%3D1520821609%2C4097703303%26fm%3D214%26gp%3D0.jpg",
        
        
        // webp
        @"http://littlesvr.ca/apng/images/Contact.webp",
    ];
    
    _imageLinks = links;
    [self.tableView reloadData];
    [self scrollViewDidScroll:self.tableView];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleLightContent;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.navigationController.navigationBar.barStyle = UIBarStyleDefault;
    self.navigationController.navigationBar.tintColor = nil;
    [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleDefault;
}

- (void)reload {
    [[YYImageCache sharedCache].memoryCache removeAllObjects];
    [[YYImageCache sharedCache].diskCache removeAllObjectsWithBlock:^{}];
    [self.tableView performSelector:@selector(reloadData) withObject:nil afterDelay:0.1];
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _imageLinks.count * 4;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return kCellHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    YYWebImageExampleCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) cell = [[YYWebImageExampleCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    [cell setImageURL:[NSURL URLWithString:_imageLinks[indexPath.row % _imageLinks.count]]];
    return cell;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat viewHeight = scrollView.height + scrollView.contentInset.top;
    for (YYWebImageExampleCell *cell in [self.tableView visibleCells]) {
        CGFloat y = cell.centerY - scrollView.contentOffset.y;
        CGFloat p = y - viewHeight / 2;
        CGFloat scale = cos(p / viewHeight * 0.8) * 0.95;
        [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState animations:^{
            cell.webImageView.transform = CGAffineTransformMakeScale(scale, scale);
        } completion:NULL];
    }
}

@end
