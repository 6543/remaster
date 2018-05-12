variablen, welche um zu funktionieren mit statischen pfaden
ausgetauscht werden müssen:

remaster.sh
 * <ROOTDIR>
    -(install)> ""
    -(debug)> 'pwd'/build

remaster.sh; <LIBDIR>/*/*;
 * <LIBDIR>
    -(install)> /usr/lib/remaster
    -(debug)> 'pwd'/build/usr/lib/remaster
