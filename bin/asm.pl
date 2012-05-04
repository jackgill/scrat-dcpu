# This script is a two-pass assembler, which reads a text file containing DCPU-16 assembly
# and outputs a binary object code file.

use strict;
use warnings;
use autodie;
use lib 'lib';

use DCPU;

my $debug = 0;

#########################################
my %basic_op_codes = (
	'SET' => 0x01,
	'ADD' => 0x02,
	'SUB' => 0x03,
	'MUL' => 0x04,
	'MLI' => 0x05,
	'DIV' => 0x06,
	'DVI' => 0x07,
	'MOD' => 0x08,
	'MDI' => 0x09,
	'AND' => 0x0a,
	'BOR' => 0x0b,
	'XOR' => 0x0c,
	'SHR' => 0x0d,
	'ASR' => 0x0e,
	'SHL' => 0x0f,
	'IFB' => 0x10,
	'IFC' => 0x11,
	'IFE' => 0x12,
	'IFN' => 0x13,
	'IFG' => 0x14,
	'IFA' => 0x15,
	'IFL' => 0x16,
	'IFU' => 0x17,
	'ADX' => 0x1a,
	'SBX' => 0x1b,
	'STI' => 0x1e,
	'STD' => 0x1f,
	);

my %special_op_codes = (
	'JSR' => 0x01,
	'INT' => 0x08,
	'IAG' => 0x09,
	'IAS' => 0x0a,
	'RFI' => 0x0b,
	'IAQ' => 0x0c,
	'HWN' => 0x10,
	'HWQ' => 0x11,
	'HWI' => 0x12,
	);

