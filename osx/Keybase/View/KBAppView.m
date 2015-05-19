//
//  KBAppView.m
//  Keybase
//
//  Created by Gabriel on 2/4/15.
//  Copyright (c) 2015 Gabriel Handford. All rights reserved.
//

#import "KBAppView.h"

#import "KBUsersAppView.h"
#import "KBUserProfileView.h"
#import "AppDelegate.h"
#import "KBLoginView.h"
#import "KBSignupView.h"
#import "KBInstaller.h"
#import "KBDevicesAppView.h"
#import "KBAppProgressView.h"
#import "KBFoldersAppView.h"
#import "KBAppToolbar.h"
#import "KBPGPAppView.h"
#import "KBSourceOutlineView.h"
#import "KBInstallAction.h"
#import "KBInstallerView.h"

#import "KBService.h"
#import "KBFSService.h"
#import "KBHelperTool.h"
#import "KBFuseComponent.h"
#import "KBCLIInstall.h"
#import "KBControlPanel.h"


typedef NS_ENUM (NSInteger, KBAppViewMode) {
  KBAppViewModeInProgress = 1,
  KBAppViewModeInstaller,
  KBAppViewModeLogin,
  KBAppViewModeSignup,
  KBAppViewModeMain
};

@interface KBAppView () <KBAppToolbarDelegate, KBSignupViewDelegate, KBLoginViewDelegate, KBRPClientDelegate, NSWindowDelegate>
@property KBAppToolbar *toolbar;
@property KBSourceOutlineView *sourceView;
@property (readonly) YOView *contentView;

@property KBUsersAppView *usersAppView;
@property KBDevicesAppView *devicesAppView;
@property KBFoldersAppView *foldersAppView;
@property KBPGPAppView *PGPAppView;

@property KBUserProfileView *userProfileView;
@property (nonatomic) KBLoginView *loginView;
@property (nonatomic) KBSignupView *signupView;

@property KBNavigationTitleView *titleView;

@property NSString *title;
@property KBAppViewMode mode;

@property KBEnvironment *environment;
@end

#define TITLE_HEIGHT (32)

@implementation KBAppView

- (void)viewInit {
  [super viewInit];

  _title = @"Keybase";

  _delegates = [NSHashTable weakObjectsHashTable];

  _toolbar = [[KBAppToolbar alloc] init];
  _toolbar.hidden = YES;
  _toolbar.delegate = self;
  [self addSubview:_toolbar];

  _sourceView = [[KBSourceOutlineView alloc] init];
  _sourceView.hidden = YES;
  //_sourceView.delegate = self;
  //[self addSubview:_sourceView];

  YOSelf yself = self;
  self.viewLayout = [YOLayout layoutWithLayoutBlock:^(id<YOLayout> layout, CGSize size) {
    CGFloat x = 0;
    CGFloat y = 0;

    if (!yself.toolbar.hidden) {
      y += [layout sizeToFitVerticalInFrame:CGRectMake(0, y, size.width, 0) view:yself.toolbar].size.height;
    }

    if (!yself.sourceView.hidden && yself.sourceView.superview) {
      [layout setFrame:CGRectMake(x, y, 160 - 1, size.height - y) view:yself.sourceView]; // NSOutlineView has trouble initializing to a bad size
      x += 160;
    }

    [layout setFrame:CGRectMake(x, y, size.width - x, size.height - y) view:yself.contentView];

    return size;
  }];

  [self showInProgress:@"Loading"];
}

- (NSArray *)componentsForEnvironment:(KBEnvironment *)environment {
  NSMutableArray *components = [NSMutableArray array];

  _service = [[KBService alloc] initWithEnvironment:environment];

  [components addObject:_service];

  [components addObject:[[KBHelperTool alloc] initWithEnvironment:environment]];
  [components addObject:[[KBFuseComponent alloc] initWithEnvironment:environment]];
  [components addObject:[[KBFSService alloc] initWithEnvironment:environment]];

  //[components addObject:[[KBCLIInstall alloc] initWithEnvironment:environment]];

  return components;
}

