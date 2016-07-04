#!/usr/bin/env bash

export PATH="${PATH}:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin"

ME="${0}"

# These options control which packages we are going to install
# They can be pre-set, but also can be controlled with command line options
PACKAGES_NETDATA=${PACKAGES_NETDATA-0}
PACKAGES_NETDATA_NODEJS=${PACKAGES_NETDATA_NODEJS-0}
PACKAGES_NETDATA_PYTHON=${PACKAGES_NETDATA_PYTHON-0}
PACKAGES_NETDATA_PYTHON_MYSQL=${PACKAGES_NETDATA_PYTHON_MYSQL-0}
PACKAGES_DEBUG=${PACKAGES_DEBUG-0}
PACKAGES_IPRANGE=${PACKAGES_IPRANGE-0}
PACKAGES_FIREHOL=${PACKAGES_FIREHOL-0}
PACKAGES_FIREQOS=${PACKAGES_FIREQOS-0}
PACKAGES_UPDATE_IPSETS=${PACKAGES_UPDATE_IPSETS-0}
PACKAGES_NETDATA_DEMO_SITE=${PACKAGES_NETDATA_DEMO_SITE-0}

# Check which package managers are available
lsb_release=$(which lsb_release 2>/dev/null || command lsb_release 2>/dev/null)
emerge=$(which emerge 2>/dev/null || command emerge 2>/dev/null)
apt_get=$(which apt-get 2>/dev/null || command apt-get 2>/dev/null)
yum=$(which yum 2>/dev/null || command yum 2>/dev/null)
dnf=$(which dnf 2>/dev/null || command dnf 2>/dev/null)
pacman=$(which pacman 2>/dev/null || command pacman 2>/dev/null)

# FIXME add
# 1. add zypper (opensuse)
# 2. add rpm (who uses it now?)

distribution=
version=
codename=
package_installer=
package_tree=
detection=
NAME=
ID=
ID_LIKE=
VERSION=
VERSION_ID=

usage() {
	cat <<EOF
OPTIONS:

${ME} [--dont-wait] \\
  [distribution DD [version VV] [codename CN]] [installer IN] [packages]

Supported distributions (DD):

    - arch           (all Arch Linux derivatives)
    - gentoo         (all Gentoo Linux derivatives)
    - debian, ubuntu (all Debian and Ubuntu derivatives)
    - redhat, fedora (all Red Hat and Fedora derivatives)
    - centos         (all CentOS derivatives)

Supported installers (IN):

    - apt-get        all Debian / Ubuntu derivatives
    - yum            all Red Hat / Fedora / CentOS derivatives
    - dnf            newer Red Hat / Fedora
    - emerge         all Gentoo derivatives

Supported packages (you can append many of them):

    - netdata-all    all packages required to install netdata
                     including mysql client, nodejs, python, etc

    - netdata        minimum packages required to install netdata
                     (no mysql client, no nodejs, includes python)

    - nodejs         install nodejs
                     (required for monitoring named and SNMP)

    - python         install python
                     (including python-yaml, for config files parsing)

    - python-mysql   install MySQLdb
                     (for monitoring mysql)

    - firehol-all    packages required for FireHOL, FireQoS, update-ipsets
    - firehol        packages required for FireHOL
    - fireqos        packages required for FireQoS
    - update-ipsets  packages required for update-ipsets

    - demo           packages required for running a netdata demo site
                     (includes nginx and various debugging tools)


If you don't supply the --dont-wait option, the program
will ask you before touching your system.

EOF
}

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
	detection="${file}"
	return 0
}

