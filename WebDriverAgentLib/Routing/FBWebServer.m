/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBWebServer.h"

#import "RoutingConnection.h"
#import "RoutingHTTPServer.h"

#import "FBCommandHandler.h"
#import "FBErrorBuilder.h"
#import "FBExceptionHandler.h"
#import "FBMjpegServer.h"
#import "FBRouteRequest.h"
#import "FBRuntimeUtils.h"
#import "FBSession.h"
#import "FBTCPSocket.h"
#import "FBUnknownCommands.h"
#import "FBConfiguration.h"
#import "FBLogger.h"
#import "GCDAsyncUdpSocket.h"

#import "XCUIDevice+FBHelpers.h"

static NSString *const FBServerURLBeginMarker = @"ServerURLHere->";
static NSString *const FBServerURLEndMarker = @"<-ServerURLHere";
static NSString *const FBBonjourServiceName = @"WebDriverAgent";
static NSString *const FBBonjourServiceType = @"_wda._tcp.";
static NSString *const FBLocalWDAProxyTargetEnvironmentKey = @"WDA_PROXY_TARGET";
static NSString *const FBLocalWDAProxyDefaultTarget = @"http://127.0.0.1:8200";
static NSTimeInterval const FBLocalWDAProxyTimeout = 10.0;

@interface FBHTTPConnection : RoutingConnection
@end

@implementation FBHTTPConnection

- (void)handleResourceNotFound
{
  [FBLogger logFmt:@"Received request for %@ which we do not handle", self.requestURI];
  [super handleResourceNotFound];
}

@end


@interface FBWebServer () <NSNetServiceDelegate, NSNetServiceBrowserDelegate>
@property (nonatomic, strong) FBExceptionHandler *exceptionHandler;
@property (nonatomic, strong) RoutingHTTPServer *server;
@property (atomic, assign) BOOL keepAlive;
@property (nonatomic, nullable) FBTCPSocket *screenshotsBroadcaster;
@property (nonatomic, nullable, strong) FBMjpegServer *mjpegServer;
@property (nonatomic, nullable, strong) NSNetService *bonjourService;
@property (nonatomic, nullable, strong) NSNetServiceBrowser *bonjourBrowser;
@property (nonatomic, nullable, strong) GCDAsyncUdpSocket *localNetworkProbeSocket;
@end

@implementation FBWebServer

- (void)dealloc
{
  [self stopBonjourService];
  [self stopScreenshotsBroadcaster];
}

+ (NSArray<Class<FBCommandHandler>> *)collectCommandHandlerClasses
{
  NSArray *handlersClasses = FBClassesThatConformsToProtocol(@protocol(FBCommandHandler));
  NSMutableArray *handlers = [NSMutableArray array];
  for (Class aClass in handlersClasses) {
    if ([aClass respondsToSelector:@selector(shouldRegisterAutomatically)]) {
      if (![aClass shouldRegisterAutomatically]) {
        continue;
      }
    }
    [handlers addObject:aClass];
  }
  return handlers.copy;
}

