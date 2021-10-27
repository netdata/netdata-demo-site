#!/bin/sh

run() {
	echo >&2 " "
	echo >&2 "${PWD} > ${@}"
	"${@}"
	ret=$?
	
	if [ "${ret}" = "0" ]
	then
		echo >&2 " - OK - "
	else
		echo >&2 " - FAILED - ${ret} "
	fi
	
	return ${ret}
}

if [ "${1}" != "inside-container" ]
    then
    ME="$(basename "${0}")"
    DIR="$(dirname "${0}")"

    cd "${DIR}" || exit 1
    DIR="$(pwd)"

    echo "ME  : ${ME}"
    echo "DIR : ${DIR}"

    ret=0

    run sudo docker run -a stdin -a stdout -a stderr -i -t \
        -v "${DIR}:/tmp/mapped:rw" alpine:edge \
        /bin/sh "/tmp/mapped/${ME}" inside-container
    ret=$?

    if [ ${ret} -eq 0 ]
        then
        echo "Copying generated binaries to ${DIR}/../sbin.linux/"
        run mv ${DIR}/gvpe ${DIR}/../sbin.linux/
        run mv ${DIR}/gvpectrl ${DIR}/../sbin.linux/
    fi

    exit ${ret}
fi

run apk update || exit 1
run apk add --no-cache \
    bash \
    wget \
    curl \
    ncurses \
    git \
    netcat-openbsd \
    alpine-sdk \
    autoconf \
    automake \
    gcc \
    make \
    libtool \
    pkgconfig \
    util-linux-dev \
    libressl-dev \
    gnutls-dev \
    zlib-dev \
    libmnl-dev \
    libnetfilter_acct-dev \
    cvs \
    ${NULL} || exit 1

if [ ! -d /usr/src ]
    then
    run mkdir -p /usr/src || exit 1
fi
cd /usr/src || exit 1

if [ ! -d gvpe ]
then
    run cvs -z3 -d :pserver:anonymous@cvs.schmorp.de/schmorpforge co gvpe || exit 1
fi

run cd gvpe

if [ ! -d libev ]
then
    run cvs -z3 -d :pserver:anonymous@cvs.schmorp.de/schmorpforge co libev || exit 1
fi

echo > doc/Makefile.am

export AUTOMAKE="automake"
export ACLOCAL="aclocal"
export LDFLAGS="-static"

# lower 15 seconds to 10 seconds for re-connecting
#sed -i "s|^  else if (when < -15)$|  else if (when < -10)|g" src/connection.C || echo >& " --- FAILED TO PATCH CONNECTION.C --- "

run ./autogen.sh \
    --prefix=/ \
    --enable-iftype=native/linux \
    --enable-threads \
    --enable-rsa-length=3072 \
    --enable-hmac-length=12 \
    --enable-max-mtu=9000 \
    --enable-cipher=aes-256 \
    --enable-hmac-digest=ripemd160 \
    --enable-auth-digest=sha512 \
    --enable-static-daemon \
    ${NULL} 

#    --enable-bridging \
#    --enable-rand-length=12 \

run make clean
run make -j8 || exit 1

echo "gvpe linking:"
run ldd src/gvpe
run cp src/gvpe /tmp/mapped/

echo
echo "gvpectrl linking:"
run ldd src/gvpectrl
run cp src/gvpectrl /tmp/mapped/

