;------------------------------------------------------------------------------;
; UNIVERSITA' DEGLI STUDI DI PARMA - CORSO DI LAUREA IN INGEGNERIA ELETTRONICA ;
;     A.A.1997/98 - CORSO DI CALCOLATORI ELETTRONICI - PROF. GIANNI CONTE      ;
;                     Carlo Concari         Matricola 103753                   ;
;                                                                              ;
;65C12 EMULATOR - Emulatore software per PC IBM del processore 65C12.          ;
;Questo file contiene il punto di ingresso del programma (MAIN) e le procedure ;
;di interfaccia con l'utente.                                                  ;
;                                                                              ;
;Files correlati: 65C12.ASM                                                    ;
;------------------------------------------------------------------------------;
IDEAL
MODEL SMALL

LF              EQU     0AH
CR              EQU     0DH
ED              EQU     24H
NMIVECT         EQU     0FFFAH
RESVECT         EQU     0FFFCH
IRQVECT         EQU     0FFFEH

SEGMENT         DSEG    PUBLIC 'DATA'
START_ADDR      DW      ?                    ;Indir. zona mem. da caric. o salv.
END_ADDR        DW      ?                    ;Fine zona di memoria da salvare
USCITA          DB      00H                  ;Vale 1 se l'utente ha deciso di
                                             ;uscire dal programma, 0 altrim.
WORD_BUFFER     DB      05H,5 DUP(?)         ;Buffer lettura word da tastiera
FILENAME        DB      30H,31H DUP(?)       ;Buffer lettura nome file da tast.
SEL_PAGE        DB      ?                    ;Pagina selezionata durante la
                                             ;modifica dei tipi di memoria
PRES1           DB      '         ˛  UNIVERSITY OF PARMA - ELECTRONIC ENGINEERING '
                DB      'DEPARTMENT  ˛          ',00H
PRES2           DB      '     ˛ ELECTRONIC CALCULATORS EXAM - PROFs. GIANNI'
                DB      ' CONTE, ALBERTO BROGGI ˛      ',00H
PRES3           DB      ' ˛ A.Y. 1997-1998 ˛ ',00H
PRES4           DB      '6 5 C 1 2    E M U L A T O R',00H
PRES5           DB      'by Carlo Concari',00H
PRES6           DB      'version  1.1',00H
PRES7           DB      'PRESS ANY KEY TO CONTINUE',00H
PRES8           DB      '˙˙˙˙----ƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒ-----˙˙˙˙',00H
NOMESS          DB      00H
MAINMENU1       DB      'M A I N    M E N U',00H
MAINMENU2       DB      '(R)ead memory zone from file',00H
MAINMENU3       DB      '(W)rite memory zone to file',00H
MAINMENU4       DB      '(A)ssign memory type by pages',00H
MAINMENU5       DB      '(M)odify interrupt vectors',00H
MAINMENU6A      DB      '(B)RK executes normally',00H
MAINMENU6B      DB      '(B)RK terminates the emulation',00H
MAINMENU7A      DB      '(I)nstruction timing OFF',00H
MAINMENU7B      DB      '(I)nstruction timing ON',00H
MAINMENU8A      DB      '(C)lock rate = 1 MHz',00H
MAINMENU8B      DB      '(C)lock rate = 2 MHz',00H
MAINMENU9A      DB      '(L)og file OFF',00H
MAINMENU9B      DB      '(L)og file ON',00H
MAINMENU10      DB      '(S)tart emulation',00H
MAINMENU11      DB      '(E)xit program',00H
MAINMENU12      DB      'Press a key corresponding to the desired '
                DB      'function',00H
MAINMENUMESS1   DB      '⁄ƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒ'
                DB      'ƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒø',00H
MAINMENUMESS2   DB      '¿ƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒ'
                DB      'ƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒŸ',00H
MAINMENUMESS3   DB      '≥',00H
LOAD_MEM_1      DB      'Memory address to load file at?     ',00H
LOAD_MEM_2      DB      'Name of the file to load? ',00H
LOAD_MEM_MES1   DB      'Error opening the file',00H
LOAD_MEM_MES2   DB      'Error writing the file',00H
LOAD_MEM_MES3   DB      'Error closing the file',00H
SAVE_MEM_1      DB      'Start address of memory zone to be saved?     ',00H
SAVE_MEM_2      DB      'End address of memory zone to be saved?     ',00H
SAVE_MEM_3      DB      'Name of the file to save? ',00H
SAVE_MEM_MES2   DB      'Error writing the file',00H
MEM_TYPE_1      DB      'Select a memory page using the arrow keys.',00H
MEM_TYPE_2      DB      'Press A, O, I to assign respectively RAM, ROM, I/O'
                DB      ' memory.',00H
MEM_TYPE_3      DB      ' ',00H
MEM_TYPE_4      DB      'L S D',00H
MEM_TYPE_5      DB      'Press ESC to go back to the main menu.',00H
MEM_TYPE_RAM    DB      'RAM',00H
MEM_TYPE_ROM    DB      'ROM',00H
MEM_TYPE_IO     DB      'I/O',00H
CHANGE_VEC_1    DB      'Current interrupt vectors:  IRQ = 0200   NMI = 0200  '
                DB      ' RESET = 0200',00H
CHANGE_VEC_2    DB      'New value for IRQ vector?       ',00H
CHANGE_VEC_3    DB      'New value for NMI vector?       ',00H
CHANGE_VEC_4    DB      'New value for RESET vector?       ',00H
EMUL_MESS       DB      'Emulation in progress... Press ESC to terminate       '
                DB      '                    ',00H
ENDS            DSEG

SEGMENT         CSEG    PUBLIC 'CODE'

                ASSUME  CS:CSEG,DS:DSEG,SS:SSEG
EXTRN           BRKIMP:NEAR                  ;In 65C12.ASM
EXTRN           END_EMUL_BRK:NEAR            ;In 65C12.ASM
EXTRN           INSTRTABLE:WORD              ;In 65C12.ASM
EXTRN           MEMORY_TABLE:BYTE            ;In 65C12.ASM
EXTRN           TIMER_ON:BYTE                ;In TIMER.ASM
EXTRN           DEBUG_ON:BYTE                ;In DEBUG.ASM
;------------------------------------------------------------------------------;
;Questa procedura rappresenta il punto di ingresso del programma; dopo aver    ;
;visualizzato una semplice presentazione, implementa il ciclo principale del   ;
;programma dal quale richiama la routine del menó principale.                  ;
;------------------------------------------------------------------------------;
PROC            MAIN
                PUSH    DS                   ;Pone nello stack l'indirizzo FAR
                MOV     AX,0000H             ;di ritorno per tornare al DOS
                PUSH    AX
                CALL    INIZIALIZZA
                CALL    PRESENTAZIONE        ;Visualizza la presentazione
                MOV     DX,OFFSET NOMESS
MAIN_LOOP:      CALL    MAIN_MENU            ;Visualizza il menu principale ed
                                             ;attende un comando
                CMP     [USCITA],0           ;L'utente ha deciso di uscire?
                JE      MAIN_LOOP            ;Se no, esegue un altro ciclo
                MOV     AX,0003H             ;Seleziona modo video testo 80x25
                INT     10H                  ;a 16 colori tramite il BIOS
                RETF                         ;Ritorna al sistema operativo
ENDP            MAIN

;------------------------------------------------------------------------------;
;Questa procedura inizializza l'emulatore, azzera la memoria del 65C12 ed      ;
;inizializza i vettori del 65C12 a 0200H.                                      ;
;                                                                              ;
;In uscita: DS punta al segmento dei dati                                      ;
;Registri utilizzati: AX, ES                                                   ;
;------------------------------------------------------------------------------;
PROC            INIZIALIZZA
                MOV     AX,DSEG              ;Fa puntare DS al sergmento dati
                MOV     DS,AX
                MOV     AX,MSEG              ;Fa puntare ES alla memoria del
                MOV     ES,AX                ;65C12
                XOR     CX,CX                ;Azzera 64K bytes
                XOR     DI,DI                ;Inizia all'offset 0000H
                XOR     AL,AL
                CLD                          ;Setta direzione positiva stringhe
