# Overview

This project provides an assembler, disassembler, and emulator for Notch's DCPU-16. I aim for compliance with version 1.7 of Notch's spec. It's named scrat-DCPU since I'm about as good at writing assemblers and emulators as Scrat is at protecting his acorn :)

# Getting started

This project requires Perl 5.10 or later, and the Tk module from CPAN.

To get started, assemble one of the test files:

    perl bin/asm.pl test/test_set.asm
	
This will produce a object code file named test/test_set.o. You can execute it using the emulator:

    perl bin/emu.pl test/test_set.o
	
There's also a disassembler:

    perl bin/dasm.pl test/test_set.o
	
# Limitations:

* Monitor doesn't support color, or blinking
* No keyboard
* No clock
* Only supports stepping through code
* Emulator does not limit processor cycle rate
