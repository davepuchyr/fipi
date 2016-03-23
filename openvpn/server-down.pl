#!/usr/bin/perl
# $Id: server-down.pl 9 2013-11-30 20:01:35Z dave $

use strict;
use warnings;

`/sbin/ip link set tap0 nomaster`;

