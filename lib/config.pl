#!/usr/bin/perl
# Config file for switch management

our %conf = 
(
	"logfile"            => "test.log",
  "switchpw"           => "W2w1cD0mIliG!",
	"m_darwin_serial"    => "tty*usb*", #this has changed
	"m_linux_serial"     => "ttyUSB*",
	"m_darwin_usb"       => "tty*usb*",
	"m_linux_usb"        => "tty*ACM*",
	"trunk_vlan"         => 92,
# defaults for the management vlan
	"mgmt_netmask"       => { "174" => "255.255.254.0",
	                          "92"  => "255.255.252.0"
	                        },
	"mgmt_gw"            => { "174"  => "130.18.174.1",
	                          "92"   => "130.18.92.1"
	                        },
	"mgmt_broadcast"     => { "92"   => "130.18.95.255",
	                          "174"  => "130.18.175.255"
	                        },
	"new_mgmt_netmask"   => "255.255.0.0",
	"new_mgmt_gw"        => "10.92.0.1",
	"new_mgmt_broadcast" => "10.92.255.255",
# mysql settings         
	"mysql_db_cable"     => "cabledb:host=whiteoak.its.msstate.edu",
	"mysql_db_netdb"     => "netdb:host=whiteoak.its.msstate.edu",
  "mysql_db_SNDB"      => "SNDB:host=whiteoak.its.msstate.edu",
	"mysql_user"         => "network",
	"mysql_pass"         => "H2ob\@212"
);
