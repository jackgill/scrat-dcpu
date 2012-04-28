# This module contains some utility methods that are used by
# several other modules and scripts

package DCPU;

use strict;
use warnings;

use Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(
get_value_mnemonic
get_basic_opcode_mnemonic
get_special_opcode_mnemonic

bin2dec

disassemble_instruction

read_word
read_instruction

should_read_next_word
);

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

my %basic_opcode_mnemonics = (
	0x01 => 'SET',
	0x02 => 'ADD',
	0x03 => 'SUB',
	0x04 => 'MUL',
	0x05 => 'MLI',
	0x06 => 'DIV',
	0x07 => 'DVI',
	0x08 => 'MOD',
	0x09 => 'MDI',
	0x0a => 'AND',
	0x0b => 'BOR',
	0x0c => 'XOR',
	0x0d => 'SHR',
	0x0e => 'ASR',
	0x0f => 'SHL',
	0x10 => 'IFB',
	0x11 => 'IFC',
	0x12 => 'IFE',
	0x13 => 'IFN',
	0x14 => 'IFG',
	0x15 => 'IFA',
	0x16 => 'IFL',
	0x17 => 'IFU',
	0x1a => 'ADX',
	0x1b => 'SBX',
	0x1e => 'STI',
	0x1f => 'STD',
	);

my %special_opcode_mnemonics = (
	0x01 => 'JSR',
	0x08 => 'INT',
	0x09 => 'IAG',
	0x0a => 'IAS',
	0x0b => 'RFI',
	0x0c => 'IAQ',
	0x10 => 'HWN',
	0x11 => 'HWQ',
	0x12 => 'HWI',
	);

our $instruction_regex = qr/^
	([01]{6})
	([01]{5})
	([01]{5})$/x;

# Get the mnemonic for a value
sub get_value_mnemonic {
	my $value = shift;
	if (exists($value_mnemonics{$value})) {
		return $value_mnemonics{$value};
	}

	# Must be a short-form literal
	return sprintf('0x%04x', $value - 32);
}

# Get the mnemonic for a basic opcode
sub get_basic_opcode_mnemonic {
	my $opcode = shift;
	if (exists($basic_opcode_mnemonics{$opcode})) {
		return $basic_opcode_mnemonics{$opcode};
	}
	die "Error: Unrecognized basic opcode: $opcode\n";
}

# Get the mnemonic for a special opcode
sub get_special_opcode_mnemonic {
	my $opcode = shift;
	if (exists($special_opcode_mnemonics{$opcode})) {
		return $special_opcode_mnemonics{$opcode};
	}
	die "Error: Unrecognized special opcode: $opcode\n";
}

# Convert a bitstring to a decimial number
sub bin2dec {
    return unpack("N", pack("B32", substr("0" x 32 . shift, -32)));
}

# Given a sequence of words representing a single DCPU-16 instruction,
# returns the text corresponding to that disassembled instruction
sub disassemble_instruction {
	my @words = @_;
	
	my $first_word = shift @words;

	unless($first_word =~ $instruction_regex) {
		die "Illegal word: $first_word\n";
	}

	my $text = ''; # text instruction

	my $opcode = bin2dec($3);
	if ($opcode == 0) { # special opcode
		$opcode = bin2dec($2);
		my $value = bin2dec($1);

		my $opcode_mnemonic = get_special_opcode_mnemonic($opcode);
		my $value_mnemonic = get_value_mnemonic($value);
		
		$text = "$opcode_mnemonic $value_mnemonic";
	}
	else { # basic opcode
		my $first_value = bin2dec($2);
		my $second_value = bin2dec($1);

		my $opcode_mnemonic = get_basic_opcode_mnemonic($opcode);
		my $first_value_mnemonic = get_value_mnemonic($first_value);
		my $second_value_mnemonic = get_value_mnemonic($second_value);

		$text = "$opcode_mnemonic $first_value_mnemonic, $second_value_mnemonic";
	}
		
	for my $word (@words) {
		my $value = sprintf("0x%04x", DCPU::bin2dec($word));
		$text =~ s/next word/$value/;
	}

	return $text;
}

# Read a single 16 bit word from a file handle
sub read_word {
	my $file_handle = shift;
	if(read($file_handle, my $packed_word, 2)) {
		return unpack('B16', $packed_word);
	}
	return 0;
}

# Read a multi-word instruction from a file handle
# Returns an array of words
sub read_instruction {
	my $file_handle = shift;

	my @words = ();
	
	# Read the first word
	my $word = read_word($file_handle);

	unless ($word) {
		return (); # Reached EOF
	}
	
	push @words, $word;
	
	unless($word =~ $instruction_regex) {
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

# Given a value, determine if the next word should be read
sub should_read_next_word {
	my $value = shift;
	if (($value >= 0x10 && $value <= 0x17) || # [next word + register]
		$value == 0x1e || # [next word]
		$value == 0x1f) { # next word
		return 1;
	}
	return 0;
}

1;


   
