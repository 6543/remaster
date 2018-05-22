#!/bin/bash

#check param
[ -z "$1" ] && { echo "$0 \"name\" [base]"; exit 1; }
name="$1"
base="$2"

#gen project
cp "doc/proj-head" "src/proj/$name"

#set base_relations
if [ -z "$base" ]; then
  base_relations="base"
  base="base"
  sed -i "/project_relation=/c\project_relation=\"<PROJECT_NAME>\"" "src/proj/$name"
else
  [ -f "src/proj/$base" ] || {
    echo "BASE: $base dont exist"
    exit 1
  }
  #get base of $base
  base_base=`grep '# . ->' src/proj/$base`
  base_relations=`echo $base_base | sed "s/#\ \./$base/g"`
fi

## replace strings
# . -> <PROJECT_PARENT> -> base
sed -i "s/<project_relation>/\ \.\ ->\ $base_relations/g" "src/proj/$name"
#<PROJECT_NAME>
sed -i "s/<PROJECT_NAME>/$name/g" "src/proj/$name"
sed -i "s/<BASE>/$base/g" "src/proj/$name"

#open
editor "src/proj/$name"
