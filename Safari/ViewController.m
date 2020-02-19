//
//  ViewController.m
//  Safari
//
//  Created by Steven Troughton-Smith on 20/09/2015.
//  Improved by Jip van Akker on 14/10/2015 through 10/01/2019
//  Improved by LisaGuide on 02/19/2020
//

// Icons made by https://www.flaticon.com/authors/daniel-bruce Daniel Bruce from https://www.flaticon.com/ Flaticon" is licensed by  http://creativecommons.org/licenses/by/3.0/  CC 3.0 BY


#import "ViewController.h"
#import <GameController/GameController.h>

typedef struct _Input
{
    CGFloat x;
    CGFloat y;
} Input;


@interface ViewController ()
{
    UIImageView *cursorView;
    //UIActivityIndicatorView *loadingSpinner;
    Input input;
    NSString *requestURL;
    NSString *previousURL;
}

@property id webview;
@property (strong) CADisplayLink *link;
@property (strong, nonatomic) GCController *controller;
@property BOOL cursorMode;
@property BOOL displayedHintsOnLaunch;
@property BOOL scrollViewAllowBounces;
@property CGPoint lastTouchLocation;
@property NSUInteger textFontSize;
@property (weak, nonatomic) IBOutlet UILabel *URLBarLabel;

@end

@implementation ViewController {
    UITapGestureRecognizer *touchSurfaceDoubleTapRecognizer;
    UITapGestureRecognizer *playPauseOrMenuDoubleTapRecognizer;
}
-(void) webViewDidStartLoad:(id)webView {
    //[self.view bringSubviewToFront:loadingSpinner];
    if (![previousURL isEqualToString:requestURL]) {
        [self.loadingSpinner startAnimating];
    }
    previousURL = requestURL;
}
-(void) webViewDidFinishLoad:(id)webView {
    [self.loadingSpinner stopAnimating];
    //[self.view bringSubviewToFront:loadingSpinner];
    NSString *theTitle=[webView stringByEvaluatingJavaScriptFromString:@"document.title"];
    NSURLRequest *request = [webView request];
    NSString *currentURL = request.URL.absoluteString;
    
    self.lblUrlBar.text = currentURL;
    
    self.URLBarLabel.layer.masksToBounds = YES;
    self.URLBarLabel.layer.cornerRadius = 8.0;

    
    
    
    NSArray *toSaveItem = [NSArray arrayWithObjects:currentURL, theTitle, nil];
    NSMutableArray *historyArray = [NSMutableArray arrayWithObjects:toSaveItem, nil];
    if ([[NSUserDefaults standardUserDefaults] arrayForKey:@"HISTORY"] != nil) {
        NSMutableArray *savedArray = [[[NSUserDefaults standardUserDefaults] arrayForKey:@"HISTORY"] mutableCopy];
        if ([savedArray count] > 0) {
            if ([savedArray[0][0] isEqualToString: currentURL]) {
                [historyArray removeObjectAtIndex:0];
            }
        }
        [historyArray addObjectsFromArray:[[NSUserDefaults standardUserDefaults] arrayForKey:@"HISTORY"]];
    }
    while ([historyArray count] > 100) {
        [historyArray removeLastObject];
    }
    NSArray *toStoreArray = historyArray;
    [[NSUserDefaults standardUserDefaults] setObject:toStoreArray forKey:@"HISTORY"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    //loadingSpinner.center = CGPointMake(CGRectGetMidX([UIScreen mainScreen].bounds), CGRectGetMidY([UIScreen mainScreen].bounds));
    [self webViewDidAppear];
    _displayedHintsOnLaunch = YES;
}
-(void)webViewDidAppear {
    if ([[NSUserDefaults standardUserDefaults] stringForKey:@"savedURLtoReopen"] != nil) {
        [self.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[[NSUserDefaults standardUserDefaults] stringForKey:@"savedURLtoReopen"]]]];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"savedURLtoReopen"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    else if ([self.webview request] == nil) {
        //[self requestURLorSearchInput];
        [self loadHomePage];
    }
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DontShowHintsOnLaunch"] && !_displayedHintsOnLaunch) {
        [self showHintsAlert];
    }
}
-(void)loadHomePage {
    if ([[NSUserDefaults standardUserDefaults] stringForKey:@"homepage"] != nil) {
        [self.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[[NSUserDefaults standardUserDefaults] stringForKey:@"homepage"]]]];
    }
    else {
        [self.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString: @"about:blank"]]];
    }
}
-(void)initWebView {
    if (@available(tvOS 13.0, *)) {
        self.view.insetsLayoutMarginsFromSafeArea = false;
        self.additionalSafeAreaInsets = UIEdgeInsetsZero;
    }
    self.webview = [[NSClassFromString(@"UIWebView") alloc] init];
    [self.webview setTranslatesAutoresizingMaskIntoConstraints:false];
    [self.webview setClipsToBounds:false];
    
    //[self.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.duckduckgo.com"]]];
    
    //[self.view addSubview: self.webview];
    [self.browserContainerView addSubview: self.webview];

    [self.webview setFrame:self.view.frame];
    [self.webview setDelegate:self];
    [self.webview setLayoutMargins:UIEdgeInsetsZero];
    UIScrollView *scrollView = [self.webview scrollView];
    [scrollView setLayoutMargins:UIEdgeInsetsZero];
    if (@available(tvOS 13.0, *)) {
        scrollView.insetsLayoutMarginsFromSafeArea = false;
    }
    
    topMenuBrowserOffset = self.topMenuView.frame.size.height;
    //scrollView.contentOffset = CGPointMake(0, topHeight);
    scrollView.contentOffset = CGPointZero;
    
    scrollView.contentInset = UIEdgeInsetsZero;
    scrollView.frame = self.view.frame;
    scrollView.clipsToBounds = NO;
    [scrollView setNeedsLayout];
    [scrollView layoutIfNeeded];
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DisableOffsetCorrection"]) {
        CGPoint point = CGPointMake(60, 90);

        scrollView.contentInset = UIEdgeInsetsMake(-point.x + topMenuBrowserOffset, -point.y, -point.x, -point.y);
        [self offsetCorrection:YES];
    } else {
        [self offsetCorrection:NO];
    }
    scrollView.bounces = _scrollViewAllowBounces;
    scrollView.panGestureRecognizer.allowedTouchTypes = @[ @(UITouchTypeIndirect) ];
    scrollView.scrollEnabled = NO;
    
    [self.webview setUserInteractionEnabled:NO];
}
-(void)offsetCorrection:(bool)yes {
    UIScrollView *scrollView = [self.webview scrollView];
    if (yes) {
        CGPoint point = CGPointMake(60, 90);

        scrollView.contentInset = UIEdgeInsetsMake(-point.x + topMenuBrowserOffset, -point.y, -point.x, -point.y);
    } else {
        scrollView.contentInset = UIEdgeInsetsZero;
    }
}
-(void)viewDidLoad {
    self.automaticallyAdjustsScrollViewInsets = NO;
    self.definesPresentationContext = YES;
    
    topMenuShowing = YES;
    
    [self initWebView];
    _scrollViewAllowBounces = YES;
    [super viewDidLoad];
    touchSurfaceDoubleTapRecognizer = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(handleTouchSurfaceDoubleTap:)];
    touchSurfaceDoubleTapRecognizer.numberOfTapsRequired = 2;
    touchSurfaceDoubleTapRecognizer.allowedPressTypes = @[[NSNumber numberWithInteger:UIPressTypeSelect]];
    [self.view addGestureRecognizer:touchSurfaceDoubleTapRecognizer];
    
    playPauseOrMenuDoubleTapRecognizer = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(handleDoubleTapMenuOrPlayPause:)];
    playPauseOrMenuDoubleTapRecognizer.numberOfTapsRequired = 2;
    //playPauseOrMenuDoubleTapRecognizer.allowedPressTypes = @[[NSNumber numberWithInteger:UIPressTypePlayPause], [NSNumber numberWithInteger:UIPressTypeMenu]];
    playPauseOrMenuDoubleTapRecognizer.allowedPressTypes = @[[NSNumber numberWithInteger:UIPressTypePlayPause]];

    [self.view addGestureRecognizer:playPauseOrMenuDoubleTapRecognizer];
    
    cursorView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 64, 64)];
    cursorView.center = CGPointMake(CGRectGetMidX([UIScreen mainScreen].bounds), CGRectGetMidY([UIScreen mainScreen].bounds));
    cursorView.image = [UIImage imageNamed:@"Cursor"];
    cursorView.backgroundColor = [UIColor clearColor];
    cursorView.hidden = YES;
    
    
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
    longPress.allowedPressTypes = @[[NSNumber numberWithInteger:UIPressTypePlayPause]];
    [self.view addGestureRecognizer:longPress];
    
    
    [self.view addSubview:cursorView];
    
    
    
    
    
    self.loadingSpinner.hidesWhenStopped = true;
    
    //ENABLE CURSOR MODE INITIALLY
    self.cursorMode = YES;
    cursorView.hidden = NO;
    self.textFontSize = 100;
}

