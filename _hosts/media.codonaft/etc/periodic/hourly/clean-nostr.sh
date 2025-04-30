#!/usr/bin/env sh

[ -d /var/lib/rnostr ] && sudo -u rnostr rnostr delete --filter '{"kinds":[30078]}' /var/lib/rnostr/data/events
