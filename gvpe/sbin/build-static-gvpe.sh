#!/bin/sh

if [ "${1}" != "inside-container" ]
    then
    ME="$(basename "${0}")"
    DIR="$(dirname "${0}")"

    cd "${DIR}" || exit 1
    DIR="$(pwd)"

    echo "ME  : ${ME}"
    echo "DIR : ${DIR}"

    sudo docker run -a stdin -a stdout -a stderr -i -t \
        -v "${DIR}:/tmp/mapped:rw" alpine:3.5 \
        /bin/sh "/tmp/mapped/${ME}" inside-container
    exit $?
fi

apk update || exit 1
apk add --no-cache \
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
    openssl-dev \
    gnutls-dev \
    zlib-dev \
    libmnl-dev \
    libnetfilter_acct-dev \
    cvs \
    ${NULL} || exit 1

if [ ! -d /usr/src ]
    then
    mkdir -p /usr/src || exit 1
fi
cd /usr/src || exit 1

if [ ! -d gvpe ]
then
    cvs -z3 -d :pserver:anonymous@cvs.schmorp.de/schmorpforge co gvpe || exit 1
fi

cd gvpe

if [ ! -d libev ]
then
    cvs -z3 -d :pserver:anonymous@cvs.schmorp.de/schmorpforge co libev || exit 1
fi

echo > doc/Makefile.am

export AUTOMAKE="automake"
export ACLOCAL="aclocal"
export LDFLAGS="-static"

./autogen.sh \
    --enable-iftype=native/linux \
    --enable-threads \
    --enable-bridging \
    --enable-rsa-length=3072 \
    --enable-hmac-length=12 \
    --enable-max-mtu=9000 \
    --enable-cipher=aes-256 \
    --enable-hmac-digest=ripemd160 \
    --enable-auth-digest=sha512 \
    --enable-rand-length=12 \
    --enable-static-daemon \
    ${NULL} 

make clean
make -j8 || exit 1

echo "gvpe linking:"
ldd src/gvpe
cp src/gvpe /tmp/mapped/

echo
echo "gvpectrl linking:"
ldd src/gvpectrl
cp src/gvpectrl /tmp/mapped/
