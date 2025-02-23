#import <UIKit/UIKit.h> 
#ifdef RELEASE 
#define NSLog(fmt,args...)
#endif
#import "mlwrapper.h"

#define STR_CAML2OBJC(mlstr) [NSString stringWithCString:String_val(mlstr) encoding:NSASCIIStringEncoding]

char* bundle_path(char* path);
void process_touches(UIView* view, NSSet* touches, UIEvent *event,  mlstage *mlstage);
char* get_locale();
