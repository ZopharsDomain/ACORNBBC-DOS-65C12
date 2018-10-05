;------------------------------------------------------------------------------;
;Questo file contiene le procedure per la temporizzazione delle istruzioni del ;
;65C12.                                                                        ;
;------------------------------------------------------------------------------;
IDEAL
MODEL           SMALL

PUBLIC          FCLOCK
SEGMENT         DSEG    PUBLIC 'DATA'
TIMER_1MHZ      EQU     152
BRESE_FRAC_1MHZ EQU     47648
TIMER_2MHZ      EQU     76
BRESE_FRAC_2MHZ EQU     23824
OLD_61H         DB      ?
FCLOCK          DB      2
ENDS            DSEG

SEGMENT         SSEG    PUBLIC STACK 'STACK'
ENDS            SSEG

SEGMENT         MSEG    PUBLIC
ENDS            MSEG

SEGMENT         CSEG    PUBLIC 'CODE'

		ASSUME  CS:CSEG,DS:DSEG,SS:SSEG
PUBLIC          INIT_TIMER
;------------------------------------------------------------------------------;
;Questa procedura inizializza il contatore 2 del timer di sistema in modalita' ;
;'rate generator' con accesso a due bytes; in pratica, dopo aver richiamato    ;
;questa procedura, leggendo due bytes consecutivi dalla porta 42H si legge una ;
;word (prima l'LSB) che rappresenta il contenuto del contatore in quel         ;
;momento. Il contatore viene decrementato di una unita' ogni 838 Ês (frequenza ;
;pari a 1.19318 MHz) permettendo cosi' di realizzare temporizzazioni con una   ;
;precisione dell'ordine del microsecondo.                                      ;
;Vengono inoltre inizializzate le variabili BRESE_SUM, BRESE_FRAC, TIMER_TICKS ;
;e LAST_TIMER in funzione della frequenza di clock selezionata (vedere la      ;
;procedura WAIT_TIMER per una spiegazione dell'algoritmo utilizzato per la     ;
;temporizzazione).                                                             ;
;NOTA: la procedura WAIT_TIMER verrÖ richiamata durante l'emulazione vera e    ;
;propria del 65C12, quando DS punterÖ alla memoria del processore emulato e    ;
;NON al data-segment DSEG; per questo tutte le variabili utilizzate anche da   ;
;WAIT_TIMER risiedono nel code-segment CSEG e richiedono l'override di segmento;
;CS:.                                                                          ;
;                                                                              ;
;Registri utilizzati: AL                                                       ;
;------------------------------------------------------------------------------;
PROC            INIT_TIMER
                IN      AL,61H               ;Abilita il conteggio del canale 2
                MOV     [OLD_61H],AL         ;del timer (pone a 1 il bit 0 della
                OR      AL,01H               ;porta 61H) salvando il vecchio
                OUT     61H,AL               ;valore della porta 61H
                MOV     AL,0B4h              ;Setta canale 2 come 'rate gener.'
                OUT     43h,AL               ;con accesso a due bytes
                MOV     AL,00h               ;Setta il valore iniziale del
                OUT     42h,AL               ;contatore pari a 0000H
                OUT     42h,AL
                MOV     [CS:BRESE_SUM],0000H ;Iniz. l'accumulatore Bresenham
                MOV     [CS:LAST_TIMER],0000H ;Iniz. ultimo valore del timer
                CMP     [BYTE PTR FCLOCK],01H ;La frequenza di clock selezionata
                JE      ONE_MHZ              ;ä di 1 MHz?
                MOV     [CS:BRESE_FRAC],BRESE_FRAC_2MHZ ;No, setta i parametri
                MOV     [CS:TIMER_TICKS],TIMER_2MHZ ;per 2 MHz
                RET                          ;Ritorna alla procedura chiamante
