#!/bin/sh

: ${EXTERNAL_IP_ADDRESS:?"Please set EXTERNAL_IP_ADDRESS variable"}
: ${EXTERNAL_NETWORK_INTERFACE:=eth0}
: ${ROUTE_IP_PREFIX:=10.0.0.0}
: ${ROUTE_NETMASK:=255.255.0.0}
: ${OPENVPN_PORT:=443}
: ${DEBUG:=1}

OPENVPN_SERVER_DIR=/etc/openvpn/server
OPENVPN_CLIENT_DIR=/etc/openvpn/client
OPENVPN_LOG=/var/log/openvpn/tcp${OPENVPN_PORT}.log

debug() {
  [[ "$DEBUG" ]] && echo "[DEBUG] $(date) $*"
}

error() {
  echo "[ERROR] $(date) $*"
}

openvpn_server() {

  IP_ADDRESS=$(ip addr show ${EXTERNAL_NETWORK_INTERFACE} | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
  debug "IP address of ${EXTERNAL_NETWORK_INTERFACE} is ${IP_ADDRESS}"

  cd ${OPENVPN_SERVER_DIR}

  [ -f dh.pem ] ||
      openssl dhparam -out dh.pem 1024
  [ -f key.pem ] ||
      openssl genrsa -out key.pem 2048
  chmod 600 key.pem
  [ -f csr.pem ] ||
      openssl req -new -key key.pem -out csr.pem -subj /CN=OpenVPN/
  [ -f cert.pem ] ||
      openssl x509 -req -in csr.pem -out cert.pem -signkey key.pem -days 24855

  cat > tcp${OPENVPN_PORT}.conf <<EOF
server 192.168.255.0 255.255.255.128
verb 3
duplicate-cn
key ${OPENVPN_SERVER_DIR}/key.pem
ca ${OPENVPN_SERVER_DIR}/cert.pem
cert ${OPENVPN_SERVER_DIR}/cert.pem
dh ${OPENVPN_SERVER_DIR}/dh.pem
keepalive 10 60
persist-key
persist-tun
push "dhcp-option DNS ${IP_ADDRESS}"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DOMAIN service.consul node.dc1.consul"

proto tcp-server
port ${OPENVPN_PORT}
dev tun${OPENVPN_PORT}
status openvpn-status.log
EOF

  debug "Configure iptables..."
  iptables -t nat -A POSTROUTING -s 192.168.255.0/24 -o ${EXTERNAL_NETWORK_INTERFACE} -j MASQUERADE

}

openvpn_client() {
  cat > client.ovpn <<EOF
client
nobind
dev tun
route ${ROUTE_IP_PREFIX} ${ROUTE_IP_NETMASK}

<key>
`cat ${OPENVPN_SERVER_DIR}/key.pem`
</key>
<cert>
`cat ${OPENVPN_SERVER_DIR}/cert.pem`
</cert>
<ca>
`cat ${OPENVPN_SERVER_DIR}/cert.pem`
</ca>
<dh>
`cat ${OPENVPN_SERVER_DIR}/dh.pem`
</dh>

<connection>
remote ${EXTERNAL_IP_ADDRESS} ${OPENVPN_PORT} tcp-client
</connection>
EOF

}

main() {
  openvpn_server
  openvpn_client
  while true ; do openvpn tcp${OPENVPN_PORT}.conf ; done >> ${OPENVPN_LOG} &
  touch ${OPENVPN_LOG} && tail -F ${OPENVPN_LOG}
}

debug "Start openvpn..."
main
