#!/bin/bash

### Setup a lxc-container 
### Install interactive brokers trading software
### Setup the environment for autologin and daily restart
### Setup networking ans implement a secure login via ssh-tunnel
### Start simple-monitor



### Parameter
#### $1          name of the container
#### $2          ib-login
#### $3          ib-password
#### $3          port of ssh tunnel (monitoring port =  port + 10000)
#### $4          middleman server
#### $5          middleman user

### Prerequisites to run the script
### 
### * A running LXD Server 
### * Put the public ssh certificate of the middleman server into the working dir of this script

source config.sh

print_status(){  
       	echo "[+] $*" 
}
print_error() { 
      	echo "[!] $*"
}
print_question() { 
      	echo "[?] $*"
}

if [ -f $logfile ] ; then  rm $logfile ; fi
touch $logfile
SILENT=$logfile

if test -n "${1}"; then
	CONTAINER=${1}
elif  test  -z $CONTAINER  ; then
	read -p "[?] Name des Containers: " CONTAINER
fi
if test -z $CONTAINER ; then
	print_error "Es muss eine Bezeichnung für den Container angegeben werden!"
	exit 255
fi

if test -n "${2}";  then
	LOGIN=${2}
elif  test  -z "$LOGIN"  ; then  
	read -p "[?] Interactive Brokers Account Login: " LOGIN
fi

if test -n "${3}"; then
	PASS=${3}
elif  test  -z "$PASS" ; then 
	read -ps "[?] Interactive Brokers Account Password: " PASS 
fi

if test -z $DEMOACCOUNT ; then
	read -p "[?] Demoaccount? [y|N]:" 
	if [  "$REPLY" = "y" ]  || [  "$REPLY" == "j" ] ; then
		DEMOACCOUNT=1
	else 
		DEMOACCOUNT=0
	fi
fi

if test -n "${5}" ; then
	SSH_MIDDLEMAN_SERVER=${5}
elif test -z "$SSH_MIDDLEMAN_SERVER"  ; then
	read -p "[?] Bezeichnung oder IP des Endpunkts des SSH-Tunnels [return=keinen Tunnel verwenden]: " SSH_MIDDLEMAN_SERVER
fi

if test -z $SSH_MIDDLEMAN_SERVER  ; then
	SETUP_AUTOSSH=0
else
	SETUP_AUTOSSH=1
	if test -n "${4}" ; then
		SSH_PORT_NUMBER=${4}
	elif test -z "$SSH_PORT_NUMBER" ;  then 	
		print_status  "Erzeuge zufällige Ports ..."
		SSH_PORT_NUMBER=$[ ( $RANDOM % 10000 )  + 10000 ]
		read -p "[?] Port für SSH-Tunnel [$SSH_PORT_NUMBER]: " port
		if [ -n $port ] ; then
			SSH_PORT_NUMBER=$port
		fi
	fi
	SSH_MONITORING_PORT_NUMBER=`expr $SSH_PORT_NUMBER + 10000`

	if test -n "${6}" ; then
		SSH_MIDDLEMAN_USER=${6}
	elif test -z "$SSH_MIDDLEMAN_USER" ; then
		user=`whoami`
		read  -p "[?] Benutzer auf dem Endpunkt des SSH-Tunnels: $SSH_MIDDLEMAN_SERVER:[$user] "  SSH_MIDDLEMAN_USER
		if [[ -z $SSH_MIDDLEMAN_USER ]]; then
			SSH_MIDDLEMAN_USER=$user
		fi
	fi
fi
read -p  "[?] Gateway Ausgabe in Framebuffer umleiten? [Y/n]:" 
if  [  "$REPLY" = "n" ]  ; then
        TWS_DISPLAY=:0
else
	TWS_DISPLAY=:99
fi


print_status "......................................"
print_status "Containter: $CONTAINER"
print_status "Login:      $LOGIN"
print_status "Password:   **** " #  $PASS"
print_status "Demoaccount: `if [ $DEMOACCOUNT -eq 1 ] ; then echo "ja"  ; else echo "nein"; fi ` "
print_status "Gateway/TWS: `if [ "$PRODUCT" =  tws ]  ; then echo "$INSTANCE" ; else echo "Gateway" ; fi `"
if [ $SETUP_AUTOSSH -eq 1 ] ; then
	print_status "PORT:       $SSH_PORT_NUMBER"
	print_status "Backport:   $SSH_MONITORING_PORT_NUMBER"
	print_status "Middleman:  $SSH_MIDDLEMAN_SERVER"
	print_status "Middleman User: $SSH_MIDDLEMAN_USER"
