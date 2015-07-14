#!/bin/sh

IP_ADDRESS=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)

cd /etc/openvpn/certs

[ -f dh.pem ] ||
    openssl dhparam -out dh.pem 1024
[ -f key.pem ] ||
    openssl genrsa -out key.pem 2048
chmod 600 key.pem
[ -f csr.pem ] ||
    openssl req -new -key key.pem -out csr.pem -subj /CN=OpenVPN/
[ -f cert.pem ] ||
    openssl x509 -req -in csr.pem -out cert.pem -signkey key.pem -days 24855

[ -f tcp443.conf ] || cat > tcp443.conf <<EOF
server 192.168.255.0 255.255.255.128
verb 3
duplicate-cn
key /etc/openvpn/certs/key.pem
ca /etc/openvpn/certs/cert.pem
cert /etc/openvpn/certs/cert.pem
dh /etc/openvpn/certs/dh.pem
keepalive 10 60
persist-key
persist-tun
push "dhcp-option DNS ${IP_ADDRESS}"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"

proto tcp-server
port 443
dev tun443
status openvpn-status-443.log
EOF

MY_IP_ADDR=$(curl -s http://myip.enix.org/REMOTE_ADDR)
[ "$MY_IP_ADDR" ] || {
    echo "Sorry, I could not figure out my public IP address."
    echo "(I use http://myip.enix.org/REMOTE_ADDR/ for that purpose.)"
    exit 1
}

[ -f client.ovpn ] || cat > client.ovpn <<EOF
client
nobind
dev tun
route 10.0.0.0 255.255.0.0

<key>
`cat /etc/openvpn/certs/key.pem`
</key>
<cert>
`cat /etc/openvpn/certs/cert.pem`
</cert>
<ca>
`cat /etc/openvpn/certs/cert.pem`
</ca>
<dh>
`cat /etc/openvpn/certs/dh.pem`
</dh>

<connection>
remote $MY_IP_ADDR 443 tcp-client
</connection>
EOF


iptables -t nat -A POSTROUTING -s 192.168.255.0/24 -o eth0 -j MASQUERADE

touch tcp443.log
while true ; do openvpn tcp443.conf ; done >> tcp443.log &
tail -F *.log
