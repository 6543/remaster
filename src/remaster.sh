#!/bin/bash
#@version 2.0.3
#@autor 6543@obermui.de
#@date 2018-05-20
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
if [ -f "<ROOTDIR>/etc/remaster/config.cfg" ]; then
  source "<ROOTDIR>/etc/remaster/config.cfg"
else
  if [ -f "<ROOTDIR>/etc/remaster/config.sample.cfg" ]; then
    source "<ROOTDIR>/etc/remaster/config.sample.cfg"
  else
    echo "ERROR config not found"
    exit 1
  fi
fi
#check LOG
{
  [ -z "$log_file" ] && log_file="/tmp/remaster_`date '+%Y-%m-%d'`"

  if [ -f "$log_file" ]; then
    echo > "$log_file"
  else
    #check if folder exist
    [ -d "${log_file%/*}" ] || {
        # N-> exit 3
        echo "Directory for Log didnt exist"
        exit 3
    }
    #create LOG
    touch "$log_file"
  fi
}

#####################################################################################
################## M o d e s ########################################################
#####################################################################################

#remaster.sh renew
function main_renew() {
  #Start LOG
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
  echo "iso_aim=\"$iso_aim\"" >> "$log_file"
  echo "iso_lable=\"$iso_lable\"" >> "$log_file"
  echo >> "$log_file"

  echo "#Filesystem (for pxe)"  >> "$log_file"
  echo "squashfs_path=\"$squashfs_path\""  >> "$log_file"
  echo >> "$log_file"

  echo "#Network" >> "$log_file"
  echo "proxy_host=\"$proxy_host\"" >> "$log_file"
  echo "proxy_port=\"$proxy_port\"" >> "$log_file"
  echo "domain=\"$domain\"" >> "$log_file"
  echo "nameserver=\"$nameserver\"" >> "$log_file"
  echo >> "$log_file"

  echo "#remaster_script" >> "$log_file"
  echo "project=\"$project\"" >> "$log_file"
  echo >> "$log_file"

  echo "log_file=\"$log_file\""
  echo "log_mail_aim=\"$log_mail_aim\""
  echo "log_mail_subject=\"$log_mail_subj >> "$log_file"ect\""
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
  check_user >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  check_dependency >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  check_config >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  check_update >> "$log_file"

  [ "$project" != "" ] && project="_$project"

  # 2. Entpacke ISO
  iso_extract "$iso_source" "$iso_extr_dir"  >> "$log_file"

  # 3. Entpacken der Dateien des Live-Systems
  filesystem_img="`find  "$iso_extr_dir" -name filesystem.squashfs`"
  [ -e "$filesystem_img" ] || {
    echo "### ERROR ### Image \"$iso_source\" has no \"filesystem.squashfs\"" >> "$log_file"
    on_exit 15 >> "$log_file"
  }

  filesystem_extract "$filesystem_img" "$chroot_path" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  # 4. Vorbereiten für chroot-Umgebung:

  chroot_initial$project "$chroot_path" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  # 5. Setzen der Netzwerk-Einstellungen:
  [ -n "$proxy_host" ] && {
    proxy_enable$project "$chroot_path" "$proxy_host" "$proxy_port" >> "$log_file"
    error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"
  }

  dns_set "$chroot_path" "$domain" "$nameserver" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  # 6. Updaten von Desinfec't:
  os_update$project "$chroot_path" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  # 7. Installation optionaler Tools:

  tools_add$project "$chroot_path" "$tools_list" >> "$log_file"
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

  chroot_umount$project "$chroot_path" >> "$log_file"
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
  [ "$iso_aim" != "" ] && {
    iso_create$project "$chroot_path" "$iso_extr_dir" "$iso_aim" "$iso_lable" >> "$log_file"
    error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"
  }

  # wenn filesystem gewünscht
  [ "$squashfs_path" != "" ] && {
    #wen bereits forhanden dann löschen
    [ -f "$squashfs_path" ] && rm "$squashfs_path"
    cp "$filesystem_img" "$squashfs_path" >> "$log_file"
    error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

    chmod 666 "$squashfs_path"
    error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"
  }

  chmod 666 "$iso_aim" "$filesystem_img" >> "$log_file"

  workspace_erase "$iso_extr_dir/" "$chroot_path/" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"


  on_exit 0
}

