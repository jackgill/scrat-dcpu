# Implements the generic clock spec

package Clock;

use strict;
use warnings;

my $debug = 0;

sub new {
	my ($class, $dcpu) = @_;

	my $self = {
		dcpu => $dcpu,
		rate => 0, # ticks per second
		interrupt_message => 0,
		ticks => 0,
		last_cycle_time => time()
	};

	bless($self);

	return $self;
}

sub trigger_interrupt {
	my ($self) = @_;

	my $message = $self->{dcpu}->read_register('A');
	
	if ($message == 0) {
		my $b = $self->{dcpu}->read_register('B');
		$self->{rate} = 60 / $b;
	}
	elsif ($message == 1) {
		$self->{dcpu}->write_register('C', $self->{ticks});
		$self->{ticks} = 0;
	}
	elsif ($message == 2) {
		my $self->{interrupt_message} = $self->{dcpu}->read_register('B');
	}
}

sub cycle {
	my ($self) = @_;
	
	if ($self->{rate}) {
		my $seconds_elapsed = time() - $self->{last_cycle_time};
		my $ticks_elapsed = $seconds_elapsed * $self->{rate};
		for (0..$ticks_elapsed) {
			$self->{ticks}++;

			if ($self->{interrupt_message}) {
				$self->{dcpu}->trigger_interrupt($self->{interrupt_message});
			}
		}
	}
}

sub get_id {
	return 0x12d0b402;
}

sub get_version {
	return 1;
}

sub get_manufacturer_id {
	return 0;
}

1;
