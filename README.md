# IB-Container

Provides a Container including a running TWS/Gateway  and IB-Ruby attached in an isolated environment. 

* TWS/Gateway is started when the container is booted
* Automated Authentication via IBC
* Framebuffer device to redirect Gateway-Output
* X11 integration to run GUI-applications inside the container
* A reverse SSH-Tunnel is implemented for an extra layer of security
* Anything is prepared to run an reliable Trading-Bot in a secure environment
* A suitable ruby installation to develop and run ib-ruby-trading solutions
* IB-Examples are installed and ready to use.

## Customizing
* modify config.sh

The container can be transformed to a fully gui-based ubuntu-instance by setting up a window-manager (awesome is recommended) which can be remotely accessed through X2Go. (Install awesomewm and x2go)

## Background

[Linux Container](https://linuxcontainers.org/)  are the next generation system container and virtual machine manager.
They offer a unified user experience around full Linux systems running inside containers or virtual machines.

[IB-Container](https://github.com/ib-ruby/ib-container) provides a suitable environment to run applications addressing 
the TWS-API of Interactive Brokers. Several Container can safely run simultaneously and 24/7 on standard cloud-instances. 

> Setup LXD-Container:
>  * Install LDX via snap  (migrate existing lxd-installation with lxd.migrate)
>  * Initialise with `lxd.init`

## TWS / IB-Gateway
The script tries to load the stable release of the software from the interactivebrokers download server. However, you can simply 
download the software manualy and copy the executable into the `ib-container`-directory and update `config.sh`.

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

The progress of the installation can be watched using `tail -f containerbau.log`  (in a different terminal)

A framebuffer is installed to hide the GUI of the gateway. However to access the API-Configuration during its first run the gateway-application uses the X11-screen.  
You have to disable the _ReadOnly API_ checkbox.  
**Important:** Changes to the configuration of the gateway are saved only  on  closing of the application. You have to restart the gateway!


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

## No X11, No Pulseaudio?

The script assumes a desktop-like environment for the server. If no such device is present, the container has to be launched manually
```
lxc launch --profile default ubuntu-minimal:f  {container name}
```
Then the `setup.sh`-script simply skips this step. Run the script as normal. 
The TWS-Gateway will not start immediately (no X11). The cron job will step in after 5 minutes.

## Status

This  software is tested on Ubuntu systems. 


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


