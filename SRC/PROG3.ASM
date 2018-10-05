;This is a simple program used to test the stack and the subroutines.
;Note: this program is NOT relocatable and MUST be loaded at &200.

DSEG            SEGMENT
TESTPROG:       DB      0A9H,004H            ;LDA #04
LOOP1:          DB      020H,009H,002H       ;JSR DELAY
                DB      03AH                 ;DEC A
                DB      0D0H,0FAH            ;BNE LOOP1
                DB      000H                 ;BRK
DELAY:          DB      048H                 ;PHA
                DB      0A9H,004H            ;LDA #04
LOOP2:          DB      03AH                 ;DEC A
                DB      0D0H,0FDH            ;BNE LOOP2
                DB      068H                 ;PLA
                DB      060H                 ;RTS
ENDS            DSEG
END