- (void)openWithEnvironment:(KBEnvironment *)environment {
  _environment = environment;
  for (id<KBAppViewDelegate> delegate in _delegates) [delegate appViewDidLaunch:self];

  [self showInProgress:@"Loading"];

  NSArray *components = [self componentsForEnvironment:environment];

  [AppDelegate.sharedDelegate.controlPanel addComponents:components];

  KBInstaller *installer = [[KBInstaller alloc] initWithEnvironment:environment components:environment.isInstallEnabled ? components : nil];
  [installer installStatus:^(BOOL needsInstall) {
    if (needsInstall) {
      [self showInstaller:installer];
    } else {
      [self connect];
    }
  }];
}

- (void)connect {
  _service.client.delegate = self;

  GHWeakSelf gself = self;
  [_service.client registerMethod:@"keybase.1.secretUi.getSecret" sessionId:0 requestHandler:^(NSNumber *messageId, NSString *method, NSArray *params, MPRequestCompletion completion) {
    DDLogDebug(@"Password prompt: %@", params);
    KBRGetSecretRequestParams *requestParams = [[KBRGetSecretRequestParams alloc] initWithParams:params];
    [KBAlert promptForInputWithTitle:requestParams.pinentry.prompt description:requestParams.pinentry.desc secure:YES style:NSCriticalAlertStyle buttonTitles:@[@"OK", @"Cancel"] view:self completion:^(NSModalResponse response, NSString *password) {
      KBRSecretEntryRes *entry = [[KBRSecretEntryRes alloc] init];
      entry.text = response == NSAlertFirstButtonReturn ? password : nil;
      entry.canceled = response == NSAlertSecondButtonReturn;
      completion(nil, entry);
    }];
  }];

  [_service.client registerMethod:@"keybase.1.secretUi.getNewPassphrase" sessionId:0 requestHandler:^(NSNumber *messageId, NSString *method, NSArray *params, MPRequestCompletion completion) {
    KBRGetNewPassphraseRequestParams *requestParams = [[KBRGetNewPassphraseRequestParams alloc] initWithParams:params];
    [KBAlert promptForInputWithTitle:requestParams.pinentryPrompt description:requestParams.pinentryDesc secure:YES style:NSCriticalAlertStyle buttonTitles:@[@"OK", @"Cancel"] view:self completion:^(NSModalResponse response, NSString *password) {
      NSString *text = response == NSAlertFirstButtonReturn ? password : nil;
      completion(nil, text);
    }];
  }];

  [_service.client registerMethod:@"keybase.1.secretUi.getKeybasePassphrase" sessionId:0 requestHandler:^(NSNumber *messageId, NSString *method, NSArray *params, MPRequestCompletion completion) {
    DDLogDebug(@"Password prompt: %@", params);
    KBRGetKeybasePassphraseRequestParams *requestParams = [[KBRGetKeybasePassphraseRequestParams alloc] initWithParams:params];
    [KBAlert promptForInputWithTitle:@"Passphrase" description:NSStringWithFormat(@"What's your passphrase (for user %@)?", requestParams.username) secure:YES style:NSCriticalAlertStyle buttonTitles:@[@"OK", @"Cancel"] view:self completion:^(NSModalResponse response, NSString *password) {
      NSString *text = response == NSAlertFirstButtonReturn ? password : nil;
      completion(nil, text);
    }];
  }];

  [_service.client registerMethod:@"keybase.1.logUi.log" sessionId:0 requestHandler:^(NSNumber *messageId, NSString *method, NSArray *params, MPRequestCompletion completion) {
    KBRLogRequestParams *requestParams = [[KBRLogRequestParams alloc] initWithParams:params];
    for (id<KBAppViewDelegate> delegate in gself.delegates) [delegate appView:self didLogMessage:requestParams.text.data];
    completion(nil, nil);
  }];

  [_service.client open];
}