INIT_LOOP:      STOSB                        ;Azzera un byte di memoria
                LOOP    INIT_LOOP
                MOV     AX,0200H
                MOV     [ES:IRQVECT],AX      ;Inizializza tutti i vettori del
                MOV     [ES:NMIVECT],AX      ;65C12 a 0200H
                MOV     [ES:RESVECT],AX
                RET                          ;Ritorna alla procedura chiamante
ENDP            INIZIALIZZA

;------------------------------------------------------------------------------;
;Questa procedura visualizza la presentazione del programma.                   ;
;                                                                              ;
;Registri utilizzati: Tutti tranne BL, ES                                      ;
;Subroutines richiamate: HIDE_CURSOR, WRITE_STRING, READ_KEY                   ;
;------------------------------------------------------------------------------;
PROC            PRESENTAZIONE
                MOV     AX,0003H             ;Seleziona modo video testo 80x25
                INT     10H                  ;a 16 colori tramite il BIOS
                MOV     AX,0600H             ;Disegna una finestra rossa al
                MOV     BH,47H               ;centro dello schermo alle coord.
                MOV     CX,0813H             ;angolo sup. sx: X=19, Y=8
                MOV     DX,103CH             ;angolo inf. dx: X=60, Y=16
                INT     10H
                MOV     BL,1EH               ;Sfondo blu, colore giallo
                MOV     BP,OFFSET PRES1
                MOV     DX,0000H             ;X=0, Y=0
                CALL    WRITE_STRING
                MOV     BL,1FH               ;Sfondo blu, colore bianco
                MOV     BP,OFFSET PRES2
                MOV     DX,0100H             ;X=0, Y=1
                CALL    WRITE_STRING
                MOV     BL,1FH               ;Sfondo blu, colore bianco
                MOV     BP,OFFSET PRES3
                MOV     DX,021EH             ;X=30, Y=2
                CALL    WRITE_STRING
                MOV     BL,4EH               ;Sfondo rosso, colore giallo
                MOV     BP,OFFSET PRES4
                MOV     DX,0A1AH             ;X=26, Y=10
                CALL    WRITE_STRING
                MOV     BL,4FH               ;Sfondo rosso, colore bianco
                MOV     BP,OFFSET PRES5
                MOV     DX,0D20H             ;X=32, Y=13
                CALL    WRITE_STRING
                MOV     BL,4FH               ;Sfondo rosso, colore bianco
                MOV     BP,OFFSET PRES6
                MOV     DX,0E22H             ;X=34, Y=14
                CALL    WRITE_STRING
                MOV     BL,82H               ;Sfondo nero, colore verde, lamp.
                MOV     BP,OFFSET PRES7
                MOV     DX,161CH             ;X=28, Y=22
                CALL    WRITE_STRING
                MOV     BL,4CH               ;Sfondo rosso, colore rosso chiaro
                MOV     BP,OFFSET PRES8
                MOV     DX,0914H             ;X=20, Y=9
                CALL    WRITE_STRING
                MOV     BL,4CH               ;Sfondo rosso, colore rosso chiaro
                MOV     BP,OFFSET PRES8
                MOV     DX,0B14H             ;X=20, Y=11
                CALL    WRITE_STRING
                CALL    HIDE_CURSOR          ;Nasconde il cursore
                CALL    READ_KEY             ;Aspetta la pressione di un tasto
                RET                          ;Ritorna alla procedura chiamante
ENDP            PRESENTAZIONE

EXTRN           FCLOCK:BYTE                  ;In TIMER.ASM
EXTRN           EMU65C12:PROC                ;In 65C12.ASM
;------------------------------------------------------------------------------;
;Questa procedura visualizza la schermata del menó principale, attende la      ;
;pressione di un tasto e richiama la routine selezionata; al termine di questa ;
;il controllo viene subito restituito alla procedura chiamante.                ;
;Le subroutines richiamate da MAIN_MENU devono ritornare in DX l'offset del    ;
;messaggio che MAIN_MENU visualizzerÖ alla prossima chiamata. La procedura     ;
;chiamante quindi non deve modificare il registro DX tra una chiamata e        ;
;l'altra.                                                                      ;
;                                                                              ;
;In ingresso: DS:DX = indirizzo del messaggio da visualizzare nell'apposita    ;
;                     area                                                     ;
;In uscita: DS:DX = indirizzo del prossimo messaggio da visualizzare           ;
;Registri utilizzati: Tutti tranne ES se esso non viene utilizzato dalle       ;
;                     funzioni 0CH, 3CH, 3DH, 3EH, 3FH, 40H del DOS            ;
;                     (informazione non disponibile)                           ;
;Subroutines richiamate: WAIT_RETRACE, CLEAR_SCREEN, WRITE_STRING, READ_KEY,   ;
;                        LOAD_MEM, SAVE_MEM, MEM_TYPE, CHANGE_VEC, EMU65C12   ;
;------------------------------------------------------------------------------;
PROC            MAIN_MENU
                CALL    WAIT_RETRACE         ;Aspetta l'inizio della ritraccia
                                             ;vert. per non avere 'flickering'
                PUSH    DX                   ;Salva l'offset del messaggio
                MOV     BH,07H               ;Colore nero per lo sfondo
                CALL    CLEAR_SCREEN         ;Pulisce lo schermo

                POP     DX                   ;Ripristina l'offset del messaggio
                MOV     BP,DX                ;Visualizza il messaggio
                MOV     BL,0CH               ;Sfondo nero, colore rosso chiaro
                MOV     DX,1703H             ;X=3, Y=23
                CALL    WRITE_STRING

                MOV     AX,0600H             ;Disegna una finestra rossa in
                MOV     BH,47H               ;alto alle coordinate
                MOV     CX,0013H             ;angolo sup. sx: X=19, Y=0
                MOV     DX,023CH             ;angolo inf. dx: X=60, Y=2
                INT     10H
                MOV     BL,4EH               ;Sfondo rosso, colore giallo
                MOV     BP,OFFSET PRES4
                MOV     DX,011AH             ;X=26, Y=1
                CALL    WRITE_STRING
                MOV     BL,4CH               ;Sfondo rosso, colore rosso chiaro
                MOV     BP,OFFSET PRES8
                MOV     DX,0014H             ;X=20, Y=0
                CALL    WRITE_STRING
                MOV     BL,4CH               ;Sfondo rosso, colore rosso chiaro
                MOV     BP,OFFSET PRES8
                MOV     DX,0214H             ;X=20, Y=2
                CALL    WRITE_STRING
                MOV     BL,0FH               ;Sfondo nero, colore bianco
                MOV     BP,OFFSET MAINMENU1
                MOV     DX,051FH             ;X=31, Y=5
                CALL    WRITE_STRING

                MOV     BL,07H               ;Sfondo nero, colore bianco scuro
                MOV     BP,OFFSET MAINMENU2
                MOV     DX,081AH             ;X=26, Y=8
                CALL    WRITE_STRING

                MOV     BL,07H               ;Sfondo nero, colore bianco scuro
                MOV     BP,OFFSET MAINMENU3
                MOV     DX,091AH             ;X=26, Y=9
                CALL    WRITE_STRING

                MOV     BL,07H               ;Sfondo nero, colore bianco scuro
                MOV     BP,OFFSET MAINMENU4
                MOV     DX,0A1AH             ;X=26, Y=10
                CALL    WRITE_STRING

                MOV     BL,07H               ;Sfondo nero, colore bianco scuro
                MOV     BP,OFFSET MAINMENU5
                MOV     DX,0B1AH             ;X=26, Y=11
                CALL    WRITE_STRING

                MOV     BL,07H               ;Sfondo nero, colore bianco scuro
                MOV     BP,OFFSET MAINMENU6B ;Seleziona il messaggio da scrivere
                MOV     AX,[CS:INSTRTABLE]   ;a seconda che BRK venga eseguita
                CMP     AX,OFFSET END_EMUL_BRK ;normalmente o termini
                JE      MAINMENU6OK          ;l'emulazione
                MOV     BP,OFFSET MAINMENU6A
