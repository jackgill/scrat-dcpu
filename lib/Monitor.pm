# Implements the LEM1802 spec

package Monitor;

use strict;
use warnings;
use autodie;

use Tk;
use DCPU;

my $debug = 0;

sub new {
	my ($class, $dcpu, $parent_frame) = @_;

	# Set up GUI
	my $pixel_size = 3;
	my $n_rows = 12;
	my $n_columns = 32;
	my $character_width = 4 * $pixel_size;
	my $character_height = 8 * $pixel_size;
	
	# Draw canvas in GUI
	my $canvas = $parent_frame->Canvas(
		-width => $n_columns * $character_width,
		-height => $n_rows * $character_height
		)->pack(
		-padx => 10,
		-pady => 10,
		-side => 'left'
		);

	# Initialize object
	my $self = {
		dcpu => $dcpu,
		canvas => $canvas,
		pixel_size => $pixel_size,
		character_width => $character_width,
		character_height => $character_height,
		n_rows => $n_rows,
		n_columns => $n_columns,
	};
	
	bless($self);
	
	return $self;
}

sub trigger_interrupt {
	my ($self) = @_;

	my $message = $self->dcpu->read_register('A');
	
	if ($message == 0) {
		my $start = $self->dcpu->read_register('B');
		my $end = $start + 386;
		for (my $i = $start; $i < $end; $i++) {
			$self->draw_character($i - $start, $self->dcpu->read_memory($i));
		}
	}
}

sub draw_character {
	my ($self, $index, $instruction) = @_;
	my $string = sprintf("%016b", $instruction);
	$string =~ /(\d{8})(\d)(\d{7})/;
	my $color = $1;
	my $blink = $2;
	my $character = DCPU::bin2dec($3);

	# Read font (note endianess)
	# TODO: add default font
	my $word2 = $self->dcpu->read_memory(0x8180 + (2 *$character));
	my $word1 = $self->dcpu->read_memory(0x8181 + (2 *$character));

	print "draw_character($character)\n" if $debug;

	# TODO: this will only draw to the first line
	# Need to map index to x, y
	my $x = $index * $self->character_width;
	my $y = 0;
	
	$self->draw_glyph($x, $y, $word1, $word2);
}

sub draw_glyph {
	my ($self, $x, $y, $word1, $word2) = @_;

	print "draw_glyph($x, $y, $word1, $word2)\n" if $debug;
	
	my $string = sprintf("%016b%016b", $word1, $word2);
	$string =~ /(\d{8})(\d{8})(\d{8})(\d{8})/;
	draw_column($x, $y, $4);
	draw_column($x + (1 * $self->pixel_size), $y, $3);
	draw_column($x + (2 * $self->pixel_size), $y, $2);
	draw_column($x + (3 * $self->pixel_size), $y, $1);
}

sub draw_column {
	my ($self, $x, $y, $column) = @_;
	my @bits = reverse(split(//, $column));
	for (my $i = 0; $i < @bits; $i++) {
		draw_pixel($x, $y + ($i * $self->pixel_size)) if $bits[$i] eq '1';
	}
}

sub draw_pixel {
	my ($self, $x, $y) = @_;
	$self->canvas->createRectangle($x, $y, $x + $self->pixel_size, $y + $self->pixel_size, -fill => 'black');
}

1;
