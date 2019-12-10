package MSUNETHW::Switch;
#
# Switch.pm
# v 1.3
# 
# Functions for use in configuration of switches
#
# jeb446 - 2014.05.28
# original by tmh1
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

	$self->{expectlog}         = "log/".time."switch_out.log"; # logging of expect session, "" to disable
	$self->{expectlogfh}       = 0;
	$self->{switchName}        = $switch;
	$self->{pw}                = $pw;
	$self->{ssh}               = '/usr/bin/telnet';
	$self->{enabled}           = 0;
	$self->{paging_off}        = 0;
	$self->{baudrate}          = 9600;
	$self->{confmode}          = 0;
	$self->{connected}         = 0;
	$self->{running_config}    = '';
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
sub backup_config {
	my $self=shift;
	my $fn = shift;

	$self->debug("backing up to $fn", 1);
	$self->{running_config} = "";

	# attempt to open file
	$self->debug("attempting to open $fn", 1);
	open (OFH, ">" . $fn ) or die ("error: cannot open $fn for writing $!\n");
	my $config = $self->get_config();

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

# Check if initial connection has been made to switch
sub check_conn {
	my $self = shift;
	$self->debug("checking connection", 1);

	if (! $self->{connected}) {
		die "error: no connection to device, aborting...\n";
	}
	return 1;
}

# Establish initial connection
sub connect {
	my $self = shift;
	my $protocol = shift;
	my $port = shift;
	my $baud = shift;

	# set default baud to 9600 if not explicitly asked for
	if (!$baud) {
		$baud = 9600;
	}

	$self->{baudrate} = $baud;
	$self->{protocol} = $protocol;
	$self->debug("connecting using $protocol", 1);

	if ($protocol eq "network") {              # network connection
		$self->{interface} = MSUNETHW::TelnetCom->new( $self->{'switchName'},
	                                                 $self->{'pw'},
	                                                 $self->{'expectlog'},
		                                               $self->{'debugLevel'}
	                                               );
		my $value = $self->{interface}->connect();
		$self->{connected} = $value;
		return $value;
	} 
	elsif ($protocol eq "serial") {          # serial connection
		$self->{interface} = MSUNETHW::SerialCom->new( $port,
	                                                 $self->{'switchName'},
	                                                 $self->{'pw'},
	                                                 $self->{'debugLevel'},
	                                                 $self->{'expectlog'},
		                                               $baud
	                                               );
		my $value = $self->{interface}->connect();
		$self->{connected} = 1;
		return $value;
	}
}

# Disconnect from switch
sub disconnect {
	my $self = shift;
	$self->debug("disconnecting", 1);
	if ($self->{'connected'}) {
		$self->{'interface'}->disconnect();
		$self->{'connected'} = 0;
	}
}

# Sets a configure mode on the device
sub configure {
	my $self = shift;
	my $mode = shift;

	return if $self->{confmode}; # if configuration mode is set, return

	$self->check_conn();
	$self->debug("setting configure $mode", 1);
	$self->{interface}->send("configure $mode\n");
	my $retval = $self->{interface}->expect(10,$self->{'defaults'}{'modes'}{'globalconf'});
	if ($retval) {
		$self->{confmode} = $mode;
		$self->debug("configure mode: $mode", 1);
	}
	return $self->{confmode};
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

# Set switch to enable
sub enable {
	my $self = shift;
	return if $self->{enabled};

	$self->debug("enable", 1);
#	$self->check_conn();

	sleep 1;    # give it a second

	$self->{interface}->send("enable\n");

	my $action = $self->{interface}->expect(10, 'Password:', "#");
	if ($action == 1) {
		$self->{interface}->send($self->{pw}."\n");
		if ($self->{interface}->expect(10, '#')) {
			$self->{enabled} = 1;
		}
	} 
	elsif ($action == 2) {
		$self->{enabled} = 1;
	}

	return $self->{enabled};
}

# Ends configuration mode
sub endconfigure {
	my $self = shift;

	return if (! $self->{confmode});

	$self->debug("ending configuration mode", 1);

	$self->{interface}->send("end\n");
	$self->{confmode} = 0;
	$self->{'interface'}->expect(10,"Configured");
	$self->{'interface'}->send("\n");
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

# Get running config
sub get_config {
	my $self = shift;

	$self->debug("get running config", 1);
	$self->enable();

	return($self->{running_config}) if (length($self->{running_config}) > 0);

	$self->{running_config} = $self->run_cmd("sh run", 100);

	return($self->{running_config});
}

# Get int config
sub get_config_int {
	my $self = shift;
	my $int = shift;

	$self->debug("get config for interface $int", 1);
	$self->enable();
	my $retval = $self->run_cmd("sh run int $int", 10);
	return $retval;
}

# Get the device's hostname
sub get_hostname {
	my $self = shift;

	$self->debug("get hostname", 1);
	$self->enable();

	my $hntag = $self->run_cmd("sh run", 30);
	
	if ($hntag =~ /^hostname\s(\S+)\s*?$/m) {
		$self->{'info'}->{'hostname'} = $1;
		$self->debug("hostname: $1", 1);
		return($1);
	} 
	else {
		$self->{'info'}->{'hostname'} = "";
		return("");
	}
}

# Get device model number
sub get_model {
	my $self = shift;

	$self->debug("get device model", 1);
	my $output = $self->run_cmd("show version");

	if ($output =~ /^\s*Model number\s*:\s+(.*?)\s*$/m) {
		$self->{'info'}->{'model'} = $1;
		$self->debug("model: $1", 1);

		if ($self->{'info'}->{'model'} =~ /-C(\w+)-/ || $self->{'info'}->{'model'} =~ /(IE-4000)/ || $self->{'info'}->{'model'} =~ /(C9300)/ || $self->{'info'}->{'model'} =~ /(C9200\w\-\d+\w\-\d\w)/) {
			$self->{'info'}->{'modelnum'} = $1;
		}
		return($self->{'info'}->{'model'});
	} 
	else {
		return("unknown");
	}
}

# Get device OS revision number
sub get_os {
	my $self = shift;

	$self->debug("get IOS version", 1);
	$self->check_conn();
	my $output = $self->run_cmd("show version");

	if ($output =~ /^(?:Cisco\s)?IOS.*\sVersion\s(.*?),.*\((.*?)\)/m) {
		return("$1 ($2)");
	} 
	else {
		return("unknown");
	}
}

# Get POE info
sub get_poe_info {
	my $self = shift;
	my %retval = ();

	$self->debug("get POE info", 1);
	$self->enable();
	$self->check_conn();
	my $values = $self->run_cmd("show power inline", 10);
	my ($startmodule, $stopmodule,$startif,$stopif);
	for (split /\n/, $values) {
		if (/^Module/) {
			$startmodule = 1;
			$retval{'modules'} = {};
			next;
		}
		if (/^(\d+)\s+([\d\.]+|n\/a)\s+([\d\.]+|n\/a)\s+([\d\.]+|n\/a)/ && $startmodule) {
			$retval{'modules'}{$1} = {};
			$retval{'modules'}{$1}{'available'} = $2;
			$retval{'modules'}{$1}{'used'} = $3;
			$retval{'modules'}{$1}{'remaining'} = $4;
			$self->debug("poe module: $1 - $2,$3,$4", 2);
		}
		if (/^Interface/ && $startmodule) {
			$stopmodule = $startmodule;
			$startmodule = 0;
			$startif = 1;
			next;
		}
		if (/^((Gi|Fa|Te)\d\/\d\/(\d+))\s+(\w+)\s+(\w+)\s+([\d\.]+)\s+([\w\-\.\d\/]+)\s+([\w\/]+)\s+([\d\.]+)/i) {
			# print "$1\n$2\n$3\n$4\n$5\n$6\n$7\n$8\n$9\n\n";
			if (!exists($retval{'interfaces'})) {
				$retval{'interfaces'} = {};
			}
			my $shortname = $1;

			$retval{'interfaces'}{$shortname} = {};
			$retval{'interfaces'}{$shortname}{'interface'} = $1;
			$retval{'interfaces'}{$shortname}{'admin'} = $4;
			$retval{'interfaces'}{$shortname}{'oper'} = $5;
			$retval{'interfaces'}{$shortname}{'watts'} = $6;
			$retval{'interfaces'}{$shortname}{'device'} = $7;
			$retval{'interfaces'}{$shortname}{'class'} = $8;
			$retval{'interfaces'}{$shortname}{'max'} = $9;
		}
	}
	return (%retval);
}

# Get detailed information on the ports
sub get_ports {
	my $self = shift;
	my $refresh = shift;

	$self->debug("geting ports", 1);
	if (!$refresh && $self->{'info'}->{'ports'} ) {
		$self->debug("ports previously queried", 1);
		return ( %{$self->{'info'}->{'ports'}} );
	}
	my $output = $self->run_cmd("show interface status", 20);
	my @output = split(/\n/, $output);
	my %ports;
	foreach (@output) {
		my %row;
		if (/^(\S+)\s+(connected|notconnect|err-disabled)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.+)\s*$/m) {
			my $port = $1;
			%{$ports{$port}} = ('port' => $port, 'status' => $2, 'vlan' => $3,
			                    'duplex' => $4, 'speed' => $5, 'type' => $6);

			# Now to standardize some of the data
			$ports{$port}{'speed'}  =~ s/^a-//m;
			$ports{$port}{'speed'}  =~ s/^(\d+)/$1M/m;
			$ports{$port}{'speed'}  =~ s/^(\d{1})\d{3}M$/$1G/m;
			$ports{$port}{'speed'}  =~ s/^(\d{2})\d{3}M$/$1G/m;
			$ports{$port}{'speed'}  =~ s/^(\d{3})\d{3}M$/$1G/m;
			$ports{$port}{'duplex'} =~ s/^a-//m;
			$ports{$port}{'status'} =~ s/^notconnect/down/m;
			$ports{$port}{'status'} =~ s/^connected/up/m;

			if ($ports{$port}{'port'} =~ m/\/(\d+$)/) {
				$ports{$port}{'physport'} = $1;
			}

			if ($ports{$port}{'type'} =~ m/BaseTX/i) {
				$ports{$port}{'numtype'} = 1;
			} 
			else {
				$ports{$port}{'numtype'} = 2;
			}
		}
	}
	# set $self->info->ports to be a href to the array returned last from this call
	$self->{'info'}->{'ports'} = \%ports;
	return (%ports);
}

# get physical port ranges
sub get_port_phys_ranges {
	my $self = shift;
	my %ranges = ();

	$self->debug("get physical port ranges", 1);
	my (%ports) = $self->get_ports(1);  #force this to refresh!
	foreach my $port (keys %ports) {
		# if the port type isn't numeric, then something's off
		next if (! $ports{$port}{'numtype'} =~ /^\d$/);
		next if (! $ports{$port}{'physport'}); # skip fa0 and the like.
		my $mediatype = $ports{$port}{'numtype'};
		if (!exists $ranges{$mediatype}) {
			$ranges{$mediatype} = {
                              'type'     => $mediatype,
                              'start'    => $ports{$port}{'port'},
                              'end'      => $ports{$port}{'port'},
                              'str'      => $ports{$port}{'port'},
                              'endphys'  => $ports{$port}{'physport'},
                              'sphys'    => $ports{$port}{'physport'}
			                      };
		} 
		else {
			if ($ports{$port}{'physport'} > $ranges{$mediatype}{'endphys'}) {
				$ranges{$mediatype}{'end'} = $ports{$port}{'port'};
				$ranges{$mediatype}{'endphys'} = $ports{$port}{'physport'};
			}
			if ($ports{$port}{'physport'} < $ranges{$mediatype}{'sphys'}) {
				$ranges{$mediatype}{'start'} =  $ports{$port}{'port'};
				$ranges{$mediatype}{'sphys'} = $ports{$port}{'physport'};
			}
			# modify the str part to have the actual value...
			$ranges{$mediatype}{'str'} = lc ($ranges{$mediatype}{'start'} . " - " .
			$ranges{$mediatype}{'endphys'});
		}
	}
	return (%ranges);
}

# Get system serial number
sub get_serial_number {
	my $self = shift;

	$self->debug("getting system serial number", 1);
	my @serials = ();
	my $output = "";
	if ($self->{'info'}{'model'} =~ /C45\d+X-\S+/) {
		# because cisco thought it would be great to change things up
		$self->debug("4500x needs special commands", 1);
		$self->enable();
		$output = $self->run_cmd("sh license udi");
	} 
	else {
		$output = $self->run_cmd("show version");
	}	
	for (split /\n/, $output)	{
		if (/^\s*System serial number\s*:\s*(.*?)\s*$/m) {
			push(@serials, $1);
		} 
		elsif (/^\*0\s+[\w\-]+\s+(\w+)/i) {
			push(@serials, $1);
		} 
		else {
			push(@serials, '');
		}
	return(@serials);
	}
}

# get system model info
sub get_info {
	my $self = shift;

	$self->debug("getting model info...", 1);
	$self->check_conn();
	
	my $values = $self->run_cmd("show version");
	my %retval = ();
	my $found = 0;
	for (split /\n/, $values)	{
		# info for model number
		if (/^Model\snumber\s*\:\s([\w\-]+)/im) {
			$retval{'modelnum'} = $1;
			$self->debug("modelnum: $1", 1);
			if ($retval{'modelnum'} =~ /WS\-(C\d+\S+)\-(\d+)(\w+)/) {
				$found = 1;
				$retval{'model'} = $1;
				$retval{'num_ports'} = $2;
				$retval{'poe_ind'} = $3;
				$self->debug("model: $1",1);
				$self->debug("num_ports: $2",1);
				$self->debug("poe_ind: $3",1);
			}
			# the previous won't work with IE switches
			if ($retval{'modelnum'} =~ /IE-(\d+)/) {
				$found = 1;
				$retval{'model'} = $1;
				$self->debug("model: $1",1);
			}
			# and neither will work on new 9300 switches (I love cisco)
			if ($retval{'modelnum'} =~ /(C9\d00)/) {
				$found = 1;
				$retval{'model'} = $1;
				$self->debug("model: $1",1);
			}
		}

		# info for serial number
		if (/^\s*System serial number\s*:\s*(.*?)\s*$/im) {
			$retval{'serialnum'} = $1;
		} 

		# infor for interface stuff
		if (/^(\d+)\s([\w\s]+)\sinterface/ && $found == 1) {
			if (!exists $retval{'interfaces'}) {
				$retval{'interfaces'} = {};
			}
			my $num_ifs = $1;
			my $if_type = $2;
			$if_type =~ s/Virtual\sEthernet/ve/;
			$if_type =~ s/FastEthernet/fa/;
			$if_type =~ s/Ten\sGigabit\sEthernet/te/;
			$if_type =~ s/Gigabit\sEthernet/gi/;
			$retval{'interfaces'}{$if_type} = $num_ifs;
		}
		# if this is a stacked switch, notate this fact, then end the loop, we'll program this in later...
		if (/^Switch\s\d{2}/ && $found == 1) {
			last;
		}
	}
	# it's a bummer if we're dealing with a 4500x, we have to be enabled to get a version now
	if ($found == 0) {
		$self->debug("not what we expected, check if 4500x", 1);
		# sh license udi can only be done when enabled
		$self->enable();
		$values = $self->run_cmd("sh license udi");
		# this outputs the device model, thankfully
		for (split /\n/, $values) {
			# sample output: *0	WS-C4500X-16	SNXXXXXXX	WS-C4500X-16:SNXXXXXXX

			# we want just the model...
			if(/^\*0\s+([\w\-]+)\s/i) {
				$retval{'modelnum'} = $1;
				$self->debug("modelnum: $1",1);
				if($retval{'modelnum'} =~ /WS\-(C\d+\S+)\-(\d+)(\w+)/) {
					$found = 1;
					$retval{'model'} = $1;
					$retval{'num_ports'} = $2;
					$retval{'poe_ind'} = $3;
					$self->debug("model: $1", 1);
					$self->debug("num_ports: $2", 1);
					$self->debug("poe_ind: $3", 1);
				}
			}

			# well, that and the serial, because cisco changed this too
			if (/^\*0\s+[\w\-]+\s+(\w+)/i) {
				$retval{'serialnum'} = $1;
			} 
		}
	}
	return (%retval);
}

# turn paging off
sub paging_off {
	my $self = shift;
	return if $self->{paging_off};
	$self->debug("turn paging off", 1);
	$self->check_conn();
	$self->run_cmd("term len 0");
	$self->{paging_off} = 1;
}

# change baud rate
sub change_baud {
	my $self = shift;
	my $baud = shift;

	$self->debug("changing to $baud", 1);

	if ($self->{baudrate} == $baud) {
		$self->debug("already $baud", 1);
		return;
	}

	# we should set this...
	$self->{baudrate} = $baud;

	$self->check_conn();
	$self->enable();
	$self->configure("terminal");
	$self->run_cmd("line con 0\n");
	$self->run_cmd("speed $baud\n");
	$self->{interface}->disconnect();	
	$self->{interface}->setBaud($baud);
	$self->{interface}->connect();
	$self->endconfigure();
}

# reboot a device
sub reset {
	my $self = shift;
	my $response = shift;

	# standardize the response for yes/no
	$self->debug("reboot device", 1);
	$response = ($response =~ /y/i) ? "yes" : "no";
	$self->check_conn();
	$self->enable();
	$self->run_cmd("reload");
	my $saveprompt = $self->{interface}->expect(5, "Save?");
	if ($saveprompt) {
		$self->{interface}->send("$response\n");
	}
	$self->{interface}->send("\n\r");
	$self->{enabled} = 0;
}

# Restore a configuration to a device from a file
sub restore_config {
	my $self = shift;
	my $fn = shift;

	$self->debug("restoring configuration from $fn", 1);

	# verify we're connected, enabled and conf-t'd
	$self->check_conn();
	$self->enable();
	$self->configure("terminal");
	open(IFN, "<" . $fn) or die("Error: cannot open configuration file: $fn : $!");
	my $i = 0;
	my $line = "";

	#when added to the serial send wait, it'll wait 1/2 a sec for each line
	my $timeout = 15000;
	if (($self->{'protocol'} eq "usb") || ($self->{'protocol'} eq "network")) {
		# give a slightly higher timeout for USB or network
		$timeout = 800000;
	}
	while ($line = <IFN>) {
		# skip comment lines!
		next if ($line =~ m/^\#/);
		next if ($line =~ m/^\!.*$/);
		$i++;
		# sleep for at least 1/2 a second
		usleep($timeout);
		$self->{interface}->send("$line");
	}

	# config is closed by the files themselves
	$self->endconfigure();
	close(IFN);
}

# Execute a regular command (one that returns to a standard prompt)
# warning: often will capture the command as well as the output
sub run_cmd {
	my $self = shift;
	my $cmd = shift;
	my $delay = shift;
	my $output = "";

	$delay = ($delay) ? $delay : 10;
	$self->debug("serial: $cmd", 2);
	$self->check_conn();
	$self->{interface}->send("$cmd\n");

	#capture the output
	if ($self->{'protocol'} eq "network") {
		#unfortunately, for this to work, the expect call _must_fail. 
		$self->{interface}->{S}->expect(4,"boogabooga");
		$output = $self->{interface}->{S}->before();
		$self->{interface}->{S}->clear_accum();
	}
	else {
		$self->{interface}->expect($delay,'#','>');
		$output = $self->{interface}->before;
	}
	return($output);
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
	$self->enable();
	$self->configure("terminal");
	$self->{interface}->send("hostname $hostname \n");
	$self->{interface}->expect(10,"#",">");
	$self->endconfigure();
}

# return port to default
sub set_port_default {
	my $self = shift;
	my $ports = shift;
	my @series = $self->expand_series($ports);

	$self->debug("resetting port(s)", 1);

	$self->enable();
	$self->configure("terminal");

	foreach my $port (@series) {
		my $multiple = ($port =~ m/\s\-\s/) ? 1: 0;
		if ($multiple) { $self->{'interface'}->send("default interface range $port \n"); }
		else {           $self->{'interface'}->send("default interface $port \n");       }
	}	

	$self->endconfigure();
}

# put port(s) in a vlan
sub set_port_vlan {
	my $self = shift;
	my $ports = shift;
	my $vlan = shift;
	my $security = shift;
  my $poe = shift;
	my $passthrough = shift;
	my $vlan2 = shift;
	my @series = $self->expand_series($ports);

	$self->debug("putting port(s) in vlan" , 1);

	$self->enable();
	$self->configure("terminal");

	foreach my $port (@series) {
		$self->debug("set_port_vlan: port: $port vlan: $vlan, security: $security, poe: $poe, passthrough: $passthrough, vlan2: $vlan2", 1);
		my $multiple = ($port =~ m/\s\-\s/) ? 1: 0;
		my $resume = 0;
		if ($multiple) {
		# range selected
			$self->{'interface'}->send("default interface range $port \n");
			$self->{interface}->send("interface range $port \n");
			$resume = $self->{interface}->expect(10,"(config-if-range)#");
		} 
		else {
			$self->{'interface'}->send("default interface $port \n");
			$self->{interface}->send("interface $port \n");
			$resume = $self->{interface}->expect(10,"(config-if)#");
		}
		if ($resume) {
			if ($passthrough) {
				$self->{interface}->send("switchport trunk native vlan $vlan\n");
				$self->{interface}->send("switchport trunk allowed vlan $vlan2,$vlan\n");
				$self->{interface}->send("switchport mode trunk\n");
			}
			else {
				$self->{interface}->send("switchport access vlan $vlan\n");
				$self->{interface}->send("switchport mode access\n");
			}
			$self->{interface}->send("spanning-tree portfast\n");
			if ($security) {
				if ($passthrough) { $self->{interface}->send("switchport port-security maximum 5\n");     }
				else {              $self->{interface}->send("switchport port-security maximum 2\n"); }
				$self->{interface}->send("switchport port-security\n");
				$self->{interface}->send("switchport port-security aging time 15\n");
				$self->{interface}->send("switchport port-security violation protect\n");
				$self->{interface}->send("switchport port-security aging type inactivity\n");
			}
			#if ($poe eq "1") {
			#	$self->{interface}->send("no power inline consumption\n");
			#}
			#elsif ($poe eq "2") {
			#	$self->{interface}->send("power inline consumption 15400\n");
			#}
			#else {
			#	$self->{interface}->send("power inline never\n");
			#}
		}
	}
	$self->endconfigure();
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

	$self->enable();
	$self->configure("terminal");
	foreach my $port (@series) {
		$self->debug("setting port(s) $port to trunk mode", 1);

		# determine if this is a range or just 1 port
		my $multiple = ($port =~ m/\s\-\s/) ? 1: 0;
		my $resume = 0;

		# restore port defaults
		if ($multiple) {
			$self->{'interface'}->send("default interface range $port \n");
			$self->{'interface'}->send("interface range $port \n");
			$resume = $self->{'interface'}->expect(10,"(config-if-range)#");
		}
		else {
			$self->{'interface'}->send("default interface $port \n");
			$self->{'interface'}->send("interface $port \n");
			$resume = $self->{'interface'}->expect(10,"(config-if)#");
		}
		if ($resume) {
			if ($self->{'info'}{'dot1q_trunk'}) {
				$self->{'interface'}->send("switchport trunk encapsulation dot1q\n");
			}
			$self->{'interface'}->send("switchport mode trunk\n");
			$self->{'interface'}->send("switchport trunk native vlan $vlan\n");
			if ($self->{'info'}->{'dhcp_snoop'}) {
				$self->{'interface'}->send("ip dhcp snooping trust\n");
				$self->{'interface'}->send("no keepalive\n");
			}
		}
	}
	$self->endconfigure();
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

	$self->enable();
	$self->configure("terminal");

	$self->{'interface'}->send("interface vlan $vlan\n");
	$self->{'interface'}->expect(10,"(config-if)#");
	$self->{'interface'}->send("ip address $ip $netmask\n");
	$self->{'interface'}->send("ip broadcast-address $broadcast\n");
	$self->endconfigure();
}

# sets the secondary ip address of a switch
sub set_switch_mgmt_ip_secondary {
	my $self = shift;
	my $ip = shift;
	my $netmask = shift;
	my $vlan = shift;

	if (!$vlan || !$ip || !$netmask) { return 0; }
	$self->debug("setting the management vlan ip: $ip", 1);

	$self->enable();
	$self->configure("terminal");

	$self->{'interface'}->send("interface vlan $vlan\n");
	$self->{'interface'}->expect(10,"(config-if)#");
	$self->{'interface'}->send("ip address $ip $netmask secondary\n");
	$self->endconfigure();
}

# set vlan gateway
sub set_vlan_gateway {
	my $self = shift;
	my $vlan = shift;
	my $gateway = shift;

	if (!$vlan || !$gateway) { return 0; }

	$self->debug("setting the management gateway on vlan:$vlan to $gateway", 1);

	$self->enable();
	$self->configure("terminal");
	$self->{'interface'}->send("interface Vlan" . $vlan . "\n");
	$self->{'interface'}->expect(10,"(config-if)#");
	$self->{'interface'}->send("ip default-gateway $gateway\n");
	$self->endconfigure();
}

# set dhcp snooping vlan
sub set_dhcp_snooping_vlan {
	my $self = shift;
	my $vlan = shift;
	my $disable = shift;
	my $toggle = shift;

	if (!defined($vlan)) { return; }

	$self->debug("setting default dhcp snooping vlan: $vlan ", 1);
	$self->enable();
	$self->configure("terminal");

	my $cmd1 = ($disable) ? "no ip dhcp snooping\n" : "ip dhcp snooping\n";
	my $cmd2 = ($toggle) ? "no ip dhcp snooping vlan $vlan\n" : "ip dhcp snooping vlan $vlan\n";
	$cmd2 = ($disable) ? "no ip dhcp snooping vlan 1-4094\n": $cmd2;

	$self->{'interface'}->send($cmd1);
	$self->{'interface'}->expect(10,"#");
	$self->{'interface'}->send($cmd2);
	$self->{'interface'}->expect(10,"#");
	$self->endconfigure();
}

# skip_initial_configuration
sub skip_initial_configuration {
	my $self = shift;

	$self->debug("skipping initial configuration", 1);
	$self->check_conn();

	$self->{'interface'}->send("\n\r");
	sleep 2;

	my $action = $self->{'interface'}->expect(10, 
	                                          $self->{'defaults'}->{'prompts'}->{'config'},
	                                          $self->{'defaults'}->{'prompts'}->{'start'},
	                                          "#",
	                                          "Switch>"
	                                         );
	sleep 2;

	if ($action == 1) {
		$self->debug("matched config...",1);
		# give it a second to finish yacking...
		sleep 2;
		$self->{'interface'}->send("\n\r");
		$self->{'interface'}->send("no\n");
    # a second return character will skip autoinstalls on 9200's (and maybe others)
    $self->{'interface'}->send("\n\r");
	}
	elsif ($action == 2) {
		$self->debug("matched start...",1);
		# have it wait a bit, like above
		sleep 2;
		$self->{'interface'}->send("\n\r");
		$self->{'interface'}->send("no\n");
		# like above... skip autoinstall
		$self->{'interface'}->send("\n\r");
	}
	elsif (($action != 3) && ($action != 4)) {
		# have it check for ">" now, since it causes problems otherwise
		$self->{'interface'}->send("\n\r");
		$action = $self->{'interface'}->expect(10, "#", ">");
		if(($action != 1) && ($action != 2)) {
			my $mesg = $self->{'interface'}->before();
			print "No intial prompt found. Possible stuck serial port?\n";
			return "failed";
		}
	}
}

# set inventory number
sub set_inventory {
	my $self = shift;
	my $inventorynum = shift;

	$self->debug("setting inventory: $inventorynum", 1);

	$self->enable();
	$self->configure("terminal");
	$self->{'interface'}->send("snmp-server contact $inventorynum\n");
	$self->{'interface'}->expect(10,"#");
	$self->endconfigure();
}

# write erase
sub write_erase {
	my $self = shift;

	$self->debug("write erase switch", 1);

	$self->check_conn();
	$self->enable();
	$self->{'interface'}->send("wr erase");
	$self->{'interface'}->send("\n\r");
}

# write mem
sub write_mem {
	my $self = shift;

	$self->debug("writing memory", 1);

	$self->check_conn();
	$self->{interface}->send("write mem\n");
	$self->{interface}->expect(10, "#", ">");
}

# generate RSA key
sub gen_key {
	my $self = shift;
	$self->debug("generating RSA key", 1);

	$self->check_conn();
	$self->enable();
	$self->configure("terminal");
	$self->{'interface'}->send("crypto key generate rsa modulus 4096\n");
	$self->endconfigure();
}

sub set_stack_master {
	my $self = shift;
	$self->debug("setting stack master", 1);

	$self->check_conn();
	$self->enable();
	$self->{'interface'}->send("switch 1 priority 15\n");
}

1;
