
include ../../../Makefile.common

MLSOURCES = AppsFlyer.ml
MLOBJSN = $(MLSOURCES:.ml=.cmx)
MLOBJS = $(MLSOURCES:.ml=.cmo)
IFACES = $(MLSOURCES:.ml=.cmi)
CFLAGS += -DLDEBUG 

MLPPOPT += ../../syntax/pa_platform.cmo 


ifeq ($(PLATFORM),ANDROID)

CFLAGS += -DANDROID -I../../ -I../../android -I./android -I ../common
COBJS  += android/af_android.o
MLPPOPT += -DANDROID

else
ifeq ($(PLATFORM),IOS)

CFLAGS  += -DIOS -Fios -I../.. -I../../ios 
COBJS   += ios/af_ios.o
MLPPOPT += -DIOS

LIBFLAGS += -cclib '-weak_framework\ AdSupport' \
						-cclib '-framework\ iAd' \
						-cclib -lAppsFlyerLib

else

MLPPOPT += -DPC

endif
endif

ifeq ($(PLATFORM),PC)
	
appsflyer.cmxa: $(IFACES) $(MLOBJSN)
	$(OCAMLOPT) -a -o appsflyer.cmxa $(MLOBJSN)

appsflyer.cma: $(IFACES) $(MLOBJS)
	$(OCAMLC) -a -o appsflyer.cma $(MLOBJS)

else
appsflyer.cmxa: $(IFACES) $(COBJS) $(MLOBJSN)
	  $(OCAMLMKLIB) -o appsflyer $(COBJS) $(MLOBJSN) $(LIBFLAGS)

appsflyer.cma: $(IFACES) $(COBJS) $(MLOBJS)
	  $(OCAMLMKLIB) -o appsflyer $(COBJS) $(MLOBJS) $(LIBFLAGS)


endif

clean:
	rm -f *.a *.o *.so android/*.o ios/*.o *.cmx *.cmo *.cmxa *.cma *.cmi
