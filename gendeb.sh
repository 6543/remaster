#!/bin/bash
# at the moment only generate dir structure in /build

# setup build dir
rootfs=build
echo "clear build"
[ -d $rootfs ] && rm -v -R $rootfs
mkdir $rootfs

echo "copy files"
## skripte copieren
# remaster
mkdir -p $rootfs/usr/bin/
cp -v src/remaster.sh $rootfs/usr/bin/remaster
chmod +x $rootfs/usr/bin/remaster
# modules
mkdir -p $rootfs/usr/lib/remaster/
#...


# Pfade anpassen
#sed ...

#mkdeb...
#not jet
