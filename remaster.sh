#!/bin/bash
#@version 1.5.2
#@autor Martin.Huber@stbaro.bayern.de
#@date 2016-09-12


### Modes ###

function main_newiso() {

	#####################################################################################
	################## S e t t i n g s ##################################################
	#####################################################################################
	#CD/DVD
	#entweder iso_source oder filesystem_source alls quelle
	# -> bei iso gen erforderlich!
	iso_source="/data/remaster/desinfect-2016.iso"
	#destination optinal
	iso_destination="/data/remaster/result/custom_desinfect_`date '+%Y-%m-%d'`.iso"
	iso_lable="DESINFECT_`date '+%Y-%m-%d'`"

	#Filesystem (for pxe)
	#entweder iso_source oder filesystem_source alls quelle
	filesystem_source=""
	#destination optinal
	filesystem_destination="/data/remaster/result/filesystem.squashfs"

	#Network
	proxy_host="www-proxy.bybn.de"
	proxy_port="80"
	domain="stmi.bayern.de"
	nameserver="10.173.230.81,10.173.27.82"

	#remaster_script
	distro="desinfect2016"

	#LOG
	log_file="/data/remaster/logs/`date '+%Y-%m-%d'`.log"
	log_mail_source="desinfect@stbaro.bayern.de"
	log_mail_aim="Martin.Huber@stbaro.bayern.de"
	log_mail_subject="Desinfect_Remaster"

	#Sonstiges
	tools_list="nano htop nmon iftop tmux dsniff nmap openssh-server tightvncserver rsync e2fsprogs foremost gddrescue recoverjpeg safecopy sleuthkit testdisk arp-scan apt-transport-https"



	#####################################################################################
	################## R u n ############################################################
	#####################################################################################

	#on_exit [error_level]
	function on_exit() {
		#send log and errorlevel[success/errorr xy]

		if [ "$1" != "0" ]; then
			log_mail_subject="$log_mail_subject [ERROR]"
		else
			log_mail_subject="$log_mail_subject [Success]"
		fi

		#Mail Body:
		for mail_aim in `echo "$log_mail_aim" | tr "," " "`; do
			{
				echo "$log_mail_subject"
				echo $'####################################################################################\n\n'
				cat "$log_file"
			} | sendemail -s mail.stbv.bybn.de -f desinfect@bayern.de -t "$mail_aim" -u "$log_mail_subject" -o tls=no
		done

		[ "$1" != "0" ] && {
			chroot_umount$distro "$chroot_path" 2> /dev/null
			workspace_erase "$iso_extr_dir/" "$chroot_path/" 2> /dev/null
		}
		exit $1
	}

	{
		[ -f "$log_file" ] || touch "$log_file"
		tail -f "$log_file" --pid="$$" &

		chroot_path="`mktemp -d`"
		iso_extr_dir="`mktemp -d`"

		echo "Remaster LOG `date '+%Y-%m-%d'`" > "$log_file"
		echo "MODE: newiso" >> "$log_file"
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
		echo "filesystem_destination=\"$filesystem_destination\""  >> "$log_file"
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
		echo "log_mail_source=\"$log_mail_source\""
		echo "log_mail_aim=\"$log_mail_aim\""
		echo "log_mail_subject=\"$log_mail_subject\""
		echo ""

		echo "#Sonstiges" >> "$log_file"
		echo "tools_list=\"$tools_list\"" >> "$log_file"
		echo $'\n' >> "$log_file"

		echo "### Enviroment ###"
		echo "iso_extr_dir=\"$iso_extr_dir\"" >> "$log_file"
		echo "chroot_path=\"$chroot_path\"" >> "$log_file"
		echo $'\n\n' >> "$log_file"

		echo $'### R U N ... ###\n' >> "$log_file"

		#check root
		[ "`whoami`" == "root" ] || {
			echo "### ERROR ### Remaster need ROOT permision!" >> "$log_file"
			on_exit 10 >> "$log_file"
		}

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

		echo JEZ PATCH apt-transport-https
		chroot "$chroot_dir" /bin/bash

		# 6. Updaten von Desinfec't:
		os_update$distro "$chroot_path" >> "$log_file"
		error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

		# 7. Installation optionaler Tools:

		tools_add$distro "$chroot_path" "$tools_list" >> "$log_file"
		error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

		echo JEZ Upgrade OS
		chroot "$chroot_dir" /bin/bash

		chroot_clean "$chroot_path" >> "$log_file"
		error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

		# 8. Manuelle Aktionen - deaktiviert

		#echo "Now You Have TIME to do something MANUALY!"
		#echo "enter in shell: #> chroot $chroot_path /bin/bash"
		#echo "Are You Finisch? Then Press [ENTER]"
		#read

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

		iso_create$distro "$chroot_path" "$iso_extr_dir" "$iso_destination" "$iso_lable" >> "$log_file"
		error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"


		# wenn filesystem gewünscht dann
		[ "$filesystem_destination" != "" ] && {
			#wen bereits forhanden dann löschen
			[ -f "$filesystem_destination" ] && rm "$filesystem_destination"
			cp "$filesystem_img" "$filesystem_destination" >> "$log_file"
			error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"
			
			chmod 777 "$filesystem_destination"
			error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"
		}
		
		chmod 777 "$iso_destination" "$filesystem_img" >> "$log_file"

		workspace_erase "$iso_extr_dir/" "$chroot_path/" >> "$log_file"
		error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"


		on_exit 0
	}
}

