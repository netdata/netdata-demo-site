# GVPE

GVPE is a mesh VPN: a number of hosts running GVPE will get a virtual Ethernet interface (TAP) connecting them all together via encrypted communication. It is mesh, meaning that all hosts talk directly to each other, although routed communication is also supported.

GVPE is very close to [TINC](https://www.tinc-vpn.org/), with the following differences:

1. GVPE security is decided at compile-time, while TINC at configure-time. This repo includes statically linked GVPE binaries for Linux and FreeBSD, compiled with the strongest security settings GVPE supports.

2. All GVPE hosts need to be provisioned to all nodes of the network, while TINC allows new hosts to join at any time, without re-configuring the entire network.

3. GVPE and TINC support direct and routed communication (routed is when 2 hosts can only talk via another host). GVPE however allows statically configuring the order routers will be evaluated, for each node.

4. TINC has some means to distribute routing between all the nodes, so that any node can push new subnets in the routing tables of all nodes. GVPE does not have this functionality.

5. GVPE seems to support more [protocols](http://pod.tst.eu/http://cvs.schmorp.de/gvpe/doc/gvpe.protocol.7.pod) for communication between nodes:

- `rawip`, that uses raw IP frames marked with any protocol number: GRE, IPSEC AH, etc. This is the best choice, due to its low overhead.
- `icmp`, that uses any ICMP message. The second best choice in terms of overheads. It can also enable communication is certain cases that all other protocol fail.
- `udp`, the most common alternative to `rawip`.
- `tcp`, and GVPE supports tunneling tcp connections through HTTPS proxies.
- `dns` (this is not compiled in the binary files in this repo).

6. GVPE packages do not seem to be available in many operating systems, while TINC seems to be available everywhere.


## Why GVPE?

I decided to use GVPE for interconnecting netdata VMs, because GVPE seems a lot simpler and straight forward. I liked the idea that all the nodes of the VPN will be statically configured and routing is a configure-time decision, especially the order routers will be evaluated.