- (void)startServing
{
  [FBLogger logFmt:@"Built at %s %s", __DATE__, __TIME__];
  self.exceptionHandler = [FBExceptionHandler new];
  [self startHTTPServer];
  if ([self.delegate respondsToSelector:@selector(webServerDidStartServing:)]) {
    [self.delegate webServerDidStartServing:self];
  }
  [self initScreenshotsBroadcaster];

  self.keepAlive = YES;
  NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
  while (self.keepAlive &&
         [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);
}

- (void)startHTTPServer
{
  self.server = [[RoutingHTTPServer alloc] init];
  BOOL shouldUseBackgroundRouteQueue = FBConfiguration.shouldUseBackgroundRouteQueue;
  dispatch_queue_t routeQueue = shouldUseBackgroundRouteQueue
    ? dispatch_queue_create("com.facebook.WebDriverAgent.RouteQueue", DISPATCH_QUEUE_SERIAL)
    : dispatch_get_main_queue();
  [self.server setRouteQueue:routeQueue];
#if !OS_OBJECT_USE_OBJC
  if (shouldUseBackgroundRouteQueue) {
    dispatch_release(routeQueue);
  }
#endif
  [self.server setDefaultHeader:@"Server" value:@"WebDriverAgent/1.0"];
  [self.server setDefaultHeader:@"Access-Control-Allow-Origin" value:@"*"];
  [self.server setDefaultHeader:@"Access-Control-Allow-Headers" value:@"Content-Type, X-Requested-With"];
  [self.server setConnectionClass:[FBHTTPConnection self]];

  [self registerRouteHandlers:[self.class collectCommandHandlerClasses]];
  [self registerServerKeyRouteHandlers];

  NSRange serverPortRange = FBConfiguration.bindingPortRange;
  NSString *bindingIP = FBConfiguration.bindingIPAddress;
  if (bindingIP != nil) {
    [self.server setInterface:bindingIP];
    [FBLogger logFmt:@"Using custom binding IP address: %@", bindingIP];
  }

  NSError *error;
  BOOL serverStarted = NO;

  for (NSUInteger index = 0; index < serverPortRange.length; index++) {
    NSInteger port = serverPortRange.location + index;
    [self.server setPort:(UInt16)port];

    serverStarted = [self attemptToStartServer:self.server onPort:port withError:&error];
    if (serverStarted) {
      break;
    }

    [FBLogger logFmt:@"Failed to start web server on port %ld with error %@", (long)port, [error description]];
  }

  if (!serverStarted) {
    [FBLogger logFmt:@"Last attempt to start web server failed with error %@", [error description]];
    abort();
  }

  [self publishBonjourService];
  [self startBonjourBrowser];
  [self sendLocalNetworkPermissionProbe];

  NSString *serverHost = bindingIP ?: ([XCUIDevice sharedDevice].fb_wifiIPAddress ?: @"127.0.0.1");
  [FBLogger logFmt:@"%@http://%@:%d%@", FBServerURLBeginMarker, serverHost, [self.server port], FBServerURLEndMarker];
}

- (void)publishBonjourService
{
  if (self.bonjourService != nil) {
    return;
  }

  UInt16 port = [self.server port];
  if (port == 0) {
    [FBLogger log:@"Cannot publish WDA Bonjour service before HTTP server port is assigned"];
    return;
  }

  self.bonjourService = [[NSNetService alloc] initWithDomain:@""
                                                        type:FBBonjourServiceType
                                                        name:FBBonjourServiceName
                                                        port:(int)port];
  self.bonjourService.delegate = self;
  [self.bonjourService publish];
  [FBLogger logFmt:@"Published WDA Bonjour service %@ on port %d", FBBonjourServiceType, port];
}

- (void)startBonjourBrowser
{
  if (self.bonjourBrowser != nil) {
    return;
  }

  self.bonjourBrowser = [[NSNetServiceBrowser alloc] init];
  self.bonjourBrowser.delegate = self;
  [self.bonjourBrowser searchForServicesOfType:FBBonjourServiceType inDomain:@""];
  [FBLogger logFmt:@"Started WDA Bonjour browser for %@", FBBonjourServiceType];
}

- (void)sendLocalNetworkPermissionProbe
{
  if (self.localNetworkProbeSocket != nil) {
    return;
  }

  self.localNetworkProbeSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:nil
                                                               delegateQueue:dispatch_get_main_queue()];

  NSError *error = nil;
  if (![self.localNetworkProbeSocket enableBroadcast:YES error:&error]) {
    [FBLogger logFmt:@"Failed to enable WDA local network probe broadcast: %@", error.description];
    self.localNetworkProbeSocket = nil;
    return;
  }

  NSData *payload = [@"wda-local-network-probe" dataUsingEncoding:NSUTF8StringEncoding];
  [self.localNetworkProbeSocket sendData:payload
                                  toHost:@"255.255.255.255"
                                    port:9
                             withTimeout:1
                                     tag:0];
  [FBLogger log:@"Sent WDA local network permission probe"];
}

