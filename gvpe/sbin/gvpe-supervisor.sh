#!/usr/bin/env bash

ME="${0}"
ACTION="${1}"
shift

os=$(uname -s)

if [ "${os}" = "Linux" ]
	then
	:
elif [ "${os}" = "FreeBSD" ]
	then
	kldload if_tap
fi

run_command() {
	$(dirname "${ME}")/gvpe -c /etc/gvpe -D "${@}"
}

case "${ACTION}" in
	start)
		screen -dmS gvpe "${ME}" run-forever "${@}"
		exit $?
		;;

	run-forever)
		while [ 1 ]
		do
			run_command "${@}"
			echo "$(date): EXITED WITH CODE $?"
			sleep 10
		done
		;;

	*)
		echo >&2 "Unknown action '${ACTION}'"
		exit 1
		;;
esac

