package MSUNETHW::File;
#
# File.pm
# v 1.0
# 
# Functions for use in creating configuration files for switches
#
# jeb446 - 2014.07.22
#

require 5.005;
use strict;
use Expect;
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval);

our %conf;

sub new {
	my $class = shift;
	my $switch = shift;
	my $debug_level = shift;
	my $pw = shift;
	my $type = shift;

	my $self = {};
	bless ($self, $class);

	$self->{expectlog}         = "log/switch_out.log"; # logging of expect session, "" to disable
	$self->{expectlogfh}       = 0;
	$self->{switchName}        = $switch;
	$self->{pw}                = $pw;
	$self->{ssh}               = '/usr/bin/telnet';
	$self->{enabled}           = 0;
	$self->{confmode}          = 0;
	$self->{connected}         = 0;
	$self->{running_config}    = '';
	$self->{file_name}         = '';
	$self->{debugLevel}        = $debug_level;
	$self->{interface}         = "";
	$self->{'docustomconfigs'} = 1;
	$self->{'protocol'}        = "";

	$self->{defaults}{modes}   = { "userexec"    => ">",
	                               "privexec"    => "#",
	                               "globalconf"  => "(config)#",
	                               "intconf"     => "(config-if)#",
	                               "vlanconf"    => "(config-vlan)#",
	                               "lineconf"    => "(config-line)#"
	                             };

	$self->{defaults}{prompts} = { "start"   => "Press RETURN to get started.",
	                               "config"  => "[yes/no]"
	                             };

	$self->{'info'}            = { "dhcp_snoop"         => 0,
	                               "dhcp_snoop_vlan"    => "",
	                               "model"              => "",
	                               "modelnum"           => "",
	                               "num_ports"          => "",
	                               "vlan"               => "1",
	                               "hostname"           => "",
	                               "ip"                 => "",
	                               "inventory"          => "",
	                               "num_ports"          => "",
	                               "port_prefix"        => "",
	                               "num_uplinks"        => "",
	                               "uplink_pre"         => "",
	                               "uplink_start"       => "",
	                               "uplink_end"         => "",
	                               "copper_trunk"       => "",
	                               "copper_trunk_range" => "",
	                               "use_security"       => 0,
	                               "uplinks"            => [],
			                           "dot1q_trunk"        => 0
	                             };
	$self->debug("configuring $type", 1);
 
	return($self);
}

# Backup device's running-config to a file
sub disconnect {
	my $self=shift;
	my $fn=$self->{'file_name'};

	$self->debug("saving to $fn", 1);

	# attempt to open file
	$self->debug("attempting to open $fn", 1);
	open (OFH, ">" . $fn ) or die ("error: cannot open $fn for writing $!\n");

	sleep 5;       # give it a few seconds before jumping ahead...
	
	$self->debug("cleaning up config", 1);

	# get rid of ! lines
	$self->{'running_config'} =~ s/^\!.*$//mg;

	# cleanup initial command stuff
	$self->{'running_config'} =~ s/^sh\srun\s*$//m;
	$self->{'running_config'} =~ s/^Building\sconfiguration\.\.\.\s*$//m;
	$self->{'running_config'} =~ s/^Current\sconfiguration.*$//m;
	
	# remove duplicate line breaks (emtpy lines)
	$self->{'running_config'} =~ s/\n\s*\n/\n/mg;

	# remove any final command barf
	$self->{'running_config'} =~ s/^.+#//mg;

	# add "end"

	$self->{'running_config'} .= "end\n";

	# print to file
	$self->debug("writing to file", 1);
	print OFH $self->{'running_config'};
	close OFH;
}

# Establish that file can be opened
sub connect {
	my $self = shift;
	my $fn = shift;

	$self->{'file_name'} = $fn;	

	# attempt to open file
	$self->debug("atempting to open $fn", 1);
	open (OFH, ">" . $fn) or do {
		print "File could not be opened or created. Returning to main menu.\n";
		sleep 5;
		return 0;
	};

	$self->debug("$fn was successfully opened", 1);
	close OFH;

	return 1;
}

# Negates a section of a configuration
sub conf_negate {
	my $self = shift;
	my $txt = shift;
	my @arr = split(/\n/, $txt);
	my @ret = ();

	$self->debug("negating section of config", 1);

	foreach my $line (@arr) {
		if ($line =~ m/^\s*interface/i) {
			push @ret, $line;
			next;
		}

		$self->debug("line - \"$line\"", 1);

		$line = "no " . $line;
		push @ret, $line;
	}

	my $retvalue = join ("\n", @ret);
}

# Output debugging information based on the set debug level
sub debug {
	my $self = shift;
	my $message = shift;
	my $level = shift;
	my $eol = shift;
	my $fullmessage = "";

	if ($self->{debugLevel} >= $level) {
		$fullmessage = (!$eol) ? "DEBUG.$level: $message\n": $message;
		print $fullmessage;
	}
}