else
	print_status "SSH-Tunnel wird nicht installiert "
fi
print_status "Ausgabe für Gateway: $TWS_DISPLAY "
print_status "......................................"
read -p "[?] Installieren? [Y/n]:" 
if  [[ -n $REPLY  ||  $REPLY == 'n' ]]  ; then
	exit 255
fi







check_lxd(){
#LXD vereint die Vorteile virtueller Rechner (Xen et.\,al.)  und die Ressourceneffizienz von Containern (aka Docker). 
#Es ist Open-Source und gut dokumentiert. Ferner gibt eine API für eine Steuerung durch Skripte.
#Canonical positioniert LDX als Standard für Cloud-Anwendungen.
#
#Unter Ubuntu ist die Verwendung entsprechend einfach.
#
##  Voraussetzung
#
# --- sudo lxd init  ---

## Wir testen die Version

	if  [ `systemctl is-active lxd.service` = "active" ] || [ `snap list | grep -c lxd ` -eq 1 ]   ; then
		print_status "LXD ist installiert und gestartet"
	else
		print_error "LXD ist nicht installiert oder nicht aktiv"
		print_error "Abbruch!"
		exit 99
	fi
	lxd_version=`lxd --version  | awk -F'.' '{ print $1 }'`
	lxd_subversion=`lxd --version  | awk -F'.' '{ print $2 }'`
	if [ $lxd_version -lt $MIN_LXD_VERSION ] || [ $lxd_subversion -lt $MIN_LXD_SUBVERSION ] ; then
		print_error "LXD-Version nicht geeignet. "
		print_error "Mindestens 4.11 ist erforderlich. "
		print_error "`lxd --version` gefunden "
		return 1
	else
		print_status  "LXD version `lxd --version` installiert  --- OK"
		return 0
	fi
}

prepare_lxd(){
## Ist Ubuntu-Minimal bereits als Remote angelegt?
	if lxc remote list | grep -q ubuntu-minimal  ; then
		print_status "Ubuntu-minimal ist bereits als remote gelistet"
	else
		lxc remote add --protocol simplestreams ubuntu-minimal https://cloud-images.ubuntu.com/minimal/releases/
	fi

## GUI-Profil anlegen
#
#Aufsetzen für X11-Nutzung

	if test -f  lxdguiprofile.txt  ; then
		print_status "GUI-Profilidatei ist bereits heruntergeladen"
	else
		wget https://blog.simos.info/wp-content/uploads/2018/06/lxdguiprofile.txt  
	fi
	if lxc profile show gui 1>/dev/null;  then
		print_status "GUI Profil ist bereits angelegt"
	else
		lxc profile create gui
	        lxc profile edit gui < lxdguiprofile.txt
		# alias anlegen
		lxc alias add  open  'exec @ARGS@ -- sudo --login --user ubuntu' 
	fi

}


launch_image(){
## Test ob das Image bereits angelegt ist
	if  lxc list | grep -q $CONTAINER  ; then 
		return 1
	else
		lxc launch --profile default --profile gui  ubuntu-minimal:f $CONTAINER
		print_status "$LXD_DELAY Sekunden warten, bis das Netzwerk betriebsbereit ist"
		sleep $LXD_DELAY 
		return 0
	fi
}


download_ib_software(){
	if [ -f $IB_PROGRAM ] ; then
		:
	else	
		print_status "Hole $PRODUCT vom offiziellen Server"
		wget $IB_PATH
		chmod a+x $IB_PROGRAM
	fi
}

check_container(){
### Test ob der Container korrekt angelegt wurde
### 1. Status =  Running
### 2. IPV4 muster ist vorhanden

	if lxc list | grep -q $CONTAINER && [ `lxc list | grep $CONTAINER | awk -F '|' '{ print $3 }' ` = "RUNNING" ] && [ `lxc list | grep $CONTAINER |  awk -F'|' '{ if($4 ~ /[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/ ) {print 1} else {print 0}}'` -eq 1 ] ; then
		return 0
	else
		print_error 'Networking is not active'
		return  1
	fi
}


