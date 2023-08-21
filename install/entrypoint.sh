#!/bin/bash
set -ex

mkdir -p /etc/keepalived
bash /generate-keepalived-config.sh > /etc/keepalived/keepalived.conf
exec "${@}"
