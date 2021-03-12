#!/bin/bash

### tws/gateway credentials
LOGIN=demouser
PASS=demopasswort
DEMOACCOUNT=1   # 1 oder 0

### Name des Containers
### Kann entweder als Parameter übergeben werden oder unten eingesetzt
if test -n "${1}"
then
	CONTAINER=${1}
else
	CONTAINER=t1     # specify container name
fi

### Welche Software soll genutzt werden
### Es kann entweder der IB-Gateway oder die TWS als API-Server genutzt werden.
### Die TWS kann entweder im Gatewaymodus oder als klassische GUI gestartet werden
PRODUCT=tws  # ibgateway or tws
INSTANCE=gateway   # gateway or tws

IB_PROGRAM=$PRODUCT-latest-standalone-linux-x64.sh 
IB_PATH=https://download2.interactivebrokers.com/installers/$PRODUCT/latest-standalone/$IB_PROGRAM

IBC_VERSION=3.8.5
IBC_PATH=https://github.com/IbcAlpha/IBC/releases/download/${IBC_VERSION}/IBCLinux-${IBC_VERSION}.zip

## Täglicher Start von Gateway/TWS im crontab-Format (Minute Stunde)
START_TIME='5 5'

## Delay time 
## Nach dem Aufsetzen eines LXD-Containers laufen noch Backgroundprozesse ab.
## Es muss gewartet werden, bis diese abgeschlossen sind.
## Auf langsamen Rechnern anpassen!
LXD_DELAY=3 # sec


### LXD-Requirements
MIN_LXD_VERSION=4
MIN_LXD_SUBVERSION=11

### Ruby Version
RUBY_VERSION=3.0.0



SILENT_INSTALL=0  # 0 verbose output
####  return codes
###
###  2            falsche LDX-Version
###  3            Container bereits angelegt
###  4            Container konnte nicht richtig initialisiert werden (kein Netzwerk) 
###  99           LXD ist nicht gestartet oder nicht vorhanden

###################################################################################################################
################## no modifications beyond this line ##############################################################
###################################################################################################################
### Speicherort der Konfiguration des ssh-tunnels
SSH_TUNNEL_LOCATION="/etc/network/if-up.d/reverse_ssh_tunnel"
if test -n "${2}"
then
	SSH_PORT_NUMBER=${2}
	SSH_MONITORING_PORT_NUMBER=`expr ${2} + 10000`
else
	echo "Kein Port angegeben.  Erzeuge einen zufälligen Port ..."
	SSH_PORT_NUMBER=$[ ( $RANDOM % 10000 )  + 10000 ]
	SSH_MONITORING_PORT_NUMBER=$[ ( $RANDOM % 10000 )  + 20000 ]
fi

SSH_MIDDLEMAN_USER=`whoami`
if test -n "${3}"
then
	SSH_MIDDLEMAN_SERVER=${3}
else
	echo "Kein Middleman Server angegeben, benutze localhost"
	SSH_MIDDLEMAN_SERVER=localhost
fi

if test -n "${4}"
then
	SSH_MIDDLEMAN_USER=${4}
fi

if [ $SILENT_INSTALL -ne 0 ] ; then
	SILENT=" 2>&1>/dev/null"
else
	SILENT=
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

	if [ `systemctl is-active lxd.service` = "active" ] ; then
		echo "LXD ist installiert und gestartet"
	else
		echo "LXD ist nicht installiert oder nicht aktiv"
		echo "Abbruch!"
		exit 99
	fi
	lxd_version=`lxd --version  | awk -F'.' '{ print $1 }'`
	lxd_subversion=`lxd --version  | awk -F'.' '{ print $2 }'`
	if [ $lxd_version -lt $MIN_LXD_VERSION ] || [ $lxd_subversion -lt $MIN_LXD_SUBVERSION ] ; then
		echo "LXD-Version nicht geeignet. "
		echo "Mindestens 4.11 ist erforderlich. "
		echo "`lxd --version` gefunden "
		return 1
	else
		echo "LXD version `lxd --version` installiert  --- OK"
		return 0
	fi
}

