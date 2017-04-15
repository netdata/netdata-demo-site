#!/usr/bin/env bash

if [ "${UID}" != "0" ]
	then
	sudo "${0}" "${@}"
	exit $?
fi

CONFBASE=${1-/etc/gvpe}


# -----------------------------------------------------------------------------
# generate the local GVPE configuration overrides file

if [ ! -f ${CONFBASE}/local.conf ]
	then
	cat >${CONFBASE}/local.conf <<EOF
# local node GVPE configuration overrides
# this file will not be overwritten by GVPE configuration updates

# local GVPE node settings here
#enable-rawip = no
#enable-icmp = no
#enable-tcp = no
#enable-udp = no
#low-power = yes

# to have certain nodes accessed via another GVPE (router)
#deny-direct = NODENAME

# to select the order GVPE nodes will be used for routing
#node = ROUTER1_NODENAME
#router-priority = 20
#node = ROUTER2_NODENAME
#router-priority = 10

# global GVPE configuration overrides
global

EOF
fi


# -----------------------------------------------------------------------------
# generate the local GVPE if-up script

if [ ! -f ${CONFBASE}/if-up.local ]
    then
    cat >${CONFBASE}/if-up.local <<EOF
#!/usr/bin/env bash

# add here commands to be executed when GVPE starts
# (this script is called from ${CONFBASE}/if-up)


# exit successfuly to avoid breaking GVPE startup
exit 0
EOF
fi
chmod 755 ${CONFBASE}/if-up.local


# -----------------------------------------------------------------------------
# start or restart GVPE

failed=0
if [ -d /etc/systemd/system ]
    then
    cp ${CONFBASE}/gvpe.service /etc/systemd/system/
    systemctl daemon-reload || failed=1
    systemctl restart gvpe || failed=1
fi

if [ ${failed} -eq 1 ]
	then
	failed=0
	killall gvpe || failed=1
fi

if [ ${failed} -eq 1 ]
	then
	echo >&2 "FAILED TO RESTART gvpe"
	exit 1
fi

exit 0
