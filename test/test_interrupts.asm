SET A, 1
IAS interrupt_handler 			; install interrupt handler
INT 0
SET B, 2
SET C, 3
		
:interrupt_handler SET Z, 0xabcd
RFI 0 							; first operand is still mandantory