MAINMENU6OK:    MOV     DX,0C1AH             ;X=26, Y=12
                CALL    WRITE_STRING

                MOV     BL,07H               ;Sfondo nero, colore bianco scuro
                MOV     BP,OFFSET MAINMENU7B ;Seleziona il messaggio da scrivere
                MOV     AL,[CS:TIMER_ON]     ;a seconda che sia attiva o meno la
                CMP     AL,1                 ;temporizzazione delle istruzioni
                JE      MAINMENU7OK
                MOV     BP,OFFSET MAINMENU7A
MAINMENU7OK:    MOV     DX,0D1AH             ;X=26, Y=13
                CALL    WRITE_STRING

                MOV     BL,07H               ;Sfondo nero, colore bianco scuro
                MOV     BP,OFFSET MAINMENU8B ;Seleziona il messaggio da scrivere
                MOV     AL,[FCLOCK]          ;a seconda che sia attiva o meno la
                CMP     AL,2                 ;temporizzazione delle istruzioni
                JE      MAINMENU8OK
                MOV     BP,OFFSET MAINMENU8A
MAINMENU8OK:    MOV     DX,0E1AH             ;X=26, Y=14
                CALL    WRITE_STRING

                MOV     BL,07H               ;Sfondo nero, colore bianco scuro
                MOV     BP,OFFSET MAINMENU9B ;Seleziona il messaggio da scrivere
                MOV     AL,[CS:DEBUG_ON]     ;a seconda che sia attiva o meno la
                CMP     AL,1                 ;temporizzazione delle istruzioni
                JE      MAINMENU9OK
                MOV     BP,OFFSET MAINMENU9A
MAINMENU9OK:    MOV     DX,0F1AH             ;X=26, Y=15
                CALL    WRITE_STRING

                MOV     BL,07H               ;Sfondo nero, colore bianco scuro
                MOV     BP,OFFSET MAINMENU10
                MOV     DX,101AH             ;X=26, Y=16
                CALL    WRITE_STRING

                MOV     BL,07H               ;Sfondo nero, colore bianco scuro
                MOV     BP,OFFSET MAINMENU11
                MOV     DX,111AH             ;X=26, Y=17
                CALL    WRITE_STRING

                MOV     BL,0EH               ;Sfondo nero, colore giallo
                MOV     BP,OFFSET MAINMENU12
                MOV     DX,1310H             ;X=16, Y=19
                CALL    WRITE_STRING

                MOV     BL,0FH               ;Sfondo nero, colore bianco
                MOV     BP,OFFSET MAINMENUMESS1
                MOV     DX,1601H             ;X=1, Y=22
                CALL    WRITE_STRING

                MOV     BL,0FH               ;Sfondo nero, colore bianco
                MOV     BP,OFFSET MAINMENUMESS2
                MOV     DX,1801H             ;X=1, Y=24
                CALL    WRITE_STRING

                MOV     BL,0FH               ;Sfondo nero, colore bianco
                MOV     BP,OFFSET MAINMENUMESS3
                MOV     DX,1701H             ;X=1, Y=23
                CALL    WRITE_STRING

                MOV     BL,0FH               ;Sfondo nero, colore bianco
                MOV     BP,OFFSET MAINMENUMESS3
                MOV     DX,174EH             ;X=78, Y=23
                CALL    WRITE_STRING

                CALL    HIDE_CURSOR          ;Nasconde il cursore
                CALL    READ_KEY             ;Attende la pressione di un tasto
                AND     AL,223               ;Converte in maiuscolo il carattere

CONTROL_C:      CMP     AL,'R'               ;Premuto R?
                JNE     CONTROL_S            ;Se no, salta al prossimo controllo
                CALL    LOAD_MEM
                JMP     MAIN_MENU_END

CONTROL_S:      CMP     AL,'W'               ;Premuto W?
                JNE     CONTROL_A            ;Se no, salta al prossimo controllo
                CALL    SAVE_MEM
                JMP     MAIN_MENU_END

CONTROL_A:      CMP     AL,'A'               ;Premuto A?
                JNE     CONTROL_M            ;Se no, salta al prossimo controllo
                CALL    MEM_TYPE
                JMP     MAIN_MENU_END

CONTROL_M:      CMP     AL,'M'               ;Premuto M?
                JNE     CONTROL_B            ;Se no, salta al prossimo controllo
                CALL    CHANGE_VEC
                JMP     MAIN_MENU_END

CONTROL_B:      CMP     AL,'B'               ;Premuto B?
                JNE     CONTROL_T            ;Se no, salta al prossimo controllo
                MOV     DX,OFFSET BRKIMP     ;B ä stato premuto, modifica lo
                MOV     AX,[CS:INSTRTABLE]   ;stato dell'istruzione BRK
                CMP     AX,OFFSET END_EMUL_BRK
                JE      BRK_OK
                MOV     DX,OFFSET END_EMUL_BRK
BRK_OK:         MOV     [CS:INSTRTABLE],DX
                MOV     DX,OFFSET NOMESS
                JMP     MAIN_MENU_END

CONTROL_T:      CMP     AL,'I'               ;Premuto I?
                JNE     CONTROL_F            ;Se no, salta al prossimo controllo
                MOV     DL,1                 ;T ä stato premuto, modifica lo
                MOV     AL,[CS:TIMER_ON]     ;stato della temporizzazione
                CMP     AL,0
                JE      TIM_OK
                MOV     DL,0
TIM_OK:         MOV     [CS:TIMER_ON],DL
                MOV     DX,OFFSET NOMESS
                JMP     MAIN_MENU_END

CONTROL_F:      CMP     AL,'C'               ;Premuto C?
                JNE     CONTROL_L            ;Se no, salta al prossimo controllo
                MOV     DL,2                 ;F ä stato premuto, modifica la
                MOV     AL,[FCLOCK]          ;frequenza di clock
                CMP     AL,1
                JE      CLK_OK
                MOV     DL,1
CLK_OK:         MOV     [FCLOCK],DL
                MOV     DX,OFFSET NOMESS
                JMP     MAIN_MENU_END

CONTROL_L:      CMP     AL,'L'               ;Premuto L?
                JNE     CONTROL_I            ;Se no, salta al prossimo controllo
                MOV     DL,1                 ;L ä stato premuto, modifica lo
                MOV     AL,[CS:DEBUG_ON]     ;stato del file di log
                CMP     AL,0
                JE      LOG_OK
                MOV     DL,0
LOG_OK:         MOV     [CS:DEBUG_ON],DL
                MOV     DX,OFFSET NOMESS
                JMP     MAIN_MENU_END

CONTROL_I:      CMP     AL,'S'               ;Premuto S?
                JNE     CONTROL_E            ;Se no, salta al prossimo controllo
                MOV     BP,OFFSET EMUL_MESS  ;Visualizza il messaggio
                                             ;'Emulazione in corso...'
                MOV     BL,0CH               ;Sfondo nero, colore rosso chiaro
                MOV     DX,1703H             ;X=3, Y=23
                CALL    WRITE_STRING
                CALL    HIDE_CURSOR          ;Nasconde il cursore
                CALL    EMU65C12
                JMP     MAIN_MENU_END

CONTROL_E:      CMP     AL,'E'               ;Premuto E?
                JNE     NON_VALID_CHAR       ;Se no, esce (carattere non valido)
                MOV     [USCITA],1           ;Attiva il flag di uscita
                JMP     MAIN_MENU_END

NON_VALID_CHAR: MOV     DX,OFFSET NOMESS

MAIN_MENU_END:  RET                          ;Ritorna alla procedura chiamante
ENDP            MAIN_MENU

