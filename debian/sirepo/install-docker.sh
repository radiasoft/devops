#!/bin/bash
#
# Install docker with devicemapper
#
set -e

sirepo_docker_check() {
    # Assume devicemapper is the only drive we'll use. Not
    # technically correct, but good enough for now.
    if sirepo_docker_devicemapper; then
       return 0
    fi
    if docker info 2>&1 | grep -q -s 'Storage Driver: aufs'; then
        cat <<EOF 1>&2
Cannot use aufs driver. Need to reinstall docker. Please run:
systemctl stop docker
systemctl disable docker
apt-get -y purge docker-engine
rm -rf /var/lib/docker

Then restart this program.
EOF
        exit 1
    fi
    return 1
}

sirepo_docker_devicemapper() {
    if docker info 2>&1 | grep -q -s 'Storage Driver: devicemapper'; then
        return 0
    fi
    return 1
}

sirepo_docker_empty() {
    if [[ $sirepo_docker_installed || ! -f /var/lib/docker ]]; then
        return
    fi
    if ! systemctl status docker >& /dev/null; then
        systemctl enable docker || true
        systemctl start docker || true
    fi
    if docker images 2>/dev/null | grep -v -s -q ^REPOSITORY; then
        cat <<'EOF'
Cannot use aufs driver. Need to reconfigure docker. Please run:
systemctl stop docker
systemctl disable docker
rm -rf /var/lib/docker

Then restart this program.
EOF
        exit 1
    fi
}

sirepo_docker_install() {
    if dpkg -s docker-engine >& /dev/null; then
        return
    fi
    apt-get -y purge 'lxc-docker*' || true
    apt-get -y purge 'docker.io*' || true
    apt-get -y update
    apt-get -y install apt-transport-https ca-certificates || true
    apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D || true
    echo 'deb https://apt.dockerproject.org/repo debian-wheezy main' > /etc/apt/sources.list.d/docker.list
    apt-get -y update
    apt-cache policy docker-engine
    apt-get -y update
    apt-get -y install docker-engine
    sirepo_docker_installed=1
}

sirepo_docker_main() {
    sirepo_docker_check
    if sirepo_docker_devicemapper; then
        return 0
    fi
    sirepo_docker_install
    sirepo_docker_empty
    sirepo_docker_reinstall
    if ! sirepo_docker_devicemapper; then
        echo 'Something went wrong with the upgrade to devicemapper.'
    fi
}

sirepo_docker_reinstall() {
    systemctl stop docker || true
    systemctl disable docker || true
    rm -rf /var/lib/docker

    x=/etc/systemd/system/docker.service
    perl -p -e '/^ExecStart=/ && s/$/ -s devicemapper/' \
         /lib/systemd/system/docker.service > "$x"
    systemctl enable docker
    systemctl start docker || journalctl -xn && false
}

sirepo_docker_main
