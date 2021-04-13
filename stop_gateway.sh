#!/bin/bash
for process in ` ps -ef | grep tws | awk '{ print $2 }' ` ; do  
	kill -9  $process  2>&1 1>/dev/null

done
