# DCPU-16 emulator. Provides implementations of all DCPU-16 opcodes.

package Emulator;

use strict;
use warnings;
use autodie;
use 5.010;

use Exporter;
use DCPU;
use VM;
use Monitor;

our @ISA = qw(Exporter);
our @EXPORT = qw(execute_cycle get_current_instruction);

my $debug = 1;

# Define operators
my %basic_operators = (
	0x00 => \&dispatch_special_operator,
	0x01 => \&SET,
	0x02 => \&ADD,
	0x03 => \&SUB,
	0x04 => \&MUL,
	0x05 => \&MLI,
	0x06 => \&DIV,
	0x07 => \&DVI,
	0x08 => \&MOD,
	0x09 => \&MDI,
	0x0a => \&AND,
	0x0b => \&BOR,
	0x0c => \&XOR,
	0x0d => \&SHR,
	0x0e => \&ASR,
	0x0f => \&SHL,
	0x10 => \&IFB,
	0x11 => \&IFC,
	0x12 => \&IFE,
	0x13 => \&IFN,
	0x14 => \&IFG,
	0x15 => \&IFA,
	0x16 => \&IFL,
	0x17 => \&IFU,
	0x1a => \&ADX,
	0x1b => \&SBX,
	0x1e => \&STI,
	0x1f => \&STD,
	);

my %special_operators = (
	0x01 => \&JSR,
	0x08 => \&INT,
	0x09 => \&not_implemented, # IAG
	0x0a => \&not_implemented, # IAS
	0x0b => \&not_implemented, # RFI
	0x0c => \&not_implemented, # IAQ
	0x10 => \&not_implemented, # HWN
	0x11 => \&not_implemented, # HWQ
	0x12 => \&not_implemented, # HWI
	);

my $current_instruction;

sub get_current_instruction {
	return $current_instruction;
}

sub execute_cycle {
	# Read a word from memory
	my $word = VM::read_memory(read_program_counter());

	# Increment program counter
	VM::write_program_counter(read_program_counter() + 1);
	
	# Convert instruction to binary
	my $instruction = sprintf("%016b", $word);
	$instruction =~ $DCPU::instruction_regex;

	# Extract op code and operands in decimal
	my $second_value = DCPU::bin2dec($1);
	my $first_value = DCPU::bin2dec($2);
	my $op_code = DCPU::bin2dec($3);

	if ($op_code == 0) { # Special op code
		# Decode operator
		my $operator_ref = get_special_operator($first_value);

		# Resolve operand
		my $operand = resolve_operand($second_value);

		# Print instruction
		my $operator_mnemonic = DCPU::get_special_opcode_mnemonic($first_value);

		$current_instruction = sprintf("%s %s\n", $operator_mnemonic, $operand);
		
		# Invoke operator
		&$operator_ref($operand);
	}
	else { # Basic instructions
		# Decode operator
		my $operator_ref = get_basic_operator($op_code);

		# Resolve operands
		my $first_operand = resolve_operand($first_value);
		my $second_operand = resolve_operand($second_value);

		# Print instruction
		my $operator_mnemonic = DCPU::get_basic_opcode_mnemonic($op_code);

		$current_instruction = sprintf("%s %s %s\n", $operator_mnemonic, $first_operand, $second_operand);
		
		# Invoke operator
		&$operator_ref($first_operand, $second_operand);
	}

	# Check for queued interrupts
	unless (VM::get_interrupt_queueing()) {
		if (my $interrupt = VM::dequeue_interrupt()) {
			trigger_interrupt($interrupt);
		}
	}
	
	# Dump machine state
	#VM::dump_machine_state();
}


