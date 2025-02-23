//
//  LightViewController.h
//

#import <UIKit/UIKit.h>
#import <GameKit/GameKit.h>
#import <StoreKit/StoreKit.h>
#import <caml/mlvalues.h>
#import "LightActivityIndicator.h"

#define SYSTEM_VERSION_LESS_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)

@protocol OrientationDelegate
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;
- (BOOL)shouldAutorotate;
- (NSUInteger)supportedInterfaceOrientations;
@end

@protocol RemoteNotificationsRegisterDelegate
-(void)didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken;
-(void)didFailToRegisterForRemoteNotificationsWithError:(NSError *)error;
@end

@interface LightViewController : UIViewController <GKAchievementViewControllerDelegate, GKLeaderboardViewControllerDelegate, SKPaymentTransactionObserver, SKProductsRequestDelegate> {
	id<OrientationDelegate> _orientationDelegate;
	id<RemoteNotificationsRegisterDelegate> _rnDelegate;
	LightActivityIndicatorView*	activityIndicator;

	value *bgDelayedCallback;
	NSTimer *bgDelayedCallbackTimer;
	NSTimeInterval bgCallbackDelay;
	UIBackgroundTaskIdentifier bgTaskId;
@public
	// Payments need refactoring for deprecated api.
	// Лучше будет переписать их через Callback механизм, так как их не может быть много
	value payment_success_cb;
	value payment_error_cb;
	//value remote_notification_request_success_cb;
	//value remote_notification_request_error_cb;
}

+(LightViewController*)sharedInstance;
+(void)addExceptionInfo:(NSString*)info;
+(NSString *)version;
-(void)becomeActive;
-(void)resignActive;
-(void)background;
-(void)foreground;
-(void)showLeaderboard;
-(void)showAchievements;
-(void)showActivityIndicator:(LightActivityIndicatorView *)indicator;
-(void)hideActivityIndicator;
+(void)setSupportEmail:(NSString*)email;
- (void)showKeyboard:(value)visible maxCnt:(value)maxCnt size:(value)size  updateCallback:(value)updateCallback returnCallback:(value)returnCallback initString:(value)initString;
- (void)setBackgroundCallback:(value)callback withDelay:(long) delay;
- (void)resetBackgroundDelayedCallback;
- (void)runBackgroudDelayerCallback;

-(void)hideKeyboard;
-(void)cleanKeyboard;

@property (nonatomic,retain) id<OrientationDelegate> orientationDelegate;
@property (retain) id<RemoteNotificationsRegisterDelegate> rnDelegate;

@end

/* при модальном показе LightViewController паузит себя, однако он не знает, когда показываемый им контроллер
// дисмиссится, соответственно не может продолжить работу.
// контроллеры, которые мы показыавем поверх должны наследоваться от этого контроллера.
@interface LightViewCompatibleController : UIViewController
@end
*/

void flushErrlog();
void silentUncaughtException(char *exceptionInfo);
