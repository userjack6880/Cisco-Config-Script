#!/usr/bin/perl -w

#
# configSwitch.pl
# script to configure switches
# jeb446
#

require 5.005;
use strict;
use SNMP;

use FindBin qw($Bin);
use lib "$Bin/lib";

use MSUNETHW::Switch;
use MSUNETHW::File;
use MSUNETHW::SerialCom;

use Data::Dumper;

# version number

my $script_version = "3.20.09.01.1";

# Configuration Variables -------------------------------------------------------------------------

our $debug = 0;                     # debug level (default 0)

our %conf;
our %ciscoModels;

my $configfile = "$Bin/lib/config.pl";
do $configfile or die "couldn't read in (do) $configfile\n";

my $cisco_model_file = "$Bin/lib/cisco_models.pl";
do $cisco_model_file or die "couldn't read in (do) $cisco_model_file\n";

require "ttylib.pl";
require "mysql.pl";

my $swconfigpath = "$Bin/cfg/";

my ($connected, $ip, $port, $S) = ("");    #$S is a magic var
my $type = "catalyst";
my $os = $^O;
my $action = "start";          # default action is start
my $interface = "serial";      # default interface is serial
my $confmode = "single";       # default configuration mode is single action
my $treemode = "mst";
my $pipe = "less";             # using less by default because I like it...
my $manualIP = 1;              # welcome to the new world, we're reversing this decision.
my $updateSIP = 0;
my $netid = "";
my $missing_lines = 16;        # acceptable number of missing lines

my $dbUpdate = 0;

# CLI Arguments -----------------------------------------------------------------------------------

if (@ARGV) {
	foreach my $argument (@ARGV) {
		# help
		if (($argument eq "--help") || ($argument eq "-h")) {
			$action = "help";
		}
		# debug
		elsif (($argument eq "--debug") || ($argument eq "-d")) {
			$debug = 3;         # defaults to lowest level debug if user does not specify
		}
		elsif (($argument eq "--reset") || ($argument eq "-r")) {
			$action = 50;
		}
		elsif (($argument eq "--manual") || ($argument eq "-m")) {
			$manualIP = 1;
		}
		# invalid argument
		else {
			$action = "help";
		}
	}
}

# Help Text ---------------------------------------------------------------------------------------

if ($action eq "help") {
	print "(sudo) perl configSwitch.pl [args]\n".
	      "[0-9]\t\tenables desired level of debugging\n".
	      "-d\t--debug\tenables debugging\n".
	      "-h\t--help\tdisplays this help text\n";
	exit;
}

if ($debug > 0) {
	print "using debug level $debug\n";
	print "configSwitch v$script_version\n";
	sleep 2;
}

# Menu Data ---------------------------------------------------------------------------------------

my %main_menu = ( "title"     => "Main Menu",
                  "prompt"    => "",
                  "1"         => "Configure Switch",
                  "2"         => "Restore Switch From File",
#                  "3"         => "Restore Switch From TFTP",
                  "4"         => "Backup Switch To File",
                  "5"         => "Update Cable MGMT Database",
                  "6"         => "Reset Switch To Factory",
                  "7"         => "Show Running Config",
                  "8"         => "Generate RSA Key",
                  "h"         => "Change Hostname",
                  "i"         => "Change Inventory",
                  "int"       => "Change Interface",
                  "c"         => "Configure Script",
                  "q"         => "Quit"
                );

my %main_file_menu = ( "title"  => "Main Menu",
                       "prompt" => "",
                       "1"      => "Configure Switch",
                       "c"      => "Configure Script",
                       "q"      => "Quit"
                     );

my %conf_menu = ( "title"     => "Script Configuration",
                  "prompt"    => "",
                  "1"         => "Debug Level",
                  "2"         => "Set Interface Type",
                  "3"         => "Set Switch Type",
									"4"					=> "Set Spanning Tree Type",
                  "5"         => "Set Pipe Application",
#                  "6"         => "Manual IP Input",
                  "7"         => "Password",
                  "b"         => "Go Back"
                );

my %int_menu  = ( "prompt"    => "Choose Interface",
                  "1"         => "Serial",
                  "2"         => "USB (Warning: unstable)",
#                  "3"         => "Telnet",
#                  "4"         => "Output to File"
                );

my %type_menu = ( "prompt"    => "Choose Switch Type",
                  "1"         => "Cisco Catalyst (Default)"
                );

my %tree_menu = ( "prompt"    => "Chose Spanning Tree Type",
                  "1"         => "MST (Main Campus)",
                  "2"         => "PVST (Meridian)",
                  "3"         => "PVST (Meridian-Rosenbaum)",
                  "4"         => "PVST (Riley Center)",
                  "5"         => "PVST (Jackson Architecture)",
                  "6"         => "PVST (Flowood)",
                  "7"         => "PVST Construction",
                  "8"         => "PVST (MVRDL)"
                );

# Start UX ----------------------------------------------------------------------------------------

MAINLOOP:

