# Overview

This project provides an assembler, disassembler, and emulator for Notch's DCPU-16. I aim for compliance with version 1.1 of the DCPU-16 spec: http://www.0x10c.com/doc/dcpu-16.txt

This is my learning project for DCPU programming. It's named scrat-DCPU since I'm about as good at writing assemblers and emulators as Scrat is at protecting his acorn.

# Getting started

To get started, assemble one of the test files:

    perl bin/asm.pl test/test_set.asm
	
This will produce a object code file named test/test_set.o. You can execute it using the emulator:

    perl bin/emu.pl test/test_set.o
	
There's also a disassembler:

    perl bin/dasm.pl test/test_set.o
	
# Limitations:

* GUI is still rather primitive
* No keyboard input
* Emulator does not simulate clock
