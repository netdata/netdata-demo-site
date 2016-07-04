#!/usr/bin/env bash

export PATH="${PATH}:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin"

ME="${0}"

lsb_release=$(which lsb_release 2>/dev/null || command lsb_release 2>/dev/null)
emerge=$(which emerge 2>/dev/null || command emerge 2>/dev/null)
apt_get=$(which apt-get 2>/dev/null || command apt-get 2>/dev/null)
yum=$(which yum 2>/dev/null || command yum 2>/dev/null)
dnf=$(which dnf 2>/dev/null || command dnf 2>/dev/null)
pacman=$(which pacman 2>/dev/null || command pacman 2>/dev/null)

# TODO
# 1. add zypper (opensuse)
# 2. add rpm (who uses it now?)

distribution=
version=
codename=
package_installer=
package_tree=

release2lsb_release() {
	# loads the given /etc/x-release file
	# this file is normaly a single line containing something like
	#
	# X Linux release 1.2.3 (release-name)
	#
	# It attempts to parse it
	# If it succeeds, it returns 0
	# otherwise it returns 1

	local file="${1}" x DISTRIB_ID= DISTRIB_RELEASE= DISTRIB_CODENAME= DISTRIB_DESCRIPTION=
	echo >&2 "Loading ${file} ..."


	x=$(<"${file}")

	if [[ "${x}" =~ ^.*[[:space:]]+Linux[[:space:]]+release[[:space:]]+.*[[:space:]]+(.*)[[:space:]]*$ ]]
		then
		eval "$(sed "s|^\(.*\)[[:space:]]\+Linux[[:space:]]\+release[[:space:]]\+\(.*\)[[:space:]]\+(\(.*\))[[:space:]]\+$|DISTRIB_ID=\1\nDISTRIB_RELEASE=\2\nDISTRIB_CODENAME=\3|g" <${file})"
	elif [[ "${x}" =~ ^.*[[:space:]]+Linux[[:space:]]+release[[:space:]]+.*[[:space:]]+$ ]]
		then
		eval "$(sed "s|^\(.*\)[[:space:]]\+Linux[[:space:]]\+release[[:space:]]\+\(.*\)[[:space:]]\+$|DISTRIB_ID=\1\nDISTRIB_RELEASE=\2|g" <${file})"
	elif [[ "${x}" =~ ^.*[[:space:]]+release[[:space:]]+.*[[:space:]]+(.*)[[:space:]]*$ ]]
		then
		eval "$(sed "s|^\(.*\)[[:space:]]\+release[[:space:]]\+\(.*\)[[:space:]]\+(\(.*\))[[:space:]]\+$|DISTRIB_ID=\1\nDISTRIB_RELEASE=\2\nDISTRIB_CODENAME=\3|g" <${file})"
	elif [[ "${x}" =~ ^.*[[:space:]]+release[[:space:]]+.*[[:space:]]+$ ]]
		then
		eval "$(sed "s|^\(.*\)[[:space:]]\+release[[:space:]]\+\(.*\)[[:space:]]\+$|DISTRIB_ID=\1\nDISTRIB_RELEASE=\2|g" <${file})"
	fi

	distribution="${DISTRIB_ID}"
	version="${DISTRIB_RELEASE}"
	codename="${DISTRIB_CODENAME}"

	[ -z "${distribution}" ] && echo >&2 "Cannot parse this lsb-release: ${x}" && return 1
	return 0
}

get_os_release() {
	# Loads the /etc/os-release file
	# Only the required fields are loaded
	#
	# If it manages to load /etc/os-release, it returns 0
	# otherwise it returns 1

	local x NAME= ID= ID_LIKE= VERSION= VERSION_ID=
	if [ -f "/etc/os-release" ]
		then
		echo >&2 "Loading /etc/os-release ..."

		eval "$(cat /etc/os-release | grep -E "^(NAME|ID|ID_LIKE|VERSION|VERSION_ID)=")"
		for x in "${ID}" ${ID_LIKE}
		do
			case "${x,,}" in
				arch|centos|debian|fedora|gentoo|rhel|ubuntu)
					distribution="${x}"
					version="${VERSION_ID}"
					codename="${VERSION}"
					break
					;;
				*)
					echo >&2 "Unknown distribution ID: ${x}"
					;;
			esac
		done
		[ -z "${distribution}" ] && echo >&2 "Cannot find valid distribution in: ${ID} ${ID_LIKE}" && return 1
	else
		echo >&2 "Cannot find /etc/os-release" && return 1
	fi

	[ -z "${distribution}" ] && return 1
	return 0
}

