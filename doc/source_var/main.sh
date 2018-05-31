#!/bin/bash

echo try to import functions of script "$1"

export "mod=$1"

[[ -s "$mod" ]] && source "$mod"


ja
[ "$?" != "0" ] && echo use $0 with doja.sh next time ;)
