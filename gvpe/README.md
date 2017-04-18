# GVPE

[GVPE](http://software.schmorp.de/pkg/gvpe.html) is a mesh VPN: a number of hosts running GVPE will get a virtual Ethernet interface (TAP) connecting them all together via encrypted communication. It is mesh, meaning that all hosts talk directly to each other, although routed communication is also supported.


## GVPE and TINC

[GVPE](http://software.schmorp.de/pkg/gvpe.html) is very close to [TINC](https://www.tinc-vpn.org/), with the following differences (I found):

1. GVPE security is decided at compile-time, while TINC at configure-time. This repo includes statically linked GVPE binaries for Linux and FreeBSD, compiled with the strongest security settings GVPE supports.

2. All GVPE hosts need to be provisioned to all nodes of the network, while TINC allows new hosts to join at any time, without re-configuring the entire network.

3. GVPE and TINC support direct and routed communication (routed is when 2 hosts can only talk via another host). GVPE however allows statically configuring the order routers will be evaluated, for each node.

4. TINC has some means to distribute routing between all the nodes, so that any node can push new subnets in the routing tables of all nodes. GVPE does not have this functionality. You can hardcode it in the configuration though (so, it is static).

5. GVPE seems to support more [protocols](http://pod.tst.eu/http://cvs.schmorp.de/gvpe/doc/gvpe.protocol.7.pod) for communication between nodes:

- `rawip`, that uses raw IP frames marked with any protocol number: GRE, IPSEC AH, etc. This is the best choice, due to its low overhead.
- `icmp`, that uses any ICMP message. The second best choice in terms of overheads. It can also enable communication is certain cases that all other protocol fail.
- `udp`, the most common alternative to `rawip`.
- `tcp`, GVPE supports plain TCP but also tunneled through HTTPS proxies tcp connections.
- `dns` (this is not compiled in the binary files in this repo).

6. GVPE communication between any 2 nodes cannot be sniffed or faked even by other nodes in the same VPN. I am not sure if this is also supported by TINC.

7. GVPE packages do not seem to be available in many operating systems, while TINC seems to be available everywhere.


## So, why GVPE?

Yes, it seems that TINC is more capable than GVPE. So why GVPE?

I decided to use GVPE for interconnecting netdata VMs, because GVPE seems a lot simpler and straight forward. I liked the idea that all the nodes of the VPN will be statically configured and routing order is a configure-time decision. I also liked the broad range of transport protocols supported.

The key limitations of GVPE in netdata case are:

1. The lack of any automated mechanism for attempting multiple protocols between any 2 nodes. So, if for example `rawip` does not work for a node, manual re-configuration of the node is required to switch to another protocol.

2. The lack of any automated mechanism to fallback from direct to routed communications between any 2 nodes. So, if for example, due to temporary network issues a node cannot directly reach another node, gvpe will not attempt to re-route packets via another node is can connect to both.


## What are the GVPE files on this repo?

The files in this directory attempt to easily provision changes to the entire VPN network:

1. Statically built gvpe binaries are provided for x64 Linux and FreeBSD. These binaries should be usable on any x64 Linux and FreeBSD.
2. A global configuration file ([nodes.conf](nodes.conf)) handles all the configuration for all nodes.
3. GVPE configuration `gvpe.conf` is common on all nodes. The script maintains the order of nodes (nodeid) across runs.
4. Custom gvpe configuration for nodes in maintained in `local.conf` and `routing.conf`. Both of these files are gvpe configurations and are not overwritten by updates.
5. A script ([provision-gvpe.sh](provision-gvpe.sh)) provisions everything (initial setup and updates) on all nodes (via SSH).
6. GVPE `if-up`, `node-up`, `node-down` and `node-changed` are provided. Each node may have its own extensions using `if-up.local`, `node-up.local`, `node-down.local` and `node-changed.local` (which are not overwritten by updates).
7. An enhanced status script [`gvpe-status.sh`](sbin/gvpe-status.sh) is provided, that shows current connection state for all nodes.
8. A simple script [`gvpe-routing-order.sh](sbin/gvpe-routing-order.sh) is provided to ping all running nodes and based on their latency, decide the order they shoud be used as routers.


## Links

- [GVPE home page](http://software.schmorp.de/pkg/gvpe.html)
- [GVPE configuration reference](http://pod.tst.eu/http://cvs.schmorp.de/gvpe/doc/gvpe.conf.5.pod)
- [GVPE supported transport protocol](http://pod.tst.eu/http://cvs.schmorp.de/gvpe/doc/gvpe.protocol.7.pod)
- [GVPE O/S support](http://pod.tst.eu/http://cvs.schmorp.de/gvpe/doc/gvpe.osdep.5.pod)


## How to use the scripts on this repo

1. Edit [nodes.conf](nodes.conf) and describe your nodes. You will need to describe the following:

- a `name` for each node.
- the `public IP` and `port` of each node. You can give the word `dynamic` as the IP, if it is not static, in which case the other nodes will not initiate connections towards this node. I use `dynamic` for my home, office and laptop.
- the `virtual IP` of the node, i.e. the IP the node should get once connected to the VPN.
- the `SSH IP` of the node, i.e. the IP the scripts will use for provisioning files and configuration to the node. You can use the keyword `vpn` to use the VPN IP (you can do this after the network has been setup once), or `localhost` to provision the files on the host running the scripts (I use this for my laptop), or `none` to disable provisioning for a node.
- the operating system of the node. Currently `linux` and `freebsd` are supported.

   This is mine:

```sh
# -----------------------------------------------------------------------------
# configuration

BASE_IP="172.16.254"

# The CIDR of the entire VPN network
VPN_NETWORK="${BASE_IP}.0/24"

# The default port - each node may use a different
PORT="49999"

#    HOSTNAME             PUBLIC IP : PORT        VIRTUAL IP          O/S     SSH IP
node box                  dynamic:${PORT}         ${BASE_IP}.1        linux   'vpn'
node boxe                 dynamic:${PORT}         ${BASE_IP}.2        linux   'vpn'
node costa                dynamic:$((PORT - 1))   ${BASE_IP}.3        linux   'localhost'
node london               139.59.166.55:${PORT}   ${BASE_IP}.10       linux   ''
node atlanta              185.93.0.89:${PORT}     ${BASE_IP}.20       linux   ''
node west-europe          13.93.125.124:${PORT}   ${BASE_IP}.30       linux   ''
node bangalore            139.59.0.212:${PORT}    ${BASE_IP}.40       linux   ''
node frankfurt            46.101.193.115:${PORT}  ${BASE_IP}.50       linux   ''
node sanfrancisco         104.236.149.236:${PORT} ${BASE_IP}.60       linux   ''
node toronto              159.203.30.96:${PORT}   ${BASE_IP}.70       linux   ''
node singapore            128.199.80.131:${PORT}  ${BASE_IP}.80       linux   ''
node newyork              162.243.236.205:${PORT} ${BASE_IP}.90       linux   ''
node aws-fra              35.156.164.190:${PORT}  ${BASE_IP}.100      linux   ''
node netdata-build-server 40.68.190.151:${PORT}   ${BASE_IP}.110      linux   ''
node freebsd              178.62.98.199:${PORT}   ${BASE_IP}.120      freebsd ''

# generate all configuration files locally
configure

# push all configuration files to all nodes
provision

# restart gvpe on all nodes
activate
```

   These are all the configuration you need to do. For most setups, the scripts will handle the rest.


2. Run [provision-gvpe.sh](provision-gvpe.sh) to generate the configuration, the public and private keys of the nodes and push everything to all nodes. The script uses SSH and RSYNC to update the nodes. If it fails to ssh to one of your servers it will stop - you have to fix it. I normally allow password-less ssh with my personal keys, so the script runs without any interaction.

3. When the script finsihes successfully, all systems that are using `systemd` will be running `gvpe` (binaries and script will be saved at `/usr/local/sbin` and configuration at `/etc/gvpe`). For non-systemd systems you will have to ssh to the nodes manually and add `/usr/local/sbin/gvpe-supervisor.sh start` to your `/etc/rc.local` or `/etc/local.d`. Run it also by hand to start gvpe without rebooting. You will not need to do this again. Re-executing `provision-gvpe.sh` will restart `gvpe` even on these nodes.

4. For most systems, no firewall change should be needed. Yes, gvpe will get connected without any change to your firewall. The reason is that all nodes are attempting to connect to all other nodes. So firewalls will encounted both incbound and outbound communications, making them believe the connection was an outbound one that should be allowed. This allows connections to be established without altering the firewall, at least for UDP communications. Of course you will need to configure the firewall for all nodes if you use any `dynamic` nodes.

5. You can see the status of all nodes by running [`/usr/local/sbin/gvpe-status.sh`](sbin/gvpe-status.sh) on each node. You will get something like this:

```sh
# /usr/local/sbin/gvpe-status.sh 

GVPE Status on boxe (Node No 2)

Total Events: 259
Last Event: 2017-04-17 01:55:24

Up 15, Down 0, Total 15 nodes

 ID Name                      VPN IP          REAL IP                   STATUS SINCE               
  1 box                       172.16.254.1    udp/195.97.5.206:49999    up     2017-04-17 01:54:48 
  3 costa                     172.16.254.3    udp/10.11.13.143:49998    up     2017-04-17 01:44:18 
  4 london                    172.16.254.10   udp/139.59.166.55:49999   up     2017-04-17 01:54:44 
  5 atlanta                   172.16.254.20   udp/185.93.0.89:49999     up     2017-04-17 01:54:46 
  6 west-europe               172.16.254.30   udp/13.93.125.124:49999   up     2017-04-17 01:54:56 
  7 bangalore                 172.16.254.40   udp/139.59.0.212:49999    up     2017-04-17 01:54:51 
  8 frankfurt                 172.16.254.50   udp/46.101.193.115:49999  up     2017-04-17 01:54:50 
  9 sanfrancisco              172.16.254.60   udp/104.236.149.236:49999 up     2017-04-17 01:54:59 
 10 toronto                   172.16.254.70   udp/159.203.30.96:49999   up     2017-04-17 01:54:59 
 11 singapore                 172.16.254.80   udp/128.199.80.131:49999  up     2017-04-17 01:55:09 
 12 newyork                   172.16.254.90   udp/162.243.236.205:49999 up     2017-04-17 01:55:00 
 13 aws-fra                   172.16.254.100  udp/35.156.164.190:49999  up     2017-04-17 01:55:12 
 14 netdata-build-server      172.16.254.110  udp/40.68.190.151:49999   up     2017-04-17 01:47:38 
 15 freebsd                   172.16.254.120  udp/178.62.98.199:49999   up     2017-04-17 01:55:24 
```

6. You can set the order gvpe routers will be evaluated, by running [`/usr/local/sbin/gvpe-routing-order.sh`](sbin/gvpe-routing-order.sh) on each node.

7. If a node fails connect, you may need to disable a few protocols for it. On the failing node, edit `/etc/gvpe/local.conf` to override any of the default settings. Do not edit `/etc/gvpe/gvpe.conf`, as this will be overwritten when `provision-gvpe.sh` pushes new configuration. On amazon EC2 nodes, for example, I had to disable `rawip` and `icmp`.

8. If you need to add static routes to the routing tables of the nodes or take other actions when gvpe starts, nodes are connected, disconnected or updated, you will have to do it by hand, on each node, by editing all the `.local` files in `/etc/gvpe`. Keep in mind you can place any of these files in `conf.d` and `provision-gvpe.sh` will push it to all nodes (but note it will be executed on all nodes, without exception - normally static routing should be executed on all nodes, except one - the node that should route this traffic to its local network - you should handle this case by code in the script).

9. The scripts try to maintain persistent IDs for nodes. GVPE uses the order of the nodes in `gvpe.conf` to determine the ID of each node. The ID is used in the packets to identify the keys that should be used. If an update re-arranges the nodes, gvpe on all nodes will have to be restarted for the communication to be restored. So, the scripts try to maintain the same ID for each node, indepently of the order the nodes appear in `nodes.conf`. If you need to remove a node through, I suggest to keep it with its `SSH IP` set to `none`.
