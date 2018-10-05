;------------------------------------------------------------------------------;
;Questo file contiene le procedure per il salvataggio su file del tracciamento ;
;delle istruzioni eseguite dal 65C12 emulato.                                  ;
;------------------------------------------------------------------------------;
IDEAL
MODEL           SMALL

SEGMENT         DSEG    PUBLIC 'DATA'
LF              EQU     0AH
CR              EQU     0DH
SPC             EQU     20H
LOG_HEADER_SIZE EQU     88
LOG_LINE_SIZE   EQU     41
LOG_FILE_NAME   DB      '65C12EM.LOG',00H
LOG_HEADER      DB      '65C12 Emulator Log File.',CR,LF,CR,LF
                DB      ' PC   INSTRUCTION   A  X  Y NV1BDIZC  S',CR,LF
                DB      '                   '
ENDS            DSEG

SEGMENT         SSEG    PUBLIC STACK 'STACK'
ENDS            SSEG

SEGMENT         MSEG    PUBLIC
ENDS            MSEG

SEGMENT         CSEG    PUBLIC 'CODE'

		ASSUME  CS:CSEG,DS:DSEG,SS:SSEG
PUBLIC          OPEN_LOG_FILE
;------------------------------------------------------------------------------;
;Questa procedura apre in scrittura il file su cui verrÖ salvato il            ;
;tracciamento passo-passo delle istruzioni eseguite dal 65C12 emulato (log     ;
;file).                                                                        ;
;Il nome del file da aprire ä una stringa ASCIIZ in LOG_FILE_NAME; l'handle del;
;file aperto viene salvato in LOG_FILE_HANDLE.                                 ;
;NOTA: la procedura TRACE_INSTR verrÖ richiamata durante l'emulazione vera e   ;
;propria del 65C12, quando DS punterÖ alla memoria del processore emulato e    ;
;NON al data-segment DSEG; per questo tutte le variabili utilizzate anche da   ;
;TRACE_INSTR risiedono nel code-segment CSEG e richiedono l'override di        ;
;segmento CS:.                                                                 ;
;                                                                              ;
;In uscita: CF=1 se si ä verificato un errore durante l'apertura del file      ;
;Registri utilizzati: AX, CX, DX + tutti i registri utilizzati dalla funzione  ;
;                     3CH del DOS (informazione non disponibile)               ;
;------------------------------------------------------------------------------;
PROC            OPEN_LOG_FILE
                MOV     AH,3CH               ;Funzione DOS apertura file R/W
                XOR     CX,CX                ;Attributi del file (normal file)
                MOV     DX,OFFSET LOG_FILE_NAME
                INT     21H                  ;Tenta di aprire il file
                MOV     [CS:LOG_FILE_HANDLE],AX ;Salva l'handle del file
                RET                          ;Ritorna alla procedura chiamante
ENDP            OPEN_LOG_FILE

PUBLIC          WRITE_LOG_HEADER
;------------------------------------------------------------------------------;
;Questa procedura scrive l'intestazione nel file su cui verrÖ salvato il       ;
;tracciamento passo-passo delle istruzioni eseguite dal 65C12 emulato.         ;
;L'handle del file ä in LOG_FILE_HANDLE.                                       ;
;                                                                              ;
;In uscita: CF=1 se si ä verificato un errore durante la scrittura del file    ;
;Registri utilizzati: AH, BX, CX, DX + tutti i registri utilizzati dalla       ;
;                     funzione 40H del DOS (informazione non disponibile)      ;
;------------------------------------------------------------------------------;
PROC            WRITE_LOG_HEADER
                MOV     BX,[CS:LOG_FILE_HANDLE] ;BX = file handle
                MOV     AH,40H               ;Servizio DOS scrittura file
                MOV     CX,LOG_HEADER_SIZE   ;CX = numero di bytes da scrivere
                MOV     DX,OFFSET LOG_HEADER ;Stringa da scrivere nel file
                INT     21H                  ;Scrive l'intestazione nel file
                JC      WLG_RET              ;Se c'ä un errore, esce subito
                CMP     AX,CX                ;Controlla se il disco ä pieno
                JNB     WLG_RET              ;Se no, esce
                STC                          ;Se sç, setta il carry
