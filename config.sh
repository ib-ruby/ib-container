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

readonly IB_VERSION=stable           # stable or latest
readonly IB_INSTANCE=ibgateway      # ibgateway or tws     
readonly IB_GW_VERSION=1019         # goes into gatewaystart of ibc
readonly IB_TWS_VERSION=1019        # goes into twsstart of ibc
#IB_GATEWAY=    # provided ibgateway executable (renamed, ignored if missing)
#IB_TWS=        # provided ibgateway executable (renamed, ignored if missing)
IB_PROGRAM=${IB_INSTANCE}-${IB_VERSION}-standalone-linux-x64.sh
readonly IB_PATH=https://download2.interactivebrokers.com/installers/${IB_INSTANCE}/${IB_VERSION}-standalone/${IB_PROGRAM}
# the tws/gateway-output is displayed on the host of ib-container if
# not redirected to the framebuffer
# If the tws is used in gateway-mode, it fires the gui-version upon its daily reset.
# 
# 
readonly IBC_VERSION='3.14.0' 
readonly IBC_PATH=https://github.com/IbcAlpha/IBC/releases/download/${IBC_VERSION}/IBCLinux-${IBC_VERSION}.zip
# disabled for now: the versions are changing to fast
# readonly IB_PATH=https://download2.interactivebrokers.com/installers/${PRODUCT}/${IB_VERSION}-standalone/${IB_PROGRAM}
readonly GIT_SERVER=github.com
readonly IB_EXAMPLES_GIT_REPOSITORY=ib-ruby/ib-examples.git

# directory to install simple-montor in container 
readonly IB_EXAMPLES_DIRECTORY=ib-examples
readonly IB_EXAMPLES_BRANCH=master
## request a restart after #{TWS_RESTART} minutes if tws/gateway has shutdown 
## only in DEMO Mode!
TWS_RESTART=5

## Delay time 
## Nach dem Aufsetzen eines LXD-Containers laufen noch Backgroundprozesse ab.
## Es muss gewartet werden, bis diese abgeschlossen sind.
## Auf langsamen Rechnern anpassen!
LXD_DELAY=15 # sec


### LXD-Requirements
MIN_LXD_VERSION=5
MIN_LXD_SUBVERSION=1

### Ruby Version
RUBY_VERSION=3.1.2

### Speicherort der Konfiguration des ssh-tunnels
SSH_TUNNEL_LOCATION="etc/network/if-up.d/reverse_ssh_tunnel"

### Alle Ausgaben in die Datei containerbau.log umleiten
logfile=containerbau.log

### additional programms to load
### list of deb-pakets 
INSTALL_ADDITONAL_PROGRAMS="vim  ranger"

####  return codes
###
###  2            falsche LDX-Version
###  3            Container bereits angelegt
###  4            Container konnte nicht richtig initialisiert werden (kein Netzwerk, Java nicht erfolgreich installiert) 
###  99           LXD ist nicht gestartet oder nicht vorhanden; uid ist nicht 1000
###  255          Abbruch durch Nutzer           