ONE_MHZ:        MOV     [CS:BRESE_FRAC],BRESE_FRAC_1MHZ ;Sç, setta i parametri
                MOV     [CS:TIMER_TICKS],TIMER_1MHZ ;per 1 MHz
                RET                          ;Ritorna alla procedura chiamante
ENDP            INIT_TIMER

		ASSUME  CS:CSEG,DS:MSEG,SS:SSEG
PUBLIC          WAIT_TIMER
;------------------------------------------------------------------------------;
;Questa procedura aspetta 128 cicli macchina del processore emulato dall'ultima;
;volta che ä stata richiamata o dall'ultima volta che ä stata chiamata la      ;
;procedura INIT_TIMER, ed aggiorna le variabili BRESE_SUM e LAST_TIMER.        ;
;Occorre calcolare un tempo di 64 o 128 Ês (a seconda della frequenza di clock);
;usando il timer di sistema che ha una risoluzone di 0.838 Ês. Come si vede,   ;
;ciï non puï essere fatto in modo esatto. L'idea ä quella di usare l'algoritmo ;
;di Bresenham per fornire una temporizzazione che sia esatta almeno 'in media'.;
;Per esempio con una frequenza di clock di 2MHz occorre misurare intervalli di ;
;tempo di 64 Ês, equivalenti a 76.363 impulsi del timer di sistema; l'algoritmo;
;utilizzato aspetterÖ 76 impulsi durante le prime due chiamate a questa routine;
;e 77 impulsi durante la terza chiamata, e cosç via.                           ;
;Per fare ciï la variabile BRESE_FRAC contiene 2^16 moltiplicato per la parte  ;
;frazionaria del numero di impulsi da aspettare, in questo caso 65536 * 0.363 =;
;= 23824; ad ogni chiamata tale valore viene sommato alla word BRESE_SUM. Se si;
;ha un overflow (cioä se il risultato eccede 65535) la routine aspetta 77      ;
;impulsi di clock, in caso contrario 76.                                       ;
;                                                                              ;
;Registri utilizzati: BP                                                       ;
;------------------------------------------------------------------------------;
PROC            WAIT_TIMER
                PUSH    AX                   ;Salva i registri utilizzati
                PUSH    BX
                MOV     BP,[CS:LAST_TIMER]   ;Carica in BP il valore assunto dal
                                             ;timer alla fine dell'ultima chiam.
                MOV     BX,[CS:TIMER_TICKS]  ;BX = parte intera numero di
                                             ;impulsi da aspettare
                SUB     [CS:LAST_TIMER],BX   ;Aggiorna il valore di LAST_TIMER
                                             ;per la chiamata successiva
                MOV     AX,[CS:BRESE_FRAC]   ;Carica in AX la parte frazionaria
                ADD     [CS:BRESE_SUM],AX    ;e la somma all'accum. di Bresenham
                JNC     TIMER_LOOP           ;Se non c'ä overflow va tutto bene
                DEC     [CS:LAST_TIMER]      ;C'ä overflow, decrementa
                INC     BX                   ;ulteriormente LAST_TIMER ed
                                             ;incrementa impulsi da aspettare
TIMER_LOOP:     MOV     AL,80H               ;Spedisce al timer un comando per
                OUT     43H,AL               ;salvare il contatore 2 in un latch
                IN      AL,42H               ;Legge il contatore 2 del timer
                MOV     AH,AL                ;(prima LSB, poi MSB) dal latch e
                           IN      AL,42H               ;mette il valore in AX
                XCHG    AL,AH
                ADD     AX,BX                ;AX=contatore+impulsi da aspettare
                CMP     BP,AX                ;Cfr. valore prec. del timer con AX
                JS      TIMER_LOOP           ;Ricicla se valore prec. timer < AX
                POP     BX                   ;Ripristina i registri utilizzati
                POP     AX
                RET                          ;Ritorna alla procedura chiamante
ENDP            WAIT_TIMER

		ASSUME  CS:CSEG,DS:DSEG,SS:SSEG
