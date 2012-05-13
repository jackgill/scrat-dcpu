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
		print "Setting rate to $self->{rate}\n" if $debug;
	}
	elsif ($message == 1) {
		$self->{dcpu}->write_register('C', $self->{ticks});
		$self->{ticks} = 0;
	}
	elsif ($message == 2) {
		$self->{interrupt_message} = $self->{dcpu}->read_register('B');
		print "Setting interrupt message to $self->{interrupt_message}\n" if $debug;
	}
	else {
		die "Error: unrecognized clock interrupt message: $message\n";
	}
}

sub execute_cycle {
	my ($self) = @_;

	#print "Clock executing cycle\n" if $debug;
	
	if ($self->{rate}) {
		#print "At rate $self->{rate}\n" if $debug;

		my $now = time();
		my $seconds_elapsed = $now - $self->{last_cycle_time};
		my $ticks_elapsed = $seconds_elapsed * $self->{rate};
		#print "$ticks_elapsed ticks elapsed\n" if $debug;
		for (my $i = 0; $i < $ticks_elapsed; $i++) {
			$self->{ticks}++;
			print "Ticking\n" if $debug;
			
			if ($self->{interrupt_message}) {
				print "triggering interrupt\n" if $debug;
				$self->{dcpu}->trigger_interrupt($self->{interrupt_message});
			}
		}
		$self->{last_cycle_time} = $now;
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