init_container(){
## Check ob Container jungfraeulich ist
## Containerzertifikate installieren
## Java JRE installieren
## TWS / Gateway installieren
	local access_container="lxc exec $CONTAINER -- sudo --login --user ubuntu --"
	if test " `$access_container ls  /home/ubuntu | wc -l ` -eq 0 "  ; then
		print_status "Home-Directory des Containers ist leer"
		print_status "Installiere $PRODUCT"
		print_status "warte $LXD_DELAY  Sekunden bis sich der Container initialisiert hat"
		sleep $LXD_DELAY 

		print_status "Installiere Java  Das dauert einige Minuten ..."
		$access_container  sudo apt-get update   >> $SILENT  
		$access_container  sudo apt-get install -y openjdk-14-jre    >> $SILENT  	

#	testen, ob java installiert ist: 
  		if test " `$access_container dpkg -s openjdk-14-jre | grep -c installed ` -eq 1 " ; then 
			print_status "Java erfolgreich installiert"
		else
			print_error "Java Installation wird später nachgeholt"
		fi

		lxc file push keygen.sh $CONTAINER/home/ubuntu/
		$access_container /home/ubuntu/keygen.sh
		## overwrite id_rsa keys if provided in certificates dir

		if [ -d certificates ] ; then                       #  directory exists
			if [ -s certificates ] ; then               #  its not empty
				cd certificates 
				for file in *
				do
					lxc file push $file $CONTAINER/home/ubuntu/.ssh/
					$access_container chmod 600 /home/ubuntu/.ssh/$file
				done
				cd ..
				print_status "Zertifikate erfolgreich installiert"
			fi
		fi
		lxc file push $IB_PROGRAM $CONTAINER/home/ubuntu/
		print_status "Installiere ${PRODUCT}.  Das dauert einige Minuten ..."
		#$access_container DISPLAY= $IB_PROGRAM <<<""$'\n' 
		lxc exec --user 1000 --group 1000 --env "DISPLAY=" $CONTAINER -- bash --login /home/ubuntu/$IB_PROGRAM <<<""$'\n'  >> $SILENT

		lxc file push check-gateway.sh $CONTAINER/home/ubuntu/
		return 0
	else
		print_error "Container ist nicht leer. Konfiguration übersprungen!"
		return 1
	fi
}


setup_xvfb(){
	local access_container="lxc exec $CONTAINER -- sudo --login --user ubuntu --"
	$access_container  sudo apt-get install -y xvfb  >> $SILENT  
	lxc file push xvfb.service $CONTAINER/home/ubuntu/
	$access_container sudo mv /home/ubuntu/xvfb.service /lib/systemd/system/xvfb.service
	$access_container sudo chmod +x /lib/systemd/system/xvfb.service
	$access_container sudo systemctl enable /lib/systemd/system/xvfb.service
	$access_container sudo systemctl start xvfb.service
	# autostart xvfb
	$access_container sudo systemctl enable xvfb
#	$access_container export DISPLAY=:99
	
}

