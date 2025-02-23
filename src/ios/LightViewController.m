//
//  LightViewController.m
//  DoodleNumbers
//
//  Created by Yury Lasty on 6/24/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "LightViewController.h"
#import "LightAppDelegate.h"
#import "LightView.h"

#import <caml/mlvalues.h>
#import <caml/memory.h>
#import <caml/alloc.h>
#import <caml/callback.h>
#import <caml/threads.h>
#import <caml/fail.h>

#import "mobile_res.h"

@implementation LightViewController

@synthesize orientationDelegate=_orientationDelegate;
@synthesize rnDelegate=_rnDelegae;

static LightViewController *instance = NULL;
static NSString *supportEmail = @"nanofarm@redspell.ru";
UITextField* kbTextField = NULL;
value keyboardCallbackUpdate, keyboardCallbackReturn;
NSString *keyboardFilter;
int maxCountSymbols = 0;

static NSMutableArray *exceptionInfo = nil;

static NSString *errlogPath() {
	return [NSString stringWithFormat:@"%@error-log", NSTemporaryDirectory()];
}

void flushErrlog() {
	NSFileManager *fmngr = [NSFileManager defaultManager];
	NSString *errlog = errlogPath();

	NSLog(@"fmngr %@ %@", fmngr, errlog);

	if ([fmngr fileExistsAtPath:errlog]) {
		NSData *body = [NSData dataWithContentsOfFile:errlog];

		NSString *url = [NSString stringWithFormat:@"http://mobile-errors.redspell.ru/submit?app_name=%@", [[NSBundle mainBundle] bundleIdentifier]];
		NSLog(@"url %@", url);
		NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
		[r setHTTPMethod:@"POST"];
		[r setHTTPBody:body];
		[r setTimeoutInterval:0.5];

		if ([NSURLConnection canHandleRequest:r]) {
			NSURLResponse *response = nil;
			NSError *err = nil;
			[NSURLConnection sendSynchronousRequest:r returningResponse:&response error:&err];

			if (err == nil && [response respondsToSelector:@selector(statusCode)] && [response statusCode] == 200) {
				[fmngr removeItemAtPath:errlog error:nil];
			}
		};
	}
}

/*void mlMailUncaughtException(const char* exn, int bc, char** bv) {
        NSBundle *bundle = [NSBundle mainBundle];
        NSString *subj = [bundle localizedStringForKey:@"exception_email_subject" value:@"Error report '%@'" table:nil];
  subj = [NSString stringWithFormat:subj, [bundle objectForInfoDictionaryKey: @"CFBundleDisplayName"]];
        UIDevice * dev = [UIDevice currentDevice];
        NSString *appVersion = [bundle objectForInfoDictionaryKey: @"CFBundleVersion"];
        NSString * body = [bundle localizedStringForKey:@"exception_email_body" value:@"" table:nil];
        body = [NSString stringWithFormat:[body stringByAppendingString:@"\n----------------------------------\n"],dev.model, dev.systemVersion, appVersion];
        for (NSString *info in exceptionInfo) {
                body = [body stringByAppendingFormat:@"%@\n",info];
        };
        body = [body stringByAppendingFormat:@"%s\n",exn];
        for (int i = 0; i < bc; i++) {
                if (bv[i]) body = [body stringByAppendingString:[NSString stringWithCString:bv[i] encoding:NSASCIIStringEncoding]];
        };
        NSString *email = [NSString stringWithFormat:@"mailto:%@?subject=%@&body=%@", supportEmail, subj, body];
  email = [email stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
  [[UIApplication sharedApplication] openURL:[NSURL URLWithString:email]];
}*/

