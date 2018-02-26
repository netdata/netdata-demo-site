#!/bin/bash

for x in $(ls /var/lib/lxc)
do
	case "${x}" in
		arch*)
			echo "${x}: pacman -Syu"
			lxc-attach -n "${x}" -- /bin/sh -c 'yes | pacman -Syu'
			;;

		alpine*)
			echo "${x}: apk update"
			lxc-attach -n "${x}" -- /bin/sh -c 'apk update && apk upgrade'
			;;

		centos*)
			echo "${x}: yum -y update"
			lxc-attach -n "${x}" -- /bin/sh -c 'yum -y update && yum -y upgrade'
			;;

		fedora*)
			echo "${x}: dnf -y distro-sync --refresh"
			lxc-attach -n "${x}" -- /bin/sh -c 'dnf -y distro-sync --refresh'
			;;

		debian*|ubuntu*)
			echo "${x}: apt-get update && apt-get -yq dist-upgrade"
			lxc-attach -n "${x}" -- /bin/sh -c 'apt-get -y update && apt-get -y dist-upgrade'
			;;

		gentoo*)
			echo "${x}: emerge -uDNv world"
			lxc-attach -n "${x}" -- /bin/sh -c 'emerge --sync && emerge -uDNv world'
			;;

		*suse*)
			echo "${x}: zypper refresh && zypper update"
			lxc-attach -n "${x}" -- /bin/sh -c 'zypper --non-interactive refresh && zypper --non-interactive update'
			;;

		*)
			echo "${x}: unknown"
			;;
	esac
done

