#!/usr/bin/env bash

sudo pkg install cvs || exit 1

[ -f gpve.old ] && rm -rf gvpe.old
[ -f gpve ] && mv -f gvpe gvpe.old

cvs -z3 -d :pserver:anonymous@cvs.schmorp.de/schmorpforge co gvpe || exit 1
cd gvpe || exit 1
cvs -z3 -d :pserver:anonymous@cvs.schmorp.de/schmorpforge co libev || exit 1

echo > doc/Makefile.am

cat >m4/Makefile.am.in <<"EOF"
## Process this file with automake to produce Makefile.in   -*-Makefile-*-

##m4-files-begin
##m4-files-end

Makefile.am: Makefile.am.in
	rm -f $@ $@t
	#sed -n '1,/^##m4-files-begin/p' $< > $@t
	( echo EXTRA_DIST = README Makefile.am.in; \
	  find . -type f -name '*.m4' -print |sed 's,^\./,,' |sort ) \
	  |fmt | (tr '\012' @; echo) \
	      |sed 's/@$$/%/;s/@/ \\@/g' |tr @% '\012\012' \
	        >> $@t
	#sed -n '/^##m4-files-end/,$$p' $< >> $@t
	chmod a-w $@t
	mv $@t $@
EOF

export AUTOMAKE="automake"
export ACLOCAL="aclocal"
export LDFLAGS="-static"

./autogen.sh \
    --prefix=/ \
    --enable-threads \
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
echo "You need these 2 files - they are statically linked"
ls -l $(pwd)/src/gvpe $(pwd)/src/gvpectrl