get_lsb_release() {
	# Loads the /etc/lsb-release file
	# If it fails, it attempts to run the command: lsb_release -a
	# and parse its output
	#
	# If it manages to find the lsb-release, it returns 0
	# otherwise it returns 1

	if [ -f "/etc/lsb-release" ]
	then
		echo >&2 "Loading /etc/lsb-release ..."
		local DISTRIB_ID= ISTRIB_RELEASE= DISTRIB_CODENAME= DISTRIB_DESCRIPTION=
		eval "$(cat /etc/lsb-release | grep -E "^(DISTRIB_ID|DISTRIB_RELEASE|DISTRIB_CODENAME)=")"
		distribution="${DISTRIB_ID}"
		version="${DISTRIB_RELEASE}"
		codename="${DISTRIB_CODENAME}"
	fi

	if [ -z "${distribution}" -a ! -z "${lsb_release}" ]
		then
		echo >&2 "Cannot find distribution with /etc/lsb-release"
		echo >&2 "Running command: lsb_release ..."
		eval "declare -A release=( $(lsb_release -a 2>/dev/null | sed -e "s|^\(.*\):[[:space:]]*\(.*\)$|[\1]=\"\2\"|g") )"
		distribution="${release[Distributor ID]}"
		version="${release[Release]}"
		codename="${release[Codename]}"
	fi

	[ -z "${distribution}" ] && echo >&2 "Cannot find valid distribution with lsb-release" && return 1
	return 0
}

find_etc_any_release() {
	# Check for any of the known /etc/x-release files
	# If it finds one, it loads it and returns 0
	# otherwise it returns 1

	if [ -f "/etc/arch-release" ]
		then
		release2lsb_release "/etc/arch-release" && return 0
	fi

	if [ -f "/etc/centos-release" ]
		then
		release2lsb_release "/etc/centos-release" && return 0
	fi

	if [ -f "/etc/redhat-release" ]
		then
		release2lsb_release "/etc/redhat-release" && return 0
	fi

	return 1
}

autodetect_distribution() {
	# autodetection of distribution
	get_os_release || get_lsb_release || find_etc_any_release
}

user_picks_distribution() {
	# let the user pick a distribution

	echo >&2
	echo >&2 "I NEED YOUR HELP"
	echo >&2 "It seems I cannot detect your system automatically."
	if [ -z "${emerge}" -a -z "${apt_get}" -a -z "${yum}" -a -z "${dnf}" -a -z "${pacman}" ]
		then
		echo >&2 "And it seems I cannot find a known package manager in this system."
		echo >&2 "Please open a github issue to help us support your system too."
		exit 1
	fi

	local opts=
	echo >&2 "I found though that the following installers are available:"
	echo >&2
	[ ! -z "${apt_get}" ] && echo >&2 " - Debian/Ubuntu based (installer is: apt-get)" && opts="${opts} apt-get"
	[ ! -z "${yum}"     ] && echo >&2 " - Redhat/Fedora/Centos based (installer is: yum)" && opts="${opts} yum"
	[ ! -z "${dnf}"     ] && echo >&2 " - Redhat/Fedora/Centos based (installer is: dnf)" && opts="${opts} dnf"
	[ ! -z "${pacman}"  ] && echo >&2 " - Arch Linux based (installer is: pacman)" && opts="${opts} pacman"
	[ ! -z "${emerge}"  ] && echo >&2 " - Gentoo based (installer is: emerge)" && opts="${opts} emerge"
	echo >&2

	REPLY=
	while [ -z "${REPLY}" ]
	do
		read -p "To proceed please write one of these:${opts}: "
		check_package_manager "${REPLY}" || REPLY=
	done
}

