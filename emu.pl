use strict;
use warnings;
use 5.010;

use DCPU;

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
my $n_memory_words = 0x10000;
my $memory = [];
# Zero out memory initially
for (my $i = 0; $i < $n_memory_words; $i++) {
	$memory->[$i] = 0;
}

# Define operators
my %operators = (
	0x1 => \&SET, # a, b - sets a to b
	0x2 => \&notimplemented, # a, b - sets a to a+b, sets O to 0x0001 if there's an overflow, 0x0 otherwise
	0x3 => \&notimplemented, # a, b - sets a to a-b, sets O to 0xffff if there's an underflow, 0x0 otherwise
	0x4 => \&notimplemented, # a, b - sets a to a*b, sets O to ((a*b)>>16)&0xffff
	0x5 => \&notimplemented, # a, b - sets a to a/b, sets O to ((a<<16)/b)&0xffff. if b==0, sets a and O to 0 instead.
	0x6 => \&notimplemented, # a, b - sets a to a%b. if b==0, sets a to 0 instead.
	0x7 => \&notimplemented, # a, b - sets a to a<<b, sets O to ((a<<b)>>16)&0xffff
	0x8 => \&notimplemented, # a, b - sets a to a>>b, sets O to ((a<<16)>>b)&0xffff
	0x9 => \&notimplemented, # a, b - sets a to a&b
	0xa => \&notimplemented, # a, b - sets a to a|b
	0xb => \&notimplemented, # a, b - sets a to a^b
	0xc => \&notimplemented, # a, b - performs next instruction only if a==b
	0xd => \&notimplemented, # a, b - performs next instruction only if a!=b
	0xe => \&notimplemented, # a, b - performs next instruction only if a>b
	0xf => \&notimplemented, # a, b - performs next instruction only if (a&b)!=0
	);


# Parse command line arguments
if (@ARGV != 1) {
	die "Usage: $0 file.asm";
}

my $input_file_name = $ARGV[0];

open(my $in, '<:raw', $input_file_name);

dump_machine_state();

my $line_number = 0;
while(my @words = read_instruction($in)) {
	my $word = shift @words;

	# Print instruction
	my $assembly = disassemble_instruction($word);
	print "$assembly";
	for my $word (@words) {
		printf(" 0x%04x", bin2dec($word));
	}
	print "\n";
	
	# Unpack instruction
	unless ($word =~ /^
	([01]{6})
	([01]{6})
	([01]{4})$/x) {
		die "Invalid instruction: $word (line $line_number)\n";
	}
	my $second_value = bin2dec($1);
	my $first_value = bin2dec($2);
	my $op_code = bin2dec($3);

	# Decode operator
	my $operator_ref = get_operator($op_code);

	# Resolve operands
	my $words_ref = \@words;
	my $first_operand = resolve_operand($first_value, $words_ref);
	my $second_operand = resolve_operand($second_value, $words_ref);
	
	# Invoke operator
	&$operator_ref($first_operand, $second_operand);

	# Dump machine state
	dump_machine_state();
}

sub resolve_operand {
	my ($value, $words_ref) = @_;
	#print "Resolve $value...";
	if ($value >= 0x00 && $value <= 0x07) { # Register
		my $mnemonic = get_value_mnemonic($value);
		#print "resolved to register $mnemonic\n";
		return $mnemonic;
	}
	elsif ($value == 0x1f) { # next word (literal)
		my $next_word = shift @{ $words_ref };
		my $literal = bin2dec($next_word);
		#print "resolved to literal $literal\n";
		return $literal;
	}
	elsif ($value == 0x1e) { # [next word] (memory location)
		my $next_word = shift @{ $words_ref };
		my $address = '[' . bin2dec($next_word) . ']';
		#print "resolved to memory address $address\n";
		return $address;
	}
	elsif ($value >= 0x10 && $value <= 0x17) { # [next word + register]
		my $next_word = shift @{ $words_ref };
		my $address = bin2dec($next_word);
		my $register = '';
		given ($value) {
			when(0x10) { $register = 'A' }
			when(0x11) { $register = 'B' }
			when(0x12) { $register = 'C' }
			when(0x13) { $register = 'X' }
			when(0x14) { $register = 'Y' }
			when(0x15) { $register = 'Y' }
			when(0x16) { $register = 'I' }
			when(0x17) { $register = 'J' }
		}
		return "[$address + $register]";
	}
	die "Unable to resolve operand $value (line $line_number)\n";
}

sub get_operator {
	my ($op_code) = @_;
	if (exists($operators{$op_code})) {
		return $operators{$op_code};
	}
	die "Unrecognized op_code: $op_code (line $line_number)\n";
}

sub get_value {
	my ($value) = @_;
	return $value - 32;
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
	unless ($value >= 0 && $value < 65536) {
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
	unless ($value >= 0 && $value < 65536) {
		die "Illegal memory value: $value\n";
	}
	$memory->[$address] = $value;
}

# VM diagnostics
sub dump_machine_state {
	dump_registers();
	dump_memory();
}
sub dump_registers {
	for my $mnemonic (('A', 'B', 'C', 'X', 'Y', 'Z', 'I', 'J')) {
		printf("\t%s: %04x", $mnemonic, read_register($mnemonic) );
	}
	print "\n";
}

sub dump_memory {
	for (my $memory_address = 0; $memory_address < 16; $memory_address++) {
		if ($memory_address % 8 == 0) {
			printf "\t0x%04x:", $memory_address
		}
		printf " %04x", read_memory($memory_address);
		if ((($memory_address + 1) % 8) == 0) {
			print "\n";
		}
	}
}

# Operators

sub SET {
	my ($first_operand, $second_operand) = @_;
	print "SET($first_operand, $second_operand)\n";
	if ($first_operand =~ /^\w$/) { # Register
		write_register($first_operand, read_value($second_operand));
	}
	elsif ($first_operand =~ /\[(\d+)\]/) { # Memory
		write_memory($1, read_value($second_operand));
	}
	else {
		die "Error: SET unrecognized first operand: $first_operand\n";
	}
}

sub not_implemented {
	my ($mnemonic) = @_;
	die "$mnemonic is not implemented.\n";
}

sub read_value {
	my $value = shift;
	if ($value =~ /^\d+$/) { # literal
		return $value;
	}
	elsif ($value =~ /\[(\d+)\]/) { # Memory
		return read_memory($1);
	}
	elsif ($value =~ /\[(\w)\]/) { # Register
		return read_register($1);
	}
	elsif ($value =~ /\[(\d+) \+ (\w)\]/) {# [literal + register]
		return read_memory($1 + read_register($2));
	}
	die "Error: unrecognized value: $value\n";
}