function main_desinfect_pxe_update() {

	#####################################################################################
	################## S e t t i n g s ##################################################
	#####################################################################################
	#Filesystem (from pxe)
	filesystem_img="/data/remaster/result/filesystem.squashfs"

	#Network
	domain="stmi.bayern.de"
	nameserver="10.173.230.81,10.173.27.82"

	#remaster_script
	distro="desinfect2016"

	#LOG
	log_file="/data/remaster/logs/`date '+%Y-%m-%d'`.log"
	log_mail_source="desinfect@stbaro.bayern.de"
	#log_mail_source="`hostname`@stbaro.bayern.de"
	log_mail_aim="Martin.Huber@stbaro.bayern.de"
	log_mail_subject="Desinfect_Remaster"

	#Sonstiges
	tools_list="nano htop nmon iftop tmux dsniff nmap openssh-server tightvncserver rsync e2fsprogs foremost gddrescue recoverjpeg safecopy sleuthkit testdisk arp-scan"



	#####################################################################################
	################## R u n ############################################################
	#####################################################################################

	#on_exit [error_level]
	function on_exit() {
		#send log and errorlevel[success/errorr xy]

		if [ "$1" != "0" ]; then
			log_mail_subject="$log_mail_subject [ERROR]"
		else
			log_mail_subject="$log_mail_subject [Success]"
		fi

		#Mail Body:
		for mail_aim in `echo "$log_mail_aim" | tr "," " "`; do
			{
				echo "$log_mail_subject"
				echo $'####################################################################################\n\n'
				cat "$log_file"
			} | sendemail -s mail.stbv.bybn.de -f desinfect@bayern.de -t "$mail_aim" -u "$log_mail_subject" -o tls=no
		done

		[ "$1" != "0" ] && {
			chroot_umount$distro "$chroot_path" 2> /dev/null
			workspace_erase "$iso_extr_dir/" "$chroot_path/" 2> /dev/null
		}

		exit $1
	}

	{
		[ "$log_file" == "" ] && log_file="`mktemp`"
		[ -f "$log_file" ] || touch "$log_file"
		tail -f "$log_file" --pid="$$" &

		chroot_path="`mktemp -d`"

		echo "Remaster LOG `date '+%Y-%m-%d'`" > "$log_file"
		echo "MODE: desinfect_pxe_update" >> "$log_file"
		echo "HOST: `hostname`" >> "$log_file"
		echo >> "$log_file"

		echo "### S e t t i n g s ###" >> "$log_file"
		echo "#Filesystem (for pxe)"  >> "$log_file"
		echo "filesystem_img=\"$filesystem_img\""
		echo >> "$log_file"

		echo "#Network" >> "$log_file"
		echo "domain=\"$domain\"" >> "$log_file"
		echo "nameserver=\"$nameserver\"" >> "$log_file"
		echo >> "$log_file"

		echo "#remaster_script" >> "$log_file"
		echo "distro=\"$distro\"" >> "$log_file"
		echo >> "$log_file"

		echo "log_file=\"$log_file\""
		echo "log_mail_source=\"$log_mail_source\""
		echo "log_mail_aim=\"$log_mail_aim\""
		echo "log_mail_subject=\"$log_mail_subject\""
		echo ""

		echo "#Sonstiges" >> "$log_file"
		echo "tools_list=\"$tools_list\"" >> "$log_file"
		echo $'\n' >> "$log_file"

		echo "### Enviroment ###"
		echo "chroot_path=\"$chroot_path\"" >> "$log_file"
		echo $'\n\n' >> "$log_file"

		echo $'### R U N ... ###\n' >> "$log_file"

		#check root
		[ "`whoami`" == "root" ] || {
			echo "### ERROR ### Remaster need ROOT permision!" >> "$log_file"
			on_exit 10 >> "$log_file"
		}

		[ "$distro" != "" ] && distro="_$distro"

		# 1. Entpacken der Dateien des Live-Systems
		[ -e "$filesystem_img" ] || {
			echo "### ERROR ### \"$filesystem_img\" does not exist!" >> "$log_file"
			on_exit 15 >> "$log_file"
		}

		filesystem_extract "$filesystem_img" "$chroot_path" >> "$log_file"
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

		#echo "Now You Have TIME to do something MANUALY!"
		#echo "enter in shell: #> chroot $chroot_path /bin/bash"
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
		rm "$filesystem_img" >> "$log_file"
		error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

		filesystem_pack "$chroot_path"  "$filesystem_img" >> "$log_file"
		error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

		chmod 777 "$filesystem_img" >> "$log_file"
		error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

		workspace_erase "$chroot_path/" >> "$log_file"
		error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"


		on_exit 0
	}
}

