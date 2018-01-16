#!/usr/bin/env bash

LC_ALL=C
umask 022

# make sure host is here
which host >/dev/null || { echo >&2 "Install: host" && exit 1; }
which ip >/dev/null || { echo >&2 "Install: ip" && exit 1; }
# which dig >/dev/null || { echo >&2 "Install: dnsutils" && exit 1; }

# find the device of the default gateway
wan="$(ip -4 route get 8.8.8.8 | grep -oP "dev [^[:space:]]+ " | cut -d ' ' -f 2)"
[ -z "${wan}" ] && wan="eth0"
echo >&2 "Assuming default gateway is via device: ${wan}"

# find our IP
myip=( $(ip -4 address show ${wan} | grep 'inet' | sed 's/.*inet \([0-9\.]\+\).*/\1/') )
if [ -z "${myip[*]}" ]
	then
	echo >&2 "Cannot find my IP !"
	exit 1
fi

hostname_fqdn="$(hostname --fqdn)"
if [ -z "${hostname_fqdn}" ]
	then
	cat <<EOFHOSTNAME
Please set the hostname of the system:

 - edit /etc/hostname to add the FQDN hostname of the system
 - run: hostname -F /etc/hostname
 - add the FQDN hostname and the shortname to /etc/hosts
 - run me again
EOFHOSTNAME
	exit 1
fi

hostname_resolved="$(host ${hostname_fqdn} 8.8.8.8 | grep ' has address ' | sort -u | cut -d ' ' -f 4)"

cat <<EOF
THIS SCRIPT WILL TURN THIS MACHINE TO A NETDATA-DEMO-SITE

HOSTNAME     : ${hostname_fqdn}    (change it with: hostnamectl set-hostname FQDN-HOSTNAME )
WAN INTERFACE: ${wan}
WAN IPv4 IP  : ${myip}
RESOLVED IP  : ${hostname_resolved}
EOF

read -p "PRESS ENTER TO CONTINUE > "


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
		-e "s|MY_WAN_INTERFACE_TO_BE_REPLACED_HERE|${wan}|g" \
		-e "s|MY_REAL_IP_TO_BE_REPLACED_HERE|${myip[*]}|g" \
		-e "s|MY_HOSTNAME_TO_BE_REPLACED_HERE|$(hostname -s)|g" \
		-e "s|MY_FQDN_HOSTNAME_TO_BE_REPLACED_HERE|${hostname_fqdn}|g" \
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
myinstall etc/sysctl.d/inotify.conf root:root 644 || exit 1
sysctl --system



# -----------------------------------------------------------------------------
# NGINX

myinstall etc/nginx/cloudflare.conf root:root 644 || exit 1
myinstall etc/nginx/conf.d/status.conf root:root 644 || exit 1
myinstall etc/nginx/conf.d/netdata.conf root:root 644 || exit 1

cat >files/etc/nginx/snippets/ssl-certs.conf <<EOF
ssl_certificate /etc/letsencrypt/live/${hostname_fqdn}/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/${hostname_fqdn}/privkey.pem;
EOF
myinstall etc/nginx/snippets/ssl-certs.conf root:root 644 || exit 1
myinstall etc/nginx/snippets/ssl-params.conf root:root 644 || exit 1
myinstall etc/nginx/snippets/ssl.conf root:root 644 || exit 1

if [ ! -f /etc/ssl/certs/dhparam.pem ]
	then
	openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048 || exit 1
fi


# -----------------------------------------------------------------------------
# SSH LOCALE

myinstall etc/locale.gen root:root 644 locale-gen || exit 1


# -----------------------------------------------------------------------------
# COLORFULL PROMPT

myinstall etc/profile.d/prompt.sh root:root 755 || exit 1


# -----------------------------------------------------------------------------
# BOOT OPTIONS

myinstall etc/rc.local root:root 755 || exit 1


# -----------------------------------------------------------------------------
# LXC

myinstall etc/default/lxc-net root:root 755 || exit 1
myinstall etc/lxc/default.conf root:root 755 || exit 1


# -----------------------------------------------------------------------------
# SYSTEMD ACCOUNTING

sed -e 's|^#Default\(.*\)Accounting=.*$|Default\1Accounting=yes|g' </etc/systemd/system.conf >files/etc/systemd/system.conf || exit 1
myinstall etc/systemd/system.conf root:root 644 || exit 1
systemctl daemon-reexec

# -----------------------------------------------------------------------------
# ADD USERS