/*static void mlUncaughtException(const char* exn, int bc, char** bv) {
	NSBundle *bundle = [NSBundle mainBundle];
	NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
	UIDevice *dev = [UIDevice currentDevice];
	//NSString *appName = [bundle objectForInfoDictionaryKey: @"CFBundleDisplayName"];
	NSString *appVer = [bundle objectForInfoDictionaryKey: @"CFBundleVersion"];
	NSString *exnInf = [NSString string];
	NSString *backtrace = [NSString string];

	for (NSString *info in exceptionInfo) {
		exnInf = [exnInf stringByAppendingFormat:@"\t%@\n", info];
	};

	NSString *exception = [NSString stringWithCString:exn encoding:NSUTF8StringEncoding];

	if (bc > 0) {
		if (bv[0]) exception = [exception stringByAppendingFormat:@"\n%s",bv[0]];
		for (int i = 1; i < bc; i++) {
			if (bv[i]) backtrace = [backtrace stringByAppendingFormat:@"%s\n", bv[i]];
		};
	}


	if ([exnInf length]) {
		backtrace = [backtrace stringByAppendingFormat:@"exception info:%@\n", exnInf];
	}

	NSString *keyArray[5] = {@"date",@"device",@"vers",@"exception",@"data"};
	NSString *valArray[5] = {[NSString stringWithFormat:@"%f",now],[NSString stringWithFormat:@"%@(%@)",dev.model,dev.systemVersion],appVer,exception,backtrace};
	//NSString *report =
		//[NSString stringWithFormat:@"\n------------------------------------------------------\ndate: %@\ndevice: %@(%@)\napplication: %@(%@)\nexception:\n\t%s\n%@", now, dev.model, dev.systemVersion, appName, appVer, exn, backtrace];
	//if ([exnInf length]) {
		//report = [report stringByAppendingFormat:@"exception info:\n%@\n", exnInf];
	//}

	NSDictionary *dict = [NSDictionary dictionaryWithObjects:valArray forKeys:keyArray count:5];
	NSFileManager *fmngr = [NSFileManager defaultManager];
	NSString *errlog = errlogPath();

	NSData *js = [NSJSONSerialization dataWithJSONObject:dict options:0 error:NULL];
	if ([fmngr fileExistsAtPath:errlog] == NO) {
		//[fmngr createFileAtPath:errlog contents:[report dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
		[fmngr createFileAtPath:errlog contents:js attributes:nil];
	} else {
		NSFileHandle *f = [NSFileHandle fileHandleForWritingAtPath:errlog];
		[f seekToEndOfFile];
		//[f writeData:[report dataUsingEncoding:NSUTF8StringEncoding]];
		[f writeData:js];
		[f closeFile];
	}

	flushErrlog();
}*/

void silentUncaughtException(char *exceptionJson) {
	NSFileManager *fmngr = [NSFileManager defaultManager];
	NSString *errlog = errlogPath();

	NSData *data = [NSData dataWithBytes:exceptionJson length:strlen(exceptionJson)];
	if ([fmngr fileExistsAtPath:errlog] == NO) {
		[fmngr createFileAtPath:errlog contents:data attributes:nil];
	} else {
		NSFileHandle *f = [NSFileHandle fileHandleForWritingAtPath:errlog];
		[f seekToEndOfFile];
		[f writeData:data];
		[f closeFile];
	}

	flushErrlog();
}

+alloc {
	//NSLog(@"Try INIT Light view controller");
	if (instance != NULL) return NULL; // raise exception
	//NSLog(@"INIT Light view controller");
	char *argv[] = {"ios",NULL};
	/*uncaught_exception_callback = &mlUncaughtException;*/
	caml_startup(argv);
	//caml_release_runtime_system();
	instance = [super alloc];
	return instance;
}


+(NSString *)version {
	//NSLog(@"VERSION");
	NSBundle *bundle = [NSBundle mainBundle];
	NSLog(@"!!!version %@", bundle);
	/*NSString *appVersion = [bundle objectForInfoDictionaryKey: @"CFBundleVersion"];*/
	NSString *appVersion = [bundle objectForInfoDictionaryKey: @"CFBundleShortVersionString"];
	return appVersion;
}


