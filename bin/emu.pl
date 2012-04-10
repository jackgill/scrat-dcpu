use strict;
use warnings;
use autodie;
use 5.010;
use lib 'lib';

use DCPU;
use VM;

# Define operators
my %operators = (
	0x1 => \&SET,
	0x2 => \&ADD,
	0x3 => \&SUB,
	0x4 => \&MUL,
	0x5 => \&DIV,
	0x6 => \&MOD,
	0x7 => \&SHL,
	0x8 => \&SHR,
	0x9 => \&AND,
	0xa => \&BOR,
	0xb => \&XOR,
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

	$line_number++;
}

# build an expression for an operand
sub resolve_operand {
	my ($value, $words_ref) = @_;
	#print "Resolve $value...";
	if (($value >= 0x00 && $value <= 0x0f) ||
		($value >= 0x1b && $value <= 0x1d)) { # register, [register], and special-purpose registers (SP, PC, O)
		my $mnemonic = get_value_mnemonic($value);
		#print "resolved to register $mnemonic\n";
		return $mnemonic;
	}
	elsif($value == 0x18) { # POP
		my $stack_pointer = read_stack_pointer();

		# increment stack pointer
		my $new_value = $stack_pointer + 1;
		
		# Apparently wrapping is called for by the spec
		# Putting in a warning until I feel comfortable with this
		if ($new_value >= 0x10000 ) {
			my $wrapped_value = $new_value - 0x10000;
			print "Warning: wrapping stack pointer from $new_value to $wrapped_value\n";
			$new_value = $wrapped_value;
		}

		write_stack_pointer($new_value);
		return "[$stack_pointer]";
	}
	elsif($value == 0x19) { # PEEK
		my $stack_pointer = read_stack_pointer();
		return "[$stack_pointer]";
	}
	elsif($value == 0x1a) { # PUSH
		my $stack_pointer = read_stack_pointer();
		my $new_value = $stack_pointer - 1;
		
		# Apparently wrapping is called for by the spec
		# Putting in a warning until I feel comfortable with this
		if ($new_value < 0) {
			my $wrapped_value = $new_value + 0x10000;
			print "Warning: wrapping stack pointer from $new_value to $wrapped_value\n";
			$new_value = $wrapped_value;
		}
		write_stack_pointer($new_value);
		return "[$new_value]";
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
	
	die "Unable to resolve operand $value (line $line_number)\n";
}

# get the subroutine that implements an opcode
sub get_operator {
	my ($op_code) = @_;
	if (exists($operators{$op_code})) {
		return $operators{$op_code};
	}
	die "Unrecognized op_code: $op_code (line $line_number)\n";
}

# read the value represented by an arbitrary expression
sub read_value {
	my $expression = shift;
	if ($expression =~ /^\d+$/) { # literal
		return $expression;
	}
	elsif ($expression =~ /\[(\d+)\]/) { # Memory
		return read_memory($1);
	}
	# TODO: need to sort out difference between A and [A] as lvalues and rvalues
	elsif ($expression =~ /^(\w)$/) { # Register
		return read_register($1);
	}
	elsif ($expression =~ /\[(\w)\]/) { # [Register]
		return read_register($1);
	}
	elsif ($expression =~ /\[(\d+) \+ (\w)\]/) { # [literal + register]
		return read_memory($1 + read_register($2));
	}
	die "Error: read_value unrecognized expression: $expression\n";
}

# write the value represented by an arbitrary expression to the location represented by another arbitrary expression
sub write_value {
	my ($left_expression, $right_expression) = @_;
	my $right_value = read_value($right_expression);

	if ($left_expression =~ /^\d+$/) { # literal
		# Spec says to silently ignore this but I'm a rebel
		die "Error: write_value attempt to assign to a literal\n";
	}
	elsif ($left_expression =~ /^\w$/) { # Register
		write_register($left_expression, $right_value);
	}
	elsif ($left_expression =~ /\[(\d+)\]/) { # Memory
		write_memory($1, $right_value);
	}
	elsif ($left_expression =~ /\[(\d+) \+ (\w)\]/) { # [literal + register]
		return write_memory($1 + read_register($2), $right_value);
	}
	else {
		die "Error: write_value unrecognized expression: $left_expression\n";
	}
}

# Operators

# SET a, b - sets a to b
sub SET {
	my ($first_operand, $second_operand) = @_;
	#print "SET($first_operand, $second_operand)\n";
	write_value($first_operand, $second_operand);
}

# ADD a, b - sets a to a+b, sets O to 0x0001 if there's an overflow, 0x0 otherwise
sub ADD {
	my ($first_operand, $second_operand) = @_;

	my $first_value = read_value($first_operand);
	my $second_value = read_value($second_operand);
	
	my $result = $first_value + $second_value;
	
	if ($result > $VM::word_size) {
		write_overflow(0x0001);
	}
	else {
		write_overflow(0x0000);
	}
	
	write_value($first_operand, $result);
}

# SUB a, b - sets a to a-b, sets O to 0xffff if there's an underflow, 0x0 otherwise
sub SUB {
	my ($first_operand, $second_operand) = @_;

	my $first_value = read_value($first_operand);
	my $second_value = read_value($second_operand);
	
	my $result = $first_value - $second_value;
	
	if ($result < 0) {
		write_overflow(0xffff);
	}
	else {
		write_overflow(0x0000);
	}
	
	write_value($first_operand, $result);
}

# MUL a, b - sets a to a*b, sets O to ((a*b)>>16)&0xffff
sub MUL {
	my ($first_operand, $second_operand) = @_;

	my $first_value = read_value($first_operand);
	my $second_value = read_value($second_operand);
	
	my $result = $first_value * $second_value;

	write_overflow( (($first_value * $second_value) >> 16) & 0xffff);
	
	write_value($first_operand, $result);
}

# DIV a, b - sets a to a/b, sets O to ((a<<16)/b)&0xffff. if b==0, sets a and O to 0 instead.
sub DIV {
	my ($first_operand, $second_operand) = @_;

	my $first_value = read_value($first_operand);
	my $second_value = read_value($second_operand);
	
	my $result = int($first_value / $second_value);

	write_overflow( (($first_value << 16) / $second_value) & 0xffff);
	
	write_value($first_operand, $result);
}

# MOD a, b - sets a to a%b. if b==0, sets a to 0 instead.
sub MOD {
	my ($first_operand, $second_operand) = @_;

	my $first_value = read_value($first_operand);
	my $second_value = read_value($second_operand);
	
	if ($second_value == 0) {
		write_value($first_operand, 0);
	}
	else {
		my $result = $first_value % $second_value;
		write_value($first_operand, $result);
	}
}

# SHL a, b - sets a to a<<b, sets O to ((a<<b)>>16)&0xffff
sub SHL {
	my ($first_operand, $second_operand) = @_;

	my $first_value = read_value($first_operand);
	my $second_value = read_value($second_operand);
	
	my $result = $first_value << $second_value;

	write_overflow( (($first_value << $second_value) >> 16) & 0xffff);
	
	write_value($first_operand, $result);
}

# SHR a, b - sets a to a>>b, sets O to ((a<<16)>>b)&0xffff
sub SHR {
	my ($first_operand, $second_operand) = @_;

	my $first_value = read_value($first_operand);
	my $second_value = read_value($second_operand);
	
	my $result = $first_value >> $second_value;

	write_overflow( (($first_value << 16) >> $second_value) & 0xffff);
	
	write_value($first_operand, $result);
}

# AND a, b - sets a to a&b
sub AND {
	my ($first_operand, $second_operand) = @_;

	my $first_value = read_value($first_operand);
	my $second_value = read_value($second_operand);
	
	my $result = $first_value & $second_value;
	
	write_value($first_operand, $result);
}

# BOR a, b - sets a to a|b
sub BOR {
	my ($first_operand, $second_operand) = @_;

	my $first_value = read_value($first_operand);
	my $second_value = read_value($second_operand);
	
	my $result = $first_value | $second_value;
	
	write_value($first_operand, $result);
}

# XOR a, b - sets a to a^b
sub XOR {
	my ($first_operand, $second_operand) = @_;

	my $first_value = read_value($first_operand);
	my $second_value = read_value($second_operand);
	
	my $result = $first_value ^ $second_value;
	
	write_value($first_operand, $result);
}
sub notimplemented {
	die "Not implemented.\n";
}

