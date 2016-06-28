#!/bin/bash

# for debian 8.5

apt-get update
apt-get dist-upgrade

apt-get install \
	zlib1g-dev \
	uuid-dev \
	libmnl-dev \
	gcc \
	gdb \
	valgrind \
	make \
	cmake \
	git \
	autoconf \
	autogen \
	automake \
	pkg-config \
	traceroute \
	ipset \
	curl \
	nodejs \
	zip \
	unzip \
	jq \
	ulogd \
	tcpdump \
	python-pip \
	python3-pip \
	nginx

exit $?
