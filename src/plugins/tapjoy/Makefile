include ../../../Makefile.common

CFLAGS += -I . 
#CFLAGS += -DLDEBUG

MLFLAGS += -package redspell.syntax.debug

%.o: %.c
	$(OCAMLOPT) -I . -verbose -g  $(if $(CFLAGS),$(patsubst %,-ccopt %,$(CFLAGS))) -ccopt '-fPIC' -ccopt '-o $@' -c $<

MLSOURCES = TapjoyConnect.ml
MLOBJSN = $(MLSOURCES:.ml=.cmx)
MLOBJS = $(MLSOURCES:.ml=.cmo)
IFACES = $(MLSOURCES:.ml=.cmi)

MLFLAGS += -I ..

MLPPOPT += ../../syntax/pa_platform.cmo -enable-debug default

ifeq ($(PLATFORM),IOS)

CFLAGS  += -DIOS -Fios 

COBJS   +=  ios/tapjoy_wrapper.o
#ios/TJCAdManager.o \
#ios/TJCAdRequestHandler.o \
#ios/TJCAdView.o \
#ios/TJCCallsWrapper.o \
#ios/TJCCoreFetcher.o \
#ios/TJCCoreFetcherHandler.o \
#ios/TJCCrossPromoAdManager.o \
#ios/TJCDailyRewardAdManager.o \
#ios/TJCDailyRewardAdRequestHandler.o \
#ios/TJCDailyRewardAdView.o \
#ios/TJCEventTrackingManager.o \
#ios/TJCEventTrackingRequestHandler.o \
#ios/TJCFullScreenAdManager.o \
#ios/TJCFullScreenAdRequestHandler.o \
#ios/TJCFullScreenAdView.o \
#ios/TJCHardwareUtil.o \
#ios/TJCLoadingMainView.o \
#ios/TJCLoadingView.o \
#ios/TJCLog.o \
#ios/TJCNetReachability.o \
#ios/TJCOffersManager.o \
#ios/TJCOffersRequestHandler.o \
#ios/TJCOffersView.o \
#ios/TJCTBXML.o \
#ios/TJCUIWebPageView.o \
#ios/TJCUserAccountManager.o \
#ios/TJCUserAccountModel.o \
#ios/TJCUserAccountRequestHandler.o \
#ios/TJCUtil.o \
#ios/TJCVideoLayer.o \
#ios/TJCVideoManager.o \
#ios/TJCVideoObject.o \
#ios/TJCVideoRequestHandler.o \
#ios/TJCVideoView.o \
#ios/TJCVideoViewHandler.o \
#ios/TJCViewCommons.o \
#ios/TapjoyConnect.o \
#ios/TapjoyConnectAdvertiser.o \
#ios/TapjoyConnectPublisher.o
            
LIBFLAGS = -cclib '-framework\ Foundation' \
			 -cclib '-weak_framework\ AdSupport' \
			 -cclib '-framework\ CFNetwork' \
		   -cclib '-framework\ CoreGraphics' \
		   -cclib '-framework\ CoreLocation' \
		   -cclib '-framework\ CoreMotion' \
		   -cclib '-weak_framework\ CoreTelephony' \
		   -cclib '-framework\ EventKitUI' \
		   -cclib '-framework\ EventKit' \
		   -cclib '-lsqlite3' \
		   -cclib '-lxml2' \
		   -cclib '-lz' \
			 -cclib '-lc++' \
		   -cclib '-framework\ MapKit' \
		   -cclib '-framework\ MediaPlayer' \
		   -cclib '-framework\ MessageUI' \
		   -cclib '-framework\ MobileCoreServices' \
		   -cclib '-framework\ QuartzCore' \
		   -cclib '-framework\ Security' \
		   -cclib '-weak_framework\ Social' \
		   -cclib '-framework\ StoreKit' \
		   -cclib '-framework\ SystemConfiguration' \
		   -cclib '-framework\ Twitter' \
		   -cclib '-framework\ UIKit' \
			-cclib '-framework\ Tapjoy'
		   

else
ifeq ($(PLATFORM),ANDROID)

CFLAGS  += -DANDROID -Iandroid -I../../ -I../../android -I../common
COBJS   +=  android/tapjoy_wrapper.o


endif
endif


ifeq ($(PLATFORM),PC)
	
tapjoy.cmxa: $(IFACES) $(MLOBJSN)
	$(OCAMLOPT) -a -o tapjoy.cmxa $(MLOBJSN)

tapjoy.cma: $(IFACES) $(MLOBJS)
	$(OCAMLC) -a -o tapjoy.cma $(MLOBJS)

else
tapjoy.cmxa: $(IFACES) $(COBJS) $(MLOBJSN) 
	$(OCAMLMKLIB) -verbose -o tapjoy $(COBJS) $(MLOBJSN) $(LIBFLAGS)

tapjoy.cma: $(IFACES) $(COBJS) $(MLOBJS) 
	$(OCAMLMKLIB) -verbose -o tapjoy $(COBJS) $(MLOBJS) $(LIBFLAGS) 
endif


.PHONY : clean
clean: 
	rm -f *.o *.cm[ioxa] *.a *.cmxa *.so *.cmo ios/tapjoy_wrapper.o android/tapjoy_wrapper.o