- (void)stopBonjourService
{
  [self.bonjourBrowser stop];
  self.bonjourBrowser.delegate = nil;
  self.bonjourBrowser = nil;

  [self.bonjourService stop];
  self.bonjourService.delegate = nil;
  self.bonjourService = nil;

  [self.localNetworkProbeSocket close];
  self.localNetworkProbeSocket = nil;
}

- (void)netServiceDidPublish:(NSNetService *)sender
{
  [FBLogger logFmt:@"WDA Bonjour service published as %@.%@", sender.name, sender.type];
}

- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary<NSString *, NSNumber *> *)errorDict
{
  [FBLogger logFmt:@"Failed to publish WDA Bonjour service %@: %@", sender.type, errorDict];
}

- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)browser
{
  [FBLogger logFmt:@"WDA Bonjour browser started for %@", FBBonjourServiceType];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didNotSearch:(NSDictionary<NSString *, NSNumber *> *)errorDict
{
  [FBLogger logFmt:@"Failed to browse WDA Bonjour service %@: %@", FBBonjourServiceType, errorDict];
}

- (void)initScreenshotsBroadcaster
{
  [self readMjpegSettingsFromEnv];
  self.mjpegServer = [[FBMjpegServer alloc] init];
  self.screenshotsBroadcaster = [[FBTCPSocket alloc]
                                 initWithPort:(uint16_t)FBConfiguration.mjpegServerPort];
  self.screenshotsBroadcaster.delegate = self.mjpegServer;
  NSError *error;
  if (![self.screenshotsBroadcaster startWithError:&error]) {
    [FBLogger logFmt:@"Cannot init screenshots broadcaster service on port %@. Original error: %@", @(FBConfiguration.mjpegServerPort), error.description];
    [self.mjpegServer stopStreaming];
    self.mjpegServer = nil;
    self.screenshotsBroadcaster = nil;
  }
}

- (void)stopScreenshotsBroadcaster
{
  if (nil == self.screenshotsBroadcaster) {
    self.mjpegServer = nil;
    return;
  }

  id<FBTCPSocketDelegate> delegate = self.screenshotsBroadcaster.delegate;
  if ([(NSObject *)delegate respondsToSelector:@selector(stopStreaming)]) {
    [(FBMjpegServer *)delegate stopStreaming];
  }
  self.screenshotsBroadcaster.delegate = nil;
  [self.screenshotsBroadcaster stop];
  self.screenshotsBroadcaster = nil;
  self.mjpegServer = nil;
}

- (void)readMjpegSettingsFromEnv
{
  NSDictionary *env = NSProcessInfo.processInfo.environment;
  NSString *scalingFactor = [env objectForKey:@"MJPEG_SCALING_FACTOR"];
  if (scalingFactor != nil && [scalingFactor length] > 0) {
    [FBConfiguration setMjpegScalingFactor:[scalingFactor floatValue]];
  }
  NSString *screenshotQuality = [env objectForKey:@"MJPEG_SERVER_SCREENSHOT_QUALITY"];
  if (screenshotQuality != nil && [screenshotQuality length] > 0) {
    [FBConfiguration setMjpegServerScreenshotQuality:[screenshotQuality integerValue]];
  }
}

- (void)stopServing
{
  [FBSession.activeSession kill];
  [self stopBonjourService];
  [self stopScreenshotsBroadcaster];
  if (self.server.isRunning) {
    [self.server stop:NO];
  }
  self.server = nil;
  self.exceptionHandler = nil;
  self.keepAlive = NO;
}

- (BOOL)attemptToStartServer:(RoutingHTTPServer *)server onPort:(NSInteger)port withError:(NSError **)error
{
  server.port = (UInt16)port;
  NSError *innerError = nil;
  BOOL started = [server start:&innerError];
  if (!started) {
    if (!error) {
      return NO;
    }

    NSString *description = @"Unknown Error when Starting server";
    if ([innerError.domain isEqualToString:NSPOSIXErrorDomain] && innerError.code == EADDRINUSE) {
      description = [NSString stringWithFormat:@"Unable to start web server on port %ld", (long)port];
    }
    return
    [[[[FBErrorBuilder builder]
       withDescription:description]
      withInnerError:innerError]
     buildError:error];
  }
  return YES;
}

- (NSURL *)localWDAProxyBaseURL
{
  NSString *target = NSProcessInfo.processInfo.environment[FBLocalWDAProxyTargetEnvironmentKey];
  if (target.length == 0) {
    target = FBLocalWDAProxyDefaultTarget;
  }
  if (![target hasSuffix:@"/"]) {
    target = [target stringByAppendingString:@"/"];
  }
  return [NSURL URLWithString:target];
}

- (void)respondWithLocalWDAProxyError:(NSString *)message
                             response:(RouteResponse *)response
                            statusCode:(NSInteger)statusCode
{
  response.statusCode = statusCode;
  [response setHeader:@"Content-Type" value:@"application/json;charset=UTF-8"];
  NSDictionary *payload = @{
    @"value": @{
      @"error": @"local_wda_proxy_error",
      @"message": message ?: @"Unknown local WDA proxy error"
    }
  };
  NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
  [response respondWithData:data ?: [NSData data]];
}

- (void)proxyLocalWDAPath:(NSString *)upstreamPath
                 response:(RouteResponse *)response
{
  NSURL *baseURL = [self localWDAProxyBaseURL];
  NSURL *upstreamURL = [NSURL URLWithString:upstreamPath relativeToURL:baseURL];
  if (upstreamURL == nil) {
    [self respondWithLocalWDAProxyError:@"Invalid local WDA proxy target URL"
                               response:response
                              statusCode:500];
    return;
  }

  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:upstreamURL
                                                         cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                     timeoutInterval:FBLocalWDAProxyTimeout];
  request.HTTPMethod = @"GET";

  NSURLSessionConfiguration *configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration;
  configuration.timeoutIntervalForRequest = FBLocalWDAProxyTimeout;
  configuration.timeoutIntervalForResource = FBLocalWDAProxyTimeout;
  NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];

  dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
  __block NSData *responseData = nil;
  __block NSURLResponse *urlResponse = nil;
  __block NSError *requestError = nil;

  NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                          completionHandler:^(NSData *data, NSURLResponse *taskResponse, NSError *error) {
    responseData = data;
    urlResponse = taskResponse;
    requestError = error;
    dispatch_semaphore_signal(semaphore);
  }];
  [task resume];

  long waitResult = dispatch_semaphore_wait(
    semaphore,
    dispatch_time(DISPATCH_TIME_NOW, (int64_t)(FBLocalWDAProxyTimeout * NSEC_PER_SEC))
  );
  [session finishTasksAndInvalidate];

  if (waitResult != 0) {
    [task cancel];
    [self respondWithLocalWDAProxyError:[NSString stringWithFormat:@"Timed out proxying %@", upstreamURL.absoluteString]
                               response:response
                              statusCode:504];
    return;
  }

  if (requestError != nil) {
    [self respondWithLocalWDAProxyError:requestError.localizedDescription
                               response:response
                              statusCode:502];
    return;
  }

  if (![urlResponse isKindOfClass:NSHTTPURLResponse.class]) {
    [self respondWithLocalWDAProxyError:@"Local WDA proxy target returned a non-HTTP response"
                               response:response
                              statusCode:502];
    return;
  }

  NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)urlResponse;
  id contentType = httpResponse.allHeaderFields[@"Content-Type"];
  if ([contentType isKindOfClass:NSString.class]) {
    [response setHeader:@"Content-Type" value:(NSString *)contentType];
  }
  response.statusCode = httpResponse.statusCode;
  [response respondWithData:responseData ?: [NSData data]];
}