;------------------------------------------------------------------------------;
;Questa procedura permette di caricare un file nella memoria del 65C12 a       ;
;partire da una locazione X specificata. Se tale locazione sommata alla        ;
;lunghezza del file eccede FFFFH (cioä se il file non sta tutto nel segmento di;
;memoria del 65C12) viene caricata solo la prima parte del file, fino ad       ;
;occupare la locazione FFFFH della memoria del 65C12.                          ;
;                                                                              ;
;Registri utilizzati: Tutti tranne ES se esso non viene utilizzato dalle       ;
;                     funzioni 3DH, 3EH, 3FH del DOS (informazione non         ;
;                     disponibile)                                             ;
;Subroutines richiamate: CLEAR_SCREEN, WRITE_STRING, READ_WORD, MOVE_CURSOR,   ;
;                        BEEP                                                  ;
;------------------------------------------------------------------------------;
PROC            LOAD_MEM
                MOV     BH,07H               ;Attributo per lo sfondo
                CALL    CLEAR_SCREEN         ;Pulisce lo schermo

LOAD_MEM_LOOP1: MOV     BL,0FH               ;Sfondo nero, colore bianco
                MOV     BP,OFFSET LOAD_MEM_1
                MOV     DX,0101H             ;X=1, Y=1
                CALL    WRITE_STRING         ;Richiede indir. a cui caric. file
                MOV     DX,0121H
                CALL    MOVE_CURSOR
                CALL    READ_WORD            ;Attende indirizzo da tastiera
                JNC     LOAD_MEM_OK1         ;Ci sono errori?
                CALL    BEEP                 ;Se sç, emette un suono e chiede di
                JMP     LOAD_MEM_LOOP1       ;nuovo l'indirizzo
LOAD_MEM_OK1:   MOV     [START_ADDR],DX      ;Salva l'indir. in una var. tempor.

                MOV     BL,0FH               ;Sfondo nero, colore bianco
                MOV     BP,OFFSET LOAD_MEM_2
                MOV     DX,0301H             ;X=1, Y=3
                CALL    WRITE_STRING         ;Richiede il nome del file da
                MOV     DX,OFFSET FILENAME   ;caricare
                MOV     AH,0AH
                INT     21H                  ;Attende nome del file da tastiera

                MOV     SI,(OFFSET FILENAME)+1
                MOV     AL,[SI]              ;Legge il n. di caratt. introdotti
                INC     SI
                XOR     AH,AH                ;Aggiunge un byte 00H alla fine
                ADD     SI,AX                ;del nome del file
                MOV     [SI],AH
                MOV     DX,(OFFSET FILENAME)+2 ;DX punta al nome del file
                MOV     AX,3D00H
                INT     21H                  ;Apre il file
                JC      LOAD_MEM_ERR1
                PUSH    AX                   ;Salva l'handle del file
                MOV     BX,AX                ;Copia handle in BX
                XOR     CX,CX
                SUB     CX,[START_ADDR]      ;Numero max di bytes da leggere =
                                             ;= 65536 - indirizzo di partenza
                MOV     DX,[START_ADDR]      ;DS:DX = buffer in cui car. il file
                PUSH    DS                   ;Salva DS nello stack
                MOV     AX,MSEG
                MOV     DS,AX                ;DS punta alla memoria del 65C12
                MOV     AH,3FH
                INT     21H                  ;Legge dal file
                POP     DS                   ;Ripristina DS
                JC      LOAD_MEM_ERR2
                POP     BX                   ;Ripristina handle del file
                MOV     AH,3EH
                INT     21H                  ;Chiude il file
                JC      LOAD_MEM_ERR3
                MOV     DX,OFFSET NOMESS
                RET                          ;Ritorna alla procedura chiamante
LOAD_MEM_ERR1:  MOV     DX,OFFSET LOAD_MEM_MES1
                RET                          ;Ritorna alla procedura chiamante
LOAD_MEM_ERR2:  MOV     DX,OFFSET LOAD_MEM_MES2
                RET                          ;Ritorna alla procedura chiamante
LOAD_MEM_ERR3:  MOV     DX,OFFSET LOAD_MEM_MES3
                RET                          ;Ritorna alla procedura chiamante
ENDP            LOAD_MEM

;------------------------------------------------------------------------------;
;Questa procedura permette di salvare su file una parte della memoria del      ;
;65C12, specificata tramite l'indirizzo di partenza e quello di fine del blocco;
;da salvare.                                                                   ;
;                                                                              ;
;Registri utilizzati: Tutti tranne ES se esso non viene utilizzato dalle       ;
;                     funzioni 3CH, 3EH, 40H del DOS (informazione non         ;
;                     disponibile)                                             ;
;Subroutines richiamate: CLEAR_SCREEN, WRITE_STRING, READ_WORD, MOVE_CURSOR,   ;
;                        BEEP                                                  ;
;------------------------------------------------------------------------------;
PROC            SAVE_MEM
                MOV     BH,07H               ;Attributo per lo sfondo
                CALL    CLEAR_SCREEN         ;Pulisce lo schermo

SAVE_MEM_LOOP1: MOV     BL,0FH               ;Sfondo nero, colore bianco
                MOV     BP,OFFSET SAVE_MEM_1
                MOV     DX,0101H             ;X=1, Y=1
                CALL    WRITE_STRING         ;Richiede indirizzo di partenza
                MOV     DX,012BH             ;della zona di memoria da salvare
                CALL    MOVE_CURSOR
                CALL    READ_WORD            ;Attende indirizzo da tastiera
                JNC     SAVE_MEM_OK1         ;Ci sono errori?
                CALL    BEEP                 ;Se sç, emette un suono e chiede di
                JMP     SAVE_MEM_LOOP1       ;nuovo l'indirizzo
SAVE_MEM_OK1:   MOV     [START_ADDR],DX      ;Salva l'indir. in una var. tempor.

SAVE_MEM_LOOP2: MOV     BL,0FH               ;Sfondo nero, colore bianco
                MOV     BP,OFFSET SAVE_MEM_2
                MOV     DX,0201H             ;X=1, Y=2
                CALL    WRITE_STRING         ;Richiede la lunghezza della zona
                MOV     DX,0229H             ;di memoria da salvare
                CALL    MOVE_CURSOR
                CALL    READ_WORD            ;Attende lunghezza da tastiera
                JNC     SAVE_MEM_OK2         ;Ci sono errori?
                CALL    BEEP                 ;Se sç, emette un suono e chiede di
                JMP     SAVE_MEM_LOOP2       ;nuovo la lunghezza

SAVE_MEM_OK2:   CMP     DX,[START_ADDR]      ;Se l'indirizzo della fine della
                JNB     SAVE_MEM_OK3         ;zona da salvare e' minore di
                CALL    BEEP                 ;quello dell'inizio, emette un beep
                JMP     SAVE_MEM_LOOP2       ;e richiede l'ultimo dato
                
SAVE_MEM_OK3:   MOV     [END_ADDR],DX
                MOV     BL,0FH               ;Sfondo nero, colore bianco
                MOV     BP,OFFSET SAVE_MEM_3
                MOV     DX,0401H             ;X=1, Y=4
                CALL    WRITE_STRING         ;Richiede il nome del file da
                MOV     DX,OFFSET FILENAME   ;salvare
                MOV     AH,0AH
                INT     21H                  ;Attende nome del file da tastiera

                MOV     SI,(OFFSET FILENAME)+1
                MOV     AL,[SI]              ;Legge il n. di caratt. introdotti
                INC     SI
                XOR     AH,AH                ;Aggiunge un byte 00H alla fine
                ADD     SI,AX                ;del nome del file
                MOV     [SI],AH
                MOV     DX,(OFFSET FILENAME)+2 ;DX punta al nome del file
                MOV     CX,0000H             ;Attributi file normali
                MOV     AX,3C00H
                INT     21H                  ;Apre il file
                JC      SAVE_MEM_ERR1
                PUSH    AX                   ;Salva l'handle del file
                MOV     BX,AX                ;Copia handle in BX
                MOV     CX,[END_ADDR]        ;CX = indir. fine zona da salvare
                MOV     DX,[START_ADDR]      ;DS:DX = indir. blocco da salvare
                PUSH    DS                   ;Salva DS nello stack
                MOV     AX,MSEG
                MOV     DS,AX                ;DS punta alla memoria del 65C12
                CMP     CX,0FFFFH            ;Se occorre salvare tutti i 64KB di
                JNE     SAVE_MEM_OK4         ;memoria, effettua il salvataggio
                CMP     DX,0000H             ;in due riprese (la funzione DOS
                JNE     SAVE_MEM_OK4         ;di scrittura su file permette di
                MOV     CX,8000H             ;salvare un massimo di 65535 bytes)
                MOV     AH,40H
                INT     21H                  ;Scrive nel file
                POP     DS                   ;Ripristina DS
                JC      SAVE_MEM_ERR2
                POP     BX                   ;Ripristina handle del file
                PUSH    BX                   ;Salva l'handle del file
                PUSH    DS                   ;Salva DS nello stack
                MOV     AX,MSEG
                MOV     DS,AX                ;DS punta alla memoria del 65C12
                MOV     CX,8000H
                MOV     DX,CX
                JMP     SAVE_MEM_SAVE2

