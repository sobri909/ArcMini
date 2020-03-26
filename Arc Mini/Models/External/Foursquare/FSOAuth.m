//
// Copyright 2013 Foursquare
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "FSOAuth.h"

#define kFoursquareOAuthRequiredVersion @"20130509"
#define kFoursquareAppStoreURL @"https://itunes.apple.com/app/foursquare/id306934924?mt=8"
#define kFoursquareAppStoreID @306934924

#if (__IPHONE_OS_VERSION_MAX_ALLOWED >= 60000)
#import <StoreKit/StoreKit.h>
#endif

#if (__IPHONE_OS_VERSION_MAX_ALLOWED >= 90000)
#import <SafariServices/SafariServices.h>
#endif

#if (__IPHONE_OS_VERSION_MAX_ALLOWED >= 90000)
@interface FSOAuth () <SFSafariViewControllerDelegate>

@property (nonatomic) SFSafariViewController *safariVC;

@end
#endif

@implementation FSOAuth

+ (FSOAuth *)shared {
    static FSOAuth *oauthInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        oauthInstance = [[FSOAuth alloc] init];
    });
    
    return oauthInstance;
}

- (FSOAuthStatusCode)authorizeUserUsingClientId:(NSString *)clientID
                        nativeURICallbackString:(NSString *)nativeURICallbackString
                     universalURICallbackString:(NSString *)universalURICallbackString
                           allowShowingAppStore:(BOOL)allowShowingAppStore
                      presentFromViewController:(UIViewController *)presentFromViewController {
    if ([clientID length] <= 0) {
        return FSOAuthStatusErrorInvalidClientID;
    }

    UIApplication *sharedApplication = [UIApplication sharedApplication];
    BOOL hasNativeCallback = ([nativeURICallbackString length] > 0);
    BOOL hasUniversalCallback = ([universalURICallbackString length] > 0);
    
    if (!hasNativeCallback && !hasUniversalCallback) {
        return FSOAuthStatusErrorInvalidCallback;
    }

    if (hasUniversalCallback) {
        NSString *urlScheme = [[NSURL URLWithString:universalURICallbackString] scheme];
        if (![urlScheme isEqualToString:@"http"]
            && ![urlScheme isEqualToString:@"https"]) {
            return FSOAuthStatusErrorInvalidCallback;
        }
    }

    BOOL isOnIOS9OrLater = NO;
#if (__IPHONE_OS_VERSION_MAX_ALLOWED >= 90000)
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    if ([processInfo respondsToSelector:@selector(isOperatingSystemAtLeastVersion:)]) {
        NSOperatingSystemVersion minVersion;
        minVersion.majorVersion = 9;
        minVersion.minorVersion = 0;
        minVersion.patchVersion = 0;
        if ([processInfo isOperatingSystemAtLeastVersion:minVersion]) {
            isOnIOS9OrLater = YES;
        }
    }
#endif
    
    if (!isOnIOS9OrLater && !hasNativeCallback) {
        return FSOAuthStatusErrorInvalidCallback;
    }

    if (!isOnIOS9OrLater) {
        if (![sharedApplication canOpenURL:[NSURL URLWithString:@"foursquare://"]]) {
            if (allowShowingAppStore) {
                [self launchAppStoreOrShowStoreKitModalFromViewController:presentFromViewController];
            }
            
            return FSOAuthStatusErrorFoursquareNotInstalled;
        }
    }
    
    NSURL *authURL = nil;
    
    if (isOnIOS9OrLater) {
        NSString *urlEncodedCallbackString = nil;
        if (hasUniversalCallback) {
            urlEncodedCallbackString = [self urlEncodedStringForString:universalURICallbackString];
        }
        else {
            urlEncodedCallbackString = [self urlEncodedStringForString:nativeURICallbackString];
        }
        
        authURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://foursquare.com/native/oauth2/authenticate?client_id=%@&redirect_uri=%@&response_type=code", clientID, urlEncodedCallbackString]];
        
#if (__IPHONE_OS_VERSION_MAX_ALLOWED >= 90000)
        self.safariVC = [[SFSafariViewController alloc] initWithURL:authURL];
        self.safariVC.delegate = self;
        
        [presentFromViewController presentViewController:self.safariVC
                                                animated:YES
                                              completion:nil];
#else
        [sharedApplication openURL:authURL];
#endif
    }
    else {
        NSString *urlEncodedCallbackString = [self urlEncodedStringForString:nativeURICallbackString];
        
        authURL = [NSURL URLWithString:[NSString stringWithFormat:@"foursquareauth://authorize?client_id=%@&v=%@&redirect_uri=%@", clientID, kFoursquareOAuthRequiredVersion, urlEncodedCallbackString]];
        
        if (![sharedApplication canOpenURL:authURL]) {
            if (allowShowingAppStore) {
                [self launchAppStoreOrShowStoreKitModalFromViewController:presentFromViewController];
            }
            
            return FSOAuthStatusErrorFoursquareOAuthNotSupported;
        }
        
        [sharedApplication openURL:authURL];
    }
    
    return FSOAuthStatusSuccess;
}

- (FSOAuthErrorCode)errorCodeForString:(NSString *)value {
    if ([value isEqualToString:@"invalid_request"]) {
        return FSOAuthErrorInvalidRequest;
    }
    else if ([value isEqualToString:@"invalid_client"]) {
        return FSOAuthErrorInvalidClient;
    }
    else if ([value isEqualToString:@"invalid_grant"]) {
        return FSOAuthErrorInvalidGrant;
    }
    else if ([value isEqualToString:@"unauthorized_client"]) {
        return FSOAuthErrorUnauthorizedClient;
    }
    else if ([value isEqualToString:@"unsupported_grant_type"]) {
        return FSOAuthErrorUnsupportedGrantType;
    }
    else {
        return FSOAuthErrorUnknown;
    }
}

