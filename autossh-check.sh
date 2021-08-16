#!/bin/bash
installation=`ls ~/Jts  | awk ' /^[0-9]/  { print $1 } '`
if [ `ps -ef | grep autossh | grep PORT | awk ' { print $2 }' | wc -l` -eq  0  ] ; then
	sudo bash /etc/network/if-up.d/reverse_ssh_tunnel
fi
if [ `ps -ef | grep java | grep $installation | awk ' { print $2 }' | wc -l` -eq  0  ] ; then
	cd ~
	DISPLAY=TWS ./ibc/gatewaystart.sh -inline &
	sleep 60
fi

