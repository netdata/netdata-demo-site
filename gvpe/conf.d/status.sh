#!/usr/bin/env bash

export PATH="${PATH}:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin"

set -e

cd $(dirname "$0")/status

now=$(date +%s)

printf "%-30s %-15s %-15s %-6s %-20s\n" "Name" "VPN IP" "REAL IP" "STATUS" "DATE"

for x in $(ls * | sort -n)
do
	. $x
	printf "%-30s %-15s %-15s %-6s %-20s\n" "$name" "$ip" "$rip" "$status" "$(date --date=@${timestamp} "+%Y-%m-%d %H:%M:%S")"
done

