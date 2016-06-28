#!/bin/bash

# for debian 8.5

LC_ALL=C
umask 022

# -----------------------------------------------------------------------------

#./packages.sh || exit 1

# -----------------------------------------------------------------------------

#./install-all-firehol.sh || exit 1

# -----------------------------------------------------------------------------

myinstall() {
	local file="${1}" owner="${2}" perms="${3}" callback="${4}"

	echo >&2
	echo >&2 "Checking: /${file} ..."

	if [ ! -f "files/${file}" ]
	then
		echo >&2 "Cannot find file '${file}'"
		return 1
	fi

	if [ -f "/${file}" ]
	then
		diff -q "files/${file}" "/${file}"
		if [ $? -eq 0 ]
		then
			echo >&2 " >> it is the same..."
			return 0
		else
			echo >&2 " >> file /${file} has differences: "
			diff "files/${file}" "/${file}"
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
	cp "files/${file}" "/${file}" || return 1
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
# START EVERTYTHING

echo >&2 "Reloading systemd"
systemctl daemon-reload || exit 1

echo >&2 "Enabling firehol"
systemctl enable firehol || exit 1

echo >&2 "Enabling fireqos"
systemctl enable fireqos || exit 1

echo >&2 "Enabling netdata"
systemctl enable netdata || exit 1

echo >&2 "Enabling nginx"
systemctl enable nginx || exit 1

echo >&2 "Enabling ulogd2"
systemctl enable ulogd2 || exit 1

echo >&2 "Starting ulogd2"
systemctl start ulogd2 || exit 1

echo >&2 "Starting firehol"
systemctl start firehol || exit 1

echo >&2 "Starting fireqos"
systemctl start fireqos || exit 1

echo >&2 "Starting nginx"
systemctl start nginx || exit 1

echo >&2 "Restarting netdata"
systemctl restart netdata || exit 1

echo >&2 "All done!"
exit 0

