# IB-Container

Provides a Container including a running TWS/Gateway  in an isolated environment. 

* The TWS/Gateway ist restarted once a day
* A reverse SSH-Tunnel is implemented for an extra layer of security
* [Simple-Monitor](https://github.com/ib-ruby/simple-monitor) is started upon setup
* Anything is prepared to run an realible Trading-Bot in a secure environment

## Background

[Linux Container](https://linuxcontainers.org/)  are the next generation system container and virtual machine manager.
They offer a unified user experience around full Linux systems running inside containers or virtual machines.


[IB-Container](https://github.com/ib-ruby/ib-container) provide a suitable environment to run applications adressing 
the TWS-API of Interactive Brokers. Several Container can savely run simultaniously and 24/7 on standard cloud-instances. 

The broker provides two java-executables serving as API-Server
* ibgateway
* tws
The `tws`-binary can operate as full GUI-Interface or as lightweigth Gateway-Application. [IB-Container](https://github.com/ib-ruby/ib-container) can run both.  The `ibgateway`-binary
provides the properitary `IB-API` and the `FIX-Protocol`, the industry standard to access trading-applications. 


## Setup
The script `setup.sh` 
* downloads and installs a minimalized Ubuntu Linux Image  (Unbuntu 20.4 LTS)
* downloads the offical binaries from the interactive brokers server into the container
* downloads the [IBC](https://github.com/IbcAlpha/IBC) automation software providing  tws/gateway-autostart
* prepares the container to run ruby programs
* downloads [Simple-Monitor](https://github.com/ib-ruby/simple-monitor) 
* installs the components and runs the tws/gateway
* opens a tmux-session inclung a running [Simple-Monitor](https://github.com/ib-ruby/simple-monitor) to verify the success of the implementation



