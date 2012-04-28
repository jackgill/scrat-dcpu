# This script reads a file containing DCPU-16 object code and prints
# the disassembled instructions to the terminal

use strict;
use warnings;
use autodie;
use lib 'lib';

use DCPU;

# Parse command line arguments
if (@ARGV != 1) {
	die "Usage: $0 file.o";
}

my $input_file_name = $ARGV[0];

# Loop through the file and print disassembled instructions
my $line_number = 1;
open(my $in, '<:raw', $input_file_name);
while(my @words = DCPU::read_instruction($in)) {
	eval {
		# Get the hex strings corresponding to the instruction's words
		my @hex_words = map { sprintf("%04x", DCPU::bin2dec($_)) } @words;

		# Get the text of the instruction
		my $text = DCPU::disassemble_instruction(@words);
		
		printf "%-18s %s\n", join(' ', @hex_words), $text;
	};
	if ($@) {
		die "$@(on line $line_number)\n";
	}
	$line_number++;
}
close $in;


