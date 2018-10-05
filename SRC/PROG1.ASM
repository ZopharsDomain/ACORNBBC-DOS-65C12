;This program implements a triple nested loop. This is executed in 21 seconds by
;a real 2 MHz 65C12.

DSEG            SEGMENT
TESTPROG:       DB      0A9H,080H            ;LDA #80
LOOP3:          DB      0A0H,000H            ;LDY #00
LOOP2:          DB      0A2H,000H            ;LDX #00
LOOP1:          DB      0CAH                 ;DEX
                DB      0D0H,0FDH            ;BNE LOOP1
                DB      088H                 ;DEY
                DB      0D0H,0F8H            ;BNE LOOP2
                DB      03AH                 ;DEC A
                DB      0D0H,0F3H            ;BNE LOOP3
                DB      000H                 ;BRK
ENDS            DSEG
END