WLG_RET:        RET                          ;Ritorna alla procedura chiamante
ENDP            WRITE_LOG_HEADER

		ASSUME  CS:CSEG,DS:MSEG,SS:SSEG
PUBLIC          WRITE_LOG_LINE
;------------------------------------------------------------------------------;
;Questa procedura scrive una linea nel file di log.                            ;
;Vengono scritti nel file i valori attuali dei registri del 65C12, una         ;
;sequenza CR/LF e la prossima istruzione da eseguire.                          ;
;                                                                              ;
;In ingresso: I registri dell'80x86 devono contenere i valori attuali dei      ;
;             registri del 65C12 come segue:                                  ;
;                Registro 65C12            Registro 80x86                      ;
;                      PC                        SI                            ;
;                      P                         AH                            ;
;                      A                         AL                            ;
;                      X                         DL                            ;
;                      Y                         DH                            ;
;                      S                         DI                            ;
;             BL = prossimo codice operativo da eseguire                       ;
;In uscita: CF=1 se si ä verificato un errore durante la scrittura del file    ;
;Registri utilizzati: Nessuno                                                  ;
;------------------------------------------------------------------------------;
PROC            WRITE_LOG_LINE
                PUSH    AX                   ;Salva tutti i registri nello
                PUSH    BX                   ;stack; questo ä necessario in
                PUSH    CX                   ;quanto non ä disponibile alcuna
                PUSH    DX                   ;informazione su quali registri
                PUSH    DI                   ;vengano modificati dalla funzione
                PUSH    BP                   ;40H del DOS
                PUSH    DS
                PUSH    ES
                PUSH    SI
                MOV     SI,OFFSET CS:LOG_BUFFER ;SI punterÖ alla stringa da
                                             ;costruire
                MOV     CH,AL                ;Scrive nella stringa il valore di
                CALL    CONV_HEX             ;A in esadecimale
                MOV     [BYTE CS:SI],' '     ;Scrive uno spazio nella stringa
                INC     SI                   ;Incr. puntatore dentro la stringa
                MOV     CH,DL                ;Scrive nella stringa il valore di
                CALL    CONV_HEX             ;X in esadecimale
                MOV     [BYTE CS:SI],' '     ;Scrive uno spazio nella stringa
                INC     SI                   ;Incr. puntatore dentro la stringa
                MOV     CH,DH                ;Scrive nella stringa il valore di
                CALL    CONV_HEX             ;Y in esadecimale
                MOV     [BYTE CS:SI],' '     ;Scrive uno spazio nella stringa
                INC     SI                   ;Incr. puntatore dentro la stringa
                MOV     CX,8                 ;CX = contatore dei bit da scrivere
FLAGS_LOOP:     MOV     BH,'0'               ;Carica il carattere '0' in BH
                ROL     AH,1                 ;Ruota P a sinistra; CF = bit 7
                JNC     WRITE_BIT            ;Se il bit vale 0, BH va giÖ bene
                INC     BH                   ;Il bit vale 1, BH = carattere '1'
WRITE_BIT:      MOV     [CS:SI],BH           ;Scrive il bit nella stringa
                INC     SI                   ;Incr. puntatore dentro la stringa
                LOOP    FLAGS_LOOP           ;Cicla per otto volte
                MOV     [BYTE CS:SI],' '     ;Scrive uno spazio nella stringa
                INC     SI                   ;Incr. puntatore dentro la stringa
                MOV     CX,DI                ;Scrive nella stringa il valore di
                MOV     CH,CL                ;S in esadecimale
                CALL    CONV_HEX
                MOV     [BYTE CS:SI],CR      ;Va a capo
                INC     SI
                MOV     [BYTE CS:SI],LF
                INC     SI
                POP     CX                   ;Carica PC in CX
                PUSH    CX
                CALL    CONV_HEX             ;Scrive nella stringa il valore di
                MOV     CH,CL                ;PC in esadecimale
                CALL    CONV_HEX
                MOV     [BYTE CS:SI],' '     ;Scrive uno spazio nella stringa
                INC     SI                   ;Incr. puntatore dentro la stringa
                XOR     BH,BH                ;BX = opcode attuale
                SHL     BX,1                 ;Moltiplica BX per 4 per puntare
                SHL     BX,1                 ;nella tabella dei codici mnemonici
                MOV     CL,[CS:MNEMONICS+BX] ;Scrive nella stringa i tre
                MOV     [CS:SI],CL           ;caratteri che compongono il codice
                INC     SI                   ;mnemonico dell'istruzione attuale
                INC     BX
                MOV     CL,[CS:MNEMONICS+BX]
                MOV     [CS:SI],CL
                INC     SI
                INC     BX
                MOV     CL,[CS:MNEMONICS+BX]
                MOV     [CS:SI],CL
                INC     SI
                INC     BX
                MOV     [BYTE CS:SI],' '     ;Scrive uno spazio nella stringa
                INC     SI                   ;Incr. puntatore dentro la stringa
                MOV     CH,[CS:MNEMONICS+BX] ;CH = modo di indirizzamento
                CMP     CH,01H               ;Modo di indirizzamento implicito?
                JNE     ACC_2                ;Se no, salta al prossimo controllo
                                             ;Esempio: CLI
                MOV     CL,10                ;Scrive 10 spazi dentro la stringa
                JMP     ADD_SPACES           ;per terminarla