PUBLIC          CLOSE_TIMER
;------------------------------------------------------------------------------;
;Questa procedura riporta il timer allo stato in cui era inizialmente prima    ;
;dell'uso.                                                                     ;
;                                                                              ;
;Registri utilizzati: AL                                                       ;
;------------------------------------------------------------------------------;
PROC            CLOSE_TIMER
                MOV     AL,[OLD_61H]         ;Ripristina il valore iniziale
                OUT     61H,AL               ;della porta 61H
                RET                          ;Ritorna alla procedura chiamante
ENDP            CLOSE_TIMER

;˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛;
; AREA DATI NEL CS PER LA TEMPORIZZAZIONE DELLE ISTRUZIONI                     ;
;˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛;
PUBLIC          TIMER_ON
PUBLIC          CLOCK_CYCLES
;Area dati nel CS per l'utilizzo del timer
TIMER_ON        DB      0                    ;1 se occorre temporizzare le
                                             ;istruzioni, 0 altrimenti
LAST_TIMER      DW      ?                    ;Valore del timer alla fine
                                             ;dell'ultima chiamata a WAIT_TIMER
                                             ;o INIT_TIMER
TIMER_TICKS     DW      ?                    ;Parte intera impulsi del timer da
                                             ;aspettare
BRESE_SUM       DW      ?                    ;Accumulatore di Bresenham
BRESE_FRAC      DW      ?                    ;Parte frazionaria impulsi del
                                             ;timer da aspettare
;Tabella dei cicli di clock utilizzati per l'esecuzione di ciascun opcode.
;I dati relativi alle istruzioni documentate provengono dalla documentazione
;fornita dal costruttore; i cicli di clock richiesti dagli opcodes 'invalidi'
;(che si comportano come dei NOP) sono stati determinati sperimentalmente.
CLOCK_CYCLES    DB      7,6,2,1,5,3,5,1,3,2,2,1,6,4,6,1 ;Opcodes 00H - 0FH
                DB      2,5,4,1,5,4,6,1,2,4,2,1,6,4,6,1 ;Opcodes 10H - 1FH
                DB      6,6,2,1,3,3,5,1,4,2,2,1,4,4,6,1 ;Opcodes 20H - 2FH
                DB      2,5,5,1,4,4,6,1,2,4,2,1,4,4,6,1 ;Opcodes 30H - 3FH
                DB      6,6,2,1,3,3,5,1,3,2,2,1,3,4,6,1 ;Opcodes 40H - 4FH
                DB      2,5,5,1,4,4,6,1,2,4,3,1,8,4,6,1 ;Opcodes 50H - 5FH
                DB      6,6,2,1,3,3,5,1,4,2,2,1,6,4,6,1 ;Opcodes 60H - 6FH
                DB      2,5,5,1,4,4,6,1,2,4,4,1,6,4,6,1 ;Opcodes 70H - 7FH
                DB      2,6,2,1,3,3,3,1,2,2,2,1,4,4,4,1 ;Opcodes 80H - 8FH
                DB      2,6,5,1,4,4,4,1,2,5,2,1,4,5,5,1 ;Opcodes 90H - 9FH
                DB      2,6,2,1,3,3,3,1,2,2,2,1,4,4,4,1 ;Opcodes A0H - AFH
                DB      2,5,5,1,4,4,4,1,2,4,2,1,4,4,4,1 ;Opcodes B0H - BFH
                DB      2,6,2,1,3,3,5,1,2,2,2,1,4,4,6,1 ;Opcodes C0H - CFH
                DB      2,5,5,1,4,4,6,1,2,4,3,1,4,4,6,1 ;Opcodes D0H - DFH
                DB      2,6,2,1,3,3,5,1,2,2,2,1,4,4,6,1 ;Opcodes E0H - EFH
                DB      2,5,5,1,4,4,6,1,2,4,4,1,4,4,6,1 ;Opcodes F0H - FFH

ENDS            CSEG

END
