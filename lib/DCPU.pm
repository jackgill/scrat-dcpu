package DCPU;

use strict;
use warnings;

use Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(disassemble_instruction get_value_mnemonic get_opcode_mnemonic read_word read_instruction bin2dec);

# Define mnemonics
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

sub get_opcode_mnemonic {
	my $opcode = shift;
	if (exists($opcode_mnemonics{$opcode})) {
		return $opcode_mnemonics{$opcode};
	}
	die "Error: Unrecognized opcode: $opcode\n";
}

sub get_value_mnemonic {
	my $value = shift;
	if (exists($value_mnemonics{$value})) {
		return $value_mnemonics{$value};
	}

	# Must be a short-form literal
	return sprintf('0x%04x', $value - 32);
}

sub bin2dec {
    return unpack("N", pack("B32", substr("0" x 32 . shift, -32)));
}

sub disassemble_instruction {
	my $bitstring = shift;
	
	unless($bitstring =~ /([01]{6})([01]{6})([01]{4})/) {
		die "Illegal bitstring: $bitstring\n";
	}
	
	my $opcode = bin2dec($3);
	my $first_value = bin2dec($2);
	my $second_value = bin2dec($1);

	my $opcode_mnemonic = get_opcode_mnemonic($opcode);
	my $first_value_mnemonic = get_value_mnemonic($first_value);
	my $second_value_mnemonic = get_value_mnemonic($second_value);

	return "$opcode_mnemonic $first_value_mnemonic, $second_value_mnemonic";
}

sub read_word {
	my $file_handle = shift;
	if(read($file_handle, my $packed_word, 2)) {
		return unpack('B16', $packed_word);
	}
	return 0;
}

sub should_read_next_word {
	my $value = shift;
	if (($value >= 0x10 && $value <= 0x17) ||
		$value == 0x1e ||
		$value == 0x1f) {
		return 1;
	}
	return 0;
}

sub read_instruction {
	my $file_handle = shift;

	my @words = ();
	
	# Read the first word
	my $word = read_word($file_handle);

	unless ($word) {
		return (); # Reached EOF
	}
	
	push @words, $word;
	
	unless($word =~ /([01]{6})([01]{6})([01]{4})/) {
		die "Illegal bitstring: $word\n";
	}

	my $first_value = bin2dec($2);
	my $second_value = bin2dec($1);

	if (should_read_next_word($first_value)) {
		my $next_word = read_word($file_handle);
		unless ($next_word) {
			die "Error: expecting next word, but reached EOF.\n";
		}
		push @words, $next_word;
	}

	if (should_read_next_word($second_value)) {
		my $next_word = read_word($file_handle);
		unless ($next_word) {
			die "Error: expecting next word, but reached EOF.\n";
		}
		push @words, $next_word;
	}

	return @words;
}
1;


   
