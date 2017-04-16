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
	local exec=""

	[ "${1}" = "exec" ] && exec="exec"
	${exec} $(dirname "${ME}")/gvpe -c /etc/gvpe -D "$(</etc/gvpe/hostname)"
}

run_forever() {
	while [ 1 ]
	do
		run_command "${@}"
		echo "$(date): EXITED WITH CODE $?"
		sleep 10
	done
}

case "${ACTION}" in
	systemd-start)
		run_command exec "${@}"
		;;

	start)
		screen -dmS gvpe "${ME}" run-forever "${@}"
		exit $?
		;;

	run-forever)
		run_forever "${@}"
		;;

	*)
		echo >&2 "Unknown action '${ACTION}'"
		exit 1
		;;
esac