function main_test() {

	#####################################################################################
	################## S e t t i n g s ##################################################
	#####################################################################################
	#CD/DVD
	#entweder iso_source oder filesystem_source alls quelle
	# -> bei iso gen erforderlich!
	iso_source="/data/remaster/desinfect-2016.iso"
	#destination optinal
	iso_destination="/data/remaster/result/custom_desinfect_`date '+%Y-%m-%d'`.iso"
	iso_lable="DESINFECT_`date '+%Y-%m-%d'`"

	#Filesystem (for pxe)
	#entweder iso_source oder filesystem_source alls quelle
	filesystem_source=""
	#destination optinal
	filesystem_destination="/data/remaster/result/filesystem.squashfs"

	#Network
	proxy_host="www-proxy.bybn.de"
	proxy_port="80"
	domain="stmi.bayern.de"
	nameserver="10.173.230.81,10.173.27.82"

	#remaster_script
	distro="desinfect2016"	
	
	#LOG
	log_file="/data/remaster/logs/`date '+%Y-%m-%d'`.log"
	log_mail_source="desinfect@stbaro.bayern.de"
	log_mail_aim="Martin.Huber@stbaro.bayern.de"
	log_mail_subject="Desinfect_Remaster"

	#Sonstiges
	tools_list="nano htop nmon iftop tmux dsniff nmap openssh-server tightvncserver rsync e2fsprogs foremost gddrescue recoverjpeg safecopy sleuthkit testdisk arp-scan"
	


	#####################################################################################
	################## R u n ############################################################
	#####################################################################################

	#on_exit [error_level]
	function on_exit() {
		#send log and errorlevel[success/errorr xy]
		
		if [ "$1" != "0" ]; then
			log_mail_subject="$log_mail_subject [ERROR]"
		else
			log_mail_subject="$log_mail_subject [Success]"
		fi

		#Mail Body:
		for mail_aim in `echo "$log_mail_aim" | tr "," " "`; do
			{
				echo "$log_mail_subject"
				echo $'####################################################################################\n\n'
				cat "$log_file"
			} | sendemail -s mail.stbv.bybn.de -f desinfect@bayern.de -t "$mail_aim" -u "$log_mail_subject" -o tls=no
		done

		[ "$1" != "0" ] && {
			chroot_umount$distro "$chroot_path" 2> /dev/null
			workspace_erase "$iso_extr_dir/" "$chroot_path/" 2> /dev/null
		}

		exit $1
	}

	{
		[ "$log_file" == "" ] && log_file="`mktemp`"
		[ -f "$log_file" ] || touch "$log_file"
		tail -f "$log_file" --pid="$$" &

		chroot_path="`mktemp -d`"
		iso_extr_dir="`mktemp -d`"


		echo "Remaster LOG `date '+%Y-%m-%d'`" > "$log_file"
		echo "MODE: main_test" >> "$log_file"
		echo "HOST: `hostname`" >> "$log_file"
		echo >> "$log_file"

		echo "### S e t t i n g s ###" >> "$log_file"
		echo "#CD/DVD" >> "$log_file"
		echo "iso_source=\"$iso_source\"" >> "$log_file"
		echo "iso_destination=\"$iso_destination\"" >> "$log_file"
		echo "iso_lable=\"$iso_lable\"" >> "$log_file"
		echo >> "$log_file"

		echo "#Filesystem (for pxe)"  >> "$log_file"
		echo "filesystem_source=\"$filesystem_source\""
		echo "filesystem_destination=\"$filesystem_destination\""
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
		echo "log_mail_source=\"$log_mail_source\""
		echo "log_mail_aim=\"$log_mail_aim\""
		echo "log_mail_subject=\"$log_mail_subject\""
		echo ""

		echo "#Sonstiges" >> "$log_file"
		echo "tools_list=\"$tools_list\"" >> "$log_file"
		echo $'\n' >> "$log_file"

		echo "### Enviroment ###"
		echo "iso_extr_dir=\"$iso_extr_dir\"" >> "$log_file"
		echo "chroot_path=\"$chroot_path\"" >> "$log_file"
		echo $'\n\n' >> "$log_file"

		echo $'### R U N ... ###\n' >> "$log_file"


		### Check Settings ####

		# to ad
		# to ad


		# check script run with root
		[ "`whoami`" == "root" ] || {
			echo "### ERROR ### Remaster need ROOT permision!" >> "$log_file"
			on_exit 10 >> "$log_file"
		}

		[ "$distro" != "" ] && distro="_$distro"


		#If iso sorce & aim: entpake
		[ "$iso_source" != "" ] && [ "$iso_destination" != "" ] && {
			#Entpacke ISO
			iso_extract "$iso_source" "$iso_extr_dir" >> "$log_file"
			error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"
		}

		#If file source set
		if [ "$filesystem_source" != "" ]; then
			filesystem_img="$filesystem_source"
		else
			filesystem_img="`find  "$iso_extr_dir" -name filesystem.squashfs`"
			[ -e "$filesystem_img" ] || {
				echo "### ERROR ### Image \"$iso_source\" has no \"filesystem.squashfs\"" >> "$log_file"
				on_exit 15 >> "$log_file"
			}
		fi

		### Normal ###

		### 3. Entpacken der Dateien des Live-Systems
		

		filesystem_extract "$filesystem_img" "$chroot_path" >> "$log_file"
		error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

		### 4. Vorbereiten für chroot-Umgebung:

		chroot_initial$distro "$chroot_path" >> "$log_file"
		error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

		### 5. Setzen der Netzwerk-Einstellungen:

		proxy_enable$distro "$chroot_path" "$proxy_host" "$proxy_port" >> "$log_file"
		error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

		dns_set "$chroot_path" "$domain" "$nameserver" >> "$log_file"
		error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

		### 6. Updaten von Desinfec't:
		os_update$distro "$chroot_path" >> "$log_file"
		error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

		### 7. Installation optionaler Tools:

		tools_add$distro "$chroot_path" "$tools_list" >> "$log_file"
		error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

		chroot_clean "$chroot_path" >> "$log_file"
		error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

		### 8. Umount - Chroot Umgebung auflösen

		chroot_umount$distro "$chroot_path" >> "$log_file"
		error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

		#Überprüfen ob alles ausgehängt wurde
		[ "`chroot_is_mounted "$chroot_path"`" == "true" ] && {
			echo "### ERROR ### Cant Unmount Chroot!" >> "$log_file"
			on_exit 21 >> "$log_file"
		}

		## Normal END ##

		[ "$filesystem_destination" != "" ] && filesystem_img="$filesystem_destination"

		### 9. Packen und Ersetzen der Dateien des Live-Systems
		[ -f "$filesystem_img" ] && rm "$filesystem_img" 2>> "$log_file" >> "$log_file"
		error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

		filesystem_pack "$chroot_path"  "$filesystem_img" >> "$log_file"
		error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"


		[ "$iso_destination" != "" ] && {
			tmp_var_2143445="`find  "$iso_extr_dir" -name filesystem.squashfs`"
			
			[ "$tmp_var_2143445" != "$filesystem_img" ] && {
				rm "$tmp_var_2143445" 2>> "$log_file" >> "$log_file"
				cp "$filesystem_img" "$tmp_var_2143445"
			}
			tmp_var_2143445=

			iso_create$distro "$chroot_path" "$iso_extr_dir" "$iso_destination" "$iso_lable" >> "$log_file"
			error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

			chmod 777 "$iso_destination"
			error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"
		}


		# wenn filesystem gewünscht dann
		[ "$filesystem_destination" != "" ] && {			
			chmod 777 "$filesystem_destination"
			error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"
		}

		workspace_erase "$iso_extr_dir/" "$chroot_path/" >> "$log_file"
		error_level="$?"; [ "$error_level" != "0" ] && on_exit $error_level >> "$log_file"

		on_exit 0
	}
}