SAVE_MEM_OK4:   SUB     CX,DX                ;CX = lunghezza zona da salvare
                INC     CX                   ;(fine - inizio + 1)
SAVE_MEM_SAVE2: MOV     AH,40H
                INT     21H                  ;Scrive nel file
                POP     DS                   ;Ripristina DS
                JC      SAVE_MEM_ERR2
                POP     BX                   ;Ripristina handle del file
                MOV     AH,3EH
                INT     21H                  ;Chiude il file
                JC      SAVE_MEM_ERR3
                MOV     DX,OFFSET NOMESS
                RET                          ;Ritorna alla procedura chiamante
SAVE_MEM_ERR1:  MOV     DX,OFFSET LOAD_MEM_MES1
                RET                          ;Ritorna alla procedura chiamante
SAVE_MEM_ERR2:  MOV     DX,OFFSET SAVE_MEM_MES2
                RET                          ;Ritorna alla procedura chiamante
SAVE_MEM_ERR3:  MOV     DX,OFFSET LOAD_MEM_MES3
                RET                          ;Ritorna alla procedura chiamante
ENDP            SAVE_MEM

;------------------------------------------------------------------------------;
;Questa procedura permette di modificare il tipo di memoria (RAM, ROM, I/O)    ;
;associato ad ogni pagina (1 pagina = 256 bytes). Il tipo di memoria delle     ;
;pagine 0 e 1 deve essere RAM e non puï essere modificato.                     ;
;                                                                              ;
;Registri utilizzati: Tutti tranne ES se esso non viene utilizzato dalla       ;
;                     funzione 0CH del DOS (informazione non disponibile)      ;
;Subroutines richiamate: CLEAR_SCREEN, WRITE_STRING, WRITE_TYPE, READ_KEY      ;
;------------------------------------------------------------------------------;
PROC            MEM_TYPE
                CALL    CLEAR_SCREEN
                MOV     BL,0BH               ;Sfondo nero, colore azzurro
                MOV     BP,OFFSET MEM_TYPE_1
                MOV     DX,0013H             ;X=19, Y=0
                CALL    WRITE_STRING

                MOV     BL,0BH               ;Sfondo nero, colore azzurro
                MOV     BP,OFFSET MEM_TYPE_2
                MOV     DX,010BH             ;X=11, Y=1
                CALL    WRITE_STRING

                MOV     BL,0BH               ;Sfondo nero, colore azzurro
                MOV     BP,OFFSET MEM_TYPE_5
                MOV     DX,0215H             ;X=21, Y=2
                CALL    WRITE_STRING

                MOV     AL,'⁄'               ;Visualizza angolo sup. sx tabella
                MOV     [MEM_TYPE_3],AL
                MOV     BL,0FH
                MOV     BP,OFFSET MEM_TYPE_3
                MOV     DX,0608H             ;X=8, Y=6
                CALL    WRITE_STRING

                MOV     AL,'ø'               ;Visualizza angolo sup. dx tabella
                MOV     [MEM_TYPE_3],AL
                MOV     BL,0FH               ;Sfondo nero, colore bianco
                MOV     BP,OFFSET MEM_TYPE_3
                MOV     DX,0648H             ;X=72, Y=6
                CALL    WRITE_STRING

                MOV     AL,'¿'               ;Visualizza angolo inf. sx tabella
                MOV     [MEM_TYPE_3],AL
                MOV     BL,0FH               ;Sfondo nero, colore bianco
                MOV     BP,OFFSET MEM_TYPE_3
                MOV     DX,1708H             ;X=8, Y=23
                CALL    WRITE_STRING

                MOV     AL,'Ÿ'               ;Visualizza angolo inf. dx tabella
                MOV     [MEM_TYPE_3],AL
                MOV     BL,0FH               ;Sfondo nero, colore bianco
                MOV     BP,OFFSET MEM_TYPE_3
                MOV     DX,1748H             ;X=72, Y=23
                CALL    WRITE_STRING

                MOV     AL,'ƒ'               ;Visualizza bordi orizzont. tabella
                MOV     [MEM_TYPE_3],AL
                MOV     DL,9
MEM_TYPE_LOOP1: MOV     DH,6
                MOV     BL,0FH
                MOV     BP,OFFSET MEM_TYPE_3
                CALL    WRITE_STRING
                MOV     DH,23
                MOV     BL,0FH
                MOV     BP,OFFSET MEM_TYPE_3
                CALL    WRITE_STRING
                INC     DL
                CMP     DL,72
                JNE     MEM_TYPE_LOOP1

                MOV     DH,7                 ;Visualizza bordi verticali tabella
MEM_TYPE_LOOP2: MOV     DL,8
                MOV     BL,0FH
                MOV     BP,OFFSET MAINMENUMESS3
                CALL    WRITE_STRING
                MOV     DL,72
                MOV     BL,0FH
                MOV     BP,OFFSET MAINMENUMESS3
                CALL    WRITE_STRING
                INC     DH
                CMP     DH,23
                JNE     MEM_TYPE_LOOP2

                MOV     AL,'0'               ;Visual. numeri LSD sopra la tab.
                MOV     DL,10
                MOV     DH,5
MEM_TYPE_LOOP3: MOV     [MEM_TYPE_3],AL
                MOV     BL,0FH
                MOV     BP,OFFSET MEM_TYPE_3
                PUSH    AX
                CALL    WRITE_STRING
                POP     AX
                INC     AL
                CMP     AL,'9'+1             ;Se occorre passare dai numeri
                JNE     MEM_TYPE_OK1         ;alle lettere, somma 7 al codice
                ADD     AL,7                 ;ASCII
MEM_TYPE_OK1:   ADD     DL,4
                CMP     DL,74
                JNE     MEM_TYPE_LOOP3

                MOV     AL,'0'               ;Visual. num. MSD a sx della tab.
                MOV     DL,7
                MOV     DH,7
MEM_TYPE_LOOP4: MOV     [MEM_TYPE_3],AL
                MOV     BL,0FH
                MOV     BP,OFFSET MEM_TYPE_3
                PUSH    AX
                CALL    WRITE_STRING
                POP     AX
                INC     AL
                CMP     AL,'9'+1             ;Se occorre passare dai numeri
                JNE     MEM_TYPE_OK2         ;alle lettere, somma 7 al codice
                ADD     AL,7                 ;ASCII