#remaster.sh update_pxe
function main_update_pxe() {

  #Start LOG
  tail -f "$log_file" --pid="$$" &

  chroot_path="`mktemp -d`"

  echo "Remaster LOG `date '+%Y-%m-%d'`" > "$log_file"
  echo "MODE: update_pxe" >> "$log_file"
  echo "HOST: `hostname`" >> "$log_file"
  echo >> "$log_file"

  echo "### S e t t i n g s ###" >> "$log_file"
  echo "#Filesystem (for pxe)"  >> "$log_file"
  echo "squashfs_path=\"$squashfs_path\""
  echo >> "$log_file"

  echo "#Network" >> "$log_file"
  echo "domain=\"$domain\"" >> "$log_file"
  echo "nameserver=\"$nameserver\"" >> "$log_file"
  echo >> "$log_file"

  echo "#remaster_script" >> "$log_file"
  echo "project=\"$project\"" >> "$log_file"
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
  check_user >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  check_update >> "$log_file"

  check_dependency >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  check_config >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  [ "$project" != "" ] && project="_$project"

  # 1. Entpacken der Dateien des Live-Systems
  [ -e "$squashfs_path" ] || {
    echo "### ERROR ### \"$squashfs_path\" does not exist!" >> "$log_file"
    on_exit 15 >> "$log_file"
  }

  filesystem_extract "$squashfs_path" "$chroot_path" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  # 2. Vorbereiten für chroot-Umgebung:

  chroot_initial$project "$chroot_path" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  # 3. Setzen der Netzwerk-Einstellungen:

  dns_set "$chroot_path" "$domain" "$nameserver" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  # 4. Updaten von Desinfec't:
  os_update$project "$chroot_path" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  # 5. Manuelle Aktionen - deaktiviert

  echo "Now You Have TIME to do something MANUALY!"
  #echo "enter in shell:
  chroot $chroot_path /bin/bash
  #echo "Are You Finisch? Then Press [ENTER]"
  #read

  # 6. Umount - Chroot Umgebung auflösen

  chroot_umount$project "$chroot_path" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  #Überprüfen ob alles ausgehängt wurde
  [ "`chroot_is_mounted "$chroot_path"`" == "true" ] && {
    echo "### ERROR ### Cant Unmount Chroot!" >> "$log_file"
    on_exit 21 >> "$log_file"
  }

  # 5. Packen und Ersetzen der Dateien
  rm "$squashfs_path" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  filesystem_pack "$chroot_path"  "$squashfs_path" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  chmod 777 "$squashfs_path" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  workspace_erase "$chroot_path/" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"


  on_exit 0
}

#remaster.sh update_iso #in arbeit
function main_update_iso() {
  #Start LOG
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
  echo "iso_aim=\"$iso_aim\"" >> "$log_file"
  echo "iso_lable=\"$iso_lable\"" >> "$log_file"
  echo >> "$log_file"

  echo "#Filesystem (for pxe)"  >> "$log_file"
  echo "squashfs_path=\"$squashfs_path\""  >> "$log_file"
  echo >> "$log_file"

  echo "#Network" >> "$log_file"
  echo "proxy_host=\"$proxy_host\"" >> "$log_file"
  echo "proxy_port=\"$proxy_port\"" >> "$log_file"
  echo "domain=\"$domain\"" >> "$log_file"
  echo "nameserver=\"$nameserver\"" >> "$log_file"
  echo >> "$log_file"

  echo "#remaster_script" >> "$log_file"
  echo "project=\"$project\"" >> "$log_file"
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
  check_user >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  check_update >> "$log_file"

  check_dependency >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  check_config >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  [ "$project" != "" ] && project="_$project"

  # 2. Entpacke ISO
  iso_extract "$iso_source" "$iso_extr_dir"  >> "$log_file"

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

  chroot_initial$project "$chroot_path" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  # 5. Setzen der Netzwerk-Einstellungen:
  [ -n "$proxy_host" ] && {
    proxy_enable$project "$chroot_path" "$proxy_host" "$proxy_port" >> "$log_file"
    error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"
  }

  dns_set "$chroot_path" "$domain" "$nameserver" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  # 6. Updaten von Desinfec't:
  os_update$project "$chroot_path" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

  # 7. Installation optionaler Tools:

  tools_add$project "$chroot_path" "$tools_list" >> "$log_file"
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

  chroot_umount$project "$chroot_path" >> "$log_file"
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
  [ "$iso_aim" != "" ] && {
    iso_create$project "$chroot_path" "$iso_extr_dir" "$iso_aim" "$iso_lable" >> "$log_file"
    error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"
  }

  # wenn filesystem gewünscht
  [ "$squashfs_path" != "" ] && {
    #wen bereits forhanden dann löschen
    [ -f "$squashfs_path" ] && rm "$squashfs_path"
    cp "$filesystem_img" "$squashfs_path" >> "$log_file"
    error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

    chmod 666 "$squashfs_path"
    error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"
  }

  chmod 666 "$iso_aim" "$filesystem_img" >> "$log_file"

  #11. End
  workspace_erase "$iso_extr_dir/" "$chroot_path/" >> "$log_file"
  error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"


  on_exit 0
}

#####################################################################################
################## F u n c t i o n s ################################################
#####################################################################################

### Error Handlings ###

#check_config
source <LIBDIR>/func/check_config

#on_exit [error_level]
source <LIBDIR>/func/on_exit

#error_code [error_level]
source <LIBDIR>/func/error_code

#check_user
source <LIBDIR>/func/check_user

#check_dependency
# -> 0 | -> 16
source <LIBDIR>/func/check_dependency

#check_update
source <LIBDIR>/func/check_update

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

#iso_create [chroot_path] [iso_extr_dir] [iso_aim] [iso_lable]
source <LIBDIR>/func/iso_create

### chroot ###

#chroot_initial [chroot_dir]
source <LIBDIR>/func/chroot_initial

#chroot_clean [chroot_dir]
source <LIBDIR>/func/chroot_clean

#chroot_umount [chroot_dir]
source <LIBDIR>/func/chroot_umount

#chroot_is_mounted [chroot_dir]
#(Boolean)-> true | false
source <LIBDIR>/func/chroot_is_mounted

#chroot_sh [chroot_dir] [command]
source <LIBDIR>/func/chroot_sh

source <LIBDIR>/proj/desinfect.17

### Handle Parameters & Modes ###

#wenn kein modus angegebnen: default modus
if [ -z "$1" ]; then
  main_$modus_default
else
  main_$1 $2 $3 $4 $5 $6 $7 $8 $9
fi
