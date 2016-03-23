#!/usr/bin/perl
# $Id: openvpn-bridge.pl 12 2013-12-15 20:57:28Z dave $
# dmjp

use strict;
use warnings;

usage() if ( scalar( @ARGV ) != 3 );
usage( "'$ARGV[0]' can only be either 'start' or 'stop'" ) if ( $ARGV[0] !~ m/(start)|(stop)/i );
usage( "'$ARGV[1]' can only be either 'client' or 'server'" ) if ( $ARGV[1] !~ m/(client)|(server)/i );
usage() if ( !length( $ARGV[2] ) );

my $br = $ARGV[1] =~ m|server|i ? 'br0' : 'br1';
my %conf = %{+ vpnconfig( $ARGV[1] ) };
my %eth = %{+ ifconfig( $ARGV[2] ) };

usage( "no 'dev' in /etc/openvpn/$ARGV[1].conf" ) if ( !exists( $conf{dev} ) );

my %actions = (
   start => \&start,
   stop => \&stop
);

$actions{$ARGV[0]}->();

exit print "done\n";


sub do_or_die {
   my $cmd = shift;
   print "$cmd\n";
   my $out = `$cmd`;
   die "failed to '$cmd'; out == '$out'" if ( $? >> 8 );
   
   return $out;
}


sub start {
   my $cmd = "openvpn --mktun --dev $conf{dev}";
   my $out = do_or_die( $cmd );
   die "failed to '$cmd'; out == '$out'" if ( $out !~ m|TUN/TAP device $conf{dev} opened| );
   
   my %tap = %{+ ifconfig( $conf{dev} ) };

   do_or_die( "ip link set dev $tap{iface} promisc on" );
   do_or_die( "ip link set dev $eth{iface} promisc on" );
   do_or_die( "ip link add $br type bridge" );
   do_or_die( "ip link set $eth{iface} master $br" );
   do_or_die( "ip addr del $eth{addr}/$eth{netmask} dev $eth{iface}" );
   do_or_die( "ip addr add $eth{addr}/$eth{netmask} broadcast $eth{broadcast} dev $br" );
   do_or_die( "ip link set $br up" );
   do_or_die( "ip route add default via $eth{gateway}" );
}


sub stop {
   my %tap = %{+ ifconfig( $conf{dev} ) };
   my %br = %{+ ifconfig( $br ) };

   do_or_die( "ip link set $eth{iface} nomaster" );
   do_or_die( "ip link delete $br" );
   do_or_die( "ip addr add $br{addr}/$br{netmask} broadcast $br{broadcast} dev $eth{iface}" );
   do_or_die( "ip route add default via $br{gateway}" );
   
   my $cmd = "openvpn --rmtun --dev $conf{dev}";
   my $out = do_or_die( $cmd );
   die "failed to '$cmd'; out == '$out'" if ( $out !~ m|TUN/TAP device $conf{dev} opened| ); # yes, rmtun returns opened
}


sub ifconfig {
   my $iface = shift;
   my %ifconfig;
   my @lines = split( /\n/, `ip addr show $iface` );
   my $reIP = '\d+\.\d+\.\d+\.\d+';
   
   foreach my $line ( @lines ) {
      #print "$line\n";
      if ( $line =~ m|\d+: (.*?): <.* state (\S+) | ) {
         $ifconfig{iface} = $1;
         $ifconfig{state} = $2;
      } elsif ( $line =~ m|inet ($reIP)/(\d+) brd ($reIP) scope (.*?) | ) {
         my ( $addr, $netmask, $broadcast, $scope ) = ( $1, $2, $3, $4 );
         $ifconfig{addr} = $addr; 
         $ifconfig{netmask} = $netmask; 
         $ifconfig{broadcast} = $broadcast; 
         $ifconfig{scope} = $scope;
      }
   }
   
   usage( "did ip on '$iface' but got '$ifconfig{iface}' as an echo" ) if ( $iface ne $ifconfig{iface} );
   
   @lines = split( /\n/, `ip route` );
   
   foreach my $line ( @lines ) {
      #print "$line\n";
      if ( $line =~ m|default via ($reIP)| ) {
         $ifconfig{gateway} = $1;
         last;
      }
   }
   
   return \%ifconfig;
}


sub vpnconfig {
   my $role = shift;
   my $file = "/etc/openvpn/$role.conf";
   local $/;
   open( IN, $file ) or die "couldn't open $file: $!\n";
   binmode( IN, ':utf8' );
   my $conf = <IN>;
   close( IN ) or die "couldn't close $file: $!";
   $conf =~ s|[;#].*\n||g;

   #my ( $proto ) = $conf =~ m|proto\s+(\S+)|gi; 
   my ( $dev ) = $conf =~ m|dev\s+(\S+)|gi;
   
   #usage( "proto cannot be defined in $file" ) if ( defined( $proto ) ); 
   
   $conf{dev} = $dev;
   
   return \%conf;
}


sub usage {
   my $msg = shift;
   
   if ( defined( $msg ) ) {
      $msg = "message: $msg\n";
   } else {
      $msg = '';
   }
   
   exit print <<EOS;
${msg}usage: $0 start|stop client|server iface

Creates/Deletes a bridge with interface iface and the device in the openvpn client/service config file.
iface must be up and available for manipulation with command ip. 
OpenVPN config files must be in /etc/openvpn and NOT specify proto; proto must be specified as an openvpn commandline arg.
EOS
}

__DATA__
as of 2013.11.23 on fios

start:

openvpn --mktun --dev tap0
ip link set dev p1p1 promisc on
ip link set dev tap0 promisc on
ip link add br0 type bridge
ip link set p1p1 master br0
ip link set tap0 master br0
ip addr del 192.168.1.8/24 dev p1p1
ip addr add 192.168.1.8/24 broadcast 192.168.1.255 dev br0
ip link set br0 up
ip route add default via 192.168.1.1

stop:
ip link set p1p1 nomaster
ip link set tap0 nomaster
ip link delete br0
ip addr add 192.168.1.8/24 broadcast 192.168.1.255 dev p1p1
ip route add default via 192.168.1.1
openvpn --rmtun --dev tap0

