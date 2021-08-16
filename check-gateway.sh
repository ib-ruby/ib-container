#!/bin/bash
# returns 2 if the gateway is running
# it tests the number of the first entry returned by 'ls ~/Jts', which is the TWS-Version Number.
installation=`ls ~/Jts  | awk ' /^[0-9]/  { print $1 } '`
if [ `ps -ef | grep java | grep $installation | awk ' { print $2 }' | wc -l` -eq  0  ] ; then
	cd ~
	DISPLAY=TWS ./ibc/gatewaystart.sh -inline &
	sleep 60
fi