detect_package_manager_from_distribution() {
	case "${1,,}" in
		arch*)
			package_installer="install_pacman"
			package_tree="arch"
			if [ -z "${pacman}" ]
				then
				echo >&2 "command 'pacman' is required to install packages on a '${distribution} ${version}' system."
				exit 1
			fi
			;;

		gentoo*)
			package_installer="install_emerge"
			package_tree="gentoo"
			if [ -z "${emerge}" ]
				then
				echo >&2 "command 'emerge' is required to install packages on a '${distribution} ${version}' system."
				exit 1
			fi
			;;

		debian*|ubuntu*)
			package_installer="install_apt_get"
			package_tree="debian"
			if [ -z "${apt_get}" ]
				then
				echo >&2 "command 'apt-get' is required to install packages on a '${distribution} ${version}' system."
				exit 1
			fi
			;;

		centos*)
			echo >&2 "You should have EPEL enabled to install all the prerequisites."
			echo >&2 "Check: http://www.tecmint.com/how-to-enable-epel-repository-for-rhel-centos-6-5/"
			package_installer="install_yum"
			package_tree="centos"
			if [ -z "${yum}" ]
				then
				echo >&2 "command 'yum' is required to install packages on a '${distribution} ${version}' system."
				exit 1
			fi
			;;

		fedora*|redhat*|red\ hat*|rhel*)
			package_installer=
			package_tree="rhel"
			[ ! -z "${yum}" ] && package_installer="install_yum"
			[ ! -z "${dnf}" ] && package_installer="install_dnf"
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

check_package_manager() {
	# This is called only when the user is selecting a package manager
	# It is used to verify the user selection is right

	echo >&2 "Checking package manager: ${1}"

	case "${1}" in
		apt-get)
			[ -z "${apt_get}" ] && echo >&2 "${1} is not available." && return 1
			package_installer="install_apt_get"
			package_tree="debian"
			return 0
			;;

		dnf)
			[ -z "${dnf}" ] && echo >&2 "${1} is not available." && return 1
			package_installer="install_dnf"
			package_tree="rhel"
			return 0
			;;

		emerge)
			[ -z "${emerge}" ] && echo >&2 "${1} is not available." && return 1
			package_installer="install_emerge"
			package_tree="gentoo"
			return 0
			;;

		pacman)
			[ -z "${pacman}" ] && echo >&2 "${1} is not available." && return 1
			package_installer="install_pacman"
			package_tree="arch"
			return 0
			;;

		yum)
			[ -z "${yum}" ] && echo >&2 "${1} is not available." && return 1
			package_installer="install_yum"
			[ -z "${distribution}" ] && echo >&2 "Warning: PLEASE SET THE DISTRIBUTION TOO (centos or redhat or fedora?)."
			if [ "${distribution}" = "centos" ]
				then
				package_tree="centos"
			else
				package_tree="rhel"
			fi
			return 0
			;;

		*)
			echo >&2 "Invalid package manager: '${1}'."
			return 1
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
			check_package_manager "${2}" || exit 1
			shift 2
			;;
		help|-h|--help)
			echo >&2 "${ME} [distribution gentoo|debian|redhat|ubuntu|fedora|centos [version 1.2.3] [codename NAME]] [installer apt-get|yum|dnf|emerge] "
			exit 1
			;;
		*) echo >&2 "Cannot understand option '${1}'"; exit 1 ;;
	esac
done

if [ -z "${package_installer}" -o -z "${package_tree}" ]
	then
	if [ -z "${distribution}" ]
		then
		# we dont know the distribution
		autodetect_distribution || user_picks_distribution
	fi

	detect_package_manager_from_distribution "${distribution}"
fi

require_cmd() {
	while [ ! -z "${1}" ]
	do
		which "${1}" >/dev/null 2>&1 && return 0
		command "${1}" >/dev/null 2>&1 && return 0
		shift
	done
	return 1
}

