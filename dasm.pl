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
while(read($in, my $packed_word, 2)) {
	my $word = unpack('B16', $packed_word);
	eval {
		my $assembly = disassemble_instruction($word);
		print "$word $assembly\n";
	};
	if ($@) {
		die "$@(on line $line_number)\n";
	}
}
close $in;