-(void)hideTopNav
{
    [self.topMenuView setHidden:YES];
    topMenuShowing = NO;
    topMenuBrowserOffset = 0;
    
    
    UIScrollView *scrollView = [self.webview scrollView];
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DisableOffsetCorrection"]) {
        CGPoint point = CGPointMake(60, 90);
        
        scrollView.contentInset = UIEdgeInsetsMake(-point.x + topMenuBrowserOffset, -point.y, -point.x, -point.y);
        [self offsetCorrection:YES];
    } else {
        [self offsetCorrection:NO];
    }
    
    

    [self.webview reload];

}

-(void)showTopNav
{
    [self.topMenuView setHidden:NO];
    topMenuShowing = YES;
    topMenuBrowserOffset = self.topMenuView.frame.size.height;
    
    
    UIScrollView *scrollView = [self.webview scrollView];
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DisableOffsetCorrection"]) {
        CGPoint point = CGPointMake(60, 90);
        
        scrollView.contentInset = UIEdgeInsetsMake(-point.x + topMenuBrowserOffset, -point.y, -point.x, -point.y);
        [self offsetCorrection:YES];
    } else {
        [self offsetCorrection:NO];
    }
    

    [self.webview reload];

}



-(void)showFormatMenu
{
    UIAlertController *formatAlertController = [UIAlertController
                                          alertControllerWithTitle:@"Format"
                                          message:@""
                                          preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancelAction = [UIAlertAction
    actionWithTitle:@"Cancel"
    style:UIAlertActionStyleCancel
    handler:^(UIAlertAction *action)
    {
    }];
    
    
    
    UIAlertAction *increaseFontSizeAction = [UIAlertAction
                                             actionWithTitle:@"Increase Font Size"
                                             style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action)
                                             {
                                                 self.textFontSize = (self.textFontSize < 160) ? self.textFontSize +5 : self.textFontSize;
                                                 
                                                 NSString *jsString = [[NSString alloc] initWithFormat:@"document.getElementsByTagName('body')[0].style.webkitTextSizeAdjust= '%lu%%'",
                                                                       (unsigned long)self.textFontSize];
                                                 [self.webview stringByEvaluatingJavaScriptFromString:jsString];
                                             }];
    
    UIAlertAction *decreaseFontSizeAction = [UIAlertAction
                                             actionWithTitle:@"Decrease Font Size"
                                             style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action)
                                             {
                                                 self.textFontSize = (self.textFontSize > 50) ? self.textFontSize -5 : self.textFontSize;
                                                 
                                                 NSString *jsString = [[NSString alloc] initWithFormat:@"document.getElementsByTagName('body')[0].style.webkitTextSizeAdjust= '%lu%%'",
                                                                       (unsigned long)self.textFontSize];
                                                 [self.webview stringByEvaluatingJavaScriptFromString:jsString];
                                             }];
    
    UIAlertAction *mobileModeAction = [UIAlertAction
                                       actionWithTitle:@"Switch To Mobile Mode"
                                       style:UIAlertActionStyleDefault
                                       handler:^(UIAlertAction *action)
                                       {
                                           NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:@"Mozilla/5.0 (iPad; CPU OS 10_0 like Mac OS X) AppleWebKit/602.1.38 (KHTML, like Gecko) Version/10.0 Mobile/14A300 Safari/602.1", @"UserAgent", nil];
                                           [[NSUserDefaults standardUserDefaults] registerDefaults:dictionary];
                                           [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"MobileMode"];
                                           [[NSUserDefaults standardUserDefaults] synchronize];
                                           NSURLRequest *request = [self.webview request];
                                           if (request != nil) {
                                               if (![request.URL.absoluteString isEqual:@""]) {
                                                   [[NSUserDefaults standardUserDefaults] setObject:request.URL.absoluteString forKey:@"savedURLtoReopen"];
                                                   [[NSUserDefaults standardUserDefaults] synchronize];
                                               }
                                           }
                                           NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
                                           for (NSHTTPCookie *cookie in [storage cookies]) {
                                               [storage deleteCookie:cookie];
                                           }
                                           [[NSURLCache sharedURLCache] removeAllCachedResponses];
                                           [[NSUserDefaults standardUserDefaults] synchronize];
                                           [[NSURLSession sharedSession] resetWithCompletionHandler:^{
                                               dispatch_sync(dispatch_get_main_queue(), ^{
                                                   [self.webview removeFromSuperview];
                                                   [self initWebView];
                                                   [self.view bringSubviewToFront:self->cursorView];
                                                   //[self.view bringSubviewToFront:self->loadingSpinner];
                                                   [self webViewDidAppear];
                                                   
                                               });
                                           }];
                                       }];
    UIAlertAction *desktopModeAction = [UIAlertAction
                                        actionWithTitle:@"Switch To Desktop Mode"
                                        style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction *action)
                                        {
                                            NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:@"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_2) AppleWebKit/602.3.12 (KHTML, like Gecko) Version/10.0.2 Safari/602.3.12", @"UserAgent", nil];
                                            [[NSUserDefaults standardUserDefaults] registerDefaults:dictionary];
                                            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"MobileMode"];
                                            [[NSUserDefaults standardUserDefaults] synchronize];
                                            NSURLRequest *request = [self.webview request];
                                            if (request != nil) {
                                                if (![request.URL.absoluteString isEqual:@""]) {
                                                    [[NSUserDefaults standardUserDefaults] setObject:request.URL.absoluteString forKey:@"savedURLtoReopen"];
                                                    [[NSUserDefaults standardUserDefaults] synchronize];
                                                }
                                            }
                                            NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
                                            for (NSHTTPCookie *cookie in [storage cookies]) {
                                                [storage deleteCookie:cookie];
                                            }
                                            [[NSURLCache sharedURLCache] removeAllCachedResponses];
                                            [[NSUserDefaults standardUserDefaults] synchronize];
                                            [[NSURLSession sharedSession] resetWithCompletionHandler:^{
                                                dispatch_sync(dispatch_get_main_queue(), ^{
                                                    [self.webview removeFromSuperview];
                                                    [self initWebView];
                                                    [self.view bringSubviewToFront:self->cursorView];
                                                    //[self.view bringSubviewToFront:self->loadingSpinner];
                                                    [self webViewDidAppear];
                                                    
                                                });
                                            }];
                                        }];
    /*
    UIAlertAction *scalePageToFitAction = [UIAlertAction
                                              actionWithTitle:@"Scale Pages to Fit"
                                              style:UIAlertActionStyleDefault
                                              handler:^(UIAlertAction *action)
                                              {
                                                  [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"ScalePagesToFit"];
                                                  [[NSUserDefaults standardUserDefaults] synchronize];
                                                  [self.webview setScalesPageToFit:YES];
                                                  [self.webview setContentMode:UIViewContentModeScaleAspectFit];
                                                  [self.webview reload];
                                              }];
       UIAlertAction *stopScalePageToFitAction = [UIAlertAction
                                                  actionWithTitle:@"Stop Scaling Pages to Fit"
                                                  style:UIAlertActionStyleDefault
                                                  handler:^(UIAlertAction *action)
                                                  {
                                                      [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"ScalePagesToFit"];
                                                      [[NSUserDefaults standardUserDefaults] synchronize];
                                                      [self.webview setScalesPageToFit:NO];
                                                      [self.webview reload];
                                                  }];
       UIAlertAction *disableOffsetCorrectionAction = [UIAlertAction
                                                       actionWithTitle:@"Stop Correcting Offset"
                                                       style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction *action)
                                                       {
                                                           [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"DisableOffsetCorrection"];
                                                           [[NSUserDefaults standardUserDefaults] synchronize];
                                                           [self offsetCorrection:NO];
                                                           [self.webview reload];
                                                       }];
       UIAlertAction *enableOffsetCorrectionAction = [UIAlertAction
                                                      actionWithTitle:@"Enable Offset Correction"
                                                      style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *action)
                                                      {
                                                          [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DisableOffsetCorrection"];
                                                          [[NSUserDefaults standardUserDefaults] synchronize];
                                                          [self offsetCorrection:YES];
                                                          [self.webview reload];
                                                      }];
    */
    
    
    [formatAlertController addAction:increaseFontSizeAction];
    [formatAlertController addAction:decreaseFontSizeAction];
    
    /*
    if ([self.webview scalesPageToFit]) {
           [formatAlertController addAction:stopScalePageToFitAction];
       } else {
           [formatAlertController addAction:scalePageToFitAction];
       }
       
       if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DisableOffsetCorrection"]) {
           [formatAlertController addAction:enableOffsetCorrectionAction];
       }
       else {
           [formatAlertController addAction:disableOffsetCorrectionAction];
       }
        */
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"MobileMode"]) {
           [formatAlertController addAction:desktopModeAction];
       }
       else {
           [formatAlertController addAction:mobileModeAction];
       }
    [formatAlertController addAction:cancelAction];
    [self presentViewController:formatAlertController animated:YES completion:nil];
}

