# Property of Four Js*
# (c) Copyright Four Js 2017, 2017. All Rights Reserved.
# * Trademark of Four Js Development Tools Europe Ltd
#   in the United States and elsewhere
# 
# Four Js and its suppliers do not warrant or guarantee that these
# samples are accurate and suitable for your purposes. Their inclusion is
# purely for information purposes only.

#calling make without parameters simply creates an GMI executable for the simulator
#use "make gmi.install" to install on the simulator or device depending on the TARGET

BUNDLE_IDENTIFIER   = com.4js.music
APPNAME             = Music
DEVICE              = phone
MODE                = debug
VERBOSE             = no
IDENTITY='59W7RY75ZU'
PROVISIONING_PROFILE=/Users/leo/Library/MobileDevice/Provisioning\ Profiles/4js_wildcard
FORMS   = $(patsubst %.per, %.42f, $(wildcard *.per))

MUSIC=cordova-plugin-music
# in case you build the demo when having the plugin checked out of github 
# then we use the fglcvdMedia.42m in the fgl dir of the plugin
ifneq ($(wildcard ../../plugin.xml),)
  MUSIC=$(CURDIR)/../..
  FGLLDPATH=../../fgl
endif

MODULES  = $(patsubst %.4gl, %.42m, $(wildcard *.4gl))
FORMS    = $(patsubst %.per, %.42f, $(wildcard *.per))

%.42m: %.4gl
	FGLLDPATH=$(FGLLDPATH) fglcomp -r -M $*

%.42f: %.per
	fglform -M $*

all:: $(MODULES) $(FORMS)

#main.42m: main.42f 

ifeq ($(GBC),)
  $(info GBC not set, no GBC will be bundled)
else
# GBC can either be: a directory containing gbc's index.html 
# or the fjs-gbc-<version>-runtime.zip
  GBCSWITCH= --gbc "$(GBC)"
endif


define gmibuild
	gmibuildtool --install=$(1) --verbose=$(VERBOSE) --app-name=$(APPNAME) --bundle-id=$(BUNDLE_IDENTIFIER) --provisioning=$(PROVISIONING_PROFILE) --certificate=$(IDENTITY) --device=$(DEVICE) --mode=$(MODE) $(EXTENSION_LIBS) $(GBCSWITCH) --build-cordova=$(MUSIC),GeneroTestPlugin
endef

#just builds the GMI files
gmi.build: all
	$(call gmibuild,no)
#installs on device
gmi.install: all
	$(call gmibuild,yes)

openxcode:
	@rm -f gmi.env
ifdef GMIDIR
	echo "export GMIDIR=$(GMIDIR)" > gmi.env
endif
ifdef FGLDIR
	echo "export FGLDIR=$(FGLDIR)" >> gmi.env
else
	$(error FGLDIR must be set)
endif
	open simple.xcodeproj

clean::
	rm -f *.42*
	rm -rf build bin distbin
	rm -rf build bin distbin
	rm -f cordovamap.txt gmi/*.a gmi/link_flags.sh *.4pwvs *.4pwdb *.4pwcfg

distclean::clean
	rm -rf simple.xcodeproj/project.xcworkspace/ simple.xcodeproj/xcuserdata
