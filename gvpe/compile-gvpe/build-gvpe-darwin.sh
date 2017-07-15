#!/usr/bin/env bash

brew install openssl || exit 1
brew install cvs || exit 1

[ -f gpve.old ] && rm -rf gvpe.old
[ -f gpve ] && mv -f gvpe gvpe.old

cvs -z3 -d :pserver:anonymous@cvs.schmorp.de/schmorpforge co gvpe || exit 1
cd gvpe || exit 1
cvs -z3 -d :pserver:anonymous@cvs.schmorp.de/schmorpforge co libev || exit 1

export LDFLAGS="-L/usr/local/opt/openssl/lib"
export CPPFLAGS="-I/usr/local/opt/openssl/include"
export PKG_CONFIG_PATH="/usr/local/opt/openssl/lib/pkgconfig"

echo > doc/Makefile.am

export AUTOMAKE="automake"
export ACLOCAL="aclocal"
#export LDFLAGS="-static"

./autogen.sh \
    --prefix=/ \
    --enable-iftype=native/darwin \
    --enable-threads \
    --enable-bridging \
    --enable-rsa-length=3072 \
    --enable-hmac-length=12 \
    --enable-max-mtu=9000 \
    --enable-cipher=aes-256 \
    --enable-hmac-digest=ripemd160 \
    --enable-auth-digest=sha512 \
    --enable-rand-length=12 \
    ${NULL} || exit 1

make clean
make -j2 || exit 1

echo "ALL DONE"
echo "You need these 2 files - openssl needs to be installed to run them"
ls -l $(pwd)/src/gvpe $(pwd)/src/gvpectrl
