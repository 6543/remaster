#!/bin/bash
#@version 1.9.2
#@autor 6543@obermui.de
#@date 2018-05-10
#@licence GNUv3

#####################################################################################
################## S e t t i n g s ##################################################
#####################################################################################

#set functions
[ -d "<LIBDIR>" ] || {
  echo "ERROR Librarys not found"
  exit 1
}

#read main setting
if [ -f "<ROOTDIR>/etc/remaster/config.cfg"]; then
  source "<ROOTDIR>/etc/remaster/config.cfg"
else
  if [ -f "<ROOTDIR>/etc/remaster/config.sample.cfg"]; then
    source "<ROOTDIR>/etc/remaster/config.sample.cfg"
  else
    echo "ERROR config not found"
    exit 1
  fi
fi

#####################################################################################
################## M o d e s ########################################################
#####################################################################################

#remaster.sh renew
function main_renew() {

  [ -f "$log_file" ] || touch "$log_file"
  tail -f "$log_file" --pid="$$" &

  chroot_path="`mktemp -d`"
  iso_extr_dir="`mktemp -d`"

  echo "Remaster LOG `date '+%Y-%m-%d'`" > "$log_file"
  echo "MODE: renew" >> "$log_file"
  echo "HOST: `hostname`" >> "$log_file"
  echo >> "$log_file"

  echo "### S e t t i n g s ###" >> "$log_file"
  echo "#CD/DVD" >> "$log_file"
  echo "iso_source=\"$iso_source\"" >> "$log_file"
  echo "iso_destination=\"$iso_destination\"" >> "$log_file"
  echo "iso_lable=\"$iso_lable\"" >> "$log_file"
  echo >> "$log_file"

  echo "#Filesystem (for pxe)"  >> "$log_file"
  echo "filesystem_source=\"$filesystem_source\""  >> "$log_file"
  echo >> "$log_file"

  echo "#Network" >> "$log_file"
  echo "proxy_host=\"$proxy_host\"" >> "$log_file"
  echo "proxy_port=\"$proxy_port\"" >> "$log_file"
  echo "domain=\"$domain\"" >> "$log_file"
  echo "nameserver=\"$nameserver\"" >> "$log_file"
  echo >> "$log_file"

  echo "#remaster_script" >> "$log_file"
  echo "distro=\"$distro\"" >> "$log_file"
  echo >> "$log_file"

  echo "log_file=\"$log_file\""
  echo "log_mail_aim=\"$log_mail_aim\""
  echo "log_mail_subject=\"$log_mail_subject\""
  echo ""

  echo "#Sonstiges" >> "$log_file"
  echo "tools_list=\"$tools_list\"" >> "$log_file"
  echo $'\n' >> "$log_file"

  echo "### Enviroment ###"
  echo "iso_extr_dir=\"$iso_extr_dir\"" >> "$log_file"
  echo "chroot_path=\"$chroot_path\"" >> "$log_file"
  #env >> "$log_file"
  echo $'\n\n' >> "$log_file"

  echo $'### R U N ... ###\n' >> "$log_file"

  #1. Set and Check Enviroment
  check_user
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  check_dependency
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  [ "$distro" != "" ] && distro="_$distro"

  # 2. Entpacke ISO
  iso_extract "$iso_source" "$iso_extr_dir"

  # 3. Entpacken der Dateien des Live-Systems
  filesystem_img="`find  "$iso_extr_dir" -name filesystem.squashfs`"
  [ -e "$filesystem_img" ] || {
    echo "### ERROR ### Image \"$iso_source\" has no \"filesystem.squashfs\"" >> "$log_file"
    on_exit 15 >> "$log_file"
  }

  filesystem_extract "$filesystem_img" "$chroot_path" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  # 4. Vorbereiten für chroot-Umgebung:

  chroot_initial$distro "$chroot_path" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  # 5. Setzen der Netzwerk-Einstellungen:

  proxy_enable$distro "$chroot_path" "$proxy_host" "$proxy_port" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  dns_set "$chroot_path" "$domain" "$nameserver" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  # 6. Updaten von Desinfec't:
  os_update$distro "$chroot_path" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  # 7. Installation optionaler Tools:

  tools_add$distro "$chroot_path" "$tools_list" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  #addo ClamAV to conky_info
  sed -i 's/# ${color white}ClamAV/ ${color white}ClamAV/g'  "$chroot_path/etc/skel/.conkyrc"

  chroot_clean "$chroot_path" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  # 8. Manuelle Aktionen - deaktiviert

  #echo "Now You Have TIME to do something MANUALY!"
  #echo "enter in shell: #> chroot $chroot_path /bin/bash"
  #chroot $chroot_path /bin/bash
  #echo "Are You Finisch? Then Press [ENTER]"

  #config xrdp to start xfce
  echo '#!/bin/sh' > "$chroot_path"/etc/xrdp/startwm.sh
  echo "export LANG=\"de_DE.UTF-8\"" >> "$chroot_path"/etc/xrdp/startwm.sh
  echo "startxfce4" >> "$chroot_path"/etc/xrdp/startwm.sh

  # 9. Umount - Chroot Umgebung auflösen

  chroot_umount$distro "$chroot_path" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  #Überprüfen ob alles ausgehängt wurde
  [ "`chroot_is_mounted "$chroot_path"`" == "true" ] && {
    echo "### ERROR ### Cant Unmount Chroot!" >> "$log_file"
    on_exit 21 >> "$log_file"
  }

  # 10. Packen und Ersetzen der Dateien des Live-Systems
  rm "$filesystem_img" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  filesystem_pack "$chroot_path"  "$filesystem_img" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  # wenn iso gewünscht
  [ "$iso_destination" != "" ] && {
    iso_create$distro "$chroot_path" "$iso_extr_dir" "$iso_destination" "$iso_lable" >> "$log_file"
    error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"
  }

  # wenn filesystem gewünscht
  [ "$filesystem_source" != "" ] && {
    #wen bereits forhanden dann löschen
    [ -f "$filesystem_source" ] && rm "$filesystem_source"
    cp "$filesystem_img" "$filesystem_source" >> "$log_file"
    error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

    chmod 666 "$filesystem_source"
    error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"
  }

  chmod 666 "$iso_destination" "$filesystem_img" >> "$log_file"

  workspace_erase "$iso_extr_dir/" "$chroot_path/" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"


  on_exit 0
}