while (!($action eq "q")) {

	# always clear the screen when running through the loop
	if ($debug < 1) {
		clear_screen();
	}
	print "MSU Network Services Switch Configuration Script\n\n";
	if ($netid eq "") {
		$netid = prompt("NetID", "text");
		next MAINLOOP;
	}

# Main Menu ---------------------------------------------------------------------------------------

	# if we aren't actively doing something, we need to be at the starting menu
	if ($action eq "start") {
		if ($interface eq "file") {
			$action = menu(%main_file_menu);
		}
		else {
			$action = menu(%main_menu);
		}
		next MAINLOOP;
	}

# Configuration - Connect -------------------------------------------------------------------------

	# let's configure a switch
	if ($action =~ /\d/ || $action eq 'h' || $action eq 'i' || $action eq "int" ) {
		debug("action: $action", 1);
		if ($debug > 1) { sleep 2; }
		$confmode = "new";
		my $fn = "";
		# connect to switch
		if (!$connected) {
			print "Connecting to switch.\n";

			# if simply creating a .cfg file, we can create a different type of thing
			if ($interface eq "file") {
				$S = MSUNETHW::File->new($ip, $debug, $conf{'switchpw'}, $type);
			}
			# create a switch option to work with, and we can start to debug as well
			else {
				$S = MSUNETHW::Switch->new($ip, $debug, $conf{'switchpw'}, $type);
			}

			# and if we're doing serial ports...
			debug("OS is $os", 1);
			if ($interface eq "serial") {
				if ($os eq "darwin") { $port = get_serial_port($conf{'m_darwin_serial'}); }
				elsif ($os eq "linux") { $port = get_serial_port($conf{'m_linux_serial'}); }
			}

			if ($interface eq "usb") {
				print "Warning: USB mode is highly experimental and is not recommended. Seriously. Don't.\n";
				if ($os eq "darwin") { $port = get_serial_port($conf{'m_darwin_usb'}); }
				elsif ($os eq "linux") { $port = get_serial_port($conf{'m_linux_usb'}); }
			}

			if ($interface eq "serial" || $interface eq "usb") {
				# if we can't find a port, we're just gonna have to fail back to main menu
				if (!$port) {
					print "Warning: Could not find tty. Incompatible OS or cable fault.\n";
					sleep 2;
					$action = "start";
					next MAINLOOP;
				}
				# establish the connection
				$connected = $S->connect("serial", $port);
				$S->{'protocol'} = "serial";
				debug("connecting via serial", 1);
			}

			if ($interface eq "file") {
				# no real connection, this is just initializing a file to use, but makes file output an easy drop-in
				# but first, prompt the user for a filename
				$fn = prompt("Where do you want to save the config?", "text");
				$connected = $S->connect($fn);
				if (!$connected) {
					$action = "start";
					next MAINLOOP;
				}
				debug("outputting to file", 1);
			}
		}

		# skip the initial configuration promp
		if ($interface ne "file") {
			my $init_conf = $S->skip_initial_configuration();

			if ($init_conf eq "failed") {
				sleep 2;
				$action = "start";
				next MAINLOOP;
			}

			sleep 2;                     # give it time to finish
			$S->paging_off();
			sleep 2;                     # and still give it some time to reconnect at new speed
		}

# Configuration - Get Switch Information ----------------------------------------------------------

		debug("getting model number", 1);

		my $dhcpvlan;
		my $poe = undef;
		my $num_ports = undef;
		my (%verinfo) = ();
		my $modelnum = "";
		my $serialnum = "";

		if ($interface eq "file") {
			$modelnum = prompt("What is the model number?", "text");
			# uppercase it for the script
			$modelnum = uc $modelnum;
			if ($modelnum =~ /WS\-(C\d+\S+)\-(\d+)(\w+)/) {
				# let's go ahead and do this here, as there's no verinfo stuff to give later
				$S->{'info'}{'model'} = $1;
				$S->debug("model series: ".$S->{'info'}{'model'}, 1);
			}
			$serialnum = "none";
		}
		else {
			%verinfo = $S->get_info();
			$modelnum = (exists $verinfo{'modelnum'}) ? $verinfo{'modelnum'} : 'na';
			$serialnum = (exists $verinfo{'serialnum'}) ? $verinfo{'serialnum'} : 'na';
		}

		debug("model: ".$modelnum, 1);

		# Check to see if model is known (based on type)
		if ($type eq "catalyst") {
			# check for catalyst type switches
			if (exists $ciscoModels{$modelnum}) {
				debug("valid model", 1);
		
				# get even more info
				$num_ports                    = $ciscoModels{$modelnum}{'num_ports'};
				$S->{'info'}{'num_ports'}     = $ciscoModels{$modelnum}{'num_ports'};
				$poe                          = $ciscoModels{$modelnum}{'poe'};
				$S->{'info'}{'poe'}           = $ciscoModels{$modelnum}{'poe'};
				$S->{'info'}{'port_prefix'}   = $ciscoModels{$modelnum}{'port_prefix'};
				$S->{'info'}{'num_uplinks'}   = $ciscoModels{$modelnum}{'num_uplinks'};
				$S->{'info'}{'uplink_pre'}    = $ciscoModels{$modelnum}{'uplink_pre'};
				$S->{'info'}{'copper_trunk'}  = 0;

				# debug stuff
				debug("num_ports: "  .$ciscoModels{$modelnum}{'num_ports'},1);
				debug("port_prefix: ".$ciscoModels{$modelnum}{'port_prefix'},1);
				debug("num_uplinks: ".$ciscoModels{$modelnum}{'num_uplinks'},1);
				debug("uplink_pre:  ".$ciscoModels{$modelnum}{'uplink_pre'},1);
				debug("POE:   "      .$ciscoModels{$modelnum}{'poe'},1);

				# if the switch has uplinks, which it *should*
				if ($S->{'info'}{'num_uplinks'} > 0) {
					# if the uplink prefix is the *same* as the port prefix, just increment by one
					#if ($ciscoModels{$modelnum}{'uplink_pre'} eq $ciscoModels{$modelnum}{'port_prefix'}) {
						$S->debug("uplink prefix and port prefix match - setting increment...\n",1);
						$S->{'info'}{'uplink_start'} = $ciscoModels{$modelnum}{'num_ports'} + 1;
					#}
					#else {
					#	$S->debug("uplink prefix and port prefix do not match - continuing...\n",1);
					#	$S->{'info'}{'uplink_start'} = 1;
					#}
					$S->{'info'}{'uplink_end'} = $S->{'info'}{'uplink_start'} + $S->{'info'}{'num_uplinks'} - 1;
				}
			}
			else {
		  	print "Warning: Model is not known. Update ./lib/cisco_models.pl\n";
				sleep 2;
				$action = "start";
				next MAINLOOP;
			}
		}
		# we shouldn't ever get to this point
		else {
			print "Not known type of switch ($type).\n";
			sleep 2;
			$action = "c";
			next MAINLOOP;
		}

		# change info->model to make the script work right....
		debug("setting model", 1);
		if (exists $verinfo{'model'} && $interface ne "file") {
			$S->{'info'}{'model'} = $verinfo{'model'};
			$S->debug("done.\n",1);
		}
		$S->debug("model series: ".$S->{'info'}{'model'},1);

		if ($debug > 0) {
			sleep 2;
		}

		my $hostname = "";
		my $restorefile = "";

# Script Switch Point -----------------------------------------------------------------------------

		# set to skip to certain parts of the script...
		if ($action eq "2")   { goto RESTORE; }
		if ($action eq "3")   { goto TFTP; }
		if ($action eq "4")   { goto BACKUP; }
		if ($action eq "5")   { goto UPDATE; }
		if ($action eq "6")   { goto RESET; }
		if ($action eq "7")   { goto SHCONFIG; }
		if ($action eq "8")   { goto GENKEY; }
		if ($action eq "h")   { goto HOSTNAME; }
		if ($action eq "i")   { goto INVENTORY; }
		if ($action eq "int") { goto INTERFACE; }
		if ($action eq "50")  { goto RESET; }

# Configuation - User Input -----------------------------------------------------------------------

		CONFIG:

		if ($debug < 1) {
			clear_screen();
		}

		# configuration questions

		print "Configuration\n";
		print $modelnum."\n";
		print $serialnum."\n";

		# ask for general information
		$hostname     = prompt("Hostname \t\t\t\t", "text"); 

		my $location;
		$location     = prompt("Location \t\t\t\t", "text");

		my $ip_address;
		if (!($interface eq 'telnet')) {
			if ($manualIP eq "0") {
				$ip_address = getIP($hostname,$location);
			}
			else {
				$ip_address = prompt("IP Address \t\t\t\t", "ip");
			}
			debug("ip: $ip_address", 1);
		}

		my $inventory = "";
		$inventory    = prompt("Inventory \t\t\t\t", "text");

		# general port settings
		my $dhcpsnoop = "";
		$dhcpsnoop    = prompt("Enable DHCP Snooping? \t\t  ", "bool");

		my %vlan_list;       # we can do some magic where duplicate keys/values don't happen (hacky hacky)
		$vlan_list{92} = 92; # we should always have an uplink VLAN

		if ($dhcpsnoop) {
			$S->{'info'}{'dhcp_snoop'} = 1;
			$dhcpvlan     = prompt("DHCP Snooping VLAN \t\t\t", "int_list");
			$S->{'info'}{'dhcp_snoop_vlan'} = $dhcpvlan;
			$vlan_list{$dhcpvlan} = $dhcpvlan;
		}

		my $vlan = "";
		$vlan         = prompt("Default VLAN \t\t\t\t", "int");

		my $security = "";
		my $dot1q_trunk = "";
		$security     = prompt("Enable Default Port Security? \t  ", "bool");
		$dot1q_trunk  = prompt("Enable dot1q on trunk? \t\t  ", "bool");

		$S->{'info'}{'vlan'} = $vlan;
		$S->{'info'}{'use_security'} = $security;
		$S->{'info'}{'dot1q_trunk'} = $dot1q_trunk;
		$vlan_list{$vlan} = $vlan;

		# additional copper uplinks besides dedicated uplinks
		my $copper_trnk = "";
		$copper_trnk  = prompt("Additional Uplink Ports? \t  ", "bool");

		if ($copper_trnk) {
			$S->{'info'}{'copper_trunk'} = 1;
			my $trnk_range = "";
			my $valid = 0;
			while (!$valid) {
				$trnk_range  = prompt("Port Range (1 - $num_ports) \t\t\t", "text");
				$S->{'info'}{'copper_trunk_range'} = $trnk_range;
				$valid = checkRange($num_ports, $trnk_range);
			}
		}

		if (exists $S->{'info'}{'model'} && !($S->{'info'}{'model'} eq "")) {
			$restorefile = $swconfigpath;
			debug("restorefile model: ".$S->{'info'}{'model'}, 1);
			$restorefile .= lc $S->{'info'}{'model'} . ".cfg";
		}

		# Ten-gig switches can be configured as gig interfaces
		my @trunk_pres = split(/\|/,$S->{'info'}{'uplink_pre'});
		foreach my $prefix (@trunk_pres)
		{
			my $tstart;
			my $tend;

			if ($prefix eq $S->{'info'}{'port_prefix'}) {
				debug("uplink prefix and port prefix match - setting increment...", 1);
				$tstart = $S->{'info'}{'num_ports'} + 1;
				$tend   = $S->{'info'}{'num_ports'} + $S->{'info'}{'num_uplinks'};
			}
			else {
				# such as 2960 where uplink is gi0/1 and ports are fa0
				debug("uplink prefix and port prefix do not match - continuing...", 1);
				$tstart = $S->{'info'}{'uplink_start'};
				$tend   = $S->{'info'}{'uplink_end'};
			}

			my $uplink = $prefix . $tstart . " - " . $tend;
			push @{$S->{'info'}{'uplinks'}},$uplink;
		}

		# ask for additional port configs
		my @addports;
		my $addportnum = 0;

		while (prompt("Add Additional VLANs? \t\t  ", "bool")) {
			debug("adding additional ports to config...", 1);
			my $aports     = "";
			my $valid   = 0;
			while (!$valid) {
				$aports   = prompt("Additional Ports (1 - $num_ports) \t\t", "text");
				$valid    = checkRange($num_ports, $aports);
			}
			my $avlans  = prompt("VLAN \t\t\t\t\t", "text");
			my $asecure = prompt("Enable Port Security? \t\t  ", "bool");
			my $apoe    = 1;

# PULL THIS SECTION OUT TO ALWAYS ENABLE POE
#			if ($poe eq "1") {
#				$apoe  = prompt("Enable POE? \t\t\t  ", "bool");
#				if ($apoe) {
#					my $poe_max    = prompt("Enable 15.4W? \t\t\t  ", "bool");
#					if ($poe_max) { $apoe++; }
#				}
#			}

# PULL THIS SECTION OUT BECAUSE WE DON'T USE THIS ANYMORE
#			my $passthrough = prompt("Passthrough? \t\t\t  ", "bool");
#			my $vlan2 = "";
#			if ($passthrough) {
#				$vlan2 = prompt("Passthrough Vlan \t\t\t", "text");
#				$vlan_list{$vlan2} = $vlan2;
#			}

			my $passthrough = 0;
			my $vlan2 = "";

			$addports[$addportnum] = { 'ports'       => $aports,
			                           'vlan'        => $avlans,
			                           'security'    => $asecure,
			                           'poe'         => $apoe,
			                           'passthrough' => $passthrough,
			                           'vlan2'       => $vlan2
			                         };
			$vlan_list{$avlans} = $avlans;
			$addportnum++;
		}

		# define additional vlans not assigned to ports, but may be used downstream
		while (prompt("Define Additional VLANs? \t  ", "bool")) {
			debug("defining additional vlans...", 1);
			my $avlans = prompt("VLAN \t\t\t\t\t", "text");
			$vlan_list{$avlans} = $avlans;
		}

		my $updatedb = "";
		my $backupconfig = "";
		$backupconfig = "1";

		# ask if cable management should be updated
		if ($interface ne "file") {
			$updatedb = prompt("Update Databases? \t\t  ", "bool");
		}

		# confirm configuration with user
		if ($debug < 1)
		{
			clear_screen();
		}

		print "Please Confirm\n";
		print "---------------------\n";
		print "Hostname: \t\t$hostname\n" .
		      "IP: \t\t\t$ip_address\n" .
		      "Inventory:\t\t$inventory\n" .
		      "Serial: \t\t$serialnum\n" .
		      "Switch Ports:\t\t" .
		                                $S->{'info'}{'port_prefix'} .
		                                "1 - " .
		                                $S->{'info'}{'num_ports'} .
		                                "\n" .
		      "Uplink Ports:\t\t" .
		                                join (", ", @{$S->{'info'}{'uplinks'}}) .
		                                "\n" .
		      "DHCP Snooping:\t\t$dhcpsnoop\n";
		if ($dhcpvlan) {
			print "DHCP Snoop VLAN:\t$dhcpvlan\n";
		}
		print "Default VLAN:\t\t$vlan\n" .
		      "Port Security Default:\t$security\n" .
		      "dot1q:\t\t\t$dot1q_trunk\n" .
		      "Trunk Ports:\t\t" .
		                                $S->{'info'}{'port_prefix'} .
		                                $S->{'info'}{'copper_trunk_range'} .
		                                "\n";
		if ($addportnum > 0) {
			print "-- Additional Vlans --\n";

			foreach my $aportrow (0..@addports-1) {
				print "\tPorts:\t\t" .
				                   $S->{'info'}{'port_prefix'} .
				                   $addports[$aportrow]{'ports'} .
				                   "\n".
				      "\tVLAN:\t\t" .
				                   $addports[$aportrow]{'vlan'} .
				                   "\n".
				      "\tPort Sec: \t" .
				                   $addports[$aportrow]{'security'} .
				                   "\n".
				      "\tPOE: \t\t".
				                   $addports[$aportrow]{'poe'} .
				                   "\n";
				if ($addports[$aportrow]{'passthrough'}) {
					print "\tPassthrough: \t".
					                 $addports[$aportrow]{'passthrough'} .
					                 "\n".
					      "\tVLAN 2: \t".
					                 $addports[$aportrow]{'vlan2'} .
					                 "\n";
				}
				print "------------------------\n";
			}
		}

		if ($updatedb) {
			print "+ Databases will be updated.\n";
		}
		else {
			print "- Databases will not be updated.\n";
		}
		if ($backupconfig) {
			print "+ Configuration will be backed up to $Bin/cfg/hosts/$hostname.cfg \n";
		}
		else {
			print "- Configuration will not be backed up. \n";
		}
		if ($treemode ne "mst") {
			print "PVST Spanning Tree. \n";
		}
		print "------------------------\n";

		if (!(prompt("Conform Correct: ", "bool"))) {
			goto CONFIG;
		}

# Configuration - Restore From File Base/Whole Config ---------------------------------------------

		RESTORE:

		# if we're skipping here, we need to specify a restore file...
		if ($action eq "2") { 
			$restorefile = prompt("Enter filename to restore from", "text");
		}

		print "Restoring switch from file.\n";

		restoreConfig($S,$restorefile);
		debug("completed", 1);

		if ($action eq "2") {
			print "Done Restoring Switch";
			debug("saving config", 1);
			$S->write_mem();
			$action = "start";
			$S->disconnect();
			$connected = 0;
			next MAINLOOP;
		}

		sleep 2;

		# add spanning tree stuff
		$restorefile = $swconfigpath;

		if ($treemode eq "pvstmeridian") {
			$restorefile .= "pvstmeridian.cfg";
		}
		elsif ($treemode eq "pvstrosenbaum") {
			$restorefile .= "pvstrosenbaum.cfg";
		}
		elsif ($treemode eq "pvstriley") {
			$restorefile .= "pvstriley.cfg";
		}
		elsif ($treemode eq "pvstjackson") {
			$restorefile .= "pvstjackson.cfg";
		}
		elsif ($treemode eq "pvstflowood") {
			$restorefile .= "pvstflowood.cfg";
		}
		elsif ($treemode eq "pvstconstruction") {
			$restorefile .= "pvstconstruction.cfg";
		}
		elsif ($treemode eq "pvstmvrdl") {
			$restorefile .= "pvstmvrdl.cfg";
		}
		else {
			$restorefile .= "mst.cfg";
		}

		debug ("configuring spanning tree using $restorefile", 1);
		restoreConfig($S,$restorefile);
		debug ("completed", 1);

		sleep 1;

# Configuration - Define Switch Attributes --------------------------------------------------------

		HOSTNAME:
		if ($action eq 'h') {
			$hostname = prompt("Enter new hostname", "text");
		}
		setHostname($S,$hostname);
		if ($action eq 'h') {
			$S->write_mem();
			$action = "start";
			$S->disconnect();
			$connected = 0;
			next MAINLOOP;
		}
		sleep 1;

		INVENTORY:
		if ($action eq 'i') {
			$inventory = prompt("Enter new inventory", "text");
		}
		setInventory($S,$inventory);
		if ($action eq 'i') {
			$S->write_mem();
			$action = "start";
			$S->disconnect();
			$connected = 0;
			next MAINLOOP;
		}
		sleep 1;
		if (!($interface eq 'telnet')) {
			setIP($S,$ip_address);
			sleep 1;
		}
		if ($dhcpsnoop) {
			setDHCPSnoop($S,$dhcpvlan,0,0);
			sleep 1;
		}

# Configuration - Define Ports --------------------------------------------------------------------

		print "Configuring ports.\n";

		# Configure Default Ports
		debug("configuring default ports...",1);
		if ($debug > 0) {
			sleep 5;
		}
		my $portrange = $S->{'info'}{'port_prefix'} . "1 - " . $S->{'info'}{'num_ports'};
		$S->set_port_vlan($portrange, $S->{'info'}{'vlan'}, $S->{'info'}{'use_security'}, 0, 0, 0);
		$portrange = "";
		debug("done",1);

		INTERFACE:
	# SUBSECTION - Interface-Only-Config ------------------------------------------------------------
		if ($action eq "int") {
			$addportnum = 0;
			$copper_trnk = prompt("Configure Trunk? \t\t  ", "bool");

			# first configure copper trunks
			if ($copper_trnk) {
				$S->{'info'}{'copper_trunk'} = 1;
				my $trnk_range = "";
				my $valid = 0;
				while (!$valid) {
					$trnk_range  = prompt("Port Range (1 - $num_ports) \t\t\t", "text");
					$S->{'info'}{'copper_trunk_range'} = $trnk_range;
					$valid = checkRange($num_ports, $trnk_range);
				}
			}

			# if not copper trunks, we configure a normal port
			
			while (prompt("Modify Additional Ports? \t  ", "bool")) {
				my $aports     = "";
				my $valid   = 0;
				while (!$valid) {
					$aports   = prompt("Additional Ports (1 - $num_ports) \t\t", "text");
					$valid    = checkRange($num_ports, $aports);
				}
				my $avlans  = prompt("VLAN \t\t\t\t\t", "text");
				my $asecure = prompt("Enable Port Security? \t\t  ", "bool");
				my $apoe    = 0;
        if ($poe eq "1") {
					$apoe     = prompt("Enable POE? \t\t\t  ", "bool");
				}
				my $passthrough = prompt("Passthrough? \t\t\t  ", "bool");
				my $vlan2 = "";
				if ($passthrough) {
					$vlan2 = prompt("Passthrough Vlan \t\t\t", "text");
				}
				$addports[$addportnum] = { 'ports'       => $aports,
				                           'vlan'        => $avlans,
				                           'security'    => $asecure,
				                           'poe'         => $apoe,
				                           'passthrough' => $passthrough,
				                           'vlan2'       => $vlan2
				                         };
				$addportnum++;
			}

			# I realize, we need to confirm with the user that they wanna do this or change something

			print "Confirm Ports\n\n";
			if ($copper_trnk) {
			print "Trunk Ports:\t\t" .
            $S->{'info'}{'port_prefix'} .
            $S->{'info'}{'copper_trunk_range'} .
            "\n\n";
			}

			if ($addportnum > 0) {
				print "-- Ports --\n";

				foreach my $aportrow (0..@addports-1) {
					print "\tPorts:\t\t" .
					                   $S->{'info'}{'port_prefix'} .
					                   $addports[$aportrow]{'ports'} .
					                   "\n".
					      "\tVLAN:\t\t" .
					                   $addports[$aportrow]{'vlan'} .
					                   "\n".
					      "\tPort Sec: \t" .
					                   $addports[$aportrow]{'security'} .
					                   "\n".
					      "\tPOE: \t\t".
					                   $addports[$aportrow]{'poe'} .
					                   "\n";
					if ($addports[$aportrow]{'passthrough'}) {
						print "\tPassthrough: \t".
						                 $addports[$aportrow]{'passthrough'} .
						                 "\n".
						      "\tVLAN 2: \t".
						                 $addports[$aportrow]{'vlan2'} .
						                 "\n";
					}
					print "------------------------\n";
				}
			}

			if (!(prompt("Conform Correct: ", "bool"))) {
				goto INTERFACE;
			}

			print "Configuring Ports\n";
		}

		# Configure Additional VLANs
		if ($addportnum > 0) {
			debug("configuring additional ports...",1);
			if ($debug > 0) {
				sleep 5;
			}

			foreach my $aportrow (0..@addports-1) {
				$portrange = $S->{'info'}{'port_prefix'} . $addports[$aportrow]{'ports'};
				if ($action eq "int") { $S->set_port_default($portrange); }
				$S->set_port_vlan($portrange, 
				                  $addports[$aportrow]{'vlan'}, 
				                  $addports[$aportrow]{'security'}, 
				                  $addports[$aportrow]{'poe'},
				                  $addports[$aportrow]{'passthrough'},
				                  $addports[$aportrow]{'vlan2'}
				                 );
				$portrange = "";
			}

			debug("done.",1);
		}

		# Configure Extra Trunk Ports
		if ($S->{'info'}{'copper_trunk'}) {
			debug("configuring extra trunk ports...",1);
			if ($debug > 0) {
				sleep 5;
			}

			if ($action eq "int") { $S->set_port_default($S->{'info'}{'copper_trunk_range'}); }
			$S->set_port_trunk($S->{'info'}{'copper_trunk_range'}, $conf{'trunk_vlan'},1);
			$S->debug("done...\n",2);
		}

		if ($action eq "int") {
			$S->write_mem();
			$action = "start";
			$S->disconnect();
			$connected = 0;
			next MAINLOOP;
		}

		# Trunk Uplink Ports
		if ($S->{'info'}{'num_uplinks'}) {
			debug("configuring uplinks...",1);
			if ($debug > 0) {
				sleep 5;
			}

			foreach $portrange (@{$S->{'info'}{'uplinks'}}) {
				$S->set_port_trunk($portrange, $conf{'trunk_vlan'},0);
				$portrange = "";
			}
			debug("done.",1);
		}

		if ($debug > 0) {
			sleep 5;
		}

		# Generate the VLANs too
		debug("defining vlans...",1);
		if ($debug > 0) {
			sleep 5;
		}

		foreach my $vlan_key (keys %vlan_list) {
			my $vlan_name = getVLAN($vlan_key);

			if ($vlan_name ne '') {
				$S->enable();
				$S->configure("terminal");
				$S->{'interface'}->send("vlan $vlan_key\n");
				$S->{'interface'}->send("name $vlan_name\n");
				$S->endconfigure();
			}
		}

# Configuration - Generate RSA Key ----------------------------------------------------------------

		GENKEY:
		debug("generating rsa key...",1);
		if ($debug > 0) {
			sleep 5;
		}
		$S->gen_key();
		debug("done.",1);
		if ($action eq "8") {
			$S->write_mem();
			$action = "start";
			$S->disconnect();
			$connected = 0;
			next MAINLOOP;
		}

# Configuration - Save Switch Config --------------------------------------------------------------

		# Save the Switch Config
		if ($interface ne "file") {
			debug("saving config...",1);
			$S->write_mem();
			sleep 2;
			$S->{'interface'}->send("\r\r");
			$S->{'interface'}->expect(10,"#",">");
			debug("done.",1);
		}

# Configuration - Backup Config -------------------------------------------------------------------

		BACKUP:
		# backup config to file
		if ($action eq "4") {
			$hostname = prompt("Enter hostname", "text");
		}

		if ($action eq "4" || $backupconfig) {
			print "Backing up config.\n";
			sleep 2; #sometimes we're going WAYYY to fast
			saveConfig($S, "$Bin/cfg/hosts/$hostname.cfg");
		}

# Error Checking (buggy) --------------------------------------------------------------------------

		CHECKS:
		# checks to see if outputted file is big enough

		# generate filename path for switch's config
		my $filename = "$Bin/cfg/hosts/$hostname.cfg";
		my $filesize = -s $filename;

		# generate filename path for base config
		my $basecfg = '';
		if (exists $S->{'info'}{'model'} && !($S->{'info'}{'model'} eq "")) {
			$basecfg = $swconfigpath;
			$basecfg .= lc $S->{'info'}{'model'} . ".cfg";
		}

		# generate filename path for spanning tree
		my $treecfg = $swconfigpath;

		if ($treemode eq "pvstmeridian") {
			$treecfg .= "pvstmeridian.cfg";
		}
		elsif ($treemode eq "pvstrosenbaum") {
			$treecfg .= "pvstrosenbaum.cfg";
		}
		elsif ($treemode eq "pvstriley") {
			$treecfg .= "pvstriley.cfg";
		}
		elsif ($treemode eq "pvstjackson") {
			$treecfg .= "pvstjackson.cfg";
		}
		elsif ($treemode eq "pvstflowood") {
			$treecfg .= "pvstflowood.cfg";
		}
		elsif ($treemode eq "pvstconstruction") {
			$restorefile .= "pvstconstruction.cfg";
		}
		elsif ($treemode eq "pvstmvrdl") {
			$restorefile .= "pvstmvrdl.cfg";
		}
		else {
			$treecfg .= "mst.cfg";
		}

		debug("checking filesize...",1);
		debug("filesize: $filesize",1);
		if ($filesize < 10000) {
			print "Caution! File size: $filesize - too small. Check config. (error check may be buggy)\n";
		}

		sleep 30;

# Update Databases --------------------------------------------------------------------------------

		UPDATE:
		# update database
		if ($action eq "5") {
			$hostname = prompt("Enter hostname:", "text");
		}
		if ($updatedb || ($action eq "5")) {
			print "Updating Cable MGMT Database.\n";
			dbUpdate($S,$hostname);
			update_conf_db($serialnum,$location,$hostname,'',$modelnum,$inventory,$ip_address,$netid,"$Bin/cfg/hosts/$hostname.cfg");
		}

# Reset Switch ------------------------------------------------------------------------------------

		RESET:
		# reset swtich
		if ($action eq "6") {
			print "Resetting switch. Please wait.\n";
			sleep 1;
			$S->write_mem();     # because I don't feel like fixing the reset function right now
			$S->write_erase();
			$S->reset("no");     # don't save on the way out
			print "Switch reset, rebooting. May take a while.\n";
			sleep 5;
			$S->disconnect();
			$connected = 0;
			$action = "start";
			next MAINLOOP;
		}

# Show Running Config -----------------------------------------------------------------------------

		SHCONFIG:
		# show running config
		if ($action eq "7") {
			print "Getting config. Please wait.\n";
			showConfig($S);
			$S->disconnect();
			$connected = 0;
			$action = "start";
			next MAINLOOP;
		}

		print "Setup Done!\n";

# Finished Configuration! -------------------------------------------------------------------------

		$S->disconnect();
		$connected = 0;

		if ($action eq "1" && prompt("Setup Another? (connect next switch now)", "bool")) {
			debug("going for another round", 1);
			sleep 5;
		}
		else {
			debug("going back to menu", 1);
			$action = "start";
		}
	}

# Configuration Menus -----------------------------------------------------------------------------

	# let the user do some script configurations for non-default actions
	if ($action eq "c") {
		print "Debug Level: $debug\n".
		      "Script Version: $script_version\n".
		      "Interface: $interface\n".
		      "Tree Mode: $treemode\n".
		      "Pipe Command: $pipe\n".
					"Manual IP: $manualIP\n";
		$action = menu(%conf_menu);

		debug("$action selected", 1);

		# configure debug level
		if ($action eq "1") {
			print "0 - No Debugging\n".
			      "1 - Script Debug\n".
			      "2 - Serial Debugging To Switch\n".
			      "3 - Serial Debugging From Switch\n";
			$debug = prompt("Enter Debug Level", "int");

			debug("debug level: $debug", 1);

			$action = "c";
			next MAINLOOP;
		}

		# set interface type.
		if ($action eq "2") {
			my $prompt = menu(%int_menu);

			if ($prompt eq "1") { $interface = "serial"; }
			if ($prompt eq "2") { $interface = "usb"; }
			if ($prompt eq "3") { $interface = "telnet"; }
			if ($prompt eq "4") { $interface = "file"; }

			debug("interface set to $interface", 1);

			$action = "c";
			next MAINLOOP;
		}

		# set switch type
		if ($action eq "3") {
			my $prompt = menu(%type_menu);

			if ($prompt eq "1") { $type = "catalyst"; }

			debug("type set to $type", 1);

			$action = "c";
			next MAINLOOP;
		}

		# set spanning tree type
		if ($action eq "4") {
			my $prompt = menu(%tree_menu);

			if ($prompt eq "1") { $treemode = "mst"; }
			if ($prompt eq "2") { $treemode = "pvstmeridian"; }
			if ($prompt eq "3") { $treemode = "pvstrosenbaum"; }
			if ($prompt eq "4") { $treemode = "pvstriley"; }
			if ($prompt eq "5") { $treemode = "pvstjackson"; }
			if ($prompt eq "6") { $treemode = "pvstflowood"; }
			if ($prompt eq "7") { $treemode = "pvstconstruction"; }
			if ($prompt eq "8") { $treemode = "pvstmvrdl"; }

			debug("spanning tree set to $treemode", 1);

			$action = "c";
			next MAINLOOP;
		}

		# set pipe command
		if ($action eq "5") {
			print "Current pipe command is $pipe. Set new pipe command.\n";
			$pipe = prompt("Enter command", "text");

			debug("pipe command set to $pipe", 1);

			$action = "c";
			next MAINLOOP;
		}

		# set IP input
		if ($action eq "6") {
			print "Manual IP Input: $manualIP.\n";
			$manualIP = prompt("Manual IP?", "bool");

			debug("manual ip set to $manualIP", 1);

			$action = "c";
			next MAINLOOP;
		}

		# set Password
		if ($action eq "7") {
			$conf{'switchpw'} = prompt("Switch Password", "text");

			debug("password changed to $conf{'switchpw'}", 1);

			$action = "c";
			next MAINLOOP;
		}

		# return to main menu
		if ($action eq "b") {
			$action = "start";
			next MAINLOOP;
		}
	}

	# and let's just keep going with the mainloop ordeal
	next MAINLOOP;
}

