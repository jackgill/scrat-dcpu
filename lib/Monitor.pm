package Monitor;

use strict;
use warnings;
use autodie;

use Exporter;
use Tk;
use DCPU;

our @ISA = qw(Exporter);
our @EXPORT = qw(draw_character set_parent_frame);

my $debug = 0;
my $canvas;

# Set up dimensions
my $pixel_size = 3;
my $character_width = 4 * $pixel_size;
my $character_height = 8 * $pixel_size;
my $n_rows = 12;
my $n_columns = 32;


sub set_parent_frame {
	my $parent_frame = shift;

	$canvas = $parent_frame->Canvas(
		-width => $n_columns * $character_width,
		-height => $n_rows * $character_height
		)->pack(
		-padx => 10,
		-pady => 10,
		-side => 'left'
		);
}

sub draw_character {
	my ($address, $instruction) = @_;
	my $string = sprintf("%016b", $instruction);
	$string =~ /(\d{8})(\d)(\d{7})/;
	my $color = $1;
	my $blink = $2;
	my $character = DCPU::bin2dec($3);

	# Endianess
	my $word2 = VM::read_memory(0x8180 + (2 *$character));
	my $word1 = VM::read_memory(0x8181 + (2 *$character));

	print "draw_character($character)\n" if $debug;
	
	my $x = ($address - 0x8000) * $character_width;
	my $y = 0;
	
	draw_glyph($x, $y, $word1, $word2);
}

sub draw_glyph {
	my ($x, $y, $word1, $word2) = @_;
	my $string = sprintf("%016b%016b", $word1, $word2);
	$string =~ /(\d{8})(\d{8})(\d{8})(\d{8})/;
	draw_column($x, $y, $4);
	draw_column($x + (1 * $pixel_size), $y, $3);
	draw_column($x + (2 * $pixel_size), $y, $2);
	draw_column($x + (3 * $pixel_size), $y, $1);
}

sub draw_column {
	my ($x, $y, $column) = @_;
	my @bits = reverse(split(//, $column));
	for (my $i = 0; $i < @bits; $i++) {
		draw_pixel($x, $y + ($i * $pixel_size)) if $bits[$i] eq '1';
	}
}

sub draw_pixel {
	my ($x, $y) = @_;
	$canvas->createRectangle($x, $y, $x + $pixel_size, $y + $pixel_size, -fill => 'black');
}