#####################################################################################
################## F u n c t i o n s ################################################
#####################################################################################

### Workspace ###

#workspace_erase [workspace_path]
function workspace_erase() {
	echo -n "erase workspace ... "

	for dir in "$@"; do
		[ -d "$dir" ] && rm -r -f "$dir"
	done

	echo "done"
}

### Filesystem ###

#filesystem_extract [filesystem_img_source] [chroot_path]
function filesystem_extract() {
	echo "extract filesystem ..."

	#$1 = filesystem_img_source
	#$2 = chroot_path
	filesystem_img_source="$1"
	chroot_path="$2"
	filesystem_log="`mktemp`"

	#Überfrüfen der Parameter
	[ -f "$filesystem_img_source" ] || {
		echo "### ERROR ### filesystem_extract: squashfs \"$filesystem_img_source\" not exist!"
		return 11
	}

	[ "`mkdir -p "$chroot_path"`" != "" ] && {
		echo "### ERROR ### filesystem_extract: chroot_path \"$chroot_path\" can't create!"
		return 13
	}

	[ "`filesystem_get_type $chroot_path`" != "ext4" ] && [ "`filesystem_get_type $chroot_path`" != "btrfs" ] && {
		echo "### ERROR ### filesystem_extract: incorect filesystem (`filesystem_get_type $chroot_path`)!"
		return 22
	}

	rm -r "$chroot_path"

	#eigendliches entpacken
	unsquashfs -d "$chroot_path" "$filesystem_img_source" > "$filesystem_log" || {
		echo "### ERROR ### filesystem_extract: unsquashfs failed!"
		return 14
	}

	grep -v "\[" "$filesystem_log"
	rm "$filesystem_log"

	echo "done"
}