MEM_TYPE_OK2:   INC     DH
                CMP     DH,23
                JNE     MEM_TYPE_LOOP4

                MOV     BL,0EH               ;Sfondo nero, colore giallo
                MOV     BP,OFFSET MEM_TYPE_4 ;Visualizza scritta 'L S D'
                MOV     DX,0426H             ;X=38, Y=4
                CALL    WRITE_STRING

                MOV     AL,'M'               ;Visualizza la M di 'MSD'
                MOV     [MEM_TYPE_3],AL
                MOV     BL,0EH               ;Sfondo nero, colore giallo
                MOV     BP,OFFSET MEM_TYPE_3
                MOV     DX,0D05H             ;X=5, Y=13
                CALL    WRITE_STRING

                MOV     AL,'S'               ;Visualizza la S di 'MSD'
                MOV     [MEM_TYPE_3],AL
                MOV     BL,0EH               ;Sfondo nero, colore giallo
                MOV     BP,OFFSET MEM_TYPE_3
                MOV     DX,0E05H             ;X=5, Y=14
                CALL    WRITE_STRING

                MOV     AL,'D'               ;Visualizza la D di 'MSD'
                MOV     [MEM_TYPE_3],AL
                MOV     BL,0EH               ;Sfondo nero, colore giallo
                MOV     BP,OFFSET MEM_TYPE_3
                MOV     DX,0F05H             ;X=5, Y=15
                CALL    WRITE_STRING

                MOV     AL,00H               ;Visualizza i tipi attuali di
MEM_TYPE_LOOP5: PUSH    AX                   ;memoria
                CALL    WRITE_TYPE
                POP     AX
                INC     AL
                JNE     MEM_TYPE_LOOP5

                MOV     [SEL_PAGE],00H       ;Inizialm. pos. il curs. su pag. 0
MEM_TYPE_LOOP6: MOV     AL,[SEL_PAGE]
                MOV     DL,AL                ;In DL calcola la colonna a cui
                AND     DL,0FH               ;posizionare il cursore
                SHL     DL,1
                SHL     DL,1
                ADD     DL,10
                MOV     DH,AL                ;In DH calcola la riga a cui
                SHR     DH,1                 ;posizionare il cursore
                SHR     DH,1
                SHR     DH,1
                SHR     DH,1
                ADD     DH,7

                CALL    MOVE_CURSOR          ;Sposta curs. sulla pag. selezion.
                CALL    READ_KEY             ;Attende la pressione di un tasto
                CMP     AL,27                ;ESC premuto?
                JNE     MT_NO_EXIT           ;Se no, continua
                JMP     MEM_TYPE_EXIT        ;Se sç, esce
MT_NO_EXIT:     AND     AL,223               ;Converte tasto premuto in maiusc.

                CMP     AL,'A'               ;E' stato premuto il tasto A?
                JNE     CONTROL_O            ;Se no, salta al prossimo controllo
                MOV     AL,[SEL_PAGE]        ;Se sç, crea un puntatore alla tab.
                XOR     AH,AH                ;di utilizzazione della memoria
                MOV     SI,AX
                MOV     [CS:MEMORY_TABLE+SI],0 ;Pone tipo mem. selezion. = RAM
                MOV     AL,[SEL_PAGE]
                CALL    WRITE_TYPE           ;Aggiorna la tabella sullo schermo
                INC     [SEL_PAGE]           ;Punta alla pagina successiva
                JMP     MEM_TYPE_LOOP6       ;Attende un altro tasto

CONTROL_O:      CMP     AL,'O'               ;E' stato premuto il tasto O?
                JNE     MT_CONTROL_I         ;Se no, salta al prossimo controllo
                MOV     AL,[SEL_PAGE]        ;Se sç, crea un puntatore alla tab.
                CMP     AL,02H               ;La pagina selezionata ä 0 o 1?
                JNB     MEM_TYPE_OK3         ;Se no, cambia il tipo di memoria
                CALL    BEEP                 ;Se sç, emette un beep
                JMP     MEM_TYPE_LOOP6       ;ed attende un altro tasto
MEM_TYPE_OK3:   XOR     AH,AH                ;di utilizzazione della memoria
                MOV     SI,AX
                MOV     [CS:MEMORY_TABLE+SI],1 ;Pone tipo mem. selezion. = ROM
                MOV     AL,[SEL_PAGE]
                CALL    WRITE_TYPE           ;Aggiorna la tabella sullo schermo
                INC     [SEL_PAGE]           ;Punta alla pagina successiva
                JMP     MEM_TYPE_LOOP6       ;Attende un altro tasto

MT_CONTROL_I:   CMP     AL,'I'               ;E' stato premuto il tasto I?
                JNE     CONTROL_0            ;Se no, salta al prossimo controllo
                MOV     AL,[SEL_PAGE]        ;Se sç, crea un puntatore alla tab.
                CMP     AL,02H               ;La pagina selezionata ä 0 o 1?
                JNB     MEM_TYPE_OK4         ;Se no, cambia il tipo di memoria
                CALL    BEEP                 ;Se sç, emette un beep
                JMP     MEM_TYPE_LOOP6       ;ed attende un altro tasto
MEM_TYPE_OK4:   XOR     AH,AH                ;di utilizzazione della memoria
                MOV     SI,AX
                MOV     [CS:MEMORY_TABLE+SI],2 ;Pone tipo mem. selezion. = I/O
                MOV     AL,[SEL_PAGE]
                CALL    WRITE_TYPE           ;Aggiorna la tabella sullo schermo
                INC     [SEL_PAGE]           ;Punta alla pagina successiva
                JMP     MEM_TYPE_LOOP6       ;Attende un altro tasto

CONTROL_0:      CMP     AL,00H               ;E' stato premuto un tasto esteso?
                JE      MEM_TYPE_XTEND       ;Se sç, continua
                JMP     MEM_TYPE_LOOP6       ;Se no, attende un altro tasto
MEM_TYPE_XTEND: CMP     AH,48H               ;Premuta la freccia in su?
                JNE     CONTROL_DOWN         ;Se no, salta al prossimo controllo
                SUB     [SEL_PAGE],10H
                JMP     MEM_TYPE_LOOP6       ;Attende un altro tasto

CONTROL_DOWN:   CMP     AH,50H               ;Premuta la freccia in gió?
                JNE     CONTROL_LEFT         ;Se no, salta al prossimo controllo
                ADD     [SEL_PAGE],10H
                JMP     MEM_TYPE_LOOP6       ;Attende un altro tasto

CONTROL_LEFT:   CMP     AH,4BH               ;Premuta la freccia a sinistra?
                JNE     CONTROL_RIGHT        ;Se no, salta al prossimo controllo
                DEC     [SEL_PAGE]
                JMP     MEM_TYPE_LOOP6       ;Attende un altro tasto

CONTROL_RIGHT:  CMP     AH,4DH               ;Premuta la freccia a destra?
                JNE     MEM_TYPE_NOKEY       ;Se no, attende un altro tasto
                INC     [SEL_PAGE]
MEM_TYPE_NOKEY: JMP     MEM_TYPE_LOOP6       ;Attende un altro tasto

MEM_TYPE_EXIT:  MOV     DX,OFFSET NOMESS
                RET                          ;Ritorna alla procedura chiamante
ENDP            MEM_TYPE

;------------------------------------------------------------------------------;
;Questa procedura viene utilizzata da MEM_TYPE e visualizza nella tabella il   ;
;tipo di memoria associato al numero di pagina in AL.                          ;
;                                                                              ;
;Registri utilizzati: AX, CX, BL, DX, BH, SI, DI, BP                           ;
;Subroutines richiamate: WRITE_STRING                                          ;
;------------------------------------------------------------------------------;
PROC            WRITE_TYPE
                XOR     AH,AH                ;Crea un puntatore alla tabella
                MOV     SI,AX                ;di utilizzazione della memoria
                MOV     AH,[CS:MEMORY_TABLE+SI] ;Legge il tipo di mem. associato
                                             ;alla pagina specificata
                MOV     DL,AL                ;In DL calcola la colonna a cui
                AND     DL,0FH               ;scrivere il tipo di memoria
                SHL     DL,1
                SHL     DL,1
                ADD     DL,9

                MOV     DH,AL                ;In DH calcola la riga a cui
                SHR     DH,1                 ;scrivere il tipo di memoria
                SHR     DH,1
                SHR     DH,1
                SHR     DH,1
                ADD     DH,7

                CMP     AH,00H               ;E' memoria RAM?
                JNE     CONTROL_ROM          ;No, controlla se ä ROM o I/O
                MOV     BL,2FH               ;Sç, seleziona sfondo verde
                MOV     BP,OFFSET MEM_TYPE_RAM ;e scritta 'RAM'
                JMP     DO_WRITE