- (void)registerLocalWDAProxyRouteHandlers
{
  __weak typeof(self) weakSelf = self;
  NSDictionary<NSString *, NSString *> *routes = @{
    @"/proxy/status": @"status",
    @"/proxy/screenshot": @"screenshot",
    @"/proxy/source": @"source",
  };

  for (NSString *routePath in routes) {
    NSString *upstreamPath = routes[routePath];
    [self.server get:routePath withBlock:^(RouteRequest *request, RouteResponse *response) {
      __strong typeof(weakSelf) strongSelf = weakSelf;
      if (strongSelf == nil) {
        return;
      }
      [strongSelf proxyLocalWDAPath:upstreamPath response:response];
    }];
  }
}

- (void)registerNetworkDiagnosticsRouteHandlers
{
  __weak typeof(self) weakSelf = self;
  [self.server get:@"/wda/network" withBlock:^(RouteRequest *request, RouteResponse *response) {
    __strong typeof(weakSelf) strongSelf = weakSelf;
    if (strongSelf == nil) {
      return;
    }

    NSString *serverInterface = strongSelf.server.interface;
    NSString *wifiIPAddress = [XCUIDevice sharedDevice].fb_wifiIPAddress;
    NSDictionary *payload = @{
      @"value": @{
        @"port": @([strongSelf.server port]),
        @"serverInterface": serverInterface ?: NSNull.null,
        @"listenScope": serverInterface == nil ? @"all" : @"custom",
        @"wifiIPAddress": wifiIPAddress ?: NSNull.null,
        @"bonjourServiceType": FBBonjourServiceType,
        @"bonjourServiceName": FBBonjourServiceName,
        @"bonjourServiceConfigured": @(strongSelf.bonjourService != nil),
      }
    };

    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    [response setHeader:@"Content-Type" value:@"application/json;charset=UTF-8"];
    [response respondWithData:data ?: [NSData data]];
  }];
}

