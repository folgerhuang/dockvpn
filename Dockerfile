FROM alpine:3.2

MAINTAINER SequenceIQ <info@sequenceiq.com>

#http://wiki.alpinelinux.org/wiki/Setting_up_a_OpenVPN_server
RUN apk update && apk add openvpn openssl curl

RUN mkdir /etc/openvpn/server
RUN mkdir /etc/openvpn/client
RUN mkdir /var/log/openvpn


ADD script/bootstrap.sh /bootstrap.sh

ENTRYPOINT ["/bootstrap.sh"]