CONTROL_ROM:    CMP     AH,01H               ;E' memoria ROM?
                JNE     IS_IO                ;No, allora ä I/O
                MOV     BL,4FH               ;Sç, seleziona sfondo rosso
                MOV     BP,OFFSET MEM_TYPE_ROM ;e scritta 'ROM'
                JMP     DO_WRITE

IS_IO:          MOV     BL,7FH               ;E' I/O, seleziona sfondo grigio
                MOV     BP,OFFSET MEM_TYPE_IO ;e scritta 'I/O'

DO_WRITE:       CALL    WRITE_STRING
                RET                          ;Ritorna alla procedura chiamante
ENDP            WRITE_TYPE

;------------------------------------------------------------------------------;
;Questa procedura mostra i valori attuali dei vettori di ingresso del 65C12 e  ;
;permette di modificarli.                                                      ;
;                                                                              ;
;Registri utilizzati: AX, CX, DX, SI + tutti i registri utilizzati dalla       ;
;                     funzione 0CH del DOS (informazione non disponibile)      ;
;Subroutines richiamate: WRITE_WORD, READ_WORD                                 ;
;------------------------------------------------------------------------------;
PROC            CHANGE_VEC
                PUSH    ES                   ;Salva ES nello stack
                MOV     AX,MSEG
                MOV     ES,AX                ;ES punta alla memoria del 65C12
                MOV     BH,07H               ;Attributo per lo sfondo
                CALL    CLEAR_SCREEN         ;Pulisce lo schermo
                MOV     BL,0FH               ;Sfondo nero, colore bianco
                MOV     BP,OFFSET CHANGE_VEC_1
                MOV     DX,0101H             ;X=1, Y=1
                CALL    WRITE_STRING         ;Scrive valori attuali dei vettori

CHNG_VEC_LOOP1: MOV     BL,07H               ;Sfondo nero, colore bianco scuro
                MOV     BP,OFFSET CHANGE_VEC_2
                MOV     DX,0301H             ;X=1, Y=3
                CALL    WRITE_STRING         ;Richiede nuovo valore vettore IRQ
                MOV     DX,031BH
                CALL    MOVE_CURSOR
                CALL    READ_WORD
                JNC     CHNG_VEC_OK1
                CALL    BEEP
                JMP     CHNG_VEC_LOOP1
CHNG_VEC_OK1:   MOV     [ES:IRQVECT],DX

CHNG_VEC_LOOP2: MOV     BL,07H               ;Sfondo nero, colore bianco scuro
                MOV     BP,OFFSET CHANGE_VEC_3
                MOV     DX,0501H             ;X=1, Y=5
                CALL    WRITE_STRING         ;Richiede nuovo valore vettore NMI
                MOV     DX,051BH
                CALL    MOVE_CURSOR
                CALL    READ_WORD
                JNC     CHNG_VEC_OK2
                CALL    BEEP
                JMP     CHNG_VEC_LOOP2
CHNG_VEC_OK2:   MOV     [ES:NMIVECT],DX

CHNG_VEC_LOOP3: MOV     BL,07H               ;Sfondo nero, colore bianco scuro
                MOV     BP,OFFSET CHANGE_VEC_4
                MOV     DX,0701H             ;X=1, Y=7
                CALL    WRITE_STRING         ;Richiede nuovo valore vett. RESET
                MOV     DX,071DH
                CALL    MOVE_CURSOR
                CALL    READ_WORD
                JNC     CHNG_VEC_OK3
                CALL    BEEP
                JMP     CHNG_VEC_LOOP3
CHNG_VEC_OK3:   MOV     [ES:RESVECT],DX

                MOV     DX,[ES:IRQVECT]      ;Legge il vettore IRQ
                MOV     SI,(OFFSET CHANGE_VEC_1)+34
                CALL    WRITE_WORD           ;Converte in ASCII il vettore IRQ
                MOV     DX,[ES:NMIVECT]      ;Legge il vettore NMI
                MOV     SI,(OFFSET CHANGE_VEC_1)+47
                CALL    WRITE_WORD           ;Converte in ASCII il vettore NMI
                MOV     DX,[ES:RESVECT]      ;Legge il vettore RESET
                MOV     SI,(OFFSET CHANGE_VEC_1)+62
                CALL    WRITE_WORD           ;Converte in ASCII il vettore RESET
                POP     ES                   ;Ripristina ES dallo stack
                MOV     DX,OFFSET CHANGE_VEC_1 ;Messaggio = valori attuali vett.
                RET                          ;Ritorna alla procedura chiamante
ENDP            CHANGE_VEC

;------------------------------------------------------------------------------;
;Questa procedura stampa sullo schermo una stringa alle coordinate e con       ;
;l'attributo assegnati.                                                        ;
;                                                                              ;
;In ingresso: BL = attributo col quale visualizzare la stringa                 ;
;             DH, DL = rispettivamente riga e colonna a cui stampare la stringa;
;             BP = offset nel data segment della stringa da visualizzare; la   ;
;                  stringa deve terminare con un byte 00H                      ;
;Registri utilizzati: AX, CX, BH, SI, DI, BP                                   ;
;------------------------------------------------------------------------------;
PROC            WRITE_STRING
                CLD                          ;Seleziona direz. positiva stringhe
                PUSH    ES                   ;Salva ES nello stack
                MOV     AX,DS                ;Pone ES = DSEG
                MOV     ES,AX
                MOV     SI,BP                ;Conta i caratteri che compongono
                MOV     CX,0FFFFH            ;la stringa (CX ä il contatore)
STR_LENGTH_LOOP:INC     CX
                LODSB
                CMP     AL,00H               ;La stringa termina con un byte 00H
                JNE     STR_LENGTH_LOOP
                MOV     AX,1301H             ;Seleziona servizio BIOS
                XOR     BH,BH                ;Seleziona la pagina video 0
                INT     10H                  ;Richiama servizio BIOS
                POP     ES                   ;Ripristina ES dallo stack
                RET                          ;Ritorna alla procedura chiamante
ENDP            WRITE_STRING

;------------------------------------------------------------------------------;
;Questa procedura svuota il buffer della tastiera, attende la pressione di un  ;
;tasto e ritorna il codice ASCII del tasto premuto.                            ;
;                                                                              ;
;In uscita: AL = codice ASCII del tasto premuto oppure 00H per i tasti estesi  ;
;           AH = codice tasto esteso quando AL=00H                             ;
;Registri utilizzati: Tutti i registri utilizzati dalla funzione 0CH del DOS   ;
;                     (informazione non disponibile)                           ;
;------------------------------------------------------------------------------;
PROC            READ_KEY
                MOV     AX,0C07H             ;Svuota il buffer ed attende la
                INT     21H                  ;pressione di un tasto
                CMP     AL,00H               ;E' un tasto esteso?
                JNE     KEY_OK               ;Se no, esce
                MOV     AH,07H               ;Se sç, legge il codice esteso
                INT     21H
                MOV     AH,AL                ;Copia il codice esteso in AH
                XOR     AL,AL                ;Azzera AL
KEY_OK:         RET                          ;Ritorna alla procedura chiamante
ENDP            READ_KEY

;------------------------------------------------------------------------------;
;Questa procedura sposta il cursore alle coordinate specificate.               ;
;                                                                              ;
;In ingresso: DH, DL = rispettivamente riga e colonna a cui spostare il        ;
;                      cursore                                                 ;
;Registri utilizzati: AX, BH, SI, DI, BP                                       ;
;------------------------------------------------------------------------------;
PROC            MOVE_CURSOR
                MOV     AH,02H               ;Seleziona servizio 02H
                XOR     BH,BH                ;Pagina video 0
                INT     10H                  ;Richiama l'interrupt 10H
                RET                          ;Ritorna alla procedura chiamante
ENDP            MOVE_CURSOR

