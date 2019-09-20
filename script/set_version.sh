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

[ -e "Changelog.md" ] && {

  echo >> Changelog.md
  echo $date - $version >> Changelog.md
  $EDITOR Changelog.md
}

[ -f "DEBIAN/control" ] && {
  sed -i "/Version:\ /c\Version:\ $version_sed" "DEBIAN/control"
}