// If we errored while checking status
- (void)setStatusError:(NSError *)error {
  GHWeakSelf gself = self;

  if (gself.mode == KBAppViewModeInProgress) {
    NSMutableDictionary *errorInfo = [error.userInfo mutableCopy];
    errorInfo[NSLocalizedRecoveryOptionsErrorKey] = @[@"Retry", @"Quit"];
    error = [NSError errorWithDomain:error.domain code:error.code userInfo:errorInfo];

    [AppDelegate setError:error sender:self completion:^(NSModalResponse res) {
      // Option to retry or quit if we are trying to get status for the first time
      if (res == NSAlertFirstButtonReturn) {
        [self checkStatus];
      } else {
        [AppDelegate.sharedDelegate quitWithPrompt:YES sender:self];
      }
    }];
  } else {
    [AppDelegate setError:error sender:self];
  }
}

- (void)setContentView:(YOView *)contentView mode:(KBAppViewMode)mode {
  _mode = mode;
  _toolbar.hidden = (mode != KBAppViewModeMain);
  [_contentView removeFromSuperview];
  _contentView = contentView;
  if (_contentView) [self addSubview:_contentView];
  if ([_contentView respondsToSelector:@selector(viewDidAppear:)]) [(id)_contentView viewDidAppear:NO];
  [self setNeedsLayout];
}

- (KBLoginView *)loginView {
  GHWeakSelf gself = self;
  if (!_loginView) {
    _loginView = [[KBLoginView alloc] init];
    _loginView.delegate = self;
    _loginView.signupButton.targetBlock = ^{
      [gself showSignup];
    };
  }

  // TODO reset progress?
  //[_loginView.navigation setProgressEnabled:NO];
  _loginView.client = _service.client;
  return _loginView;
}

- (KBSignupView *)signupView {
  GHWeakSelf gself = self;
  if (!_signupView) {
    _signupView = [[KBSignupView alloc] init];
    _signupView.delegate = self;
    _signupView.loginButton.targetBlock = ^{
      [gself showLogin];
    };
  }
  _signupView.client = _service.client;
  return _signupView;
}

- (void)showInProgress:(NSString *)title {
  KBAppProgressView *view = [[KBAppProgressView alloc] init];
  [view enableProgressWithTitle:title];
  KBNavigationView *navigation = [[KBNavigationView alloc] initWithView:view title:_title];
  [self setContentView:navigation mode:KBAppViewModeInProgress];
}

- (void)showInstaller:(KBInstaller *)installer {
  KBInstallerView *view = [[KBInstallerView alloc] init];
  [view setInstaller:installer];
  view.completion = ^() {
    [self showInProgress:@"Loading"];
    [self connect];
  };
  KBNavigationView *navigation = [[KBNavigationView alloc] initWithView:view title:_title];
  [self setContentView:navigation mode:KBAppViewModeInstaller];
}

- (void)showLogin {
  KBLoginView *view = [self loginView];
  [view removeFromSuperview];
  KBNavigationView *navigation = [[KBNavigationView alloc] initWithView:view title:_title];
  [self setContentView:navigation mode:KBAppViewModeLogin];
}

- (void)showSignup {
  KBSignupView *view = [self signupView];
  [view removeFromSuperview];
  KBNavigationView *navigation = [[KBNavigationView alloc] initWithView:view title:_title];
  [self setContentView:navigation mode:KBAppViewModeSignup];
}

- (void)showUsers {
  if (!_usersAppView) _usersAppView = [[KBUsersAppView alloc] init];
  _usersAppView.client = _service.client;
  [self setContentView:_usersAppView mode:KBAppViewModeMain];
}

- (void)showProfile {
  NSAssert(_user, @"No user");
  if (!_userProfileView) _userProfileView = [[KBUserProfileView alloc] init];
  [_userProfileView setUsername:_user.username client:_service.client];
  [self setContentView:_userProfileView mode:KBAppViewModeMain];
  _toolbar.selectedItem = KBAppViewItemProfile;
}

