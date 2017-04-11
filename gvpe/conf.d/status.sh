#!/usr/bin/env bash

export PATH="${PATH}:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin"

set -e
ME="${0}"
cd $(dirname "${ME}")/status

now=$(date +%s)

EVENTS=0
NODES_ALL=0
NODES_UP=0
NODES_DOWN=0
LAST="NEVER"

[ -f status ] && . ./status

cat <<EOF

GVPE Status on ${MYNODENAME} (Node No ${MYNODEID})

Total Events: ${EVENTS}
Last Event: $(date --date=@${timestamp} "+%Y-%m-%d %H:%M:%S")

Up ${NODES_UP}, Down ${NODES_DOWN}, Total ${NODES_ALL} nodes

EOF

printf "%3s %-30s %-15s %-15s %-6s %-20s\n" \
	"ID" "Name" "VPN IP" "REAL IP" "STATUS" "SINCE"

for x in $(ls -t *)
do
	[ "${x}" = "status" ] && continue
	[ "${x}" = "${MYNODEID}" ] && continue

	. ./${x}
	printf "%3u %-30s %-15s %-15s %-6s %-20s\n" \
		"$((x))" "${name}" "${ip}" "${rip}" "${status}" \
		"$(date --date=@${timestamp} "+%Y-%m-%d %H:%M:%S")"
done

