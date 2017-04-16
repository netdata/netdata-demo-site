#!/usr/bin/env bash

export PATH="${PATH}:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin"

set -e
ME="${0}"

cd /etc/gvpe/status

if [ ! -f ./status ]
	then
	echo >&2 "Is GVPE running?"
	exit 1
fi

EVENTS=0
NODES_ALL=0
NODES_UP=0
NODES_DOWN=0
timestamp="NEVER"
. ./status

if [ "${timestamp}" = "NEVER" ]
	then
	echo >&2 "GVPE is not connected"
	exit 1
fi

cat <<EOF

GVPE Status on ${MYNODENAME} (Node No ${MYNODEID})

Total Events: ${EVENTS}
Last Event: $(date -r ./status "+%Y-%m-%d %H:%M:%S")

Up ${NODES_UP}, Down ${NODES_DOWN}, Total ${NODES_ALL} nodes

EOF

printf "%3s %-25s %-15s %-25s %-6s %-20s\n" \
	"ID" "Name" "VPN IP" "REAL IP" "STATUS" "SINCE"

while read x
do
	[ "${x}" = "${MYNODENAME}" ] && continue
	[ ! -f "${x}" ] && echo >&2 "File '${x}' missing!" && continue

	. ./${x}

	remote="${rip}"
	if [ "${status}" = "up" ]
		then
		remote="${si}"
		[ ! -z "${pip}" -a "${pip}" != "dynamic" -a "${rip}" != "${pip}" ] && status="routed"
	else
		remote="${pip}"
	fi

	printf "%3u %-25s %-15s %-25s %-6s %-20s\n" \
		"$((nodeid))" "${name}" "${ip}" "${remote}" "${status}" \
		"$(date -r "./${x}" "+%Y-%m-%d %H:%M:%S")"
done <nodes
