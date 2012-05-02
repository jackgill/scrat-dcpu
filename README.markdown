# Overview

This project provides an assembler, disassembler, and emulator for Notch's DCPU-16. I am currently in the process of moving from version 1.1 to version 1.7 of Notch's spec.

This is my learning project for DCPU programming. It's named scrat-DCPU since I'm about as good at writing assemblers and emulators as Scrat is at protecting his acorn.

# Getting started

This project requires Perl 5.10 or later, and the Tk module from CPAN.

To get started, assemble one of the test files:

    perl bin/asm.pl test/test_set.asm
	
This will produce a object code file named test/test_set.o. You can execute it using the emulator:

    perl bin/emu.pl test/test_set.o
	
There's also a disassembler:

    perl bin/dasm.pl test/test_set.o
	
# Limitations:

* No interrupts
* None of the 1.7 special opcodes have been implemented yet
* GUI is still rather primitive
* No keyboard input
* Emulator does not simulate clock