-(id)init {
	bgDelayedCallback = nil;
	bgCallbackDelay = -1;

  self = [super init];
  if (self != nil) {
		payment_success_cb = 0;
		payment_error_cb   = 0;
		_orientationDelegate = nil;
		_rnDelegate = nil;
		//remote_notification_request_success_cb = Val_int(1);
		//remote_notification_request_error_cb   = Val_int(1);
  }
  return self;
}

+(LightViewController*)sharedInstance {
	if (!instance) [[LightViewController alloc] init];
	return instance;
}

+(void)addExceptionInfo:(NSString*)info {
	if (exceptionInfo == nil) exceptionInfo = [[NSMutableArray alloc] initWithCapacity:1];
	[exceptionInfo addObject:info];
}

#pragma mark - View lifecycle
- (void)loadView {
	UIInterfaceOrientation orient = self.interfaceOrientation;
	CGRect rect = [UIScreen mainScreen].applicationFrame;
	switch (orient) {
		case UIInterfaceOrientationLandscapeLeft:
		case UIInterfaceOrientationLandscapeRight:
			if(SYSTEM_VERSION_LESS_THAN(@"8.0")) {
				float tmp = rect.size.width;
				rect.size.width = rect.size.height;
				rect.size.height = tmp;
			}

			break;

		default: break;
	};
	LightView * lightView = [[LightView alloc] initWithFrame:rect];
	self.view = lightView;
	[lightView release];
}

-(void)resignActive {
	[self hideActivityIndicator];
	[(LightView *)(self.view) stop];
}

-(void)becomeActive {
	[(LightView *)(self.view) start];
}

-(void)background {
	NSLog(@"background call %f", bgCallbackDelay);
	if (bgCallbackDelay > 0) {
		bgTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
		bgDelayedCallbackTimer = [NSTimer scheduledTimerWithTimeInterval:bgCallbackDelay target:self selector:@selector(runBackgroudDelayerCallback) userInfo:nil repeats:NO];
	}

	[(LightView *)(self.view) background];
}

-(void)foreground {
	if (bgDelayedCallbackTimer != nil) {
		[bgDelayedCallbackTimer invalidate];
		bgDelayedCallbackTimer = nil;
		[[UIApplication sharedApplication] endBackgroundTask:bgTaskId];
	}

	[(LightView *)(self.view) foreground];
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
	NSLog(@"presentViewController");
	[self resignActive];
	[super presentViewController: viewControllerToPresent animated: flag completion: completion];
}

-(void)showLeaderboard {
	GKLeaderboardViewController *leaderboardController = [[GKLeaderboardViewController alloc] init];
	if (leaderboardController != nil) {
		leaderboardController.leaderboardDelegate = self;
		[self presentViewController: leaderboardController animated: YES completion:nil];
	}
}


-(void)leaderboardViewControllerDidFinish:(GKLeaderboardViewController *)viewController {
 [self dismissViewControllerAnimated:YES completion:nil];
}


-(void)showAchievements {
	GKAchievementViewController *achievements = [[GKAchievementViewController alloc] init];
	if (achievements != nil){
		achievements.achievementDelegate = self;
		[self presentViewController: achievements animated: YES completion:nil];
	}
	[achievements release];
}


-(void)achievementViewControllerDidFinish:(GKAchievementViewController *)viewController {
    [self dismissViewControllerAnimated:YES completion:nil];
}



////////////////////
//// URLConnection

static value *ml_url_response = NULL;
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response {
	//NSLog(@"did recieve response %lld",response.expectedContentLength);
	//caml_acquire_runtime_system();
	if (ml_url_response == NULL) ml_url_response = caml_named_value("url_response");
	value contentType;
  Begin_roots1(contentType);
	contentType = caml_copy_string([[response MIMEType] cStringUsingEncoding:NSUTF8StringEncoding]);
	value args[4];
	args[0] = (value)connection;
	args[1] = Val_int(response.statusCode);
	args[2] = caml_copy_int64(response.expectedContentLength);
	args[3] = contentType;
	caml_callbackN(*ml_url_response,4,args);
	End_roots();
	//caml_release_runtime_system();
}

