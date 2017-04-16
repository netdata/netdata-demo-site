# GVPE

GVPE is a mesh VPN: a number of hosts running GVPE will get a virtual Ethernet interface (TAP) connecting them all together via encrypted communication. It is mesh, meaning that all hosts talk directly to each other, although routed communication is also supported.

GVPE is very close to [TINC](https://www.tinc-vpn.org/), with the following differences (I found):

1. GVPE security is decided at compile-time, while TINC at configure-time. This repo includes statically linked GVPE binaries for Linux and FreeBSD, compiled with the strongest security settings GVPE supports.

2. All GVPE hosts need to be provisioned to all nodes of the network, while TINC allows new hosts to join at any time, without re-configuring the entire network.

3. GVPE and TINC support direct and routed communication (routed is when 2 hosts can only talk via another host). GVPE however allows statically configuring the order routers will be evaluated, for each node.

4. TINC has some means to distribute routing between all the nodes, so that any node can push new subnets in the routing tables of all nodes. GVPE does not have this functionality. You can hardcode it in the configuration though (so, it is static).

5. GVPE seems to support more [protocols](http://pod.tst.eu/http://cvs.schmorp.de/gvpe/doc/gvpe.protocol.7.pod) for communication between nodes:

- `rawip`, that uses raw IP frames marked with any protocol number: GRE, IPSEC AH, etc. This is the best choice, due to its low overhead.
- `icmp`, that uses any ICMP message. The second best choice in terms of overheads. It can also enable communication is certain cases that all other protocol fail.
- `udp`, the most common alternative to `rawip`.
- `tcp`, GVPE supports plain TCP but all tunneled through HTTPS proxies tcp connections.
- `dns` (this is not compiled in the binary files in this repo).

6. GVPE packages do not seem to be available in many operating systems, while TINC seems to be available everywhere.


## So, why GVPE?

Yes, it seems that TINC is more capable and well maintained than GVPE. So why GVPE?

I decided to use GVPE for interconnecting netdata VMs, because GVPE seems a lot simpler and straight forward. I liked the idea that all the nodes of the VPN will be statically configured and routing is a configure-time decision. I also liked the broad range of transport protocols supported and the ability to statically configure the order routers will be evaluated.

Of course, GVPE lacks a management system, to easily provision the entire network with changes. The files in this directory attempt to provide that.


## How-To

1. Edit [nodes.conf](nodes.conf) and describe your nodes.

2. Run [provision-gvpe.sh](provision-gvpe.sh) to push the configuration to all nodes. If it fails to ssh to your servers, you have to fix it. I normally allow password-less ssh with my keys, so the script runs without any interaction.

3. When the script finsihes successfully, all systems that are using `systemd` will be running `gvpe`. For non-systemd systems you will have to ssh to the nodes manually and add `/usr/local/sbin/gvpe-supervisor.sh start` to your `/etc/rc.local` or `/etc/local.d`. Run it also by hand. You will not need to do this again. Re-executing `provision-gvpe.sh` will restart `gvpe` even on these nodes.

4. For most systems, no firewall change should be needed. Yes, gvpe will get connected without any change to your firewall. The reason is that all nodes are attempting to connect to all other nodes, using raw IP, ICMP, UDP and TCP. For all kinds of connections except TCP, the firewalls will encounter outbound connections, which will be replied back. This allows the connections to be established.

5. You can see the status of all nodes by running `/usr/local/sbin/gvpe-status.sh` on each node.

6. You can set the order gvpe routers will be evaluated, by running `/usr/local/sbin/gvpe-routing-order.sh` on each node.

7. If a node fails to get connected, you may need to disable a few protocols for it. On the failing node, edit `/etc/gvpe/local.conf` to override any of the default settings. Do not edit `/etc/gvpe/gvpe.conf`, as this will be overwritten when `provision-gvpe.sh` pushes new configuration.

8. If you need to add static routes or take other actions when gvpe starts, nodes are connected, disconnected or updated, you will have to do it by hand, on each node, by editing all the `.local` files in `/etc/gvpe`. Keep in mind you can place any of these files in `conf.d` and `provision-gvpe.sh` will push it to all nodes (but node it will be executed on all nodes, without exception - normally static routing should be executed on all nodes, except one - the node that should route this traffic to its local network - you should handle this case by code in the script).

