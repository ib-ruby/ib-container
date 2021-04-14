#!/bin/bash
source config.sh
if [ `echo ps -ef | grep autossh | grep PORT | awk ' { print $2 }' | wc -l` -eq  0  ] ; then
	sudo bash /etc/network/if-up.d/reverse_ssh_tunnel
fi
