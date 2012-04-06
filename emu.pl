use strict;
use warnings;

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
	0x1 => ['SET', \&SET], # a, b - sets a to b
	0x2 => ['ADD', \&not_implemented], # a, b - sets a to a+b, sets O to 0x0001 if there's an overflow, 0x0 otherwise
	0x3 => ['SUB', \&not_implemented], # a, b - sets a to a-b, sets O to 0xffff if there's an underflow, 0x0 otherwise
	0x4 => ['MUL', \&not_implemented], # a, b - sets a to a*b, sets O to ((a*b)>>16)&0xffff
	0x5 => ['DIV', \&not_implemented], # a, b - sets a to a/b, sets O to ((a<<16)/b)&0xffff. if b==0, sets a and O to 0 instead.
	0x6 => ['MOD', \&not_implemented], # a, b - sets a to a%b. if b==0, sets a to 0 instead.
	0x7 => ['SHL', \&not_implemented], # a, b - sets a to a<<b, sets O to ((a<<b)>>16)&0xffff
	0x8 => ['SHR', \&not_implemented], # a, b - sets a to a>>b, sets O to ((a<<16)>>b)&0xffff
	0x9 => ['AND', \&not_implemented], # a, b - sets a to a&b
	0xa => ['BOR', \&not_implemented], # a, b - sets a to a|b
	0xb => ['XOR', \&not_implemented], # a, b - sets a to a^b
	0xc => ['IFE', \&not_implemented], # a, b - performs next instruction only if a==b
	0xd => ['IFN', \&not_implemented], # a, b - performs next instruction only if a!=b
	0xe => ['IFG', \&not_implemented], # a, b - performs next instruction only if a>b
	0xf => ['IFB', \&not_implemented], # a, b - performs next instruction only if (a&b)!=0
	);

# Define registers
my %registers = (
	0x00 => [ 'A', \$A ],
	0x01 => [ 'B', \$B ],
	0x02 => [ 'C', \$C ],
	0x03 => [ 'X', \$X ],
	0x04 => [ 'Y', \$Y ],
	0x05 => [ 'Z', \$Z ],
	0x06 => [ 'I', \$I ],
	0x07 => [ 'J', \$J ],
	);

# Parse command line arguments
if (@ARGV != 1) {
	die "Usage: $0 file.asm";
}

my $input_file_name = $ARGV[0];

open(my $in, '<', $input_file_name);

dump_registers();

my $line_number = 0;
while(<$in>) {
	chomp;
	my $line = $_;

	# Unpack instruction
	unless ($line =~ /^
	([01]{6})
	([01]{6})
	([01]{4})$/x) {
		die "Invalid instruction: $line (line $line_number)\n";
	}
	my $second_value = bin2dec($1);
	my $first_value = bin2dec($2);
	my $op_code = bin2dec($3);

	#print $line, "\n";
	#print "Op code: $op_code\n";
	#print "First value: $first_value\n";
	#print "Second value: $second_value\n";

	# Decode operator
	my ($mnemonic, $operator_ref) = get_operator($op_code);

	# Invoke operator
	&$operator_ref($mnemonic, $first_value, $second_value);

	# Dump registers
	dump_registers();
}

sub get_operator {
	my ($op_code) = @_;
	if (exists($operators{$op_code})) {
		return @{ $operators{$op_code} };
	}
	die "Unrecognized op_code: $op_code (line $line_number)\n";
}

sub get_register {
	my ($value) = @_;
	if (exists($registers{$value})) {
		return @{ $registers{$value} };
	}
	return undef;
}

sub get_value {
	my ($value) = @_;
	return $value - 32;
}

sub dump_registers {
	print "Registers:\n";
	for my $value (sort(keys %registers)) {
		printf("\t%s: %#04x\n", $registers{$value}->[0], ${ $registers{$value}->[1] });
	}
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
	my ($mnemonic, $first_operand, $second_operand) = @_;
	my ($register_name, $register_ref) = get_register($first_operand);
	unless ($register_name) {
		die "First argument of SET must be a register. Invalid register: $first_operand (line $line_number)\n";
	}
	my $literal = get_value($second_operand);
	print "SET $register_name, $literal\n";
	$$register_ref = $literal
}
