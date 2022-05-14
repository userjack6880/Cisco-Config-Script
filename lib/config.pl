#!/usr/bin/perl
# Config file for switch management

our %conf = 
(
	"logfile"            => "test.log",
    "switchpw"           => "password",
	"m_darwin_serial"    => "tty*usb*", #this has changed
	"m_linux_serial"     => "ttyUSB*",
	"m_darwin_usb"       => "tty*usb*",
	"m_linux_usb"        => "tty*ACM*",
	"trunk_vlan"         => 92,
# defaults for the management vlan
	"mgmt_netmask"       => { "174" => "255.255.255.0",
	                          "92"  => "255.255.255.0"
	                        },
	"mgmt_gw"            => { "174"  => "192.168.1.1",
	                          "92"   => "192.168.2.1"
	                        },
	"mgmt_broadcast"     => { "92"   => "192.168.1.255",
	                          "174"  => "192.168.1.255"
	                        },
	"new_mgmt_netmask"   => "255.255.255.0",
	"new_mgmt_gw"        => "192.168.1.1",
	"new_mgmt_broadcast" => "192.168.1.255",
# mysql settings         
	"mysql_db_cable"     => "cabledb:host=",
	"mysql_db_netdb"     => "netdb:host=",
    "mysql_db_SNDB"      => "SNDB:host=",
	"mysql_user"         => "",
	"mysql_pass"         => ""
);
