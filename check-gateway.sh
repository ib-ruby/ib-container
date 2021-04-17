#!bin/bash
# returns 2 to the gateway is running
installation=`ls ~/Jts  | awk ' /^[0-9]/  { print $1 } '`
ps -ef | grep java | grep $installation | awk ' { print  }' | wc -l