my %values = (
	'A' => 0x00,
	'B' => 0x01,
	'C' => 0x02,
	'X' => 0x03,
	'Y' => 0x04,
	'Z' => 0x05,
	'I' => 0x06,
	'J' => 0x07,
	'[A]' => 0x08,
	'[B]' => 0x09,
	'[C]' => 0x0a,
	'[X]' => 0x0b,
	'[Y]' => 0x0c,
	'[Z]' => 0x0d,
	'[I]' => 0x0e,
	'[J]' => 0x0f,
	'[next word + A]' => 0x10,
	'[next word + B]' => 0x11,
	'[next word + C]' => 0x12,
	'[next word + X]' => 0x13,
	'[next word + Y]' => 0x14,
	'[next word + Z]' => 0x15,
	'[next word + I]' => 0x16,
	'[next word + J]' => 0x17,
	'POP' => 0x18,
	'PUSH' => 0x18,
	'PEEK' => 0x19,
	'PICK' => 0x1a,
	'SP' => 0x1b,
	'PC' => 0x1c,
	'EX' => 0x1d,
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

# First pass

open(my $in, '<', $input_file_name);

my $line_number = 0;
my $word_count = 0;
my %labels = ();

# Read assembly file
my @lines = ();
my @instructions = ();
while(my $line = <$in>) {
	# Increment line number
	$line_number++;

	# Strip newline
	chomp $line;

	# Discard comments
	$line = (split /;/, $line)[0];

	# Skip empty lines
	next unless $line;
	
	# Strip leading and trailing whitespace
	$line =~ s/^\s*//;
	$line =~ s/\s*$//;

	# Skip lines w/ only whitespace
	next unless $line;

	# Check syntax
	# TODO: check for unbalanced brackets
	# note that second operand is optional
	unless ($line =~ /
	^
	(?::(\w+)\s+)?                            # label (optional)
	(\w{3})                                   # operator
	\s+
	(\[? \s* [\w\d]+ (?:\s*\+\s*\w)? \s* \]?) # first operand
	\s*
	(?:,                                      # second operand (optional)
	\s+
	(\[? \s* -? \s? [\w\d]+ (?:\s*\+\s*\w)? \s* \]?) 
	)?
	$
	/x) {
		die "Syntax error on line $line_number:\n$line\n";
	}

	# Extract mnemonic and operands
	my $label = $1;
	my $mnemonic = $2;
	my $first_operand = $3;
	my $second_operand = $4;

	if ($debug) {
		print "\n";
		print "$line ($word_count)\n";
		print "Label: $label\n" if $label;
		print "Mnemonic: $mnemonic\n";
		print "First operand: $first_operand\n";
		print "Second operand: $second_operand\n" if defined $second_operand;
		print "\n";
	}

	$labels{$label} = $word_count if $label;

	# Dupe'd w/ second pass
	$word_count++;
	$word_count += get_value_length($first_operand);
	$word_count += get_value_length($second_operand) if defined $second_operand;
	
	push @instructions, [$mnemonic, $first_operand, $second_operand];
	push @lines, $line;
}
close($in);

# Second pass

my $instruction_number = 0;
open(my $out, '>:raw', $output_file_name); # Write output to a binary file
for my $tokens_ref (@instructions) {
	# Unpack tokens
	my ($mnemonic, $first_operand, $second_operand) = @{ $tokens_ref };

	# Convert mnemonic to op code
	my $op_code;
	my $text_instruction;
	my $additional_words = [];
	my $instruction_bit_length = 16;

	# Build first word of instruction
	my $instruction_format = "%06b%05b%05b";
	if (exists($basic_op_codes{$mnemonic})) {
		
		$op_code = $basic_op_codes{$mnemonic};
		
		# Convert operands to values
		my $first_value = encode_value($first_operand, $additional_words);
		my $second_value = encode_value($second_operand, $additional_words);
		
		# Build instruction
		$text_instruction = sprintf($instruction_format, $second_value, $first_value, $op_code);
	}
	elsif (exists($special_op_codes{$mnemonic})) {
		my $value = encode_value($first_operand, $additional_words);
		
		# Build instruction
		$text_instruction = sprintf($instruction_format, $value, $special_op_codes{$mnemonic}, 0);
	}
	else {
		die "Error: unrecognized mnemonic: $mnemonic\n(on line $line_number)\n";
	}

	my @hex_words = ( sprintf("%04x", DCPU::bin2dec($text_instruction)) );

	# Build additional words of instruction
	for my $additional_word (@{ $additional_words }) {
		$instruction_bit_length += 16;
		$text_instruction .=  $additional_word;
		push @hex_words, substr(sprintf("%04x", DCPU::bin2dec($additional_word)), -4);
	}
	
	my $binary_instruction = pack("B$instruction_bit_length", $text_instruction);

	printf "%-30s %s\n", $lines[$instruction_number], join(' ', @hex_words);

	# Write instruction
	print $out $binary_instruction;
	
	# Increment instruction number
	$instruction_number++;
}

close($out);
print "Wrote $output_file_name\n";


###############################################
sub encode_value {
	my ($value, $additional_words_ref) = @_;
	print "encode_value($value)\n" if $debug;
	
	if ($value =~ /^-?\s?(?:(0x[\da-fA-F]{4})|(\d+))$/) { # Literal
		# convert hex to dec if necessary
		$value = hex($value) if $value =~ /^0x/;
		
		if ($value > -2 && $value < 0x1f) { # short form value
			return $value + 0x21;
		}
		else { # long form value
			push @{ $additional_words_ref }, encode_literal($value);
			return $values{'next word'};
		}
	}
	elsif ($value =~ /\[\s*-?\s?(0x[\da-fA-F]{4})\s*\]/) { # [literal]
		#print "[literal]\n";
		push @{ $additional_words_ref }, encode_literal($1);
		return $values{'[next word]'};
	}
	elsif ($value =~ /\[\s*-?\s?(0x[\da-fA-F]{4})\s*\+\s*(\w)\s*\]/) { # [literal + register]
		#print "[literal + register]\n";
		my $literal = $1;
		my $register = $2;
		unless ($register =~ /[ABCXYZIJ]/i) {
			die "Unknown register: $register (line $line_number)\n";
		}
		push @{ $additional_words_ref }, encode_literal($literal);
		return $values{"[next word + $register]"};
	}
	elsif(exists($values{$value})) { # value
		#print "value\n";
		return $values{$value};	
	}
	elsif(exists($labels{$value})) { # label
		push @{ $additional_words_ref }, encode_literal($labels{$value});
		return $values{'next word'};
	}
	else {
		die "Error: unrecognized value: $value\n";
	}
}

sub encode_literal {
	my $value = shift;

	if ($value =~ /^-?\s?0x[\da-fA-F]{1,4}$/) { # hex number
		my $num = hex($value); # TODO: validate number size
		my $bin = substr(sprintf("%016b", $num), -16);
		#print "$bin\n";
		return $bin;
	}
	elsif ($value =~ /^-?\s?\d+$/) { # dec number
		return substr(sprintf("%016b", $value), -16);
	}
	die "Error: illegal literal: $value\n(on line $line_number)\n";
}

# TODO: redundant w/ should_read_next_instruction?
sub get_value_length {
	my ($value) = @_;

	print "get_value_length($value)\n" if $debug;
	
	if ($value =~ /^(0x[\da-fA-F]{4})|(\d+)$/) { # Literal
		# convert hex to dec if necessary
		$value = hex($value) if $value =~ /^0x/;
		
		if ($value > -2 && $value < 0x1f) { # short form value
			return 0;
		}
		else { # long form value
			return 1;
		}
	}
	elsif ($value =~ /\[\s*(0x[\da-fA-F]{4})\s*\]/) { # [literal]
		return 1;
	}
	elsif ($value =~ /\[ \s* (0x\d{4}) \s* \+ \s* (\w) \s* \]/x) { # [literal + register]
		return 1;
	}
	elsif(exists($values{$value})) { # value
		return 0;
	}
	elsif($value =~ /\w+/) { # label
		return 1;
	}
	else {
		die "Error: get_value_length: unrecognized value: $value\n";
	}
}
