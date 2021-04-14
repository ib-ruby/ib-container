#!/bin/bash
### ++++++++++++++++++++++++++++++++++++++++++++++
##  Config file to setup IB-Container          +++
### ++++++++++++++++++++++++++++++++++++++++++++++

### tws/gateway credentials  
###  leave empty for interactive mode
LOGIN=
PASS=
DEMOACCOUNT=   # 1 or 0

### predefine settings for ssh-tunnel
SSH_MIDDLEMAN_SERVER=
SSH_MIDDLEMAN_USER=
SSH_PORT_NUMBER=

### Name of Container
CONTAINER=

### Welche Software soll genutzt werden
### Es kann entweder der IB-Gateway oder die TWS als API-Server genutzt werden.
### Die TWS kann entweder im Gatewaymodus oder als klassische GUI gestartet werden

### Which program should be used
### Either 'ibgateway' or 'tws' are suitable  
### TWS can be started either as non-GUI Gateway or in classical GUI-Mode

readonly PRODUCT=tws  # ibgateway or tws       # do not change, actually only tws is supported
readonly INSTANCE=gateway   # gateway or tws      # the tws/gateway-output is displayed on the host of ib-container if
                                                  # not redirected to the framebuffer

IB_PROGRAM=${PRODUCT}-latest-standalone-linux-x64.sh 
readonly IB_PATH=https://download2.interactivebrokers.com/installers/${PRODUCT}/latest-standalone/${IB_PROGRAM}

IBC_VERSION=3.8.5
readonly IBC_PATH=https://github.com/IbcAlpha/IBC/releases/download/${IBC_VERSION}/IBCLinux-${IBC_VERSION}.zip

readonly GIT_SERVER=github.com
readonly GIT_REPOSITORY=ib-ruby/simple-monitor.git

# directory to install simple-montor in container 
readonly SIMPLE_MONITOR_DIRECTORY=simple-monitor
readonly SIMPLE_MONITOR_BRANCH=master
## Täglicher Start von Gateway/TWS im crontab-Format (Minute Stunde)
## When to start Gateawy/TWS by cron
START_TIME='5 5'

## Delay time 
## Nach dem Aufsetzen eines LXD-Containers laufen noch Backgroundprozesse ab.
## Es muss gewartet werden, bis diese abgeschlossen sind.
## Auf langsamen Rechnern anpassen!
LXD_DELAY=7 # sec


### LXD-Requirements
MIN_LXD_VERSION=4
MIN_LXD_SUBVERSION=11

### Ruby Version
RUBY_VERSION=3.0.0

### Speicherort der Konfiguration des ssh-tunnels
SSH_TUNNEL_LOCATION="etc/network/if-up.d/reverse_ssh_tunnel"

### Alle Ausgaben in die Datei containerbau.log umleiten
logfile=containerbau.log

### Weitere Software
### Liste von Debian-Paketnanen 
INSTALL_ADDITONAL_PROGRAMS="vim  ranger"

####  return codes
###
###  2            falsche LDX-Version
###  3            Container bereits angelegt
###  4            Container konnte nicht richtig initialisiert werden (kein Netzwerk, Java nicht erfolgreich installiert) 
###  99           LXD ist nicht gestartet oder nicht vorhanden
###  255          Abbruch durch Nutzer           

