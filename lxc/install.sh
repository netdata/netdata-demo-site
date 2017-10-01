#!/usr/bin/env bash

# for installing older ubuntu releases:
# apt-get install ubuntu-archive-keyring

base="/var/lib/lxc"
cd "${base}" || exit 1

NULL=

was_ok=()
ok=()
failed=()

#        NAME         TEMPLATE    DISTRO    RELEASE  ARCH
for x in \
        "alpine31     alpine      -         v3.1     amd64" \
        "alpine32     alpine      -         v3.2     amd64" \
        "alpine33     download    alpine    3.3      amd64" \
        "alpine34     download    alpine    3.4      amd64" \
        "alpine35     download    alpine    3.5      amd64" \
        "alpine36     download    alpine    3.6      amd64" \
        "alpineedge   download    alpine    edge     amd64" \
        "arch         download    archlinux current  amd64" \
        "centos6      download    centos    6        amd64" \
        "centos7      download    centos    7        amd64" \
        "cirros       cirros      -         -        amd64" \
        "debian10     download    debian    buster   amd64" \
        "debian8      download    debian    jessie   amd64" \
        "debiansid    download    debian    sid      amd64" \
        "debian9      download    debian    stretch  amd64" \
        "debian7      download    debian    wheezy   amd64" \
        "fedora24     download    fedora    24       amd64" \
        "fedora25     download    fedora    25       amd64" \
        "fedora26     download    fedora    26       amd64" \
        "gentoo       download    gentoo    current  amd64" \
        "opensuse422  download    opensuse  42.2     amd64" \
        "opensuse423  download    opensuse  42.3     amd64" \
        "oracle6      download    oracle    6        amd64" \
        "oracle7      download    oracle    7        amd64" \
        "plamo5       download    plamo     5.x      amd64" \
        "plamo6       download    plamo     6.x      amd64" \
        "ubuntu1204   download    ubuntu    precise  amd64" \
        "ubuntu1404   download    ubuntu    trusty   amd64" \
        "ubuntu1604   download    ubuntu    xenial   amd64" \
        "ubuntu1610   ubuntu      -         yakkety  amd64" \
        "ubuntu1704   download    ubuntu    zesty    amd64" \
        "ubuntu1710   download    ubuntu    artful   amd64" \
        ;
do
#        "ubuntu1510   ubuntu-old  -         wily     amd64" \
#        "ubuntu1504   ubuntu-old  -         vivid    amd64" \
#        "ubuntu1410   ubuntu-old  -         utopic   amd64" \
#        "ubuntu1310   ubuntu-old  -         saucy    amd64" \
#        "ubuntu1304   ubuntu-old  -         raring   amd64" \
#        "ubuntu1210   ubuntu-old  -         quantal  amd64" \
#        "ubuntu1110   ubuntu-old  -         oneiric  amd64" \
#        "ubuntu1104   ubuntu-old  -         natty    amd64" \
#        "ubuntu1010   ubuntu-old  -         maverick amd64" \
#        "ubuntu1004   ubuntu-old  -         lucid    amd64" \

        a=(${x})
        name="${a[0]}"
        template="${a[1]}"
        distro="${a[2]}"
        release="${a[3]}"
        arch="${a[4]}"

        opts=()
        case "${template}" in
                download)
                        opts+=("-d" "${distro}" "-r" "${release}" "--no-validate")
                        ;;

                ubuntu-old)
                        template="ubuntu"
                        opts+=("-r" "${release}" "--mirror" "http:/old-releases.ubuntu.com/ubuntu" "--security-mirror" "http:/old-releases.ubuntu.com/ubuntu")
                        ;;

                *)
                        [ "${release}" != "-" ] && opts+=("-r" "${release}")
                        ;;
        esac
        opts+=("-a" "${arch}")

        if [ -d "${name}" -a ! -d "${name}/rootfs" ]
        	then
        	echo >&2 "Removing incomplete container: ${name}"
        	rm -rf "${name}"
        fi

        if [ ! -d "${name}" ]
                then
                echo
                echo "lxc-create -n ${name} -t ${template} -- ${opts[*]}"
                lxc-create -n "${name}" -t "${template}" -- "${opts[@]}"
                ret=$?
                if [ $ret -eq 0 ]
                	then
                	ok+=("${name}")
                else
                        echo >&2 "FAILED with code $ret"
                	failed+=("${name}")
                fi
        else
        	echo >&2 "Found installed container: ${name}"
        	was_ok+=("${name}")
        fi
done

cat <<EOF

-------------------------------------------------------------------------------

SUMMARY

were installed   : ${was_ok[*]}
installed now    : ${ok[*]}
failed to install: ${failed[*]}

EOF

