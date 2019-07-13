#!/bin/bash

version=$1
date=`date +%Y-%m-%d`

[ -e "src/remaster.sh" ] && {

  version_sed=`echo $version | sed 's/\./\\./g'`

  #nummer
  sed -i "/#@version\ /c\#@version\ $version_sed" src/remaster.sh
  sed -i "/echo\ Remaster\ /c\ \ \ \ \ \ \ \ \ \ echo\ Remaster\ $version_sed" src/remaster.sh

  #datum
  sed -i "/#@date\ /c\#@date\ $date" src/remaster.sh
}

[ -e "changes/remaster.md" ] && {

  echo >> changes/remaster.md
  echo $date - $version >> changes/remaster.md
  $EDITOR changes/remaster.md
}

[ -f "DEBIAN/control" ] && {
  sed -i "/Version:\ /c\Version:\ $version_sed" "DEBIAN/control"
}
