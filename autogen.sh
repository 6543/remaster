#!/bin/bash
# at the moment only generate dir structure in /build

####################
## set enviroment ##
####################

[ -n "$1" ] && mode=debug
# install | clean | debug

function clean() {
  echo "clear build"
  [ -d build ] && rm -v -R build
  mkdir build
}

function build() {
  echo "build ..."
  ## skripte copieren ##
  # remaster
  mkdir -p build/usr/bin/
  cp -v src/remaster.sh build/usr/bin/remaster
  chmod +x build/usr/bin/remaster

  # modules
  mkdir -p build/usr/lib/remaster/
  for i in proj func mods; do
    mkdir -p build/usr/lib/remaster/$i
    cp -v src/$i/* build/usr/lib/remaster/$i/
  done

  # setting
  mkdir -p build/etc/remaster/
  cp -v src/config.sample.cfg build/etc/remaster/config.sample.cfg

}

function set_rootdir() {
  sed -i "s/<ROOTDIR>/$1/g" build/usr/bin/remaster
  for i in proj func mods; do
    sed -i "s/<ROOTDIR>/$1/g" build/usr/lib/remaster/$i/*
  done
}
function set_libdir() {
  sed -i "s/<LIBDIR>/$1/g" build/usr/bin/remaster
  for i in proj func mods; do
    sed -i "s/<LIBDIR>/$1/g" build/usr/lib/remaster/$i/*
  done
}

function debug() {
  clean
  build
  set_rootdir "`pwd`/build"
  set_libdir "`pwd`/build/usr/lib/remaster"
}

function install() {
  clean
  build
  set_rootdir ""
  set_libdir "/usr/lib/remaster"
  #cp -f -r build/* /
}

case "$1" in
  install)
    install || exit 1
    ;;
  clean)
    clean || exit 1
    ;;
  debug)
    debug || exit 1
    ;;
  *)
    echo "Usage: install | clean | debug"
    exit 1
esac
