# Property of Four Js*
# (c) Copyright Four Js 2013, 2017. All Rights Reserved.
# * Trademark of Four Js Development Tools Europe Ltd
#   in the United States and elsewhere
# 
# Four Js and its suppliers do not warrant or guarantee that these
# samples are accurate and suitable for your purposes. Their inclusion is
# purely for information purposes only.

#/bin/bash
#this script only works if fglgmi.zip was extracted in $FGLDIR,
#that means FGLDIR=GMIDIR
#we use our supplied Makefile to actually build GMI, none of the 
#internal XCode build rules are used
env
echo "SRCROOT=$1,ACTION=$2,SDKROOT=$SDKROOT"
if [ "$ACTION" == "build" ] 
then
  ACTION=gmi.build
fi
if [ -z "$FGLDIR" ] 
then
  #we were invoked via make openxcode
  if [ -f $SRCROOT/gmi.env ] 
  then
    source $SRCROOT/gmi.env
  else
    if [ -d $SRCROOT/../phoneMain ]
    then
      FGLDIR=$SRCROOT/../../..
    else # dev repository, don't look at this
      if [ -d $SRCROOT/../../fgl/opt/fgl ] 
      then
        FGLDIR=$SRCROOT/../../fgl/opt/fgl
      fi
    fi
  fi
fi

if [ -z "$FGLDIR" ] 
then
  echo "FGLDIR not set,please invoke XCode via 'make openxcode'"
  exit 1
fi
export PATH="$FGLDIR/bin":$PATH
if [ -n "$GMIDIR" ]
then
  export PATH="$GMIDIR/bin":$PATH
fi

cd $SRCROOT
echo "pwd:`pwd`, FGLDIR:$FGLDIR"
if [[ $SDKROOT == *"imulator"* ]]
then
#we have chosen one of the simulators in the IDE
  DEVICE="simulator"
  APP=$SRCROOT/build/iphonesimulator/GMI.app
else
#we have chosen a real phone, IDENTITY and PROVISIONING profile should be set in the Makefile
  DEVICE="phone"
  APP=$SRCROOT/build/iphoneos/GMI.app
fi

rm -rf $SRCROOT/build/iphonesimulator/GMI.app
rm -rf $SRCROOT/build/iphoneos/GMI.app

echo "make FGLDIR=$FGLDIR DEVICE=$DEVICE $ACTION"
FGLDIR=$FGLDIR make FGLDIR=$FGLDIR DEVICE=$DEVICE $ACTION
if [ $? -ne 0 ]
then
  exit 1
fi

#replace the dummy exe by our executable
MYAPPDIR=$TARGET_BUILD_DIR/GMI.app
rm -rf $MYAPPDIR

if [[ $DEVICE == "phone" ]]
then
  cp -a $SRCROOT/build/iphoneos/GMI.app $MYAPPDIR
else 
  cp -a $SRCROOT/build/iphonesimulator/GMI.app $MYAPPDIR
fi