ACC_2:          CMP     CH,02H               ;Modo di indir. all'accumulatore?
                JNE     IMM_3                ;Se no, salta al prossimo controllo
                MOV     [BYTE CS:SI],'A'     ;Esempio: LSR A
                INC     SI
                MOV     CL,9                 ;Scrive 9 spazi dentro la stringa
                JMP     ADD_SPACES           ;per terminarla
IMM_3:          CMP     CH,03H               ;Modo di indirizzamento immediato?
                JNE     ABS_4                ;Se no, salta al prossimo controllo
                MOV     [BYTE CS:SI],'#'     ;Esempio: LDA #5C
                INC     SI
                POP     BX                   ;Carica PC in BX
                PUSH    BX
                MOV     CH,[BX+1]            ;Carica operando in CL e lo scrive
                CALL    CONV_HEX             ;in esadecimale
                MOV     CL,7                 ;Scrive 7 spazi dentro la stringa
                JMP     ADD_SPACES           ;per terminarla
ABS_4:          CMP     CH,04H               ;Modo di indirizzamento assoluto?
                JNE     ZPG_5                ;Se no, salta al prossimo controllo
                POP     BX                   ;Esempio: ADC A35C
                PUSH    BX
                MOV     CX,[BX+1]
                CALL    CONV_HEX
                MOV     CH,CL
                CALL    CONV_HEX
                MOV     CL,6                 ;Scrive 6 spazi dentro la stringa
                JMP     ADD_SPACES           ;per terminarla
ZPG_5:          CMP     CH,05H               ;Modo di indirizz. in pagina zero?
                JNE     IND_6                ;Se no, salta al prossimo controllo
                POP     BX                   ;Esempio: SBC A3
                PUSH    BX
                MOV     CH,[BX+1]
                CALL    CONV_HEX
                MOV     CL,8
                JMP     ADD_SPACES
IND_6:          CMP     CH,06H               ;Modo di indirizzamento indiretto?
                JNE     IZP_7                ;Se no, salta al prossimo controllo
                MOV     [BYTE CS:SI],'('     ;Esempio: JMP (74B0)
                INC     SI
                POP     BX
                PUSH    BX
                MOV     CX,[BX+1]
                CALL    CONV_HEX
                MOV     CH,CL
                CALL    CONV_HEX
                MOV     [BYTE CS:SI],')'
                INC     SI
                MOV     CL,4                 ;Scrive 4 spazi dentro la stringa
                JMP     ADD_SPACES           ;per terminarla
IZP_7:          CMP     CH,07H               ;Modo indir. indiretto in pagina 0?
                JNE     INX_8                ;Se no, salta al prossimo controllo
                MOV     [BYTE CS:SI],'('     ;Esempio: LDX (A6)
                INC     SI
                POP     BX
                PUSH    BX
                MOV     CH,[BX+1]
                CALL    CONV_HEX
                MOV     [BYTE CS:SI],')'
                INC     SI
                MOV     CL,6                 ;Scrive 6 spazi dentro la stringa
                JMP     ADD_SPACES           ;per terminarla
