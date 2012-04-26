use strict;
use warnings;
use lib 'lib';

use Emulator;
use VM;
use Monitor;
use Tk;

# Parse command line arguments
if (@ARGV != 1) {
	die "Usage: $0 file.asm";
}

# Load object code into memory
VM::load_data($ARGV[0], 0);

# Load font into memory
# TODO: allow font file to be specified as command-line argument
VM::load_data('font.bin', 0x8180);

#VM::dump_machine_state();

# Set up GUI

# Main window
my $mw = MainWindow->new(
	-background => 'gray'
	);
$mw->title('scrat-dcpu');

my $top_frame = $mw->Frame(
	-background => 'gray'
	);

# Monitor

Monitor::set_parent_frame($top_frame);

my %register_labels = ();
my @registers = ( 'A', 'B', 'C', 'X', 'Y', 'Z', 'I', 'J', 'PC', 'SP', 'O');
render_registers();

my %memory_labels = ();
render_memory();

$top_frame->pack(
	-side => 'top'
	);
render_buttons();

MainLoop();

sub render_buttons {
	my $frame = $mw->Frame();
	
	# Step button
	$frame->Button(
		-text => 'Step',
		-command => sub {
			Emulator::execute_cycle();
			update_gui();
		}
		)->pack(
		-padx => 10,
		-pady => 10,
		-side => 'left'
		);

	# Quit button
	$frame->Button(
		-text => 'Quit',
		-command => sub { exit }
		)->pack(
		-padx => 10,
		-side => 'left'
			);

	$frame->pack(
		-padx => 10,
		-pady => 10,
		-side => 'left'
		);
}


sub render_registers {
	
	my $frame = $top_frame->Frame(
		-background => 'gray'
		);
	for my $register (@registers) {
		$frame->Label(
			-text => $register
			)->pack(
			-side => 'left'
			);

		 my $label = $frame->Label(
			-text => sprintf("%04x", get_register_value($register))
			)->pack(
			 -side => 'left',
			 -padx => 5
			);
		$register_labels{$register} = $label;
	}
	
	$frame->pack(
		-padx => 10,
		-pady => 10,
		-side => 'top'
		);
}

sub render_memory {
	render_memory_bank(0x0000);
	render_memory_bank(0x0008);
	render_memory_bank(0x8000);
	render_memory_bank(0xfff8);
}

sub render_memory_bank {
	my $starting_address = shift;
	my $frame = $top_frame->Frame(
		-background => 'gray'
		);
	for (my $memory_address = $starting_address; $memory_address < $starting_address + 8; $memory_address++) {
		if ($memory_address % 8 == 0) {
			$frame->Label(
				-text => sprintf("0x%04x", $memory_address),
				-width => 8
				)->pack(
				-side => 'left'
				
				);
		}
		 my $label = $frame->Label(
			-text => sprintf("%04x", VM::read_memory($memory_address)),
			-width => 8
			)->pack(
			 -side => 'left',
			 -padx => 5
			);
		$memory_labels{$memory_address} = $label;
	}
	
	$frame->pack(
		-padx => 10,
		-pady => 10,
		-side => 'top'
		);
}

sub get_register_value {
	my $register = shift;
	return VM::read_program_counter() if $register eq 'PC';
	return VM::read_stack_pointer() if $register eq 'SP';
	return VM::read_overflow() if $register eq 'O';
	return VM::read_register($register);
}

sub update_gui {
	update_register_labels();
	update_memory_labels();
}

sub update_register_labels {
	for my $register (@registers) {
		$register_labels{$register}->configure(
			-text => sprintf("%04x", get_register_value($register))
			);
	}
}

sub update_memory_labels {
	for my $memory_address (keys %memory_labels) {
		$memory_labels{$memory_address}->configure(
			-text => sprintf("%04x", VM::read_memory($memory_address))
			);
	}
}