#remaster.sh update_pxe
function main_update_pxe() {

  [ "$log_file" == "" ] && log_file="`mktemp`"
  [ -f "$log_file" ] || touch "$log_file"
  tail -f "$log_file" --pid="$$" &

  chroot_path="`mktemp -d`"

  echo "Remaster LOG `date '+%Y-%m-%d'`" > "$log_file"
  echo "MODE: update_pxe" >> "$log_file"
  echo "HOST: `hostname`" >> "$log_file"
  echo >> "$log_file"

  echo "### S e t t i n g s ###" >> "$log_file"
  echo "#Filesystem (for pxe)"  >> "$log_file"
  echo "filesystem_source=\"$filesystem_source\""
  echo >> "$log_file"

  echo "#Network" >> "$log_file"
  echo "domain=\"$domain\"" >> "$log_file"
  echo "nameserver=\"$nameserver\"" >> "$log_file"
  echo >> "$log_file"

  echo "#remaster_script" >> "$log_file"
  echo "distro=\"$distro\"" >> "$log_file"
  echo >> "$log_file"

  echo "log_file=\"$log_file\""
  echo "log_mail_aim=\"$log_mail_aim\""
  echo "log_mail_subject=\"$log_mail_subject\""
  echo ""

  echo "#Sonstiges" >> "$log_file"
  echo "tools_list=\"$tools_list\"" >> "$log_file"
  echo $'\n' >> "$log_file"

  echo "### Enviroment ###"
  echo "chroot_path=\"$chroot_path\"" >> "$log_file"
  #env >> "$log_file"
  echo $'\n\n' >> "$log_file"

  echo $'### R U N ... ###\n' >> "$log_file"

  #1. Set and Check Enviroment
  check_user
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  check_dependency
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  [ "$distro" != "" ] && distro="_$distro"

  # 1. Entpacken der Dateien des Live-Systems
  [ -e "$filesystem_source" ] || {
    echo "### ERROR ### \"$filesystem_source\" does not exist!" >> "$log_file"
    on_exit 15 >> "$log_file"
  }

  filesystem_extract "$filesystem_source" "$chroot_path" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  # 2. Vorbereiten für chroot-Umgebung:

  chroot_initial$distro "$chroot_path" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  # 3. Setzen der Netzwerk-Einstellungen:

  dns_set "$chroot_path" "$domain" "$nameserver" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  # 4. Updaten von Desinfec't:
  os_update$distro "$chroot_path" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  # 5. Manuelle Aktionen - deaktiviert

  echo "Now You Have TIME to do something MANUALY!"
  #echo "enter in shell:
  chroot $chroot_path /bin/bash
  #echo "Are You Finisch? Then Press [ENTER]"
  #read

  # 6. Umount - Chroot Umgebung auflösen

  chroot_umount$distro "$chroot_path" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  #Überprüfen ob alles ausgehängt wurde
  [ "`chroot_is_mounted "$chroot_path"`" == "true" ] && {
    echo "### ERROR ### Cant Unmount Chroot!" >> "$log_file"
    on_exit 21 >> "$log_file"
  }

  # 5. Packen und Ersetzen der Dateien
  rm "$filesystem_source" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  filesystem_pack "$chroot_path"  "$filesystem_source" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  chmod 777 "$filesystem_source" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  workspace_erase "$chroot_path/" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"


  on_exit 0
}

#remaster.sh update_iso #in arbeit
function main_update_iso() {
  [ -f "$log_file" ] || touch "$log_file"
  tail -f "$log_file" --pid="$$" &

  chroot_path="`mktemp -d`"
  iso_extr_dir="`mktemp -d`"

  echo "Remaster LOG `date '+%Y-%m-%d'`" > "$log_file"
  echo "MODE: update_iso" >> "$log_file"
  echo "HOST: `hostname`" >> "$log_file"
  echo >> "$log_file"

  echo "### S e t t i n g s ###" >> "$log_file"
  echo "#CD/DVD" >> "$log_file"
  echo "iso_source=\"$iso_source\"" >> "$log_file"
  echo "iso_destination=\"$iso_destination\"" >> "$log_file"
  echo "iso_lable=\"$iso_lable\"" >> "$log_file"
  echo >> "$log_file"

  echo "#Filesystem (for pxe)"  >> "$log_file"
  echo "filesystem_source=\"$filesystem_source\""  >> "$log_file"
  echo >> "$log_file"

  echo "#Network" >> "$log_file"
  echo "proxy_host=\"$proxy_host\"" >> "$log_file"
  echo "proxy_port=\"$proxy_port\"" >> "$log_file"
  echo "domain=\"$domain\"" >> "$log_file"
  echo "nameserver=\"$nameserver\"" >> "$log_file"
  echo >> "$log_file"

  echo "#remaster_script" >> "$log_file"
  echo "distro=\"$distro\"" >> "$log_file"
  echo >> "$log_file"

  echo "log_file=\"$log_file\""
  echo "log_mail_aim=\"$log_mail_aim\""
  echo "log_mail_subject=\"$log_mail_subject\""
  echo ""

  echo "#Sonstiges" >> "$log_file"
  echo "tools_list=\"$tools_list\"" >> "$log_file"
  echo $'\n' >> "$log_file"

  echo "### Enviroment ###"
  echo "iso_extr_dir=\"$iso_extr_dir\"" >> "$log_file"
  echo "chroot_path=\"$chroot_path\"" >> "$log_file"
  #env >> "$log_file"
  echo $'\n\n' >> "$log_file"

  echo $'### R U N ... ###\n' >> "$log_file"

  #1. Set and Check Enviroment
  check_user
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  check_dependency
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  [ "$distro" != "" ] && distro="_$distro"

  # 2. Entpacke ISO
  iso_extract "$iso_source" "$iso_extr_dir"

  # 3. Checke pxe version
  # if pxe is set
  # 	if (date != date ); then $0 update_pxe 		#4.1
  #		filesystem = update												#4.2
  # else
  #  	extrakt filesystem												#5.
  #		update																		#6.
  # done
  # pack iso

  # 3. Entpacken der Dateien des Live-Systems
  filesystem_img="`find  "$iso_extr_dir" -name filesystem.squashfs`"
  [ -e "$filesystem_img" ] || {
    echo "### ERROR ### Image \"$iso_source\" has no \"filesystem.squashfs\"" >> "$log_file"
    on_exit 15 >> "$log_file"
  }

  filesystem_extract "$filesystem_img" "$chroot_path" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  # 4. Vorbereiten für chroot-Umgebung:

  chroot_initial$distro "$chroot_path" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  # 5. Setzen der Netzwerk-Einstellungen:

  proxy_enable$distro "$chroot_path" "$proxy_host" "$proxy_port" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  dns_set "$chroot_path" "$domain" "$nameserver" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  # 6. Updaten von Desinfec't:
  os_update$distro "$chroot_path" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  # 7. Installation optionaler Tools:

  tools_add$distro "$chroot_path" "$tools_list" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  #addo ClamAV to conky_info
  sed -i 's/# ${color white}ClamAV/ ${color white}ClamAV/g'  "$chroot_path/etc/skel/.conkyrc"

  chroot_clean "$chroot_path" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  # 8. Manuelle Aktionen - deaktiviert

  #echo "Now You Have TIME to do something MANUALY!"
  #echo "enter in shell: #> chroot $chroot_path /bin/bash"
  #chroot $chroot_path /bin/bash
  #echo "Are You Finisch? Then Press [ENTER]"

  # 9. Umount - Chroot Umgebung auflösen

  chroot_umount$distro "$chroot_path" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  #Überprüfen ob alles ausgehängt wurde
  [ "`chroot_is_mounted "$chroot_path"`" == "true" ] && {
    echo "### ERROR ### Cant Unmount Chroot!" >> "$log_file"
    on_exit 21 >> "$log_file"
  }

  # 10. Packen und Ersetzen der Dateien des Live-Systems
  rm "$filesystem_img" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  filesystem_pack "$chroot_path"  "$filesystem_img" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  # wenn iso gewünscht
  [ "$iso_destination" != "" ] && {
    iso_create$distro "$chroot_path" "$iso_extr_dir" "$iso_destination" "$iso_lable" >> "$log_file"
    error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"
  }

  # wenn filesystem gewünscht
  [ "$filesystem_source" != "" ] && {
    #wen bereits forhanden dann löschen
    [ -f "$filesystem_source" ] && rm "$filesystem_source"
    cp "$filesystem_img" "$filesystem_source" >> "$log_file"
    error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

    chmod 666 "$filesystem_source"
    error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"
  }

  chmod 666 "$iso_destination" "$filesystem_img" >> "$log_file"

  #11. End
  workspace_erase "$iso_extr_dir/" "$chroot_path/" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"


  on_exit 0
}