INX_8:          CMP     CH,08H               ;Modo ind. indicizzato ass. con X?
                JNE     INY_9                ;Se no, salta al prossimo controllo
                POP     BX                   ;Esempio: LDY 4300,X
                PUSH    BX
                MOV     CX,[BX+1]
                CALL    CONV_HEX
                MOV     CH,CL
                CALL    CONV_HEX
                MOV     [BYTE CS:SI],','
                INC     SI
                MOV     [BYTE CS:SI],'X'
                INC     SI
                MOV     CL,4                 ;Scrive 4 spazi dentro la stringa
                JMP     ADD_SPACES           ;per terminarla
INY_9:          CMP     CH,09H               ;Modo ind. indicizzato ass. con Y?
                JNE     IZX_A                ;Se no, salta al prossimo controllo
                POP     BX                   ;Esempio: LDX A70C,Y
                PUSH    BX
                MOV     CX,[BX+1]
                CALL    CONV_HEX
                MOV     CH,CL
                CALL    CONV_HEX
                MOV     [BYTE CS:SI],','
                INC     SI
                MOV     [BYTE CS:SI],'Y'
                INC     SI
                MOV     CL,4                 ;Scrive 4 spazi dentro la stringa
                JMP     ADD_SPACES           ;per terminarla
IZX_A:          CMP     CH,0AH               ;Modo ind. indic. in pag. 0 con X?
                JNE     IZY_B                ;Se no, salta al prossimo controllo
                POP     BX                   ;Esempio: STY 7C,X
                PUSH    BX
                MOV     CH,[BX+1]
                CALL    CONV_HEX
                MOV     [BYTE CS:SI],','
                INC     SI
                MOV     [BYTE CS:SI],'X'
                INC     SI
                MOV     CL,6                 ;Scrive 6 spazi dentro la stringa
                JMP     ADD_SPACES           ;per terminarla
IZY_B:          CMP     CH,0BH               ;Modo ind. indic. in pag. 0 con Y?
                JNE     IPR_C                ;Se no, salta al prossimo controllo
                POP     BX                   ;Esempio: STX C8,Y
                PUSH    BX
                MOV     CH,[BX+1]
                CALL    CONV_HEX
                MOV     [BYTE CS:SI],','
                INC     SI
                MOV     [BYTE CS:SI],'Y'
                INC     SI
                MOV     CL,6                 ;Scrive 6 spazi dentro la stringa
                JMP     ADD_SPACES           ;per terminarla
IPR_C:          CMP     CH,0CH               ;Modo ind. indir. pre-indicizzato?
                JNE     IPO_D                ;Se no, salta al prossimo controllo
                MOV     [BYTE CS:SI],'('     ;Esempio: LDA (67,X)
                INC     SI
                POP     BX
                PUSH    BX
                MOV     CH,[BX+1]
                CALL    CONV_HEX
                MOV     [BYTE CS:SI],','
                INC     SI
                MOV     [BYTE CS:SI],'X'
                INC     SI
                MOV     [BYTE CS:SI],')'
                INC     SI
                MOV     CL,4                 ;Scrive 4 spazi dentro la stringa
                JMP     ADD_SPACES           ;per terminarla
IPO_D:          CMP     CH,0DH               ;Modo ind. indir. post-indicizzato?
                JNE     IPA_E                ;Se no, salta al prossimo controllo
                MOV     [BYTE CS:SI],'('     ;Esempio: STA (1D),Y
                INC     SI
                POP     BX
                PUSH    BX
                MOV     CH,[BX+1]
                CALL    CONV_HEX
                MOV     [BYTE CS:SI],')'
                INC     SI
                MOV     [BYTE CS:SI],','
                INC     SI
                MOV     [BYTE CS:SI],'Y'
                INC     SI
                MOV     CL,4                 ;Scrive 4 spazi dentro la stringa
                JMP     ADD_SPACES           ;per terminarla