clear_screen();
exit;

# Functions ---------------------------------------------------------------------------------------

sub int_to_bin {
	my $ip = shift;
	my $bin_ip = '';        

	# split IP
	my @octet = split /\./, $ip;

	# convert each octet to binary
	foreach my $dec (@octet) { 

		my $bin = unpack("B32", pack("N", $dec));
		$bin =~ s/^0{24}(?=\d)//; # to kill the excess zeroes

		$bin_ip .= $bin;
	}
        
	return $bin_ip;
}

sub bin_to_int {
	my $bin_ip = shift;
	my $ip = '';

	# split binary into groups of 8
	my @octet = ($bin_ip =~ m/.{8}/g);

	# convert each octet to integer and add period between octets
	my $count = 0;
	foreach my $bin (@octet) {

		my $dec = unpack("N", pack("B32", substr("0" x 32 . $bin, -32)));
                
		$ip .= $dec;
		if ($count < 3) {
			$ip .= '.';
			$count++;
		}
	}

	return $ip;
}

sub ipDepad {
	my $padded = shift;
	return bin_to_int(int_to_bin($padded));
}

sub ipPad {
	my $ip = shift;
	my @octets = split(/\./,$ip);
	my $padded = '';
	for (my $i = 0; $i < 4; $i++) {
		if ($i > 0) { $padded .= '.'; }
		$padded .= sprintf("%03s",$octets[$i]);
	}
	return $padded;
}