- (void)registerRouteHandlers:(NSArray *)commandHandlerClasses
{
  __weak typeof(self) weakSelf = self;
  for (Class<FBCommandHandler> commandHandler in commandHandlerClasses) {
    NSArray *routes = [commandHandler routes];
    for (FBRoute *route in routes) {
      [self.server handleMethod:route.verb withPath:route.path block:^(RouteRequest *request, RouteResponse *response) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (nil == strongSelf) {
          return;
        }
        NSDictionary *arguments = [NSJSONSerialization JSONObjectWithData:request.body options:NSJSONReadingMutableContainers error:NULL];
        FBRouteRequest *routeParams = [FBRouteRequest
          routeRequestWithURL:request.url
          parameters:request.params
          arguments:arguments ?: @{}
        ];

        [FBLogger verboseLog:routeParams.description];

        @try {
          [route mountRequest:routeParams intoResponse:response];
        }
        @catch (NSException *exception) {
          [strongSelf handleException:exception forResponse:response];
        }
      }];
    }
  }
}

- (void)handleException:(NSException *)exception forResponse:(RouteResponse *)response
{
  [self.exceptionHandler handleException:exception forResponse:response];
}

- (void)registerServerKeyRouteHandlers
{
  [self.server get:@"/health" withBlock:^(RouteRequest *request, RouteResponse *response) {
    [response respondWithString:@"<!DOCTYPE html><html><title>Health Check</title><body><p>I-AM-ALIVE</p></body></html>"];
  }];

  NSString *calibrationPage = @"<html>"
  "<title>{\"x\":null,\"y\":null}</title>"
  "<header>"
  "<script>document.addEventListener(\"click\",function(e){document.title=JSON.stringify({x:e.clientX,y:e.clientY})})</script>"
  "</header>"
  "</html>";
  [self.server get:@"/calibrate" withBlock:^(RouteRequest *request, RouteResponse *response) {
    [response respondWithString:calibrationPage];
  }];

  __weak typeof(self) weakSelf = self;
  [self.server get:@"/wda/shutdown" withBlock:^(RouteRequest *request, RouteResponse *response) {
    __strong typeof(weakSelf) strongSelf = weakSelf;
    if (nil == strongSelf) {
      return;
    }
    [response respondWithString:@"Shutting down"];
    [strongSelf.delegate webServerDidRequestShutdown:strongSelf];
  }];

  [self registerLocalWDAProxyRouteHandlers];
  [self registerNetworkDiagnosticsRouteHandlers];

  [self registerRouteHandlers:@[FBUnknownCommands.class]];
}

@end