static value *ml_url_data = NULL;
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	//NSLog(@"did revieve data");
	//caml_acquire_runtime_system();
	if (ml_url_data == NULL)
		ml_url_data = caml_named_value("url_data");
	int size = data.length;
	value mldata = caml_alloc_string(size); memcpy(String_val(mldata),data.bytes,size);
	caml_callback2(*ml_url_data,(value)connection,mldata);
	//caml_release_runtime_system();
}

static value *ml_url_failed = NULL;
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	//NSLog(@"did fail with error");
	//caml_acquire_runtime_system();
	if (ml_url_failed == NULL)
		ml_url_failed = caml_named_value("url_failed");
	NSString *errdesc = [error localizedDescription];
	value errmessage = caml_copy_string([errdesc cStringUsingEncoding:NSUTF8StringEncoding]);
	//NSLog(@"connection didFailWithError with [%s]",String_val(errmessage));
	caml_callback3(*ml_url_failed,(value)connection,Val_int(error.code),errmessage);
	[connection release];
	//caml_release_runtime_system();
}


static value *ml_url_complete = NULL;
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	//NSLog(@"did finish loading");
	//caml_acquire_runtime_system();
	if (ml_url_complete == NULL)
		ml_url_complete = caml_named_value("url_complete");
	caml_callback(*ml_url_complete,(value)connection);
	[connection release];
	//caml_release_runtime_system();
}

// end URL connection
// ////////////////////


//
-(void)showActivityIndicator: (LightActivityIndicatorView *)indicator {
    if (indicator == nil) {
        indicator = [[[LightActivityIndicatorView alloc] initWithTitle: nil message: @"" delegate:nil cancelButtonTitle:nil otherButtonTitles:nil] autorelease];
    }

	if (activityIndicator) {
		[activityIndicator dismissWithClickedButtonIndex:-1 animated:YES];
		[activityIndicator release];
	}

	activityIndicator = [indicator retain];
    [activityIndicator show];
}


//
-(void)hideActivityIndicator {
	if (!activityIndicator) {
		return;
	}
	[activityIndicator dismissWithClickedButtonIndex:-1 animated:YES];
	[activityIndicator release];
	activityIndicator = nil;
}

- (void)changeTextFieldOrientation:(UIInterfaceOrientation)interfaceOrientation {
	if (kbTextField != nil) {
		switch (interfaceOrientation) {
			case UIInterfaceOrientationLandscapeLeft: {
				kbTextField.transform = CGAffineTransformConcat(kbTextField.transform, CGAffineTransformMakeRotation(M_PI * 3 / 2.0));
				break;
			}
			case UIInterfaceOrientationLandscapeRight: {
				kbTextField.transform = CGAffineTransformConcat(kbTextField.transform, CGAffineTransformMakeRotation(M_PI / 2.0));
				break;
			}
			case UIInterfaceOrientationPortrait: {
				kbTextField.transform = CGAffineTransformConcat(kbTextField.transform, CGAffineTransformMakeRotation(0));
				break;
			}
			case UIInterfaceOrientationPortraitUpsideDown: {
				kbTextField.transform = CGAffineTransformConcat(kbTextField.transform, CGAffineTransformMakeRotation(M_PI));
				break;
			}
			default: break;
		};
	};
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	NSLog(@"controller shouldAutofotateToInterfaceOrientation");
	if (_orientationDelegate) {
		BOOL res = [_orientationDelegate shouldAutorotateToInterfaceOrientation:interfaceOrientation];
		return res;
	}
	else {
    return (interfaceOrientation == UIInterfaceOrientationPortrait || interfaceOrientation == UIInterfaceOrientationMaskPortraitUpsideDown);
	}
}