get_os_release() {
	# Loads the /etc/os-release file
	# Only the required fields are loaded
	#
	# If it manages to load /etc/os-release, it returns 0
	# otherwise it returns 1
	#
	# It searches the ID_LIKE field for a compatible distribution

	local x
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
					detection="/etc/os-release"
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
		detection="/etc/lsb-release"
	fi

	if [ -z "${distribution}" -a ! -z "${lsb_release}" ]
		then
		echo >&2 "Cannot find distribution with /etc/lsb-release"
		echo >&2 "Running command: lsb_release ..."
		eval "declare -A release=( $(lsb_release -a 2>/dev/null | sed -e "s|^\(.*\):[[:space:]]*\(.*\)$|[\1]=\"\2\"|g") )"
		distribution="${release[Distributor ID]}"
		version="${release[Release]}"
		codename="${release[Codename]}"
		detection="lsb_release"
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
		if [ "${REPLY}" = "yum" -a -z "${distribution}" ]
			then
			REPLY=
			while [ -z "${REPLY}" ]
				do
				read -p "yum in centos, rhel or fedora? > "
				case "${REPLY,,}" in
					fedora|rhel)
						distribution="rhel"
						;;
					centos)
						distribution="centos"
						;;
					*)
						echo >&2 "Please enter 'centos', 'fedora' or 'rhel'."
						REPLY=
						;;
				esac
			done
			REPLY="yum"
		fi
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
			detection="user-input"
			return 0
			;;

		dnf)
			[ -z "${dnf}" ] && echo >&2 "${1} is not available." && return 1
			package_installer="install_dnf"
			package_tree="rhel"
			detection="user-input"
			return 0
			;;

		emerge)
			[ -z "${emerge}" ] && echo >&2 "${1} is not available." && return 1
			package_installer="install_emerge"
			package_tree="gentoo"
			detection="user-input"
			return 0
			;;

		pacman)
			[ -z "${pacman}" ] && echo >&2 "${1} is not available." && return 1
			package_installer="install_pacman"
			package_tree="arch"
			detection="user-input"
			return 0
			;;

		yum)
			[ -z "${yum}" ] && echo >&2 "${1} is not available." && return 1
			package_installer="install_yum"
			if [ "${distribution}" = "centos" ]
				then
				package_tree="centos"
			else
				package_tree="rhel"
			fi
			detection="user-input"
			return 0
			;;

		*)
			echo >&2 "Invalid package manager: '${1}'."
			return 1
			;;
	esac
}

require_cmd() {
	# check if any of the commands given as argument
	# are present on this system
	# If any of them is available, it returns 0
	# otherwise 1

	while [ ! -z "${1}" ]
	do
		which "${1}" >/dev/null 2>&1 && return 0
		command "${1}" >/dev/null 2>&1 && return 0
		shift
	done
	return 1
}

packages() {
	# detect the packages we need to install on this system

	local tree="${1}"

	# -------------------------------------------------------------------------
	# basic build environment

	require_cmd git      || echo git
	require_cmd gcc      || echo gcc
	require_cmd make     || echo make
	require_cmd autoconf || echo autoconf
	require_cmd autogen  || echo autogen
	require_cmd automake || echo automake

	# pkg-config
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

	if [ ${PACKAGES_DEBUG} -ne 0 ]
		then
		if [ ${PACKAGES_NETDATA} -ne 0 ]
			then
			require_cmd gdb        || echo gdb
			require_cmd valgrind   || echo valgrind
		fi
		require_cmd traceroute || echo traceroute
		require_cmd tcpdump    || echo tcpdump
		require_cmd screen     || echo screen
	fi

	# -------------------------------------------------------------------------
	# common command line tools

	if [ ${PACKAGES_NETDATA} -ne 0 ]
		then
		require_cmd curl || echo curl	# web client

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
	fi

	# -------------------------------------------------------------------------
	# firehol/fireqos/update-ipsets command line tools

	if [ ${PACKAGES_FIREQOS} -ne 0 ]
		then
		require_cmd ip || echo iproute2
	fi

	if [ ${PACKAGES_FIREHOL} -ne 0 ]
		then
		require_cmd iptables || echo iptables
		require_cmd ipset    || echo ipset
		case "${tree}" in
			centos) echo >&2 "WARNING: CentOS does not have ulogd."
					;;
			*)		require_cmd ulogd ulogd2 || echo ulogd
					;;
		esac
	fi

	if [ ${PACKAGES_UPDATE_IPSETS} -ne 0 ]
		then
		require_cmd ipset    || echo ipset
		require_cmd zip      || echo zip
		require_cmd funzip   || echo unzip
	fi

	# -------------------------------------------------------------------------
	# netdata libraries

	if [ ${PACKAGES_NETDATA} -ne 0 ]
		then
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
	fi

	# -------------------------------------------------------------------------
	# scripting interpreters for netdata plugins

	if [ ${PACKAGES_NETDATA_NODEJS} -ne 0 ]
		then
		require_cmd nodejs node js || echo nodejs
	fi

	if [ ${PACKAGES_NETDATA_PYTHON} -ne 0 ]
		then
		require_cmd python || echo python

		case "${tree}" in
			debian|rhel|centos|arch)
					# echo python-pip
					echo python-yaml
					;;

			gentoo) 	# echo dev-python/pip
					echo dev-python/pyyaml
					;;

			*)		echo >&2 "Unknown package tree '${tree}'."
					;;
		esac

		if [ ${PACKAGES_NETDATA_PYTHON_MYSQL} -ne 0 ]
			then
			# nice! everyone has given its own name!
			case "${tree}" in
				debian)		echo python-mysqldb
						;;

				rhel)		echo python-mysql
						;;

				centos)		echo MySQL-python
						;;

				gentoo) 	echo dev-python/mysqlclient
						;;

				arch)   	echo mysql-python
						;;

				*)		echo >&2 "Unknown package tree '${tree}'."
						;;
			esac
		fi
	fi

	# -------------------------------------------------------------------------
	# applications needed for the netdata demo sites

	if [ ${PACKAGES_NETDATA_DEMO_SITE} -ne 0 ]
		then
		require_cmd jq   || echo jq		# JSON parsing
		require_cmd nginx || echo nginx
	fi
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