packages() {
	local tree="${1}"

	# -------------------------------------------------------------------------
	# basic build environment

	require_cmd gcc      || echo gcc
	require_cmd make     || echo make
	require_cmd git      || echo git
	require_cmd autoconf || echo autoconf
	require_cmd autogen  || echo autogen
	require_cmd automake || echo automake

	case "${tree}" in
		debian|gentoo|arch)
				require_cmd pkg-config || echo pkg-config
				;;
		rhel|centos)
				require_cmd pkg-config || echo pkgconfig
				;;
		*)		echo >&2 "Unknown package tree '${tree}'."
				;;
	esac

	# -------------------------------------------------------------------------
	# debugging tools for development

	require_cmd gdb        || echo gdb
	require_cmd valgrind   || echo valgrind
	require_cmd traceroute || echo traceroute
	require_cmd tcpdump    || echo tcpdump
	require_cmd screen     || echo screen

	# -------------------------------------------------------------------------
	# common command line tools

	require_cmd curl || echo curl	# web client
	require_cmd jq   || echo jq		# JSON parsing

	case "${tree}" in
		debian|gentoo|arch)
				require_cmd nc || echo netcat # network swiss army knife
				;;
		rhel|centos)
				require_cmd nc || echo nmap-ncat
				;;
		*)		echo >&2 "Unknown package tree '${tree}'."
				;;
	esac

	# -------------------------------------------------------------------------
	# firehol/fireqos/update-ipsets command line tools

	require_cmd iptables || echo iptables
	require_cmd ipset    || echo ipset
	require_cmd zip      || echo zip	# for update-ipsets
	require_cmd funzip   || echo unzip	# for update-ipsets

	case "${tree}" in
		centos) # FIXME: centos does not have ulogd
				;;

		*)		require_cmd ulogd ulogd2 || echo ulogd
				;;
	esac

	# -------------------------------------------------------------------------
	# netdata libraries

	case "${tree}" in
		debian)		echo zlib1g-dev
				echo uuid-dev
				echo libmnl-dev
				;;

		rhel|centos)
				echo zlib-devel
				echo uuid-devel
				echo libmnl-devel
				;;

		gentoo)		echo sys-libs/zlib
				echo sys-apps/util-linux
				echo net-libs/libmnl
				;;

		arch)		echo zlib
				echo util-linux
				echo libmnl
				;;

		*)		echo >&2 "Unknown package tree '${tree}'."
				;;
	esac

	# -------------------------------------------------------------------------
	# scripting interpreters for netdata plugins

	require_cmd nodejs node js || echo nodejs
	require_cmd python || echo python

	case "${tree}" in
		debian)		# echo python-pip
				echo python-mysqldb
				echo python-yaml
				;;

		rhel)		# echo python-pip
				echo python-mysql
				echo python-yaml
				;;

		centos)		# echo python-pip
				echo MySQL-python
				echo python-yaml
				;;

		gentoo) 	# echo dev-python/pip
				echo dev-python/mysqlclient
				echo dev-python/pyyaml
				;;

		arch)   	# echo python-pip
				echo mysql-python
				echo python-yaml
				;;

		*)		echo >&2 "Unknown package tree '${tree}'."
				;;
	esac

	# -------------------------------------------------------------------------
	# applications needed for the netdata demo sites

	echo nginx
}

DRYRUN=0
run() {

	printf >&2 "%q " "${@}"
	printf >&2 "\n"

	if [ ! "${DRYRUN}" -eq 1 ]
		then
		"${@}"
		return $?
	fi
	return 0
}

install_apt_get() {
	run apt-get install "${@}"
}

install_yum() {
	run yum install "${@}"
}

install_dnf() {
	run dnf install "${@}"
}

install_emerge() {
	run emerge --ask -DNv "${@}"
}

install_pacman() {
	run pacman --needed -S "${@}"
}

cat <<EOF

Distribution   : ${distribution}
Version        : ${version}
Codename       : ${codename}
Package Manager: ${package_installer}
Packages Tree  : ${package_tree}

Please make sure your system is up to date.

The following command will be run:

EOF

DRYRUN=1
${package_installer} $(packages ${package_tree} | sort -u | tr -s '\n'  ' ')
DRYRUN=0
echo >&2

read -p "Press ENTER to run it > "

${package_installer} $(packages ${package_tree} | sort -u) || exit 1

exit 0
