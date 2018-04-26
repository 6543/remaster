#!/bin/bash
# at the moment only generate dir structure in /build

#####################
## setup build dir ##
#####################

rootdir=build
echo "clear build"
[ -d $rootdir ] && rm -v -R $rootdir
mkdir $rootdir

######################
## skripte copieren ##
######################

echo "copy files"

# remaster
mkdir -p $rootdir/usr/bin/
cp -v src/remaster.sh $rootdir/usr/bin/remaster
chmod +x $rootdir/usr/bin/remaster

# modules
mkdir -p $rootdir/usr/lib/remaster/
for i in dist functions mods; do
  cp -v src/$i/* $rootdir/usr/lib/remaster/
done

# setting
cp -v src/config.sample.cfg $rootdir/etc/remaster/config.sample.cfg


# Pfade anpassen
#sed ...


#mkdeb...
#not jet