apply_ibc(){
	# Download der IBC-Software
	# Kopieren in Container
	# Entpacken und Rechte der Skripte setzen
	# Startprogramm anpassen
	# Autostart per Cron aufsetzen
	local ibc_file=IBCLinux-$IBC_VERSION.zip 
	local access_container="lxc exec $CONTAINER -- sudo --login --user ubuntu -- "
	if [ -f  $ibc_file ] ; then
		print_status "IBC-$IBC_VERSION ist bereits lokal vorhanden "
	else	
		print_status  "Hole IBC-Archiv  vom GitHub-Server"
		wget $IBC_PATH  >> $SILENT 
	fi
	## Erstelle ibc-Verzeichnis im Container
	if [ `$access_container find /home/ubuntu -type d -name ibc | wc -l ` -ne  0 ] ; then
		print_error "Verzeichnis ibc bereits vorhanden. "
		print_error "Installation von IBC wird übersprungen."
		print_error "Es wird keine crontab installiert."
	else
		gw_installation=`ls ~/Jts  | awk ' /^[0-9]/  { print $1 } '`

		$access_container sudo apt-get install -y  openjdk-14-jre  software-properties-common  unzip  cron >> $SILENT  	
		$access_container mkdir ibc
		lxc file push $ibc_file $CONTAINER/home/ubuntu/ibc/
		$access_container unzip ibc/$ibc_file -d ibc   >> $SILENT 
		$access_container chmod a+x ibc/gatewaystart.sh
		$access_container chmod a+x ibc/twsstart.sh
		$access_container chmod a+x ibc/scripts/ibcstart.sh
		$access_container chmod a+x ibc/scripts/displaybannerandlaunch.sh
		$access_container sed -i -e  '80 s/edemo/'"${LOGIN}"'/' -e ' 85 s/demouser/'"${PASS}"'/' /home/ubuntu/ibc/config.ini
		if [ $DEMOACCOUNT -eq 1 ] ; then
			$access_container sed -i ' 143 s/=live/=paper/ ' /home/ubuntu/ibc/config.ini
#			AcceptNonBrokerageAccountWarning=no
			$access_container sed -i ' 322 s/=no/=yes/ ' /home/ubuntu/ibc/config.ini
		fi
#		MinimizeMainWindow=no
#		$access_container sed -in ' 207 s/=no/=yes/ ' /home/ubuntu/ibc/config.ini
		if [ "$PRODUCT" = "tws" ] ; then
			$access_container sed -i ' 21 s/978/$gw_installation/ ' /home/ubuntu/ibc/twsstart.sh 
#			$access_container sed -i ' 23 s/=/=paper/ ' /home/ubuntu/ibc/twsstart.sh 
			$access_container sed -i ' 25 s/\/opt/\~/ ' /home/ubuntu/ibc/twsstart.sh
		else
			$access_container rm ibc/twsstart.sh
		fi
		$access_container sed -i ' 21 s/972/$gw_installation/ ' /home/ubuntu/ibc/gatewaystart.sh 
#		$access_container sed -i ' 23 s/=/=paper/ ' /home/ubuntu/ibc/gatewaystart.sh 
		$access_container sed -i ' 25 s/\/opt/\~/ ' /home/ubuntu/ibc/gatewaystart.sh
		local lxd_display=`$access_container echo $DISPLAY`
		# set display , if no DISPLAY setting is found, use :99 (xvfb)
		if [ $lxd_display ] ; then 
			if [ "$TWS_DISPLAY" == ":0" ] ; then
				TWS_DISPLAY=$lxd_display
			fi
		else
#			$access_container  export DISPLAY=:99 
			TWS_DISPLAY=:99
		fi
		# write entry to cronfile (overwrite previous entries ) and install it on the container	
		echo 'START_TIME * * 1-5 export DISPLAY=ibc-display && /bin/bash /home/ubuntu/ibc/gatewaystart.sh -inline' > ibc_cronfile
		if [ $INSTANCE = "tws" ] ; then
			sed -i ' s/gateway/tws/ ' ibc_cronfile
			sed -i ' s/ibc-display/$lxd_display/ ' ibc_cronfile
		else
			sed -i " s/ibc-display/$TWS_DISPLAY/ " ibc_cronfile
		fi
		sed -i  " s/START_TIME/$START_TIME/ "  ibc_cronfile 

		lxc file push ibc_cronfile $CONTAINER/home/ubuntu/
		lxc file push start_framebuffer_gateway.sh  $CONTAINER/home/ubuntu/
		lxc file push start_gateway.sh  $CONTAINER/home/ubuntu/
		lxc file push stop_gateway.sh  $CONTAINER/home/ubuntu/
		$access_container chmod a+x start_framebuffer_gateway.sh 
		$access_container chmod a+x start_gateway.sh 
		$access_container chmod a+x stop_gateway.sh 
		$access_container  crontab -u ubuntu /home/ubuntu/ibc_cronfile 
		$access_container  rm /home/ubuntu/ibc_cronfile 
	fi
}

# where to fetch simple monitor



