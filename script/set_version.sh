#!/bin/bash

version=$1
date=`date +%Y-%m-%d`

[ -e "src/remaster.sh" ] && {

  version_sed=`echo $version | sed 's/\./\\./g'`

  #nummer
  sed -i "s/@version\ .\..\../@version\ $version_sed/g" src/remaster.sh

  #datum
  sed -i "s/@date\ ....-..-../@date\ $date/g" src/remaster.sh
}

[ -e "changes/remaster.md" ] && {

  echo >> changes/remaster.md
  echo $date - $version >> changes/remaster.md
  editor changes/remaster.md
}

[ -f "DEBIAN/control" ] && {
  sed -i "s/Version:\ .\..\../Version:\ $version_sed/g" "DEBIAN/control"
}
