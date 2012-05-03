# Emulator for the DCPU-16. Accepts a file containing object code, and renders a Tk-based GUI
# which displays the contents of the registers, memory, and a monitor. Allows the user to
# step through the program.

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
VM::load_data('data/font.bin', 0x8180);

#VM::dump_machine_state();

# Set up GUI

# Main window
my $mw = MainWindow->new(
	-background => 'gray'
	);
$mw->title('scrat-dcpu');
my $icon = $mw->Photo(-file => 'data/scrat_icon.gif');
$mw->Icon(-image => $icon);

# Bind key events
$mw->bind('<Key-Escape>', sub { exit });
$mw->bind('<Key-space>', \&step);

# Top frame
my $top_frame = $mw->Frame(
	-background => 'gray'
	);

# Monitor
Monitor::set_parent_frame($top_frame);

# Registers
my %register_labels = ();
my @registers = ( 'A', 'B', 'C', 'X', 'Y', 'Z', 'I', 'J', 'PC', 'SP', 'EX', 'IA');
render_registers();

# Memory
my %memory_labels = ();
render_memory();

# Instruction
my $instruction_label = $top_frame->Label( -text => 'Instruction' )->pack(
	-anchor => 'w',
	-pady => 10
	);

# Message
my $message_label = $top_frame->Label( -text => 'Message' )->pack(
	-anchor => 'w'
	);

$top_frame->pack(
	-side => 'top'
	);
render_buttons();

MainLoop();

sub step {
	eval {
		Emulator::execute_cycle();
	};
	if ($@) {
		$message_label->configure(
			-text => $@
			);
	}
	update_gui();
}
		  
sub render_buttons {
	my $frame = $mw->Frame(
		-background => 'gray'
		);
	
	# Step button
	$frame->Button(
		-text => 'Step',
		-command => \&step
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
	return VM::read_excess() if $register eq 'EX';
	return VM::read_interrupt_address() if $register eq 'IA';
	return VM::read_register($register);
}

sub update_gui {
	update_register_labels();
	update_memory_labels();
	$instruction_label->configure(
		-text => Emulator::get_current_instruction()
		);
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