#remaster.sh update
function main_update() {
  main_update_pxe
}

#####################################################################################
################## F u n c t i o n s ################################################
#####################################################################################

### Error Handlings ###

#on_exit [error_level]
source <LIBDIR>/func/on_exit

#error_code [error_level]
source <LIBDIR>/func/error_code

#check_user
source <LIBDIR>/func/check_user

#check_dependency
# -> 0 | -> 16
source <LIBDIR>/func/check_dependency


### Workspace ###

#workspace_erase [workspace_path]
source <LIBDIR>/func/workspace_erase


### Filesystem ###

#filesystem_extract [filesystem_img_source] [chroot_path]
source <LIBDIR>/func/filesystem_extract

#filesystem_pack [chroot_path] [filesystem_img_destination]
source <LIBDIR>/func/filesystem_pack

#filesystem_get_type [dir]
#(String)-> ext4, ext2, btfs, fuse, ...
source <LIBDIR>/func/filesystem_get_type

### ISO ###

#iso_extract [iso_source] [iso_extr_dir]
source <LIBDIR>/func/iso_extract

#iso_create [chroot_path] [iso_extr_dir] [iso_destination] [iso_lable]
source <LIBDIR>/func/iso_create

#iso_create_desinfect2015 [chroot_path] [iso_extr_dir] [iso_destination] [iso_lable]
function iso_create_desinfect2015() {
  echo "prepere iso folder ... "

  chroot_path="$1"
  iso_extr_dir="$2"
  iso_destination="$3"
  iso_lable="$4"

  #desinfect
  rm "$iso_extr_dir/casper/initrd.lz"
  wget http://www.heise.de/ct/projekte/desinfect/des15/initrd.lz -O "$iso_extr_dir/casper/initrd.lz"

  echo "done"

  iso_create  "$chroot_path" "$iso_extr_dir" "$iso_destination" "$iso_lable"
}

#iso_create_desinfect2016 [chroot_path] [iso_extr_dir] [iso_destination] [iso_lable]
function iso_create_desinfect2016() {
  #echo "prepere iso folder ... "

  chroot_path="$1"
  iso_extr_dir="$2"
  iso_destination="$3"
  iso_lable="$4"

  #desinfect
  #rm "$iso_extr_dir/casper/initrd.lz"
  #wget http://www.heise.de/ct/projekte/desinfect/des15/initrd.lz -O "$iso_extr_dir/casper/initrd.lz"

  #echo "done"

  iso_create  "$chroot_path" "$iso_extr_dir" "$iso_destination" "$iso_lable"
}

#iso_create_desinfect2017 [chroot_path] [iso_extr_dir] [iso_destination] [iso_lable]
function iso_create_desinfect2017() {
  #echo "prepere iso folder ... "

  chroot_path="$1"
  iso_extr_dir="$2"
  iso_destination="$3"
  iso_lable="$4"

  iso_create  "$chroot_path" "$iso_extr_dir" "$iso_destination" "$iso_lable"
}

### chroot ###

## overload chroot with lxc
source <LIBDIR>/func/chroot

#chroot_initial [chroot_dir]
source <LIBDIR>/func/chroot_initial

#chroot_initial_desinfect2015 [chroot_dir]
function chroot_initial_desinfect2015() {
  #$1 = chroot dir

  chroot_initial "$1"

  echo -n "initial desinfect on chroot ... "

  #check chroot dir
  chroot_dir="$1"
  [ -d "$chroot_dir" ] || {
    echo "### ERROR ### chroot_initial_desinfect: chroot directory not exist!"
    return 12
  }

  #mount virus definitions
  #bitdefender
  mount --bind $chroot_dir/opt/BitDefender-scanner/var/lib/scan{.orig,}
  mount --bind $chroot_dir/var/kl/bases_rd{.orig,}

  echo "done"
}

#chroot_initial_desinfect2016 [chroot_dir]
function chroot_initial_desinfect2016() {
  #$1 = chroot dir

  chroot_initial "$1"

  echo -n "initial desinfect on chroot ... "

  #check chroot dir
  chroot_dir="$1"
  [ -d "$chroot_dir" ] || {
    echo "### ERROR ### chroot_initial_desinfect: chroot directory not exist!"
    return 12
  }

  #mount virus definitions
  mount --bind $chroot_dir/var/kl/bases_rd{.orig,}

  echo "done"
}

#chroot_initial_desinfect2017 [chroot_dir]
function chroot_initial_desinfect2017() {
  #$1 = chroot dir

  chroot_initial "$1"

	#LXC Start
	config="/var/lib/lxc/_remaster_/config"

	#special conf for distros:
	echo "lxc.include = /usr/share/lxc/config/nesting.conf" > $config
	echo "lxc.include = /usr/share/lxc/config/ubuntu.common.conf" >> $config
	echo "lxc.arch = x86_64" >> $config

	#normal config
	chroot_config "$chroot_dir" >> $config
	#LXC End

}


#chroot_clean [chroot_dir]
source <LIBDIR>/func/chroot_clean

#chroot_umount [chroot_dir]
source <LIBDIR>/func/chroot_umount

#chroot_umount_desinfect2015 [chroot_dir]
function chroot_umount_desinfect2015() {
  #call main mount
  chroot_umount "$1"

  echo -n "unmount desinfect on chroot ... "
  #check chroot dir
  chroot_dir="$1"
  [ -d "$chroot_dir" ] || {
    echo "### ERROR ### chroot_umount_desinfect: chroot directory not exist!"
    return 12
  }

  for d in "$chroot_dir/opt/BitDefender-scanner/var/lib/scan" "$chroot_dir/var/kl/bases_rd" ; do
    umount $d
    retval=$?
    [ "$retval" -gt 0 ] && {
      echo "### ERROR ### chroot_umount_desinfect: can't umount \"$d\"!"
      return 21
    }
  done

  echo "done"
}

#chroot_umount_desinfect2016 [chroot_dir]
function chroot_umount_desinfect2016() {
  #call main mount
  chroot_umount "$1"

  echo -n "unmount desinfect on chroot ... "
  #check chroot dir
  chroot_dir="$1"
  [ -d "$chroot_dir" ] || {
    echo "### ERROR ### chroot_umount_desinfect: chroot directory not exist!"
    return 12
  }

  umount "$chroot_dir/var/kl/bases_rd"
  [ "$?" -gt 0 ] && {
    echo "### ERROR ### chroot_umount_desinfect: can't umount \"$chroot_dir/var/kl/bases_rd\"!"
    #return 21
  }

  echo "done"
}