myadduser() {
	local username="${1}" key="${2}" home=

	getent passwd "${username}" >/dev/null 2>&1 || useradd -m ${username}
	
	eval "local home=~${username}"
	if [ -z "${home}" -o ! -d "${home}" ]
		then
		echo >&2 "Cannot find the home dir of user ${username}"
		exit 1
	fi

	mkdir -p files/${home}/.ssh || exit 1
	mkdir -p ${home}/.ssh || exit 1
	if [ -f "${home}/.ssh/authorized_keys" ]
		then
		( echo "${key}"; cat ${home}/.ssh/authorized_keys; ) | sort -u >files/${home}/.ssh/authorized_keys
	else
		echo "${key}" >files/${home}/.ssh/authorized_keys
	fi

	myinstall ./${home}/.ssh/authorized_keys ${username} 644 || exit 1

	# add the key to root
	mkdir -p files/root/.ssh || exit 1
	mkdir -p /root/.ssh || exit 1
	if [ -f /root/.ssh/authorized_keys ]
		then
		( echo "${key}"; cat /root/.ssh/authorized_keys; ) | sort -u >files/root/.ssh/authorized_keys
	else
		echo "${key}" >files/root/.ssh/authorized_keys
	fi

	myinstall root/.ssh/authorized_keys root:root 644 || exit 1

	if [ -f files/etc/sudoers.d/${username} ]
		then
		myinstall etc/sudoers.d/${username} root:root 400 || exit 1
	fi
}
myadduser costa "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCvh2gm+bcosazdtW7kd82in5/8rOB/SmsQnt+vNBpniBwM2TUfpcBpR/ydV3IA0B/tR/vWGm3Ak6pkCrAOm70URKx6aQKeUmqK3TxkXKehZA5eWifcZSyS6StQpPQLWW1PbtviFWwsWiJPA++uWfnMu3B2P2mc3lAUTAPv7Deii1SRTKj9RZW7jZ88mD/5SUSVIudu7f+X1oXycvwen/Zen29ot3E9zzjuqeDD+vGcQp9olfXPSrgR8IGYgdFDHieC9OXPiGS/VgZX+P3YFxR/xpWz1+7hq2TIU+7QFz1kclF+5eWzUiHmdyPj0T97tPHCD5yuQVbTmdHE197YndbB costa@tsaousis.gr"

# -----------------------------------------------------------------------------
# CONFIGURE POSTFIX

postconf -e "myhostname = $(hostname -s).my-netdata.io"
postconf -e "mydomain = my-netdata.io"
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

cat </etc/aliases |\
	sed -e '$a\' -e 'sysadmin: costa'          -e "/^sysadmin:.*$/d" |\
	sed -e '$a\' -e 'root: costa'              -e "/^root:.*$/d"     |\
	sed -e '$a\' -e 'costa: costa@tsaousis.gr' -e "/^costa:.*$/d"    |\
	cat >files/etc/aliases
myinstall etc/aliases root:root 644
newaliases


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

echo >&2 "Enabling LXC"
systemctl enable lxc || exit 1


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

echo >&2 "Starting LXC"
systemctl start lxc || exit 1


# -----------------------------------------------------------------------------
# SSL (nginx has to be running)

if [ ! -d /etc/letsencrypt/live/${hostname_fqdn}/ ]
	then

	do_ssl=1
	if [ "$(hostname -s).my-netdata.io" != "${hostname_fqdn}" ]
		then
		echo >&2 "CANNOT INSTALL LETSENCRYPT - WRONG HOSTNAME: $(hostname -s).my-netdata.io is not ${hostname_fqdn}"
		do_ssl=0
	fi

	if [ "${myip}" != "${hostname_resolved}" ]
		then
		echo >&2 "CANNOT INSTALL LETSENCRYPT - ${hostname_fqdn} is resolved to ${hostname_resolved}, instead of ${myip}"
		do_ssl=0
	fi

	if [ ${do_ssl} -eq 1 ]
		then

		if [ -d /usr/src/letsencrypt.git ]
			then
			cd /usr/src/letsencrypt.git || exit 1
			git fetch --all || exit 1
			git reset --hard origin/master || exit 1
		else
			cd /usr/src
			git clone https://github.com/letsencrypt/letsencrypt.git letsencrypt.git || exit 1
			cd letsencrypt.git || exit 1
		fi

		./letsencrypt-auto certonly --renew-by-default --text --agree-tos \
			--webroot --webroot-path=/var/www/html \
			--email costa@tsaousis.gr \
			-d ${hostname_fqdn} || exit 1

	fi
fi


# -----------------------------------------------------------------------------

cat <<EOF



# FIXME: 1. add hostname at /etc/hosts
# FIXME: 2. include snippets/ssl.conf at /etc/nginx/sites-available/default
# FIXME: 3. configure logging of timings at nginx.conf
# FIXME: 4. add ${myip} to my-netdata.io SPF record at cloudflare.com
# FIXME: 5. allow registry backup to this site (rsync from london)


EOF

echo >&2
echo >&2 "All done!"
exit 0
