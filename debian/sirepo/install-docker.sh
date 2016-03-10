#!/bin/bash
apt-get -y purge 'lxc-docker*' || true
apt-get -y purge 'docker.io*' || true
apt-get -y update
apt-get -y install apt-transport-https ca-certificates
apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo 'deb https://apt.dockerproject.org/repo debian-wheezy main' > /etc/apt/sources.list.d/docker.list
apt-get -y update
apt-cache policy docker-engine
apt-get -y update
apt-get -y install docker-engine
systemctl enable docker
service docker start
