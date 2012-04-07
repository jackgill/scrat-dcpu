use strict;
use warnings;
use autodie;

#########################################
my %op_codes = (
	'SET' => 0x1, # sets a to b
	'ADD' => 0x2, # sets a to a+b, sets O to 0x0001 if there's an overflow, 0x0 otherwise
	'SUB' => 0x3, # sets a to a-b, sets O to 0xffff if there's an underflow, 0x0 otherwise
	'MUL' => 0x4, # sets a to a*b, sets O to ((a*b)>>16)&0xffff
	'DIV' => 0x5, # sets a to a/b, sets O to ((a<<16)/b)&0xffff. if b==0, sets a and O to 0 instead.
	'MOD' => 0x6, # sets a to a%b. if b==0, sets a to 0 instead.
	'SHL' => 0x7, # sets a to a<<b, sets O to ((a<<b)>>16)&0xffff
	'SHR' => 0x8, # sets a to a>>b, sets O to ((a<<16)>>b)&0xffff
	'AND' => 0x9, # sets a to a&b
	'BOR' => 0xa, # sets a to a|b
	'XOR' => 0xb, # sets a to a^b
	'IFE' => 0xc, # performs next instruction only if a==b
	'IFN' => 0xd, # performs next instruction only if a!=b
	'IFG' => 0xe, # performs next instruction only if a>b
	'IFB' => 0xf, # performs next instruction only if (a&b)!=0
	);

my %values = (
	'A' => 0x00, # Register A
	'B' => 0x01, # Register B
	'C' => 0x02, # Register C
	'X' => 0x03, # Register X
	'Y' => 0x04, # Register Y
	'Z' => 0x05, # Register Z
	'I' => 0x06, # Register I
	'J' => 0x07, # Register J
	'[A]' => 0x08, # Value of register A
	'[B]' => 0x09, # Value of register B
	'[C]' => 0x0a, # Value of register C
	'[X]' => 0x0b, # Value of register X
	'[Y]' => 0x0c, # Value of register Y
	'[Z]' => 0x0d, # Value of register Z
	'[I]' => 0x0e, # Value of register I
	'[J]' => 0x0f, # Value of register J
	'[next word + A]' => 0x10,
	'[next word + B]' => 0x11,
	'[next word + C]' => 0x12,
	'[next word + X]' => 0x13,
	'[next word + Y]' => 0x14,
	'[next word + Z]' => 0x15,
	'[next word + I]' => 0x16,
	'[next word + J]' => 0x17,
	'POP' => 0x18,
	'PEEK' => 0x19,
	'PUSH' => 0x1a,
	'SP' => 0x1b,
	'PC' => 0x1c,
	'O' => 0x1d,
	'[next word]' => 0x1e,
	'next word' => 0x1f,
	);
################################################

if (@ARGV != 1) {
	die "Usage: $0 file.asm";
}

my $input_file_name = $ARGV[0];
my $output_file_name = $input_file_name;
$output_file_name =~ s/\.asm/\.o/; # TODO: make this less hacky

open(my $out, '>:raw', $output_file_name); # Write output to a binary file
open(my $in, '<', $input_file_name);

my $line_number = 0;
while(<$in>) {
	# Strip newline
	chomp;

	# Discard comments
	my $line = (split /;/)[0];

	# Strip leading and trailing whitespace
	$line =~ s/^\s*//;
	$line =~ s/\s*$//;

	# Check syntax
	# TODO: check for unbalanced brackets
	unless ($line =~ /
	^
	(\w{3})
	\s+
	(\[? \s* [\w\d]+ (?:\s*\+\s*\w)? \s* \]?)
	\s*
	,
	\s+
	(\[? \s* [\w\d]+ (?:\s*\+\s*\w)? \s* \]?)
	$
	/x) {
		die "Syntax error on line $line_number:\n$line\n";
	}

	# Extract mnemonic and operands
	my $mnemonic = $1;
	my $first_operand = $2;
	my $second_operand = $3;
	
	#print $line, "\n";
	#print "Mnemonic: $mnemonic\n";
	#print "First operand: $first_operand\n";
	#print "Second operand: $second_operand\n";

	# Convert mnemonic to op code
	unless (exists($op_codes{$mnemonic})) {
		die "Error: unrecognized mnemonic: $mnemonic\n(on line $line_number)\n";
	}
	my $op_code = $op_codes{$mnemonic};

	# Convert operands to values
	my $additional_words = [];
	my $instruction_bit_length = 16;
	my $first_value = encode_value($first_operand, $additional_words);
	my $second_value = encode_value($second_operand, $additional_words);
	
	# Build instruction
	my $text_instruction = sprintf("%06b%06b%04b", $second_value, $first_value, $op_code);
	
	for my $additional_word (@{ $additional_words }) {
		$instruction_bit_length += 16;
		$text_instruction .=  $additional_word;
	}
	
	my $binary_instruction = pack("B$instruction_bit_length", $text_instruction);

	printf "%-20s $text_instruction\n", $line;

	# Write instruction
	print $out $binary_instruction;

	# Increment line number
	$line_number++;
}

close($in);
close($out);
print "Wrote $output_file_name\n";


###############################################
sub encode_value {
	my ($value, $additional_words_ref) = @_;
	#print "encode_value($value)\n";
	
	if ($value =~ /^0x\d{4}$/) { # Literal
		#print "literal\n";
		push @{ $additional_words_ref }, encode_literal($value);
		return $values{'next word'};
	}
	elsif ($value =~ /\[\s*(0x\d{4})\s*\]/) { # [literal]
		#print "[literal]\n";
		push @{ $additional_words_ref }, encode_literal($1);
		return $values{'[next word]'};
	}
	elsif ($value =~ /\[\s*(0x\d{4})\s*\+\s*(\w)\s*\]/) { # [literal + register]
		#print "[literal + register]\n";
		my $literal = $1;
		my $register = $2;
		unless ($register =~ /[ABCXYZIJ]/i) {
			die "Unknown register: $register (line $line_number)\n";
		}
		push @{ $additional_words_ref }, encode_literal($literal);
		return $values{"[next word + $register]"};
	}
	elsif(exists($values{$value})) {
		#print "value\n";
		return $values{$value};	
	}
	return undef;
}

sub encode_literal {
	my $value = shift;
	#print "encode_literal($value) = ";
	if ($value =~ /0x\d{4}/) {
		my $num = hex($value); # TODO: validate number size
		my $bin = sprintf("%016b", $num);
		#print "$bin\n";
		return $bin;
	}
	die "Error: illegal literal: $value\n(on line $line_number)\n";
}