IPA_E:          CMP     CH,0EH               ;Modo ind. indir. pre-indic. ass.?
                JNE     REL_F                ;Se no, il modo di ind. ä relativo
                MOV     [BYTE CS:SI],'('     ;Esempio: JMP (4580,X)
                INC     SI
                POP     BX
                PUSH    BX
                MOV     CX,[BX+1]
                CALL    CONV_HEX
                MOV     CH,CL
                CALL    CONV_HEX
                MOV     [BYTE CS:SI],','
                INC     SI
                MOV     [BYTE CS:SI],'X'
                INC     SI
                MOV     [BYTE CS:SI],')'
                INC     SI
                MOV     CL,2                 ;Scrive 2 spazi dentro la stringa
                JMP     ADD_SPACES           ;per terminarla
REL_F:          POP     BX                   ;Modo di indirizzamento relativo
                PUSH    BX                   ;Es.: BCC 54=746C
                MOV     CH,[BX+1]
                CALL    CONV_HEX
                MOV     [BYTE CS:SI],'='
                INC     SI
                INC     BX                   ;Calcola la locazione a cui saltare
                INC     BX
                MOV     AL,CH
                CBW
                ADD     BX,AX
                MOV     CH,BH                ;Scrive la locazione a cui saltare
                CALL    CONV_HEX
                MOV     CH,BL
                CALL    CONV_HEX
                MOV     CL,3                 ;Scrive 3 spazi dentro la stringa
ADD_SPACES:     XOR     CH,CH                ;Usa CX come contatore di spazi
SPACES_LOOP:    MOV     [BYTE CS:SI],' '     ;Aggiunge uno spazio alla stringa
                INC     SI
                LOOP    SPACES_LOOP          ;Cicla CL volte
                MOV     BX,[CS:LOG_FILE_HANDLE] ;BX = file handle
                MOV     CX,LOG_LINE_SIZE     ;CX = numero di bytes da scrivere
                MOV     DX,OFFSET CS:LOG_BUFFER ;Stringa da scrivere nel file
                MOV     AX,CS                ;Copia CS in DS
                MOV     DS,AX
                MOV     AH,40H               ;Servizio DOS scrittura file
                INT     21H                  ;Scrive la stringa nel file
                JC      WLL_RET              ;Se c'ä un errore, esce subito
                CMP     AX,CX                ;Controlla se il disco ä pieno
                JNB     WLL_RET              ;Se no, esce
                STC                          ;Se sç, setta il carry
WLL_RET:        POP     SI                   ;Ripristina i registri come erano
                POP     ES                   ;al momento della chiamata
                POP     DS
                POP     BP
                POP     DI
                POP     DX
                POP     CX
                POP     BX
                POP     AX
                RET                          ;Ritorna alla procedura chiamante
ENDP            WRITE_LOG_LINE

;------------------------------------------------------------------------------;
;Questa procedura converte il valore di CH in esadecimale e scrive il risultato;
;come due caratteri ASCII alla locazione CS:SI, incrementando SI di due unitÖ. ;
;                                                                              ;
;Registri utilizzati: Nessuno                                                  ;
;------------------------------------------------------------------------------;
PROC            CONV_HEX
                PUSH    AX                   ;Salva il registro utilizzato AX
                MOV     AL,CH                ;Carica in AL il valore da scrivere
                SHR     AL,1                 ;AL = nibble alto del valore
                SHR     AL,1
                SHR     AL,1
                SHR     AL,1
                ADD     AL,'0'               ;Converte AL in una cifra
                CMP     AL,'9'               ;Occorre una lettera A-F?
                JNG     HIGH_NIBBLE_OK       ;No, va bene cosç
                ADD     AL,7                 ;Sç, converte AL in una lettera
HIGH_NIBBLE_OK: MOV     [CS:SI],AL           ;Salva il carattere nella stringa
                INC     SI                   ;Incr. puntatore dentro la stringa
                MOV     AL,CH                ;Carica in AL il valore da scrivere
                AND     AL,0FH               ;AL = nibble basso del valore
                ADD     AL,'0'               ;Converte AL in una cifra
                CMP     AL,'9'               ;Occorre una lettera A-F?
                JNG     LOW_NIBBLE_OK        ;No, va bene cosç
                ADD     AL,7                 ;Sç, converte AL in una lettera
LOW_NIBBLE_OK:  MOV     [CS:SI],AL           ;Salva il carattere nella stringa
                INC     SI                   ;Incr. puntatore dentro la stringa
                POP     AX                   ;Ripristina registro utilizzato
                RET                          ;Ritorna alla procedura chiamante