-(void)showAdvancedMenu
{
    UIAlertController *alertController = [UIAlertController
                                          alertControllerWithTitle:@"Bookmarks"
                                          message:@""
                                          preferredStyle:UIAlertControllerStyleAlert];
    
    
   
    UIAlertAction *showHintsAction = [UIAlertAction
                                      actionWithTitle:@"User Guide"
                                      style:UIAlertActionStyleDefault
                                      handler:^(UIAlertAction *action)
                                      {
                                          [self showHintsAlert];
                                      }];
    UIAlertAction *cancelAction = [UIAlertAction
                                   actionWithTitle:@"Cancel"
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction *action)
                                   {
                                   }];
    UIAlertAction *viewFavoritesAction = [UIAlertAction
                                          actionWithTitle:@"Bookmarks"
                                          style:UIAlertActionStyleDefault
                                          handler:^(UIAlertAction *action)
                                          {
                                              NSArray *indexableArray = [[NSUserDefaults standardUserDefaults] arrayForKey:@"FAVORITES"];
                                              UIAlertController *historyAlertController = [UIAlertController
                                                                                           alertControllerWithTitle:@"Favorites"
                                                                                           message:@""
                                                                                           preferredStyle:UIAlertControllerStyleAlert];
                                              UIAlertAction *editFavoritesAction = [UIAlertAction
                                                                                    actionWithTitle:@"Delete a Favorite"
                                                                                    style:UIAlertActionStyleDestructive
                                                                                    handler:^(UIAlertAction *action)
                                                                                    {
                                                                                        NSArray *editingIndexableArray = [[NSUserDefaults standardUserDefaults] arrayForKey:@"FAVORITES"];
                                                                                        UIAlertController *editHistoryAlertController = [UIAlertController
                                                                                                                                         alertControllerWithTitle:@"Delete a Favorite"
                                                                                                                                         message:@"Select a Favorite to Delete"
                                                                                                                                         preferredStyle:UIAlertControllerStyleAlert];
                                                                                        if (editingIndexableArray != nil) {
                                                                                            for (int i = 0; i < [editingIndexableArray count]; i++) {
                                                                                                NSString *objectTitle = editingIndexableArray[i][1];
                                                                                                NSString *objectSubtitle = editingIndexableArray[i][0];
                                                                                                if (![[objectSubtitle stringByReplacingOccurrencesOfString:@" " withString:@""] isEqualToString: @""]) {
                                                                                                    if ([[objectTitle stringByReplacingOccurrencesOfString:@" " withString:@""] isEqualToString: @""]) {
                                                                                                        objectTitle = objectSubtitle;
                                                                                                    }
                                                                                                    UIAlertAction *favoriteItem = [UIAlertAction
                                                                                                                                   actionWithTitle:objectTitle
                                                                                                                                   style:UIAlertActionStyleDefault
                                                                                                                                   handler:^(UIAlertAction *action)
                                                                                                                                   {
                                                                                                                                       NSMutableArray *editingArray = [editingIndexableArray mutableCopy];
                                                                                                                                       [editingArray removeObjectAtIndex:i];
                                                                                                                                       NSArray *toStoreArray = editingArray;
                                                                                                                                       [[NSUserDefaults standardUserDefaults] setObject:toStoreArray forKey:@"FAVORITES"];
                                                                                                                                       [[NSUserDefaults standardUserDefaults] synchronize];
                                                                                                                                   }];
                                                                                                    [editHistoryAlertController addAction:favoriteItem];
                                                                                                }
                                                                                            }
                                                                                        }
                                                                                        [editHistoryAlertController addAction:cancelAction];
                                                                                        [self presentViewController:editHistoryAlertController animated:YES completion:nil];
                                                                                        
                                                                                    }];
                                              UIAlertAction *addToFavoritesAction = [UIAlertAction
                                                                                     actionWithTitle:@"Add Current Page to Favorites"
                                                                                     style:UIAlertActionStyleDefault
                                                                                     handler:^(UIAlertAction *action)
                                                                                     {
                                                                                         NSString *theTitle=[self.webview stringByEvaluatingJavaScriptFromString:@"document.title"];
                                                                                         NSURLRequest *request = [self.webview request];
                                                                                         NSString *currentURL = request.URL.absoluteString;
                                                                                         UIAlertController *favoritesAddToController = [UIAlertController
                                                                                                                                        alertControllerWithTitle:@"Name New Favorite"
                                                                                                                                        message:currentURL
                                                                                                                                        preferredStyle:UIAlertControllerStyleAlert];
                                                                                         
                                                                                         [favoritesAddToController addTextFieldWithConfigurationHandler:^(UITextField *textField)
                                                                                          {
                                                                                              textField.keyboardType = UIKeyboardTypeDefault;
                                                                                              textField.placeholder = @"Name New Favorite";
                                                                                              textField.text = theTitle;
                                                                                              textField.textColor = [UIColor blackColor];
                                                                                              textField.backgroundColor = [UIColor whiteColor];
                                                                                              [textField setReturnKeyType:UIReturnKeyDone];
                                                                                              [textField addTarget:self
                                                                                                            action:@selector(alertTextFieldShouldReturn:)
                                                                                                  forControlEvents:UIControlEventEditingDidEnd];
                                                                                              
                                                                                          }];
                                                                                         
                                                                                         UIAlertAction *saveAction = [UIAlertAction
                                                                                                                      actionWithTitle:@"Save"
                                                                                                                      style:UIAlertActionStyleDestructive
                                                                                                                      handler:^(UIAlertAction *action)
                                                                                                                      {
                                                                                                                          UITextField *urltextfield = favoritesAddToController.textFields[0];
                                                                                                                          NSString *toMod = urltextfield.text;
                                                                                                                          if ([toMod isEqualToString:@""]) {
                                                                                                                              toMod = currentURL;
                                                                                                                          }
                                                                                                                          NSArray *toSaveItem = [NSArray arrayWithObjects:toMod, theTitle, nil];
                                                                                                                          NSMutableArray *historyArray = [NSMutableArray arrayWithObjects:toSaveItem, nil];
                                                                                                                          if ([[NSUserDefaults standardUserDefaults] arrayForKey:@"FAVORITES"] != nil) {
                                                                                                                              historyArray = [[[NSUserDefaults standardUserDefaults] arrayForKey:@"FAVORITES"] mutableCopy];
                                                                                                                              [historyArray addObject:toSaveItem];
                                                                                                                          }
                                                                                                                          NSArray *toStoreArray = historyArray;
                                                                                                                          [[NSUserDefaults standardUserDefaults] setObject:toStoreArray forKey:@"FAVORITES"];
                                                                                                                          [[NSUserDefaults standardUserDefaults] synchronize];
                                                                                                                          
                                                                                                                      }];
                                                                                         [favoritesAddToController addAction:saveAction];
                                                                                         [favoritesAddToController addAction:cancelAction];
                                                                                         [self presentViewController:favoritesAddToController animated:YES completion:nil];
                                                                                         //UITextField *textFieldAlert = favoritesAddToController.textFields[0];
                                                                                         //[textFieldAlert becomeFirstResponder];
                                                                                         
                                                                                     }];
                                              if (indexableArray != nil) {
                                                  for (int i = 0; i < [indexableArray count]; i++) {
                                                      NSString *objectTitle = indexableArray[i][1];
                                                      NSString *objectSubtitle = indexableArray[i][0];
                                                      if (![[objectSubtitle stringByReplacingOccurrencesOfString:@" " withString:@""] isEqualToString: @""]) {
                                                          if ([[objectTitle stringByReplacingOccurrencesOfString:@" " withString:@""] isEqualToString: @""]) {
                                                              objectTitle = objectSubtitle;
                                                          }
                                                          UIAlertAction *favoriteItem = [UIAlertAction
                                                                                         actionWithTitle:objectTitle
                                                                                         style:UIAlertActionStyleDefault
                                                                                         handler:^(UIAlertAction *action)
                                                                                         {
                                                                                             [self.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString: indexableArray[i][0]]]];
                                                                                         }];
                                                          [historyAlertController addAction:favoriteItem];
                                                      }
                                                  }
                                              }
                                              if ([[NSUserDefaults standardUserDefaults] arrayForKey:@"FAVORITES"] != nil) {
                                                  if ([[[NSUserDefaults standardUserDefaults] arrayForKey:@"FAVORITES"] count] > 0) {
                                                      [historyAlertController addAction:editFavoritesAction];
                                                  }
                                              }
                                              [historyAlertController addAction:addToFavoritesAction];
                                              [historyAlertController addAction:cancelAction];
                                              [self presentViewController:historyAlertController animated:YES completion:nil];
                                          }];
    UIAlertAction *viewHistoryAction = [UIAlertAction
                                        actionWithTitle:@"History"
                                        style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction *action)
                                        {
                                            NSArray *indexableArray = [[NSUserDefaults standardUserDefaults] arrayForKey:@"HISTORY"];
                                            UIAlertController *historyAlertController = [UIAlertController
                                                                                         alertControllerWithTitle:@"History"
                                                                                         message:@""
                                                                                         preferredStyle:UIAlertControllerStyleAlert];
                                            UIAlertAction *clearHistoryAction = [UIAlertAction
                                                                                 actionWithTitle:@"Clear History"
                                                                                 style:UIAlertActionStyleDestructive
                                                                                 handler:^(UIAlertAction *action)
                                                                                 {
                                                                                     [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"HISTORY"];
                                                                                     [[NSUserDefaults standardUserDefaults] synchronize];
                                                                                     
                                                                                 }];
                                            if ([[NSUserDefaults standardUserDefaults] arrayForKey:@"HISTORY"] != nil) {
                                                [historyAlertController addAction:clearHistoryAction];
                                            }
                                            for (int i = 0; i < [indexableArray count]; i++) {
                                                NSString *objectTitle = indexableArray[i][1];
                                                NSString *objectSubtitle = indexableArray[i][0];
                                                if (![[objectSubtitle stringByReplacingOccurrencesOfString:@" " withString:@""] isEqualToString: @""]) {
                                                    if ([[objectTitle stringByReplacingOccurrencesOfString:@" " withString:@""] isEqualToString: @""]) {
                                                        objectTitle = objectSubtitle;
                                                    }
                                                    else {
                                                        objectTitle = [NSString stringWithFormat:@"%@ - %@",objectTitle,objectSubtitle ];
                                                    }
                                                    UIAlertAction *historyItem = [UIAlertAction
                                                                                  actionWithTitle:objectTitle
                                                                                  style:UIAlertActionStyleDefault
                                                                                  handler:^(UIAlertAction *action)
                                                                                  {
                                                                                      [self.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString: indexableArray[i][0]]]];
                                                                                  }];
                                                    [historyAlertController addAction:historyItem];
                                                }
                                            }
                                            [historyAlertController addAction:cancelAction];
                                            [self presentViewController:historyAlertController animated:YES completion:nil];
                                        }];
    
   
    UIAlertAction *clearCacheAction = [UIAlertAction
                                       actionWithTitle:@"Clear Cache"
                                       style:UIAlertActionStyleDestructive
                                       handler:^(UIAlertAction *action)
                                       {
                                           [[NSURLCache sharedURLCache] removeAllCachedResponses];
                                           [[NSUserDefaults standardUserDefaults] synchronize];
                                           self->previousURL = @"";
                                           [self.webview reload];
                                           
                                       }];
    UIAlertAction *clearCookiesAction = [UIAlertAction
                                         actionWithTitle:@"Clear Cookies"
                                         style:UIAlertActionStyleDestructive
                                         handler:^(UIAlertAction *action)
                                         {
                                             NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
                                             for (NSHTTPCookie *cookie in [storage cookies]) {
                                                 [storage deleteCookie:cookie];
                                             }
                                             [[NSUserDefaults standardUserDefaults] synchronize];
                                             self->previousURL = @"";
                                             [self.webview reload];
                                             
                                         }];
    
    


    [alertController addAction:viewFavoritesAction];
    [alertController addAction:viewHistoryAction];
    
    [alertController addAction:clearCacheAction];
    [alertController addAction:clearCookiesAction];
    [alertController addAction:showHintsAction];
    [alertController addAction:cancelAction];
    [self presentViewController:alertController animated:YES completion:nil];
}