if [ -z "${1}" ]
	then
	usage
	exit 1
fi

# parse command line arguments
DONT_WAIT=0
while [ ! -z "${1}" ]
do
	case "${1}" in
		distribution)
			distribution="${2}"
			shift
			;;

		version)
			version="${2}"
			shift
			;;

		codename)
			codename="${2}"
			shift
			;;

		installer)
			check_package_manager "${2}" || exit 1
			shift
			;;
			
		dont-wait|--dont-wait)
			DONT_WAIT=1
			;;

		netdata-all)
			PACKAGES_NETDATA=1
			PACKAGES_NETDATA_NODEJS=1
			PACKAGES_NETDATA_PYTHON=1
			PACKAGES_NETDATA_PYTHON_MYSQL=1
			;;

		netdata)
			PACKAGES_NETDATA=1
			PACKAGES_NETDATA_PYTHON=1
			;;

		python|python-yaml|yaml-python|pyyaml|netdata-python)
			PACKAGES_NETDATA_PYTHON=1
			;;

		python-mysql|mysql-python|mysqldb|netdata-mysql)
			PACKAGES_NETDATA_PYTHON=1
			PACKAGES_NETDATA_PYTHON_MYSQL=1
			;;

		nodejs|netdata-nodejs)
			PACKAGES_NETDATA_NODEJS=1
			;;

		firehol-all)
			PACKAGES_IPRANGE=1
			PACKAGES_FIREHOL=1
			PACKAGES_FIREQOS=1
			PACKAGES_UPDATE_IPSETS=1
			;;

		firehol)
			PACKAGES_IPRANGE=1
			PACKAGES_FIREHOL=1
			;;

		update-ipsets)
			PACKAGES_IPRANGE=1
			PACKAGES_UPDATE_IPSETS=1
			;;

		demo|all)
			PACKAGES_NETDATA=1
			PACKAGES_NETDATA_NODEJS=1
			PACKAGES_NETDATA_PYTHON=1
			PACKAGES_NETDATA_PYTHON_MYSQL=1
			PACKAGES_DEBUG=1
			PACKAGES_IPRANGE=1
			PACKAGES_FIREHOL=1
			PACKAGES_FIREQOS=1
			PACKAGES_UPDATE_IPSETS=1
			PACKAGES_NETDATA_DEMO_SITE=1
			;;

		help|-h|--help)
			usage
			exit 1
			;;

		*)
			echo >&2 "ERROR: Cannot understand option '${1}'"
			echo >&2 
			usage
			exit 1
			;;
	esac
	shift
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

[ "${detection}" = "/etc/os-release" ] && cat <<EOF

/etc/os-release information:
NAME            : ${NAME}
VERSION         : ${VERSION}
ID              : ${ID}
ID_LIKE         : ${ID_LIKE}
VERSION_ID      : ${VERSION_ID}
EOF

cat <<EOF

We detected these:
Distribution    : ${distribution}
Version         : ${version}
Codename        : ${codename}
Package Manager : ${package_installer}
Packages Tree   : ${package_tree}
Detection Method: ${detection}
EOF

cat <<EOF

Please make sure your system is up to date.

The following command will be run:

EOF

PACKAGES_TO_INSTALL=( $(packages ${package_tree} | sort -u) )

if [ ${#PACKAGES_TO_INSTALL[@]} -gt 0 ]
	then
	DRYRUN=1
	${package_installer} "${PACKAGES_TO_INSTALL[@]}"
	DRYRUN=0
	echo >&2

	if [ ${DONT_WAIT} -eq 0 ]
		then
		read -p "Press ENTER to run it > "
	fi

	${package_installer} "${PACKAGES_TO_INSTALL[@]}" || exit 1
else
	echo >&2 "All required packages are already installed"
fi

exit 0
