use strict;
use warnings;
use lib 'lib';

use Emulator;
use VM;

# Parse command line arguments
if (@ARGV != 1) {
	die "Usage: $0 file.asm";
}

# Load object code into memory
VM::load_data($ARGV[0], 0);

# Load font into memory
# TODO: allow font file to be specified as command-line argument
VM::load_data('font.bin', 0x8180);

VM::dump_machine_state();

Monitor::gui_loop();
