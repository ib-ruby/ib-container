# IB-Container

Provides a Container including a running TWS/Gateway  in an isolated environment. 

* TWS/Gateway is restarted automaticcally (per cron job)
* Framebuffer device to redirect Gateway-Output
* X11 integration to run GUI-applications inside the container
* A reverse SSH-Tunnel is implemented for an extra layer of security
* [Simple-Monitor](https://github.com/ib-ruby/simple-monitor) is started upon setup
* Anything is prepared to run an reliable Trading-Bot in a secure environment
* A suitable ruby installation to develop and run ib-ruby-trading solutions

## Customizing
* modify config.yml

The location of a specific version of the tws to be used can be specified, as well as a substiute for the simple-monitor-application to install. Additional programs to install  can be specified there, too. Its even possible to extend the container to a fully gui-based ubuntu-instance by setting up a window-manager (awesome is recommended) which can be remotely accessed through X2Go. 

**note:** The TWS-executable is included. Don't be surprized if you clone this respository. 

## Background

[Linux Container](https://linuxcontainers.org/)  are the next generation system container and virtual machine manager.
They offer a unified user experience around full Linux systems running inside containers or virtual machines.


[IB-Container](https://github.com/ib-ruby/ib-container) provides a suitable environment to run applications addressing 
the TWS-API of Interactive Brokers. Several Container can safely run simultaneously and 24/7 on standard cloud-instances. 

> Setup LXD-Container:
>  * Install LDX via snap  (migrate existing lxd-installation with lxd.migrate)
>  * Initiailise with lxd.init`  (important: lxd is initialized as normal user) 


## Setup

Edit `config.sh` and modify with defaults to your needs. 

The script `setup.sh` 
* downloads and installs a minimized Ubuntu Linux Image  (Ubuntu 20.4 LTS)
* downloads the official binaries from the interactive brokers server into the container
* downloads the [IBC](https://github.com/IbcAlpha/IBC) automation software providing  tws/gateway-autostart
* prepares the container to run ruby programs
* downloads [Simple-Monitor](https://github.com/ib-ruby/simple-monitor) 
* installs the components and runs the tws/gateway
* opens a tmux-session including a running [Simple-Monitor](https://github.com/ib-ruby/simple-monitor) to verify the success of the implementation

## Prerequisites

Copy your Public SSH-Key to the IB-Container directory. This will grant SSH-access to the container.


## Arguments

The script is called with up to six arguments

```
> bash setup.sh {name of the container}  
                {ib login}
                {ib password}
                {port of the reverse ssh tunnel default= random number}
                {middleman-server}
                {username on the middleman server default=actual username}

```
All arguments are requested interactively if absent.

The progress of the installation is available through `tail -f containerbau.log`  (in a different terminal)

After successfully initializing the container, the gateway is started  and a TMUX-Session 
is opened. [Simple-Monitor](https://github.com/ib-ruby/simple-monitor)  is autostarted.
 
Even if a framebuffer is installed, to get access to the API-Configuration during its first run the gateway-application uses the X11-screen.  In most cases, you have to disable the _ReadOnly API_ checkbox.  
**Important:** Changes to the configuration of the gateway are saved only  on  closing of the application. You have to restart the gateway!

The Control-Key is **CRTL A**;  `CRTL a d`  detaches from the session.  
`tmux attach` re-establishes the session.

The container is accessible (with X11 support)  through: `lxc open {container name}`

Simple scripts to start `./start_gateway.sh`, `./start_framebuffer_gateway.sh` and to stop `./stop_gateway.sh` the 
gateway application are included. 

## Finishing

On your Middleman Server, edit `~.ssh/config` and add the reverse tunnel specification

If you specified `bash setup.sh t1  username password 3445 your-server-adress your-username` then add
 
```
Host ibcontainer
    HostKeyAlias t1
    Hostname localhost
    User ubuntu
    Port 3445
``` 
Then connect through `ssh -Y ibcontainer`

Don't forget to add {container name}.pub to `~/.ssh/autorized_keys` on the Middleman Server. 


## Status

This  software is tested on Ubuntu systems. 

## ToDo

* Implement addressing the ibgateway  application and enable the fix protocol

## CONTRIBUTING

If you want to contribute to IB-Container development:

  *  Make a fresh fork of ib-container (Fork button on top of Github GUI)
  *  Clone your fork locally (git clone /your fork private URL/)
  *  Add main ib-container repo as upstream (git remote add upstream https://github.com/ib-ruby/ib-container.git)
  *  Create your feature branch (git checkout -b my-new-feature)
  *  Modify code as you see fit
  *  Commit your changes (git commit -am 'Added some feature')
  *  Pull in latest upstream changes (git fetch upstream -v; git merge upstream/master)
  *  Push to the branch (git push origin my-new-feature)
  *  Go to your Github fork and create new Pull Request via Github GUI

... then proceed from step 5 for more code modifications... 


