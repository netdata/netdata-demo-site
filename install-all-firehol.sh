#!/bin/bash

for x in iprange firehol netdata
do
    if [ ! -d /usr/src/${x}.git ]
        then
        echo "Downloading (git clone) ${x}..."
        git clone https://github.com/firehol/${x}.git /usr/src/${x}.git || exit 1
    else
        echo "Downloading (git pull) ${x}..."
        cd /usr/src/${x}.git || exit 1
        git pull || exit 1
    fi
done

echo
echo "Building iprange..."
cd /usr/src/iprange.git || exit 1
./autogen.sh || exit 1
./configure --prefix=/usr CFLAGS="-march=native -O3" --disable-man || exit 1
make || exit 1
make install || exit 1

echo
echo "Building firehol..."
cd /usr/src/firehol.git || exit 1
./autogen.sh || exit 1
./configure --prefix=/usr --sysconfdir=/etc --disable-man --disable-doc || exit 1
make || exit 1
make install || exit 1

echo
echo "Building netdata..."
cd /usr/src/netdata.git || exit 1
./netdata-installer.sh --dont-wait

exit $?