#!/bin/bash

[ -f "src/remaster.sh" ] && {

  v=`echo $1 | sed 's/\./\\./g'`

  #nummer
  sed -i "s/@version\ .\..\../@version\ $v/g" src/remaster.sh

  #datum
  sed -i "s/@date\ ....-..-../@date\ `date +%Y-%m-%d`/g" src/remaster.sh
}
