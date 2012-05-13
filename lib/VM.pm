# This module encapsulates the state of the DCPU-16, which currently consists of the following:
# 
# 8 general purpose registers
# 4 special purpose registers
# 65536 words of memory
#
# There is also a method to load data from a file into RAM, and a method to dump the state
# of the VM to the terminal.

package VM;

use strict;
use warnings;
use autodie;

use DCPU;

my $debug = 0;

sub new {
	my ($class) = @_;

	my $n_memory_words = 0x10000; # 65536 words of RAM
	
	my @memory = ();
	
	# Zero out memory initially
	for (my $i = 0; $i < $n_memory_words; $i++) {
		$memory[$i] = 0;
	}
	
	my $self = {
		# General purpose registers
		registers => {
			'A' => 0,
			'B' => 0,
			'C' => 0,
			'X' => 0,
			'Y' => 0,
			'Z' => 0,
			'I' => 0,
			'J' => 0,
		},
		
		# Special purpose registers
		PC => 0, # Program Counter
		SP => 0, # Stack Pointer
		EX => 0, # Excess
		IA => 0, # Interupt address

		# Memory
		word_size => 0x10000, # 16 bit word
		n_memory_words => $n_memory_words,
		memory => \@memory,

		# Interrupt queue
		interrupt_queue => [],

		# Interrupt queueing
		interrupt_queueing => 0,
		
		# Registered hardware devices
		hardware_devices => [],
	};

	bless($self);
	
	return $self;
}

# Read a general purpose register
sub read_register {
	my ($self, $mnemonic) = @_;
	
	if (exists($self->{registers}->{$mnemonic})) {
		return $self->{registers}->{$mnemonic};
	}
	
	die "Error: unknown register: $mnemonic\n";
}

# Write to a general purpose register
sub write_register {
	my ($self, $mnemonic, $value) = @_;

	print "write_register($mnemonic, $value)\n" if $debug;
	
	unless (exists($self->{registers}->{$mnemonic})) {
		die "Error: unknown register: $mnemonic\n";		
	}
	
	$value = $self->wrap($value);
	
	$self->{registers}->{$mnemonic} = $value;
}

# Read the program counter
sub read_program_counter {
	my $self = shift;
	
	return $self->{PC};
}

# Write to the program counter
sub write_program_counter {
	my ($self, $value) = @_;
	
	unless ($value >= 0 && $value < $self->{word_size}) {
		die "Illegal program counter value: $value\n";
	}

	# Try to detect infinite loops (e.g., :crash SET PC, crash)
	#die "HALT\n" if $PC == $value + 2;

	$self->{PC} = $value;
}

# Read the stack pointer
sub read_stack_pointer {
	my $self = shift;
	
	return $self->{SP};
}

# Write to the stack pointer
sub write_stack_pointer {
	my ($self, $value) = @_;

	print "write_stack_pointer($value)\n" if $debug;
	
	$value = $self->wrap($value);

	print "wrapped: write_stack_pointer($value)\n" if $debug;
	
	$self->{SP} = $value;
}

# Read the excess register
sub read_excess {
	my $self = shift;
	
	return $self->{EX};
}

# Write to the excess register
sub write_excess {
	my ($self, $value) = @_;
	
	unless ($value >= 0 && $value < $self->{word_size}) {
		die "Illegal excess value: $value\n";
	}

	$self->{EX} = $value;
}

# Read the interupt address
sub read_interrupt_address {
	my $self = shift;
	
	return $self->{IA};
}

# Write to the interupt address
sub write_interrupt_address {
	my ($self, $value) = @_;
	
	unless ($value >= 0 && $value < $self->{word_size}) {
		die "Illegal interupt address value: $value\n";
	}

	$self->{IA} = $value;
}

# Read a location in memory
sub read_memory {
	my ($self, $address) = @_;
	unless ($address >= 0 && $address < $self->{n_memory_words}) {
		die "Illegal memory address: $address";
	}
	return $self->{memory}->[$address];
}

# Write to a location in memory
sub write_memory {
	my ($self, $address, $value) = @_;

	print "write_memory($address, $value)\n" if $debug;

	$value = $self->wrap($value);

	# Video RAM
	# if ($address >= 0x8000 && $address < 0x8180) {
	# 	if ($value != 0) {
	# 		Monitor::draw_character($address, $value);
	# 	}
	# }
	
	$self->{memory}->[$address] = $value;
}

