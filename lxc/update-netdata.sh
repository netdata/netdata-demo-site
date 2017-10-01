#!/usr/bin/env bash
#
# Install or Update netdata
# on all lxc containers of the system
# and stream their metrics to the netdata
# running at the host

lxcbase="/var/lib/lxc"
lxcbr="lxcbr0"
host=( $(ip -4 address show ${lxcbr} | grep 'inet' | sed 's/.*inet \([0-9\.]\+\).*/\1/') )

if [ ${#host[*]} -eq 0 ]
	then
	echo >&2 "Cannot find the IP address of interface '${lxcbr}'."
	exit 1
fi

# -----------------------------------------------------------------------------
# api keys

lxcapikey=$(</etc/netdata/apikey.lxc)
if [ -z "${lxcapikey}" ]
	then
	lxcapikey=$(cat /proc/sys/kernel/random/uuid)
	[ -z "${lxcapikey}" ] && echo >&2 "Cannot create a UUID" && exit 1
	echo "${lxcapikey}" >/etc/netdata/apikey.lxc
fi

demoapikey=$(</etc/netdata/apikey.demos)

# -----------------------------------------------------------------------------
# download the latest static netdata

STATICBASE='https://raw.githubusercontent.com/firehol/binary-packages/master'
LATEST=$(curl "${STATICBASE}/netdata-latest.gz.run")
[ -z "${LATEST}" ] && echo >&2 "Cannot find the latest binary netdata." && exit 1
curl "${STATICBASE}/${LATEST}" >"/tmp/${LATEST}"

[ ! -s "/tmp/${LATEST}" ] && echo >&2 "Cannot download latest binary netdata." &&  exit 1


# -----------------------------------------------------------------------------
# prepare the master

cat >/etc/netdata/netdata.conf <<EOF
# DO NOT EDIT - generated by netdata-demo-sites/lxc/update.sh
[global]
	access log = none
	errors flood protection period = 3600
	errors to trigger flood protection = 1000
	hostname = $(hostname -f)
	history = 172800
	memory mode = map
	OOM score = -10
	process scheduling policy = nice
	process nice level = -10
	disconnect idle web clients after seconds = 3600
	update every = 1

[health]
	in memory max health log entries = 10000
	rotate log every lines = 20000

[web]
	stream allow from = localhost 10.* 192.168.* 172.16.*
	listen backlog = 2000

[registry]
	enabled = yes
	registry db file = /backup/registry/latest/registry.db
	registry log file = /backup/registry/latest/registry-log.db
	registry domain = my-netdata.io

EOF

cat >/etc/netdata/stream.conf <<EOF
# DO NOT EDIT - generated by netdata-demo-sites/lxc/update.sh
[stream]
	enabled = no
	api key =
	destination =
	timeout seconds = 60
	default port = 19999
	buffer size bytes = 1048576
	reconnect delay seconds = 5
	initial clock resync iterations = 60

[${lxcapikey}]
	enabled = yes
	default history = 129600
	default memory mode = map
	health enabled by default = auto
	default postpone alarms on connect seconds = 60
	default proxy enabled = no
EOF

if [ ! -z "${demoapikey}" ]
	then
	cat >>/etc/netdata/stream.conf <<EOF2

# demo servers
[${demoapikey}]
	enabled = yes
	default history = 129600
	default memory mode = map
	health enabled by default = auto
	default postpone alarms on connect seconds = 60
	default proxy enabled = no
EOF2
fi

opwd="$(pwd)"
for x in $(ls ${lxcbase})
do
	base="${lxcbase}/${x}/rootfs"
	
	echo >&2
	echo >&2 "working on lxc container: ${x}"
	
	mkdir -p "${lxcbase}/${x}/rootfs/opt/netdata/etc/netdata" || continue

	cp "/tmp/${LATEST}" "${lxcbase}/${x}/rootfs/opt/netdata-latest.run"
	chmod 755 "${lxcbase}/${x}/rootfs/opt/netdata-latest.run"

	cat >"${lxcbase}/${x}/rootfs/opt/netdata/etc/netdata/netdata.conf" <<EOF
# DO NOT EDIT - generated by netdata-demo-sites/lxc/update.sh
[global]
	hostname = build-lxc-${x}
	memory mode = none

[web]
	mode = none

[plugins]
	enable running new plugins = no
	tc = no
	idlejitter = no
	proc = yes
	diskspace = no
	cgroups = no
	checks = no

[health]
	enabled = no

EOF

	cat >"${lxcbase}/${x}/rootfs/opt/netdata/etc/netdata/stream.conf" <<EOF
# DO NOT EDIT - generated by netdata-demo-sites/lxc/update.sh
[stream]
	enabled = yes
	api key = ${lxcapikey}
	destination = ${host}:19999
	timeout seconds = 60
	default port = 19999
	buffer size bytes = 1048576
	reconnect delay seconds = 5
	initial clock resync iterations = 60
EOF

	lxc-attach -n "${x}" -- /opt/netdata-latest.run --accept
done
cd "${opwd}" || exit 1

cd /usr/src/netdata-ktsaou.git
git fetch --all
git reset --hard origin/master
./netdata-updater.sh -f
