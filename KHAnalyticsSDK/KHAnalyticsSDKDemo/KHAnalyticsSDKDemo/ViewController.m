//
//  ViewController.m
//  KHAnalyticsSDKDemo
//
//  Created by lcf on 2020/10/16.
//

#import "ViewController.h"
#import "SensorsDataReleaseObject.h"
#import <WebKit/WebKit.h>
#import "PresenVC.h"
#import <KHAnalyticsSDK/KHAnalyticsSDK.h>

#define kScreenWidht [UIScreen mainScreen].bounds.size.width

@interface ViewController ()
<
UITableViewDelegate,
UITableViewDataSource,
UICollectionViewDelegate,
UICollectionViewDataSource,
WKNavigationDelegate
>
@property (weak, nonatomic) IBOutlet UITableView *tableview;
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet UILabel *tapLabel;
@property (weak, nonatomic) IBOutlet UILabel *longTapLabel;
@property (strong, nonatomic)  WKWebView *webview;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view.
    self.tableview.delegate = self;
    self.tableview.dataSource = self;
    [self.tableview registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    
    UICollectionViewFlowLayout *flow = [[UICollectionViewFlowLayout alloc] init];
    flow.itemSize = CGSizeMake(kScreenWidht, 30);
    flow.minimumLineSpacing = 0.1;
    flow.minimumInteritemSpacing = 0.1;
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"celll"];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
    [self.tapLabel addGestureRecognizer:tap];
    
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
    [self.longTapLabel addGestureRecognizer:longPress];
    
    self.webview = [[WKWebView alloc] initWithFrame:CGRectMake(0, 500, kScreenWidht, 150)];
    [self.view addSubview:self.webview];
    NSURLRequest *requet = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://www.baidu.com"]];
    [self.webview loadRequest:requet];
    self.webview.navigationDelegate = self;
}

- (void)tap:(UITapGestureRecognizer *)tap {
    NSLog(@"__%s__",__func__);
    
    SensorsDataReleaseObject *releaseObject = [[SensorsDataReleaseObject alloc] init];
    [releaseObject signalCrash];
    
}

- (void)longPress:(UILongPressGestureRecognizer *)tap {
    NSLog(@"__%s__",__func__);
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 5;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    if (indexPath.row == 2) {
        cell.textLabel.text = [NSString stringWithFormat:@"删除 crash--当前 index==%ld",indexPath.row];
    } else if (indexPath.row == 3) {
        cell.textLabel.text = [NSString stringWithFormat:@"闪退--当前 index==%ld",indexPath.row];
    } else {
        cell.textLabel.text = [NSString stringWithFormat:@"当前 index==%ld",indexPath.row];
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 30;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 3) {
        NSArray *array = @[@"first", @"second"];
        NSLog(@"%@", array[2]);
        return;
    }
    if (indexPath.row == 2) {
        [[YLLoggerServer sharedServer] deleteCrashLoggerForCount:2];
        return;
    }
    NSLog(@"点击了第%ld个 cell",indexPath.row);
    PresenVC *vc = [[PresenVC alloc] init];
    [self presentViewController:vc animated:YES completion:nil];
    
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    
}


#pragma mark - C
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return 5;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"celll" forIndexPath:indexPath];
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, kScreenWidht, 30)];
    titleLabel.textColor = [UIColor blackColor];
    titleLabel.text = [NSString stringWithFormat:@"当前 index==%ld",indexPath.row];;
    titleLabel.textAlignment = NSTextAlignmentLeft;
    [cell addSubview:titleLabel];
    
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"点击了第%ld个 cell",indexPath.row);
}
- (IBAction)buttonCLicked:(id)sender {
    NSLog(@"点我");
}

@end
