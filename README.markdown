If you're looking for a decent Perl-based DCPU implementation, check out https://github.com/doy/games-emulation-dcpu16

This is my learning project for DCPU programming, which currently includes a (very) minimal assembler, disassembler and emulator. It's named scrat-DCPU since I'm about as good at writing assemblers and emulators as Scrat is at protecting his acorn.

To get started, assemble one of the test files:

    perl bin/asm.pl test/test_set.asm
	
This will produce a object code file named test/test_set.o. You can execute it using the emulator:

    perl bin/emu.pl test/test_set.o
	
There's also a disassembler:

    perl bin/dasm.pl test/test_set.o
	
Limitations:

* Assembler does not support labels
* Assembler does not support short-form values
* Emulator does not support JSR instruction
* Emulator does not simulate clock
