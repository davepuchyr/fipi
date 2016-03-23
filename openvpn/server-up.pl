#!/usr/bin/perl
# $Id: server-up.pl 13 2013-12-15 21:51:01Z dave $
# dmjp

use strict;
use warnings;

# dmjp: HARD-CODED in conjunciton with openvpn-bridge.pl
#`/usr/sbin/ip link set dev eth0 promisc on`;
#`/usr/sbin/ip link set dev tap0 promisc on`;
`/sbin/ip link set tap0 master br0`;

