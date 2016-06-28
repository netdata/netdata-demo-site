#!/bin/bash

echo >&2

x=$(grep newrelic /etc/apt/sources.list.d/newrelic.list)
if [ -z "${x}" ]
	then
	echo >&2 "Adding NewRelic to apt..."
	echo deb http://apt.newrelic.com/debian/ newrelic non-free >>/etc/apt/sources.list.d/newrelic.list
	wget -O- https://download.newrelic.com/548C16BF.gpg | apt-key add -
	apt-get update
fi

echo >&2 "Installing newrelic agent..."
apt-get install newrelic-sysmond

echo >&2 "Setting newrelic license key..."
nrsysmond-config --set license_key=4048c8a4e7e604a87074eb565aa10acdd6a94adb

echo >&2 "Restarting newrelic agent..."
/etc/init.d/newrelic-sysmond restart
