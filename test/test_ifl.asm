;; At the end of the program:
;; A should be 0x0001
;; B should be 0x0002
;; C should be 0x0000
;; X should be 0x0005
		
SET A, 1
IFL A, 2
SET B, 0x0002
IFL A, 0
SET C, 0x0004
SET X, 0x0005