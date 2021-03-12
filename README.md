# IB-Container

Provides a Container including a running TWS/Gateway  in an isolated environment. 

* The TWS/Gateway is restarted once a day
* A reverse SSH-Tunnel is implemented for an extra layer of security
* [Simple-Monitor](https://github.com/ib-ruby/simple-monitor) is started upon setup
* Anything is prepared to run an reliable Trading-Bot in a secure environment

## Background

[Linux Container](https://linuxcontainers.org/)  are the next generation system container and virtual machine manager.
They offer a unified user experience around full Linux systems running inside containers or virtual machines.


[IB-Container](https://github.com/ib-ruby/ib-container) provide a suitable environment to run applications addressing 
the TWS-API of Interactive Brokers. Several Container can safely run simultaneously and 24/7 on standard cloud-instances. 

The broker provides two java-executables serving as API-Server
* ibgateway
* tws

The `tws`-binary can operate as full GUI-Interface or as lightweight Gateway-Application. [IB-Container](https://github.com/ib-ruby/ib-container) can run both.  The `ibgateway`-binary
provides the proprietary `IB-API` and the `FIX-Protocol`, the industry standard to access trading-applications. 


## Setup
The script `setup.sh` 
* downloads and installs a minimized Ubuntu Linux Image  (Unbuntu 20.4 LTS)
* downloads the official binaries from the interactive brokers server into the container
* downloads the [IBC](https://github.com/IbcAlpha/IBC) automation software providing  tws/gateway-autostart
* prepares the container to run ruby programs
* downloads [Simple-Monitor](https://github.com/ib-ruby/simple-monitor) 
* installs the components and runs the tws/gateway
* opens a tmux-session including a running [Simple-Monitor](https://github.com/ib-ruby/simple-monitor) to verify the success of the implementation

## Prerequisites

Copy your Public SSH-Key to the IB-Container directory. This will grant SSH-access to the container.

Edit `setup.sh` and change `LOGIN`, `PASS`. If no demo account is used, set `DEMOACCOUNT`  to zero.


## Arguments

The script is called with up to four arguments

```
> bash setup.sh {name of the container default= t1} 
                {port of the reverse ssh tunnel default= random number}
                {middleman-server  default= localhost}
                {username on the middleman server default=actual username}

```

## Finishing

On your Middleman Server, edit `~.ssh/config` and add the reverse tunnel credentials

If you specified `bash setup.sh t1 3445 your-server-adress your-username` then add
 
```
Host ibcontainer
    HostKeyAlias t1
    Hostname localhost
    User ubuntu
    Port 3445
``` 
Then connect through `ssh -Y ibcontainer`



## Status

This  software is currently NOT production ready. 

* The autostart of an ibgateway instance is unfinished
* The ssh-tunnel is not tested yet



# CONTRIBUTING

If you want to contribute to IC-Container development:

  *  Make a fresh fork of ib-container (Fork button on top of Github GUI)
  *  Clone your fork locally (git clone /your fork private URL/)
  *  Add main ib-container repo as upstream (git remote add upstream git://github.com/ib-ruby/ib-container.git)
  *  Create your feature branch (git checkout -b my-new-feature)
  *  Modify code as you see fit
  *  Commit your changes (git commit -am 'Added some feature')
    Pull in latest upstream changes (git fetch upstream -v; git merge upstream/master)
  *  Push to the branch (git push origin my-new-feature)
  *  Go to your Github fork and create new Pull Request via Github GUI

... then proceed from step 5 for more code modifications... 


