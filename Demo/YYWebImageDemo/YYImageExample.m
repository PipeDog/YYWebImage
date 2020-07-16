//
//  YYImageExample.m
//  YYKitExample
//
//  Created by ibireme on 15/7/18.
//  Copyright (c) 2015 ibireme. All rights reserved.
//

#import "YYImageExample.h"
#import "YYImage.h"
#import "UIView+YYAdd.h"
#import <ImageIO/ImageIO.h>
#import <WebP/demux.h>
#import "UIImageView+YYWebImage.h"

@interface YYImageExample()
@property (nonatomic, strong) NSMutableArray *titles;
@property (nonatomic, strong) NSMutableArray *classNames;
@property (nonatomic, strong) UIImageView *imageView;
@end

@implementation YYImageExample

- (void)viewDidLoad {
    self.title = @"Demo";
    [super viewDidLoad];
    self.titles = @[].mutableCopy;
    self.classNames = @[].mutableCopy;
    [self addCell:@"Animated Image" class:@"YYImageDisplayExample"];
    [self addCell:@"Progressive Image" class:@"YYImageProgressiveExample"];
    [self addCell:@"Web Image" class:@"YYWebImageExample"];
    //[self addCell:@"Benchmark" class:@"YYImageBenchmark"];
    [self.tableView reloadData];
    
    self.imageView = [[UIImageView alloc] initWithFrame:CGRectMake(20, 100, 200, 200)];
    self.imageView.backgroundColor = [UIColor redColor];
    [self.view addSubview:self.imageView];

//    NSURL *URL = [NSURL URLWithString:@"https://timgsa.baidu.com/timg?image&quality=80&size=b9999_10000&sec=1594901825139&di=b73c610834744d8b18f56eece54d7a03&imgtype=0&src=http%3A%2F%2Fa3.att.hudong.com%2F20%2F56%2F19300001056606131348564606754.jpg"];
    NSURL *URL = [NSURL URLWithString:@"https://timgsa.baidu.com/timg?image&quality=80&size=b9999_10000&sec=1594902015963&di=5c726a371dd08c01bcf13a2521fdda81&imgtype=0&src=http%3A%2F%2Fb-ssl.duitang.com%2Fuploads%2Fblog%2F201402%2F14%2F20140214125747_EfjVP.thumb.700_0.gif"];
    [self.imageView yy_setImageWithURL:URL options:0];
}

- (void)addCell:(NSString *)title class:(NSString *)className {
    [self.titles addObject:title];
    [self.classNames addObject:className];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _titles.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"YY"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"YY"];
    }
    cell.textLabel.text = _titles[indexPath.row];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *className = self.classNames[indexPath.row];
    Class class = NSClassFromString(className);
    if (class) {
        UIViewController *ctrl = class.new;
        ctrl.title = _titles[indexPath.row];
        [self.navigationController pushViewController:ctrl animated:YES];
    }
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
