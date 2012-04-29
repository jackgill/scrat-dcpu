# Given a binary file, prints a string representation of the contents to the terminal,
# one 16 bit word per line.

use strict;
use warnings;
use autodie;

if (@ARGV != 1) {
	die "Usage: $0 file.o";
}

my $input_file_name = $ARGV[0];

open(my $in, '<:raw', $input_file_name);
while(read($in, my $packed_data, 2)) {
	my $data = unpack('B16', $packed_data);
	print $data, "\n";
}
close $in;
