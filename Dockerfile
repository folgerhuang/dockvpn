FROM alpine:3.2

MAINTAINER SequenceIQ <info@sequenceiq.com>

#http://wiki.alpinelinux.org/wiki/Setting_up_a_OpenVPN_server
RUN apk update && apk add openvpn openssl curl

RUN mkdir /etc/openvpn/certs

VOLUME /etc/openvpn/certs

ADD script/bootstrap.sh /bootstrap.sh

ENTRYPOINT ["/bootstrap.sh"]
