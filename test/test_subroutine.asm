; Call a subroutine
              SET X, 0x4               ; 9031
              JSR testsub              ; 7c10 0018 [*]
              SET PC, crash            ; 7dc1 001a [*]
        
:testsub      SHL X, 4                 ; 9037
              SET PC, POP              ; 61c1
                        
; Hang forever. X should now be 0x40 if everything went right.
:crash        SET PC, crash            ; 7dc1 001a [*]