#returns an array of the included ranges
sub expand_range {
	my $self = shift;
	my $range = shift;
	my @ret = ();
	my ($i, $j, $k, $port);

	$self->debug("expanding range", 1);

	if ($range =~ /^([\w\/]+\/)(\d+)\s\-\s(\d+)/) {
		$port = $1;
		$j = $2;
		$k = $3;
	} 
	else {
		return ($range);
	}

	for ($i = $j; $i <= $k; $i++) {
		my $val = $port . $i;
		push @ret, $val;
	}

	return @ret;
}

# returns an array of valid ports/ranges from a csv list of ports
sub expand_series {
	my $self = shift;
	my $series = shift;
	my $doprefix = shift;
	my @parts = split(/\,/, $series);
	my $ptype = "";
	my @retval = ();

	$self->debug("expanding series", 1);

	foreach my $part (@parts) {
		#replace any starting or trailing whitespace
		$part =~ s/^\s+|\s+$//g;
		if ($doprefix) {
			# get the port type and store it... others will use this
			if ($part =~ m/((fa|gi|te)\d+\/(\d+\/)*)/) {
				$ptype = $1;
			} 
			else {
				$ptype = $self->{'info'}->{'port_prefix'};
			}

			# add the port type if it's not there yet
			if ($part !~ /$ptype/) {
			$part = $ptype . $part;
			}
		}

		# nicely standardize the port range stuff
		$part =~ s/(\d)\-/$1 -/;
		$part =~ s/\-(\d)/- $1/;
		push @retval, $part;
	}

	return @retval;
}

# loads a configuration to the running_config variable
sub restore_config {
	my $self = shift;
	my $fn = shift;

	$self->debug("restoring configuration from $fn", 1);

	# open the file and save it to the running config variable...
	open(IFN, "<" . $fn) or die("Error: cannot open configuration file: $fn : $!");
	my $i = 0;
	my $line = "";

	while ($line = <IFN>) {
		$i++;
		$self->{'running_config'} .= $line;
	}

	# config is closed by the files themselves
	close(IFN);
}

# Set the system hostname
sub set_hostname {
	my $self = shift;
	my $hostname = shift;
	if ($hostname eq "") {
		$self->debug("cannot set empty hostname", 1);
		return;
	}
	else {
		$self->debug("setting hostname to $hostname", 1)
	}
	
	my $configString = "hostname $hostname\n";
	$self->{'running_config'} =~ s/(service\spassword\-encryption\n)/$1$configString/;
}

# put port(s) in a vlan
sub set_port_vlan {
	my $self = shift;
	my $ports = shift;
	my $vlan = shift;
	my $security = shift;
	my @series = $self->expand_series($ports);

	$self->debug("putting port(s) in vlan" , 1);

	my $portConfig = "";

	foreach my $port (@series) {
		$self->debug("set_port_vlan: port: $port vlan: $vlan, security: $security", 1);
		my $multiple = ($port =~ m/\s\-\s/) ? 1: 0;
		my $resume = 0;

		# default the ports...
		if ($multiple) {
			$portConfig .= "default interface range $port \n";
		}
		else {
			$portConfig .= "default interface $port \n";
		}

		if ($multiple) {
		# range selected
			$portConfig .= "interface range $port \n";
		} 
		else {
			$portConfig .= "interface $port \n";
		}
		$portConfig .= "switchport access vlan $vlan\n";
		$portConfig .= "switchport mode access\n";
		$portConfig .= "spanning-tree portfast\n";
		if ($security) {
			$portConfig .= "switchport port-security maximum 2\n";
			$portConfig .= "switchport port-security\n";
			$portConfig .= "switchport port-security aging time 15\n";
			$portConfig .= "switchport port-security violation protect\n";
			$portConfig .= "switchport port-security aging type inactivity\n";
		}
	}

	# finally insert the port config into the right location

	$self->{'running_config'} =~ s/(\!CONFIGURE_PORTS\n)/$portConfig$1/;
}

# set trunk ports
sub set_port_trunk {
	my $self = shift;
	my $ports = shift;
	my $vlan = shift;
	my $add_prefix = shift;
	my @series = $self->expand_series($ports,$vlan,$add_prefix);

	$self->debug("setting trunk port(s)", 1);
	$self->debug("add prefix: $add_prefix", 1);

	my $portConfig = "";

	foreach my $port (@series) {
		$self->debug("setting port(s) $port to trunk mode", 1);

		# determine if this is a range or just 1 port
		my $multiple = ($port =~ m/\s\-\s/) ? 1: 0;
		my $resume = 0;

		# restore port defaults
		if ($multiple) {
			$portConfig .= "default interface range $port \n";
		}
		else {
			$portConfig .= "default interface $port \n";
		}

		# select range
		if ($multiple) {
			$portConfig .= "interface range $port \n";
		}
		else {
			$portConfig .= "interface $port \n";
		}
		if ($self->{'info'}{'dot1q_trunk'}) {
			$portConfig .= "switchport trunk encapsulation dot1q\n";
		}
		$portConfig .= "switchport mode trunk\n";
		$portConfig .= "switchport trunk native vlan $vlan\n";
		if ($self->{'info'}->{'dhcp_snoop'}) {
			$portConfig .= "ip dhcp snooping trust\n";
			$portConfig .= "no keepalive\n";
		}
	}

	$self->{'running_config'} =~ s/(\!CONFIGURE_PORTS\n)/$portConfig$1/;
}