ENDP            CONV_HEX

		ASSUME  CS:CSEG,DS:DSEG,SS:SSEG
PUBLIC          CLOSE_LOG_FILE
;------------------------------------------------------------------------------;
;Questa procedura chiude il file su cui ä stato salvato il tracciamento delle  ;
;istruzoni eseguite dal 65C12 emulato.                                         ;
;                                                                              ;
;In uscita: CF=1 se si ä verificato un errore durante la chiusura del file     ;
;Registri utilizzati: AH, BX + tutti i registri utilizzati dalla funzione 3EH  ;
;                     del DOS (informazione non disponibile)                   ;
;------------------------------------------------------------------------------;
PROC            CLOSE_LOG_FILE
                MOV     AH,3EH               ;Funz. DOS per chiudere un file
                MOV     BX,[CS:LOG_FILE_HANDLE] ;Carica in BX l'handle del file
                INT     21H                  ;Chiude il file
                RET                          ;Ritorna alla procedura chiamante
ENDP            CLOSE_LOG_FILE

;˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛;
; AREA DATI NEL CS PER IL TRACCIAMENTO SU FILE DELLE ISTRUZIONI ESEGUITE       ;
;˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛;
PUBLIC          DEBUG_ON
DEBUG_ON        DB      0                    ;1 se occorre tracciare su file le
                                             ;istruzioni, 0 altrimenti
