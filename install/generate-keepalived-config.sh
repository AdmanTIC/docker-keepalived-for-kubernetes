#!/bin/bash
set -eo pipefail

CHK_PORT=${CHK_PORT:-443}

function gen_chk_script() {
  CHK_PROTO=${CHK_PROTO:-https}
  CHK_IP=${CHK_IP?"You must provide CHK_IP"}
  CHK_PORT=${CHK_PORT:-443}
  CHK_URI=${CHK_URI:-/healthz}
  CHK_ALLOWED_HTTP_CODES=${CHK_ALLOWED_HTTP_CODES:-}
  VRRP_ID=${VRRP_ID?"You must provide VRRP_ID"}
  cat - <<EOF
vrrp_script chk_http_$VRRP_ID {
  script "/chk_http.sh '$CHK_PROTO://$CHK_IP:$CHK_PORT$CHK_URI' '$CHK_ALLOWED_HTTP_CODES'"
  interval 5
  fall 2
  rise 2
  timeout 5
}

EOF
}

function gen_vrrp_instance() {
  VRRP_ID=${VRRP_ID?"You must provide VRRP_ID"}
  VRRP_IF=${VRRP_IF?"You must provide VRRP_IF"}
  VRRP_PASS=${VRRP_PASS?"You must provide VRRP_PASS"}
  VRRP_SELF_IP=${VRRP_SELF_IP?"You must provide VRRP_SELF_IP"}
  VRRP_PEERS=($(get_my_peers $VRRP_SELF_IP))
  VRRP_PRIO=$(( ${#VRRP_PEER_GROUPS} - $(grep -ob $VRRP_SELF_IP <<<$VRRP_PEER_GROUPS | cut -d: -f1) ))
  cat - <<EOF
vrrp_instance VI_$VRRP_ID {
  state BACKUP
  interface $VRRP_IF
  virtual_router_id $VRRP_ID
  priority ${VRRP_PRIO:-150}
  advert_int 5
  authentication {
    auth_type PASS
    auth_pass "$VRRP_PASS"
  }

  unicast_src_ip $VRRP_SELF_IP
  unicast_peer {
EOF
  for PEER in ${VRRP_PEERS[@]} ; do
    if [ "$PEER" != "$VRRP_SELF_IP" ] ; then
      echo "    $PEER"
    fi
  done
  echo "  }"

  if [ -n "$(get_my_vips)" ] ; then
    cat - <<EOF
  virtual_ipaddress {
EOF
    for VIP in $(get_my_vips) ; do
      echo "    $VIP"
    done
    cat - <<EOF
  }
EOF
  fi

  if [ -n "$(get_my_gateways)" ] && [ -n "$(get_my_vips)" ] ; then
    cat - <<EOF
  virtual_routes {
EOF
    for VIP in $(get_my_vips) ; do
      for GW in $(get_my_gateways) ; do
        echo "    src ${VIP/\/*/} to 0.0.0.0/0 via $GW dev $VRRP_IF"
      done
    done
    cat - <<EOF
  }
EOF
  fi

  CHK_IP=$VRRP_SELF_IP
  cat - <<EOF
  track_script {
    chk_http_$VRRP_ID
  }
}

EOF
}

function gen_vrrp_sync_group() {
  cat - <<EOF
vrrp_sync_group VG {
  group {
EOF
  for ID in ${VRRP_IDS[@]} ; do echo "    VI_$ID" ; done
  cat - <<EOF
  }
}

EOF
}

function gen_global_defs() {
  cat - <<EOF
global_defs {
  vrrp_check_unicast_src
}

EOF
}

function get_managed_ips() {
  ip a | grep -Po "\b($(grep -Po '[^|]+' <<<"$VRRP_PEER_GROUPS" | cut -d';' -f1 | cut -d',' -f1 | xargs | tr ' ' '|'))\b"
  return 0
}

function get_interface_of_ip() {
  ifconfig | grep -P " inet addr:$1" -B 1 | grep -Po "^[^ ]+"
}

function get_my_peer_group() {
  echo ${VRRP_PEER_GROUPS[@]} | grep -Po "[^|]*\b${VRRP_SELF_IP/./\.}\b[^|]*" | sort
}

function get_my_peers() {
  get_my_peer_group | grep -Po ".*\b${VRRP_SELF_IP/./\.}\b[^|;,]*" | sort
}

function get_my_vips() {
  get_my_peer_group | grep -Po ";\K((\d+\.){3}\d+(/\d+)?)" | sort
}

function get_my_gateways() {
  get_my_peer_group | grep -Po ",\K((\d+\.){3}\d+(/\d+)?)" | sort
}

if [ -z "$MANAGED_IPS" ] ; then MANAGED_IPS=$(get_managed_ips) ; fi
declare -a MANAGED_IPS=(${MANAGED_IPS[@]})

VRRP_IDS=$(seq 1 ${#MANAGED_IPS[@]})

gen_global_defs

for VRRP_ID in ${VRRP_IDS[@]} ; do
  CHK_IP=${MANAGED_IPS[$(( $VRRP_ID - 1))]}
  gen_chk_script
done

gen_vrrp_sync_group

for VRRP_ID in ${VRRP_IDS[@]} ; do
  VRRP_SELF_IP=${MANAGED_IPS[$(( $VRRP_ID - 1))]}
  VRRP_IF=$(get_interface_of_ip $VRRP_SELF_IP)
  gen_vrrp_instance
done