prepare_lxd(){
## Ist Ubuntu-Minimal bereits als Remote angelegt?
	if lxc remote list | grep -q ubuntu-minimal  ; then
		echo "Ubuntu-minimal ist bereits als remote gelistet"
	else
		lxc remote add --protocol simplestreams ubuntu-minimal https://cloud-images.ubuntu.com/minimal/releases/
	fi

## GUI-Profil anlegen
#
#Aufsetzen für X11-Nutzung

	if [ -f  lxdguiprofile.txt ] ; then
		echo "GUI-Profilidatei ist bereits heruntergeladen"
	else
		wget https://blog.simos.info/wp-content/uploads/2018/06/lxdguiprofile.txt  -o lxdguiprofile.txt
	fi
	if lxc profile list | grep -q gui ;  then
		echo "GUI Profil ist bereits angelegt"
	else
		lxc profile create gui
		cat lxdguiprofile.txt | lxc profile edit gui 
		# alias anlegen
		lxc alias add  ubuntu  'exec @ARGS@ -- sudo --login --user ubuntu' 
	fi

}


launch_image(){
## Test ob das Image bereits angelegt ist
	if  lxc list | grep -q $CONTAINER  ; then 
		echo "Container ist bereits angelegt"
		echo "Bitte Container >> $CONTAINER <<  zuerst manuell entfernen"
		return 1
	else
		lxc launch --profile default --profile gui  ubuntu-minimal:f $CONTAINER
		echo "$LXD_DELAY Sekunden warten, bis das Netzwerk betriebsbereit ist"
		sleep $LXD_DELAY 
		return 0
	fi
}


download_ib_software(){
	if [ -f $IB_PROGRAM ] ; then
		echo "$PRODUCT ist bereits lokal vorhanden "
	else	
		echo "Hole $PRODUCT vom offiziellen Server"
		wget $IB_PATH
		chmod a+x $IB_PROGRAM
	fi
}

check_container(){
### Test ob der Container korrekt angelegt wurde
### 1. Status =  Running
### 2. IPV4 muster ist vorhanden

	if lxc list | grep -q $CONTAINER && [ `lxc list | grep $CONTAINER | awk -F '|' '{ print $3 }' ` = "RUNNING" ] && [ `lxc list | grep $CONTAINER |  awk -F'|' '{ if($4 ~ /[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/ ) {print 1} else {print 0}}'` -eq 1 ] ; then
		echo "Container is active and running" 
		return 0
	else
		echo 'Networking is not active'
		return  1
	fi
}