sub getVLAN {
	my $vlanid = shift;
	my $vlanname = '';

	# we shouldn't get a VLAN ID 1 or 0 or blank, but if it is, return empty
	
	if ($vlanid eq 1 || $vlanid eq 0 || $vlanid eq '') {
		return '';
	} else {
		db_connect($conf{'mysql_db_netdb'}, $conf{'mysql_user'},$conf{'mysql_pass'});
		my $query = "SELECT name FROM lan WHERE valid = 1 and vlan_id = $vlanid";
		my $result = db_query($query);

		if ($result) { return $result->{'name'}; } 
		else         { return ''; }

		db_disconnect();
	}
}

sub getIP {
	my $hostname = shift;
	my $location = shift;
	my @ip_oct = split /\./, "10.92.1.2";
	my $cur_ip = join('.',@ip_oct);
	my $i = 0;
	my $ip_sel = 0;	

	db_connect($conf{'mysql_db_netdb'}, $conf{'mysql_user'},$conf{'mysql_pass'});

	# first see if there's a switch named the same

	my $query = "SELECT ip_address FROM device WHERE description = '".$hostname."' AND ip_address LIKE '010.092.%' AND valid = 1";
	my $result = db_query($query);

	if ($result) {
		print "$hostname exists. Using existing IP.";
		$ip_sel = ipDepad($result->{'ip_address'});
		print "Using $ip_sel.\n";
		return $ip_sel;
	}

	while ($ip_sel eq '0') {
		if ($ip_oct[2] eq '255' && $ip_oct[3] eq '254') {
			print "IP allocation full. I will not refuse to configure.\n";
			exit;
		}

		# check if current IP is used

		my $query = "SELECT * FROM device WHERE ip_address = '".ipPad($cur_ip)."' AND valid = 1";
		if (!db_query($query)) {
			$ip_sel = $cur_ip;
			last;
		}	

		# increment IP
		$ip_oct[3]++;
		if ($ip_oct[3] == 256) {
			$ip_oct[3] = 0;
			$ip_oct[2]++;
		}
		if ($ip_oct[2] == 256) {
			$ip_oct[2] = 0;
			$ip_oct[1]++;
		}
		if ($ip_oct[1] == 256) {
			$ip_oct[1] = 0;
			$ip_oct[0]++;
		}
		if ($ip_oct[0] == 256) { last; }

		$cur_ip = join('.',@ip_oct);
	}

	# insert into static IP db

	print "Using $ip_sel.\n";

	db_disconnect();

	return $ip_sel;
}