# set switch management port IP address
sub set_switch_mgmt_ip {
	my $self = shift;
	my $ip = shift;
	my $netmask = shift;
	my $vlan = shift;
	my $broadcast = shift;

	if (!$vlan || !$ip || !$netmask) { return 0; }
	$self->debug("setting the management vlan ip: $ip", 1);

	my $mgmtIPcmd = "";

	$mgmtIPcmd .= "ip address $ip $netmask\n";
	$mgmtIPcmd .= "ip broadcast-address $broadcast\n";

	# let's lovingly place it where it belongs

	$self->{'running_config'} =~ s/(Vlan$vlan\n)/$1$mgmtIPcmd/;
}

# sets the secondary ip address of a switch
sub set_switch_mgmt_ip_secondary {
	my $self = shift;
	my $ip = shift;
	my $netmask = shift;
	my $vlan = shift;

	if (!$vlan || !$ip || !$netmask) { return 0; }
	$self->debug("setting the management vlan ip: $ip", 1);

	my $mgmtIPcmd = "";

	$mgmtIPcmd .= "ip address $ip $netmask secondary\n";

	# let's loving place it where it belongs

	$self->{'running_config'} =~ s/(Vlan$vlan\n)/$1$mgmtIPcmd/;
}

# set vlan gateway
sub set_vlan_gateway {
	my $self = shift;
	my $vlan = shift;
	my $gateway = shift;

	if (!$vlan || !$gateway) { return 0; }

	$self->debug("setting the management gateway on vlan:$vlan to $gateway", 1);

	my $mgmtIPcmd = "";

	$mgmtIPcmd .= "ip default-gateway $gateway\n";

	# let's lovingly place it where it belongs

	$self->{'running_config'} =~ s/(ip\sbroadcast\-address\s\d+\.\d+\.\d+\.\d+\n)/$1$mgmtIPcmd/;

}

# set dhcp snooping vlan
sub set_dhcp_snooping_vlan {
	my $self = shift;
	my $vlan = shift;
	my $disable = shift;
	my $toggle = shift;

	if (!defined($vlan)) { return; }

	$self->debug("setting default dhcp snooping vlan: $vlan ", 1);

	my $cmd1 = ($disable) ? "no ip dhcp snooping\n" : "ip dhcp snooping\n";
	my $cmd2 = ($toggle) ? "no ip dhcp snooping vlan $vlan\n" : "ip dhcp snooping vlan $vlan\n";
	$cmd2 = ($disable) ? "no ip dhcp snooping vlan 1-4094\n": $cmd2;

	$self->{'running_config'} =~ s/(authentication\smac\-move\spermit\n)/$1$cmd1/;
	$self->{'running_config'} =~ s/($cmd1)/$1$cmd2/;
}

# set inventory number
sub set_inventory {
	my $self = shift;
	my $inventorynum = shift;

	$self->debug("setting inventory: $inventorynum", 1);

	my $snmpcmd = "snmp-server contact $inventorynum\n";

	$self->{'running_config'} =~ s/(snmp\-server\senable\straps\ssnmp)/$snmpcmd$1/;
}

sub gen_key {
  my $self = shift;
  $self->debug("generating RSA key", 1);

  $self->{'running_config'} .= "crypto key generate rsa\n";
  $self->{'running_config'} .= "no\n";
  $self->{'running_config'} .= "2048\n";
}

# Backup device's running-config to a file
sub backup_config {
  my $self=shift;
  my $fn = shift;

  $self->debug("backing up to $fn", 1);

  # attempt to open file
  $self->debug("attempting to open $fn", 1);
  open (OFH, ">" . $fn ) or die ("error: cannot open $fn for writing $!\n");
  my $config = $self->{'running_config'};

  sleep 5;       # give it a few seconds before jumping ahead...

  $self->debug("cleaning up config", 1);

  # get rid of ! lines
  $config =~ s/^\!\s*$//mg;

  # cleanup initial command stuff
  $config =~ s/^sh\srun\s*$//m;
  $config =~ s/^Building\sconfiguration\.\.\.\s*$//m;
  $config =~ s/^Current\sconfiguration.*$//m;

  # remove duplicate line breaks (emtpy lines)
  $config =~ s/\n\s*\n/\n/mg;

  # remove any final command barf
  $config =~ s/^.+#//mg;

  # print to file
  $self->debug("writing to file", 1);
  print OFH $config;
  close OFH;
}

1;