- (NSString *)accessCodeForFSOAuthURL:(NSURL *)url error:(FSOAuthErrorCode *)errorCode {
    NSString *accessCode = nil;
    
    if (errorCode != NULL) {
        *errorCode = FSOAuthErrorUnknown;
    }
    
#if (__IPHONE_OS_VERSION_MAX_ALLOWED >= 90000)
    [self.safariVC dismissViewControllerAnimated:YES
                                      completion:nil];
    self.safariVC = nil;
#endif
    
    NSArray *parameterPairs = [[url query] componentsSeparatedByString:@"&"];
    
    for (NSString *pair in parameterPairs) {
        NSArray *keyValue = [pair componentsSeparatedByString:@"="];
        if ([keyValue count] == 2) {
            NSString *param = keyValue[0];
            NSString *value = keyValue[1];
            
            if ([param isEqualToString:@"code"]) {
                accessCode = value;
                
                if (errorCode != NULL) {
                    if (*errorCode == FSOAuthErrorUnknown) { // don't clobber any previously found real error value
                        *errorCode = FSOAuthErrorNone;
                    }
                }
            }
            else if ([param isEqualToString:@"error"]) {
                if (errorCode != NULL) {
                    *errorCode = [self errorCodeForString:value];
                }
            }
        }
    }
    
    return accessCode;
}

- (void)requestAccessTokenForCode:(NSString *)accessCode clientId:(NSString *)clientID callbackURIString:(NSString *)callbackURIString clientSecret:(NSString *)clientSecret completionBlock:(FSTokenRequestCompletionBlock)completionBlock {
    if ([accessCode length] > 0
        && [clientID length] > 0
        && [callbackURIString length] > 0
        && [clientSecret length] > 0) {
        
        NSString *urlEncodedCallbackString = [self urlEncodedStringForString:callbackURIString];
        
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://foursquare.com/oauth2/access_token?client_id=%@&client_secret=%@&grant_type=authorization_code&redirect_uri=%@&code=%@", clientID, clientSecret, urlEncodedCallbackString, accessCode]]];
        
        [self sendAsynchronousRequest:request completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
            if (data && [[response MIMEType] isEqualToString:@"application/json"]) {
                id jsonObj = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
                if ([jsonObj isKindOfClass:[NSDictionary class]]) {
                    NSDictionary *jsonDict = (NSDictionary *)jsonObj;

                    FSOAuthErrorCode errorCode = FSOAuthErrorNone;
                    
                    if (jsonDict[@"error"]) {
                        errorCode = [self errorCodeForString:jsonDict[@"error"]];
                    }
                    
                    completionBlock(jsonDict[@"access_token"], YES, errorCode);
                    return;
                }
            }
            completionBlock(nil, NO, FSOAuthErrorNone);
        }];
    }
}

-(void)launchAppStoreOrShowStoreKitModalFromViewController:(UIViewController *)fromViewController {
#if (__IPHONE_OS_VERSION_MAX_ALLOWED >= 60000)
    if ([SKStoreProductViewController class]) {
        SKStoreProductViewController *storeViewController = [SKStoreProductViewController new];
        storeViewController.delegate = (id<SKStoreProductViewControllerDelegate>)self;
        [storeViewController loadProductWithParameters:@{SKStoreProductParameterITunesItemIdentifier : kFoursquareAppStoreID}
                                       completionBlock:nil];
        
        [fromViewController presentViewController:storeViewController animated:YES completion:nil];
    }
    else
#endif
    {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:kFoursquareAppStoreURL]];
    }
}

#if (__IPHONE_OS_VERSION_MAX_ALLOWED >= 60000)
- (void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController {
    [viewController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}
#endif

- (NSString *)urlEncodedStringForString:(NSString *)string {
    NSString *urlEncodedString = nil;
    // Introduced in iOS 7, -stringByAddingPercentEncodingWithAllowedCharacters: replaces CFURLCreateStringByAddingPercentEscapes (deprecated in iOS 9).
    if ([NSString instancesRespondToSelector:@selector(stringByAddingPercentEncodingWithAllowedCharacters:)]) {
        urlEncodedString = [string stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    }
    else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        urlEncodedString = (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                                                           (CFStringRef)string,
                                                                                                           NULL,
                                                                                                           (CFStringRef)@"!*'();:@&=+$,/?%#[]",
                                                                                                           kCFStringEncodingUTF8);
#pragma clang diagnostic pop
    }
    
    return urlEncodedString;
}

- (void)sendAsynchronousRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLResponse *response, NSData *data, NSError *error))completionHandler
{
    // Introduced in iOS 7, NSURLSession replaces NSURLConnection (deprecated in iOS 9).
    if ([NSURLSession class]) {
        [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (completionHandler) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionHandler(response, data, error);
                });
            }
        }] resume];
    }
    else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:completionHandler];
#pragma clang diagnostic pop
    }
}

#if (__IPHONE_OS_VERSION_MAX_ALLOWED >= 90000)
#pragma mark - SFSafariViewControllerDelegate

- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller {
    if (controller == self.safariVC) {
        self.safariVC = nil;
    }
}
#endif

@end
