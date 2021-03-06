#!/bin/bash
#  install | clean | debug | build-deb

function clean() {
    echo "clear build"
    [ -d build ] && rm -v -R build
    mkdir build
}
function copy() {
    echo "copy files ..."
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

    #changelog
    mkdir -p build/usr/share/doc/remaster
    cp -v changes/remaster.md build/usr/share/doc/remaster/changelog
    gzip --best build/usr/share/doc/remaster/changelog
}

#config ...
function set_rootdir() {
    sed -i "s#<ROOTDIR>#$1#g" build/usr/bin/remaster
    for i in proj func mods; do
        sed -i "s#<ROOTDIR>#$1#g" build/usr/lib/remaster/$i/*
    done
}
function set_libdir() {
    sed -i "s#<LIBDIR>#$1#g" build/usr/bin/remaster
    for i in proj func mods; do
        sed -i "s#<LIBDIR>#$1#g" build/usr/lib/remaster/$i/*
    done
}

#modes
function debug() {
    clean

    #prebuild
    copy
    set_rootdir "`pwd`/build"
    set_libdir "`pwd`/build/usr/lib/remaster"
}
function install() {
    #überprüfe auf root
    [ "`id -u`" != "0" ] && { echo "Error start as root"; exit 1; }

    #lösche alltes build dir
    clean

    #prebuild
    copy
    set_rootdir ""
    set_libdir "/usr/lib/remaster"

    #set owner
    chown -r root:root build/

    #install
    cp -f -r build/* /
}
function build-deb() {
    #überprüfe auf root
    [ "`id -u`" != "0" ] && { echo "Error start as root"; exit 1; }

    #lösche alltes build dir
    clean

    #prebuild
    copy
    set_rootdir ""
    set_libdir "/usr/lib/remaster"
    ####
    ## changes for deb file
    ####
    cp -v -r -f DEBIAN build/
    #create md5sums
    find ./build -type f -exec md5sum {} \; | grep -v './build/DEBIAN' | sed 's/\.\/build\///g' > build/DEBIAN/md5sums
    chmod 0644 build/DEBIAN/md5sums

    #set size
    SIZE="`du --exclude=build/DEBIAN -c build/ | cut -f 1 | tail -n 1`"
    sed -i "s/<SIZE>/$SIZE/g" build/DEBIAN/control

    #set owner
    chown -r root:root build/

    ##
    #build deb
    ##
    dpkg -b build/
    version="`cat build/DEBIAN/control | grep Version | cut -d " " -f 2`"
    arch="`cat build/DEBIAN/control | grep Arch | cut -d " " -f 2`"
    [ -f "release/remaster_"$version"_"$arch".deb" ] && rm "release/remaster_"$version"_"$arch".deb"
    mkdir -p release
    mv -v "build.deb" "release/remaster_"$version"_"$arch".deb"
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
    copy)
        copy || exit 1
        ;;
    build-deb)
        build-deb || exit 1
        ;;
    *)
        echo "Usage: install | clean | debug | build-deb"
        exit 1
esac
