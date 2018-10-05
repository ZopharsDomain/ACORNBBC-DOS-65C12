;------------------------------------------------------------------------------;
;Questo file contiene le procedure di emulazione dell'hardware collegato al    ;
;65C12. Attualmente le procedure sono vuote in quanto non viene emulato alcun  ;
;hardware aggiuntivo.                                                          ;
;------------------------------------------------------------------------------;
IDEAL
MODEL           SMALL

SEGMENT         DSEG    PUBLIC 'DATA'
ENDS            DSEG

SEGMENT         SSEG    PUBLIC STACK 'STACK'
ENDS            SSEG

SEGMENT         MSEG    PUBLIC
ENDS            MSEG

SEGMENT         CSEG    PUBLIC 'CODE'

		ASSUME  CS:CSEG,DS:MSEG,SS:SSEG
PUBLIC          READ_IO
;------------------------------------------------------------------------------;
;Questa Š la procedura di lettura dalla memoria I/O.                           ;
;Attualmente non viene emulato alcun dispositivo memory-mapped, di conseguenza ;
;questa procedura non fa nulla.                                                ;
;                                                                              ;
;In ingresso: BX = Locazione di memoria dalla quale leggere                    ;
;In uscita:   BL = Valore letto dalla memoria                                  ;
;Registri utilizzati: Nessuno                                                  ;
;------------------------------------------------------------------------------;
PROC            READ_IO
                RET
ENDP            READ_IO

PUBLIC          WRITE_IO
;------------------------------------------------------------------------------;
;Questa Š la procedura di scrittura nella memoria I/O.                         ;
;Attualmente non viene emulato alcun dispositivo memory-mapped, di conseguenza ;
;questa procedura non fa nulla.                                                ;
;                                                                              ;
;In ingresso: BX = Locazione di memoria in cui scrivere                        ;
;             CL = Valore da scrivere nella memoria                            ;
;Registri utilizzati: Nessuno                                                  ;
;------------------------------------------------------------------------------;
PROC            WRITE_IO
                RET
ENDP            WRITE_IO

ENDS            CSEG

END