install_simple_monitor(){
	# Ruby installieren
	# tmux installieren
	# elinks installieren
	# tmux- und elinks-Konfigurationen kopieren
	# Simple-Monitor installieren
	local access_container="lxc exec $CONTAINER -- sudo --login --user ubuntu --"
	# where to fetch simple monitor
	if [[ $GIT_SERVER == *[@]* ]] ; then
		SIMPLE_MONITOR_SOURCE=${GIT_SERVER}:/${GIT_REPOSITORY}
	else
		SIMPLE_MONITOR_SOURCE=https://${GIT_SERVER}/${GIT_REPOSITORY}
	fi
	
	if [ `$access_container find /home/ubuntu -type d -name  $SIMPLE_MONITOR_DIRECTORY | wc -l ` -ne  0 ] ; then
		print_status "$SIMPLE_MONITOR_DIRECTORY ist bereits angelegt"
		return 1
	else 
		{
		$access_container  sudo apt-add-repository -y ppa:rael-gc/rvm
		$access_container  sudo apt-get update  
		$access_container  sudo apt-get install -y rvm elinks git tmux $INSTALL_ADDITONAL_PROGRAMS
		$access_container  sudo usermod -a -G rvm ubuntu
		$access_container  rvm install $RUBY_VERSION	 
		$access_container  gem install bundler  

		if [[ $GIT_SERVER == *[@]* ]] ; then
			$access_container  ssh  -o "StrictHostKeyChecking=no"  $GIT_SERVER -C "ls" 2>&1 1>/dev/null  # suppress ssh warnings
		fi
		$access_container  git clone --branch $SIMPLE_MONITOR_BRANCH  --single-branch $SIMPLE_MONITOR_SOURCE $SIMPLE_MONITOR_DIRECTORY


		lxc file push install_simple_monitor.sh ${CONTAINER}/home/ubuntu/

		if [ `$access_container find /home/ubuntu/${SIMPLE_MONITOR_DIRECTORY} -type f -name config.yml | wc -l ` -eq  0 ] ; then
			lxc file push config.yml $CONTAINER/home/ubuntu/${SIMPLE_MONITOR_DIRECTORY}/
		fi
		$access_container sed -i " 3 s/simple-monitor/${SIMPLE_MONITOR_DIRECTORY}/ "  /home/ubuntu/install_simple_monitor.sh
		if [ $DEMOACCOUNT -eq 0 ] ; then
			if [ "$INSTANCE" = tws ] ; then
			$access_container  sed -i 's/:host: localhost/&:7496/g'  /home/ubuntu/${SIMPLE_MONITOR_DIRECTORY}/config.yml
			else
			$access_container  sed -i 's/:host: localhost/&:4001/g'  /home/ubuntu/${SIMPLE_MONITOR_DIRECTORY}/config.yml
			fi
		elif [ "$INSTANCE" = tws ] ; then
			$access_container  sed -i 's/:host: localhost/&:7497/g'  /home/ubuntu/${SIMPLE_MONITOR_DIRECTORY}/config.yml
		fi 
		$access_container  ./install_simple_monitor.sh  
		} >> $SILENT
		return 0
	fi 
} 

