#!/bin/bash
set -e

# Render sets $PORT at runtime (commonly 10000). Apache's stock config
# listens on 80, so rewrite both the global Listen directive and the
# vhost to match whatever Render gives us.
PORT="${PORT:-80}"

sed -i "s/Listen 80/Listen ${PORT}/" /etc/apache2/ports.conf
sed -i "s/<VirtualHost \*:80>/<VirtualHost *:${PORT}>/" /etc/apache2/sites-available/000-default.conf

exec "$@"