#filesystem_pack [chroot_path] [filesystem_img_destination]
function filesystem_pack() {
	echo "pack filesystem ..."

	#$1 = chroot_path
	#$2 = filesystem_img_destination
	chroot_path="$1"
	filesystem_img_destination="$2"
	filesystem_log="`mktemp`"

	#Überfrüfen der Parameter
	[ -d "$chroot_path" ] || {
		echo "### ERROR ### filesystem_extract: chroot_path \"$chroot_path\" not exist!"
		return 12
	}

	#loslegen ...
	rm -f "$filesystem_img_destination"
	mksquashfs "$chroot_path" "$filesystem_img_destination" > "$filesystem_log" || {
		echo "### ERROR ### filesystem_pack: mksquashfs failed!"
		return 13
	}

	grep -v "\[" "$filesystem_log"
	rm "$filesystem_log"

	echo "done"
}

#filesystem_get_type [dir]
#(String)-> ext4, ext2, btfs, fuse, ...
function filesystem_get_type() {
	fs_aTemp=(`df -T "$1"`)
	echo ${fs_aTemp[9]}
}

### ISO ###

#iso_extract [iso_source] [iso_extr_dir]
function iso_extract() {
	echo -n "extract iso ... "

	#$1 = iso_source
	#$2 = iso_extr_dir

	#check root
	[ "`whoami`" == "root" ] || {
		echo "### ERROR ### iso_extract: need root permision!"
		return 10
	}

	iso_source="$1"
	[ -f "$iso_source" ] || {
		echo "### ERROR ### iso_extract: ISO \"$iso_source\" not exist!"
		return 11
	}

	iso_extr_dir="$2"
	[ -d "$iso_extr_dir" ] || {
		echo "### ERROR ### iso_extract: aim directory not exist!"
		return 12
	}

	#mace tmp mountpoint
	tmpdir="`mktemp -d`"
	[ -d "$iso_extr_dir" ] && {
		rm -r "$iso_extr_dir/"
		mkdir "$iso_extr_dir"
	} 

	#copy files ...
	mount -o loop,ro "$iso_source" "$tmpdir"
	cp -f -r "$tmpdir/"* "$iso_extr_dir"

	#clear tmp mountpoint
	umount "$iso_source"
	rm -r "$tmpdir"
	tmpdir=

	echo "done"
}

