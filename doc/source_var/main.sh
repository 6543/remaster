#!/bin/bash

echo try to import functions of script "$1"

export "mod=$1"

[[ -s "$mod" ]] && source "$mod"


ja