#chroot_umount_desinfect2017 [chroot_dir]
function chroot_umount_desinfect2017() {
  #call main mount
  chroot_umount "$1"
}

#chroot_is_mounted [chroot_dir]
#(Boolean)-> true | false
source <LIBDIR>/func/chroot_is_mounted

#chroot_sh [chroot_dir] [command]
source <LIBDIR>/func/chroot_sh

### Settings ###
### proxy

#proxy_enable [chroot_dir] [proxy_host] [proxy_port]
function proxy_enable() {
  echo -n "enable proxy ... "

  chroot_dir="$1"
  proxy_host="$2"
  proxy_port="$3"

  [ -d "$chroot_dir" ] || {
    echo "### ERROR ### chroot_umount_desinfect: chroot directory not exist!"
    return 12
  }

  #Wenn alle zwei Parameter gegeben
  if [ "$proxy_host" != "" ] && [ "$proxy_port" != "" ] ; then
    echo "http_proxy=\"http://$proxy_host:$proxy_port\"" >> $chroot_dir/etc/environment
    echo "https_proxy=\"http://$proxy_host:$proxy_port\"" >> $chroot_dir/etc/environment
    echo "ftp_proxy=\"http://$proxy_host:$proxy_port\"" >> $chroot_dir/etc/environment

    echo "HTTP_PROXY=\"http://$proxy_host:$proxy_port\"" >> $chroot_dir/etc/environment
    echo "HTTPS_PROXY=\"http://$proxy_host:$proxy_port\"" >> $chroot_dir/etc/environment
    echo "FTP_PROXY=\"http://$proxy_host:$proxy_port\"" >> $chroot_dir/etc/environment

    echo "Acquire::http::Proxy  \"http://$proxy_host:$proxy_port\"\;" > $chroot_dir/etc/apt/apt.conf.d/90proxy
    echo "Acquire::ftp::Proxy \"ftp://$proxy_host:$proxy_port\"\;" >> $chroot_dir/etc/apt/apt.conf.d/90proxy

    echo "done"
  else
    if [ "$proxy_host" == "" ] && [ "$proxy_port" == "" ] ; then
      echo "done"
    else
      echo "### ERROR ### proxy_enable: wrong parameters! (\"$chroot_dir\"; \"$proxy_host\"; \"$proxy_port\")"
      echo "proxy_enable [chroot_dir] [proxy_host] [proxy_port]"
      return 2
    fi
  fi
}

#proxy_enable_desinfect2015 [chroot_dir] [proxy_host] [proxy_port]
function proxy_enable_desinfect2015() {

  proxy_enable $1 $2 $3

  echo -n "enable proxy for desinfect's av ... "

  chroot_dir="$1"
  proxy_host="$2"
  proxy_port="$3"

  #Avast AntiVirus
  sed -i "s/--skip-master-file/--skip-master-file --proxy-host=$proxy_host --proxy-port=$proxy_port/g" "$chroot_dir/AntiVirUpdate/avupdate"
  sed -i "s/--proxy-host=$proxy_host --proxy-port=$proxy_port --proxy-host=$proxy_host --proxy-port=$proxy_port/--proxy-host=$proxy_host --proxy-port=$proxy_port/g" "$chroot_dir/AntiVirUpdate/avupdate"

  #BitDefender
  echo "ProxyEnable = Yes" >> "$chroot_dir/etc/BitDefender-scanner/bdscan.conf"
  echo "ProxyHost = $proxy_host:$proxy_port" >> "$chroot_dir/etc/BitDefender-scanner/bdscan.conf"

  #Clam AV
  echo "HTTPProxyServer $proxy_host" >> "$chroot_dir/etc/clamav/freshclam.conf"
  echo "HTTPProxyPort $proxy_port" >> "$chroot_dir/etc/clamav/freshclam.conf"

  #Kaspersky
  sed -i "s/<tDWORD name=\"UseProxy\">0<\/tDWORD>/<tDWORD name=\"UseProxy\">1<\/tDWORD>/g" "$chroot_dir/etc/kl/config.xml"
  sed -i "s/<tSTRING name=\"ProxyHost\"><\/tSTRING>/<tSTRING name=\"ProxyHost\">$proxy_host<\/tSTRING>/g" "$chroot_dir/etc/kl/config.xml"
  sed -i "s/<tDWORD name=\"ProxyPort\"><\/tDWORD>/<tDWORD name=\"ProxyPort\">$proxy_port<\/tDWORD>/g" "$chroot_dir/etc/kl/config.xml"

  echo "done"
}

#proxy_enable_desinfect2016 [chroot_dir] [proxy_host] [proxy_port]
function proxy_enable_desinfect2016() {

  proxy_enable $1 $2 $3

  echo -n "enable proxy for desinfect's av ... "

  chroot_dir="$1"
  proxy_host="$2"
  proxy_port="$3"
  tmp_file_344532="`mktemp`"

  #Avast AntiVirus
  sed -i "s/--skip-master-file/--skip-master-file --proxy-host=$proxy_host --proxy-port=$proxy_port/g" "$chroot_dir/AntiVirUpdate/avupdate"
  sed -i "s/--proxy-host=$proxy_host --proxy-port=$proxy_port --proxy-host=$proxy_host --proxy-port=$proxy_port/--proxy-host=$proxy_host --proxy-port=$proxy_port/g" "$chroot_dir/AntiVirUpdate/avupdate"

  #Clam AV
  cat "$chroot_dir/etc/clamav/freshclam.conf" | grep -v "HTTPProxyServer" | grep -v "HTTPProxyPort" > "$tmp_file_344532"
  rm "$chroot_dir/etc/clamav/freshclam.conf"
  cp "$tmp_file_344532" "$chroot_dir/etc/clamav/freshclam.conf"

  echo "HTTPProxyServer $proxy_host" >> "$chroot_dir/etc/clamav/freshclam.conf"
  echo "HTTPProxyPort $proxy_port" >> "$chroot_dir/etc/clamav/freshclam.conf"

  #Eset AV
  cat "$chroot_dir/etc/opt/eset/esets/esets.cfg" | grep -v "proxy_addr" | grep -v "proxy_port" > "$tmp_file_344532"
  rm "$chroot_dir/etc/opt/eset/esets/esets.cfg"
  cp "$tmp_file_344532" "$chroot_dir/etc/opt/eset/esets/esets.cfg"

  echo "proxy_addr = \"$proxy_host\"" >> "$chroot_dir/etc/opt/eset/esets/esets.cfg"
  echo "proxy_port = $proxy_port" >> "$chroot_dir/etc/opt/eset/esets/esets.cfg"

  #Kaspersky
  sed -i "s/<tDWORD name=\"UseProxy\">0<\/tDWORD>/<tDWORD name=\"UseProxy\">1<\/tDWORD>/g" "$chroot_dir/etc/kl/config.xml"
  sed -i "s/<tSTRING name=\"ProxyHost\"><\/tSTRING>/<tSTRING name=\"ProxyHost\">$proxy_host<\/tSTRING>/g" "$chroot_dir/etc/kl/config.xml"
  sed -i "s/<tDWORD name=\"ProxyPort\"><\/tDWORD>/<tDWORD name=\"ProxyPort\">$proxy_port<\/tDWORD>/g" "$chroot_dir/etc/kl/config.xml"

  rm "$tmp_file_344532"
  tmp_file_344532=

  echo "done"
}