# build an expression for an operand
sub resolve_operand {
	my ($value) = @_;

	print "Resolve $value...\n" if $debug;
	
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
		if ($new_value >= 0x10000 ) {
			my $wrapped_value = $new_value - 0x10000;
			#print "Warning: wrapping stack pointer from $new_value to $wrapped_value\n";
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
		if ($new_value < 0) {
			my $wrapped_value = $new_value + 0x10000;
			#print "Warning: wrapping stack pointer from $new_value to $wrapped_value\n";
			$new_value = $wrapped_value;
		}
		write_stack_pointer($new_value);
		return "[$new_value]";
	}
	elsif ($value >= 0x10 && $value <= 0x17) { # [next word + register]
		my $next_word = read_memory(read_program_counter());
		write_program_counter(read_program_counter() + 1);
		
		my $address = $next_word;
		
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
		my $next_word = read_memory(read_program_counter());
		write_program_counter(read_program_counter() + 1);
		
		my $literal = $next_word;
		#print "resolved to literal $literal\n";
		return $literal;
	}
	elsif ($value == 0x1e) { # [next word] (memory location)
		my $next_word = read_memory(read_program_counter());
		write_program_counter(read_program_counter() + 1);
		
		my $address = "[$next_word]";
		#print "resolved to memory address $address\n";
		return $address;
	}
	elsif ($value >= 0x20 && $value < 0x40) { # short form literal
		return $value - 0x21;
	}
	die "Unable to resolve operand $value\n";
}

# get the subroutine that implements an opcode
sub get_basic_operator {
	my ($op_code) = @_;
	if (exists($basic_operators{$op_code})) {
		return $basic_operators{$op_code};
	}
	die "Unrecognized op_code: $op_code\n";
}

sub get_special_operator {
	my ($op_code) = @_;
	if (exists($special_operators{$op_code})) {
		return $special_operators{$op_code};
	}
	else {
		die "Error: unrecognized special opcode: $op_code\n";
	}
}

