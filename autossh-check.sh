#!/bin/bash
source config.sh
if [ `ps -ef | grep autossh | grep PORT | awk ' { print $2 }' | wc -l` -eq  0  ] ; then
	sudo bash /etc/network/if-up.d/reverse_ssh_tunnel
fi
if [ `ps -ef | grep java | grep 981 | awk ' { print $2 }' | wc -l` -eq  0  ] ; then
	cd ~
	DISPLAY=:99 ./ibc/gatewaystart.sh -inline &
	sleep 60
fi