- (BOOL)shouldAutorotate {
	NSLog(@"controller shouldAutofotate");
	if (_orientationDelegate /*&& [_orientationDelegate respondsToSelector:@selector(shouldAutorotate)]*/) {
		return [_orientationDelegate shouldAutorotate];
	}
	else {
		return YES;
	}
}

- (BOOL)prefersStatusBarHidden
{
	return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
	//NSLog(@"Controller supportedOrientations called");
	if (_orientationDelegate /*&& [_orientationDelegate respondsToSelector:@selector(supportedInterfaceOrientations)]*/) {
		return [_orientationDelegate supportedInterfaceOrientations];
	}
	else {
		//NSLog(@"_orientationDelegate nill");
		return UIInterfaceOrientationMaskPortrait;
	}
}


/* handle payment transactions */
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
    BOOL restored;
    LightActivityIndicatorView * indicator;
    for (SKPaymentTransaction *transaction in transactions) {
        restored = NO;
				switch (transaction.transactionState) {
					case SKPaymentTransactionStatePurchasing:
						indicator = [[[LightActivityIndicatorView alloc] initWithTitle: nil message:@"Connecting to AppStore" delegate:nil cancelButtonTitle:nil otherButtonTitles:nil] autorelease];
						[self showActivityIndicator: indicator];
						break;
					case SKPaymentTransactionStateFailed:
						[self hideActivityIndicator];
						NSString * e;
						if (transaction.error.code != SKErrorPaymentCancelled)
						{
							e = [transaction.error localizedDescription];
							UIAlertView* alert =
							[
							 [UIAlertView alloc]
							 initWithTitle:@"Payment error"
							 message: e
							 delegate:nil
							 cancelButtonTitle:@"OK"
							 otherButtonTitles:nil
							 ];
							[alert show];
							[alert release];
						} else {
							e = @"Cancelled";
						}
						if (Is_block(payment_error_cb)) {
							//caml_acquire_runtime_system();
							value ml_product_id = 0, ml_error_msg = 0;
							//NSLog(@"PAYMENT ERORR FOR: '%@'",transaction.payment.productIdentifier);
							Begin_roots2(ml_product_id,ml_error_msg);
							ml_product_id = caml_copy_string([transaction.payment.productIdentifier cStringUsingEncoding:NSUTF8StringEncoding]);
							if (e.length > 0)
								ml_error_msg =  caml_copy_string([e cStringUsingEncoding:NSUTF8StringEncoding]);
							else ml_error_msg = caml_alloc_string(0);
							caml_callback3(payment_error_cb, ml_product_id,ml_error_msg,Val_bool(transaction.error.code == SKErrorPaymentCancelled));
							End_roots();
							//caml_release_runtime_system();
						}
						[[SKPaymentQueue defaultQueue] finishTransaction: transaction];
						break;

					case SKPaymentTransactionStateRestored:
							//NSLog(@"Restoring");
							restored = YES;
					case SKPaymentTransactionStatePurchased:
							//NSLog(@"Purchased");
							if (Is_block(payment_success_cb)) {
								[transaction retain]; // Обязательно из ocaml надо вызвать commit_transaction!!!
								//caml_acquire_runtime_system();
								caml_callback3(
									payment_success_cb,
									caml_copy_string([transaction.payment.productIdentifier cStringUsingEncoding:NSUTF8StringEncoding]), // product id
									(value)transaction,
									Val_bool(restored));
									//caml_release_runtime_system();
							}
							[self hideActivityIndicator];
							break;
					default:
							break;
        }
    }
}


-(void)didReceiveMemoryWarning {
	//NSLog(@"APP did recieve memory warning");
	ml_memoryWarning();
}


/*- (void)presentModalViewController:(UIViewController *)modalViewController animated:(BOOL)animated {
	NSLog(@"presentModalViewController");
	[self resignActive];
	[super presentModalViewController: modalViewController animated: animated];
}*/




