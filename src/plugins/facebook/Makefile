include ../../../Makefile.common

CFLAGS += -I . 
#CFLAGS += -DLDEBUG

MLFLAGS += -package ojson,extlib,redspell.syntax.debug

MLSOURCES = Facebook.ml
MLOBJSN = $(MLSOURCES:.ml=.cmx)
MLOBJS = $(MLSOURCES:.ml=.cmo)
IFACES = $(MLSOURCES:.ml=.cmi)

ifeq ($(PLATFORM),IOS)
CFLAGS  += -DDEBUG -DIOS -Fios  -I../..  -I../../ios -I ios/sdk/FBSDKCoreKit -I ios/sdk/FBSDKCoreKit/FBSDKCoreKit -I ios/sdk/FBSDKLoginKit -I ios/sdk/FBSDKLoginKit/FBSDKLoginKit -I ios/sdk/FBSDKShareKit -I ios/sdk/FBSDKShareKit/FBSDKShareKit

MOBJS   += ios/fbwrapper_ios.o ios/LightFacebookDelegate.o 
            
MLPPOPT += -DIOS
LIBFLAGS = -cclib '-framework\ Foundation' \
		   -cclib '-framework\ UIKit' \
		   -cclib '-framework\ QuartzCore' \
		   -cclib '-framework\ CoreGraphics' \
		   -cclib '-framework\ CoreMedia' \
		   -cclib '-weak_framework\ Accounts' \
		   -cclib '-weak_framework\ Social' \
		   -cclib '-weak_framework\ AdSupport' \
		   -cclib '-framework\ Security' \
		   -cclib '-framework\ FBSDKCoreKit' \
		   -cclib '-framework\ FBSDKLoginKit' \
		   -cclib '-framework\ FBSDKShareKit' \
		   -cclib '-framework\ FBSDKMessengerShareKit' \
		   -cclib '-framework\ FBAudienceNetwork' \


else
ifeq ($(PLATFORM),ANDROID)
CFLAGS += -DANDROID -I../../ -I../../android -I./android -I../common
MLPPOPT += -DANDROID
MOBJS += android/fbwrapper_android.o


#android/fbwrapper_android.o: CFLAGS += -DLDEBUG

endif
endif


ifeq ($(PLATFORM),PC)
MLPPOPT += -DPC

facebook.cmxa: $(IFACES) $(MLOBJSN)
	$(OCAMLOPT) -a -o facebook.cmxa $(MLOBJSN)

facebook.cma: $(IFACES) $(MLOBJS)
	$(OCAMLC) -a -o facebook.cma $(MLOBJS)

else
facebook.cmxa: $(IFACES) $(MOBJS) $(MLOBJSN)
	$(OCAMLMKLIB) -verbose -o facebook $(MOBJS) $(MLOBJSN) $(LIBFLAGS) 

facebook.cma: $(IFACES) $(MOBJS) $(MLOBJS) $(FAKELIBS)
	$(OCAMLMKLIB) -verbose -o facebook $(MOBJS) $(MLOBJS) $(LIBFLAGS) 


endif



.PHONY : clean
clean: 
	rm -f *.o *.cm[ioxa] *.a *.cmxa *.so *.cmo ios/*.o ios/*.o android/*.o