sub update_conf_db {
	my $serial = shift;
	my $location = shift;
	my $name = shift;
	my $series = shift;
	my $model = shift;
	my $inventory = shift;
	my $ip = shift;
	my $netid = shift;
	my $fn = shift;

	# we need to convert a file into a huge string and just shove that into the database
	
	open(IFN, "<" . $fn) or die ("Error: cannot open configuration file: $fn : $!");
	my $line = "";
	my $config = "";
	while ($line = <IFN>) {
		$config .= "$line";
	}

	close(IFN);
	
	db_connect($conf{'mysql_db_SNDB'}, $conf{'mysql_user'},$conf{'mysql_pass'});

	my $query = "INSERT INTO configured_switches (serial,location,name,series,model,inventory,ip,last_handled,configured_by,picked_up,configured_date,configuration) VALUES ('$serial','$location','$name','$series','$model','$inventory','$ip','$netid','$netid',0,NOW(),'$config')";
	my $continue = db_do($query);
	if (!$continue) { print "problem\n"; }

	db_disconnect();

	return 0;
}

# compares config of switch to base configs and returns a number
sub checkLines {
	my $config = shift;
	my $basecfg = shift;
	my $spancfg = shift;

	print "$config\n" if $debug;
	print "$basecfg\n" if $debug;
	print "$spancfg\n" if $debug;

	sleep 5 if $debug;

	# open the switch to be check's config and save into a hash table
	open (CFG, $config) or die "can't open file\n";
	my %config_hash;
	my $line_cnt = 0;

	while (my $line = <CFG>) {
		chomp $line;

		# skip the comment lines
		next if ($line =~ m/^\#/);
		next if ($line =~ m/^\!.*$/);
		# skip blank lines too
		next if ($line =~ m/^$/);
		# remove whitespace at beginning and end of line
		$line =~ s/^\s+|\s+$//g;

		$line_cnt++;
		$config_hash{$line} = $line_cnt;
		debug ("$config_hash{$line}: $line",1);
	}
	close (CFG);

	sleep 5 if $debug;

	my $missing = 0;

	# now, open the base config, and check to see if all lines exist in the switch's config
	debug ("checking base config",1);
	open (BCFG, $basecfg) or die "can't open base config\n";
	while (my $line = <BCFG>) {
		chomp $line;

		# as always, skip comments and spaces
		next if ($line =~ m/^\#/);
		next if ($line =~ m/^\!.*$/);
		next if ($line =~ m/^$/);
		# remove whitespace at beginning and end of line
		$line =~ s/^\s+|\s+$//g;

		if(!exists $config_hash{$line}) {
			debug("base line missing: $line", 1);
			$missing++;
			sleep 5 if $debug;
		}
	}
	close (BCFG);

	sleep 5 if $debug;

	# and now to check the spanning tree
	debug ("checking spanning tree",1);
	open (SCFG, $spancfg) or die "can't open base config\n";
	while (my $line = <SCFG>) {
		chomp $line;

		# as always, skip comments and spaces
		next if ($line =~ m/^\#/);
		next if ($line =~ m/^\!.*$/);
		next if ($line =~ m/^$/);
		# remove whitespace at beginning and end of line
		$line =~ s/^\s+|\s+$//g;

		if(!exists $config_hash{$line}) {
			debug("spanning line missing: $line", 1);
			$missing++;
			sleep 5 if $debug;
		}
	}
	close (SCFG);

	debug ("$missing line(s) missng",1);
	return $missing;
}

sub checkRange {
	my $maxPort = shift;
	my $range = shift;
	my $lowPort = "";
	my $highPort = "";
	# check to see if range
	if ($range =~ /\s?(\d+)\s?\-\s?(\d+)\s?/) {
		$lowPort = $1;
		$highPort = $2;
		debug("port range is $lowPort to $highPort", 1);
	}
	# now check if just a single number
	elsif ($range =~ /\s?(\d+)\s?/) {
		$lowPort = $1;
		$highPort = $1;
		debug("single port, $lowPort", 1);
	}
	else {
		print "Invalid input.\n";
		return 0;
	}
	# check if lower is less than or equal to upper
	if (!($lowPort <= $highPort)) {
		print "Lower bound higher than upper bound.\n";
		return 0;
	}
	# check lower bound
	if (!($lowPort > 0)) {
		print "Lower bound out of range.\n";
		return 0;
	}
	# check upper bound
	if (!($highPort <= $maxPort)) {
		print "Upper bound out of range.\n";
		return 0;
	}
	# if it hasn't failed yet, it's good
	debug("valid range", 1);
	return 1;
}

# update cable management database
sub dbUpdate {
	my $S = shift;
	my $hostname = shift;

	DBSECTION: {
		my (%ranges) = $S->get_port_phys_ranges();
		my (%ports) = $S->get_ports();
		my ($continue, $rowid);
		my $hn = $hostname;
		$hn =~ s/\.mgmt\.msstate\.edu//;
		db_connect($conf{'mysql_db_cable'}, $conf{'mysql_user'},$conf{'mysql_pass'});
		my $qry = "Select * from `device` where `name`=\'$hn\' and `valid`='1' LIMIT 1";
		my $row = db_query($qry);

		# update the row as invalid
		if ($row) {
			debug("marking old device line as invalid!", 1);
			$qry = "UPDATE `device` SET `valid`=0 WHERE `rowid`=\'" . $row->{'rowid'} . "\'";
			$continue = db_do($qry);
			if (!$continue) {
				warn "did not update previous row: $!\n";
				last DBSECTION;
			}
		}

		# add a new row for the switch
		debug("adding db entry for the switch", 1);
		$qry = "INSERT into `device` (`name`,`date`,`valid`) values" .
		       " (\'$hn\', NOW(), 1);";

		$continue = db_do($qry);
		if (!$continue) {
			warn "did not insert new row: $!\n";
			last DBSECTION;
		}
		else {
			debug("...success!", 1);
		}

		# get last-insert-id
		$rowid = db_last_insert_id();
		if (!$rowid) {
			warn "did not insert new row: $!\n";
			last DBSECTION;
		}

		# add device rows:
		debug("adding port description entries", 1);
		my $numrows = 0;
		foreach my $range (keys %ranges) {
			my $rn = $ranges{$range}{'str'};
			$rn =~ s/\s//g;
			$qry = "INSERT into `port_desc` (`device_rowid`,`desc`,`type`) values " .
			       "( $rowid, '" . $rn . "' , " . $range . " );";

			$continue = db_do($qry);
			if (!$continue) {
				warn "did not insert new port_desc row: $!\n";
				last DBSECTION;
			}
			else {
				$numrows += 1;
			}
		}

		print "\tInserted $numrows port description rows!\n";

		# add individual port rows.
		debug("adding port entries", 1);
		$numrows = 0;

		foreach my $port (keys %ports) {
			my $pname = lc $ports{$port}{'port'};
			next if ($ports{$port}{'vlan'} !~ /^\d+$/);
			# keep it from inputting a bunch of 1's in trunked ports, et al
			$ports{$port}{'vlan'} = ($ports{$port}{'vlan'} == 1) ? '' : $ports{$port}{'vlan'};
			my $qry = "INSERT INTO `ports` (`device_rowid`,`name`,`vlan`,`date`) values " .
			          "( $rowid, '" . $pname . "', '" . $ports{$port}{'vlan'} . "' , " .
			          " NOW() );";
			$continue = db_do($qry);
			if ($continue) { $numrows += 1; }
		}

		print "\tInserted $numrows port rows!\n";
	}
}

# debugging
sub debug {
	my $message = shift;
	my $level = shift;
	my $eol = shift;
	my $fullmessage = "";

	if ($debug >= $level) {
		$fullmessage = (!$eol) ? "DEBUG.$level: $message\n": $message;
		print $fullmessage;
	}
}

# get serial port
sub get_serial_port {
	my $matchstr = shift;
	my $cmd = "find /dev -maxdepth 1 -name ";
	$cmd .= $matchstr . " 2>/dev/null";
	debug("$cmd", 1);
	my $retval = `$cmd`;
	debug ("$retval", 1);
	chomp $retval;
return $retval;
}

sub restoreConfig {
	my $S = shift;
	my $file = shift;
	$file = (defined $file) ? $file : prompt("Enter a filename", "text");
	$S->restore_config($file);
}

sub saveConfig {
	my $S = shift;
	my $file = shift;
	$file = (defined $file) ? $file : prompt("Enter a filename", "text");
	$S->backup_config($file);
}

sub setDebug {
	my $S = shift;
	$S->{'debugLevel'} = prompt("Enter new debug level (Currently Level " .
	                            $S->{'debugLevel'} . ")", "int");
}

sub setDHCPSnoop {
	my $S = shift;
	my $vlans = shift;
	my $disable = shift;
	my $toggle = shift;
	my $vlan;
	if (!defined ($disable)) {
		$disable = prompt("Enable DHCP snooping?", "bool");
		if ($disable) { $vlan = "1"; }
	}
	if (defined $vlans) {
		my @vlan_list = split( /,/ , $vlans);
		$toggle = (defined $toggle) ? $toggle : prompt("Enable DHCP snooping on vlan: $vlan","bool");
		foreach $vlan (@vlan_list) {
		  $S->set_dhcp_snooping_vlan($vlan,$disable, $toggle);
		}
	}
	else {
		$vlan = prompt("Enter vlan", "int");
		$toggle = prompt("Enable DHCP snooping on vlan: $vlan","bool");
		$S->set_dhcp_snooping_vlan($vlan,$disable, $toggle);
	}
}

sub setHostname {
	my $S = shift;
	my $hostname = shift;
	# only show current_hostname if called without a hostname
	if (!$hostname) {
		my $curr_hostname = $S->get_hostname();
		if ($curr_hostname) {
		  print "Current hostname: " . $curr_hostname . "\n";
		}
	}
	$hostname = (defined $hostname) ? $hostname : prompt("Enter new hostname","text");
	$S->{'info'}->{'hostname'} = $hostname;
	$S->set_hostname($S->{'info'}->{'hostname'});
}

sub setInventory {
	my $S = shift;
	my $in = shift;
	$in = (defined $in) ? $in : prompt("Enter new inventory number", "text");
	$S->set_inventory($in);
}

sub setIP {
	my $S = shift;
	my $ip = shift;
	my $curr_ip = $S->{'info'}->{'ip'} ? $S->{'info'}->{'ip'} : "";
	if ($curr_ip) {
		print ("Current IP: $curr_ip\n");
	}
	$ip = $ip ? $ip : prompt("Enter new IP", "ip");
	$S->{'info'}->{'ip'} = $ip;
	my $vlan = $conf{'trunk_vlan'};

	# changes for new management network
	my $netmask = $conf{'new_mgmt_netmask'};
	my $gateway = $conf{'new_mgmt_gw'};
	my $broadcast = $conf{'new_mgmt_broadcast'};

	$S->set_switch_mgmt_ip( $ip,
	                        $netmask,
	                        $vlan,
	                        $broadcast);

	$S->set_vlan_gateway($vlan,$gateway);
}

sub showConfig {
	$S = shift;
	my $config = $S->get_config();
	open PIPE, "|$pipe" or die "unable to start $pipe";
	select PIPE;
	print $config;
	select STDOUT;
	close PIPE;
}