#proxy_enable_desinfect2017 [chroot_dir] [proxy_host] [proxy_port]
function proxy_enable_desinfect2017() {

  proxy_enable $1 $2 $3

  echo "enable proxy for desinfect's av ... "

  chroot_dir="$1"
  proxy_host="$2"
  proxy_port="$3"
  tmp_file_344532="`mktemp`"

  #Avast AntiVirus
  if [ -f "$chroot_dir/AntiVirUpdate/avupdate" ]; then
    echo "Avast AntiVirus: Found"
    sed -i "s/--skip-master-file/--skip-master-file --proxy-host=$proxy_host --proxy-port=$proxy_port/g" "$chroot_dir/AntiVirUpdate/avupdate"
    sed -i "s/--proxy-host=$proxy_host --proxy-port=$proxy_port --proxy-host=$proxy_host --proxy-port=$proxy_port/--proxy-host=$proxy_host --proxy-port=$proxy_port/g" "$chroot_dir/AntiVirUpdate/avupdate"
  else
    eco "Avast AntiVirus: NOT Found"
  fi

  #Eset AV
  if [ -f "$chroot_dir/etc/opt/eset/esets/esets.cfg" ]; then
    echo "Eset AV: Found"
    cat "$chroot_dir/etc/opt/eset/esets/esets.cfg" | grep -v "proxy_addr" | grep -v "proxy_port" > "$tmp_file_344532"
    rm "$chroot_dir/etc/opt/eset/esets/esets.cfg"
    cp "$tmp_file_344532" "$chroot_dir/etc/opt/eset/esets/esets.cfg"

    echo "proxy_addr = \"$proxy_host\"" >> "$chroot_dir/etc/opt/eset/esets/esets.cfg"
    echo "proxy_port = $proxy_port" >> "$chroot_dir/etc/opt/eset/esets/esets.cfg"
  else
    eco "Eset AV: NOT Found"
  fi

  #ClamAV
  if [ -f "$chroot_dir/etc/clamav/freshclam.conf" ]; then
    echo "ClamAV: Found"
    cat "$chroot_dir/etc/clamav/freshclam.conf" | grep -v "HTTPProxyServer" | grep -v "HTTPProxyPort" > "$tmp_file_344532"
    rm "$chroot_dir/etc/clamav/freshclam.conf"
    cp "$tmp_file_344532" "$chroot_dir/etc/clamav/freshclam.conf"

    echo "HTTPProxyServer $proxy_host" >> "$chroot_dir/etc/clamav/freshclam.conf"
    echo "HTTPProxyPort $proxy_port" >> "$chroot_dir/etc/clamav/freshclam.conf"
  else
    eco "ClamAV: NOT Found"
  fi

  #Sophos
  if [ -f ""$chroot_dir/opt/sophos-av/etc/savd.cfg"" ]; then
    echo "Sophos: Found"
    echo "<Source>sophos:</Source><Proxy><Address>http://www-proxy.bybn.de:80</Proxy></Address>" >> "$chroot_dir/opt/sophos-av/etc/savd.cfg"
  else
    eco "Sophos: NOT Found"
  fi

  #F-Secure
  if [ -f "$chroot_dir/opt/f-secure/fsaua/fsaua_config.template" ]; then
    echo "F-Secure: Found"
    echo "enable_fsma=no" >> "$chroot_dir/opt/f-secure/fsaua/fsaua_config.template"
    echo "update_servers=http://fsbwserver-direct.f-secure.com" >> "$chroot_dir/opt/f-secure/fsaua/fsaua_config.template"
    echo "update_proxies=http://$proxy_host:$proxy_port" >> "$chroot_dir/opt/f-secure/fsaua/fsaua_config.template"
    echo "http_proxies=http://$proxy_host:$proxy_port" >> "$chroot_dir/opt/f-secure/fsaua/fsaua_config.template"
    cat "$chroot_dir/opt/f-secure/fsaua/fsaua_config.template" > "$chroot_dir/etc/opt/f-secure/fsaua/fsaua_config"
  else
    eco "F-Secure: NOT Found"
  fi


  rm "$tmp_file_344532"
  tmp_file_344532=

  echo "done"
}


### dns
#dns_set [chroot_dir] [domain] [nameserver]
function dns_set() {
  echo -n "set dns config ... "

  rm "$chroot_dir/etc/resolv.conf"

  [ "$2" != "" ] && echo "domain $2" >> "$chroot_dir/etc/resolv.conf"
  echo "search $2" >> "$chroot_dir/etc/resolv.conf"
  for namesv in `echo "$3" | tr "," " "`; do
    echo "nameserver $namesv" >> "$chroot_dir/etc/resolv.conf"
  done

  echo "done"
}

### source list

#sourcelist_desinfect_set_nomal2015 [chroot_dir]
function sourcelist_desinfect_set_nomal2015() {
  echo -n "build normal source.list ... "
  #$1 = chroot directory

  sourcelist="$1/etc/apt/sources.list"


  echo "#### Desinfe't 2015 ####" > "$sourcelist"
  echo "" >> "$sourcelist"
  echo "deb http://www.heise.de/ct/projekte/desinfect/ubuntu 2015 main" >> "$sourcelist"
  echo "" >> "$sourcelist"
  echo "" >> "$sourcelist"
  echo "# #### Ubuntu 14.04 (trusty) ####" >> "$sourcelist"
  echo "#" >> "$sourcelist"
  echo "# deb http://de.archive.ubuntu.com/ubuntu trusty main restricted universe multiverse" >> "$sourcelist"
  echo "# deb-src http://de.archive.ubuntu.com/ubuntu trusty main restricted universe multiverse" >> "$sourcelist"
  echo "#" >> "$sourcelist"
  echo "# deb http://de.archive.ubuntu.com/ubuntu trusty-updates main restricted universe multiverse" >> "$sourcelist"
  echo "# deb-src http://de.archive.ubuntu.com/ubuntu trusty-updates main restricted universe multiverse" >> "$sourcelist"
  echo "#" >> "$sourcelist"
  echo "# deb http://de.archive.ubuntu.com/ubuntu trusty-security main restricted universe multiverse" >> "$sourcelist"
  echo "# deb-src http://de.archive.ubuntu.com/ubuntu trusty-security main restricted universe multiverse" >> "$sourcelist"
  echo "#" >> "$sourcelist"
  echo "# deb http://de.archive.ubuntu.com/ubuntu trusty-backports main restricted universe multiverse" >> "$sourcelist"
  echo "# deb-src http://de.archive.ubuntu.com/ubuntu trusty-backports main restricted universe multiverse" >> "$sourcelist"
  echo "#" >> "$sourcelist"
  echo "# ## This software is not part of Ubuntu, but is offered by third-party" >> "$sourcelist"
  echo "# ## developers who want to ship their latest software." >> "$sourcelist"
  echo "# deb http://extras.ubuntu.com/ubuntu trusty main" >> "$sourcelist"

  echo "done"
}

