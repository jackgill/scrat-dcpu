package VM;

use strict;
use warnings;

use Exporter;

our @ISA = qw(Exporter);
our @EXPORT =qw(read_register write_register read_memory write_memory read_overflow write_overflow read_stack_pointer write_stack_pointer dump_registers dump_memory dump_machine_state);

# Define programming environment
my $J = 0; # Register J
my $PC = 0; # Program Counter
my $SP = 0; # Stack Pointer
my $O = 0; # Overflow

# Define registers
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

# Memory
our $word_size = 0x10000; # 16 bit word
my $n_memory_words = 0x10000;
my $memory = [];

# Zero out memory initially
for (my $i = 0; $i < $n_memory_words; $i++) {
	$memory->[$i] = 0;
}

# VM

sub read_register {
	my $mnemonic = shift;
	if (exists($registers{$mnemonic})) {
		return $registers{$mnemonic};
	}
	die "Error: unknown register: $mnemonic\n";
}

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

sub read_memory {
	my $address = shift;
	unless ($address >= 0 && $address < $n_memory_words) {
		die "Illegal memory address: $address\n";
	}
	return $memory->[$address];
}

sub write_memory {
	my ($address, $value) = @_;
	unless ($address >= 0 && $address < $n_memory_words) {
		die "Illegal memory address: $address\n";
	}
	unless ($value >= 0 && $value < $word_size) {
		die "Illegal memory value: $value\n";
	}
	$memory->[$address] = $value;
}

sub read_overflow {
	return $O;
}

sub write_overflow {
	my $value = shift;
	
	unless ($value >= 0 && $value < $word_size) {
		die "Illegal overflow value: $value\n";
	}

	$O = $value;
}

sub read_stack_pointer {
	return $SP;
}

sub write_stack_pointer {
	my $value = shift;

	unless ($value >= 0 && $value < $word_size) {
		die "Illegal stack pointer value: $value\n";
	}

	$SP = $value;
}

# VM diagnostics
sub dump_machine_state {
	dump_registers();
	dump_memory();
}
sub dump_registers {
	my $format = "\t%s: %04x";
	for my $mnemonic (('A', 'B', 'C', 'X', 'Y', 'Z', 'I', 'J')) {
		printf($format, $mnemonic, read_register($mnemonic) );
	}
	printf $format, 'O', read_overflow();
	print "\n";
}

sub dump_memory {
	for (my $memory_address = 0; $memory_address < 16; $memory_address++) {
		print_memory_location($memory_address);
	}
	for (my $memory_address = (0x10000 - 8); $memory_address < 0x10000; $memory_address++) {
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