-(void)handleDoubleTapMenuOrPlayPause:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        [self showAdvancedMenu];
    }
}
-(void)handleTouchSurfaceDoubleTap:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        [self toggleMode];
    }
}

-(void)showInputURLorSearchGoogle
{
    UIAlertController *alertController2 = [UIAlertController
                                           alertControllerWithTitle:@"Search or enter website name"
                                           message:@""
                                           preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController2 addTextFieldWithConfigurationHandler:^(UITextField *textField)
     {
         textField.keyboardType = UIKeyboardTypeURL;
         textField.placeholder = @"Search or enter website name";
         textField.textColor = [UIColor blackColor];
         textField.backgroundColor = [UIColor whiteColor];
         [textField setReturnKeyType:UIReturnKeyDone];
         [textField addTarget:self
                       action:@selector(alertTextFieldShouldReturn:)
             forControlEvents:UIControlEventEditingDidEnd];
         
     }];
    
    
    UIAlertAction *goAction = [UIAlertAction
                               actionWithTitle:@"Go"
                               style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *action)
                               {
                                   UITextField *urltextfield = alertController2.textFields[0];
                                   NSString *toMod = urltextfield.text;
                                   
                                   if (![toMod isEqualToString:@""]) {
                                       if ([toMod containsString:@"http://"] || [toMod containsString:@"https://"]) {
                                           [self.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@", toMod]]]];
                                       }
                                       else {
                                           [self.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://%@", toMod]]]];
                                       }
                                   }
                                   else {
                                       [self requestURLorSearchInput];
                                   }
                                   //}
                                   
                               }];
    
    UIAlertAction *searchAction = [UIAlertAction
                                   actionWithTitle:@"Search"
                                   style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction *action)
                                   {
                                       UITextField *urltextfield = alertController2.textFields[0];
                                       NSString *toMod = urltextfield.text;
                                       toMod = [toMod stringByReplacingOccurrencesOfString:@" " withString:@"+"];
                                       toMod = [toMod stringByReplacingOccurrencesOfString:@"." withString:@"+"];
                                       toMod = [toMod stringByReplacingOccurrencesOfString:@"++" withString:@"+"];
                                       toMod = [toMod stringByReplacingOccurrencesOfString:@"++" withString:@"+"];
                                       toMod = [toMod stringByReplacingOccurrencesOfString:@"++" withString:@"+"];
                                       toMod = [toMod stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
                                       if (toMod != nil) {
                                           [self.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://www.google.com/search?q=%@", toMod]]]];
                                       }
                                       else {
                                           [self requestURLorSearchInput];
                                       }
                                   }];
    
    UIAlertAction *cancelAction = [UIAlertAction
                                   actionWithTitle:@"Cancel"
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction *action)
                                   {
                                   }];
    
    [alertController2 addAction:goAction];
    [alertController2 addAction:searchAction];
    [alertController2 addAction:cancelAction];
    
    [self presentViewController:alertController2 animated:YES completion:nil];
    
    NSURLRequest *request = [self.webview request];

    
    if (request == nil) {
        UITextField *loginTextField = alertController2.textFields[0];
        [loginTextField becomeFirstResponder];
    }
    else if (![request.URL.absoluteString  isEqual: @""]) {
        UITextField *loginTextField = alertController2.textFields[0];
        [loginTextField becomeFirstResponder];
    }
    
    
    
    
}

-(void)requestURLorSearchInput
{
    
    UIAlertController *alertController = [UIAlertController
                                          alertControllerWithTitle:@"Quick Menu"
                                          message:@""
                                          preferredStyle:UIAlertControllerStyleAlert];
    
    
    
    
    
    
    
    
    
    UIAlertAction *backAction = [UIAlertAction
                                   actionWithTitle:@"Navigate Back"
                                   style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction *action)
                                   {
                                       [self.webview goBack];
                                   }];
    
    
    UIAlertAction *reloadAction = [UIAlertAction
                                   actionWithTitle:@"Reload Page"
                                   style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction *action)
                                   {
                                       self->previousURL = @"";
                                       [self.webview reload];
                                   }];
    
    
    UIAlertAction *cancelAction = [UIAlertAction
                                   actionWithTitle:@"Cancel"
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction *action)
                                   {
                                   }];
    
    UIAlertAction *inputAction = [UIAlertAction
                                  actionWithTitle:@"Input URL or Search with Google"
                                  style:UIAlertActionStyleDefault
                                  handler:^(UIAlertAction *action)
                                  {
                                      
                                      [self showInputURLorSearchGoogle];
                                      
                                  }];
    
    
    if([self.webview canGoBack])
        [alertController addAction:backAction];
    
    [alertController addAction:inputAction];
    
    NSURLRequest *request = [self.webview request];
    if (request != nil) {
        if (![request.URL.absoluteString  isEqual: @""]) {
            [alertController addAction:reloadAction];
            [alertController addAction:cancelAction];
        }
    }
    
    [self presentViewController:alertController animated:YES completion:nil];
    
    
    
    
    
    
}
- (BOOL)webView:(id)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(NSInteger)navigationType {
    requestURL = request.URL.absoluteString;
    return YES;
}

