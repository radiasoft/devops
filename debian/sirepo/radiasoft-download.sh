#!/bin/bash
#
# To run: curl radia.run | sudo bash -s devops/debian/sirepo
#
set -e
: ${sirepo_devops_repo:=https://github.com/radiasoft/devops}

sirepo_assert() {
    if (( $UID != 0 )); then
        echo 'Must run as root' 1>&2
        exit 1
    fi
    if ! grep -s -q '^8\.' /etc/debian_version; then
        echo 'Incorrect debian version (not 8.x) or not Debian' 1>&2
        exit 1
    fi
}

sirepo_beaker() {
    if [[ -f $sirepo_beaker_secret ]]; then
        return
    fi
    # Generate random secret
    echo "Generating: $sirepo_beaker_secret"
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
    git clone "$sirepo_devops_repo"
    cd devops/debian/sirepo
    . ./install-docker.sh
    cd root
    rsync -r * /
    . /etc/default/bivio-service
    . /etc/default/sirepo
}

sirepo_done() {
    cd "$prev_dir"
    rm -rf "$TMPDIR"
    cat <<'EOF'
To restart services:
for s in ${services[*]}; do service \$s update_and_restart; done
EOF
}

sirepo_main() {
    sirepo_assert
    sirepo_tmp
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
    local dirs=( $sirepo_db_dir $sirepo_db_dir/beaker )
    for s in "${sirepo_services[@]}"; do
        chmod u+x /etc/init.d/"$s"
        dirs+=( "$bivio_service_base_dir/$s" )
    done
    mkdir -p "${dirs[@]}"
    chown -R vagrant:vagrant "${dirs[@]}"
}

sirepo_prerequisites() {
    if ! id vagrant >& /dev/null; then
        echo Adding user vagrant
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

sirepo_tmp() {
    prev_dir=$PWD
    export TMPDIR=/var/tmp/sirepo_config-$$-$RANDOM
    umask 027
    mkdir -p "$TMPDIR"
    cd "$TMPDIR"
}

sirepo_main