#sourcelist_desinfect_set_nomal2016 [chroot_dir]
function sourcelist_desinfect_set_nomal2016() {
  echo -n "build normal source.list ... "
  #$1 = chroot directory

  sourcelist="$1/etc/apt/sources.list"


  echo "#### Desinfe't 2016 ####" > "$sourcelist"
  echo "" >> "$sourcelist"
  echo "deb http://www.heise.de/ct/projekte/desinfect/ubuntu 2016 main" >> "$sourcelist"
  echo "" >> "$sourcelist"
  echo "" >> "$sourcelist"
  echo "# #### Ubuntu 14.04 (trusty) ####" >> "$sourcelist"
  echo "#" >> "$sourcelist"
  echo "# deb http://de.archive.ubuntu.com/ubuntu trusty main restricted universe multiverse" >> "$sourcelist"
  echo "# deb-src http://de.archive.ubuntu.com/ubuntu trusty main restricted universe multiverse" >> "$sourcelist"
  echo "#" >> "$sourcelist"
  echo "# deb http://de.archive.ubuntu.com/ubuntu trusty-updates main restricted universe multiverse" >> "$sourcelist"
  echo "# deb-src http://de.archive.ubuntu.com/ubuntu trusty-updates main restricted universe multiverse" >> "$sourcelist"
  echo "#" >> "$sourcelist"
  echo "# deb http://de.archive.ubuntu.com/ubuntu trusty-security main restricted universe multiverse" >> "$sourcelist"
  echo "# deb-src http://de.archive.ubuntu.com/ubuntu trusty-security main restricted universe multiverse" >> "$sourcelist"
  echo "#" >> "$sourcelist"
  echo "# deb http://de.archive.ubuntu.com/ubuntu trusty-backports main restricted universe multiverse" >> "$sourcelist"
  echo "# deb-src http://de.archive.ubuntu.com/ubuntu trusty-backports main restricted universe multiverse" >> "$sourcelist"
  echo "#" >> "$sourcelist"
  echo "# ## This software is not part of Ubuntu, but is offered by third-party" >> "$sourcelist"
  echo "# ## developers who want to ship their latest software." >> "$sourcelist"
  echo "# deb http://extras.ubuntu.com/ubuntu trusty main" >> "$sourcelist"

  echo "done"
}

#sourcelist_desinfect_set_nomal2017 [chroot_dir]
function sourcelist_desinfect_set_nomal2017() {
  echo -n "build normal source.list ... "
  #$1 = chroot directory

  sourcelist="$1/etc/apt/sources.list"


  echo "#### Desinfe't 2017 ####" > "$sourcelist"
  echo "" >> "$sourcelist"
  echo "deb http://www.heise.de/ct/projekte/desinfect/ubuntu 2017 main" >> "$sourcelist"
  echo "" >> "$sourcelist"
  echo "" >> "$sourcelist"
  echo "# #### Ubuntu 16.04 LTS (Xenial) ####" >> "$sourcelist"
  echo "#" >> "$sourcelist"
  echo "# deb http://archive.ubuntu.com/ubuntu xenial main restricted universe multiverse" >> "$sourcelist"
  echo "# deb-src http://archive.ubuntu.com/ubuntu xenial main restricted universe multiverse" >> "$sourcelist"
  echo "#" >> "$sourcelist"
  echo "# deb http://security.ubuntu.com/ubuntu xenial-updates main restricted universe multiverse" >> "$sourcelist"
  echo "# deb-src http://security.ubuntu.com/ubuntu xenial-updates main restricted universe multiverse" >> "$sourcelist"
  echo "#" >> "$sourcelist"
  echo "# deb http://security.ubuntu.com/ubuntu xenial-security main restricted universe multiverse" >> "$sourcelist"
  echo "# deb-src http://security.ubuntu.com/ubuntu xenial-security main restricted universe multiverse" >> "$sourcelist"
  echo "#" >> "$sourcelist"
  echo "# ## This software is not part of Ubuntu, but is offered by third-party" >> "$sourcelist"
  echo "# ## developers who want to ship their latest software." >> "$sourcelist"
  echo "# deb http://extras.ubuntu.com/ubuntu xenial main" >> "$sourcelist"

  echo "done"
}

#sourcelist_desinfect_set_extendet2015 [chroot_dir]
function sourcelist_desinfect_set_extendet2015() {
  echo -n "build extendet source.list ... "

  sourcelist="$1/etc/apt/sources.list"


  echo "#### Desinfe't 2015 ####" > "$sourcelist"
  echo "" >> "$sourcelist"
  echo "deb http://www.heise.de/ct/projekte/desinfect/ubuntu 2015 main" >> "$sourcelist"
  echo "" >> "$sourcelist"
  echo "" >> "$sourcelist"
  echo "#### Ubuntu 14.04 (trusty) ####" >> "$sourcelist"
  echo "" >> "$sourcelist"
  echo "deb http://de.archive.ubuntu.com/ubuntu trusty main restricted universe multiverse" >> "$sourcelist"
  echo "deb-src http://de.archive.ubuntu.com/ubuntu trusty main restricted universe multiverse" >> "$sourcelist"
  echo "" >> "$sourcelist"
  echo "deb http://de.archive.ubuntu.com/ubuntu trusty-updates main restricted universe multiverse" >> "$sourcelist"
  echo "deb-src http://de.archive.ubuntu.com/ubuntu trusty-updates main restricted universe multiverse" >> "$sourcelist"
  echo "" >> "$sourcelist"
  echo "deb http://de.archive.ubuntu.com/ubuntu trusty-security main restricted universe multiverse" >> "$sourcelist"
  echo "deb-src http://de.archive.ubuntu.com/ubuntu trusty-security main restricted universe multiverse" >> "$sourcelist"
  echo "" >> "$sourcelist"
  echo "deb http://de.archive.ubuntu.com/ubuntu trusty-backports main restricted universe multiverse" >> "$sourcelist"
  echo "deb-src http://de.archive.ubuntu.com/ubuntu trusty-backports main restricted universe multiverse" >> "$sourcelist"
  echo "" >> "$sourcelist"
  echo "## This software is not part of Ubuntu, but is offered by third-party" >> "$sourcelist"
  echo "## developers who want to ship their latest software." >> "$sourcelist"
  echo "deb http://extras.ubuntu.com/ubuntu trusty main" >> "$sourcelist"

  echo "done"
}