- (void)webView:(id)webView didFailLoadWithError:(NSError *)error {
    [self.loadingSpinner stopAnimating];
    if (![[NSString stringWithFormat:@"%lid", (long)error.code] containsString:@"999"] && ![[NSString stringWithFormat:@"%lid", (long)error.code] containsString:@"204"]) {
        UIAlertController *alertController = [UIAlertController
                                              alertControllerWithTitle:@"Could Not Load Webpage"
                                              message:[error localizedDescription]
                                              preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *searchAction = [UIAlertAction
                                       actionWithTitle:@"Google This Page"
                                       style:UIAlertActionStyleDefault
                                       handler:^(UIAlertAction *action)
                                       {
                                           if (self->requestURL != nil) {
                                               if ([self->requestURL length] > 1) {
                                                   NSString *lastChar = [self->requestURL substringFromIndex: [self->requestURL length] - 1];
                                                   if ([lastChar isEqualToString:@"/"]) {
                                                       NSString *newString = [self->requestURL substringToIndex:[self->requestURL length]-1];
                                                       self->requestURL = newString;
                                                   }
                                               }
                                               self->requestURL = [self->requestURL stringByReplacingOccurrencesOfString:@"http://" withString:@""];
                                               self->requestURL = [self->requestURL stringByReplacingOccurrencesOfString:@"https://" withString:@""];
                                               self->requestURL = [self->requestURL stringByReplacingOccurrencesOfString:@"www." withString:@""];
                                               [self.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://www.google.com/search?q=%@", self->requestURL]]]];
                                           }
                                           
                                       }];
        UIAlertAction *reloadAction = [UIAlertAction
                                       actionWithTitle:@"Reload Page"
                                       style:UIAlertActionStyleDefault
                                       handler:^(UIAlertAction *action)
                                       {
                                           self->previousURL = @"";
                                           [self.webview reload];
                                       }];
        UIAlertAction *newurlAction = [UIAlertAction
                                       actionWithTitle:@"Enter a URL or Search"
                                       style:UIAlertActionStyleDefault
                                       handler:^(UIAlertAction *action)
                                       {
                                           [self requestURLorSearchInput];
                                       }];
        UIAlertAction *cancelAction = [UIAlertAction
                                       actionWithTitle:@"Dismiss"
                                       style:UIAlertActionStyleCancel
                                       handler:^(UIAlertAction *action)
                                       {
                                       }];
        if (requestURL != nil) {
            if ([requestURL length] > 1) {
                [alertController addAction:searchAction];
            }
        }
        NSURLRequest *request = [self.webview request];
        if (request != nil) {
            if (![request.URL.absoluteString  isEqual: @""]) {
                [alertController addAction:reloadAction];
            }
            else {
                [alertController addAction:newurlAction];
            }
        }
        else {
            [alertController addAction:newurlAction];
        }
        
        [alertController addAction:cancelAction];
        [self presentViewController:alertController animated:YES completion:nil];
    }
}
-(void)toggleMode
{
    self.cursorMode = !self.cursorMode;
    UIScrollView *scrollView = [self.webview scrollView];
    if (self.cursorMode)
    {
        scrollView.scrollEnabled = NO;
        [self.webview setUserInteractionEnabled:NO];
        cursorView.hidden = NO;
    }
    else
    {
        scrollView.scrollEnabled = YES;
        [self.webview setUserInteractionEnabled:YES];
        cursorView.hidden = YES;
        
        
    }
}
- (void)showHintsAlert
{
    UIAlertController *alertController = [UIAlertController
                                          alertControllerWithTitle:@"User Guide"
                                          
                                          message:@"Double-press the Touch Surface to switch between the cursor and scroll.\nPress the Touch Surface while in cursor mode to interact with the page."
                                          preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *hideForeverAction = [UIAlertAction
                                        actionWithTitle:@"Do not Show This Again"
                                        style:UIAlertActionStyleDestructive
                                        handler:^(UIAlertAction *action)
                                        {
                                            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"DontShowHintsOnLaunch"];
                                            [[NSUserDefaults standardUserDefaults] synchronize];
                                        }];
    UIAlertAction *showForeverAction = [UIAlertAction
                                        actionWithTitle:@"Always Show On Launch"
                                        style:UIAlertActionStyleDestructive
                                        handler:^(UIAlertAction *action)
                                        {
                                            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DontShowHintsOnLaunch"];
                                            [[NSUserDefaults standardUserDefaults] synchronize];
                                        }];
    UIAlertAction *cancelAction = [UIAlertAction
                                   actionWithTitle:@"Dismiss"
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction *action)
                                   {
                                   }];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DontShowHintsOnLaunch"]) {
        [alertController addAction:showForeverAction];
    }
    else {
        [alertController addAction:hideForeverAction];
    }
    [alertController addAction:cancelAction];
    [self presentViewController:alertController animated:YES completion:nil];
    
    
}
- (void)alertTextFieldShouldReturn:(UITextField *)sender
{
    
}
-(void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event
{
    
    
    if (presses.anyObject.type == UIPressTypeMenu)
    {
        UIAlertController *alertController = (UIAlertController *)self.presentedViewController;
        if (alertController)
        {
            [self.presentedViewController dismissViewControllerAnimated:true completion:nil];
        }
        else
        {
            //UIControl().sendAction(#selector(NSURLSessionTask.suspend), to: UIApplication.sharedApplication(), forEvent: nil);
            exit(EXIT_SUCCESS);
        }
       
        
    }
    else if (presses.anyObject.type == UIPressTypeUpArrow)
    {
       
    }
    else if (presses.anyObject.type == UIPressTypeDownArrow)
    {
    }
    
    
    else if (presses.anyObject.type == UIPressTypeSelect) // Handle the normal single Touchpad press with our virtual cursor
    {
        if(!self.cursorMode)
        {
            
        }
        else
        {
            // Handle the virtual cursor
            
            

            CGPoint point = [self.view convertPoint:cursorView.frame.origin toView:self.webview];
            
            if(topMenuShowing == YES && point.y < topMenuBrowserOffset)
            {
                // Handle menu buttons press
                
                CGRect backBtnFrameExtra = self.btnImageBack.frame;
                backBtnFrameExtra.origin.y = 0; // Enable cursor in upper right corner
                backBtnFrameExtra.size.height = backBtnFrameExtra.size.height+ 8;// Enable cursor in upper right corner

                
                if(CGRectContainsPoint(backBtnFrameExtra, point))
                {
                    [self.webview goBack];
                }
                else if(CGRectContainsPoint(self.btnImageRefresh.frame, point))
                {
                    [self.webview reload];
                }
                else if(CGRectContainsPoint(self.btnImageForward.frame, point))
                {
                    [self.webview goForward];
                }
                else if(CGRectContainsPoint(self.btnImageHome.frame, point))
                {
                    [self loadHomePage];
                }
                else if(CGRectContainsPoint(self.lblUrlBar.frame, point))
                {
                    [self showInputURLorSearchGoogle];
                }

                
                
                CGRect menuBtnFrameExtra = self.btnImgMenu.frame;
                menuBtnFrameExtra.origin.y = 0; // Enable cursor in upper right corner
                menuBtnFrameExtra.size.width = menuBtnFrameExtra.size.width + 100; // Enable cursor in upper right corner
                menuBtnFrameExtra.size.height = menuBtnFrameExtra.size.height+ 100;// Enable cursor in upper right corner

                if(CGRectContainsPoint(menuBtnFrameExtra, point))
                {
                    // Show advanced menu:
                    [self showAdvancedMenu];
                }
                
                CGRect formatMenuFrameExtra = self.formatImgMenu.frame;
                formatMenuFrameExtra.origin.y = 0; // Enable cursor in upper right corner
                formatMenuFrameExtra.size.width = formatMenuFrameExtra.size.width + 100; // Enable cursor in upper right corner
                formatMenuFrameExtra.size.height = formatMenuFrameExtra.size.height+ 100;// Enable cursor in upper right corner

                if(CGRectContainsPoint(formatMenuFrameExtra, point))
                {
                    // Show advanced menu:
                    [self showFormatMenu];
                }
               

                    
            }
            else // Handle Press in the Browser view
            {
            
            point.y = point.y - topMenuBrowserOffset;
            
            int displayWidth = [[self.webview stringByEvaluatingJavaScriptFromString:@"window.innerWidth"] intValue];
            CGFloat scale = [self.webview frame].size.width / displayWidth;
            
            point.x /= scale;
            point.y /= scale;

            [self.webview stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.elementFromPoint(%i, %i).click()", (int)point.x, (int)point.y]];
            // Make the UIWebView method call
            NSString *fieldType = [self.webview stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.elementFromPoint(%i, %i).type;", (int)point.x, (int)point.y]];
            
            fieldType = fieldType.lowercaseString;
            if ([fieldType isEqualToString:@"date"] || [fieldType isEqualToString:@"datetime"] || [fieldType isEqualToString:@"datetime-local"] || [fieldType isEqualToString:@"email"] || [fieldType isEqualToString:@"month"] || [fieldType isEqualToString:@"number"] || [fieldType isEqualToString:@"password"] || [fieldType isEqualToString:@"tel"] || [fieldType isEqualToString:@"text"] || [fieldType isEqualToString:@"time"] || [fieldType isEqualToString:@"url"] || [fieldType isEqualToString:@"week"]) {
                NSString *fieldTitle = [self.webview stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.elementFromPoint(%i, %i).title;", (int)point.x, (int)point.y]];
                if ([fieldTitle isEqualToString:@""]) {
                    fieldTitle = fieldType;
                }
                NSString *placeholder = [self.webview stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.elementFromPoint(%i, %i).placeholder;", (int)point.x, (int)point.y]];
                if ([placeholder isEqualToString:@""]) {
                    if (![fieldTitle isEqualToString:fieldType]) {
                        placeholder = [NSString stringWithFormat:@"%@ Input", fieldTitle];
                    }
                    else {
                        placeholder = @"Text Input";
                    }
                }
                NSString *testedFormResponse = [self.webview stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.elementFromPoint(%i, %i).form.hasAttribute('onsubmit');", (int)point.x, (int)point.y]];
                UIAlertController *alertController = [UIAlertController
                                                      alertControllerWithTitle:@"Input Text"
                                                      message: [fieldTitle capitalizedString]
                                                      preferredStyle:UIAlertControllerStyleAlert];
                
                [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField)
                 {
                     if ([fieldType isEqualToString:@"url"]) {
                         textField.keyboardType = UIKeyboardTypeURL;
                     }
                     else if ([fieldType isEqualToString:@"email"]) {
                         textField.keyboardType = UIKeyboardTypeEmailAddress;
                     }
                     else if ([fieldType isEqualToString:@"tel"] || [fieldType isEqualToString:@"number"] || [fieldType isEqualToString:@"date"] || [fieldType isEqualToString:@"datetime"] || [fieldType isEqualToString:@"datetime-local"]) {
                         textField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
                     }
                     else {
                         textField.keyboardType = UIKeyboardTypeDefault;
                     }
                     textField.placeholder = [placeholder capitalizedString];
                     if ([fieldType isEqualToString:@"password"]) {
                         textField.secureTextEntry = YES;
                     }
                     textField.text = [self.webview stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.elementFromPoint(%i, %i).value;", (int)point.x, (int)point.y]];
                     textField.textColor = [UIColor blackColor];
                     textField.backgroundColor = [UIColor whiteColor];
                     [textField setReturnKeyType:UIReturnKeyDone];
                     [textField addTarget:self
                                   action:@selector(alertTextFieldShouldReturn:)
                         forControlEvents:UIControlEventEditingDidEnd];
                     
                 }];
                UIAlertAction *inputAndSubmitAction = [UIAlertAction
                                                       actionWithTitle:@"Submit"
                                                       style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction *action)
                                                       {
                                                           UITextField *inputViewTextField = alertController.textFields[0];
                                                           NSString *javaScript = [NSString stringWithFormat:@"var textField = document.elementFromPoint(%i, %i);"
                                                                                   "textField.value = '%@';"
                                                                                   "textField.form.submit();"
                                                                                   //"var ev = document.createEvent('KeyboardEvent');"
                                                                                   //"ev.initKeyEvent('keydown', true, true, window, false, false, false, false, 13, 0);"
                                                                                   //"document.body.dispatchEvent(ev);"
                                                                                   , (int)point.x, (int)point.y, inputViewTextField.text];
                                                           [self.webview stringByEvaluatingJavaScriptFromString:javaScript];
                                                       }];
                UIAlertAction *inputAction = [UIAlertAction
                                              actionWithTitle:@"Done"
                                              style:UIAlertActionStyleDefault
                                              handler:^(UIAlertAction *action)
                                              {
                                                  UITextField *inputViewTextField = alertController.textFields[0];
                                                  NSString *javaScript = [NSString stringWithFormat:@"var textField = document.elementFromPoint(%i, %i);"
                                                                          "textField.value = '%@';", (int)point.x, (int)point.y, inputViewTextField.text];
                                                  [self.webview stringByEvaluatingJavaScriptFromString:javaScript];
                                              }];
                UIAlertAction *cancelAction = [UIAlertAction
                                               actionWithTitle:@"Cancel"
                                               style:UIAlertActionStyleCancel
                                               handler:^(UIAlertAction *action)
                                               {
                                               }];
                [alertController addAction:inputAction];
                if (testedFormResponse != nil) {
                    if ([testedFormResponse isEqualToString:@"true"]) {
                        [alertController addAction:inputAndSubmitAction];
                    }
                }
                [alertController addAction:cancelAction];
                [self presentViewController:alertController animated:YES completion:nil];
                UITextField *inputViewTextField = alertController.textFields[0];
                if ([[inputViewTextField.text stringByReplacingOccurrencesOfString:@" " withString:@""] isEqualToString:@""]) {
                    [inputViewTextField becomeFirstResponder];
                }
            }
            else {
                //[self.webview stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.elementFromPoint(%i, %i).click()", (int)point.x, (int)point.y]];
            }
            //[self toggleMode];
                
            }
        }
    }
    
    else if (presses.anyObject.type == UIPressTypePlayPause)
    {
        UIAlertController *alertController = (UIAlertController *)self.presentedViewController;
        if (alertController)
        {
            [self.presentedViewController dismissViewControllerAnimated:true completion:nil];
        }
        else {
            [self requestURLorSearchInput];
        }
    }
}
- (void)longPress:(UILongPressGestureRecognizer*)gesture {
    if ( gesture.state == UIGestureRecognizerStateBegan) {
        
    }
    else if ( gesture.state == UIGestureRecognizerStateEnded) {
        //[self toggleMode];
    }
}

#pragma mark - Cursor Input

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    self.lastTouchLocation = CGPointMake(-1, -1);
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    for (UITouch *touch in touches)
    {
        CGPoint location = [touch locationInView:self.webview];
        
        if(self.lastTouchLocation.x == -1 && self.lastTouchLocation.y == -1)
        {
            // Prevent cursor from recentering
            self.lastTouchLocation = location;
        }
        else
        {
            CGFloat xDiff = location.x - self.lastTouchLocation.x;
            CGFloat yDiff = location.y - self.lastTouchLocation.y;
            CGRect rect = cursorView.frame;
            
            if(rect.origin.x + xDiff >= 0 && rect.origin.x + xDiff <= 1920)
                rect.origin.x += xDiff;//location.x - self.startPos.x;//+= xDiff; //location.x;
            
            if(rect.origin.y + yDiff >= 0 && rect.origin.y + yDiff <= 1080)
                rect.origin.y += yDiff;//location.y - self.startPos.y;//+= yDiff; //location.y;
            
            cursorView.frame = rect;
            self.lastTouchLocation = location;
        }
        
        // We only use one touch, break the loop
        break;
    }
    
}



@end
