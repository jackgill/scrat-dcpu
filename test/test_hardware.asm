JSR init_clock
; keyboard interrupts are off by default, so there's nothing to do there
; we will use the monitor's default font and palette
IAS handle_interrupt			; install interrupt handler
:main_loop
SET PC, main_loop
		
:init_clock
SET PUSH, A						;save registers
SET PUSH, B
; clock will tick once per second
SET A, 0
SET B, 60
HWI 2
; clock will fire an interrupt with message 1 whenever it ticks
SET A, 2
SET B, 1
HWI 2
; return
SET B, POP
SET A, POP
SET PC, POP

:handle_interrupt
; should be called when the clock ticks
; poll keyboard for input
; and paint monitor
JSR poll_keyboard
JSR echo
JSR paint_monitor
RFI 0
		
:poll_keyboard
; copy keyboard buffer to memory
SET PUSH, A						; save registers
SET PUSH, B
SET PUSH, C
SET A, 1						; hardware interrupt message - read keyboard buffer to reg C
SET B, 0						; buffer loop index
:keyboard_buffer_loop
HWI 1							; send hardware interrupt to keyboard
SET [0x9000 + B], C				; set memory to keyboard buffer value
ADD B, 1
IFN B, 0x000f					; wrap buffer
  SET PC, keyboard_buffer_loop	; loop
SET C, POP						; return
SET B, POP		
SET A, POP
SET PC, POP		

:paint_monitor
; paint monitor based on video RAM
SET PUSH, A						; save registers
SET PUSH, B
SET A, 0						; hardware interrupt message - memory map screen
SET B, 0x8000					; video RAM starting address
HWI 0							; sent hardware interrupt to monitor
SET B, POP						; return
SET A, POP
SET PC, POP

:echo
SET PUSH, A						; save registers
:echo_loop
IFN [0x9000 + A], 0
  SET [0x8000 + A], [0x9000 + A]	; set memory to keyboard buffer value
ADD A, 1
IFN A, 0x000f					; wrap buffer
  SET PC, echo_loop		        ; loop
SET A, POP						; return
SET PC, POP