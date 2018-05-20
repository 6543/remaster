#!/bin/bash

#check param
[ -z "$1" ] && { echo "$0 [name]"; exit 1; }
name="$1"

#gen function
cp "doc/lib-head+tail" "src/func/$name"
sed -i "s/<function>/$name/g" "src/func/$name"

#open
editor "src/func/$name"
