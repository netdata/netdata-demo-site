#!/usr/bin/env bash

ME="${0}"

lsb_release=$(which lsb_release 2>/dev/null || command lsb_release 2>/dev/null)
emerge=$(which emerge 2>/dev/null || command emerge 2>/dev/null)
apt_get=$(which apt-get 2>/dev/null || command apt-get 2>/dev/null)
yum=$(which yum 2>/dev/null || command yum 2>/dev/null)
dnf=$(which dnf 2>/dev/null || command dnf 2>/dev/null)

distribution=
version=
codename=
package_installer=
package_tree=

validate_package_manager() {
	case "${1}" in
		apt-get)
			[ -z "${apt_get}" ] && echo >&2 "${1} is not available." && return 1
			package_installer="install_apt_get"
			package_tree="debian"
			return 0
			;;

		yum)
			[ -z "${yum}" ] && echo >&2 "${1} is not available." && return 1
			package_installer="install_yum"
			package_tree="redhat"
			return 0
			;;

		dnf)
			[ -z "${dnf}" ] && echo >&2 "${1} is not available." && return 1
			package_installer="install_dnf"
			package_tree="redhat"
			return 0
			;;

		emerge)
			[ -z "${emerge}" ] && echo >&2 "${1} is not available." && return 1
			package_installer="install_emerge"
			package_tree="gentoo"
			return 0
			;;

		*)
			echo >&2 "Invalid package manager: '${1}'."
			return 1
			;;
	esac
}

user_picks_distribution() {
	echo >&2
	echo >&2 "I NEED YOUR HELP"
	echo >&2 "It seems I cannot detect your system automatically."
	if [ -z "${emerge}" -a -z "${apt_get}" -a -z "${yum}" -a -z "${dnf}" ]
		then
		echo >&2 "And it seems I cannot find a known packages installer in this system."
		echo >&2 "Please open a github issue to help us support your system too."
		exit 1
	fi

	local opts=
	echo >&2 "I found though that the following installers are available:"
	echo >&2
	[ ! -z "${apt_get}" ] && echo >&2 " - Debian/Ubuntu based (installer is: apt-get)" && opts="${opts} apt-get"
	[ ! -z "${yum}"     ] && echo >&2 " - Redhat/Fedora/Centos based (installer is: yum)" && opts="${opts} yum"
	[ ! -z "${dnf}"     ] && echo >&2 " - Redhat/Fedora/Centos based (installer is: dnf)" && opts="${opts} dnf"
	[ ! -z "${emerge}"  ] && echo >&2 " - Gentoo based (installer is: emerge)" && opts="${opts} emerge"
	echo >&2

	REPLY=
	while [ -z "${REPLY}" ]
	do
		read -p "To proceed please write one of these:${opts}: "
		validate_package_manager "${REPLY}" || REPLY=
	done
}

autodetect_package_manager() {
	case "${distribution,,}" in
		gentoo)
			package_installer="install_gentoo"
			package_tree="debian"
			if [ -z "${emerge}" ]
				then
				echo >&2 "command 'emerge' is required to install packages on a '${distribution} ${version}' system."
				exit 1
			fi
			;;

		debian|ubuntu|elementary\ os)
			package_installer="install_apt_get"
			package_tree="debian"
			if [ -z "${apt_get}" ]
				then
				echo >&2 "command 'apt-get' is required to install packages on a '${distribution} ${version}' system."
				exit 1
			fi
			;;

		fedora|redhat|centos)
			package_installer=
			package_tree="redhat"
			[ ! -z "${dnf}" ] && package_installer="install_dnf"
			[ ! -z "${yum}" ] && package_installer="install_yum"
			if [ -z "${package_installer}" ]
				then
				echo >&2 "command 'yum' or 'dnf' is required to install packages on a '${distribution} ${version}' system."
				exit 1
			fi
			;;

		*)
			# oops! unknown system
			user_picks_distribution
			;;
	esac
}

