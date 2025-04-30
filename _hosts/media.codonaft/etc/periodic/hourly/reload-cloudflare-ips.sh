#!/usr/bin/env sh

update-cloudflare-ips.sh && logger 'received new Cloudflare IPs' && /etc/init.d/local restart | logger
