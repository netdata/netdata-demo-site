#!/usr/bin/env bash

LC_ALL=C
umask 022

# find our IP
myip=( $(ip -4 address show eth0 | grep 'inet' | sed 's/.*inet \([0-9\.]\+\).*/\1/') )
if [ -z "${myip[*]}" ]
	then
	echo >&2 "Cannot find my IP !"
	exit 1
fi

# -----------------------------------------------------------------------------

./install-required-packages.sh demo || exit 1

# -----------------------------------------------------------------------------

./install-all-firehol.sh || exit 1

# -----------------------------------------------------------------------------

tmp=/tmp/installer.$RANDOM.$RANDOM.$$

myinstall() {
	local file="${1}" owner="${2}" perms="${3}" callback="${4}"

	echo >&2
	echo >&2 "Checking: /${file} ..."

	if [ ! -f "files/${file}" ]
	then
		echo >&2 "Cannot find file '${file}'"
		return 1
	fi

	cat "files/${file}" | sed \
		-e "s|MY_REAL_IP_TO_BE_REPLACED_HERE|${myip[*]}|g" \
		>"${tmp}"

	if [ ! -s "${tmp}" ]
		then
		echo " >> empty sized converted file: ${tmp} from files/${file}"
		return 1
	fi

	if [ -f "/${file}" ]
	then
		diff -q "/${file}" "${tmp}"
		if [ $? -eq 0 ]
		then
			echo >&2 " >> it is the same..."
			return 0
		else
			echo >&2 " >> file /${file} has differences: "
			diff "/${file}" "${tmp}"
			REPLY=
			while [ "${REPLY}" != "y" -a "${REPLY}" != "Y" ]
			do
				read -p "update /${file} ? [y/n] > "
				case "${REPLY}" in
					y|Y) break ;;
					n|N) return 0;;
				esac
			done
		fi
	fi

	echo >&2 " >> installing: /${file} ..."
	cp "${tmp}" "/${file}" || return 1
	chown "${owner}" "/${file}" || return 1
	chmod "${perms}" "/${file}" || return 1

	if [ ! -z "${callback}" ]
	then
		echo >&2 " >> running: ${callback}"
		${callback} || return 1
	fi

	return 0
}

# -----------------------------------------------------------------------------
# FireHOL / FireQOS

myinstall etc/firehol/cloudflare.netset root:root 600 || exit 1
myinstall etc/firehol/firehol.conf root:root 600 || exit 1
myinstall etc/firehol/fireqos.conf root:root 600 || exit 1
myinstall etc/systemd/system/firehol.service  root:root 644 || exit 1
myinstall etc/systemd/system/fireqos.service  root:root 644 || exit 1

myinstall etc/sysctl.d/core.conf root:root 644 || exit 1
myinstall etc/sysctl.d/synproxy.conf root:root 644 || exit 1
myinstall etc/sysctl.d/net-buffers.conf root:root 644 || exit 1
myinstall etc/sysctl.d/net-security.conf root:root 644 || exit 1
sysctl --system

# -----------------------------------------------------------------------------
# NGINX

myinstall etc/nginx/cloudflare.conf root:root 644 || exit 1
myinstall etc/nginx/conf.d/status.conf root:root 644 || exit 1
myinstall etc/nginx/conf.d/netdata.conf root:root 644 || exit 1

# -----------------------------------------------------------------------------
# SSH LOCALE

myinstall etc/locale.gen root:root 644 locale-gen || exit 1

# -----------------------------------------------------------------------------
# COLORFUL PROMPT

myinstall etc/profile.d/prompt.sh root:root 755 || exit 1

# -----------------------------------------------------------------------------
# BOOT OPTIONS

myinstall etc/rc.local root:root 755 || exit 1

# -----------------------------------------------------------------------------
# CONFIGURE POSTFIX

postconf -e "myhostname=$(hostname -s).my-netdata.io"
postconf -e "mydomain=my-netdata.io"
postconf -e "myorigin = my-netdata.io"
postconf -e "mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128 172.16.254.0/24"
postconf -e "relay_domains = my-netdata.io, mynetdata.io, netdata.cloud, netdata.online, netdata.rocks"
postconf -e "mailbox_size_limit = 0"
postconf -e "recipient_delimiter = +"
postconf -e "inet_interfaces = localhost"
postconf -e "smtpd_tls_security_level=may"
postconf -# "smtpd_use_tls"
postconf -# "smtpd_enforce_tls"
postconf -e "alias_maps = hash:/etc/aliases"

if [ ! -z "$(grep "^root: costa$" /etc/aliases)" ]
	then
	cat >>/etc/aliases <<EOF
root: costa
costa: costa@tsaousis.gr
EOF
	newaliases
fi

# -----------------------------------------------------------------------------
# ENABLE EVERTYTHING

echo >&2 "Reloading systemd"
systemctl daemon-reload || exit 1

echo >&2 "Enabling ulogd2"
systemctl enable ulogd2 || exit 1

echo >&2 "Enabling firehol"
systemctl enable firehol || exit 1

echo >&2 "Enabling fireqos"
systemctl enable fireqos || exit 1

echo >&2 "Enabling postfix"
systemctl enable postfix || exit 1

echo >&2 "Enabling nginx"
systemctl enable nginx || exit 1

echo >&2 "Enabling netdata"
systemctl enable netdata || exit 1

# -----------------------------------------------------------------------------
# START EVERYTHING

echo >&2

echo >&2 "Starting ulogd2"
systemctl restart ulogd2 || exit 1

echo >&2 "Starting firehol"
systemctl restart firehol || exit 1

echo >&2 "Starting fireqos"
systemctl restart fireqos || exit 1

echo >&2 "Restarting postfix"
systemctl restart postfix || exit 1

echo >&2 "Starting nginx"
systemctl restart nginx || exit 1

echo >&2 "Restarting netdata"
systemctl restart netdata || exit 1

echo >&2
echo >&2 "All done!"
exit 0
