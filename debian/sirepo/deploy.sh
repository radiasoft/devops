#!/bin/bash
#
# To run: curl -L https://raw.githubusercontent.com/radiasoft/devops/master/debian/sirepo/deploy.sh | bash
#
set -e
: ${repo:=https://github.com/radiasoft/devops}

#
# Assertions
#
if (( $UID != 0 )); then
    echo 'Must run as root' 1>&2
    exit 1
fi
if ! grep '^8\.' /etc/debian_version >& /dev/null; then
    echo 'Incorrect debian version (not 8.x) or not Debian' 1>&2
    exit 1
fi

prev_dir=$PWD
export TMPDIR=/var/tmp/sirepo_config-$$-$RANDOM
umask 027
mkdir -p "$TMPDIR"
cd "$TMPDIR"

#
# Prerequisites
#
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

#
# Install
#
git clone "$repo"
cd devops/debian/sirepo
. ./install-docker.sh
cd root
rsync -r * /
. /etc/default/bivio-service
. /etc/default/sirepo

#
# Permissions
#
services=( rabbitmq celery-sirepo sirepo )
dirs=( $sirepo_db_dir $sirepo_db_dir/beaker )
for s in "${services[@]}"; do
    chmod u+x /etc/init.d/"$s"
    dirs+=( "$bivio_service_base_dir/$s" )
done
mkdir -p "${dirs[@]}"
chown -R vagrant:vagrant "${dirs[@]}"

#
# Beaker
#
if [[ ! -f $sirepo_beaker_secret ]]; then
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
fi

#
# Nginx
#
rm -f /etc/nginx/sites-enabled/default
x=/var/www/empty
if [[ ! -d $x ]]; then
    mkdir "$x"
    chmod 555 "$x"
fi

#
# Services
#
docker pull "$bivio_service_image:$bivio_service_channel"
systemctl daemon-reload
for s in "${services[@]}" nginx; do
    if ! systemctl status "$s" >& /dev/null; then
        systemctl enable "$s"
    fi
    service "$s" restart
done

cd "$prev_dir"
rm -rf "$TMPDIR"

cat <<'EOF'
To restart services:
for s in ${services[*]}; do service \$s update_and_restart; done
EOF
