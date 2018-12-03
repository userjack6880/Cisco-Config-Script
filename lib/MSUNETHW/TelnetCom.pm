package MSUNETHW::TelnetCom;
#
# TelnetCom.pm
# v 1.1
# 
# Functions for use in telnet communications
#
# jeb446 - 2014.06.02
# original by tmh1/csv7
#

require 5.005;
use strict;
use Expect;

sub new {
	my $class = shift;
	my $switch = shift;
	my $pw = shift;
	my $expectlog = shift;
	my $debuglevel = shift;

	my $self = {
	             "switchName" => $switch,
	             "pw"         => $pw,
	             "expectlog"  => $expectlog,
	             "debuglevel" => $debuglevel,
	             "ssh"        => "telnet",
	             "S"          => ""
	           };

	bless ($self, $class);

	return ($self);
}

# before buffer
sub before {
	my $self = shift;
	return $self->{S}->before;
}

# connect to switch
sub connect {
	my $self = shift;
	my $S;
	$self->debug("connect to " . $self->{switchName}, 1);
	$S = new Expect;
	if ($self->{expectlog}) {
		$self->{expectlogfh} = $S->log_file($self->{expectlog});
	}
	$S->raw_pty(1);
	$S->spawn($self->{ssh} . " " . $self->{switchName}) || die "Error: can't spawn: $!\n";
	$S->log_stdout(0);
	$S->expect(10, 'Password: ', 'Username: ');
	if (!$S->match()) {
		return 0;
	}
	if ($S->match() eq 'Username: ') {
		$S->send("root\n");
		$S->expect(10, 'Password: ');
		$S->send($self->{pw}."\n");
	} 
	elsif ($S->match() eq 'Password: ') {
		$S->send($self->{pw}."\n");
	} 
	else {
		print "Unexpected prompt (or no prompt) on ".$self->{switchName} .
		      " (".$S->match().")\n";
		return 0;
	}
	my $result = $S->expect(10, '>');
	return 0 if (!$result);
	$self->{S} = $S;
	return 1;
}

# debugging output
sub debug {
	my $self = shift;
	my $mesg = shift;
	my $level = shift;

	if ($self->{'debuglevel'} >= $level) {
	print "Serial ". $level .": " . $mesg . "\n";
	}
}

# disconnect from switch
sub disconnect {
	my $self = shift;
	$self->debug("close connection", 1);
	if ($self->{expectlogfh}) {
		#try to send 'exit' commandi
		$self->{S}->send("exit\n");
		# use this to grab last stuff in buffer
		$self->{S}->expect(0);
		$self->{S}->print_log_file("\nDisconnecting...\n----\n");
		# then write it and close the filehandle
		$self->{S}->log_file(undef);
		$self->{S}->hard_close;
	}
	else {
		# faster, but leaves stuff out of the logs.
		$self->{S}->hard_close;
	}
}

# send command to switch
sub send {
	my $self = shift;
	my $stuff = shift;
	$self->{S}->send($stuff);
}

# set debug level!
sub setDebug{
	my $self = shift;
	my $value = shift;
	$self->{'debuglevel'} = $value;
}

# expect
sub expect {
	my $self = shift;
	my $timeout = shift;
	my $retval =  $self->{S}->expect($timeout,@_);
	# this is broke anyways
	# return $retval;
	return 1;
}

1;
