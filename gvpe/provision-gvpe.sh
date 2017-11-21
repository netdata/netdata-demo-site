#!/usr/bin/env bash

set -e

STATIC_NODE_ROUTER_PRIORITY="1"
DYNAMIC_NODE_ROUTER_PRIORITY="0"

STATIC_NODE_CONNECT="always"
DYNAMIC_NODE_CONNECT="ondemand"

ME="$(realpath ${0})"
NULL=

[ ! -d ids ] && mkdir -p ids
[ ! -d keys ] && mkdir -p keys
[ ! -d conf.d ] && mkdir -p conf.d
[ ! -d conf.d/pubkey ] && mkdir -p conf.d/pubkey
[ ! -d conf.d/status ] && mkdir -p conf.d/status

# clean up
rm conf.d/status/* 2>/dev/null || echo >/dev/null
rm conf.d/pubkey/* 2>/dev/null || echo >/dev/null

run() {
    printf >&2 " > "
    printf >&2 "%q " "${@}"
    printf >&2 "\n"

    "${@}"
    return $?
}

prepare_configuration() {
    cat >conf.d/gvpe.conf <<EOF
# DO NOT EDIT - automatically generated by ${ME}

# -----------------------------------------------------------------------------
global

enable-rawip = yes
ip-proto = 51 # 47 (GRE), 50 (IPSEC, ESP), 51 (IPSEC, AH), 4 (IPIP tunnels), 98 (ENCAP, rfc1241)

enable-icmp = yes
icmp-type = 0 # 0 (echo-reply), 8 (echo-request), 11 (time-exceeded)

enable-udp = yes
udp-port = ${PORT} # the external port to listen on (configure your firewall)

enable-tcp = yes
tcp-port = ${PORT} # the external port to listen on (configure your firewall)

# Sets the maximum MTU that should be used on outgoing packets (basically the
# MTU of the outgoing interface) The daemon will automatically calculate
# maximum overhead (e.g. UDP header size, encryption blocksize...) and pass
# this information to the if-up script.
# Recommended values are 1500 (ethernet), 1492 (pppoe), 1472 (pptp).
# This value must be the minimum of the MTU values of all nodes.
mtu = 1400       # minimum MTU of all outgoing interfaces on all hosts

# the local network device name
ifname = vpn0

# Sets the keepalive probe interval in seconds (default: 60).
# After this many seconds of inactivity the daemon will start to send keepalive
# probe every 3 seconds until it receives a reply from the other end.
# If no reply is received within 15 seconds, the peer is considered unreachable
# and the connection is closed.
keepalive = 5

# loglevel = noise|trace|debug|info|notice|warn|error|critical
loglevel = info

# nfmark = integer
# This advanced option, when set to a nonzero value (default: 0), tries to set
# the netfilter mark (or fwmark) value on all sockets gvpe uses to send packets.
#nfmark = 0

if-up = if-up
node-up = node-up
node-change = node-change
node-down = node-down

private-key = hostkey

# Sets the rekeying interval in seconds (default: 3607).
# Connections are reestablished every rekey seconds, making them use a new
# encryption key.
rekey = 3600

# The configuration serial number. This can be any string up to 16 bytes
# length. Only when the serial matches on both sides of a connection will the
# connection succeed. This is not a security mechanism and eay to spoof, this
# mechanism exists to alert users that their config is outdated.
#serial = $(date +%Y%m%d%H%M%S)

# defaults for all nodes
compress = yes


inherit-tos = yes

# The maximum interval in seconds between retries to establish a connection to this node.
max-retry = 60

# Expire packets that couldn't be sent after this many seconds.
max-ttl = 120

# The maximum number of packets that will be queued.
max-queue = 1024

# all hosts can be used as routers.
router-priority = 1

EOF

    cat >conf.d/gvpe.conf.end <<EOF

# -----------------------------------------------------------------------------
# load local configuration overrides

EOF

    cat >conf.d/hosts.real <<EOF
# BEGIN gvpe real
# DO NOT EDIT - automatically generated by ${ME}
EOF

    cat >conf.d/hosts.vpn <<EOF
# BEGIN gvpe vpn
# DO NOT EDIT - automatically generated by ${ME}
EOF
}

declare -A unique_names=()
declare -A unique_pips=()
declare -A unique_vips=()

max_id=0
[ -f ids/.max ] && max_id=$(<ids/.max)
declare -a gvpe_name_by_id=()
declare -A gvpe_id=()
declare -A gvpe_name=()
declare -A gvpe_vip=()
declare -A gvpe_os=()
declare -A gvpe_sip=()
declare -A gvpe_pip=()
declare -A gvpe_port=()
declare -A gvpe_ifname=()
declare -A gvpe_ifupdata=()
declare -A gvpe_connect=()
declare -A gvpe_router_priority=()
declare -A gvpe_proto=()

node() {
    local name="${1// /}" p="${2// /}" vip="${3// /}" os="${4// /}" sip="${5// /}" proto="${6}"
    local pip port ifname ifupdata connect router_priority

    pip=$(echo "${p}"  | cut -d ':' -f 1)
    port=$(echo "${p}" | cut -d ':' -f 2)

    case "${os}" in
        linux)
            ifname="vpn0"
            ;;

        freebsd)
            ifname="tap0"
            ;;

        none)
     		ifname="none0"
     		;;

        *)
            echo >&2 "Unknown O/S '${os}'"
            exit 1
            ;;
    esac

    ifupdata="${VPN_NETWORK}|${vip}"

    case "${pip}" in
        dynamic)
            [ -z "${sip}" ] && sip="${vip}"
            connect="${DYNAMIC_NODE_CONNECT}"
            router_priority="${DYNAMIC_NODE_ROUTER_PRIORITY}"
            ;;

        *)
            connect="${STATIC_NODE_CONNECT}"
            router_priority="${STATIC_NODE_ROUTER_PRIORITY}"
            ;;
    esac

    [ "${sip}" = "vpn" ] && sip="${vip}"
    [ -z "${sip}" ] && sip="${pip}"

    if [ ! -z "${unique_names[${name}]}" ]
        then
        echo >&2 "Name '${name}' for IP ${pip} already exists with IP ${unique_names[${name}]}."
        exit 1
    fi

    if [ "${pip}" != "dynamic" -a ! -z "${unique_pips[${pip}]}" ]
        then
        echo >&2 "Public IP '${pip}' for ${name} already exists for ${unique_pips[${pip}]}."
        exit 1
    fi

    if [ ! -z "${unique_vips[${vip}]}" ]
        then
        echo >&2 "VPN IP '${vip}' for ${name} already exists for ${unique_vips[${vip}]}."
        exit 1
    fi

    unique_names[${name}]="${pip}"
    unique_pips[${pip}]="${name}"
    unique_vips[${vip}]="${name}"

    if [ -f ids/${name} ]
        then
        gvpe_id[${name}]=$(<ids/${name})
    else
        max_id=$((max_id + 1))
        echo "${max_id}" >ids/.max
        gvpe_id[${name}]=${max_id}
    fi
    echo "${gvpe_id[${name}]}" >ids/${name}

    if [ ! -z "${gvpe_name_by_id[${gvpe_id[${name}]}]}" ]
        then
        echo >&2 "Node '${name}' gets ID ${gvpe_id[${name}]} that points to node '${gvpe_name_by_id[${gvpe_id[${name}]}]}'"
        exit 1
    fi
    gvpe_name_by_id[${gvpe_id[${name}]}]=${name}

    gvpe_name[${name}]="${name}"
    gvpe_os[${name}]="${os}"
    gvpe_vip[${name}]="${vip}"
    gvpe_sip[${name}]="${sip}"
    gvpe_pip[${name}]="${pip}"
    gvpe_port[${name}]="${port}"
    gvpe_ifname[${name}]="${ifname}"
    gvpe_ifupdata[${name}]="${ifupdata}"
    gvpe_connect[${name}]="${connect}"
    gvpe_router_priority[${name}]="${router_priority}"

	local x fproto=
	for x in ${proto//,/ }
	do
		case "${x}" in 
			any|all)
				;;

			tcp|udp|rawip|icmp)
				fproto="${fproto} ${x}"
				;;

			*)
				echo >&2 "Ignoring unknown protocol: ${x}"
				;;
		esac
	done
    gvpe_proto[${name}]="${fproto}"
}

foreach_node() {
    local callback="${1}" name

    for name in "${gvpe_name_by_id[@]}"
    do
        # echo >&2 "Calling ${callback} for ${name} (${gvpe_id[${name}]})"
        ${callback} "${name}"
    done
}

node_status_file() {
    local name="${1}"

    echo "${name}" >>conf.d/status/nodes

    cat >conf.d/status/${name} <<EOF
nodeid="${gvpe_id[${name}]}"
name="${name}"
status="down"
ip="${gvpe_vip[${name}]}"
si=""
pip="${gvpe_pip[${name}]}"
pipport="${gvpe_port[${name}]}"
rip="${gvpe_pip[${name}]}"
ripport="${gvpe_port[${name}]}"
mac=""
ifupdata="${gvpe_ifupdata[${name}]}"
timestamp="$(date +%s)"
EOF
}

node_gvpe_conf() {
    local name="${1}" hostname_comment

    case "${gvpe_pip[${name}]}" in
        dynamic)
            hostname_comment="# "
            ;;

        *)
            hostname_comment=
            ;;
    esac

	local udp="yes" tcp="yes" icmp="yes" rawip="yes"
	local x proto="${gvpe_proto[${name}]}"
	if [ ! -z "${proto}" ]
		then
		udp="no"
		tcp="no"
		icmp="no"
		rawip="no"
		for x in ${proto}
		do
			case "${x}" in
				udp) udp="yes";;
				tcp) tcp="yes";;
				icmp) icmp="yes";;
				rawip) rawip="yes";;
				*) echo >&2 "Invalid protocol: ${x}";;
			esac
		done
	fi

    cat >>conf.d/gvpe.conf <<EOF

# -----------------------------------------------------------------------------
node = ${name}

${hostname_comment}hostname = ${gvpe_pip[${name}]}
on ${name} hostname = 0.0.0.0
on ${name} ifname = ${gvpe_ifname[${name}]}
udp-port = ${gvpe_port[${name}]}
tcp-port = ${gvpe_port[${name}]}
connect = ${gvpe_connect[${name}]} # ondemand | never | always | disabled
router-priority = ${gvpe_router_priority[${name}]}
on ${name} if-up-data = ${gvpe_ifupdata[${name}]}
# allow-direct = *
# deny-direct = *
# on ${name} low-power = yes # on laptops
enable-rawip = ${rawip}
enable-icmp = ${icmp}
enable-tcp = ${tcp}
enable-udp = ${udp}
EOF

    cat >>conf.d/gvpe.conf.end <<EOF
node = ${name}
on ${name} include local.conf

EOF
}

node_keys() {
    local name="${1}"

    if [ ! -f "keys/${name}" -o ! -f "keys/${name}.privkey" ]
    then
        echo >&2 "generating keys for: ${name}"
        cd keys
        run ../sbin.linux/gvpectrl -c ../conf.d -g ${name}
        cd ..
    fi

    if [ ! -f "conf.d/pubkey/${name}" ]
    then
        run cp -p keys/${name} conf.d/pubkey/${name}
    fi
}

node_hosts() {
    local name="${1}"

    if [ "${gvpe_pip[${name}]}" != "dynamic" ]
        then
        printf "%-15s %s\n" "${gvpe_pip[${name}]}" "${name}" >>conf.d/hosts.real
    fi
    printf "%-15s %s\n" "${gvpe_vip[${name}]}" "${name}" >>conf.d/hosts.vpn
}

node_provision_files() {
    local name="${1}"

    local confd="$(run mktemp -d /tmp/gvpe-${name}-XXXXXXXXXX)"
    [ -z "${confd}" ] && echo >&2 "Cannot create temporary directory" && return 1

    rsync -HaSPv conf.d/ "${confd}/"

    echo "${name}" >${confd}/hostname
    run cp keys/${name}.privkey ${confd}/hostkey
    [ -f "gvpe-conf-d-on-${name}.tar.gz" ] && run rm "gvpe-conf-d-on-${name}.tar.gz"
    run tar -zcpf "gvpe-conf-d-on-${name}.tar.gz" ${confd}/

    # do not provision hosts with O/S set to 'none'
    if [ "${gvpe_os[${name}]}" != "none" -a "${gvpe_sip[${name}]}" != "none" ]
        then
        echo >&2
        echo >&2 "Provisioning: ${name} (${gvpe_sip[${name}]})"

        if [ "${gvpe_sip[${name}]}" = "localhost" ]
            then
            run sudo rsync -HaSPv sbin/ /usr/local/sbin/
            run sudo rsync -HaSPv sbin.${gvpe_os[${name}]}/ /usr/local/sbin/
            run sudo rsync -HaSPv ${confd}/ /etc/gvpe/
        else
            run rsync -HaSPv sbin/ -e "ssh" --rsync-path="\`which sudo\` rsync" ${gvpe_sip[${name}]}:/usr/local/sbin/
            run rsync -HaSPv sbin.${gvpe_os[${name}]}/ -e "ssh" --rsync-path="\`which sudo\` rsync" ${gvpe_sip[${name}]}:/usr/local/sbin/
            run rsync -HaSPv ${confd}/ -e "ssh" --rsync-path="\`which sudo\` rsync" ${gvpe_sip[${name}]}:/etc/gvpe/
        fi
    fi

    run rm -rf "${confd}"
    return 0
}

node_setup() {
    local name="${1}"

    if [ "${gvpe_os[${name}]}" != "none" -a "${gvpe_sip[${name}]}" != "none" ]
        then
        echo >&2
        echo >&2 "Setting up GVPE on: ${name} (${gvpe_sip[${name}]})"
        
        failed=0
        if [ "${gvpe_sip[${name}]}" = "localhost" ]
            then
            # it will sudo by itself if needed
            run /etc/gvpe/setup.sh /etc/gvpe || failed=1
        else
            # it will sudo by itself if needed
            run ssh "${gvpe_sip[${name}]}" "/etc/gvpe/setup.sh /etc/gvpe" || failed=1
        fi
    fi
}

node_routing_order() {
    local name="${1}"

    if [ "${gvpe_os[${name}]}" != "none" -a "${gvpe_sip[${name}]}" != "none" ]
        then
        echo >&2
        echo >&2 "Calculating GVPE routing order on: ${name} (${gvpe_sip[${name}]})"
        
        if [ "${gvpe_sip[${name}]}" = "localhost" ]
            then
            # it will sudo by itself if needed
            run sudo /usr/local/sbin/gvpe-routing-order.sh || failed=1
        else
            run ssh "${gvpe_sip[${name}]}" "\`which sudo\` /usr/local/sbin/gvpe-routing-order.sh" || failed=1
        fi
    fi
}

configure() {
    local c=0
    while [ ${c} -lt ${max_id} ]
    do
        c=$((c + 1))
        if [ -z "${gvpe_name_by_id[${c}]}" ]
            then
            echo >&2 "Missing id ${c}. Please don't remove nodes. Disable them."
            exit 1
        fi  
    done

    # generate the headers of configuration files
    prepare_configuration

    # generate needed files
    foreach_node node_status_file
    foreach_node node_gvpe_conf
    foreach_node node_hosts
    foreach_node node_keys

    # finalize the files
    cat conf.d/gvpe.conf.end >>conf.d/gvpe.conf
    cat >>conf.d/gvpe.conf <<EOF

# -----------------------------------------------------------------------------
# load routing priority
include routing.conf
EOF
    rm conf.d/gvpe.conf.end

    echo "# END gvpe real" >>conf.d/hosts.real
    echo "# END gvpe vpn"  >>conf.d/hosts.vpn
}

provision() {
    # provision files
    foreach_node node_provision_files
}

activate() {
    # setup nodes
    foreach_node node_setup
}

save_routing_order() {
    # setup nodes
    foreach_node node_routing_order
}

source nodes.conf
exit $?
