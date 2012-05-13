# Implements the generic keyboard spec

package Keyboard;

use strict;
use warnings;

my $debug = 0;

sub new {
	my ($class, $dcpu, $parent_frame) = @_;

	my $self = {
		dcpu => $dcpu,
		buffer => [],
		interrupts_enabled => 0,
	};

	bless($self);

	return $self;
}

sub trigger_interrupt {
	my ($self) = @_;

	my $message = $self->{dcpu}->read_register('A');
	
	if ($message == 0) {
		$self->{buffer} = [];
	}
	elsif ($message == 1) {
		my $next = shift @{ $self->{buffer} };
		if (defined $next) {
			$self->{dcpu}->write_register('C', $next);
		}
		else {
			$self->{dcpu}->write_register('C', 0);
		}
	}
	elsif ($message == 2) {
		my $b = $self->{dcpu}->read_register('A');

		$self->{dcpu}->write_register('C', 0);
		die "Keyboard does not support interrupt 2\n";
	}
	elsif ($message == 3) {
		my $self->{interrupt_message} = $self->{dcpu}->read_register('B');
	}
	else {
		die "Error: unrecognized keyboard interrupt message: $message\n";
	}
}

sub handle_key_press {
	my ($self, $key_code) = @_;

	my $key_num = ord($key_code);

	print "key_code: $key_code\n" if $debug;
	print "key_num: $key_num\n" if $debug;

	my $num = $key_num + 0x20;
	push @{ $self->{buffer} }, $num
}

sub get_id {
	return 0x30cf7406;
}

sub get_version {
	return 1;
}

sub get_manufacturer_id {
	return 0;
}

1;
