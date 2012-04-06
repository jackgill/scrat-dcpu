use strict;
use warnings;

use DCPU;

# Define programming environment
my $A = 0; # Register A
my $B = 0; # Register B
my $C = 0; # Register C
my $X = 0; # Register X
my $Y = 0; # Register Y
my $Z = 0; # Register Z
my $I = 0; # Register I
my $J = 0; # Register J
my $PC = 0; # Program Counter
my $SP = 0; # Stack Pointer
my $O = 0; # Overflow

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

# Define registers
my %registers = (
	0x00 => \$A,
	0x01 => \$B,
	0x02 => \$C,
	0x03 => \$X,
	0x04 => \$Y,
	0x05 => \$Z,
	0x06 => \$I,
	0x07 => \$J,
	);

# Parse command line arguments
if (@ARGV != 1) {
	die "Usage: $0 file.asm";
}

my $input_file_name = $ARGV[0];

open(my $in, '<:raw', $input_file_name);

dump_registers();

my $line_number = 0;
while(read($in, my $packed_word, 2)) {
	my $word = unpack('B16', $packed_word);
	my $assembly = disassemble_instruction($word);
	print "$assembly\n";
	
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

	# Invoke operator
	&$operator_ref($first_value, $second_value);

	# Dump registers
	dump_registers();
}

sub get_operator {
	my ($op_code) = @_;
	if (exists($operators{$op_code})) {
		return $operators{$op_code};
	}
	die "Unrecognized op_code: $op_code (line $line_number)\n";
}

sub get_register {
	my ($value) = @_;
	if (exists($registers{$value})) {
		return $registers{$value};
	}
	return undef;
}

sub get_value {
	my ($value) = @_;
	return $value - 32;
}

sub dump_registers {
	for my $value (sort(keys %registers)) {
		printf("\t%s: %#04x", get_value_mnemonic($value), ${ $registers{$value} });
	}
	print "\n";
}

sub bin2dec {
    return unpack("N", pack("B32", substr("0" x 32 . shift, -32)));
}

sub not_implemented {
	my ($mnemonic) = @_;
	die "$mnemonic is not implemented.\n";
}

# Operators

sub SET {
	my ($first_operand, $second_operand) = @_;
	my $register_ref = get_register($first_operand);
	unless ($register_ref) {
		die "First argument of SET must be a register. Invalid register: $first_operand (line $line_number)\n";
	}
	my $literal = get_value($second_operand);

	$$register_ref = $literal
}
