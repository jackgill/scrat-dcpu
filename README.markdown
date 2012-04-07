If you're looking for a decent Perl-based DCPU implementation, check out https://github.com/doy/games-emulation-dcpu16

This is my learning project for DCPU programming, which currently includes a (very) minimal assembler, disassembler and emulator. It's named scrat-DCPU since I'm about as good at writing assemblers and emulators as Scrat is at protecting his acorn.

Limitations:

* Emulator only supports SET opcode
* Emulator only includes registers (no memory, no stack, no program counter)