#sourcelist_desinfect_set_extendet2016 [chroot_dir]
function sourcelist_desinfect_set_extendet2016() {
  echo -n "build extendet source.list ... "

  sourcelist="$1/etc/apt/sources.list"


  echo "#### Desinfe't 2016 ####" > "$sourcelist"
  echo "" >> "$sourcelist"
  echo "deb http://www.heise.de/ct/projekte/desinfect/ubuntu 2016 main" >> "$sourcelist"
  echo "" >> "$sourcelist"
  echo "" >> "$sourcelist"
  echo "#### Ubuntu 14.04 (trusty) ####" >> "$sourcelist"
  echo "" >> "$sourcelist"
  echo "deb http://de.archive.ubuntu.com/ubuntu trusty main restricted universe multiverse" >> "$sourcelist"
  echo "deb-src http://de.archive.ubuntu.com/ubuntu trusty main restricted universe multiverse" >> "$sourcelist"
  echo "" >> "$sourcelist"
  echo "deb http://de.archive.ubuntu.com/ubuntu trusty-updates main restricted universe multiverse" >> "$sourcelist"
  echo "deb-src http://de.archive.ubuntu.com/ubuntu trusty-updates main restricted universe multiverse" >> "$sourcelist"
  echo "" >> "$sourcelist"
  echo "deb http://de.archive.ubuntu.com/ubuntu trusty-security main restricted universe multiverse" >> "$sourcelist"
  echo "deb-src http://de.archive.ubuntu.com/ubuntu trusty-security main restricted universe multiverse" >> "$sourcelist"
  echo "" >> "$sourcelist"
  echo "deb http://de.archive.ubuntu.com/ubuntu trusty-backports main restricted universe multiverse" >> "$sourcelist"
  echo "deb-src http://de.archive.ubuntu.com/ubuntu trusty-backports main restricted universe multiverse" >> "$sourcelist"
  echo "" >> "$sourcelist"
  echo "## This software is not part of Ubuntu, but is offered by third-party" >> "$sourcelist"
  echo "## developers who want to ship their latest software." >> "$sourcelist"
  echo "deb http://extras.ubuntu.com/ubuntu trusty main" >> "$sourcelist"

  echo "done"
}

#sourcelist_desinfect_set_extendet2017 [chroot_dir]
function sourcelist_desinfect_set_extendet2017() {
  echo -n "build extendet source.list ... "

  sourcelist="$1/etc/apt/sources.list"


  echo "#### Desinfe't 2017 ####" > "$sourcelist"
  echo "" >> "$sourcelist"
  echo "deb http://www.heise.de/ct/projekte/desinfect/ubuntu 2017 main" >> "$sourcelist"
  echo "" >> "$sourcelist"
  echo "" >> "$sourcelist"
  echo "#### Ubuntu 16.04 LTS (Xenial) ####" >> "$sourcelist"
  echo "" >> "$sourcelist"
  echo "deb http://archive.ubuntu.com/ubuntu xenial main restricted universe multiverse" >> "$sourcelist"
  echo "deb-src http://archive.ubuntu.com/ubuntu xenial main restricted universe multiverse" >> "$sourcelist"
  echo "" >> "$sourcelist"
  echo "deb http://security.ubuntu.com/ubuntu xenial-updates main restricted universe multiverse" >> "$sourcelist"
  echo "deb-src http://security.ubuntu.com/ubuntu xenial-updates main restricted universe multiverse" >> "$sourcelist"
  echo "" >> "$sourcelist"
  echo "deb http://security.ubuntu.com/ubuntu xenial-security main restricted universe multiverse" >> "$sourcelist"
  echo "deb-src http://security.ubuntu.com/ubuntu xenial-security main restricted universe multiverse" >> "$sourcelist"
  echo "" >> "$sourcelist"
  echo "## This software is not part of Ubuntu, but is offered by third-party" >> "$sourcelist"
  echo "## developers who want to ship their latest software." >> "$sourcelist"
  echo "deb http://extras.ubuntu.com/ubuntu xenial main" >> "$sourcelist"

  echo "done"
}

### Update ###

#os_update [chroot_dir]
#-> proj/debian

#os_update_desinfect2015 [chroot_dir]
function os_update_desinfect2015() {
  #$1 = chroot directory

  chroot_dir="$1"

  #call main os_update
  os_update "$chroot_dir"

  echo "update virus definitions ... "

  #BitDefender
  chroot "$chroot_dir" /bin/bash -c "bdscan --update" | grep -v "... updated"

  #Avast Avira
  chroot "$chroot_dir" /bin/bash -c "/AntiVirUpdate/avupdate" | grep -v " -> "

  #Clam AV
  chroot "$chroot_dir" /bin/bash -c "freshclam" > /dev/null
  rm -f "$chroot_dir/var/lib/clamav/daily.cld"

  #Karspersky
  echo '#!/bin/bash' > "$chroot_dir/tmp/up_kasp"
  echo 'PATH=/usr/lib/kl:$PATH' >> "$chroot_dir/tmp/up_kasp"
  echo 'LD_LIBRARY_PATH=/usr/lib/kl:$LD_LIBRARY_PATH' >> "$chroot_dir/tmp/up_kasp"
  echo 'KL_PLUGINS_PATH=/usr/lib/kl' >> "$chroot_dir/tmp/up_kasp"
  echo 'export PATH LD_LIBRARY_PATH KL_PLUGINS_PATH' >> "$chroot_dir/tmp/up_kasp"
  echo '/usr/lib/kl/kav update' >> "$chroot_dir/tmp/up_kasp"
  chmod +x  "$chroot_dir/tmp/up_kasp"
  chroot "$chroot_dir" /bin/bash -c "/tmp/up_kasp" | grep -v ".kdc" | grep -v "File downloaded"
  rm "$chroot_dir/tmp/up_kasp"


  echo "done"
}

#os_update_desinfect2016 [chroot_dir]
function os_update_desinfect2016() {
  #$1 = chroot directory

  chroot_dir="$1"

  #call main os_update
  os_update "$chroot_dir"

  echo "update virus definitions ... "

  #Avast Avira
  {
    echo "Avira ..."
    chroot "$chroot_dir" /bin/bash -c "/AntiVirUpdate/avupdate" | grep -v " -> "
    echo "Avira done"
  }

  #Clam AV
  {
    echo "ClamAV..."
    chroot "$chroot_dir" /bin/bash -c "freshclam" > /dev/null
    rm -f "$chroot_dir/var/lib/clamav/daily.cld"
    echo "ClamAV done"
  }

  #Eset AV
  {
    echo "Eset AV ..."
    tmp_file_23421="`mktemp`"
    cat "$chroot_dir/etc/opt/eset/esets/esets.cfg" | grep -v "av_update_username" | grep -v "av_update_password" > "$tmp_file_23421"
    cat "$tmp_file_23421" > "$chroot_dir/etc/opt/eset/esets/esets.cfg"
    chroot "$chroot_dir" /bin/bash -c "/usr/bin/esetrand" >> "$chroot_dir/etc/opt/eset/esets/esets.cfg"

    echo "set timeout: 2min"
    av_eaet_timeout=1200
    tmp_var_3092="`chroot "$chroot_dir" /bin/bash -c "/opt/desinfect/conky_info.sh eset"`"

    #eig. update routine
    chroot "$chroot_dir" /bin/bash -c "/etc/init.d/esets restart"
    sleep 2
    chroot "$chroot_dir" /bin/bash -c "/opt/eset/esets/sbin/esets_daemon --update"

    #warten auf daemon update ...
    sleep 10m
    echo "wait 10min for Eset AV update"
    while [ "`chroot "$chroot_dir" /bin/bash -c "/opt/desinfect/conky_info.sh eset"`" == "$tmp_var_3092" ]; do
      sleep 1
      av_eaet_timeout=$((av_eaet_timeout-1))
      [ $av_eaet_timeout -gt 0 ] || tmp_var_3092=
    done

    sleep 4

    chroot "$chroot_dir" /bin/bash -c "/etc/init.d/esets stop"

    cat "$tmp_file_23421" > "$chroot_dir/etc/opt/eset/esets/esets.cfg"

    rm "$tmp_file_23421"
    tmp_file_23421=
    tmp_var_3092=
    echo "Eset AV done"
  }

  #Karspersky
  {
    echo "Karspersky ..."
    #gen update-scrypt
    echo '#!/bin/bash' > "$chroot_dir/tmp/up_kasp"
    echo 'PATH=/usr/lib/kl:$PATH' >> "$chroot_dir/tmp/up_kasp"
    echo 'LD_LIBRARY_PATH=/usr/lib/kl:$LD_LIBRARY_PATH' >> "$chroot_dir/tmp/up_kasp"
    echo 'KL_PLUGINS_PATH=/usr/lib/kl' >> "$chroot_dir/tmp/up_kasp"
    echo 'export PATH LD_LIBRARY_PATH KL_PLUGINS_PATH' >> "$chroot_dir/tmp/up_kasp"
    echo '/usr/lib/kl/kav update' >> "$chroot_dir/tmp/up_kasp"
    chmod +x  "$chroot_dir/tmp/up_kasp"

    chroot "$chroot_dir" /bin/bash -c "/tmp/up_kasp" | grep -v ".kdc" | grep -v "File downloaded"
    rm "$chroot_dir/tmp/up_kasp"
    echo "Karspersky done"
  }

  echo "update virus definitions done"
}

