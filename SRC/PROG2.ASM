;This program implements a triple nested loop, then saves and reloads some
;values in locations 2000 and 3000.
;By setting page 20H as RAM memory and page 30H as ROM, and enabling the log
;file, the user can test the behaviour of the emulator related to memory types.

DSEG            SEGMENT
TESTPROG:       DB      0A9H,004H            ;LDA #04
LOOP3:          DB      0A0H,004H            ;LDY #04
LOOP2:          DB      0A2H,004H            ;LDX #04
LOOP1:          DB      0CAH                 ;DEX
                DB      0D0H,0FDH            ;BNE LOOP1
                DB      088H                 ;DEY
                DB      0D0H,0F8H            ;BNE LOOP2
                DB      03AH                 ;DEC A
                DB      0D0H,0F3H            ;BNE LOOP3
                DB      0A9H,030H            ;LDA #30
                DB      08DH,024H,020H       ;STA 2024
                DB      08DH,024H,030H       ;STA 3024
                DB      0ADH,024H,020H       ;LDA 2024
                DB      0ADH,024H,030H       ;LDA 3024
                DB      000H                 ;BRK
ENDS            DSEG
END
