#include "tapjoy_wrapper.h"
#import "TapjoyConnect.h"
#import "TapjoyConnectConstants.h"
//#import "TapjoyConnect/TJCOpenUDID.h"
#import "../../ios/LightViewController.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface TapjoyOffersController : UIViewController {
  NSString * _currency;
  BOOL _selectorVisible;
}
@property (nonatomic, retain) NSString * currency;
@property (nonatomic, assign) BOOL currencySelectorVisible;
@end



@implementation TapjoyOffersController
@synthesize currency = _currency, currencySelectorVisible = _selectorVisible;

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  return YES;
}

-(void)tapjoyOffersClosed {
	[[LightViewController sharedInstance] dismissModalViewControllerAnimated: YES];
}


-(void)loadView {
	UIView *view = [[UIView alloc] initWithFrame: [UIScreen mainScreen].applicationFrame];
  
	//[TapjoyConnect showOffersWithViewController: [LightViewController sharedInstance]];  
	//
	view.userInteractionEnabled = YES;
	self.view = view;
  
  if (self.currency) {
    [TapjoyConnect showOffersWithCurrencyID:self.currency withViewController:self withCurrencySelector:self.currencySelectorVisible];
  } else {
    [TapjoyConnect showOffersWithViewController:self];
  } 
  [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(tapjoyOffersClosed) name:TJC_VIEW_CLOSED_NOTIFICATION object:nil];
}

@end

/*
 * init
 */
void ml_tapjoy_init(value appid, value skey) {
    CAMLparam2(appid, skey);
    [TapjoyConnect requestTapjoyConnect: STR_CAML2OBJC(appid) secretKey: STR_CAML2OBJC(skey)];
    CAMLreturn0;    
}


/*
 * set user id
 */
void ml_tapjoy_set_user_id(value userid) {
  CAMLparam1(userid);
  [TapjoyConnect setUserID: STR_CAML2OBJC(userid)];
  CAMLreturn0;
}


/*
 * get user id
 */
CAMLprim value ml_tapjoy_get_user_id() {
  CAMLparam0();
  CAMLreturn(caml_copy_string([[TapjoyConnect getUserID] UTF8String]));
}

/*
 * 
 */
void ml_tapjoy_action_complete(value action) {
  CAMLparam1(action);
  [TapjoyConnect actionComplete: STR_CAML2OBJC(action)];
  CAMLreturn0;
}

/*
 * show offers. default currency. no currency selector.
 */
void ml_tapjoy_show_offers() {
  CAMLparam0();

  TapjoyOffersController * c = [[[TapjoyOffersController alloc] init] autorelease];
  c.modalPresentationStyle = UIModalPresentationFormSheet;
  c.currency = nil;
  c.currencySelectorVisible = NO;
  [[LightViewController sharedInstance] presentModalViewController: c animated: YES];
	//[TapjoyConnect showOffersWithViewController:[LightViewController sharedInstance]];

  CAMLreturn0;
}


/*
 * show offers. 
 */
void ml_tapjoy_show_offers_with_currency(value currency, value show_selector) {
  CAMLparam2(currency, show_selector);
  
  TapjoyOffersController * c = [[[TapjoyOffersController alloc] init] autorelease];
  //c.modalPresentationStyle = UIModalPresentationFormSheet;
  c.currency = STR_CAML2OBJC(currency);
  c.currencySelectorVisible = Bool_val(show_selector);
  [[LightViewController sharedInstance] presentModalViewController: c animated: YES];  
  
  CAMLreturn0;
}


/*
value ml_TJCOpenUDIDvalue(value unit) {
	NSString *id = [TJCOpenUDID value];
	value res;
	if (id != nil) {
		value mlid = caml_alloc_string(id.length);
		memcpy(String_val(mlid),[id cStringUsingEncoding:NSASCIIStringEncoding],id.length);
		res = caml_alloc_small(1,0);
		Field(res,0) = mlid;
	} else res = Val_unit;
	return res;
}
*/