#os_update_desinfect2017 [chroot_dir]
function os_update_desinfect2017() {
  #$1 = chroot directory

  chroot_dir="$1"

  #call main os_update
  os_update "$chroot_dir"

  echo "update virus definitions ... "

  #Avast Avira
  {
    echo "Avira ..."
    #chroot "$chroot_dir" /bin/bash --login -c ". /tmp/env.sh; /AntiVirUpdate/avupdate" | grep -v " -> "
    chroot_sh "$chroot_dir" "/AntiVirUpdate/avupdate" | grep -v " -> "
    echo "Avira done"
  }

  #Clam AV
  {
    echo "ClamAV..."
    #chroot "$chroot_dir" /bin/bash --login -c ". /tmp/env.sh; freshclam" > /dev/null
    chroot_sh "$chroot_dir" "freshclam" > /dev/null
    rm -f "$chroot_dir/var/lib/clamav/daily.cld"
    echo "ClamAV done"
  }

  #Eset AV
  {
    echo "Eset AV ..."
    tmp_file_23421="`mktemp`"
    cat "$chroot_dir/etc/opt/eset/esets/esets.cfg" | grep -v "av_update_username" | grep -v "av_update_password" > "$tmp_file_23421"
    cat "$tmp_file_23421" > "$chroot_dir/etc/opt/eset/esets/esets.cfg"
    chroot "$chroot_dir" /bin/bash -c "/usr/bin/esetrand" >> "$chroot_dir/etc/opt/eset/esets/esets.cfg"

    av_eaet_timeout=300
    echo "set timeout: $((av_eaet_timeout/60))min"
    tmp_var_3092="`chroot "$chroot_dir" /bin/bash -c "/opt/desinfect/conky_info.sh eset"`"

    #eig. update routine
    #chroot "$chroot_dir" /bin/bash -c "/etc/init.d/esets restart"
    chroot_sh "$chroot_dir" "/etc/init.d/esets restart"
    sleep 2
    #chroot "$chroot_dir" /bin/bash --login -c "/opt/eset/esets/sbin/esets_daemon --update"
    chroot_sh "$chroot_dir" "/opt/eset/esets/sbin/esets_daemon --update"

    #warten auf daemon update ...
    echo "wait $((av_eaet_timeout/60))min for Eset AV update"
    while [ "`chroot "$chroot_dir" /bin/bash -c "/opt/desinfect/conky_info.sh eset"`" == "$tmp_var_3092" ]; do
      sleep 10
      av_eaet_timeout=$((av_eaet_timeout-10))
      [ $av_eaet_timeout -gt 0 ] || tmp_var_3092=
    done

    sleep 4

    #chroot "$chroot_dir" /bin/bash -c "/etc/init.d/esets stop"
    chroot_sh "$chroot_dir" "/etc/init.d/esets stop"

    cat "$tmp_file_23421" > "$chroot_dir/etc/opt/eset/esets/esets.cfg"

    rm "$tmp_file_23421"
    tmp_file_23421=
    tmp_var_3092=
    echo "Eset AV done"
  }

  #Sophos
  {
    echo "Sophos..."
    #chroot "$chroot_dir" /bin/bash --login -c "/opt/sophos-av/bin/savupdate -v3"
    chroot_sh "$chroot_dir" "/opt/sophos-av/bin/savupdate -v3"
    chroot_sh "$chroot_dir" "/opt/sophos-av/bin/savdstatus --version"
    #chroot "$chroot_dir" /bin/bash -c "/opt/sophos-av/bin/savupdate -v3 -a"
    echo "Sophos done"
  }

  #F-Secure
  {
    echo "F-Secure..."
    chroot_sh "$chroot_dir" "/etc/init.d/fsaua start"
    chroot_sh "$chroot_dir" "/etc/init.d/fsupdate stop"
    ( sleep 1m; chroot_sh "$chroot_dir" "/etc/init.d/fsaua start" ) &
    chroot_sh "$chroot_dir" "/opt/f-secure/fssp/bin/dbupdate_lite" && echo "Update Success"
    sleep 1m
    chroot_sh "$chroot_dir" "/etc/init.d/fsaua stop"
    chroot_sh "$chroot_dir" "/etc/init.d/fsupdate stop"
    echo "F-Secure done"
  }

  echo "update virus definitions done"
}


### Tools ###

#tools_add [chroot_dir] [tools_list]
#-> proj/debian

#tools_add_desinfect2015 [chroot_dir] [tools_list]
function tools_add_desinfect2015() {
  #$1 = chroot directory
  chroot_dir="$1"
  tools_list="$2"

  sourcelist_desinfect_set_extendet2015 "$chroot_dir"
  tools_add "$chroot_dir" "$tools_list"
  sourcelist_desinfect_set_nomal2015 "$chroot_dir"
}

#tools_add_desinfect2016 [chroot_dir] [tools_list]
function tools_add_desinfect2016() {
  #$1 = chroot directory
  chroot_dir="$1"
  tools_list="$2"

  sourcelist_desinfect_set_extendet2016 "$chroot_dir"
  tools_add "$chroot_dir" "$tools_list"
  sourcelist_desinfect_set_nomal2016 "$chroot_dir"
}

#tools_add_desinfect2017 [chroot_dir] [tools_list]
function tools_add_desinfect2017() {
  #$1 = chroot directory
  chroot_dir="$1"
  tools_list="$2"

  sourcelist_desinfect_set_extendet2017 "$chroot_dir"
  tools_add "$chroot_dir" "$tools_list"
  sourcelist_desinfect_set_nomal2017 "$chroot_dir"
}

source <LIBDIR>/proj/desinfect.17

### Handle Parameters & Modes ###

#wenn kein modus angegebnen: default modus
if [ -z "$1" ]; then
  main_$modus_default
else
  main_$1 $2 $3 $4 $5 $6 $7 $8 $9
fi
