use strict;
use warnings;

###########################################
my %value_mnemonics = (
	0x00 => 'A',
	0x01 => 'B',
	0x02 => 'C',
	0x03 => 'X',
	0x04 => 'Y',
	0x05 => 'Z',
	0x06 => 'I',
	0x07 => 'J',
	0x08 => '[A]',
	0x09 => '[B]',
	0x0a => '[C]',
	0x0b => '[X]',
	0x0c => '[Y]',
	0x0d => '[Z]',
	0x0e => '[I]',
	0x0f => '[J]',
	0x10 => '[next word + A]',
	0x11 => '[next word + B]',
	0x12 => '[next word + C]',
	0x13 => '[next word + X]',
	0x14 => '[next word + Y]',
	0x15 => '[next word + Z]',
	0x16 => '[next word + I]',
	0x17 => '[next word + J]',	
	0x18 => 'POP',
	0x19 => 'PEEK',
	0x1a => 'PUSH',
	0x1b => 'SP',
	0x1c => 'PC',
	0x1d => 'O',
	0x1e => '[next word]',
	0x1f => 'next word',
	);

my %opcode_mnemonics = (
	0x1 => 'SET',
	0x2 => 'ADD',
	0x3 => 'SUB',
	0x4 => 'MUL',
	0x5 => 'DIV',
	0x6 => 'MOD',
	0x7 => 'SHL',
	0x8 => 'SHR',
	0x9 => 'AND',
	0xa => 'BOR',
	0xb => 'XOR',
	0xc => 'IFE',
	0xd => 'IFN',
	0xe => 'IFG',
	0xf => 'IFB',
	);

# Parse command line arguments
if (@ARGV != 1) {
	die "Usage: $0 file.o";
}

my $input_file_name = $ARGV[0];

my $line_number = 0;
open(my $in, '<:raw', $input_file_name);
while(read($in, my $packed_word, 2)) {
	my $word = unpack('B16', $packed_word);
	my $assembly = disassemble_instruction($word);
	print "$word $assembly\n";
}
close $in;



#####################################################
sub hex2bitstring {
	my $hex = shift;
	$hex =~ s/^0x//;
	my $num = hex($hex);
	return sprintf("%016b", $num);
}

sub disassemble_instruction {
	my $bitstring = shift;
	unless($bitstring =~ /([01]{6})([01]{6})([01]{4})/) {
		die "Illegal bitstring: $bitstring\n";
	}
	
	my $second_value_bit_string = $1;
	my $first_value_bit_string = $2;
	my $opcode_bit_string = $3;

	my $opcode = bin2dec($opcode_bit_string);
	my $first_value = bin2dec($first_value_bit_string);
	my $second_value = bin2dec($second_value_bit_string);

	my $opcode_mnemonic = get_opcode_mnemonic($opcode);
	my $first_value_mnemonic = get_value_mnemonic($first_value);
	my $second_value_mnemonic = get_value_mnemonic($second_value);
	
	# print "Opcode: $opcode_\n";
	# print "First value: $first_value_\n";
	# print "Second value: $second_value\n\n";

	return "$opcode_mnemonic $first_value_mnemonic, $second_value_mnemonic\n";
}

sub bin2dec {
    return unpack("N", pack("B32", substr("0" x 32 . shift, -32)));
}

sub bin2hex {
	my $bin = shift;
	my $dec = bin2dec($bin);
	my $hex = sprintf('0x%02x', $dec);
	return $hex;
}

sub get_opcode_mnemonic {
	my $opcode = shift;
	if (exists($opcode_mnemonics{$opcode})) {
		return $opcode_mnemonics{$opcode};
	}
	die "Error: Unrecognized opcode: $opcode (line $line_number)\n";
}

sub get_value_mnemonic {
	my $value = shift;
	if (exists($value_mnemonics{$value})) {
		return $value_mnemonics{$value};
	}

	# Must be a short-form literal
	return sprintf('0x%04x', $value - 32);
}