init_container(){
## Check ob Container jungfraeulich ist
## Java JRE installieren
## TWS / Gateway installieren
	local access_container="lxc exec $CONTAINER -- sudo --login --user ubuntu -- "
	if [ `$access_container ls  /home/ubuntu | wc -l `  -eq 0 ]  ; then
		echo "Home-Directory des Containers ist leer"
		echo "Installiere $PRODUCT"
		echo "warte $LXD_DELAY  Sekunden bis sich der Container initialisiert hat"
		sleep $LXD_DELAY 

		echo "Installiere Java  Das dauert einige Minuten ..."
		$access_container  sudo apt update  $SILENT
		$access_container  sudo apt install -y openjdk-14-jre   $SILENT

		lxc file push $IB_PROGRAM $CONTAINER/home/ubuntu/
		echo "Installiere ${PRODUCT}.  Das dauert einige Minuten ..."
		#$access_container DISPLAY= $IB_PROGRAM <<<""$'\n' 
		lxc exec --user 1000 --group 1000 --env "DISPLAY=" $CONTAINER -- bash --login /home/ubuntu/$IB_PROGRAM <<<""$'\n'
#$SILENT

	else
		echo "Container ist nicht leer."
	fi
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
		echo "IBC-$IBC_VERSION ist bereits lokal vorhanden "
	else	
		echo "Hole IBC-Archib  vom Git-Archiv"
		wget $IBC_PATH SILENT
	fi
	## Erstelle ibc-Verzeichnis im Container
	if [ `$access_container find /home/ubuntu -type d -name ibc | wc -l ` -ne  0 ] ; then
		echo "Verzeichnis ibc bereits vorhanden. "
		echo "Installation von IBC wird übersprungen."
		echo "Es wird keine crontab installiert."
	else
		$access_container mkdir ibc
		$access_container  sudo apt install -y unzip cron $SILENT
		lxc file push $ibc_file $CONTAINER/home/ubuntu/ibc/
		$access_container  unzip ibc/$ibc_file -d ibc  $SILENT
		$access_container  chmod a+x ibc/gatewaystart.sh
		$access_container  chmod a+x ibc/twsstart.sh
		$access_container  chmod a+x ibc/scripts/ibcstart.sh
		$access_container  chmod a+x ibc/scripts/displaybannerandlaunch.sh
		$access_container sed -in -e  '80 s/edemo/'"${LOGIN}"'/' -e ' 85 s/demouser/'"${PASS}"'/' /home/ubuntu/ibc/config.ini
		if [ $DEMO_ACCOUNT -eq 1 ] ; then
			$access_container sed -n ' 23 s/=/=paper/ ' /home/ubuntu/ibc/config.ini
		fi
		if [ "$PRODUCT" = "tws" ] ; then
			$access_container sed -in ' 21 s/978/981/ ' /home/ubuntu/ibc/twsstart.sh 
			$access_container sed -in ' 23 s/=/=paper/ ' /home/ubuntu/ibc/twsstart.sh 
			$access_container sed -in ' 25 s/\/opt/\~/ ' /home/ubuntu/ibc/twsstart.sh
		else
			$access_container rm ibc/twsstart.sh
		fi
		$access_container sed -in ' 21 s/972/981/ ' /home/ubuntu/ibc/gatewaystart.sh 
		$access_container sed -in ' 23 s/=/=paper/ ' /home/ubuntu/ibc/gatewaystart.sh 
		$access_container sed -in ' 25 s/\/opt/\~/ ' /home/ubuntu/ibc/gatewaystart.sh
		touch ibc_cronfile
		local lxd_display=`$access_container echo $DISPLAY`
		echo 'START_TIME * * 1-5 export DISPLAY=ibc-display && /bin/bash /home/ubuntu/ibc/gatewaystart.sh -inline' > ibc_cronfile
		sed  -e  " 1 s/ibc-display/$lxd_display/ " -e " 1 s/START_TIME/$START_TIME/ " ibc_cronfile > t_c
		if [ $INSTANCE = "tws" ] ; then
			sed -in ' s/gateway/tws/ ' t_c
		fi

		lxc file push t_c $CONTAINER/home/ubuntu/ibc_cronfile
		rm t_c
		rm ibc_cronfile
		$access_container  crontab -u ubuntu /home/ubuntu/ibc_cronfile 
		$access_container  rm /home/ubuntu/ibc_cronfile 
	fi
}

install_simple_monitor(){
	# Ruby installieren
	# tmux installieren
	# elinks installieren
	# tmux- und elinks-Konfigurationen kopieren
	# Simple-Monitor installieren
	local access_container="lxc exec $CONTAINER -- sudo --login --user ubuntu -- "
	if [ `$access_container find /home/ubuntu -type d -name simple-monitor | wc -l ` -ne  0 ] ; then
		echo "simple monitor ist bereits angelegt"
		return 1
	else
		$access_container  sudo apt-get install -y software-properties-common 
		$access_container  sudo apt-add-repository -y ppa:rael-gc/rvm
		$access_container  sudo apt-get update
		$access_container  sudo apt-get install -y rvm 
		$access_container  sudo usermod -a -G rvm ubuntu
		$access_container  rvm install $RUBY_VERSION	
		$access_container  sudo apt -y install tmux vim elinks git 
		$access_container  git clone https://github.com/ib-ruby/simple-monitor.git
		$access_container  gem install bundler
		lxc file push install_simple_monitor.sh $CONTAINER/home/ubuntu/
		$access_container  ./install_simple_monitor.sh
		return 0
	fi 
} 

