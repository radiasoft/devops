#!/bin/bash
#
# To run: curl radia.run | sudo bash -s devops/debian/sirepo
#
#TODO @robnagler Add channel
set -e
: ${sirepo_devops_repo:=https://github.com/radiasoft/devops}

sirepo_assert() {
    if (( $UID != 0 )); then
        install_err 'Must run as root'
    fi
    if ! grep -s -q '^8\.' /etc/debian_version; then
        install_err 'Incorrect debian version (not 8.x) or not Debian'
    fi
}

sirepo_beaker() {
    if [[ -f $sirepo_beaker_secret ]]; then
        return
    fi
    # Generate random secret
    install_msg "Generating: $sirepo_beaker_secret"
    python > "$sirepo_beaker_secret" <<'EOF'
import random, string, sys
y = string.digits + string.letters + string.punctuation
x = ''.join(random.choice(y) for _ in range(64))
sys.stdout.write(x)
EOF
    chgrp vagrant "$sirepo_beaker_secret"
    chmod 640 "$sirepo_beaker_secret"
}

sirepo_copy_files() {
    git clone -q "$sirepo_devops_repo"
    cd devops/debian/sirepo
    git checkout -q "$install_channel"
    . ./install-docker.sh
    cd root
    rsync -r * /
    #TODO @robnagler install_channel is probably master, but
    #  we want it to be alpha or beta. If "master" should be "latest" docker
    . /etc/default/bivio-service
    . /etc/default/sirepo
}

sirepo_done() {
    install_msg <<EOF
To restart services:

for s in ${sirepo_services[*]}; do service \$s update_and_restart; done

EOF
}

sirepo_main() {
    sirepo_assert
    install_tmp_dir
    sirepo_prerequisites
    sirepo_copy_files
    sirepo_permissions
    sirepo_beaker
    sirepo_nginx
    sirepo_start
    sirepo_done
}

sirepo_nginx() {
    rm -f /etc/nginx/sites-enabled/default
    x=/var/www/empty
    if [[ ! -d $x ]]; then
        mkdir "$x"
        chmod 555 "$x"
    fi
}

sirepo_permissions() {
    sirepo_services=( rabbitmq celery-sirepo sirepo )
    local -a dirs
    dirs=( $sirepo_db_dir $sirepo_db_dir/beaker )
    for s in "${sirepo_services[@]}"; do
        chmod u+x /etc/init.d/"$s"
        dirs+=( "$bivio_service_base_dir/$s" )
    done
    mkdir -p "${dirs[@]}"
    chown -R vagrant:vagrant "${dirs[@]}"
}

sirepo_prerequisites() {
    if ! id vagrant >& /dev/null; then
        install_msg 'Adding user vagrant'
        useradd vagrant
    fi
    for f in git nginx; do
        if ! dpkg -s "$f" >& /dev/null; then
            # Work around an nginx install problem
            rm -f /etc/nginx/sites-enabled/sirepo.conf
            apt-get -y install "$f"
        fi
    done
}

sirepo_start() {
    docker pull "$bivio_service_image:$bivio_service_channel"
    systemctl daemon-reload
    for s in "${sirepo_services[@]}" nginx; do
        if ! systemctl status "$s" >& /dev/null; then
            systemctl enable "$s"
        fi
        service "$s" restart
    done
}

sirepo_main