- (void)showDevices {
  if (!_devicesAppView) _devicesAppView = [[KBDevicesAppView alloc] init];
  _devicesAppView.client = _service.client;
  [_devicesAppView reload];
  [self setContentView:_devicesAppView mode:KBAppViewModeMain];
}

- (void)showFolders {
  if (!_foldersAppView) _foldersAppView = [[KBFoldersAppView alloc] init];
  _foldersAppView.client = _service.client;
  [_foldersAppView reload];
  [self setContentView:_foldersAppView mode:KBAppViewModeMain];
}

- (void)showPGP {
  if (!_PGPAppView) _PGPAppView = [[KBPGPAppView alloc] init];
  _PGPAppView.client = _service.client;
  [self setContentView:_PGPAppView mode:KBAppViewModeMain];
}

- (void)logout:(BOOL)prompt {
  GHWeakSelf gself = self;
  dispatch_block_t logout = ^{
    [self showInProgress:@"Logging out"];
    KBRLoginRequest *login = [[KBRLoginRequest alloc] initWithClient:gself.service.client];
    [login logout:^(NSError *error) {
      if (error) {
        [AppDelegate setError:error sender:self];
      }
      [self checkStatus];
    }];
  };

  if (prompt) {
    [KBAlert yesNoWithTitle:@"Log Out" description:@"Are you sure you want to log out?" yes:@"Log Out" view:self completion:^(BOOL yes) {
      if (yes) logout();
    }];
  } else {
    logout();
  }
}

- (void)checkStatus {
  GHWeakSelf gself = self;
  [_service checkStatus:^(NSError *error, KBRGetCurrentStatusRes *status, KBRConfig *config) {
    if (error) {
      [self setStatusError:error];
      return;
    }
    for (id<KBAppViewDelegate> delegate in gself.delegates) [delegate appView:self didCheckStatusWithConfig:config status:status];

    [self updateStatus:status];
    // TODO reload current view if coming back from disconnect?
    [NSNotificationCenter.defaultCenter postNotificationName:KBStatusDidChangeNotification object:nil userInfo:@{@"config": config, @"status": status}];
  }];
}

/*
- (void)setConfig:(KBRConfig *)config {
  _config = config;
  NSString *host = _config.serverURI;
  // TODO Directly accessing API client should eventually go away (everything goes to daemon)
  if ([host isEqualTo:@"https://api.keybase.io:443"]) host = @"https://keybase.io";
  AppDelegate.sharedDelegate.APIClient = [[KBAPIClient alloc] initWithAPIHost:host];
}
 */

- (NSString *)APIURLString:(NSString *)path {
  NSString *host = _service.config.serverURI;
  if ([host isEqualTo:@"https://api.keybase.io:443"]) host = @"https://keybase.io";
  return [NSString stringWithFormat:@"%@/%@", host, path];
}

- (void)updateStatus:(KBRGetCurrentStatusRes *)status {
  self.user = status.user;

  [self.sourceView.statusView setStatus:status];
  [self.toolbar setUser:status.user];

  if (status.loggedIn && status.user) {
    // Show profile if logging in or we are already showing profile, refresh it
    if (_mode != KBAppViewModeMain || _toolbar.selectedItem == KBAppViewItemProfile) {
      [self showProfile];
    }
  } else {
    [self showLogin];
  }

  for (id<KBAppViewDelegate> delegate in _delegates) [delegate appViewDidUpdateStatus:self];
}

- (void)setUser:(KBRUser *)user {
  _user = user;
  [self.loginView setUsername:user.username];
}

- (void)signupViewDidSignup:(KBSignupView *)signupView {
  [self showInProgress:@"Loading"];
  [self checkStatus];
}

- (void)loginViewDidLogin:(KBLoginView *)loginView {
  [self showInProgress:@"Loading"];
  [self checkStatus];
}

- (void)RPClientWillConnect:(KBRPClient *)RPClient {
  for (id<KBAppViewDelegate> delegate in _delegates) [delegate appView:self willConnectWithClient:_service.client];
}