;------------------------------------------------------------------------------;
;Questa procedura nasconde il cursore.                                         ;
;                                                                              ;
;Registri utilizzati: AX, BH, DX, SI, DI, BP                                   ;
;Subroutines richiamate: MOVE_CURSOR                                           ;
;------------------------------------------------------------------------------;
PROC            HIDE_CURSOR
                MOV     DX,1900H
                CALL    MOVE_CURSOR          ;Richiama l'interrupt 10H
                RET                          ;Ritorna alla procedura chiamante
ENDP            HIDE_CURSOR

;------------------------------------------------------------------------------;
;Questa procedura pulisce il video utilizzando il colore di fondo specificato. ;
;                                                                              ;
;In ingresso: BH = attributo col quale riempire lo schermo                     ;
;Registri utilizzati: AX, BH, CX, DX, SI, DI, BP                               ;
;------------------------------------------------------------------------------;
PROC            CLEAR_SCREEN
                MOV     AX,0600H             ;Selez. servizio 06H (clear screen)
                MOV     CX,0000H             ;Angolo sup. sx (riga 0, colonna 0)
                MOV     DX,184FH             ;Angolo inf. dx (riga 24, col. 79)
                INT     10H                  ;Richiama l'interrupt 10H
                RET                          ;Ritorna alla procedura chiamante
ENDP            CLEAR_SCREEN

;------------------------------------------------------------------------------;
;Questa procedura genera un 'beep' dall'altoparlante di sistema del PC.        ;
;                                                                              ;
;Registri utilizzati: Nessuno                                                  ;
;------------------------------------------------------------------------------;
PROC            BEEP
                PUSH    AX                   ;Salva i registri utilizzati
                PUSH    BX
                PUSH    CX
                PUSH    SI
                PUSH    DI
                PUSH    SP
                MOV     AX,0E07H             ;Richiama funzione BIOS per visual.
                XOR     BH,BH                ;il carattere ASCII 07H
                MOV     CX,1
                INT     10H
                POP     SP                   ;Ripristina i registri dallo stack
                POP     DI
                POP     SI
                POP     CX
                POP     BX
                POP     AX
                RET                          ;Ritorna alla procedura chiamante
ENDP            BEEP

;------------------------------------------------------------------------------;
;Questa procedura aspetta l'inizio della ritraccia verticale del video.        ;
;                                                                              ;
;Registri utilizzati: Nessuno                                                  ;
;------------------------------------------------------------------------------;
PROC            WAIT_RETRACE
                PUSH    AX                   ;Salva nello stack i registri util.
                PUSH    DX
                MOV     DX,03DAH
WR_LOOP1:       IN      AL,DX
                TEST    AL,8                 ;Primo ciclo, ripete finchä
                JNZ     WR_LOOP1             ;non finisce la ritraccia vert.
                MOV     DX,03DAH
WR_LOOP2:       IN      AL,DX
                TEST    AL,8                 ;Secondo ciclo, ripete finchä
                JZ      WR_LOOP2             ;non inizia la ritraccia vert.
                POP     DX                   ;Ripristina i registri salvati
                POP     AX
                RET                          ;Ritorna alla procedura chiamante
ENDP            WAIT_RETRACE

;------------------------------------------------------------------------------;
;Questa procedura converte una word in quattro cifre esadecimali in formato    ;
;ASCII, memorizzando la stringa generata all'offset specificato.               ;
;                                                                              ;
;In ingresso: DX = word da convertire in ASCII                                 ;
;             SI = offset in cui salvare la stringa ASCII generata             ;
;Registri utilizzati: AX, CX                                                   ;
;------------------------------------------------------------------------------;
PROC            WRITE_WORD
                ADD     SI,3                 ;Inizia dalla quarta cifra
                MOV     CX,4                 ;Genera quattro cifre esadecimali
WRITE_WRD_LOOP: MOV     AL,DL
                AND     AL,0FH               ;AL contiene il nibble da convert.
                SHR     DX,1                 ;Shifta DX a destra di un nibble
                SHR     DX,1
                SHR     DX,1
                SHR     DX,1
                ADD     AL,'0'               ;Converte in una cifra 0ˆ9
                CMP     AL,'9'               ;La cifra ä >9?
                JNA     DIGIT_OK             ;Se no, va giÖ bene
                ADD     AL,7                 ;Se sç, converte in una lettera AˆF
DIGIT_OK:       MOV     [SI],AL              ;Salva il carattere generato
                DEC     SI                   ;Punta al carattere successivo
                LOOP    WRITE_WRD_LOOP       ;Ritorna alla procedura chiamante
                RET
ENDP            WRITE_WORD

;------------------------------------------------------------------------------;
;Questa procedura accetta da tastiera un numero esadecimale di quattro cifre;  ;
;se viene introdotto un numero esadecimale corretto lo converte in una word,   ;
;altrimenti segnala un errore.                                                 ;
;                                                                              ;
;In uscita: C=0 se il numero introdotto ä corretto, C=1 altrimenti             ;
;           DX = valore introdotto se C=0                                      ;
;Registri utilizzati: AX, CX, SI + tutti i registri utilizzati dalla           ;
;                     funzione 0CH del DOS (informazione non disponibile)      ;
;------------------------------------------------------------------------------;
PROC            READ_WORD
                MOV     AH,0AH               ;Legge una stringa di 4 caratteri
                MOV     DX,OFFSET WORD_BUFFER
                INT     21H

                MOV     SI,(OFFSET WORD_BUFFER)+1
                MOV     AL,[SI]              ;Controlla il numero di caratteri
                INC     SI                   ;SI punta al primo carattere
                CMP     AL,0                 ;introdotti; se ä zero, termina con
                JNE     READ_WORD_OK1        ;un errore
                STC
                JMP     READ_WORD_END

READ_WORD_OK1:  CLD                          ;Setta direzione positiva stringhe
                XOR     DX,DX                ;DX conterrÖ la word introdotta
                XOR     AH,AH
                MOV     CX,AX                ;CX = contatore cicli
READ_WORD_LOOP: LODSB                        ;Carica uno dei caratteri introd.

                CMP     AL,'0'               ;Controlla che il carattere sia una
                JB      READ_WORD_ERR1       ;cifra esadecimale valida; se non
                CMP     AL,'F'               ;lo ä, fa un secondo tentativo in
                JA      READ_WORD_ERR1       ;READ_WORD_ERR1 per riconoscere
                CMP     AL,'A'-1             ;anche le lettere minuscole
                JA      READ_WORD_OK2
                CMP     AL,'9'+1
                JB      READ_WORD_OK3

READ_WORD_ERR1: AND     AL,223               ;Converte carattere in maiuscolo
                CMP     AL,'0'               ;Controlla che il carattere sia una
                JB      READ_WORD_ERR2       ;cifra esadecimale valida
                CMP     AL,'F'
                JA      READ_WORD_ERR2
                CMP     AL,'A'-1
                JA      READ_WORD_OK2
                CMP     AL,'9'+1
                JB      READ_WORD_OK3

READ_WORD_ERR2: STC
                JMP     READ_WORD_END
READ_WORD_OK2:  SUB     AL,7
READ_WORD_OK3:  SUB     AL,'0'               ;A questo punto AL contiene un num.
                                             ;0ˆ15 corrisp. al carattere introd.
                SHL     DX,1                 ;Aggiunge a DX la nuova cifra
                SHL     DX,1                 ;convertita, shiftando DX a destra
                SHL     DX,1                 ;di un nibble
                SHL     DX,1
                ADD     DL,AL
                LOOP    READ_WORD_LOOP       ;Esegue 1 ciclo per ogni car. intr.

READ_WORD_END:  RET                          ;Ritorna alla procedura chiamante
ENDP            READ_WORD

ENDS            CSEG

SEGMENT         SSEG    PUBLIC STACK 'STACK' ;Alloca 512 bytes di memoria
                DB      512 DUP(?)           ;per lo stack
ENDS            SSEG

SEGMENT         MSEG    PUBLIC
ENDS            MSEG

END             MAIN
