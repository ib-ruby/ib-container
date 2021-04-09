#!/bin/bash
kill -9 `ps -ef | grep export | grep -v grep|awk '{print $2}'`
kill -9 `ps -ef | grep java | grep -v grep|awk '{print $2}'`
echo "Gateway instance killed"

