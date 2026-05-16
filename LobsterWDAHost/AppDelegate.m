#import "AppDelegate.h"

#import "ViewController.h"

#import <WebDriverAgentLib/FBConfiguration.h>
#import <WebDriverAgentLib/FBDebugLogDelegateDecorator.h>
#import <WebDriverAgentLib/FBWebServer.h>

@interface AppDelegate () <FBWebServerDelegate>

@property (nonatomic, strong) FBWebServer *webServer;
@property (nonatomic, weak) ViewController *viewController;
@property (atomic, assign, getter=isWebServerRunning) BOOL webServerRunning;
@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundTaskIdentifier;
@property (nonatomic, strong) dispatch_queue_t webServerQueue;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
  self.webServerQueue = dispatch_queue_create("app.honey4212.crystal5671.wda-server", DISPATCH_QUEUE_SERIAL);

  ViewController *viewController = [[ViewController alloc] init];
  __weak typeof(self) weakSelf = self;
  viewController.restartHandler = ^{
    [weakSelf restartWebServer];
  };
  self.viewController = viewController;

  self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
  self.window.rootViewController = viewController;
  [self.window makeKeyAndVisible];

  [self configureWebDriverAgent];
  [self beginBackgroundTaskIfNeeded];
  [self startWebServer];
  return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
  [self beginBackgroundTaskIfNeeded];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
  [self updateViewWithMessage:@"Foreground"];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
  [self stopWebServer];
  [self endBackgroundTaskIfNeeded];
}

- (void)configureWebDriverAgent
{
  [FBDebugLogDelegateDecorator decorateXCTestLogger];
  [FBConfiguration setShouldUseBackgroundRouteQueue:YES];
  [FBConfiguration disableRemoteQueryEvaluation];
  [FBConfiguration configureDefaultKeyboardPreferences];
  [FBConfiguration disableApplicationUIInterruptionsHandling];

  NSDictionary<NSString *, NSString *> *environment = NSProcessInfo.processInfo.environment;
  if (environment[@"ENABLE_AUTOMATIC_SCREEN_RECORDINGS"]) {
    [FBConfiguration enableScreenRecordings];
  } else {
    [FBConfiguration disableScreenRecordings];
  }
  if (environment[@"ENABLE_AUTOMATIC_SCREENSHOTS"]) {
    [FBConfiguration enableScreenshots];
  } else {
    [FBConfiguration disableScreenshots];
  }
}

- (void)startWebServer
{
  FBWebServer *server = [[FBWebServer alloc] init];
  server.delegate = self;

  @synchronized (self) {
    if (self.isWebServerRunning) {
      [self updateViewWithMessage:@"Already running"];
      return;
    }

    self.webServerRunning = YES;
    self.webServer = server;
  }

  [self updateViewWithMessage:@"Starting"];
  dispatch_async(self.webServerQueue, ^{
    @synchronized (self) {
      if (self.webServer != server) {
        return;
      }
    }
    [self updateViewWithMessage:@"Running"];
    [server startServing];
    @synchronized (self) {
      if (self.webServer == server) {
        self.webServer = nil;
        self.webServerRunning = NO;
      }
    }
    [self updateViewWithMessage:@"Stopped"];
  });
}

- (void)stopWebServer
{
  FBWebServer *server = nil;
  @synchronized (self) {
    server = self.webServer;
    self.webServer = nil;
    self.webServerRunning = NO;
  }
  [server stopServing];
  [self updateViewWithMessage:@"Stopped"];
}

- (void)restartWebServer
{
  [self stopWebServer];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [self startWebServer];
  });
}

- (void)beginBackgroundTaskIfNeeded
{
  if (self.backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
    return;
  }

  __weak typeof(self) weakSelf = self;
  self.backgroundTaskIdentifier = [UIApplication.sharedApplication beginBackgroundTaskWithName:@"LobsterWDAHost" expirationHandler:^{
    [weakSelf endBackgroundTaskIfNeeded];
  }];
}

- (void)endBackgroundTaskIfNeeded
{
  if (self.backgroundTaskIdentifier == UIBackgroundTaskInvalid) {
    return;
  }
  [UIApplication.sharedApplication endBackgroundTask:self.backgroundTaskIdentifier];
  self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
}

- (void)updateViewWithMessage:(NSString *)message
{
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.viewController updateServiceRunning:self.isWebServerRunning message:message];
  });
}

#pragma mark - FBWebServerDelegate

- (void)webServerDidRequestShutdown:(FBWebServer *)webServer
{
  [webServer stopServing];
}

@end