/*- (void)dismissModalViewControllerAnimated:(BOOL)animated {
   	NSLog(@"dismissModalViewControllerAnimated");
	[super dismissModalViewControllerAnimated: animated];
	[self becomeActive];
}*/

- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion {
	NSLog(@"dismissViewControllerAnimated");
	[super dismissViewControllerAnimated: flag completion:completion];
	[self becomeActive];
}

+ (void)setSupportEmail:(NSString*)email {
	supportEmail = [email retain];
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
	//NSLog(@"textFieldDidEndEditing");
	if (keyboardCallbackReturn != 0) caml_callback(keyboardCallbackReturn, caml_copy_string([kbTextField.text UTF8String]));
	//NSLog(@"hideKeyboard frim did end editing");
	[self hideKeyboard];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	//NSLog(@"textFrieldShouldReturn");
	if (keyboardCallbackReturn != 0) caml_callback(keyboardCallbackReturn, caml_copy_string([kbTextField.text UTF8String]));
	//NSLog(@"hideKeyboard from should return");
	[self hideKeyboard];
	return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
	if (keyboardFilter != nil && [string length] > 0) {
		string = [string stringByReplacingOccurrencesOfString:keyboardFilter withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, [string length])];

		if ([string length] == 0) {
			return NO;
		}
	}


	NSString * st ;
	if (range.location == 0 && range.length > 0) st = @""; else
	if (range.length > 0 && [kbTextField.text length] > 0)
	{
		NSRange ran;
		ran.location = 0;
		ran.length = range.location ;
		st = [kbTextField.text substringWithRange:ran];
	}
	else
		st = [kbTextField.text stringByAppendingString:string];

	if (maxCountSymbols > 0 && [st length] > maxCountSymbols) {
		return NO;
	}

	if (keyboardCallbackUpdate != 0) caml_callback(keyboardCallbackUpdate, caml_copy_string( [st UTF8String] ));
	return YES;
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
	static value* reg_callback = 0;
	if (!reg_callback) reg_callback = caml_named_value("register_product");

	for (SKProduct* prod in response.products) {
		[prod retain];
		NSLog(@"got product info for %@", prod.productIdentifier);
		caml_callback2(*reg_callback, caml_copy_string([prod.productIdentifier UTF8String]), (value)prod);
    }

    [request release];
}

- (void)hideKeyboard
{
	NSLog(@"hideKeyboard");
	if (kbTextField != NULL)
	{
		//NSLog(@"Not null");
		caml_remove_global_root(&keyboardCallbackReturn);
		caml_remove_global_root(&keyboardCallbackUpdate);
		keyboardCallbackReturn = 0;
		keyboardCallbackUpdate = 0;
		[kbTextField resignFirstResponder];
		[kbTextField removeFromSuperview];
		kbTextField = NULL;

		if (keyboardFilter) {
			[keyboardFilter release];
			keyboardFilter = nil;
		}
		//NSLog(@"kbTextField is NUll");
	}
}

