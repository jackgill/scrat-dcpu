;; At the end of the program
;; A should be 0x0001
;; X should be 0xffff
;; I should be 6
		
SET A, 0x0002
SET B, 0x0001
SBX A, [B]

SET X, 0x0001
SET Y, 0x0002
SBX X, [Y]

SET I, 4
SET J, 0xfffd
SBX I, [J]