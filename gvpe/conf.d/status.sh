#!/usr/bin/env bash

set -e

cd $(dirname "$0")/status

printf "%-30s %-15s %-15s %-10s\n" "Name" "VPN IP" "REAL IP" "STATUS"

for x in $(ls * | sort -n)
do
	. $x
	printf "%-30s %-15s %-15s %-10s\n" "$name" "$ip" "$rip" "$status"
done