# parse command line arguments
while [ ! -z "${1}" ]
do
	case "${1}" in
		distribution) distribution="${2}"; shift 2 ;;
		version) version="${2}"; shift 2 ;;
		codename) codename="${2}"; shift 2 ;;
		installer)
			validate_package_manager "${2}" || exit 1
			shift 2
			;;
		help|-h|--help)
			echo >&2 "${ME} [distribution gentoo|debian|redhat [version 1.2.3] [codename NAME]] [installer apt-get|yum|dnf|emerge] "
			exit 1
			;;
		*) echo >&2 "Cannot understand option '${1}'"; exit 1 ;;
	esac
done

while [ -z "${package_installer}" -o -z "${package_tree}" ]
	do
	if [ -z "${distribution}" ]
		then
		if [ -z "${lsb_release}" ]
			then
			# we don't have distribution and we don't have lsb_release
			echo >&2 "Your system does not have command: lsb_release"
			user_picks_distribution
		else
			# we don't have distribution, but we have lsb_release
			eval "declare -A release=( $(lsb_release -a 2>/dev/null | sed -e "s|^\(.*\):[[:space:]]*\(.*\)$|[\1]=\"\2\"|g") )"
			distribution="${release[Distributor ID]}"
			version="${release[Release]}"
			codename="${release[Codename]}"
			autodetect_package_manager
		fi
	else
		# we have a distribution
		autodetect_package_manager
	fi
done

packages() {
	local tree="${1}"

	# -------------------------------------------------------------------------
	# basic build environment
	
	echo gcc
	echo make
	echo git
	echo autoconf
	echo autogen
	echo automake

	case "${tree}" in
		debian)	echo pkg-config
				;;
		redhat)	echo pkgconfig
				;;
		gentoo) echo pkg-config
				;;
		*)		echo >&2 "Unknown package tree '${tree}'."
				;;
	esac

	# -------------------------------------------------------------------------
	# debugging tools for development

	echo gdb
	echo valgrind
	echo cmake
	echo traceroute
	echo tcpdump
	
	# -------------------------------------------------------------------------
	# common command line tools

	echo curl	# web client
	echo jq		# JSON parsing
	echo netcat # network swiss army knife

	# -------------------------------------------------------------------------
	# firehol/fireqos/update-ipsets command line tools

	echo iptables
	echo ipset
	echo ulogd
	echo zip	# for update-ipsets
	echo unzip	# for update-ipsets

	# -------------------------------------------------------------------------
	# netdata libraries

	case "${tree}" in
		debian)	echo zlib1g-dev
				echo uuid-dev
				echo libmnl-dev

				;;
		redhat)	echo zlib-devel
				echo uuid-devel
				echo libmnl-devel
				;;

		gentoo)	echo sys-libs/zlib
				echo sys-apps/util-linux
				echo net-libs/libmnl
				;;
		*)		echo >&2 "Unknown package tree '${tree}'."
				;;
	esac

	# -------------------------------------------------------------------------
	# scripting interpreters for netdata plugins

	echo nodejs
	echo python

	case "${tree}" in
		debian)	# echo python-pip
				echo python-mysqldb
				echo python-yaml
				;;
		redhat)	# echo python-pip
				echo python-mysqldb
				echo python-yaml
				;;
		gentoo) # echo dev-python/pip
				echo dev-python/mysqlclient
				echo dev-python/pyyaml
				;;
		*)		echo >&2 "Unknown package tree '${tree}'."
				;;
	esac

	# -------------------------------------------------------------------------
	# applications needed for the netdata demo sites

	echo nginx
}

cat <<EOF

Distribution   : ${distribution}
Version        : ${version}
Codename       : ${codename}
Package Manager: ${package_installer}
Packages Tree  : ${package_tree}

The following packages will be installed:

$(packages ${package_tree} | sort -u | tr -s '\n'  ' ' | fold -w 70 -s)

Please make sure your system is up to date.

EOF


install_apt_get() {
	apt-get install "${@}"
}

install_yum() {
	yum install "${@}"
}

install_dnf() {
	dnf install "${@}"
}

install_gentoo() {
	emerge --ask -DNv "${@}"
}

${package_installer} $(packages ${package_tree} | sort -u) || exit 1

exit 0
