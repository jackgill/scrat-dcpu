use strict;
use warnings;

use DCPU;

# Parse command line arguments
if (@ARGV != 1) {
	die "Usage: $0 file.o";
}

my $input_file_name = $ARGV[0];

my $line_number = 0;
open(my $in, '<:raw', $input_file_name);
while(my @words = read_instruction($in)) {
	eval {
		my $binary = shift @words;
		my $text = disassemble_instruction($binary);
		for my $word (@words) {
			$binary .= ' ' . $word;
			$text .= ' ' . sprintf("0x%04x", bin2dec($word));
		}
		printf "%-50s %s\n", $binary, $text;

	};
	if ($@) {
		die "$@(on line $line_number)\n";
	}
}
close $in;