#iso_create [chroot_path] [iso_extr_dir] [iso_destination] [iso_lable]
function iso_create() {
	echo -n "create iso ..."

	chroot_path="$1"
	iso_extr_dir="$2"
	iso_destination="$3"
	iso_lable="$4"

	[ -e "$iso_destination" ] && rm "$iso_destination"

	xorriso -as mkisofs -graft-points -c isolinux/boot.cat -b isolinux/isolinux.bin \
	-no-emul-boot -boot-info-table -boot-load-size 4 -isohybrid-mbr \
	"$chroot_path/usr/lib/syslinux/isohdpfx.bin" \
	-eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot \
	-isohybrid-gpt-basdat -V "$iso_lable" \
	-o "$iso_destination" \
	-r -J "$iso_extr_dir" \
	--sort-weight 0 / --sort-weight 2 /boot --sort-weight 1 /isolinux

	echo "done"
}

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

### chroot ###

#chroot_initial [chroot_dir]
function chroot_initial() {
	echo -n "initial chroot ... "

	#$1 = chroot_dir

	#check chroot dir
	chroot_dir="$1"
	[ -d "$chroot_dir" ] || {
		echo "### ERROR ### chroot_initial: chroot directory not exist!"
		return 12
	}

	#mount virus definitions
	mount -t tmpfs tmpfs "$chroot_dir/tmp"
	mount -t tmpfs tmpfs "$chroot_dir/root"
	mount --bind /dev "$chroot_dir/dev"
	mount --bind /proc "$chroot_dir/proc"

	rm "$chroot_dir/etc/resolv.conf"
	cp "/etc/resolv.conf" "$chroot_dir/etc/resolv.conf"

	echo "done"
}

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

