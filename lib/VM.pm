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

use Exporter;
use DCPU;
use Monitor;

our @ISA = qw(Exporter);
our @EXPORT = qw(
read_register
write_register

read_program_counter
write_program_counter

read_stack_pointer
write_stack_pointer

read_excess
write_excess

read_interupt_address
write_interupt_address

read_memory
write_memory

load_data

dump_machine_state
);

# Variables containing VM state:

# General purpose registers
my %registers = (
	'A' => 0,
	'B' => 0,
	'C' => 0,
	'X' => 0,
	'Y' => 0,
	'Z' => 0,
	'I' => 0,
	'J' => 0,
	);

# Special purpose registers
my $PC = 0; # Program Counter
my $SP = 0; # Stack Pointer
my $EX = 0; # Excess
my $IA = 0; # Interupt address

# Memory
our $word_size = 0x10000; # 16 bit word
my $n_memory_words = 0x10000; # 65536 words of RAM
my $memory = [];

# Zero out memory initially
for (my $i = 0; $i < $n_memory_words; $i++) {
	$memory->[$i] = 0;
}

# Methods for manipulating VM state

# Read a general purpose register
sub read_register {
	my $mnemonic = shift;
	if (exists($registers{$mnemonic})) {
		return $registers{$mnemonic};
	}
	die "Error: unknown register: $mnemonic\n";
}

# Write to a general purpose register
sub write_register {
	my ($mnemonic, $value) = @_;
	unless (exists($registers{$mnemonic})) {
		die "Error: unknown register: $mnemonic\n";		
	}
	unless ($value >= 0 && $value < $word_size) {
		die "Illegal register value: $value\n";
	}
	$registers{$mnemonic} = $value;
}

# Read the program counter
sub read_program_counter {
	return $PC;
}

# Write to the program counter
sub write_program_counter {
	my $value = shift;
	
	unless ($value >= 0 && $value < $word_size) {
		die "Illegal program counter value: $value\n";
	}

	# Try to detect infinite loops (e.g., :crash SET PC, crash)
	#die "HALT\n" if $PC == $value + 2;

	$PC = $value;
}

# Read the stack pointer
sub read_stack_pointer {
	return $SP;
}

# Write to the stack pointer
sub write_stack_pointer {
	my $value = shift;

	unless ($value >= 0 && $value < $word_size) {
		die "Illegal stack pointer value: $value\n";
	}

	$SP = $value;
}

# Read the excess register
sub read_excess {
	return $EX;
}

# Write to the excess register
sub write_excess {
	my $value = shift;
	
	unless ($value >= 0 && $value < $word_size) {
		die "Illegal excess value: $value\n";
	}

	$EX = $value;
}

# Read the interupt address
sub read_interupt_address {
	return $IA;
}

# Write to the interupt address
sub write_interupt_address {
	my $value = shift;
	
	unless ($value >= 0 && $value < $word_size) {
		die "Illegal interupt address value: $value\n";
	}

	$IA = $value;
}

# Read a location in memory
sub read_memory {
	my $address = shift;
	unless ($address >= 0 && $address < $n_memory_words) {
		die "Illegal memory address: $address\n";
	}
	return $memory->[$address];
}

# Write to a location in memory
sub write_memory {
	my ($address, $value) = @_;
	unless ($address >= 0 && $address < $n_memory_words) {
		die "Illegal memory address: $address\n";
	}
	unless ($value >= 0 && $value < $word_size) {
		die "Illegal memory value: $value\n";
	}

	# Video RAM
	if ($address >= 0x8000 && $address < 0x8180) {
		if ($value != 0) {
			Monitor::draw_character($address, $value);
		}
	}
	$memory->[$address] = $value;
}

# Load binary data from a file into RAM
sub load_data {
	my ($input_file_name, $memory_address) = @_;

	open(my $in, '<:raw', $input_file_name);

	while(my $word = DCPU::read_word($in)) {
		write_memory($memory_address, DCPU::bin2dec($word));
		$memory_address++;
	}
	
	close $in;
}

# Dump the state of the VM to the terminal
sub dump_machine_state {
	dump_registers();
	dump_memory();
}

sub dump_registers {
	my $format = " %s: %04x";
	for my $mnemonic (('A', 'B', 'C', 'X', 'Y', 'Z', 'I', 'J')) {
		printf($format, $mnemonic, read_register($mnemonic) );
	}
	printf $format, 'O', read_overflow();
	printf $format, 'SP', read_stack_pointer();
	printf $format, 'PC', read_program_counter();
	print "\n";
}

sub dump_memory {
	print_memory_bank(0x0);
	#print_memory_bank(0x08);
	#print_memory_bank(0x10);
	#print_memory_bank(0x18);
	#print_memory_bank(0x2000);
	#print_memory_bank(0x2008);
	print_memory_bank(0x8000);
	#print_memory_bank(0x8180);
	#print_memory_bank(0x8188);
	print_memory_bank(0x10000 - 8);
}

sub print_memory_bank {
	my $starting_address = shift;
	for (my $memory_address = $starting_address; $memory_address < $starting_address + 8; $memory_address++) {
		print_memory_location($memory_address);
	}
}

sub print_memory_location {
	my $memory_address = shift;
	
	if ($memory_address % 8 == 0) {
		printf "\t0x%04x:", $memory_address
	}
	printf " %04x", read_memory($memory_address);
	if ((($memory_address + 1) % 8) == 0) {
		print "\n";
	}
}

1;