- (void)cleanKeyboard
{
	if (kbTextField)
	{
		kbTextField.text = @"";
	}

}
- (void)showKeyboard:(value)visible maxCnt:(value)maxCnt size:(value)size  updateCallback:(value)updateCallback returnCallback:(value)returnCallback initString:(value)initString filter:(value)filter {
	//NSLog(@"showKeyboard %b; size:[%d; %d]; cb_ret: %d cb_upd : %d", (Bool_val (visible)), (Int_val(Field(size,0))),  (Int_val(Field(size,1))),  keyboardCallbackReturn, keyboardCallbackUpdate);
	if (Is_block(filter)) {
		keyboardFilter = [[NSString alloc] initWithFormat:@"[^%s]", String_val(Field(filter, 0))];
	} else {
		keyboardFilter = nil;
	};
	maxCountSymbols = Int_val(maxCnt);

	NSLog(@"keyboardFilter %@", keyboardFilter);

	[self hideKeyboard];
	if (keyboardCallbackReturn != 0) caml_remove_global_root(&keyboardCallbackReturn);
	if (keyboardCallbackUpdate != 0) caml_remove_global_root(&keyboardCallbackUpdate);

	CGRect rect = [self view].bounds;
	if (kbTextField == NULL) {
		int w = Int_val(Field(size,0));
		int h = Int_val(Field(size,1));
		//NSLog(@"stage [%f; %f]", rect.size.width, rect.size.height);
		kbTextField = [[UITextField alloc] initWithFrame:CGRectMake((rect.size.width - w) / 2., ((rect.size.height / 2.) - h) / 2.  , Int_val(Field(size,0)), Int_val(Field(size,1)))];
	};
//	[[UIApplication sharedApplication].keyWindow addSubview:kbTextField];
	[self.view addSubview:kbTextField ];
//	kbTextField.transform = CGAffineTransformConcat(kbTextField.transform, CGAffineTransformMakeRotation(M_PI * 90 / 180.0));

	kbTextField.text = [NSString stringWithUTF8String:String_val(initString)];
	[kbTextField setDelegate:self];
	if (returnCallback != Val_none) {
		keyboardCallbackReturn = Field(returnCallback,0);
		caml_register_generational_global_root(&keyboardCallbackReturn);
	} else {
		keyboardCallbackReturn = 0;
	}
	if (updateCallback != Val_none) {
		keyboardCallbackUpdate = Field(updateCallback,0);
		caml_register_generational_global_root(&keyboardCallbackUpdate);
	} else {
		keyboardCallbackUpdate = 0;
	}
	kbTextField.autocorrectionType =  UITextAutocorrectionTypeNo;

	kbTextField.hidden = ((Int_val (visible) == 0)) ;

	// Setting the font.
	[kbTextField setFont:[UIFont fontWithName:@"Times New Roman" size:34]];

	// Setting the text alignment
	[kbTextField setTextAlignment:UITextAlignmentCenter];
	[kbTextField setBorderStyle:UITextBorderStyleRoundedRect];

	[kbTextField endEditing:YES];
	[kbTextField becomeFirstResponder];
//	[self changeTextFieldOrientation:self.interfaceOrientation];

	if (keyboardCallbackUpdate != 0) caml_callback(keyboardCallbackUpdate, caml_copy_string( String_val(initString) ));
}

- (void)setBackgroundCallback:(value)callback withDelay:(long) delay {
	if (delay <= 0) {
		caml_failwith("negative background callback delay restricted");
	}

	if (bgDelayedCallback) {
		caml_modify_generational_global_root(bgDelayedCallback, callback);
	} else {
		bgDelayedCallback = (value*)malloc(sizeof(value));
		*bgDelayedCallback = callback;
		caml_register_generational_global_root(bgDelayedCallback);
	}

	bgCallbackDelay = (NSTimeInterval)delay / 1000.;
}

- (void)resetBackgroundDelayedCallback {
	if (bgDelayedCallbackTimer != nil) {
		[[UIApplication sharedApplication] endBackgroundTask:bgTaskId];
		[bgDelayedCallbackTimer invalidate];
		bgDelayedCallbackTimer = nil;
		bgCallbackDelay = -1;
	}
}

- (void)runBackgroudDelayerCallback {
	NSLog(@"runBackgroudDelayerCallback");
	if (bgDelayedCallback) {
		caml_callback(*bgDelayedCallback, Val_unit);
	}

	[[UIApplication sharedApplication] endBackgroundTask:bgTaskId];
	[bgDelayedCallbackTimer invalidate];
	bgDelayedCallbackTimer = nil;
}

@end


/*
@implementation LightViewCompatibleController
- (void)dismissModalViewControllerAnimated:(BOOL)animated {
//  [super dismissModalViewControllerAnimated: animated];
  [[LightViewController sharedInstance] dismissModalViewControllerAnimated: animated];
  [[LightViewController sharedInstance] becomeActive];
}
@end
*/