sub trigger_interrupt {
	my ($self, $message) = @_;

	print "DCPU received interrupt\n" if $debug;

	my $IA = $self->read_interrupt_address();
	
	if ($IA) {
		if ($self->get_interrupt_queueing()) {
			$self->enqueue_interrupt($message);
		}
		else {
			# Turn on interrupt queueing
			$self->set_interrupt_queueing(1);

			# Push program counter to the stack
			$self->push_stack($self->read_program_counter());

			# Push register A to the stack
			$self->push_stack($self->read_register('A'));

			# Set program counter to interrupt address
			$self->write_program_counter($IA);

			# Set register A to the interrupt message
			$self->write_register('A', $message);
		}
	}
}

sub push_stack {
	my ($self, $value) = @_;

	print "push_stack($value)\n" if $debug;
	
	my $stack_pointer = $self->read_stack_pointer();
	my $new_stack_pointer = $stack_pointer - 1;
	
	$self->write_stack_pointer($new_stack_pointer);
	$self->write_memory($new_stack_pointer, $value);
}

sub pop_stack {
	my ($self) = @_;
	
	my $stack_pointer = $self->read_stack_pointer();
	my $new_stack_pointer = $stack_pointer + 1;
	
	$self->write_stack_pointer($new_stack_pointer);
	
	return $self->read_memory($stack_pointer);
}

# Add an interrupt to the interrupt queue
sub enqueue_interrupt {
	my ($self, $message) = @_;
	
	push @{ $self->{interrupt_queue} }, $message;
}

# Remove an interrupt from the interrupt queue
sub dequeue_interrupt {
	my $self = shift;
	
	return shift @{ $self->{interrupt_queue} };
}

sub get_interrupt_queueing {
	my $self = shift;
	
	return $self->{interrupt_queueing};
}

sub set_interrupt_queueing {
	my ($self, $value) = @_;
	
	$self->{interrupt_queueing} = $value;
}

sub register_hardware_device {
	my ($self, $hardware_device) = @_;
	push @{ $self->{hardware_devices} }, $hardware_device;
}

sub get_hardware_device {
	my ($self, $index) = @_;
	
	if ($index < 0 || $index >= scalar @{ $self->{hardware_devices} }) {
		die "No such hardware device: $index\n";
	}
	return $self->{hardware_devices}->[$index];
}

# Get the number of connected hardware devices
sub get_n_hardware_devices {
	my $self = shift;
	
	return scalar @{ $self->{hardware_devices} };
}

# Load binary data from a file into RAM
sub load_data {
	my ($self, $input_file_name, $memory_address) = @_;

	open(my $in, '<:raw', $input_file_name);

	while(my $word = DCPU::read_word($in)) {
		$self->write_memory($memory_address, DCPU::bin2dec($word));
		$memory_address++;
	}
	
	close $in;
}

# Dump the state of the VM to the terminal
sub dump_machine_state {
	my $self = shift;
	
	$self->dump_registers();
	$self->dump_memory();
}

sub dump_registers {
	my ($self, $format) = " %s: %04x";
	
	for my $mnemonic (('A', 'B', 'C', 'X', 'Y', 'Z', 'I', 'J')) {
		printf($format, $mnemonic, $self->read_register($mnemonic) );
	}
	
	printf $format, 'EX', $self->read_excess();
	printf $format, 'SP', $self->read_stack_pointer();
	printf $format, 'PC', $self->read_program_counter();
	printf $format, 'IA', $self->read_interrupt_address();
	print "\n";
}

sub dump_memory {
	my $self = shift;
	
	$self->print_memory_bank(0x0);
	#$self->print_memory_bank(0x08);
	#$self->print_memory_bank(0x10);
	#$self->print_memory_bank(0x18);
	#$self->print_memory_bank(0x2000);
	#$self->print_memory_bank(0x2008);
	$self->print_memory_bank(0x8000);
	#$self->print_memory_bank(0x8180);
	#$self->print_memory_bank(0x8188);
	$self->print_memory_bank(0x10000 - 8);
}

sub print_memory_bank {
	my ($self, $starting_address) = @_;
	for (my $memory_address = $starting_address; $memory_address < $starting_address + 8; $memory_address++) {
		$self->print_memory_location($memory_address);
	}
}

sub print_memory_location {
	my ($self, $memory_address) = @_;
	
	if ($memory_address % 8 == 0) {
		printf "\t0x%04x:", $memory_address
	}
	printf " %04x", $self->read_memory($memory_address);
	if ((($memory_address + 1) % 8) == 0) {
		print "\n";
	}
}

sub wrap {
	my ($self, $value) = @_;

	#die "wrapping undefined value" unless defined $value;
	
	#print "wrap($value)\n" if $debug;
	
	if ($value >= $self->{word_size}) {
		#print "Overflowing value: $value\n" if $debug;
		$value =  $self->wrap($value - $self->{word_size});
	}
	if ($value < 0) {
		#print "Underflowing value: $value\n" if $debug;
		$value = $self->wrap($value + $self->{word_size});
	}

	#print "returning $value\n";
	return $value;
}
1;