LOG_FILE_HANDLE DW      ?                    ;Handle del file di log
LOG_BUFFER      DB      LOG_LINE_SIZE DUP(?)
;Tabella dei codici mnemonici e modi di indirizzamento associati agli opcodes.
;Per ogni opcode da 00H a FFH la tabella contiene 4 bytes; i primi 3 sono il
;codice mnemonico ASCII, il quarto indica il modo di indirizzamento come segue:
;01H = Implicito (IMP)                   02H = All'accumulatore (ACC)
;03H = Immediato (IMM)                   04H = Assoluto (ABS)
;05H = In pagina zero (ZPG)              06H = Indiretto assoluto (IND)
;07H = Indiretto in pagina zero (IZP)
;08H = Indicizzato assoluto tramite X (INX)
;09H = Indicizzato assoluto tramite Y (INY)
;0AH = Indicizzato in pagina zero tramite X (IZX)
;0BH = Indicizzato in pagina zero tramite Y (IZY)
;0CH = Indiretto pre-indicizzato (IPR)   0DH = Indiretto post-indicizzato (IPO)
;0EH = Indiretto pre-indicizzato assoluto (IPA)   0FH = Relativo
MNEMONICS       DB      'BRK',001H,'ORA',00CH,'NOP',005H,'NOP',001H
                DB      'TSB',005H,'ORA',005H,'ASL',005H,'NOP',001H
                DB      'PHP',001H,'ORA',003H,'ASL',002H,'NOP',001H
                DB      'TSB',004H,'ORA',004H,'ASL',004H,'NOP',001H
                DB      'BPL',00FH,'ORA',00DH,'ORA',007H,'NOP',001H
                DB      'TRB',005H,'ORA',00AH,'ASL',00AH,'NOP',001H
                DB      'CLC',001H,'ORA',003H,'INC',002H,'NOP',001H
                DB      'TRB',004H,'ORA',004H,'ASL',004H,'NOP',001H
                DB      'JSR',004H,'AND',00CH,'NOP',005H,'NOP',001H
                DB      'BIT',005H,'AND',005H,'ROL',005H,'NOP',001H
                DB      'PLP',001H,'AND',003H,'ROL',002H,'NOP',001H
                DB      'BIT',004H,'AND',004H,'ROL',004H,'NOP',001H
                DB      'BMI',00FH,'AND',00DH,'AND',007H,'NOP',001H
                DB      'BIT',00AH,'AND',00AH,'ROL',00AH,'NOP',001H
                DB      'SEC',001H,'AND',009H,'DEC',002H,'NOP',001H
                DB      'BIT',008H,'AND',009H,'ROL',009H,'NOP',001H
                DB      'RTI',001H,'EOR',00CH,'NOP',005H,'NOP',001H
                DB      'NOP',005H,'EOR',005H,'LSR',005H,'NOP',001H
                DB      'PHA',001H,'EOR',003H,'LSR',002H,'NOP',001H
                DB      'JMP',004H,'EOR',004H,'LSR',004H,'NOP',001H
                DB      'BVC',00FH,'EOR',00DH,'EOR',007H,'NOP',001H
                DB      'NOP',005H,'EOR',00AH,'LSR',00AH,'NOP',001H
                DB      'CLI',001H,'EOR',009H,'PHY',001H,'NOP',001H
                DB      'NOP',004H,'EOR',008H,'LSR',008H,'NOP',001H
                DB      'RTS',001H,'ADC',00CH,'NOP',005H,'NOP',001H
                DB      'STZ',005H,'ADC',005H,'ROR',005H,'NOP',001H
                DB      'PLA',001H,'ADC',003H,'ROR',002H,'NOP',001H
                DB      'JMP',006H,'ADC',004H,'ROR',004H,'NOP',001H
                DB      'BVS',00FH,'ADC',00DH,'ADC',007H,'NOP',001H
                DB      'STZ',00AH,'ADC',00AH,'ROR',00AH,'NOP',001H
                DB      'SEI',001H,'ADC',009H,'PLY',001H,'NOP',001H
                DB      'JMP',00EH,'ADC',008H,'ROR',008H,'NOP',001H
                DB      'BRA',00FH,'STA',00CH,'NOP',005H,'NOP',001H
                DB      'STY',005H,'STA',005H,'STX',005H,'NOP',001H
                DB      'DEY',001H,'BIT',003H,'TXA',001H,'NOP',001H
                DB      'STY',004H,'STA',004H,'STX',004H,'NOP',001H
                DB      'BCC',00FH,'STA',00DH,'STA',007H,'NOP',001H
                DB      'STY',00AH,'STA',00AH,'STX',00BH,'NOP',001H
                DB      'TYA',001H,'STA',009H,'TXS',001H,'NOP',001H
                DB      'STZ',004H,'STA',008H,'STZ',008H,'NOP',001H
                DB      'LDY',003H,'LDA',00CH,'LDX',003H,'NOP',001H
                DB      'LDY',005H,'LDA',005H,'LDX',005H,'NOP',001H
                DB      'TAY',001H,'LDA',003H,'TAX',001H,'NOP',001H
                DB      'LDY',004H,'LDA',004H,'LDX',004H,'NOP',001H
                DB      'BCS',00FH,'LDA',00DH,'LDA',007H,'NOP',001H
                DB      'LDY',00AH,'LDA',00AH,'LDX',00BH,'NOP',001H
                DB      'CLV',001H,'LDA',009H,'TSX',001H,'NOP',001H
                DB      'LDY',008H,'LDA',008H,'LDX',009H,'NOP',001H
                DB      'CPY',003H,'CMP',00CH,'NOP',005H,'NOP',001H
                DB      'CPY',005H,'CMP',005H,'DEC',005H,'NOP',001H
                DB      'INY',001H,'CMP',003H,'DEX',001H,'NOP',001H
                DB      'CPY',004H,'CMP',004H,'DEC',004H,'NOP',001H
                DB      'BNE',00FH,'CMP',00DH,'CMP',007H,'NOP',001H
                DB      'NOP',005H,'CMP',00AH,'DEC',00AH,'NOP',001H
                DB      'CLD',001H,'CMP',008H,'PHX',001H,'NOP',001H
                DB      'NOP',004H,'CMP',009H,'DEC',009H,'NOP',001H
                DB      'CPX',003H,'SBC',00CH,'NOP',005H,'NOP',001H
                DB      'CPX',005H,'SBC',005H,'INC',005H,'NOP',001H
                DB      'INX',001H,'SBC',003H,'NOP',001H,'NOP',001H
                DB      'CPX',004H,'SBC',004H,'INC',004H,'NOP',001H
                DB      'BEQ',00FH,'SBC',00DH,'SBC',007H,'NOP',001H
                DB      'NOP',005H,'SBC',00AH,'INC',00AH,'NOP',001H
                DB      'SED',001H,'SBC',009H,'PLX',001H,'NOP',001H
                DB      'NOP',004H,'SBC',008H,'INC',008H,'NOP',001H

ENDS            CSEG

END