#chroot_clean [chroot_dir]
function chroot_clean() {
	echo "clean chroot ... "

	chroot_dir="$1"

	chroot "$chroot_dir" /bin/bash -c "apt-get clean" 
	chroot "$chroot_dir" /bin/bash -c "rm -r /var/cache/apt/*" 
	chroot "$chroot_dir" /bin/bash -c "apt-get update" 
	chroot "$chroot_dir" /bin/bash -c "apt-get check" 

	echo "done"
}

#chroot_umount [chroot_dir]
function chroot_umount() {
	echo -n "unmount chroot ... "

	#check chroot dir
	chroot_dir="$1"
	[ -d "$chroot_dir" ] || {
		echo "### ERROR ### chroot_umount: chroot directory not exist!"
		return 12
	}

	for d in "$chroot_dir/tmp" "$chroot_dir/root" "$chroot_dir/proc" "$chroot_dir/dev" ; do
   		umount $d
   		retval=$?
   		[ "$retval" -gt 0 ] && {
      		echo "### ERROR ### chroot_umount: can't umount \"$d\"!"
      		return 21
   		}
	done

	echo "done"
}

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

#chroot_is_mounted [chroot_dir]
#(Boolean)-> true | false
function chroot_is_mounted() {
	#$1 = chroot directory

	if [ "`mount | grep "$1"`" != "" ] ; then
		#ther is smething mounted
		echo "true"
	else
		#nothing mounted
		echo "false"
	fi
}

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

	#Wenn alle drei Parameter gegeben
	if [ "$proxy_host" != "" ] && [ "$proxy_port" != "" ] ; then
		echo "http_proxy=http://$proxy_host:$proxy_port" >> $chroot_dir/etc/environment
		echo "https_proxy=http://$proxy_host:$proxy_port" >> $chroot_dir/etc/environment
		echo "ftp_proxy=http://$proxy_host:$proxy_port" >> $chroot_dir/etc/environment

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

### Update ###

#os_update [chroot_dir]
function os_update() {
	echo "updating os ... "
	#$1 = chroot directory

	chroot_dir="$1"

	chroot "$chroot_dir" /bin/bash -c "apt-get update" > /dev/null
	[ "$?" == "0" ] && echo "apt-get update: success"
	chroot "$chroot_dir" /bin/bash -c "apt-get dist-upgrade -y" | grep -v "wird eingerichtet ..." | grep -v "Vormals nicht ausgewähltes Paket" | grep -v "Entpacken von" | grep -v "Holen: " | grep -v "Trigger für" | grep -v "update-alternatives:"
	chroot "$chroot_dir" /bin/bash -c "apt-get clean"

	echo "done"
}

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

### Tools ###

#tools_add [chroot_dir] [tools_list]
function tools_add() {
	echo "add tools ... "
	#$1 = chroot directory
	chroot_dir="$1"
	tools_list="$2"

	chroot "$chroot_dir" /bin/bash -c "apt-get update" > /dev/null
	[ "$?" == "0" ] && {
		echo "apt-get update: success"
		chroot "$chroot_dir" /bin/bash -c "apt-get install -y $tools_list" | grep -v "wird eingerichtet ..." | grep -v "Vormals nicht ausgewähltes Paket" | grep -v "Entpacken von" | grep -v "Holen: " | grep -v "Trigger für" | grep -v "update-alternatives:"
	}

	echo "done"
}

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

### Handle Parameters & Modes ###

if [ -z "$1" ]; then
	main_newiso
	#main_desinfect_pxe_update
	#main_test
	
else
	main_$1
fi


#packet=plumadfd
#[ "`dpkg -l $packet 2>&1`" == "dpkg-query: Kein Paket gefunden, das auf $packet passt" ] && {
#	echo not installed $packet
#}
#Benötigte packete:
# unsquashfs; mksquashfs; xorriso; wget; sed; chroot; sendemail;
# apt install xorriso wget sed sendemail squashfs-tools
