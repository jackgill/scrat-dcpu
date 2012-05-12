SET A, 0
SET B, 1 						; clock will tick once per second
HWI 2
SET A, 1

:loop
HWI 2
SET PC, loop
		