setup_reverse_tunnel(){
	# Kopiere das Skript in den Container
	# SSH für sicheren passwortlosen Zugang aufsetzen
	# reverse tunnel aufsetzen
	# container neu starten und tunnel testen
	local access_container="lxc exec $CONTAINER -- sudo --login --user ubuntu --"
	
	check_tunnel(){
		if [ `$access_container ps -ef | grep -c localhost:22 ` -eq 1 ] ; then 
			return 0
		else
			return 1
		fi
	}
	
	check_tunnel
        if [ $? -ne 0 ] ; then

		$access_container sudo apt-get install -y openssh-server autossh  >> $SILENT  # add .ssh dir 
		# download public-key and install it locally, but only if the containter certificate is created locally
		if [ -d certificates ]  &&  [ -s certificates ] ; then   
			:
		else		
			lxc file pull $CONTAINER/home/ubuntu/.ssh/id_rsa.pub $CONTAINER.pub
			echo ""
			echo " ++++++++++++++++++++++++++++++++++++++++++++++ "
			echo " Container-Zertifikat heruntergeladen!          "
			echo " "
			echo " ------>  $CONTAINER.pub  <------               "
			echo " "
			echo " Bitte manuell an ~/ssh/autorized_keys auf dem  "
			echo " Middleman-Server anfügen!                      "
			echo " ++++++++++++++++++++++++++++++++++++++++++++++ "
			read -p "nach <CR>   gehts weiter"   read
		fi
		

		print_status "Installiere lokal abgelegte Zertifikate im Container"
		# install certificates to access the container via ssh and reverse ssh
		touch certificates.sh
		for certificate in *.pub 
		do
			[ -f $certificate ] || continue
			if [ "$certificate" = dummy.pub ]  || [ "$certificate" = $CONTAINER.pub ] ; then
				:
			else
				print_status "installiere $certificate "
				cat $certificate >>  certificates.sh
			fi
		done
		lxc file push  certificates.sh $CONTAINER/home/ubuntu/.ssh/authorized_keys
		$access_container chmod 600 /home/ubuntu/.ssh/authorized_keys
		rm certificates.sh

		echo "#!/bin/sh

			# This is the username on your local server who has public key authentication setup at the middleman
			USER_TO_SSH_IN_AS=$SSH_MIDDLEMAN_USER

			# This is the username and hostname/IP address for the middleman (internet accessible server)
			MIDDLEMAN_SERVER_AND_USER=$SSH_MIDDLEMAN_USER@$SSH_MIDDLEMAN_SERVER

			# Port that the middleman will listen on (use this value as the -p argument when sshing)
			PORT_MIDDLEMAN_WILL_LISTEN_ON=$SSH_PORT_NUMBER

			# Connection monitoring port, don't need to know this one
			AUTOSSH_PORT=$SSH_MONITORING_PORT_NUMBER

			# Ensures that autossh keeps trying to connect
			AUTOSSH_GATETIME=0
			su -c \"autossh -f -N -R *:\${PORT_MIDDLEMAN_WILL_LISTEN_ON}:localhost:22 \${MIDDLEMAN_SERVER_AND_USER} -oLogLevel=error  -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no\" ubuntu
			" > reverse-tunnel
		chmod +x reverse-tunnel  

		lxc file push reverse-tunnel ${CONTAINER}/${SSH_TUNNEL_LOCATION}
		rm reverse-tunnel

		print_status "SSH-Tunnel wird installiert." 

		lxc exec  $CONTAINER -- /$SSH_TUNNEL_LOCATION
		sleep  $LXD_DELAY
	fi
	check_tunnel
	if [ $? -eq 0 ] ; then 
		print_status "Revese Tunnel ist gestartet"
	else
		print_error "Reverse SSH Tunnel ist noch inaktiv ... "
	fi
	# copy autossh-check.sh, customize it, add to crontab and install newn crontab
	lxc file push autossh-check.sh $CONTAINER/home/ubuntu/
	$access_container sed -i " s/PORT/${SSH_PORT_NUMBER}/ " /home/ubuntu/autossh-check.sh
	$access_container chmod a+x /home/ubuntu/autossh-check.sh
	echo '*/5 * * * * /bin/bash  /home/ubuntu/autossh-check.sh' >> ibc_cronfile
	lxc file push ibc_cronfile $CONTAINER/home/ubuntu/
	$access_container  crontab -u ubuntu /home/ubuntu/ibc_cronfile 
	$access_container  rm /home/ubuntu/ibc_cronfile 
}

run_ats(){
	# starte die IB-Software
	local access_container="lxc exec $CONTAINER -- sudo --login --user ubuntu --"
	$access_container /home/ubuntu/ibc/${INSTANCE}start.sh -inline &
	sleep  $LXD_DELAY
	sleep  $LXD_DELAY
        $access_container /home/ubuntu/${SIMPLE_MONITOR_DIRECTORY}/start-simple-monitor
	return 0
}
## Hier gehts los

check_lxd
if [ $? -ne 0 ] ; then exit 2 ; fi                     # return code 2 ---> wrong LXD version

prepare_lxd

launch_image

download_ib_software

init_container
print_status "......................................"
print_status " Container ${CONTAINER} ist angelegt     "

setup_xvfb
print_status " Framebuffer device eingerichtet         "



print_status "Installiere IBC " 
apply_ibc  

print_status "Installiere simple-monitor " 
install_simple_monitor 
 
if [ $SETUP_AUTOSSH -eq 1 ] ; then 
	setup_reverse_tunnel
	print_status "Reverse Tunnel ist aufgebaut      "
fi
run_ats  