- (void)RPClientDidConnect:(KBRPClient *)RPClient {
  for (id<KBAppViewDelegate> delegate in _delegates) [delegate appView:self didConnectWithClient:_service.client];
  [self checkStatus];
}

- (void)RPClientDidDisconnect:(KBRPClient *)RPClient {
  for (id<KBAppViewDelegate> delegate in _delegates) [delegate appView:self didDisconnectWithClient:_service.client];
  [NSNotificationCenter.defaultCenter postNotificationName:KBStatusDidChangeNotification object:nil userInfo:@{}];
}

- (void)RPClient:(KBRPClient *)RPClient didErrorOnConnect:(NSError *)error connectAttempt:(NSInteger)connectAttempt {
  //if (connectAttempt == 1) [AppDelegate.sharedDelegate setFatalError:error]; // Show error on first error attempt
  for (id<KBAppViewDelegate> delegate in _delegates) [delegate appView:self didErrorOnConnect:error connectAttempt:connectAttempt];
  [NSNotificationCenter.defaultCenter postNotificationName:KBStatusDidChangeNotification object:nil userInfo:@{}];
}

- (void)appToolbar:(KBAppToolbar *)appToolbar didSelectItem:(KBAppViewItem)item {
  switch (item) {
    case KBAppViewItemNone:
      NSAssert(NO, @"Can't select none");
      break;
    case KBAppViewItemDevices:
      [self showDevices];
      break;
    case KBAppViewItemFolders:
      [self showFolders];
      break;
    case KBAppViewItemProfile:
      [self showProfile];
      break;
    case KBAppViewItemUsers:
      [self showUsers];
      break;
    case KBAppViewItemPGP:
      [self showPGP];
      break;
  }
}

- (KBWindow *)createWindow {
  NSAssert(!self.superview, @"Already has superview");
  KBWindow *window = [KBWindow windowWithContentView:self size:CGSizeMake(800, 600) retain:YES];
  window.minSize = CGSizeMake(600, 600);
  //window.restorable = YES;
  //window.maxSize = CGSizeMake(600, 900);
  window.delegate = self; // Overrides default delegate
  window.titleVisibility = NO;
  window.styleMask = NSClosableWindowMask | NSFullSizeContentViewWindowMask | NSTitledWindowMask | NSResizableWindowMask | NSMiniaturizableWindowMask;

  window.backgroundColor = KBAppearance.currentAppearance.secondaryBackgroundColor;
  window.restorable = YES;
  //window.restorationClass = self.class;
  //window.navigation.titleView = [KBTitleView titleViewWithTitle:@"Keybase" navigation:window.navigation];
  //[window setLevel:NSStatusWindowLevel];
  return window;
}

- (NSRect)window:(NSWindow *)window willPositionSheet:(NSWindow *)sheet usingRect:(NSRect)rect {
  CGFloat sheetPosition = 0;
  if (_mode == KBAppViewModeMain) sheetPosition = 74;
  else sheetPosition = 33;
  rect.origin.y += -sheetPosition;
  return rect;
}

- (BOOL)windowShouldClose:(id)sender {
  [AppDelegate.sharedDelegate quitWithPrompt:YES sender:self];
  return NO;
}

- (KBWindow *)openWindow {
  NSAssert(!self.window, @"Already has window");
  KBWindow *window = [self createWindow];
  [window center];
  [window makeKeyAndOrderFront:nil];
  return window;
}

//- (void)encodeRestorableStateWithCoder:(NSCoder *)coder { }
//- (void)restoreStateWithCoder:(NSCoder *)coder { }
//invalidateRestorableState

//+ (void)restoreWindowWithIdentifier:(NSString *)identifier state:(NSCoder *)state completionHandler:(void (^)(NSWindow *window, NSError *error))completionHandler {
//  KBAppView *appView = [[KBAppView alloc] init];
//  NSWindow *window = [appView createWindow];
//  completionHandler(window, nil);
//}

@end
