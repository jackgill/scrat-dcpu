SET A, 1 						; Store next key typed in C register, or 0 if the buffer is empty
SET I, 0						; buffer loop index
:polling_loop SET X, 0			; no op
JSR write_buffer				; copy keyboard buffer to memory
JSR clear_buffer				; clear buffer
SET PC, polling_loop			; loop

:write_buffer SET J, 0			; buffer loop index
:write_buffer_loop SET X, 0		; no op
HWI 1							; send hardware interrupt to keyboard
IFE C, 0						; if C is 0, the keyboard buffer is empty, return
  SET PC, POP
SET [0x9000 + J], C				; set memory to keyboard buffer value
ADD J, 1
IFE J, 0x000f					; wrap buffer
  SET J, 0
SET PC, write_buffer_loop		; loop 
		
:clear_buffer SET J, 0			; buffer loop index
:clear_buffer_loop SET X, 0		; no op
SET [0x9000 + J], 0				; zero out memory
ADD J, 1						; increment loop index
IFE J, 0x000f					; 16 word buffer
  SET PC, POP					; if we're at the end of the buffer, return
SET PC, clear_buffer_loop		; loop