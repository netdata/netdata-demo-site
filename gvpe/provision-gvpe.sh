#!/usr/bin/env bash

set -e

NULL=
BASE_NETWORK="172.16.254"

[ ! -d systemd ] && mkdir -p systemd
[ ! -d keys ] && mkdir -p keys
[ ! -d conf.d ] && mkdir -p conf.d
[ ! -d conf.d/pubkey ] && mkdir -p conf.d/pubkey

run() {
    printf >&2 " > "
    printf >&2 "%q " "${@}"
    printf >&2 "\n"
    
    "${@}"
    return $?
}

cat >gvpe.conf <<EOF
# automatically generated - DO NOT EDIT

enable-udp = yes
udp-port = 49999 # the external port to listen on (configure your firewall)

#enable-tcp = yes
#tcp-port = 49999 # the external port to listen on (configure your firewall)

mtu = 1400       # minimum MTU of all outgoing interfaces on all hosts
ifname = vpn0    # the local network device name
if-up = if-up
EOF

declare -A unique_names=()
declare -A unique_pips=()
declare -A unique_vips=()

all=
for h in \
    london:139.59.166.55:${BASE_NETWORK}.10 \
    atlanta:185.93.0.89:${BASE_NETWORK}.20 \
    west-europe:13.93.125.124:${BASE_NETWORK}.30 \
    bangalore:139.59.0.212:${BASE_NETWORK}.40 \
    frankfurt:46.101.193.115:${BASE_NETWORK}.50 \
    sanfrancisco:104.236.149.236:${BASE_NETWORK}.60 \
    toronto:159.203.30.96:${BASE_NETWORK}.70 \
    singapore:128.199.80.131:${BASE_NETWORK}.80 \
    newyork:162.243.236.205:${BASE_NETWORK}.90 \
    aws-fra:35.156.164.190:${BASE_NETWORK}.100 \
    netdata-build-server:40.68.190.151:${BASE_NETWORK}.110 \
    ${NULL}
do
    all="${all} ${h}"
    name=$(echo "${h}" | cut -d ':' -f 1)
    pip=$(echo "${h}" | cut -d ':' -f 2)
    vip=$(echo "${h}" | cut -d ':' -f 3)

    [ ! -z "${unique_names[${name}]}" ] && echo >&2 "Name '${name}' for IP ${pip} already exists with IP ${unique_names[${name}]}." && exit 1
    [ ! -z "${unique_pips[${pip}]}" ] && echo >&2 "Public IP '${pip}' for ${name} already exists for ${unique_pips[${pip}]}." && exit 1
    [ ! -z "${unique_vips[${vip}]}" ] && echo >&2 "VPN IP '${vip}' for ${name} already exists for ${unique_vips[${vip}]}." && exit 1
    
    unique_names[${name}]="${pip}"
    unique_pips[${pip}]="${name}"
    unique_vips[${vip}]="${name}"

    cat >>gvpe.conf <<EOF

node = ${name}
hostname = ${pip}
EOF

cat >conf.d/if-up.${name} <<EOF
#!/usr/bin/env bash
# automatically generated - DO NOT EDIT
set -e
run() {
    printf >&2 " > "
    printf >&2 "%q " "\${@}"
    printf >&2 "\n"
    "\${@}"
    return \$?
}

# show what is happening
echo >&2 "if-up    : \${0}"
echo >&2 "CONFBASE : \$CONFBASE"
echo >&2 "IFNAME   : \$IFNAME"
echo >&2 "IFTYPE   : \$IFTYPE"
echo >&2 "IFSUBTYPE: \$IFSUBTYPE"
echo >&2 "IFUPDATA : \$IFUPDATA"
echo >&2 "NODEID   : \$NODEID"
echo >&2 "NODENAME : \$NODENAME"
echo >&2 "MAC      : \$MAC"
echo >&2 "MTU      : \$MTU"
echo >&2 "NODES    : \$NODES"

# set it up
run ip link set \$IFNAME address \$MAC mtu \$MTU up
run ip addr add ${vip} dev \$IFNAME
run ip route add ${BASE_NETWORK}.0/24 dev \$IFNAME
exit 0
EOF
    chmod 755 conf.d/if-up.${name}

    cat >systemd/${name}.service <<EOF
# automatically generated - DO NOT EDIT
[Unit]
Description=gvpe
After=network.target
Before=remote-fs.target

[Service]
ExecStart=/usr/local/sbin/gvpe -c /etc/gvpe -D ${name}
KillMode=process
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    if [ ! -f "keys/${name}" -o ! -f "keys/${name}.privkey" ]
    then
        echo >&2 "generating keys for: ${name}"
        cd keys
        run ../sbin/gvpectrl -c ../conf.d -g ${name}
        cd ..
    fi
    if [ ! -f "conf.d/pubkey/${name}" ]
    then
        run cp keys/${name} conf.d/pubkey/${name}
    fi
done

for h in ${all}
do
    name=$(echo "${h}" | cut -d ':' -f 1)
    pip=$(echo "${h}" | cut -d ':' -f 2)
    vip=$(echo "${h}" | cut -d ':' -f 3)
    
    # make it call the right script
    # and bind on all local interfaces
    sed <gvpe.conf >conf.d/gvpe.conf \
        -e "s|^if-up = if-up$|if-up = if-up.${name}|g" \
        -e "s|^hostname = ${pip}$|hostname = 0.0.0.0|g"

    echo >&2
    echo >&2 "Provisioning: ${name}"
    run rsync -HaSPv sbin/ ${pip}:/usr/local/sbin/
    run rsync -HaSPv conf.d/ ${pip}:/etc/gvpe/
    run scp keys/${name}.privkey ${pip}:/etc/gvpe/hostkey
    
    systemd=1
    run scp systemd/${name}.service ${pip}:/etc/systemd/system/gvpe.service || systemd=0
    
    failed=0
    if [ $systemd -eq 1 ]
    then
        ssh "${pip}" "systemctl daemon-reload && systemctl restart gvpe" || failed=1
    else
        ssh "${pip}" killall -HUP gvpe || failed=1
    fi
    
    if [ $failed -eq 1 ]
    then
        echo >&2 "Failed to restart gvpe on ${name} at ${pip}"
    fi
done

