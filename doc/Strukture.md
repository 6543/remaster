1. Starte "remaster"

1.1 Lade Grundfunctionen                                      [-> #functions]

1.2 Überprüfe ...
  * auf Updates
  * auf Rechte

1.3 Lade Richtige Einstellungen                               [-> #config]
  * Lade /etc/remaster/<Conf>
  * Überprüfe Conf. (Proj Exist; Mods Exist; ...)

1.4 Lade Proj-Func                                            [-> #projects]
  * Überlade nach Abhängigkeit
  * (z.B.  ubuntu.16.04 -> ubuntu -> debian)
  * Prüfe Conf. (Proj Conform)

1.5 Lade $n Mods (optional)                                   [-> #mods]
  * Überprüfen
  * Spechern in MOD_LST

2. Init Chroot

2.1 Dateien Entpacken
  * ISO
  * Squashfs

2.2 Config für Chroot (chroot_initial)
  * (lxc-conf / tmpdir)
  * Netzwerk

2.3 Starte Chroot
  * (lxc-start / mount ...)

3. Modivikationen

3.1 Netzwerk

3.2 Proj-Spez.
  * (z.B. Desinfect: conky_info)

3.3 Packet Mgr
  * Updates
  * Install
  * Delete

3.4 Weitere in $MOD_LST
  * z.B. xrdp
  * z.B. default pw

4. Finish

4.1 Aufreumen Live-Sys
  * tmpfiles
  * Packet Mgr

4.2 Stop chroot
  * Umount

4.3. Gen ISO/PXE

4.4. Del Chroot

5. Send Log

----

lxc
-> chroot_sh exec lxc-attach
-> chroot_dir = container name