setup_reverse_tunnel(){
	# Kopiere das Skript in den Container
	# SSH für sicheren passwortlosen Zugang aufsetzen
	# reverse tunnel aufsetzen
	# container neu starten und tunnel testen
	local access_container="lxc exec $CONTAINER -- sudo --login --user ubuntu -- "
	if [ `$access_container find /home/ubuntu -type d -name .ssh | wc -l ` -ne  0 ] ; then
		echo "Verzeichnis .ssh ist bereits vorhanden."
	else
		$access_container sudo apt install -y openssh-server autossh  # add .ssh dir 
		# https://stackoverflow.com/questions/43235179/how-to-execute-ssh-keygen-without-prompt
			$access_container ssh-keygen -q -t rsa -N '' -f /home/ubuntu/.ssh/id_rsa <<<y 2>&1 >/dev/null
		# download public-key and install it locally
		lxc file pull $CONTAINER/home/ubuntu/.ssh/id_rsa.pub .
		cat id_rsa.pub >> ~.ssh/autorized_keys
		rm id_rsa.pub
		# install certificates to access the container via ssh and reverse ssh
		for certificate in *.pub 
		do
			[ -f $certificate ] || continue
			if [ "$certificate" = dummy.pub ] ; then
				echo `cat $certificate`	
			else
				lxc file push  $certificate $CONTAINER/home/ubuntu/
				$access_container cat $certificate >> /home/ubuntu/.ssh/authorized_keys
				$access_container rm $certificate 
			fi
		done

		echo "#!/bin/sh

		# This is the username on your local server who has public key authentication setup at the middleman
		USER_TO_SSH_IN_AS=$SSH_MIDDLEMAN_USERNAME

		# This is the username and hostname/IP address for the middleman (internet accessible server)
		MIDDLEMAN_SERVER_AND_USERNAME=$SSH_MIDDLEMAN_USERNAME@$SSH_MIDDLEMAN_SERVER

		# Port that the middleman will listen on (use this value as the -p argument when sshing)
		PORT_MIDDLEMAN_WILL_LISTEN_ON=$SSH_PORT_NUMBER

		# Connection monitoring port, don't need to know this one
		AUTOSSH_PORT=$SSH_MONITORING_PORT_NUMBER

		# Ensures that autossh keeps trying to connect
		AUTOSSH_GATETIME=0
		su -c \"autossh -f -N -R *:\${PORT_MIDDLEMAN_WILL_LISTEN_ON}:localhost:22 \${MIDDLEMAN_SERVER_AND_USERNAME} -oLogLevel=error  -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no\" ubuntu
		" > reverse-tunnel
		chmod +x reverse-tunnel  

		lxc file push reverse-tunnel ${CONTAINER}/${SSH_SCRIPT_LOCATION}
	home/ubuntu/
	#	ly sudo mv /home/ubuntu/reverse-tunnel $SSH_SCRIPT_LOCATION
		rm reverse-tunnel

	#	echo "Making script executable"
	#	chmod +x $SSH_SCRIPT_LOCATION

		echo "SSH-Tunnel ist installiert. Wird automatisch gestartet"
		
		$access_containter sudo  $SSH_SCRIPT_LOCATION
	fi
}

run_ats(){
	# starte die IB-Software
	local access_container="lxc exec $CONTAINER -- sudo --login --user ubuntu -- "
 	$access_container /home/ubuntu/ibc/${INSTANCE}start.sh -inline &
	sleep 5
        $access_container /home/ubuntu/simple-monitor/start-simple-monitor
	return 0
}
## Hier gehts los

check_lxd
if [ $? -ne 0 ] ; then exit 2 ; fi                     # return code 2 ---> wrong LXD version

prepare_lxd

launch_image
#if [ $? -ne 0  ] ; then  select_menue=1 ; fi			# return code 3

download_ib_software


init_container
if [ $? -ne 0  ] ; then exit 4 ; fi			# return code 3init_container

apply_ibc

install_simple_monitor

setup_reverse_tunnel

run_ats 


