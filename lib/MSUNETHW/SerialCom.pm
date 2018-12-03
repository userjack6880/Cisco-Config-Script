package MSUNETHW::SerialCom;
#
# SerialCom.pm
# v 1.1
# 
# Functions for use in telnet communications
#
# jeb446 - 2014.06.02
# original by tmh1/csv7
#

use Device::SerialPort;
use strict;
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval);
use FileHandle;

sub new {
	my $class = shift;
	my $port = shift;
	my $switch = shift;
	my $pw = shift;
	my $debuglevel = shift;
	my $expectlog = shift;
	my $baudrate = shift;
	if (!$baudrate) {
		$baudrate = 9600;
	}
	my $self = {
	             "switchName" => $switch,
	             "pw"         => $pw,
	             "expectlog"  => $expectlog,
	             "port"       => $port,
	             "debuglevel" => $debuglevel,
	             "S"          => "",
	             "buffer"     => "",
	             "filedebug"  => 0,
	             "baudrate"   => $baudrate
	           };

	if (defined $expectlog) {
		# create a log file for logging communications
		$self->{'lfh'} = FileHandle->new( "> " . $expectlog);
	}
	else {
		$self->{'lfh'} = undef;
	}

	bless ($self, $class);
	return ($self);
}

# before buffer
sub before {
	my $self = shift;
	return $self->{'buffer'};
}

# connect to serial port
sub connect {
	my $self = shift;
	$self->debug("trying to use serial port: " . $self->{'port'}, 1);

	my $S = Device::SerialPort->new($self->{'port'}) || die ("Error: cannot open " . $self->{'port'} . " " .  $! . "\n" );
	$S->baudrate($self->{'baudrate'});
	$S->read_char_time(0);
	$S->read_const_time(1000);
	$self->{S} = $S;
	$self->send("\r\r");
}

# debugging output
sub debug {
	my $self = shift;
	my $mesg = shift;
	my $level = shift;
	if (( defined $self->{'lfh'})) {
		$self->{'lfh'}->print($mesg . "\n");
	}
	if ($self->{'debuglevel'} >= $level) {
		print "Serial ". $level .": " . $mesg . "\n";
	}
}

# disconnect
sub disconnect {
	my $self = shift;
	$self->{S}->close() || warn "Warning: close failed! $!\n";
}

# send command to switch
sub send {
	my $self = shift;
	my $sendString = shift;

	$self->debug(" >> " . $sendString, 2);
	my $outBytes = $self->{S}->write($sendString);
	warn "Warning: write failed\n" unless ($outBytes);
	warn "Warning: write incomplete\n" if ($outBytes != length($sendString));
	usleep (200000);
}

# set debug level
sub setDebug {
	my $self = shift;
	my $value = shift;

	$self->debug("setting debug level", 1);

	$self->{'debuglevel'} = $value;
}

# set baud rate
sub setBaud {
	my $self = shift;
	my $baud = shift;

	$self->debug("setting baud rate", 1);

	$self->{baudrate} = $baud;
}

# expect certain things
sub expect {
	my @args = @_;
	my $self = shift @args;
	my $timeout = shift @args;
	my @searchargs =  @args;
	my %params;
	$timeout = ($timeout) ? $timeout : 10;
	my $id = 0;
	my $usereg = "";
	my $joinstr = "";
	foreach my $searchtag (@searchargs) {
		if ($searchtag =~/^\-re$/i) {
			$usereg = 1;
			next;
		}
		else {
			$id++;
			$params{$id} = {};
			$params{$id}{'reg'} = $usereg;
			$params{$id}{'pattern'} = $searchtag;
			$joinstr .= " :$searchtag";
			#cleanup
			$usereg = 0;
		}
	}
	$self->debug("Expect: searching for $id strs: " . $joinstr, 1);
	my $buffer;
	my $count = 0;
	my $startTime = time();
	while (my ($count,$read)=$self->{S}->read(255)) {
		#    print "$read";
		$self->debug( " << " . $read, 3);
		$buffer .= $read;
		foreach my $idn (sort keys %params) {
			#     $self->debug("expect: checking for param: " . $params{$idn}{'pattern'});
			if ($params{$idn}{'reg'}) {
				if($buffer =~ /$params{$idn}{'pattern'}/g) {
				$self->debug("Expect: matched pattern $idn: " . $params{$idn}{'pattern'}, 1);
				$self->{S}->lookclear;
				$self->{'buffer'} = $buffer;
				return $idn;
				}
			} 
			else {
				if (index($buffer,$params{$idn}{'pattern'}) > -1) {
					$self->debug("Expect: matched string $idn: " . $params{$idn}{'pattern'}, 1);
					$self->{S}->lookclear;
					$self->{'buffer'} = $buffer;
					return $idn;
				}
			}
		}
		if ((time() - $startTime) > $timeout) {
			# mimics the behaviour of expect->before
			$self->{'buffer'} = $buffer;
			$self->debug("Expect: did not match any strings!", 1);
			$self->debug("...\n$buffer\n...\n", 1);
			return 0;
		}
	}
}

1;
