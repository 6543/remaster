#!/bin/bash
# at the moment only generate dir structure in /build

####################
## set enviroment ##
####################

[ -n "$1" ] && mode=debug
# install | clean | debug

case
ROOTDIR=build
echo "clear build"
[ -d $ROOTDIR ] && rm -v -R $ROOTDIR
mkdir $ROOTDIR

######################
## skripte copieren ##
######################

echo "copy files"

# remaster
mkdir -p $ROOTDIR/usr/bin/
cp -v src/remaster.sh $ROOTDIR/usr/bin/remaster
chmod +x $ROOTDIR/usr/bin/remaster

# modules
mkdir -p $ROOTDIR/usr/lib/remaster/
for i in proj func mods; do
  mkdir -p $ROOTDIR/usr/lib/remaster/$i
  cp -v src/$i/* $ROOTDIR/usr/lib/remaster/$i/
done

# setting
mkdir -p $ROOTDIR/etc/remaster/
cp -v src/config.sample.cfg $ROOTDIR/etc/remaster/config.sample.cfg


# Pfade anpassen
#sed ...


#mkdeb...
#not jet


case "$1" in
  install)
     install || exit 1
     ;;
  clean)
     clean || exit 1
     ;;
  debug)
     debug || exit 1
     ;;
  *)
     echo "Usage: install | clean | debug"
     exit 1
esac
