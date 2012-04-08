use strict;
use warnings;
use lib 'lib';

use DCPU;

# Parse command line arguments
if (@ARGV != 1 || !($ARGV[0] =~ /(0x)?[0-9a-fA-F]{4}/)) {
	die "Usage: $0 (hex string representing a single 16 bit word";
}

my $hex_string = $ARGV[0];
my $bin_string = hex2bitstring($hex_string);
my $assembly = disassemble_instruction($bin_string);

print "$assembly\n";

sub hex2bitstring {
	my $hex = shift;
	$hex =~ s/^0x//;
	$hex =~ s/^\s+//;
	$hex =~ s/\s+$//;
	my $num = hex($hex);
	return sprintf("%016b", $num);
}	