# read the value represented by an arbitrary expression
sub read_value {
	my $expression = shift;
	if ($expression =~ /^-?\d+$/) { # literal
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
	elsif ($expression eq 'PC') { # Program counter
		return read_program_counter();
	}
	die "Error: read_value unrecognized expression: $expression\n";
}

# write the value represented by an arbitrary expression to the location represented by another arbitrary expression
sub write_value {
	my ($left_expression, $right_expression) = @_;
	my $right_value = read_value($right_expression);

	# Handle negative values
	if ($right_value < 0) {
		$right_value = DCPU::to_twos_complement($right_value);
	}

	if ($left_expression =~ /^-?\d+$/) { # literal
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
		write_memory($1 + read_register($2), $right_value);
	}
	elsif ($left_expression eq 'PC') { # Program counter
		write_program_counter($right_value);
	}
	else {
		die "Error: write_value unrecognized expression: $left_expression\n";
	}
}

sub skip_next_instruction {
	my $next_word = read_memory(read_program_counter());
	write_program_counter(read_program_counter() + 1);
	
	my $next_bitstring = sprintf("%016b", $next_word);
	$next_bitstring =~ /([01]{6})([01]{6})([01]{4})/;
	
	my $first_value = bin2dec($1);
	my $second_value = bin2dec($2);

	if (should_read_next_word($first_value)) {
		write_program_counter(read_program_counter() + 1);
	}
	if (should_read_next_word($second_value)) {
		write_program_counter(read_program_counter() + 1);
	}
}

sub push_stack {
	my $value = shift;
	my $stack_pointer = read_stack_pointer();
	my $new_stack_pointer = $stack_pointer - 1;
	write_stack_pointer($new_stack_pointer);
	write_memory($new_stack_pointer);
}

sub pop_stack {
	my $stack_pointer = read_stack_pointer();
	my $new_stack_pointer = $stack_pointer + 1;
	write_stack_pointer($new_stack_pointer);
	return read_memory($stack_pointer);
}

# Expects a hashref w/ field 'address' and 'message'
sub trigger_interrupt {
	my $interrupt = shift;

	VM::set_interrupt_queueing(1);
	push_stack(VM::read_program_counter());
	push_stack(VM::read_register('A'));
	VM::set_program_counter($interrupt->{address});
	VM::write_register('A', $interrupt->{message});
}

# Operators

# SET b, a - sets b to a
sub SET {
	my ($first_operand, $second_operand) = @_;

	print "SET($first_operand, $second_operand)\n" if $debug;

	write_value($first_operand, $second_operand);
}

# ADD b, a - sets b to b+a, sets EX to 0x0001 if there's an overflow, 0x0 otherwise
sub ADD {
	my ($first_operand, $second_operand) = @_;

	my $first_value = read_value($first_operand);
	my $second_value = read_value($second_operand);
	
	my $result = $first_value + $second_value;
	
	if ($result > $VM::word_size) {
		write_excess(0x0001);
	}
	else {
		write_excess(0x0000);
	}
	
	write_value($first_operand, $result);
}

# SUB b, a - sets b to b-a, sets EX to 0xffff if there's an underflow, 0x0 otherwise
sub SUB {
	my ($first_operand, $second_operand) = @_;

	my $first_value = read_value($first_operand);
	my $second_value = read_value($second_operand);
	
	my $result = $first_value - $second_value;
	
	if ($result < 0) {
		write_excess(0xffff);
	}
	else {
		write_excess(0x0000);
	}
	
	write_value($first_operand, $result);
}

# MUL b, a - sets b to b*a, sets EX to ((b*a)>>16)&0xffff (treats b, a as unsigned)
sub MUL {
	my ($first_operand, $second_operand) = @_;

	my $first_value = read_value($first_operand);
	my $second_value = read_value($second_operand);
	
	my $result = $first_value * $second_value;

	write_excess( (($first_value * $second_value) >> 16) & 0xffff);
	
	write_value($first_operand, $result);
}

# MLI b, a - like MUL, but treat b, a as signed
sub MLI {
	my ($first_operand, $second_operand) = @_;

	my $first_value = DCPU::from_twos_complement(read_value($first_operand));
	my $second_value = DCPU::from_twos_complement(read_value($second_operand));
	
	my $result = $first_value * $second_value;

	write_excess( (($first_value * $second_value) >> 16) & 0xffff);
	
	write_value($first_operand, $result);
}

# DIV b, a - sets b to b/a, sets EX to ((b<<16)/a)&0xffff. if a==0, sets b and EX to 0 instead. (treats b, a as unsigned)
sub DIV {
	my ($first_operand, $second_operand) = @_;

	my $first_value = read_value($first_operand);
	my $second_value = read_value($second_operand);
	
	my $result = int($first_value / $second_value);

	write_excess( (($first_value << 16) / $second_value) & 0xffff);
	
	write_value($first_operand, $result);
}

# DVI b, a - like DIV, but treat b, a as signed. Rounds towards 0
sub DVI {
	my ($first_operand, $second_operand) = @_;

	my $first_value = DCPU::from_twos_complement(read_value($first_operand));
	my $second_value = DCPU::from_twos_complement(read_value($second_operand));
	
	my $result = int($first_value / $second_value);

	write_excess( (($first_value << 16) / $second_value) & 0xffff);
	
	write_value($first_operand, $result);
}

# MOD b, a - sets b to b%a. if a==0, sets b to 0 instead.
sub MOD {
	my ($first_operand, $second_operand) = @_;

	my $first_value = read_value($first_operand);
	my $second_value = read_value($second_operand);

	print "MOD($first_value, $second_value)\n" if $debug;
	
	if ($second_value == 0) {
		write_value($first_operand, 0);
	}
	else {
		my $result = $first_value % $second_value;
		write_value($first_operand, $result);
	}
}

# MDI b, a - like MOD, but treat b, a as signed. (MDI -7, 16 == -7)
# Note that Notch seems to have defined MDI as a remainder, not a proper modulo:
# http://www.reddit.com/r/dcpu16/comments/stf82/rfe_dcpu16_v15/c4guida
# http://www.reddit.com/r/dcpu16/comments/sxz66/i_have_an_issue_with_the_mdi_instruction/
sub MDI {
	my ($first_operand, $second_operand) = @_;

	my $first_value = DCPU::from_twos_complement(read_value($first_operand));
	my $second_value = DCPU::from_twos_complement(read_value($second_operand));

	print "MDI($first_value, $second_value) = " if $debug;	
	
	if ($second_value == 0) {
		write_value($first_operand, 0);
		print "0\n" if $debug;
	}
	else {
		my $result;
		if ($first_value < 0) {
			$first_value *= -1;
			$result = $first_value % $second_value;
			$result *= -1;
		}
		else {
			$result = $first_value % $second_value;
		}
		print "$result\n" if $debug;
		write_value($first_operand, $result);
	}
}

# AND b, a - sets b to b&a
sub AND {
	my ($first_operand, $second_operand) = @_;

	my $first_value = read_value($first_operand);
	my $second_value = read_value($second_operand);
	
	my $result = $first_value & $second_value;
	
	write_value($first_operand, $result);
}

# BOR b, a - sets b to b|a
sub BOR {
	my ($first_operand, $second_operand) = @_;

	my $first_value = read_value($first_operand);
	my $second_value = read_value($second_operand);
	
	my $result = $first_value | $second_value;
	
	write_value($first_operand, $result);
}

# XOR b, a - sets b to b^a
sub XOR {
	my ($first_operand, $second_operand) = @_;

	my $first_value = read_value($first_operand);
	my $second_value = read_value($second_operand);
	
	my $result = $first_value ^ $second_value;
	
	write_value($first_operand, $result);
}

# SHR b, a - sets b to b>>>a, sets EX to ((b<<16)>>a)&0xffff (logical shift)
# Note that in Java, >>> is an unsigned right shift operator, while >> is a signed right shift.
# In Perl, >> is an unsigned right shift. I think.
sub SHR {
	my ($first_operand, $second_operand) = @_;

	my $first_value = read_value($first_operand);
	my $second_value = read_value($second_operand);
	
	my $result = $first_value >> $second_value;

	write_excess( (($first_value << 16) >> $second_value) & 0xffff);
	
	write_value($first_operand, $result);
}

# ASR b, a - sets b to b>>a, sets EX to ((b<<16)>>>a)&0xffff (arithmetic shift) (treats b as signed)
# See note on SHR.
sub ASR {
	my ($first_operand, $second_operand) = @_;

	my $first_value = DCPU::from_twos_complement(read_value($first_operand));
	my $second_value = read_value($second_operand);
	my $result;
	
	print "ASR($first_value, $second_value) = " if $debug;

	{
		use integer;
		$result = $first_value >> $second_value;
	}
	
	print "$result\n" if $debug;

	write_excess( (($first_value << 16) >> $second_value) & 0xffff);
	
	write_value($first_operand, $result);
}

# SHL b, a - sets b to b<<a, sets EX to ((b<<a)>>16)&0xffff
sub SHL {
	my ($first_operand, $second_operand) = @_;

	my $first_value = read_value($first_operand);
	my $second_value = read_value($second_operand);
	
	my $result = $first_value << $second_value;

	write_excess( (($first_value << $second_value) >> 16) & 0xffff);
	
	write_value($first_operand, $result);
}

# IFB b, a - performs next instruction only if (b&a)!=0
sub IFB {
	my ($first_operand, $second_operand) = @_;

	my $first_value = read_value($first_operand);
	my $second_value = read_value($second_operand);

	unless (($first_value & $second_value) != 0) {
		skip_next_instruction();
	}
}

# IFC b, a - performs next instruction only if (b&a)==0
sub IFC {
	my ($first_operand, $second_operand) = @_;

	my $first_value = read_value($first_operand);
	my $second_value = read_value($second_operand);

	unless (($first_value & $second_value) == 0) {
		skip_next_instruction();
	}
}

# IFE b, a - performs next instruction only if b==a
sub IFE {
	my ($first_operand, $second_operand) = @_;

	my $first_value = read_value($first_operand);
	my $second_value = read_value($second_operand);

	unless ($first_value == $second_value) {
		skip_next_instruction();
	}
}

# IFN b, a - performs next instruction only if b!=a
sub IFN {
	my ($first_operand, $second_operand) = @_;

	my $first_value = read_value($first_operand);
	my $second_value = read_value($second_operand);

	unless ($first_value != $second_value) {
		skip_next_instruction();
	}
}

# IFG b, a - performs next instruction only if b>a
sub IFG {
	my ($first_operand, $second_operand) = @_;

	my $first_value = read_value($first_operand);
	my $second_value = read_value($second_operand);

	unless ($first_value > $second_value) {
		skip_next_instruction();
	}
}

# IFA b, a - performs next instruction only if b>a (signed)
sub IFA {
	my ($first_operand, $second_operand) = @_;

	my $first_value = DCPU::from_twos_complement(read_value($first_operand));
	my $second_value = DCPU::from_twos_complement(read_value($second_operand));

	unless ($first_value > $second_value) {
		skip_next_instruction();
	}
}

# IFL b, a - performs next instruction only if b<a
sub IFL {
	my ($first_operand, $second_operand) = @_;

	my $first_value = read_value($first_operand);
	my $second_value = read_value($second_operand);

	print "IFL($first_value, $second_value)" if $debug;
	
	unless ($first_value < $second_value) {
		skip_next_instruction();
	}
}

# IFU b, a - performs next instruction only if b<a (signed)
sub IFU {
	my ($first_operand, $second_operand) = @_;

	my $first_value = DCPU::from_twos_complement(read_value($first_operand));
	my $second_value = DCPU::from_twos_complement(read_value($second_operand));

	unless ($first_value < $second_value) {
		skip_next_instruction();
	}
}

# ADX b, a - sets b to b+a+EX, sets EX to 0x0001 if there is an overflow, 0x0 otherwise
sub ADX {
	my ($first_operand, $second_operand) = @_;

	my $first_value = read_value($first_operand);
	my $second_value = read_value($second_operand);
	my $excess = VM::read_excess();
	
	my $result = $first_value + $second_value + $excess;
	
	if ($result > $VM::word_size) {
		write_excess(0x0001);
	}
	else {
		write_excess(0x0000);
	}
	
	write_value($first_operand, $result);	
}

# SBX b, a - sets b to b-a+EX, sets EX to 0xFFFF if there is an underflow, 0x0 otherwise
sub SBX {
	my ($first_operand, $second_operand) = @_;

	my $first_value = read_value($first_operand);
	my $second_value = read_value($second_operand);
	my $excess = VM::read_excess();
	
	my $result = $first_value - $second_value + $excess;
	
	if ($result < 0) {
		write_excess(0xffff);
	}
	else {
		write_excess(0x0000);
	}
	
	write_value($first_operand, $result);
}

# STI b, a - sets b to a, then increases I and J by 1
sub STI {
	my ($first_operand, $second_operand) = @_;

	my $first_value = read_value($first_operand);
	my $second_value = read_value($second_operand);

	write_value($first_operand, $second_operand);
	write_value('I', VM::read_register('I') + 1);
	write_value('J', VM::read_register('J') + 1);
}

# STD b, a - sets b to a, then decreases I and J by 1
sub STD {
	my ($first_operand, $second_operand) = @_;

	my $first_value = read_value($first_operand);
	my $second_value = read_value($second_operand);

	write_value($first_operand, $second_operand);
	write_value('I', VM::read_register('I') - 1);
	write_value('J', VM::read_register('J') - 1);
}

# JSR a - pushes the address of the next instruction to the stack, then sets PC to a
sub JSR {
	my $value = shift;

	push_stack(read_program_counter());
	
	write_program_counter($value);
}

# INT a - triggers a software interrupt with message a
sub INT {
	my $message = shift;
	trigger_interrupt({ address => VM::read_interrupt_address, message => $message});
}

sub not_implemented {
	die "Not implemented\n";
}
1;
