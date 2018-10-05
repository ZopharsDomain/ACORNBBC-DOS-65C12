;------------------------------------------------------------------------------;
;Questo file contiene le procedure di emulazione del processore 65C12.         ;
;                                                                              ;
;Files correlati: HARDWARE.ASM, TIMER.ASM, DEBUG.ASM                           ;
;------------------------------------------------------------------------------;
IDEAL
MODEL           SMALL

NMIVECT         EQU     0FFFAH
RESVECT         EQU     0FFFCH
IRQVECT         EQU     0FFFEH

SEGMENT         DSEG    PUBLIC 'DATA'
MESS1           DB      'Error opening the log file',00H
MESS2           DB      'Error writing the log file',00H
MESS3           DB      'Emulation terminated due to the pressing of the '
                DB      'ESC key',00H
MESS4           DB      'Emulation terminated due to a BRK instruction',00H
MESS5           DB      'Error closing the log file',00H
ENDS            DSEG

SEGMENT         SSEG    PUBLIC STACK 'STACK'
ENDS            SSEG

SEGMENT         CSEG    PUBLIC 'CODE'

EXTRN           INIT_TIMER:PROC              ;In TIMER.ASM
EXTRN           WAIT_TIMER:PROC              ;In TIMER.ASM
EXTRN           CLOSE_TIMER:PROC             ;In TIMER.ASM
EXTRN           TIMER_ON:BYTE                ;In TIMER.ASM
EXTRN           CLOCK_CYCLES:BYTE            ;In TIMER.ASM
EXTRN           OPEN_LOG_FILE:PROC           ;In DEBUG.ASM
EXTRN           WRITE_LOG_HEADER:PROC        ;In DEBUG.ASM
EXTRN           WRITE_LOG_LINE:PROC          ;In DEBUG.ASM
EXTRN           CLOSE_LOG_FILE:PROC          ;In DEBUG.ASM
EXTRN           DEBUG_ON:BYTE                ;In DEBUG.ASM
		ASSUME  CS:CSEG,DS:MSEG,SS:SSEG
PUBLIC          EMU65C12
PUBLIC          END_EMUL_BRK
PUBLIC          BRKIMP
;------------------------------------------------------------------------------;
;Questa ä la procedura di emulazione vera e propria.                           ;
;Il codice ä piuttosto ridondante; ciï ä dovuto alla scelta di ottimizzare     ;
;l'emulatore in velocitÖ.                                                      ;
;I registri del 65C12 sono mappati nei registri interni dell'80x86 per         ;
;ottenere la maggiore velocitÖ di esecuzione possibile.                        ;
;            Registro 65C12            Registro 80x86                          ;
;                   PC                        SI                               ;
;                   P                         AH                               ;
;                   A                         AL                               ;
;                   X                         DL                               ;
;                   Y                         DH                               ;
;                   S                         DI                               ;
;I registri BX e CL sono usati come memoria di lavoro temporanea; BX ä inoltre ;
;utilizzato come indice per la selezione del codice da eseguire in funzione    ;
;del codice operativo.                                                         ;
;Il registro CH ä utilizzato come contatore dei cicli di clock emulati.        ;
;                                                                              ;
;In uscita: DX = offset del messaggio da visualizzare                          ;
;Registri utilizzati: Tutti tranne ES                                          ;
;Subroutines richiamate: READBLBX, WRITEBXCL, INIT_TIMER, WAIT_TIMER,          ;
;                        CLOSE_TIMER, OPEN_LOG_FILE, WRITE_LOG_HEADER,         ;
;                        WRITE_LOG_LINE, CLOSE_LOG_FILE                        ;
;------------------------------------------------------------------------------;
PROC            EMU65C12
                PUSH    DS                   ;Salva DS nello stack
                CMP     [CS:TIMER_ON],1      ;Occorre temporizzare le istruz.?
                JNE     NOT_TIMED_1          ;Se no, non inizializza il timer
                CALL    INIT_TIMER           ;Se sç, inizializza il timer
                XOR     CH,CH                ;Azzera contatore cicli di clock
NOT_TIMED_1:    CMP     [CS:DEBUG_ON],1      ;Occorre creare un file di log?
                JNE     NO_DEBUG_1           ;No, non crea il file di log
                CALL    OPEN_LOG_FILE        ;Sç, apre il file di log
                JNC     OPEN_LOG_OK
                JMP     ERR_OPEN_LOG         ;Se c'ä un errore, esce
OPEN_LOG_OK:    CALL    WRITE_LOG_HEADER     ;Scrive intestazione nel log file
                JNC     NO_DEBUG_1
                JMP     ERR_WRITE_LOG        ;Se c'ä un errore, esce
NO_DEBUG_1:     MOV     AX,MSEG              ;DS punterÖ ai 64 KB di memoria
                MOV     DS,AX                ;del 65C12
                MOV     AX,3000H             ;A=00H, P=00110000B
;Il flag B "fisico" vale sempre 1. Esso vale 0 solo nell'immagine di P posta
;nello stack in seguito ad un IRQ o NMI.
                XOR     DX,DX                ;X=00H, Y=00H
                MOV     DI,01FFH             ;S=FFH
                MOV     SI,[WORD RESVECT]    ;PC=inizio programma
                XOR     BH,BH                ;Azzera parte alta indice istr.

;˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛;
;INIZIA QUI IL CICLO PRINCIPALE DI EMULAZIONE DELLE ISTRUZIONI DEL 65C12       ;
;˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛;
NEWINS:         CMP     [CS:IRQ],0           ;IRQ in corso?
                JE      NO_IRQ
                TEST    AH,04H               ;flag I attivo?
                JNE     NO_IRQ               ;Se sç, ignora l'IRQ
                DEC     DI
                MOV     [DI],SI              ;Salva PC nello stack
                DEC     DI
                AND     AH,0EFH              ;Azzera il flag B
                MOV     [DI],AH              ;Salva P nello stack
                OR      AH,14H               ;Setta i flags B ed I
                DEC     DI
                MOV     SI,[IRQVECT]         ;PC = indir. routine servizio IRQ
                ADD     CH,7                 ;La risposta a IRQ richiede 7 cycli

NO_IRQ:         CMP     [CS:NMI],0           ;NMI in corso?
                JE      NO_NMI
                DEC     DI
                MOV     [DI],SI              ;Salva PC nello stack
                DEC     DI
                AND     AH,0EFH              ;Azzera il flag B
                MOV     [DI],AH              ;Salva P nello stack
                OR      AH,14H               ;Setta i flags B ed I
                DEC     DI
                MOV     SI,[NMIVECT]         ;PC = indir. routine servizio NMI
                ADD     CH,7                 ;La risposta a NMI richiede 7 cycli

NO_NMI:         MOV     BL,[SI]              ;Carica l'opcode da eseguire
                CMP     [CS:DEBUG_ON],1      ;Occorre creare un file di log?
                JNE     NO_DEBUG_2           ;No, non crea il file di log
                CALL    WRITE_LOG_LINE       ;Sç, scrive una linea nel log file
                JC      ERR_WRITE_LOG        ;Se c'ä un errore, esce
NO_DEBUG_2:     INC     SI                   ;Incrementa il Program Counter
                TEST    CH,CH                ;Sono stati emul. almeno 128 cicli?
                JNS     NOT_TIMED_2          ;Se no, salta all'emulazione
                AND     CH,7FH               ;Se sç, sottrae 128 ai cicli emul.
                PUSH    AX                   ;Salva AX nello stack
                IN      AL,60H               ;Legge lo stato della tastiera
                CMP     AL,1                 ;ESC premuto?
                JE      END_EMUL_ESC         ;Se sç, termina l'emulazione
                POP     AX                   ;Ripristina il valore di AX
                CMP     [CS:TIMER_ON],1      ;Occorre temporizzare le istruz.?
                JNE     NOT_TIMED_2          ;Se no, salta all'emulazione
                CALL    WAIT_TIMER           ;Se sç, salta alla routine di temp.
NOT_TIMED_2:    ADD     CH,[CS:CLOCK_CYCLES+BX] ;Somma al cont. dei cicli i
                                             ;cicli richiesti dall'istr. corr.
                SHL     BX,1                 ;Salta alla parte di codice che
                JMP     [WORD CS:INSTRTABLE+BX] ;emula l'istruzione corrente
;------------------------------------------------------------------------------;
; Codice di uscita dall'emulazione                                             ;
;------------------------------------------------------------------------------;
		ASSUME  CS:CSEG,DS:DSEG,SS:SSEG
ERR_OPEN_LOG:   POP     DS                   ;DS punta di nuovo a DSEG
                MOV     DX,OFFSET MESS1      ;Messaggio 'errore apertura file'
                RET                          ;Ritorna alla procedura chiamante

ERR_WRITE_LOG:  CMP     [CS:TIMER_ON],1      ;Occorre fermare il timer?
                JNE     NOT_TIMED_5          ;Se no, non ferma il timer
                CALL    CLOSE_TIMER          ;Se sç, ferma il timer
NOT_TIMED_5:    CALL    CLOSE_LOG_FILE       ;Sç, chiude il file di log
                POP     DS                   ;DS punta di nuovo a DSEG
                MOV     DX,OFFSET MESS2      ;Messaggio 'errore scrittura file'
                RET                          ;Ritorna alla procedura chiamante

END_EMUL_ESC:   POP     AX                   ;Ripristina AX dallo stack
                POP     DS                   ;DS punta di nuovo a DSEG
                CMP     [CS:TIMER_ON],1      ;Occorre fermare il timer?
                JNE     NOT_TIMED_3          ;Se no, non ferma il timer
                CALL    CLOSE_TIMER          ;Se sç, ferma il timer
NOT_TIMED_3:    CMP     [CS:DEBUG_ON],1      ;E' stato creato un file di log?
                JNE     NO_DEBUG_3           ;No, non chiude il file di log
                CALL    CLOSE_LOG_FILE       ;Sç, chiude il file di log
                JC      ERR_CLOSE_LOG        ;Se c'ä un errore, esce
NO_DEBUG_3:     MOV     DX,OFFSET MESS3      ;Messaggio 'ESC premuto'
                RET                          ;Ritorna alla procedura chiamante

END_EMUL_BRK:   POP     DS                   ;DS punta di nuovo a DSEG
                CMP     [CS:TIMER_ON],1      ;Occorre fermare il timer?
                JNE     NOT_TIMED_4          ;Se no, non ferma il timer
                CALL    CLOSE_TIMER          ;Se sç, ferma il timer
NOT_TIMED_4:    CMP     [CS:DEBUG_ON],1      ;E' stato creato un file di log?
                JNE     NO_DEBUG_4           ;No, non chiude il file di log
                CALL    CLOSE_LOG_FILE       ;Sç, chiude il file di log
                JC      ERR_CLOSE_LOG        ;Se c'ä un errore, esce
NO_DEBUG_4:     MOV     DX,OFFSET MESS4      ;Messaggio 'uscita su BRK'
                RET                          ;Ritorna alla procedura chiamante

ERR_CLOSE_LOG:  MOV     DX,OFFSET MESS5      ;Messaggio 'errore chiusura file'
                RET                          ;Ritorna alla procedura chiamante
;------------------------------------------------------------------------------;
;Inizia qui il codice di emulazione delle istruzioni. Le labels sono di sei    ;
;caratteri; i primi tre sono il codice mnemonico dell'istruzione, i successivi ;
;tre identificano il modo di indirizzamento:                                   ;
;IMP=implicito   ACC=all'accumulatore   IMM=immediato   ABS=Assoluto           ;
;ZPG=in pagina zero   IND=indiretto assoluto   IZP=indiretto in pagina zero    ;
;INX=indicizzato tramite X   INY=indicizzato tramite Y   IZX=indicizzato in    ;
;pagina zero tramite X   IZY=indicizzato in pagina zero tramite Y              ;
;IPR=indiretto pre-indicizzato   IPO=indiretto post-indicizzato                ;
;IPA=indiretto pre-indicizzato assoluto   REL=relativo                         ;
;                                                                              ;
;Da esperimenti eseguiti su di un 65C12 vero si ä dedotto che:                 ;
; ˛ Gli opcodes che non corrispondono ad istruzioni documentate si comportano  ;
;   come l'istruzione NOP, ma alcune di esse incrementano PC di 2 o 3. Quelle  ;
;   che incrementano PC di 1 (compresa l'istruzione documentata NOP) saltano a ;
;   NEWINS, quelle che sommano 2 a PC sono implementate da NOPZPG, quelle che  ;
;   sommano 3 a PC da NOPABS.                                                  ;
; ˛ Nel modo di indirizzamento IZP se l'argomento ä FFH l'MSB dell'indirizzo   ;
;   viene preso da 00H e non da 100H.                                          ;
; ˛ Nel modo di indirizzamento IPR se la somma di X e del parametro supera FEH ;
;   si ha un "wraparound" (in pratica i due bytes che formano l'indirizzo sono ;
;   sempre e comunque presi dalla pagina zero).                                ;
;   NOTA: Questo non avviene nell'emulatore nel caso in cui X+parametro=FFH    ;
; ˛ Il modo di indirizzamento IPO calcola correttamente l'indirizzo se sommando;
;   Y ad (argomento) si ha un salto di pagina; tuttavia, se l'argomento vale   ;
;   FFH l'MSB dell'indirizzo viene preso da 00H e non da 100H.                 ;
;   NOTA: Questo "bug" non ä implementato nell'emulatore.                      ;
; ˛ Nei modi di indirizzamento IZX e IZY se la somma di X o Y e del parametro  ;
;   supera FFH si ha un "wraparound" in pagina zero.                           ;
; ˛ I modi di indirizzamento IND, INX, INY, IPA gestiscono correttamente i     ;
;   salti di pagina e non hanno problemi di "wraparound".                      ;
; ˛ Nel modo decimale, le istruzioni ADC e SBC si comportano esattamente come  ;
;   le sequenze ADC/DAA e SBB/DAS dell'80x86 anche nella gestione dei flags,   ;
;   tranne che per il flag di carry in una sottrazione, che nel 65C12 indica   ;
;   un prestito quando vale 0, mentre nell'80x86 indica un prestito se vale 1. ;
;                                                                              ;
;Gli errori di overflow ed underflow dello stack non vengono rilevati; in caso ;
;di errore lo stack sovrascriverÖ la pagina 0 o la pagina 2.                   ;
;                                                                              ;
;Non vengono aggiunti i cicli di clock addizionali richiesti dai modi di       ;
;indirizzamento IPO, INX, INY, REL in caso di salto di pagina.                 ;
;                                                                              ;
;Nei seguenti casi il controllo del tipo di memoria (RAM, ROM, I/O) non viene  ;
;effettuato, e la memoria viene trattata come RAM:                             ;
; ˛ Accesso allo stack od alla pagina 0; in questo modo si ha una maggiore     ;
;   efficienza (le istruzioni che accedono allo stack od alla pagina 0 vengono ;
;   eseguite molto velocemente) senza una grande perdita di funzionalitÖ (nelle;
;   applicazioni reali non ha senso mettere memoria ROM o I/O in pagina 0).    ;
; ˛ Fetch delle istruzioni e degli operandi all'indirizzo contenuto nel Program;
;   Counter.                                                                   ;
; ˛ Caricamento dell'indirizzo di salto durante l'esecuzione degli opcodes 6CH ;
;   (JMP indiretto assoluto) e 7CH (JMP indiretto pre-indicizzato assoluto).   ;
;------------------------------------------------------------------------------;
		ASSUME  CS:CSEG,DS:MSEG,SS:SSEG
BRKIMP:         DEC     DI                   ;Opcode 00H
                INC     SI                   ;Pone PC+2 nello stack
                MOV     [DI],SI
                DEC     DI
                MOV     [DI],AH              ;Pone P nello stack
                DEC     DI
                OR      AH,04H               ;Pone ad 1 il flag I
                MOV     SI,[WORD IRQVECT]    ;PC = indir. routine servizio IRQ
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ORAIPR:         MOV     BL,[BYTE SI]         ;Opcode 01H
                INC     SI                   ;Incrementa il Program Counter
                ADD     BL,DL                ;Somma X al puntatore in pagina 0
                MOV     BX,[WORD BX]         ;Carica indirizzo operando in BX
                CALL    READBLBX             ;Carica l'operando dalla memoria
                OR      AL,BL                ;Esegue l'OR tra A e l'operando
                JZ      ORAIPRISZERO         ;Setta i flags in accordo col
                JS      ORAIPRISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ORAIPRISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ORAIPRISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
NOPZPG:         INC     SI                   ;Opcodes 02H,22H,42H,44H,54H,62H,
                XOR     BH,BH                ;82H,C2H,D4H,E2H,F4H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
NOPIMP:         XOR     BH,BH                ;Opcodes ?3H,?7H,?BH,?FH,EAH
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
TSBZPG:         MOV     BL,[BYTE SI]         ;Opcode 04H
                INC     SI                   ;Incrementa il Program Counter
                MOV     CL,[BYTE BX]         ;Carica il CL l'operando
                OR      [BYTE BX],AL         ;Esegue l'OR tra l'operando ed A
                AND     CL,AL                ;Esegue l'AND tra l'operando ed A
                JNZ     TSBZPGNOTZERO        ;Setta il flag Z di conseguenza
                OR      AH,02H               ;Z=1
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
TSBZPGNOTZERO:  AND     AH,0FDH              ;Z=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ORAZPG:         MOV     BL,[BYTE SI]         ;Opcode 05H
                INC     SI                   ;Incrementa il Program Counter
                OR      AL,[BYTE BX]         ;Esegue l'OR tra A e l'operando
                JZ      ORAZPGISZERO         ;Setta i flags in accordo col
                JS      ORAZPGISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ORAZPGISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ORAZPGISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ASLZPG:         MOV     BL,[BYTE SI]         ;Opcode 06H
                INC     SI                   ;Incrementa il Program Counter
                AND     AH,0FEH              ;Prepara C=0, C verrÖ settato
                                             ;in seguito se necessario
                SHL     [BYTE BX],1          ;Esegue lo shift a sinistra
                JZ      ASLZPGISZERO         ;Setta i flags in accordo col
                JS      ASLZPGISNEG          ;risultato
                JNC     ASLZPGNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
ASLZPGNOCARRY:  AND     AH,7DH
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ASLZPGISNEG:    JNC     ASLZPGISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
ASLZPGISNEGNC:  AND     AH,7DH
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ASLZPGISZERO:   JNC     ASLZPGISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
ASLZPGISZERONC: AND     AH,7DH
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
PHPIMP:         MOV     [BYTE DI],AH         ;Opcode 08H
                DEC     DI                   ;Decrementa lo Stack Pointer
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ORAIMM:         OR      AL,[BYTE SI]         ;Opcode 09H - Esegue A OR operando
                JZ      ORAIMMISZERO         ;Setta i flags in accordo col
                JS      ORAIMMISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                INC     SI                   ;Incrementa il Program Counter
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ORAIMMISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                INC     SI                   ;Incrementa il Program Counter
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ORAIMMISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                INC     SI                   ;Incrementa il Program Counter
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ASLACC:         AND     AH,0FEH              ;Opcode 0AH - Prepara C=0, C verrÖ
                                             ;settato in seguito se necessario
                SHL     AL,1                 ;Esegue lo shift a sinistra di A
                JZ      ASLACCISZERO         ;Setta i flags in accordo col
                JS      ASLACCISNEG          ;risultato
                JNC     ASLACCNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
ASLACCNOCARRY:  AND     AH,7DH
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ASLACCISNEG:    JNC     ASLACCISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
ASLACCISNEGNC:  AND     AH,7DH
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ASLACCISZERO:   JNC     ASLACCISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
ASLACCISZERONC: AND     AH,7DH
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
TSBABS:         MOV     BX,[WORD SI]         ;Opcode 0CH
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                MOV     CL,BL                ;Salva LSB indir. operando in CL
                CALL    READBLBX             ;Legge l'operando
                XCHG    BL,CL                ;Rimette operando in CL e LSB in BL
                PUSH    CX                   ;Salva l'operando nello stack
                OR      CL,AL                ;Esegue l'OR tra l'operando e A
                CALL    WRITEBXCL            ;Salva il risultato nell'operando
                POP     CX                   ;Ripristina l'operando originale
                XOR     BH,BH                ;Azzera parte alta indice istr.
                AND     CL,AL                ;Esegue l'AND tra l'operando e A
                JNZ     TSBABSNOTZERO        ;e setta il flag Z di conseguenza
                OR      AH,02H               ;Z=1
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
TSBABSNOTZERO:  AND     AH,0FDH              ;Z=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ORAABS:         MOV     BX,[WORD SI]         ;Opcode 0DH
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                CALL    READBLBX             ;Legge l'operando dalla memoria
                OR      AL,BL                ;Esegue l'OR tra l'operando e A
                JZ      ORAABSISZERO         ;Setta i flags
                JS      ORAABSISNEG
                AND     AH,7DH               ;Z=0, N=0
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ORAABSISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ORAABSISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ASLABS:         MOV     BX,[WORD SI]         ;Opcode 0EH
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                AND     AH,0FEH              ;Prepara C=0, C verrÖ settato
                                             ;in seguito se necessario
                MOV     CL,BL                ;Salva LSB indir. operando in CL
                CALL    READBLBX             ;Legge l'operando
                XCHG    BL,CL                ;Rimette operando in CL e LSB in BL
                SHL     CL,1                 ;Esegue lo shift a sinistra
                JZ      ASLABSISZERO         ;Setta i flags in accordo col
                JS      ASLABSISNEG          ;risultato
                JNC     ASLABSNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
ASLABSNOCARRY:  AND     AH,7DH
                CALL    WRITEBXCL            ;Salva il risultato di ASL in mem.
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ASLABSISNEG:    JNC     ASLABSISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
ASLABSISNEGNC:  AND     AH,7DH
                OR      AH,80H
                CALL    WRITEBXCL            ;Salva il risultato di ASL in mem.
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ASLABSISZERO:   JNC     ASLABSISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
ASLABSISZERONC: AND     AH,7DH
                OR      AH,02H
                CALL    WRITEBXCL            ;Salva il risultato di ASL in mem.
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
BPLREL:         TEST    AH,80H               ;Opcode 10H - Verifica il flag N
                JNZ     BPLRELNEG            ;Se N=1 non esegue la diramazione
                INC     CH                   ;Se salta richiede un ciclo in pió
                MOV     BX,AX                ;Salva temporaneamente A e P in BX
                MOV     AL,[SI]              ;Carica spiazzamento (-128..+127)
                CBW                          ;Converte spiazzamento in una word
                ADD     SI,AX                ;Somma lo spiazzamento al PC
                MOV     AX,BX                ;Riporta A e P rispett. in AL ed AH
                XOR     BH,BH                ;Azzera parte alta indice istr.
BPLRELNEG:      INC     SI                   ;Incrementa il Program Counter
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ORAIPO:         MOV     BL,[BYTE SI]         ;Opcode 11H
                INC     SI                   ;Incrementa il Program Counter
                MOV     BX,[WORD BX]         ;Carica indirizzo base operando
                ADD     BL,DH                ;Somma Y all'indir. base operando
                ADC     BH,00H
                CALL    READBLBX             ;Legge l'operando dalla memoria
                OR      AL,BL                ;Esegue l'OR tra A e l'operando
                JZ      ORAIPOISZERO         ;Setta i flags in accordo col
                JS      ORAIPOISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ORAIPOISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ORAIPOISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ORAIZP:         MOV     BL,[BYTE SI]         ;Opcode 12H
                INC     SI                   ;Incrementa il Program Counter
                MOV     BX,[WORD BX]         ;Carica indirizzo dell'operando
                CALL    READBLBX             ;Legge l'operando dalla memoria
                OR      AL,BL                ;Esegue l'OR tra A e l'operando
                JZ      ORAIZPISZERO         ;Setta i flags in accordo col
                JS      ORAIZPISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ORAIZPISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ORAIZPISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
TRBZPG:         MOV     BL,[BYTE SI]         ;Opcode 14H
                INC     SI                   ;Incrementa il Program Counter
                MOV     CL,[BYTE BX]         ;Carica il CL l'operando
                NOT     AL                   ;Complementa A
                AND     [BYTE BX],AL         ;Esegue OR tra operando ed A negato
                NOT     AL                   ;Rimette a posto A
                AND     CL,AL                ;Esegue l'AND tra l'operando ed A
                JNZ     TRBZPGNOTZERO        ;Setta il flag Z di conseguenza
                OR      AH,02H               ;Z=1
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
TRBZPGNOTZERO:  AND     AH,0FDH              ;Z=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ORAIZX:         MOV     BL,[BYTE SI]         ;Opcode 15H
                INC     SI                   ;Incrementa il Program Counter
                ADD     BL,DL                ;Somma X all'indir. dell'operando
                OR      AL,[BYTE BX]         ;Esegue l'OR tra A e l'operando
                JZ      ORAIZXISZERO         ;Setta i flags in accordo col
                JS      ORAIZXISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ORAIZXISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ORAIZXISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ASLIZX:         MOV     BL,[BYTE SI]         ;Opcode 16H
                INC     SI                   ;Incrementa il Program Counter
                ADD     BL,DL                ;Somma X all'indir. dell'operando
                AND     AH,0FEH              ;Prepara C=0, C verrÖ settato
                                             ;in seguito se necessario
                SHL     [BYTE BX],1          ;Esegue lo shift a sx dell'operando
                JZ      ASLIZXISZERO         ;Setta i flags in accordo col
                JS      ASLIZXISNEG          ;risultato
                JNC     ASLIZXNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
ASLIZXNOCARRY:  AND     AH,7DH
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ASLIZXISNEG:    JNC     ASLIZXISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
ASLIZXISNEGNC:  AND     AH,7DH
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ASLIZXISZERO:   JNC     ASLIZXISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
ASLIZXISZERONC: AND     AH,7DH
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
CLCIMP:         AND     AH,0FEH              ;Opcode 18H - Azzera il flag C
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ORAINY:         MOV     BL,DH                ;Opcode 19H
                ADD     BX,[WORD SI]         ;BX = Y + indirizzo base operando
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                CALL    READBLBX             ;Legge l'operando dalla memoria
                OR      AL,BL                ;Esegue l'OR tra A e l'operando
                JZ      ORAINYISZERO         ;Setta i flags in accordo col
                JS      ORAINYISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ORAINYISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ORAINYISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
INCACC:         INC     AL                   ;Opcode 1AH - Incrementa A
                JZ      INCACCISZERO         ;Setta i flags in accordo col
                JS      INCACCISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
INCACCISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
INCACCISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
TRBABS:         MOV     BX,[WORD SI]         ;Opcode 1CH
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                MOV     CL,BL                ;Salva LSB indir. operando in CL
                CALL    READBLBX             ;Legge l'operando
                XCHG    BL,CL                ;Rimette operando in CL e LSB in BL
                PUSH    CX                   ;Salva l'operando nello stack
                NOT     AL                   ;Complementa A
                AND     CL,AL                ;Esegue AND tra operando e A negato
                NOT     AL                   ;Rimette a posto A
                CALL    WRITEBXCL            ;Salva il risultato nell'operando
                POP     CX                   ;Ripristina l'operando originale
                XOR     BH,BH                ;Azzera parte alta indice istr.
                AND     CL,AL                ;Esegue l'AND tra l'operando e A
                JNZ     TRBABSNOTZERO        ;e setta il flag Z di conseguenza
                OR      AH,02H               ;Z=1
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
TRBABSNOTZERO:  AND     AH,0FDH              ;Z=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ORAINX:         MOV     BL,DL                ;Opcode 1DH
                ADD     BX,[WORD SI]         ;BX = X + indirizzo base operando
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                CALL    READBLBX             ;Legge l'operando dalla memoria
                OR      AL,BL                ;Esegue l'OR tra A e l'operando
                JZ      ORAINXISZERO         ;Setta i flags in accordo col
                JS      ORAINXISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ORAINXISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ORAINXISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ASLINX:         MOV     BL,DL                ;Opcode 1EH
                ADD     BX,[WORD SI]         ;BX = X + indirizzo base operando
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                AND     AH,0FEH              ;Prepara C=0, C verrÖ settato
                                             ;in seguito se necessario
                MOV     CL,BL                ;Salva LSB indir. operando in CL
                CALL    READBLBX             ;Legge l'operando dalla memoria
                XCHG    BL,CL                ;Rimette operando in CL e LSB in BL
                SHL     CL,1                 ;Esegue lo shift a sx dell'operando
                JZ      ASLINXISZERO         ;Setta i flags in accordo col
                JS      ASLINXISNEG          ;risultato
                JNC     ASLINXNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
ASLINXNOCARRY:  AND     AH,7DH
                CALL    WRITEBXCL            ;Salva il risultato nell'operando
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ASLINXISNEG:    JNC     ASLINXISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
ASLINXISNEGNC:  AND     AH,7DH
                OR      AH,80H
                CALL    WRITEBXCL            ;Salva il risultato nell'operando
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ASLINXISZERO:   JNC     ASLINXISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
ASLINXISZERONC: AND     AH,7DH
                OR      AH,02H
                CALL    WRITEBXCL            ;Salva il risultato nell'operando
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
JSRABS:         DEC     DI                   ;Opcode 20H
                INC     SI                   ;Incrementa il Program Counter
                MOV     [DI],SI              ;Pone PC+2 nello stack
                DEC     DI                   ;Decrementa lo stack pointer
                DEC     SI                   ;Decrementa il Program Counter per
                MOV     SI,[WORD SI]         ;leggere l'indirizzo a cui saltare
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ANDIPR:         MOV     BL,[BYTE SI]         ;Opcode 21H
                INC     SI                   ;Incrementa il Program Counter
                ADD     BL,DL                ;Somma X al puntatore in pagina 0
                MOV     BX,[WORD BX]         ;Carica indirizzo operando in BX
                CALL    READBLBX             ;Carica l'operando dalla memoria
                AND     AL,BL                ;Esegue l'AND tra A e l'operando
                JZ      ANDIPRISZERO         ;Setta i flags in accordo col
                JS      ANDIPRISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ANDIPRISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ANDIPRISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
BITZPG:         MOV     BL,[BYTE SI]         ;Opcode 24H
                INC     SI                   ;Incrementa il Program Counter
                MOV     BL,[BYTE BX]         ;Carica l'operando dalla memoria
                AND     AH,0FDH              ;Prepara Z=0, Z verrÖ settato
                                             ;in seguito se necessario
                TEST    AL,BL                ;Confronta A con l'operando
                JNE     BITZPGNOTZERO        ;e setta il flag Z di conseguenza
                OR      AH,02H               ;Z=1
BITZPGNOTZERO:  AND     AH,3FH               ;Maschera i flags N e V
                AND     BL,0C0H              ;Pone i bit 7 e 6 del dato
                OR      AH,BL                ;nei flags N e V
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ANDZPG:         MOV     BL,[BYTE SI]         ;Opcode 25H
                INC     SI                   ;Incrementa il Program Counter
                AND     AL,[BYTE BX]         ;Esegue l'AND tra A e l'operando
                JZ      ANDZPGISZERO         ;Setta i flags in accordo col
                JS      ANDZPGISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ANDZPGISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ANDZPGISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ROLZPG:         MOV     BL,[BYTE SI]         ;Opcode 26H
                INC     SI                   ;Incrementa il Program Counter
                MOV     CL,AH                ;Salva P in CL
                AND     AH,0FEH              ;Prepara C=0, C verrÖ settato
;in seguito se necessario. NOTA: AND pone anche a zero il carry dell'80x86
                TEST    CL,01H               ;Pone il flag C nel carry
                JZ      ROLZPGNC             ;dell'80x86
                STC
ROLZPGNC:       RCL     [BYTE BX],1          ;Ruota oper. a sx attrav. il carry
                MOV     BL,[BYTE BX]         ;RCL non cambia i flags, occorre
                INC     BL                   ;quindi testare il risultato
                DEC     BL                   ;(INC/DEC non modificano il CF)
                JZ      ROLZPGISZERO         ;Setta i flags in accordo col
                JS      ROLZPGISNEG          ;risultato
                JNC     ROLZPGNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
ROLZPGNOCARRY:  AND     AH,7DH
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ROLZPGISNEG:    JNC     ROLZPGISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
ROLZPGISNEGNC:  AND     AH,7DH
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ROLZPGISZERO:   JNC     ROLZPGISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
ROLZPGISZERONC: AND     AH,7DH
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
PLPIMP:         INC     DI                   ;Opcode 28H - Incr. Stack Pointer
                MOV     AH,[BYTE DI]         ;Carica P dallo stack
                OR      AH,30H               ;Forza i bits 4 e 5 di P a 1
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ANDIMM:         AND     AL,[BYTE SI]         ;Opcode 29H - Esegue A AND operando
                JZ      ANDIMMISZERO         ;Setta i flags in accordo col
                JS      ANDIMMISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                INC     SI                   ;Incrementa il Program Counter
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ANDIMMISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                INC     SI                   ;Incrementa il Program Counter
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ANDIMMISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                INC     SI                   ;Incrementa il Program Counter
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ROLACC:         MOV     BL,AH                ;Opcode 2AH - Salva P in BL
                AND     AH,0FEH              ;Prepara C=0, C verrÖ settato
;in seguito se necessario. NOTA: AND pone anche a zero il carry dell'80x86
                TEST    BL,01H               ;Pone il flag C nel carry
                JZ      ROLACCNC             ;dell'80x86
                STC
ROLACCNC:       RCL     AL,1                 ;Ruota A a sx attraverso il carry
                                             ;RCL non cambia i flags, occorre
                INC     AL                   ;quindi testare il risultato
                DEC     AL                   ;(INC/DEC non modificano il CF)
                JZ      ROLACCISZERO         ;Setta i flags in accordo col
                JS      ROLACCISNEG          ;risultato
                JNC     ROLACCNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
ROLACCNOCARRY:  AND     AH,7DH
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ROLACCISNEG:    JNC     ROLACCISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
ROLACCISNEGNC:  AND     AH,7DH
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ROLACCISZERO:   JNC     ROLACCISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
ROLACCISZERONC: AND     AH,7DH
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
BITABS:         MOV     BX,[WORD SI]         ;Opcode 2CH
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                CALL    READBLBX             ;Carica l'operando in BL
                XOR     BH,BH                ;Azzera parte alta indice istr.
                AND     AH,0FDH              ;Prepara Z=0, Z verrÖ settato
                                             ;in seguito se necessario
                TEST    AL,BL                ;Confronta A con l'operando
                JNE     BITABSNOTZERO        ;e setta il flag Z di conseguenza
                OR      AH,02H               ;Z=1
BITABSNOTZERO:  AND     AH,3FH               ;Maschera i flags N e V
                AND     BL,0C0H              ;Pone i bit 7 e 6 del dato
                OR      AH,BL                ;nei flags N e V
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ANDABS:         MOV     BX,[WORD SI]         ;Opcode 2DH
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                CALL    READBLBX             ;Carica l'operando in BL
                AND     AL,BL                ;Esegue l'AND tra AL e l'operando
                JZ      ANDABSISZERO         ;Setta i flags in accordo col
                JS      ANDABSISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ANDABSISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ANDABSISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ROLABS:         MOV     BX,[WORD SI]         ;Opcode 2EH
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                MOV     CL,AH                ;Salva P in CL
                AND     AH,0FEH              ;Prepara C=0, C verrÖ settato
;in seguito se necessario. NOTA: AND pone anche a zero il carry dell'80x86
                TEST    CL,01H               ;Pone il flag C nel carry
                JZ      ROLABSNC             ;dell'80x86
                STC
ROLABSNC:       PUSHF                        ;Preserva il carry dell'80x86
                MOV     CL,BL                ;Salva LSB indir. operando in CL
                CALL    READBLBX             ;Legge l'operando
                XCHG    BL,CL                ;Rimette operando in CL e LSB in BL
                POPF                         ;Ripristina il carry dell'80x86
                RCL     CL,1                 ;Ruota oper. a sx attraverso carry
                                             ;RCL non cambia i flags, occorre
                INC     CL                   ;quindi testare il risultato
                DEC     CL                   ;(INC/DEC non modificano il CF)
                JZ      ROLABSISZERO         ;Setta i flags in accordo col
                JS      ROLABSISNEG          ;risultato
                JNC     ROLABSNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
ROLABSNOCARRY:  AND     AH,7DH
                CALL    WRITEBXCL            ;Salva il risultato nell'operando
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ROLABSISNEG:    JNC     ROLABSISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
ROLABSISNEGNC:  AND     AH,7DH
                OR      AH,80H
                CALL    WRITEBXCL            ;Salva il risultato nell'operando
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ROLABSISZERO:   JNC     ROLABSISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
ROLABSISZERONC: AND     AH,7DH
                OR      AH,02H
                CALL    WRITEBXCL            ;Salva il risultato nell'operando
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
BMIREL:         TEST    AH,80H               ;Opcode 30H - Verifica il flag N
                JZ      BMIRELPOS            ;Se N=0 non esegue la diramazione
                INC     CH                   ;Se salta richiede un ciclo in pió
                MOV     BX,AX                ;Salva temporaneamente A e P in BX
                MOV     AL,[SI]              ;Carica spiazzamento (-128..+127)
                CBW                          ;Converte spiazzamento in una word
                ADD     SI,AX                ;Somma lo spiazzamento al PC
                MOV     AX,BX                ;Riporta A e P rispett. in AL ed AH
                XOR     BH,BH                ;Azzera parte alta indice istr.
BMIRELPOS:      INC     SI                   ;Incrementa il Program Counter
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ANDIPO:         MOV     BL,[BYTE SI]         ;Opcode 31H
                INC     SI                   ;Incrementa il Program Counter
                MOV     BX,[WORD BX]         ;Carica indirizzo base operando
                ADD     BL,DH                ;Somma Y all'indir. base operando
                ADC     BH,00H
                CALL    READBLBX             ;Legge l'operando dalla memoria
                AND     AL,BL                ;Esegue l'AND tra A e l'operando
                JZ      ANDIPOISZERO         ;Setta i flags in accordo col
                JS      ANDIPOISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ANDIPOISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ANDIPOISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ANDIZP:         MOV     BL,[BYTE SI]         ;Opcode 32H
                INC     SI                   ;Incrementa il Program Counter
                MOV     BX,[WORD BX]         ;Carica indirizzo dell'operando
                CALL    READBLBX             ;Legge l'operando dalla memoria
                AND     AL,BL                ;Esegue l'AND tra A e l'operando
                JZ      ANDIZPISZERO         ;Setta i flags in accordo col
                JS      ANDIZPISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ANDIZPISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ANDIZPISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
BITIZX:         MOV     BL,[BYTE SI]         ;Opcode 34H
                ADD     BL,DL                ;Somma X all'indir. dell'operando
                INC     SI                   ;Incrementa il Program Counter
                MOV     BL,[BYTE BX]         ;Carica l'operando dalla memoria
                AND     AH,0FDH              ;Prepara Z=0, Z verrÖ settato
                                             ;in seguito se necessario
                TEST    AL,BL                ;Confronta A con l'operando
                JNE     BITIZXNOTZERO        ;e setta Z di conseguenza
                OR      AH,02H               ;Z=1
BITIZXNOTZERO:  AND     AH,3FH               ;Maschera i flags N e V
                AND     BL,0C0H              ;Pone i bit 7 e 6 del dato
                OR      AH,BL                ;nei flags N e V
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ANDIZX:         MOV     BL,[BYTE SI]         ;Opcode 35H
                INC     SI                   ;Incrementa il Program Counter
                ADD     BL,DL                ;Somma X all'indir. dell'operando
                AND     AL,[BYTE BX]         ;Esegue l'AND tra A e l'operando
                JZ      ANDIZXISZERO         ;Setta i flags in accordo col
                JS      ANDIZXISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ANDIZXISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ANDIZXISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ROLIZX:         MOV     BL,[BYTE SI]         ;Opcode 36H
                INC     SI                   ;Incrementa il Program Counter
                ADD     BL,DL                ;Somma X all'indir. dell'operando
                MOV     CL,AH                ;Salva P in CL
                AND     AH,0FEH              ;Prepara C=0, C verrÖ settato
;in seguito se necessario. NOTA: AND pone anche a zero il carry dell'80x86
                TEST    CL,01H               ;Pone il flag C nel carry
                JZ      ROLIZXNC             ;dell'80x86
                STC
ROLIZXNC:       RCL     [BYTE BX],1          ;Ruota oper. a sx attraverso carry
                MOV     BL,[BYTE BX]         ;RCL non cambia i flags, occorre
                INC     BL                   ;quindi testare il risultato
                DEC     BL                   ;(INC/DEC non modificano il CF)
                JZ      ROLIZXISZERO         ;Setta i flags in accordo col
                JS      ROLIZXISNEG          ;risultato
                JNC     ROLIZXNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
ROLIZXNOCARRY:  AND     AH,7DH
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ROLIZXISNEG:    JNC     ROLIZXISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
ROLIZXISNEGNC:  AND     AH,7DH
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ROLIZXISZERO:   JNC     ROLIZXISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
ROLIZXISZERONC: AND     AH,7DH
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
SECIMP:         OR      AH,01H               ;Opcode 38H - Pone C=1
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ANDINY:         MOV     BL,DH                ;Opcode 39H
                ADD     BX,[WORD SI]         ;BX = Y + indirizzo base operando
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                CALL    READBLBX             ;Legge l'operando dalla memoria
                AND     AL,BL                ;Esegue l'AND tra A e l'operando
                JZ      ANDINYISZERO         ;Setta i flags in accordo col
                JS      ANDINYISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ANDINYISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ANDINYISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
DECACC:         DEC     AL                   ;Opcode 3AH - Decrementa A
                JZ      DECACCISZERO         ;Setta i flags in accordo col
                JS      DECACCISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
DECACCISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
DECACCISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
BITINX:         MOV     BL,DL                ;Opcode 3CH
                ADD     BX,[WORD SI]         ;BX = X + indirizzo base operando
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                CALL    READBLBX             ;Carica l'operando in BL
                XOR     BH,BH                ;Azzera parte alta indice istr.
                AND     AH,0FDH              ;Prepara Z=0, Z verrÖ settato
                                             ;in seguito se necessario
                TEST    AL,BL                ;Confronta A con l'operando
                JNE     BITINXNOTZERO        ;e setta il flag Z di conseguenza
                OR      AH,02H               ;Z=1
BITINXNOTZERO:  AND     AH,3FH               ;Maschera i flags N e V
                AND     BL,0C0H              ;Pone i bit 7 e 6 del dato
                OR      AH,BL                ;nei flags N e V
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ANDINX:         MOV     BL,DL                ;Opcode 3DH
                ADD     BX,[WORD SI]         ;BX = X + indirizzo base operando
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                CALL    READBLBX             ;Carica l'operando in BL
                AND     AL,BL                ;Esegue l'AND tra A e l'operando
                JZ      ANDINXISZERO         ;Setta i flags in accordo col
                JS      ANDINXISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ANDINXISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ANDINXISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ROLINX:         MOV     BL,DL                ;Opcode 3EH
                ADD     BX,[WORD SI]         ;BX = X + indirizzo base operando
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                MOV     CL,AH                ;Salva P in CL
                AND     AH,0FEH              ;Prepara C=0, C verrÖ settato
;in seguito se necessario. NOTA: AND pone anche a zero il carry dell'80x86
                TEST    CL,01H               ;Pone il flag C nel carry
                JZ      ROLINXNC             ;dell'80x86
                STC
ROLINXNC:       PUSHF                        ;Preserva il carry dell'80x86
                MOV     CL,BL                ;Salva LSB indir. operando in CL
                CALL    READBLBX             ;Legge l'operando
                XCHG    BL,CL                ;Rimette operando in CL e LSB in BL
                POPF                         ;Ripristina il carry dell'80x86
                RCL     CL,1                 ;Ruota oper. a sx attraverso carry
                                             ;RCL non cambia i flags, occorre
                INC     CL                   ;quindi testare il risultato
                DEC     CL                   ;(INC/DEC non modificano il CF)
                JZ      ROLINXISZERO         ;Setta i flags in accordo col
                JS      ROLINXISNEG          ;risultato
                JNC     ROLINXNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
ROLINXNOCARRY:  AND     AH,7DH
                CALL    WRITEBXCL            ;Salva il risultato nell'operando
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ROLINXISNEG:    JNC     ROLINXISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
ROLINXISNEGNC:  AND     AH,7DH
                OR      AH,80H
                CALL    WRITEBXCL            ;Salva il risultato nell'operando
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ROLINXISZERO:   JNC     ROLINXISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
ROLINXISZERONC: AND     AH,7DH
                OR      AH,02H
                CALL    WRITEBXCL            ;Salva il risultato nell'operando
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
RTIIMP:         INC     DI                   ;Opcode 40H - Increm. Stack Pointer
                MOV     AH,[DI]              ;Carica P dallo stack
                OR      AH,30H               ;Forza i bits 4 e 5 di P a 1
                INC     DI                   ;Incrementa lo Stack Pointer
                MOV     SI,[DI]              ;Carica PC dallo stack
                INC     DI                   ;Incrementa lo Stack Pointer
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
EORIPR:         MOV     BL,[BYTE SI]         ;Opcode 41H
                INC     SI                   ;Incrementa il Program Counter
                ADD     BL,DL                ;Somma X al puntatore in pagina 0
                MOV     BX,[WORD BX]         ;Carica indirizzo operando in BX
                CALL    READBLBX             ;Carica l'operando dalla memoria
                XOR     AL,BL                ;Esegue lo XOR tra A e l'operando
                JZ      EORIPRISZERO         ;Setta i flags in accordo col
                JS      EORIPRISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
EORIPRISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
EORIPRISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
EORZPG:         MOV     BL,[BYTE SI]         ;Opcode 45H
                INC     SI                   ;Incrementa il Program Counter
                XOR     AL,[BYTE BX]         ;Esegue lo XOR tra A e l'operando
                JZ      EORZPGISZERO         ;Setta i flags in accordo col
                JS      EORZPGISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
EORZPGISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
EORZPGISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
LSRZPG:         MOV     BL,[BYTE SI]         ;Opcode 46H
                INC     SI                   ;Incrementa il Program Counter
                AND     AH,0FEH              ;Prepara C=0, C verrÖ settato
                                             ;in seguito se necessario
                SHR     [BYTE BX],1          ;Esegue lo shift a dx dell'operando
                JZ      LSRZPGISZERO         ;Setta i flags in accordo col
                JS      LSRZPGISNEG          ;risultato
                JNC     LSRZPGNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
LSRZPGNOCARRY:  AND     AH,7DH
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LSRZPGISNEG:    JNC     LSRZPGISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
LSRZPGISNEGNC:  AND     AH,7DH
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LSRZPGISZERO:   JNC     LSRZPGISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
LSRZPGISZERONC: AND     AH,7DH
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
PHAIMP:         MOV     [BYTE DI],AL         ;Opcode 48H - Salva A nello stack
                DEC     DI                   ;Decrementa lo Stack Pointer
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
EORIMM:         XOR     AL,[BYTE SI]         ;Opcode 49H - Esegue A XOR operando
                JZ      EORIMMISZERO         ;Setta i flags in accordo col
                JS      EORIMMISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                INC     SI                   ;Incrementa il Program Counter
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
EORIMMISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                INC     SI                   ;Incrementa il Program Counter
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
EORIMMISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                INC     SI                   ;Incrementa il Program Counter
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
LSRACC:         AND     AH,0FEH              ;Opcode 4AH - Prepara C=0, C verrÖ
                                             ;settato in seguito se necessario
                SHR     AL,1                 ;Esegue lo shift a dx di A
                JZ      LSRACCISZERO         ;Setta i flags in accordo col
                JS      LSRACCISNEG          ;risultato
                JNC     LSRACCNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
LSRACCNOCARRY:  AND     AH,7DH
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LSRACCISNEG:    JNC     LSRACCISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
LSRACCISNEGNC:  AND     AH,7DH
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LSRACCISZERO:   JNC     LSRACCISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
LSRACCISZERONC: AND     AH,7DH
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
JMPABS:         MOV     SI,[WORD SI]         ;Opcode 4CH - PC=nuovo indirizzo
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
EORABS:         MOV     BX,[WORD SI]         ;Opcode 4DH
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                CALL    READBLBX             ;Carica l'operando dalla memoria
                XOR     AL,BL                ;Esegue lo XOR tra A e l'operando
                JZ      EORABSISZERO         ;Setta i flags in accordo col
                JS      EORABSISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
EORABSISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
EORABSISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
LSRABS:         MOV     BX,[WORD SI]         ;Opcode 4EH
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                AND     AH,0FEH              ;Prepara C=0, C verrÖ settato
                                             ;in seguito se necessario
                MOV     CL,BL                ;Salva LSB indir. operando in CL
                CALL    READBLBX             ;Legge l'operando
                XCHG    BL,CL                ;Rimette operando in CL e LSB in BL
                SHR     CL,1                 ;Esegue lo shift a destra
                JZ      LSRABSISZERO         ;Setta i flags in accordo col
                JS      LSRABSISNEG          ;risultato
                JNC     LSRABSNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
LSRABSNOCARRY:  AND     AH,7DH
                CALL    WRITEBXCL            ;Salva il risultato di LSR in mem.
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LSRABSISNEG:    JNC     LSRABSISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
LSRABSISNEGNC:  AND     AH,7DH
                OR      AH,80H
                CALL    WRITEBXCL            ;Salva il risultato di ASL in mem.
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LSRABSISZERO:   JNC     LSRABSISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
LSRABSISZERONC: AND     AH,7DH
                OR      AH,02H
                CALL    WRITEBXCL            ;Salva il risultato di ASL in mem.
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
BVCREL:         TEST    AH,40H               ;Opcode 50H - Verifica il flag V
                JNZ     BVCRELOVF            ;Se V=1 non esegue la diramazione
                INC     CH                   ;Se salta richiede un ciclo in pió
                MOV     BX,AX                ;Salva temporaneamente A e P in BX
                MOV     AL,[SI]              ;Carica spiazzamento (-128..+127)
                CBW                          ;Converte spiazzamento in una word
                ADD     SI,AX                ;Somma lo spiazzamento al PC
                MOV     AX,BX                ;Riporta A e P rispett. in AL ed AH
                XOR     BH,BH                ;Azzera parte alta indice istr.
BVCRELOVF:      INC     SI                   ;Incrementa il Program Counter
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
EORIPO:         MOV     BL,[BYTE SI]         ;Opcode 51H
                INC     SI                   ;Incrementa il Program Counter
                MOV     BX,[WORD BX]         ;Carica indirizzo base operando
                ADD     BL,DH                ;Somma Y all'indir. base operando
                ADC     BH,00H
                CALL    READBLBX             ;Legge l'operando dalla memoria
                XOR     AL,BL                ;Esegue lo XOR tra A e l'operando
                JZ      EORIPOISZERO         ;Setta i flags in accordo col
                JS      EORIPOISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
EORIPOISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
EORIPOISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
EORIZP:         MOV     BL,[BYTE SI]         ;Opcode 52H
                INC     SI                   ;Incrementa il Program Counter
                MOV     BX,[WORD BX]         ;Carica indirizzo dell'operando
                CALL    READBLBX             ;Legge l'operando dalla memoria
                XOR     AL,BL                ;Esegue lo XOR tra A e l'operando
                JZ      EORIZPISZERO         ;Setta i flags in accordo col
                JS      EORIZPISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
EORIZPISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
EORIZPISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
EORIZX:         MOV     BL,[BYTE SI]         ;Opcode 55H
                INC     SI                   ;Incrementa il Program Counter
                ADD     BL,DL                ;Somma X all'indir. dell'operando
                XOR     AL,[BYTE BX]         ;Esegue lo XOR tra A e l'operando
                JZ      EORIZXISZERO         ;Setta i flags in accordo col
                JS      EORIZXISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
EORIZXISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
EORIZXISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
LSRIZX:         MOV     BL,[BYTE SI]         ;Opcode 56H
                INC     SI                   ;Incrementa il Program Counter
                ADD     BL,DL                ;Somma X all'indir. dell'operando
                AND     AH,0FEH              ;Prepara C=0, C verrÖ settato
                                             ;in seguito se necessario
                SHR     [BYTE BX],1          ;Esegue lo shift a dx dell'operando
                JZ      LSRIZXISZERO         ;Setta i flags in accordo col
                JS      LSRIZXISNEG          ;risultato
                JNC     LSRIZXNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
LSRIZXNOCARRY:  AND     AH,7DH
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LSRIZXISNEG:    JNC     LSRIZXISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
LSRIZXISNEGNC:  AND     AH,7DH
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LSRIZXISZERO:   JNC     LSRIZXISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
LSRIZXISZERONC: AND     AH,7DH
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
CLIIMP:         AND     AH,0FBH              ;Opcode 58H - Azzera il flag I
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
EORINY:         MOV     BL,DH                ;Opcode 59H
                ADD     BX,[WORD SI]         ;BX = Y + indirizzo base operando
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                CALL    READBLBX             ;Legge l'operando dalla memoria
                XOR     AL,BL                ;Esegue lo XOR tra A e l'operando
                JZ      EORINYISZERO         ;Setta i flags in accordo col
                JS      EORINYISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
EORINYISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
EORINYISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
PHYIMP:         MOV     [BYTE DI],DH         ;Opcode 5AH - Salva Y nello stack
                DEC     DI                   ;Decrementa lo Stack Pointer
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
NOPABS:         INC     SI                   ;Opcodes 5CH,DCH,FCH - Incr. PC
                INC     SI                   ;Incrementa il Program Counter
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
EORINX:         MOV     BL,DL                ;Opcode 5DH
                ADD     BX,[WORD SI]         ;BX = X + indirizzo base operando
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                CALL    READBLBX             ;Legge l'operando dalla memoria
                XOR     AL,BL                ;Esegue lo XOR tra A e l'operando
                JZ      EORINXISZERO         ;Setta i flags in accordo col
                JS      EORINXISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
EORINXISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
EORINXISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
LSRINX:         MOV     BL,DL                ;Opcode 5EH
                ADD     BX,[WORD SI]         ;BX = X + indirizzo base operando
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                AND     AH,0FEH              ;Prepara C=0, C verrÖ settato
                                             ;in seguito se necessario
                MOV     CL,BL                ;Salva LSB indir. operando in CL
                CALL    READBLBX             ;Legge l'operando dalla memoria
                XCHG    BL,CL                ;Rimette operando in CL e LSB in BL
                SHR     CL,1                 ;Esegue lo shift a dx dell'operando
                JZ      LSRINXISZERO         ;Setta i flags in accordo col
                JS      LSRINXISNEG          ;risultato
                JNC     LSRINXNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
LSRINXNOCARRY:  AND     AH,7DH
                CALL    WRITEBXCL            ;Salva il risultato nell'operando
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LSRINXISNEG:    JNC     LSRINXISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
LSRINXISNEGNC:  AND     AH,7DH
                OR      AH,80H
                CALL    WRITEBXCL            ;Salva il risultato nell'operando
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LSRINXISZERO:   JNC     LSRINXISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
LSRINXISZERONC: AND     AH,7DH
                OR      AH,02H
                CALL    WRITEBXCL            ;Salva il risultato nell'operando
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
RTSIMP:         INC     DI                   ;Opcode 60H - Incrementa SP
                MOV     SI,[DI]              ;Carica PC dallo stack
                INC     DI                   ;Incrementa lo Stack Pointer
                INC     SI                   ;Incrementa il Program Counter
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ADCIPR:         MOV     BL,[BYTE SI]         ;Opcode 61H
                INC     SI                   ;Incrementa il Program Counter
                ADD     BL,DL                ;Somma X al puntatore in pagina 0
                MOV     BX,[WORD BX]         ;Carica l'indirizzo dell'operando
                CALL    READBLBX             ;Legge l'operando dalla memoria
                MOV     BH,BL                ;Copia l'operando in BH
                MOV     BL,AH                ;Copia P in BL
                AND     BL,3CH               ;Res. flags da settare in seguito
                TEST    AH,08H               ;Sceglie routine binaria o decimale
                JNZ     ADCIPRDEC            ;a seconda del valore del flag D

;Routine di somma binaria
                TEST    AH,01H               ;Pone il C nel carry dell'80x86
                JZ      ADCIPRNODNOC         ;(TEST pone il carry a zero)
                STC
ADCIPRNODNOC:   ADC     AL,BH                ;Somma l'operando ad A
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     ADCIPRNODNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
ADCIPRNODNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      ADCIPRNODNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
ADCIPRNODNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta correttamente i flags N e C
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.

;Routine di somma BCD
ADCIPRDEC:      INC     CH                   ;In modo decimale ADC richiede
                                             ;un ciclo di clock in pió
                TEST    AH,01H               ;Pone il C nel carry dell'80x86
                JZ      ADCIPRDECNOC         ;(TEST pone il carry a zero)
                STC
ADCIPRDECNOC:   ADC     AL,BH                ;Somma l'operando ad A
                DAA                          ;Converte il risultato in BCD
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     ADCIPRDECNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
ADCIPRDECNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      ADCIPRDECNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
ADCIPRDECNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta correttamente i flags N e C
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
STZZPG:         MOV     BL,[BYTE SI]         ;Opcode 64H - Carica indir. destin.
                INC     SI                   ;Incrementa il Program Counter
                MOV     [BYTE BX],BH         ;Azzera la locazione di destinaz.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ADCZPG:         MOV     BL,[BYTE SI]         ;Opcode 65H
                INC     SI                   ;Incrementa il Program Counter
                MOV     BH,[BYTE BX]         ;Legge l'operando dalla memoria
                MOV     BL,AH                ;Copia P in BL
                AND     BL,3CH               ;Res. flags da settare in seguito
                TEST    AH,08H               ;Sceglie routine binaria o decimale
                JNZ     ADCZPGDEC            ;a seconda del valore del flag D

;Routine di somma binaria
                TEST    AH,01H               ;Pone il C nel carry dell'80x86
                JZ      ADCZPGNODNOC         ;(TEST pone il carry a zero)
                STC
ADCZPGNODNOC:   ADC     AL,BH                ;Somma l'operando ad A
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     ADCZPGNODNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
ADCZPGNODNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      ADCZPGNODNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
ADCZPGNODNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta correttamente i flags N e C
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.

;Routine di somma BCD
ADCZPGDEC:      INC     CH                   ;In modo decimale ADC richiede
                                             ;un ciclo di clock in pió
                TEST    AH,01H               ;Pone il C nel carry dell'80x86
                JZ      ADCZPGDECNOC         ;(TEST pone il carry a zero)
                STC
ADCZPGDECNOC:   ADC     AL,BH                ;Somma l'operando ad A
                DAA                          ;Converte il risultato in BCD
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     ADCZPGDECNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
ADCZPGDECNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      ADCZPGDECNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
ADCZPGDECNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta correttamente i flags N e C
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
RORZPG:         MOV     BL,[BYTE SI]         ;Opcode 66H
                INC     SI                   ;Incrementa il Program Counter
                MOV     CL,AH                ;Salva P in CL
                AND     AH,0FEH              ;Prepara C=0, C verrÖ settato
;in seguito se necessario. NOTA: AND pone anche a zero il carry dell'80x86
                TEST    CL,01H               ;Pone il flag C nel carry
                JZ      RORZPGNC             ;dell'80x86
                STC
RORZPGNC:       RCR     [BYTE BX],1          ;Ruota oper. a dx attrav. il carry
                MOV     BL,[BYTE BX]         ;RCR non cambia i flags, occorre
                INC     BL                   ;quindi testare il risultato
                DEC     BL                   ;(INC/DEC non modificano il CF)
                JZ      RORZPGISZERO         ;Setta i flags in accordo col
                JS      RORZPGISNEG          ;risultato
                JNC     RORZPGNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
RORZPGNOCARRY:  AND     AH,7DH
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
RORZPGISNEG:    JNC     RORZPGISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
RORZPGISNEGNC:  AND     AH,7DH
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
RORZPGISZERO:   JNC     RORZPGISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
RORZPGISZERONC: AND     AH,7DH
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
PLAIMP:         INC     DI                   ;Opcode 68H - Incrementa SP
                MOV     AL,[BYTE DI]         ;Estrae A dallo stack
                TEST    AL,AL                ;Setta i flags in accordo col
                JZ      PLAIMPISZERO         ;valore di A
                JS      PLAIMPISNEG
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
PLAIMPISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
PLAIMPISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ADCIMM:         MOV     BL,AH                ;Opcode 69H - Copia P in BL
                AND     BL,3CH               ;Res. flags da settare in seguito
                TEST    AH,08H               ;Sceglie routine binaria o decimale
                JNZ     ADCIMMDEC            ;a seconda del valore del flag D

;Routine di somma binaria
                TEST    AH,01H               ;Pone il C nel carry dell'80x86
                JZ      ADCIMMNODNOC         ;(TEST pone il carry a zero)
                STC
ADCIMMNODNOC:   ADC     AL,[BYTE SI]         ;Somma l'operando ad A
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     ADCIMMNODNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
ADCIMMNODNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      ADCIMMNODNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
ADCIMMNODNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta correttamente i flags N e C
                INC     SI                   ;Incrementa il Program Counter
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.

;Routine di somma BCD
ADCIMMDEC:      INC     CH                   ;In modo decimale ADC richiede
                                             ;un ciclo di clock in pió
                TEST    AH,01H               ;Pone il C nel carry dell'80x86
                JZ      ADCIMMDECNOC         ;(TEST pone il carry a zero)
                STC
ADCIMMDECNOC:   ADC     AL,[BYTE SI]         ;Somma l'operando ad A
                DAA                          ;Converte il risultato in BCD
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     ADCIMMDECNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
ADCIMMDECNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      ADCIMMDECNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
ADCIMMDECNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta correttamente i flags N e C
                INC     SI                   ;Incrementa il Program Counter
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
RORACC:         MOV     BL,AH                ;Opcode 6AH - Salva P in BL
                AND     AH,0FEH              ;Prepara C=0, C verrÖ settato
;in seguito se necessario. NOTA: AND pone anche a zero il carry dell'80x86
                TEST    BL,01H               ;Pone il flag C nel carry
                JZ      RORACCNC             ;dell'80x86
                STC
RORACCNC:       RCR     AL,1                 ;Ruota A a dx attraverso il carry
                                             ;RCR non cambia i flags, occorre
                INC     AL                   ;quindi testare il risultato
                DEC     AL                   ;(INC/DEC non modificano il CF)
                JZ      RORACCISZERO         ;Setta i flags in accordo col
                JS      RORACCISNEG          ;risultato
                JNC     RORACCNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
RORACCNOCARRY:  AND     AH,7DH
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
RORACCISNEG:    JNC     RORACCISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
RORACCISNEGNC:  AND     AH,7DH
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
RORACCISZERO:   JNC     RORACCISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
RORACCISZERONC: AND     AH,7DH
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
JMPIND:         MOV     SI,[WORD SI]         ;Opcode 6CH - Carica ind. operando
                MOV     SI,[WORD SI]         ;Carica nel PC l'ind. a cui saltare
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ADCABS:         MOV     BX,[WORD SI]         ;Opcode 6DH
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                CALL    READBLBX             ;Legge l'operando dalla memoria
                MOV     BH,BL                ;Copia l'operando in BH
                MOV     BL,AH                ;Copia P in BL
                AND     BL,3CH               ;Res. flags da settare in seguito
                TEST    AH,08H               ;Sceglie routine binaria o decimale
                JNZ     ADCABSDEC            ;a seconda del valore del flag D

;Routine di somma binaria
                TEST    AH,01H               ;Pone il C nel carry dell'80x86
                JZ      ADCABSNODNOC         ;(TEST pone il carry a zero)
                STC
ADCABSNODNOC:   ADC     AL,BH                ;Somma l'operando ad A
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     ADCABSNODNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
ADCABSNODNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      ADCABSNODNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
ADCABSNODNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta correttamente i flags N e C
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.

;Routine di somma BCD
ADCABSDEC:      INC     CH                   ;In modo decimale ADC richiede
                                             ;un ciclo di clock in pió
                TEST    AH,01H               ;Pone il C nel carry dell'80x86
                JZ      ADCABSDECNOC         ;(TEST pone il carry a zero)
                STC
ADCABSDECNOC:   ADC     AL,BH                ;Somma l'operando ad A
                DAA                          ;Converte il risultato in BCD
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     ADCABSDECNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
ADCABSDECNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      ADCABSDECNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
ADCABSDECNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta correttamente i flags N e C
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
RORABS:         MOV     BX,[WORD SI]         ;Opcode 6EH
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                MOV     CL,AH                ;Salva P in CL
                AND     AH,0FEH              ;Prepara C=0, C verrÖ settato
;in seguito se necessario. NOTA: AND pone anche a zero il carry dell'80x86
                TEST    CL,01H               ;Pone il flag C nel carry
                JZ      RORABSNC             ;dell'80x86
                STC
RORABSNC:       PUSHF                        ;Preserva il carry dell'80x86
                MOV     CL,BL                ;Salva LSB indir. operando in CL
                CALL    READBLBX             ;Legge l'operando
                XCHG    BL,CL                ;Rimette operando in CL e LSB in BL
                POPF                         ;Ripristina il carry dell'80x86
                RCR     CL,1                 ;Ruota oper. a dx attraverso carry
                                             ;RCR non cambia i flags, occorre
                INC     CL                   ;quindi testare il risultato
                DEC     CL                   ;(INC/DEC non modificano il CF)
                JZ      RORABSISZERO         ;Setta i flags in accordo col
                JS      RORABSISNEG          ;risultato
                JNC     RORABSNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
RORABSNOCARRY:  AND     AH,7DH
                CALL    WRITEBXCL            ;Salva il risultato nell'operando
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
RORABSISNEG:    JNC     RORABSISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
RORABSISNEGNC:  AND     AH,7DH
                OR      AH,80H
                CALL    WRITEBXCL            ;Salva il risultato nell'operando
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
RORABSISZERO:   JNC     RORABSISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
RORABSISZERONC: AND     AH,7DH
                OR      AH,02H
                CALL    WRITEBXCL            ;Salva il risultato nell'operando
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
BVSREL:         TEST    AH,40H               ;Opcode 70H - Verifica il flag V
                JZ      BVSRELNOV            ;Se V=0 non esegue la diramazione
                INC     CH                   ;Se salta richiede un ciclo in pió
                MOV     BX,AX                ;Salva temporaneamente A e P in BX
                MOV     AL,[SI]              ;Carica spiazzamento (-128..+127)
                CBW                          ;Converte spiazzamento in una word
                ADD     SI,AX                ;Somma lo spiazzamento al PC
                MOV     AX,BX                ;Riporta A e P rispett. in AL ed AH
                XOR     BH,BH                ;Azzera parte alta indice istr.
BVSRELNOV:      INC     SI                   ;Incrementa il Program Counter
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ADCIPO:         MOV     BL,[BYTE SI]         ;Opcode 71H
                INC     SI                   ;Incrementa il Program Counter
                MOV     BX,[WORD BX]         ;Carica indirizzo base operando
                ADD     BL,DH                ;Somma Y all'indir. base operando
                ADC     BH,00H
                CALL    READBLBX             ;Legge l'operando dalla memoria
                MOV     BH,BL                ;Copia l'operando in BH
                MOV     BL,AH                ;Copia P in BL
                AND     BL,3CH               ;Res. flags da settare in seguito
                TEST    AH,08H               ;Sceglie routine binaria o decimale
                JNZ     ADCIPODEC            ;a seconda del valore del flag D

;Routine di somma binaria
                TEST    AH,01H               ;Pone il C nel carry dell'80x86
                JZ      ADCIPONODNOC         ;(TEST pone il carry a zero)
                STC
ADCIPONODNOC:   ADC     AL,BH                ;Somma l'operando ad A
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     ADCIPONODNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
ADCIPONODNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      ADCIPONODNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
ADCIPONODNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta correttamente i flags N e C
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.

;Routine di somma BCD
ADCIPODEC:      INC     CH                   ;In modo decimale ADC richiede
                                             ;un ciclo di clock in pió
                TEST    AH,01H               ;Pone il C nel carry dell'80x86
                JZ      ADCIPODECNOC         ;(TEST pone il carry a zero)
                STC
ADCIPODECNOC:   ADC     AL,BH                ;Somma l'operando ad A
                DAA                          ;Converte il risultato in BCD
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     ADCIPODECNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
ADCIPODECNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      ADCIPODECNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
ADCIPODECNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta correttamente i flags N e C
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ADCIZP:         MOV     BL,[BYTE SI]         ;Opcode 72H
                INC     SI                   ;Incrementa il Program Counter
                MOV     BX,[WORD BX]         ;Carica l'indirizzo dell'operando
                CALL    READBLBX             ;Legge l'operando dalla memoria
                MOV     BH,BL                ;Copia l'operando in BH
                MOV     BL,AH                ;Copia P in BL
                AND     BL,3CH               ;Res. flags da settare in seguito
                TEST    AH,08H               ;Sceglie routine binaria o decimale
                JNZ     ADCIZPDEC            ;a seconda del valore del flag D

;Routine di somma binaria
                TEST    AH,01H               ;Pone il C nel carry dell'80x86
                JZ      ADCIZPNODNOC         ;(TEST pone il carry a zero)
                STC
ADCIZPNODNOC:   ADC     AL,BH                ;Somma l'operando ad A
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     ADCIZPNODNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
ADCIZPNODNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      ADCIZPNODNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
ADCIZPNODNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta correttamente i flags N e C
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.

;Routine di somma BCD
ADCIZPDEC:      INC     CH                   ;In modo decimale ADC richiede
                                             ;un ciclo di clock in pió
                TEST    AH,01H               ;Pone il C nel carry dell'80x86
                JZ      ADCIZPDECNOC         ;(TEST pone il carry a zero)
                STC
ADCIZPDECNOC:   ADC     AL,BH                ;Somma l'operando ad A
                DAA                          ;Converte il risultato in BCD
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     ADCIZPDECNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
ADCIZPDECNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      ADCIZPDECNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
ADCIZPDECNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta correttamente i flags N e C
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
STZIZX:         MOV     BL,[BYTE SI]         ;Opcode 74H
                INC     SI                   ;Incrementa il Program Counter
                ADD     BL,DL                ;Somma X all'indir. base operando
                MOV     [BYTE BX],BH         ;Scrive 0 nell'operando
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ADCIZX:         MOV     BL,[BYTE SI]         ;Opcode 75H
                INC     SI                   ;Incrementa il Program Counter
                ADD     BL,DL                ;Somma X all'indir. base operando
                MOV     BH,[BYTE BX]         ;Carica l'operando dalla memoria
                MOV     BL,AH                ;Copia P in BL
                AND     BL,3CH               ;Res. flags da settare in seguito
                TEST    AH,08H               ;Sceglie routine binaria o decimale
                JNZ     ADCIZXDEC            ;a seconda del valore del flag D

;Routine di somma binaria
                TEST    AH,01H               ;Pone il C nel carry dell'80x86
                JZ      ADCIZXNODNOC         ;(TEST pone il carry a zero)
                STC
ADCIZXNODNOC:   ADC     AL,BH                ;Somma l'operando ad A
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     ADCIZXNODNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
ADCIZXNODNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      ADCIZXNODNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
ADCIZXNODNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta correttamente i flags N e C
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.

;Routine di somma BCD
ADCIZXDEC:      INC     CH                   ;In modo decimale ADC richiede
                                             ;un ciclo di clock in pió
                TEST    AH,01H               ;Pone il C nel carry dell'80x86
                JZ      ADCIZXDECNOC         ;(TEST pone il carry a zero)
                STC
ADCIZXDECNOC:   ADC     AL,BH                ;Somma l'operando ad A
                DAA                          ;Converte il risultato in BCD
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     ADCIZXDECNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
ADCIZXDECNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      ADCIZXDECNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
ADCIZXDECNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta correttamente i flags N e C
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
RORIZX:         MOV     BL,[BYTE SI]         ;Opcode 76H
                INC     SI                   ;Incrementa il Program Counter
                ADD     BL,DL                ;Somma X all'indir. base operando
                MOV     CL,AH                ;Salva P in CL
                AND     AH,0FEH              ;Prepara C=0, C verrÖ settato
;in seguito se necessario. NOTA: AND pone anche a zero il carry dell'80x86
                TEST    CL,01H               ;Pone il flag C nel carry
                JZ      RORIZXNC             ;dell'80x86
                STC
RORIZXNC:       RCR     [BYTE BX],1          ;Ruota oper. a dx attraverso carry
                MOV     BL,[BYTE BX]         ;RCR non cambia i flags, occorre
                INC     BL                   ;quindi testare il risultato
                DEC     BL                   ;(INC/DEC non modificano il CF)
                JZ      RORIZXISZERO         ;Setta i flags in accordo col
                JS      RORIZXISNEG          ;risultato
                JNC     RORIZXNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
RORIZXNOCARRY:  AND     AH,7DH
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
RORIZXISNEG:    JNC     RORIZXISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
RORIZXISNEGNC:  AND     AH,7DH
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
RORIZXISZERO:   JNC     RORIZXISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
RORIZXISZERONC: AND     AH,7DH
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
SEIIMP:         OR      AH,04H               ;Opcode 78H - Pone I=1
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ADCINY:         MOV     BL,DH                ;Opcode 79H
                ADD     BX,[WORD SI]         ;BX = Y + indirizzo base operando
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                CALL    READBLBX             ;Carica l'operando dalla memoria
                MOV     BH,BL                ;Copia l'operando in BH
                MOV     BL,AH                ;Copia P in BL
                AND     BL,3CH               ;Res. flags da settare in seguito
                TEST    AH,08H               ;Sceglie routine binaria o decimale
                JNZ     ADCINYDEC            ;a seconda del valore del flag D

;Routine di somma binaria
                TEST    AH,01H               ;Pone il C nel carry dell'80x86
                JZ      ADCINYNODNOC         ;(TEST pone il carry a zero)
                STC
ADCINYNODNOC:   ADC     AL,BH                ;Somma l'operando ad A
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     ADCINYNODNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
ADCINYNODNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      ADCINYNODNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
ADCINYNODNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta correttamente i flags N e C
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.

;Routine di somma BCD
ADCINYDEC:      INC     CH                   ;In modo decimale ADC richiede
                                             ;un ciclo di clock in pió
                TEST    AH,01H               ;Pone il C nel carry dell'80x86
                JZ      ADCINYDECNOC         ;(TEST pone il carry a zero)
                STC
ADCINYDECNOC:   ADC     AL,BH                ;Somma l'operando ad A
                DAA                          ;Converte il risultato in BCD
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     ADCINYDECNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
ADCINYDECNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      ADCINYDECNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
ADCINYDECNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta correttamente i flags N e C
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
PLYIMP:         INC     DI                   ;Opcode 7AH - Incrementa SP
                MOV     DH,[BYTE DI]         ;Carica Y dallo stack
                TEST    DH,DH                ;Setta i flags in accordo col
                JZ      PLYIMPISZERO         ;valore di Y
                JS      PLYIMPISNEG
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
PLYIMPISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
PLYIMPISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
JMPIPA:         MOV     BL,DL                ;Opcode 7CH
                ADD     BX,[WORD SI]         ;BX = X+indirizzo base operando
                MOV     SI,[WORD BX]         ;Carica nel PC l'ind. a cui saltare
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
ADCINX:         MOV     BL,DL                ;Opcode 7DH
                ADD     BX,[WORD SI]         ;BX = X + indirizzo base operando
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                CALL    READBLBX             ;Carica l'operando dalla memoria
                MOV     BH,BL                ;Copia l'operando in BH
                MOV     BL,AH                ;Copia P in BL
                AND     BL,3CH               ;Res. flags da settare in seguito
                TEST    AH,08H               ;Sceglie routine binaria o decimale
                JNZ     ADCINXDEC            ;a seconda del valore del flag D

;Routine di somma binaria
                TEST    AH,01H               ;Pone il C nel carry dell'80x86
                JZ      ADCINXNODNOC         ;(TEST pone il carry a zero)
                STC
ADCINXNODNOC:   ADC     AL,BH                ;Somma l'operando ad A
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     ADCINXNODNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
ADCINXNODNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      ADCINXNODNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
ADCINXNODNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta correttamente i flags N e C
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.

;Routine di somma BCD
ADCINXDEC:      INC     CH                   ;In modo decimale ADC richiede
                                             ;un ciclo di clock in pió
                TEST    AH,01H               ;Pone il C nel carry dell'80x86
                JZ      ADCINXDECNOC         ;(TEST pone il carry a zero)
                STC
ADCINXDECNOC:   ADC     AL,BH                ;Somma l'operando ad A
                DAA                          ;Converte il risultato in BCD
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     ADCINXDECNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
ADCINXDECNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      ADCINXDECNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
ADCINXDECNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta correttamente i flags N e C
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
RORINX:         MOV     BL,DL                ;Opcode 7EH
                ADD     BX,[WORD SI]         ;BX = X + indirizzo base operando
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                MOV     CL,AH                ;Salva P in CL
                AND     AH,0FEH              ;Prepara C=0, C verrÖ settato
;in seguito se necessario. NOTA: AND pone anche a zero il carry dell'80x86
                TEST    CL,01H               ;Pone il flag C nel carry
                JZ      RORINXNC             ;dell'80x86
                STC
RORINXNC:       PUSHF                        ;Preserva il carry dell'80x86
                MOV     CL,BL                ;Salva LSB indir. operando in CL
                CALL    READBLBX             ;Legge l'operando
                XCHG    BL,CL                ;Rimette operando in CL e LSB in BL
                POPF                         ;Ripristina il carry dell'80x86
                RCR     CL,1                 ;Ruota oper. a dx attraverso carry
                                             ;RCR non cambia i flags, occorre
                INC     CL                   ;quindi testare il risultato
                DEC     CL                   ;(INC/DEC non modificano il CF)
                JZ      RORINXISZERO         ;Setta i flags in accordo col
                JS      RORINXISNEG          ;risultato
                JNC     RORINXNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
RORINXNOCARRY:  AND     AH,7DH
                CALL    WRITEBXCL            ;Salva il risultato nell'operando
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
RORINXISNEG:    JNC     RORINXISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
RORINXISNEGNC:  AND     AH,7DH
                OR      AH,80H
                CALL    WRITEBXCL            ;Salva il risultato nell'operando
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
RORINXISZERO:   JNC     RORINXISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
RORINXISZERONC: AND     AH,7DH
                OR      AH,02H
                CALL    WRITEBXCL            ;Salva il risultato nell'operando
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
BRAREL:         MOV     BX,AX                ;Opcode 80H - Salva  A e P in BX
                MOV     AL,[SI]              ;Carica spiazzamento (-128..+127)
                CBW                          ;Converte spiazzamento in una word
                ADD     SI,AX                ;Somma lo spiazzamento al PC
                MOV     AX,BX                ;Riporta A e P rispett. in AL ed AH
                XOR     BH,BH                ;Azzera parte alta indice istr.
                INC     SI                   ;Incrementa il Program Counter
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
STAIPR:         MOV     BL,[BYTE SI]         ;Opcode 81H
                INC     SI                   ;Incrementa il Program Counter
                ADD     BL,DL                ;Somma X al puntatore in pagina 0
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                MOV     BX,[WORD BX]         ;Carica l'indirizzo della destinaz.
                MOV     CL,AL                ;Copia A in CL
                CALL    WRITEBXCL            ;Memorizza A nella destinazione
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
STYZPG:         MOV     BL,[BYTE SI]         ;Opcode 84H
                INC     SI                   ;Incrementa il Program Counter
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                MOV     [BYTE BX],DH         ;Memorizza Y nella destinazione
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
STAZPG:         MOV     BL,[BYTE SI]         ;Opcode 85H
                INC     SI                   ;Incrementa il Program Counter
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                MOV     [BYTE BX],AL         ;Memorizza A nella destinazione
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
STXZPG:         MOV     BL,[BYTE SI]         ;Opcode 86H
                INC     SI                   ;Incrementa il Program Counter
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                MOV     [BYTE BX],DL         ;Memorizza X nella destinazione
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
DEYIMP:         XOR     BH,BH                ;Opcode 88H
                DEC     DH                   ;Decrementa Y
                JZ      DEYIMPISZERO         ;Setta i flags in accordo col
                JS      DEYIMPISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
DEYIMPISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
DEYIMPISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
BITIMM:         XOR     BH,BH                ;Opcode 89H
                AND     AH,0FDH              ;Prepara Z=0, Z verrÖ settato
                                             ;in seguito se necessario
                TEST    AL,[BYTE SI]         ;Confronta A con l'operando
                JNE     BITIMMNOTZERO        ;e setta il flag Z di conseguenza
                OR      AH,02H               ;Z=1
BITIMMNOTZERO:  INC     SI                   ;Incrementa il Program Counter
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
TXAIMP:         XOR     BH,BH                ;Opcode 8AH
                MOV     AL,DL                ;Copia X in A
                TEST    AL,AL                ;Setta i flags in accordo col
                JZ      TXAIMPISZERO         ;valore di X
                JS      TXAIMPISNEG
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
TXAIMPISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
TXAIMPISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
STYABS:         MOV     BX,[WORD SI]         ;Opcode 8CH - Carica indir. destin.
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                MOV     CL,DH                ;Copia Y in CL
                CALL    WRITEBXCL            ;Memorizza Y nella destinazione
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
STAABS:         MOV     BX,[WORD SI]         ;Opcode 8DH - Carica indir. destin.
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                MOV     CL,AL                ;Copia A in CL
                CALL    WRITEBXCL            ;Memorizza A nella destinazione
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
STXABS:         MOV     BX,[WORD SI]         ;Opcode 8EH - Carica indir. destin.
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                MOV     CL,DL                ;Copia X in CL
                CALL    WRITEBXCL            ;Memorizza X nella destinazione
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
BCCREL:         TEST    AH,01H               ;Opcode 90H - Verifica il flag C
                JNZ     BCCRELCARRY          ;Se C=1 non esegue la diramazione
                INC     CH                   ;Se salta richiede un ciclo in pió
                MOV     BX,AX                ;Salva temporaneamente A e P in BX
                MOV     AL,[SI]              ;Carica spiazzamento (-128..+127)
                CBW                          ;Converte spiazzamento in una word
                ADD     SI,AX                ;Somma lo spiazzamento al PC
                MOV     AX,BX                ;Riporta A e P rispett. in AL ed AH
BCCRELCARRY:    XOR     BH,BH                ;Azzera parte alta indice istr.
                INC     SI                   ;Incrementa il Program Counter
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
STAIPO:         MOV     BL,[BYTE SI]         ;Opcode 91H
                INC     SI                   ;Incrementa il Program Counter
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                MOV     BX,[WORD BX]         ;Carica indirizzo base operando
                ADD     BL,DH                ;Somma Y all'indir. base operando
                ADC     BH,00H
                MOV     CL,AL                ;Copia A in CL
                CALL    WRITEBXCL            ;Memorizza A nella destinazione
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
STAIZP:         MOV     BL,[BYTE SI]         ;Opcode 92H
                INC     SI                   ;Incrementa il Program Counter
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                MOV     BX,[WORD BX]         ;Carica l'indirizzo dell'operando
                MOV     CL,AL                ;Copia A in CL
                CALL    WRITEBXCL            ;Memorizza A nella destinazione
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
STYIZX:         MOV     BL,[BYTE SI]         ;Opcode 94H
                INC     SI                   ;Incrementa il Program Counter
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                ADD     BL,DL                ;Somma X all'indir. dell'operando
                MOV     [BYTE BX],DH         ;Memorizza Y nella destinazione
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
STAIZX:         MOV     BL,[BYTE SI]         ;Opcode 95H
                INC     SI                   ;Incrementa il Program Counter
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                ADD     BL,DL                ;Somma X all'indir. dell'operando
                MOV     [BYTE BX],AL         ;Memorizza A nella destinazione
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
STXIZY:         MOV     BL,[BYTE SI]         ;Opcode 96H
                INC     SI                   ;Incrementa il Program Counter
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                ADD     BL,DH                ;Somma Y all'indir. dell'operando
                MOV     [BYTE BX],DL         ;Memorizza A nella destinazione
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
TYAIMP:         XOR     BH,BH                ;Opcode 98H
                MOV     AL,DH                ;Copia Y in A
                TEST    AL,AL                ;Setta i flags in accordo col
                JZ      TYAIMPISZERO         ;valore di Y
                JS      TYAIMPISNEG
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
TYAIMPISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
TYAIMPISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
STAINY:         MOV     BL,DH                ;Opcode 99H
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                ADD     BX,[WORD SI]         ;BX = Y + indirizzo base operando
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                MOV     CL,AL                ;Copia A in CL
                CALL    WRITEBXCL            ;Memorizza A nella destinazione
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
TXSIMP:         MOV     BL,DL                ;Opcode 9AH - Copia X in BL
                MOV     DI,BX                ;Copia X in S (BH vale giÖ 01H)
                XOR     BH,BH                ;Azzera parte alta indice istr.
                TEST    DL,DL                ;Setta i flags in accordo col
                JZ      TXSIMPISZERO         ;valore di X
                JS      TXSIMPISNEG
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
TXSIMPISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
TXSIMPISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
STZABS:         MOV     BX,[WORD SI]         ;Opcode 9CH - Carica indir. destin.
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                XOR     CL,CL                ;Pone 0 nel registro CL
                CALL    WRITEBXCL            ;Azzera la destinazione
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
STAINX:         MOV     BL,DL                ;Opcode 9DH
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                ADD     BX,[WORD SI]         ;BX = X + indirizzo base operando
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                MOV     CL,AL                ;Copia A in CL
                CALL    WRITEBXCL            ;Memorizza A nella destinazione
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
STZINX:         MOV     BL,DL                ;Opcode 9EH
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                ADD     BX,[WORD SI]         ;BX = X + indirizzo base operando
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                XOR     CL,CL                ;Pone 0 nel registro CL
                CALL    WRITEBXCL            ;Azzera la destinazione
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
LDYIMM:         MOV     DH,[BYTE SI]         ;Opcode A0H - Carica operando in Y
                INC     SI                   ;Incrementa il Program Counter
                XOR     BH,BH                ;Azzera parte alta indice istr.
                TEST    DH,DH                ;Setta i flags in accordo col
                JZ      LDYIMMISZERO         ;valore di Y
                JS      LDYIMMISNEG
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDYIMMISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDYIMMISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
LDAIPR:         MOV     BL,[BYTE SI]         ;Opcode A1H
                INC     SI                   ;Incrementa il Program Counter
                ADD     BL,DL                ;Somma X al puntatore in pagina 0
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                MOV     BX,[WORD BX]         ;Carica l'indirizzo dell'operando
                CALL    READBLBX             ;Legge l'operando dalla memoria
                MOV     AL,BL                ;Copia l'operando in A
                XOR     BH,BH                ;Azzera parte alta indice istr.
                TEST    AL,AL                ;Setta i flags in accordo col
                JZ      LDAIPRISZERO         ;valore di A
                JS      LDAIPRISNEG
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDAIPRISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDAIPRISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
LDXIMM:         MOV     DL,[BYTE SI]         ;Opcode A2H - Carica operando in X
                INC     SI                   ;Incrementa il Program Counter
                XOR     BH,BH                ;Azzera parte alta indice istr.
                TEST    DL,DL                ;Setta i flags in accordo col
                JZ      LDXIMMISZERO         ;valore di X
                JS      LDXIMMISNEG
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDXIMMISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDXIMMISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
LDYZPG:         MOV     BL,[BYTE SI]         ;Opcode A4H - Carica ind. sorgente
                INC     SI                   ;Incrementa il Program Counter
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                MOV     DH,[BYTE BX]         ;Carica Y dall'indirizzo sorgente
                TEST    DH,DH                ;Setta i flags in accordo col
                JZ      LDYZPGISZERO         ;valore di Y
                JS      LDYZPGISNEG
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDYZPGISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDYZPGISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
LDAZPG:         MOV     BL,[BYTE SI]         ;Opcode A5H
                INC     SI                   ;Incrementa il Program Counter
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                MOV     AL,[BYTE BX]         ;Carica A dall'indirizzo sorgente
                TEST    AL,AL                ;Setta i flags in accordo col
                JZ      LDAZPGISZERO         ;valore di A
                JS      LDAZPGISNEG
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDAZPGISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDAZPGISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
LDXZPG:         MOV     BL,[BYTE SI]         ;Opcode A6H
                INC     SI                   ;Incrementa il Program Counter
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                MOV     DL,[BYTE BX]         ;Carica X dall'indirizzo sorgente
                TEST    DL,DL                ;Setta i flags in accordo col
                JZ      LDXZPGISZERO         ;valore di A
                JS      LDXZPGISNEG
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDXZPGISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDXZPGISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
TAYIMP:         XOR     BH,BH                ;Opcode A8H
                MOV     DH,AL                ;Copia A in Y
                TEST    AL,AL                ;Setta i flags in accordo col
                JZ      TAYIMPISZERO         ;valore di A
                JS      TAYIMPISNEG
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
TAYIMPISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
TAYIMPISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
LDAIMM:         MOV     AL,[BYTE SI]         ;Opcode A9H - Carica operando in A
                INC     SI                   ;Incrementa il Program Counter
                XOR     BH,BH                ;Azzera parte alta indice istr.
                TEST    AL,AL                ;Setta i flags in accordo col
                JZ      LDAIMMISZERO         ;valore di A
                JS      LDAIMMISNEG
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDAIMMISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDAIMMISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
TAXIMP:         XOR     BH,BH                ;Opcode AAH
                MOV     DL,AL                ;Copia A in X
                TEST    AL,AL                ;Setta i flags in accordo col
                JZ      TAXIMPISZERO         ;valore di A
                JS      TAXIMPISNEG
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
TAXIMPISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
TAXIMPISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
LDYABS:         MOV     BX,[WORD SI]         ;Opcode ACH - Carica ind. sorgente
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                CALL    READBLBX             ;Legge il dato all'indirizzo sorg.
                MOV     DH,BL                ;Copia il dato in Y
                XOR     BH,BH                ;Azzera parte alta indice istr.
                TEST    DH,DH                ;Setta i flags in accordo col
                JZ      LDYABSISZERO         ;valore di Y
                JS      LDYABSISNEG
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDYABSISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDYABSISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
LDAABS:         MOV     BX,[WORD SI]         ;Opcode ADH - Carica ind. sorgente
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                CALL    READBLBX             ;Legge il dato all'indirizzo sorg.
                MOV     AL,BL                ;Copia il dato in A
                XOR     BH,BH                ;Azzera parte alta indice istr.
                TEST    AL,AL                ;Setta i flags in accordo col
                JZ      LDAABSISZERO         ;valore di A
                JS      LDAABSISNEG
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDAABSISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDAABSISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
LDXABS:         MOV     BX,[WORD SI]         ;Opcode AEH - Carica ind. sorgente
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                CALL    READBLBX             ;Legge il dato all'indirizzo sorg.
                MOV     DL,BL                ;Copia il dato in X
                XOR     BH,BH                ;Azzera parte alta indice istr.
                TEST    DL,DL                ;Setta i flags in accordo col
                JZ      LDXABSISZERO         ;valore di X
                JS      LDXABSISNEG
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDXABSISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDXABSISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
BCSREL:         TEST    AH,01H               ;Opcode B0H - Verifica il flag C
                JZ      BCSRELNOC            ;Se C=0 non esegue la diramazione
                INC     CH                   ;Se salta richiede un ciclo in pió
                MOV     BX,AX                ;Salva temporaneamente A e P in BX
                MOV     AL,[SI]              ;Carica spiazzamento (-128..+127);Salva temporaneamente A e P in BX
                CBW                          ;Converte spiazzamento in una word
                ADD     SI,AX                ;Somma lo spiazzamento al PC
                MOV     AX,BX                ;Riporta A e P rispett. in AL ed AH
BCSRELNOC:      XOR     BH,BH                ;Azzera parte alta indice istr.
                INC     SI                   ;Incrementa il Program Counter
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
LDAIPO:         MOV     BL,[BYTE SI]         ;Opcode B1H
                INC     SI                   ;Incrementa il Program Counter
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                MOV     BX,[WORD BX]         ;Carica indirizzo base operando
                ADD     BL,DH                ;Somma Y all'indir. base operando
                ADC     BH,00H
                CALL    READBLBX             ;Legge l'operando dalla memoria
                MOV     AL,BL                ;Carica operando in A
                XOR     BH,BH                ;Azzera parte alta indice istr.
                TEST    AL,AL                ;Setta i flags in accordo col
                JZ      LDAIPOISZERO         ;valore di A
                JS      LDAIPOISNEG
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDAIPOISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDAIPOISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
LDAIZP:         MOV     BL,[BYTE SI]         ;Opcode B2H
                INC     SI                   ;Incrementa il Program Counter
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                MOV     BX,[WORD BX]         ;Carica indirizzo base operando
                CALL    READBLBX             ;Legge l'operando dalla memoria
                MOV     AL,BL                ;Carica operando in A
                XOR     BH,BH                ;Azzera parte alta indice istr.
                TEST    AL,AL                ;Setta i flags in accordo col
                JZ      LDAIZPISZERO         ;valore di A
                JS      LDAIZPISNEG
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDAIZPISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDAIZPISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
LDYIZX:         MOV     BL,[BYTE SI]         ;Opcode B4H
                INC     SI                   ;Incrementa il Program Counter
                ADD     BL,DL                ;Somma X all'indir. dell'operando
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                CALL    READBLBX             ;Legge l'operando dalla memoria
                MOV     DH,BL                ;Carica operando in Y
                TEST    DH,DH                ;Setta i flags in accordo col
                JZ      LDYIZXISZERO         ;valore di Y
                JS      LDYIZXISNEG
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDYIZXISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDYIZXISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
LDAIZX:         MOV     BL,[BYTE SI]         ;Opcode B5H
                INC     SI                   ;Incrementa il Program Counter
                ADD     BL,DL                ;Somma X all'indir. dell'operando
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                CALL    READBLBX             ;Legge l'operando dalla memoria
                MOV     AL,BL                ;Carica operando in A
                TEST    AL,AL                ;Setta i flags in accordo col
                JZ      LDAIZXISZERO         ;valore di A
                JS      LDAIZXISNEG
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDAIZXISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDAIZXISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
LDXIZY:         MOV     BL,[BYTE SI]         ;Opcode B6H
                INC     SI                   ;Incrementa il Program Counter
                ADD     BL,DH                ;Somma Y all'indir. dell'operando
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                CALL    READBLBX             ;Legge l'operando dalla memoria
                MOV     DL,BL                ;Carica operando in X
                TEST    DL,DL                ;Setta i flags in accordo col
                JZ      LDXIZYISZERO         ;valore di X
                JS      LDXIZYISNEG
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDXIZYISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDXIZYISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
CLVIMP:         AND     AH,0BFH              ;Opcode B8H - Azzera il flag V
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
LDAINY:         MOV     BL,DH                ;Opcode B9H
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                ADD     BX,[WORD SI]         ;BX = Y + indirizzo base operando
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                CALL    READBLBX             ;Legge l'operando dalla memoria
                MOV     AL,BL                ;Copia l'operando in A
                XOR     BH,BH                ;Azzera parte alta indice istr.
                TEST    AL,AL                ;Setta i flags in accordo col
                JZ      LDAINYISZERO         ;valore di A
                JS      LDAINYISNEG
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDAINYISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDAINYISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
TSXIMP:         MOV     BX,DI                ;Opcode BAH - Copia S in DI
                MOV     DL,BL                ;Copia parte bassa di S in X
                XOR     BH,BH                ;Azzera parte alta indice istr.
                TEST    DL,DL                ;Setta i flags in accordo col
                JZ      TSXIMPISZERO         ;valore di X
                JS      TSXIMPISNEG
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
TSXIMPISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
TSXIMPISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
LDYINX:         MOV     BL,DL                ;Opcode BCH
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                ADD     BX,[WORD SI]         ;BX = X + indirizzo base operando
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                CALL    READBLBX             ;Legge l'operando dalla memoria
                MOV     DH,BL                ;Copia l'operando in Y
                XOR     BH,BH                ;Azzera parte alta indice istr.
                TEST    DH,DH                ;Setta i flags in accordo col
                JZ      LDYINXISZERO         ;valore di Y
                JS      LDYINXISNEG
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDYINXISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDYINXISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
LDAINX:         MOV     BL,DL                ;Opcode BDH
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                ADD     BX,[WORD SI]         ;BX = X + indirizzo base operando
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                CALL    READBLBX             ;Legge l'operando dalla memoria
                MOV     AL,BL                ;Copia l'operando in A
                XOR     BH,BH                ;Azzera parte alta indice istr.
                TEST    AL,AL                ;Setta i flags in accordo col
                JZ      LDAINXISZERO         ;valore di A
                JS      LDAINXISNEG
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDAINXISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDAINXISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
LDXINY:         MOV     BL,DH                ;Opcode BEH
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                ADD     BX,[WORD SI]         ;BX = X + indirizzo base operando
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                CALL    READBLBX             ;Legge l'operando dalla memoria
                MOV     DL,BL                ;Copia l'operando in X
                XOR     BH,BH                ;Azzera parte alta indice istr.
                TEST    DL,DL                ;Setta i flags in accordo col
                JZ      LDXINYISZERO         ;valore di X
                JS      LDXINYISNEG
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDXINYISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
LDXINYISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
CPYIMM:         XOR     BH,BH                ;Opcode C0H
                AND     AH,0FEH              ;Prepara C=0, C verrÖ settato
                                             ;in seguito se necessario
                CMP     DH,[BYTE SI]         ;Confronta Y con l'operando
                JZ      CPYIMMISZERO         ;Setta i flags in accordo col
                JS      CPYIMMISNEG          ;risultato
;NOTA: C viene settato al contrario del flag carry dell'80x86
                JC      CPYIMMNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
CPYIMMNOCARRY:  AND     AH,7DH
                INC     SI                   ;Incrementa il Program Counter
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
CPYIMMISNEG:    JC      CPYIMMISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
CPYIMMISNEGNC:  AND     AH,7DH
                OR      AH,80H
                INC     SI                   ;Incrementa il Program Counter
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
CPYIMMISZERO:   JC      CPYIMMISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
CPYIMMISZERONC: AND     AH,7DH
                OR      AH,02H
                INC     SI                   ;Incrementa il Program Counter
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
CMPIPR:         MOV     BL,[BYTE SI]         ;Opcode C1H
                INC     SI                   ;Incrementa il Program Counter
                AND     AH,0FEH              ;Prepara C=0, C verrÖ settato
                                             ;in seguito se necessario
                ADD     BL,DL                ;Somma X al puntatore in pagina 0
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                MOV     BX,[WORD BX]         ;Carica l'indirizzo dell'operando
                CALL    READBLBX             ;Carica l'operando in BL
                CMP     AL,BL                ;Confronta A con l'operando
                JZ      CMPIPRISZERO         ;Setta i flags in accordo col
                JS      CMPIPRISNEG          ;risultato
;NOTA: C viene settato al contrario del flag carry dell'80x86
                JC      CMPIPRNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
CMPIPRNOCARRY:  AND     AH,7DH
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
CMPIPRISNEG:    JC      CMPIPRISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
CMPIPRISNEGNC:  AND     AH,7DH
                OR      AH,80H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
CMPIPRISZERO:   JC      CMPIPRISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
CMPIPRISZERONC: AND     AH,7DH
                OR      AH,02H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
CPYZPG:         XOR     BH,BH                ;Opcode C4H
                AND     AH,0FEH              ;Prepara C=0, C verrÖ settato
                                             ;in seguito se necessario
                MOV     BL,[BYTE SI]         ;Carica indirizzo operando
                INC     SI                   ;Incrementa il Program Counter
                CMP     DH,[BYTE BX]         ;Confronta Y con l'operando
                JZ      CPYZPGISZERO         ;Setta i flags in accordo col
                JS      CPYZPGISNEG          ;risultato
;NOTA: C viene settato al contrario del flag carry dell'80x86
                JC      CPYZPGNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
CPYZPGNOCARRY:  AND     AH,7DH
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
CPYZPGISNEG:    JC      CPYZPGISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
CPYZPGISNEGNC:  AND     AH,7DH
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
CPYZPGISZERO:   JC      CPYZPGISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
CPYZPGISZERONC: AND     AH,7DH
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
CMPZPG:         XOR     BH,BH                ;Opcode C5H
                AND     AH,0FEH              ;Prepara C=0, C verrÖ settato
                                             ;in seguito se necessario
                MOV     BL,[BYTE SI]         ;Carica indirizzo operando
                INC     SI                   ;Incrementa il Program Counter
                CMP     AL,[BYTE BX]         ;Confronta A con l'operando
                JZ      CMPZPGISZERO         ;Setta i flags in accordo col
                JS      CMPZPGISNEG          ;risultato
;NOTA: C viene settato al contrario del flag carry dell'80x86
                JC      CMPZPGNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
CMPZPGNOCARRY:  AND     AH,7DH
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
CMPZPGISNEG:    JC      CMPZPGISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
CMPZPGISNEGNC:  AND     AH,7DH
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
CMPZPGISZERO:   JC      CMPZPGISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
CMPZPGISZERONC: AND     AH,7DH
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
DECZPG:         XOR     BH,BH                ;Opcode C6H
                MOV     BL,[BYTE SI]         ;Carica indirizzo operando
                INC     SI                   ;Incrementa il Program Counter
                DEC     [BYTE BX]            ;Decrementa l'operando
                JZ      DECZPGISZERO         ;Setta i flags in accordo col
                JS      DECZPGISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
DECZPGISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
DECZPGISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
INYIMP:         XOR     BH,BH                ;Opcode C8H
                INC     DH                   ;Incrementa il registro Y
                JZ      INYIMPISZERO         ;Setta i flags in accordo col
                JS      INYIMPISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
INYIMPISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
INYIMPISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
CMPIMM:         XOR     BH,BH                ;Opcode C9H
                AND     AH,0FEH              ;Prepara C=0, C verrÖ settato
                                             ;in seguito se necessario
                CMP     AL,[BYTE SI]         ;Confronta A con l'operando
                JZ      CMPIMMISZERO         ;Setta i flags in accordo col
                JS      CMPIMMISNEG          ;risultato
;NOTA: C viene settato al contrario del flag carry dell'80x86
                JC      CMPIMMNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
CMPIMMNOCARRY:  AND     AH,7DH
                INC     SI                   ;Incrementa il Program Counter
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
CMPIMMISNEG:    JC      CMPIMMISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
CMPIMMISNEGNC:  AND     AH,7DH
                OR      AH,80H
                INC     SI                   ;Incrementa il Program Counter
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
CMPIMMISZERO:   JC      CMPIMMISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
CMPIMMISZERONC: AND     AH,7DH
                OR      AH,02H
                INC     SI                   ;Incrementa il Program Counter
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
DEXIMP:         XOR     BH,BH                ;Opcode CAH
                DEC     DL                   ;Decrementa il registro X
                JZ      DEXIMPISZERO         ;Setta i flags in accordo col
                JS      DEXIMPISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
DEXIMPISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
DEXIMPISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
CPYABS:         MOV     BX,[WORD SI]         ;Opcode CCH - Carica ind. operando
                AND     AH,0FEH              ;Prepara C=0, C verrÖ settato
                                             ;in seguito se necessario
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                CALL    READBLBX             ;Legge l'operando dalla memoria
                CMP     DH,BL                ;Confronta Y con l'operando
                JZ      CPYABSISZERO         ;Setta i flags in accordo col
                JS      CPYABSISNEG          ;risultato
;NOTA: C viene settato al contrario del flag carry dell'80x86
                JC      CPYABSNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
CPYABSNOCARRY:  AND     AH,7DH
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
CPYABSISNEG:    JC      CPYABSISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
CPYABSISNEGNC:  AND     AH,7DH
                OR      AH,80H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
CPYABSISZERO:   JC      CPYABSISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
CPYABSISZERONC: AND     AH,7DH
                OR      AH,02H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
CMPABS:         MOV     BX,[WORD SI]         ;Opcode CDH - Carica ind. operando
                AND     AH,0FEH              ;Prepara C=0, C verrÖ settato
                                             ;in seguito se necessario
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                CALL    READBLBX             ;Legge l'operando dalla memoria
                CMP     AL,BL                ;Confronta A con l'operando
                JZ      CMPABSISZERO         ;Setta i flags in accordo col
                JS      CMPABSISNEG          ;risultato
;NOTA: C viene settato al contrario del flag carry dell'80x86
                JC      CMPABSNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
CMPABSNOCARRY:  AND     AH,7DH
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
CMPABSISNEG:    JC      CMPABSISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
CMPABSISNEGNC:  AND     AH,7DH
                OR      AH,80H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
CMPABSISZERO:   JC      CMPABSISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
CMPABSISZERONC: AND     AH,7DH
                OR      AH,02H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
DECABS:         MOV     BX,[WORD SI]         ;Opcode CEH - Carica ind. operando
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                MOV     CL,BL                ;Salva LSB indir. operando in CL
                CALL    READBLBX             ;Carica l'operando in memoria
                XCHG    BL,CL                ;Rimette operando in CL e LSB in BL
                DEC     CL                   ;Decrementa l'operando
                JZ      DECABSISZERO         ;Setta i flags in accordo col
                JS      DECABSISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                CALL    WRITEBXCL            ;Salva l'operando in memoria
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
DECABSISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                CALL    WRITEBXCL            ;Salva l'operando in memoria
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
DECABSISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                CALL    WRITEBXCL            ;Salva l'operando in memoria
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
BNEREL:         TEST    AH,02H               ;Opcode D0H - Verifica il flag Z
                JNZ     BNERELZ              ;Se Z=1 non esegue la diramazione
                INC     CH                   ;Se salta richiede un ciclo in pió
                MOV     BX,AX                ;Salva temporaneamente A e P in BX
                MOV     AL,[SI]              ;Carica spiazzamento (-128..+127)
                CBW                          ;Converte spiazzamento in una word
                ADD     SI,AX                ;Somma lo spiazzamento al PC
                MOV     AX,BX                ;Riporta A e P rispett. in AL ed AH
BNERELZ:        XOR     BH,BH                ;Azzera parte alta indice istr.
                INC     SI                   ;Incrementa il Program Counter
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
CMPIPO:         MOV     BL,[BYTE SI]         ;Opcode D1H
                INC     SI                   ;Incrementa il Program Counter
                AND     AH,0FEH              ;Prepara C=0, C verrÖ settato
                                             ;in seguito se necessario
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                MOV     BX,[WORD BX]         ;Carica indirizzo base operando
                ADD     BL,DH                ;Somma Y all'indir. base operando
                ADC     BH,00H
                CALL    READBLBX             ;Carica l'operando in BL
                CMP     AL,BL                ;Confronta A con l'operando
                JZ      CMPIPOISZERO         ;Setta i flags in accordo col
                JS      CMPIPOISNEG          ;risultato
;NOTA: C viene settato al contrario del flag carry dell'80x86
                JC      CMPIPONOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
CMPIPONOCARRY:  AND     AH,7DH
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
CMPIPOISNEG:    JC      CMPIPOISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
CMPIPOISNEGNC:  AND     AH,7DH
                OR      AH,80H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
CMPIPOISZERO:   JC      CMPIPOISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
CMPIPOISZERONC: AND     AH,7DH
                OR      AH,02H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
CMPIZP:         MOV     BL,[BYTE SI]         ;Opcode D2H
                INC     SI                   ;Incrementa il Program Counter
                AND     AH,0FEH              ;Prepara C=0, C verrÖ settato
                                             ;in seguito se necessario
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                MOV     BX,[WORD BX]         ;Carica indirizzo base operando
                CALL    READBLBX             ;Carica l'operando in BL
                CMP     AL,BL                ;Confronta A con l'operando
                JZ      CMPIZPISZERO         ;Setta i flags in accordo col
                JS      CMPIZPISNEG          ;risultato
;NOTA: C viene settato al contrario del flag carry dell'80x86
                JC      CMPIZPNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
CMPIZPNOCARRY:  AND     AH,7DH
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
CMPIZPISNEG:    JC      CMPIZPISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
CMPIZPISNEGNC:  AND     AH,7DH
                OR      AH,80H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
CMPIZPISZERO:   JC      CMPIZPISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
CMPIZPISZERONC: AND     AH,7DH
                OR      AH,02H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
CMPIZX:         XOR     BH,BH                ;Opcode D5H
                AND     AH,0FEH              ;Prepara C=0, C verrÖ settato
                                             ;in seguito se necessario
                MOV     BL,[BYTE SI]         ;Carica indirizzo base operando
                INC     SI                   ;Incrementa il Program Counter
                ADD     BL,DL                ;Somma X all'indir. base operando
                CMP     AL,[BYTE BX]         ;Confronta A con l'operando
                JZ      CMPIZXISZERO         ;Setta i flags in accordo col
                JS      CMPIZXISNEG          ;risultato
                JC      CMPIZXNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
CMPIZXNOCARRY:  AND     AH,7DH
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
CMPIZXISNEG:    JC      CMPIZXISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
CMPIZXISNEGNC:  AND     AH,7DH
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
CMPIZXISZERO:   JC      CMPIZXISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
CMPIZXISZERONC: AND     AH,7DH
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
DECIZX:         XOR     BH,BH                ;Opcode D6H
                MOV     BL,[BYTE SI]         ;Carica indirizzo base operando
                INC     SI                   ;Incrementa il Program Counter
                ADD     BL,DL                ;Somma X all'indir. base operando
                DEC     [BYTE BX]            ;Decrementa l'operando
                JZ      DECIZXISZERO         ;Setta i flags in accordo col
                JS      DECIZXISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
DECIZXISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
DECIZXISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
CLDIMP:         AND     AH,0F7H              ;Opcode D8H - Azzera il flag D
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
CMPINY:         MOV     BL,DH                ;Opcode D9H
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                ADD     BX,[WORD SI]         ;BX = Y + indirizzo base operando
                AND     AH,0FEH              ;Prepara C=0, C verrÖ settato
                                             ;in seguito se necessario
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                CALL    READBLBX             ;Legge l'operando dalla memoria
                CMP     AL,BL                ;Confronta A con l'operando
                JZ      CMPINYISZERO         ;Setta i flags in accordo col
                JS      CMPINYISNEG          ;risultato
;NOTA: C viene settato al contrario del flag carry dell'80x86
                JC      CMPINYNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
CMPINYNOCARRY:  AND     AH,7DH
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
CMPINYISNEG:    JC      CMPINYISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
CMPINYISNEGNC:  AND     AH,7DH
                OR      AH,80H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
CMPINYISZERO:   JC      CMPINYISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
CMPINYISZERONC: AND     AH,7DH
                OR      AH,02H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
PHXIMP:         MOV     [BYTE DI],DL         ;Opcode DAH - Salva X nello stack
                DEC     DI                   ;Decrementa lo Stack Pointer
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
CMPINX:         MOV     BL,DL                ;Opcode DDH
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                ADD     BX,[WORD SI]         ;BX = X + indirizzo base operando
                AND     AH,0FEH              ;Prepara C=0, C verrÖ settato
                                             ;in seguito se necessario
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                CALL    READBLBX             ;Legge l'operando dalla memoria
                CMP     AL,BL                ;Confronta A con l'operando
                JZ      CMPINXISZERO         ;Setta i flags in accordo col
                JS      CMPINXISNEG          ;risultato
;NOTA: C viene settato al contrario del flag carry dell'80x86
                JC      CMPINXNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
CMPINXNOCARRY:  AND     AH,7DH
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
CMPINXISNEG:    JC      CMPINXISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
CMPINXISNEGNC:  AND     AH,7DH
                OR      AH,80H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
CMPINXISZERO:   JC      CMPINXISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
CMPINXISZERONC: AND     AH,7DH
                OR      AH,02H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
DECINX:         MOV     BL,DL                ;Opcode DEH
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                ADD     BX,[WORD SI]         ;BX = X + indirizzo base operando
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                MOV     CL,BL                ;Salva LSB indir. operando in CL
                CALL    READBLBX             ;Carica l'operando in memoria
                XCHG    BL,CL                ;Rimette operando in CL e LSB in BL
                DEC     CL                   ;Decrementa l'operando
                JZ      DECINXISZERO         ;Setta i flags in accordo col
                JS      DECINXISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                CALL    WRITEBXCL            ;Salva l'operando in memoria
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
DECINXISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                CALL    WRITEBXCL            ;Salva l'operando in memoria
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
DECINXISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                CALL    WRITEBXCL            ;Salva l'operando in memoria
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
CPXIMM:         XOR     BH,BH                ;Opcode E0H
                AND     AH,0FEH              ;Prepara C=0, C verrÖ settato
                                             ;in seguito se necessario
                CMP     DL,[BYTE SI]         ;Confronta X con l'operando
                JZ      CPXIMMISZERO         ;Setta i flags in accordo col
                JS      CPXIMMISNEG          ;risultato
;NOTA: C viene settato al contrario del flag carry dell'80x86
                JC      CPXIMMNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
CPXIMMNOCARRY:  AND     AH,7DH
                INC     SI                   ;Incrementa il Program Counter
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
CPXIMMISNEG:    JC      CPXIMMISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
CPXIMMISNEGNC:  AND     AH,7DH
                OR      AH,80H
                INC     SI                   ;Incrementa il Program Counter
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
CPXIMMISZERO:   JC      CPXIMMISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
CPXIMMISZERONC: AND     AH,7DH
                OR      AH,02H
                INC     SI                   ;Incrementa il Program Counter
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
SBCIPR:         MOV     BL,[BYTE SI]         ;Opcode E1H
                INC     SI                   ;Incrementa il Program Counter
                ADD     BL,DL                ;Somma X al puntatore in pagina 0
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                MOV     BX,[WORD BX]         ;Carica l'indirizzo dell'operando
                CALL    READBLBX             ;Legge l'operando dalla memoria
                MOV     BH,BL                ;Copia l'operando in BH
                MOV     BL,AH                ;Copia P in BL
                AND     BL,3CH               ;Res. flags da settare in seguito
                TEST    AH,08H               ;Sceglie routine binaria o decimale
                JNZ     SBCIPRDEC            ;a seconda del valore del flag D

;Routine di sottrazione binaria
                TEST    AH,01H               ;Pone C negato nel carry dell'80x86
                JNZ     SBCIPRNODNOC         ;(TEST pone il carry a zero)
                STC
SBCIPRNODNOC:   SBB     AL,BH                ;Sottrae l'operando ad A
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     SBCIPRNODNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
SBCIPRNODNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      SBCIPRNODNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
SBCIPRNODNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta i flags N e C
                XOR     AH,01H               ;Complementa il flag C
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.

;Routine di sottrazione BCD
SBCIPRDEC:      INC     CH                   ;In modo decimale SBC richiede
                                             ;un ciclo di clock in pió
                TEST    AH,01H               ;Pone C negato nel carry dell'80x86
                JNZ     SBCIPRDECNOC         ;(TEST pone il carry a zero)
                STC
SBCIPRDECNOC:   SBB     AL,BH                ;Sottrae l'operando ad A
                DAS                          ;Converte il risultato in BCD
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     SBCIPRDECNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
SBCIPRDECNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      SBCIPRDECNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
SBCIPRDECNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta i flags N e C
                XOR     AH,01H               ;Complementa il flag C
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
CPXZPG:         XOR     BH,BH                ;Opcode E4H
                AND     AH,0FEH              ;Prepara C=0, C verrÖ settato
                                             ;in seguito se necessario
                MOV     BL,[BYTE SI]         ;Carica indirizzo operando
                INC     SI                   ;Incrementa il Program Counter
                CMP     DL,[BYTE BX]         ;Confronta X con l'operando
                JZ      CPXZPGISZERO         ;Setta i flags in accordo col
                JS      CPXZPGISNEG          ;risultato
;NOTA: C viene settato al contrario del flag carry dell'80x86
                JC      CPXZPGNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
CPXZPGNOCARRY:  AND     AH,7DH
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
CPXZPGISNEG:    JC      CPXZPGISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
CPXZPGISNEGNC:  AND     AH,7DH
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
CPXZPGISZERO:   JC      CPXZPGISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
CPXZPGISZERONC: AND     AH,7DH
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
SBCZPG:         MOV     BL,[BYTE SI]         ;Opcode E5H
                INC     SI                   ;Incrementa il Program Counter
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                MOV     BH,[BYTE BX]         ;Legge l'operando dalla memoria
                MOV     BL,AH                ;Copia P in BL
                AND     BL,3CH               ;Res. flags da settare in seguito
                TEST    AH,08H               ;Sceglie routine binaria o decimale
                JNZ     SBCZPGDEC            ;a seconda del valore del flag D

;Routine di sottrazione binaria
                TEST    AH,01H               ;Pone C negato nel carry dell'80x86
                JNZ     SBCZPGNODNOC         ;(TEST pone il carry a zero)
                STC
SBCZPGNODNOC:   SBB     AL,BH                ;Sottrae l'operando ad A
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     SBCZPGNODNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
SBCZPGNODNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      SBCZPGNODNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
SBCZPGNODNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta i flags N e C
                XOR     AH,01H               ;Complementa il flag C
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.

;Routine di sottrazione BCD
SBCZPGDEC:      INC     CH                   ;In modo decimale SBC richiede
                                             ;un ciclo di clock in pió
                TEST    AH,01H               ;Pone C negato nel carry dell'80x86
                JNZ     SBCZPGDECNOC         ;(TEST pone il carry a zero)
                STC
SBCZPGDECNOC:   SBB     AL,BH                ;Sottrae l'operando ad A
                DAS                          ;Converte il risultato in BCD
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     SBCZPGDECNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
SBCZPGDECNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      SBCZPGDECNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
SBCZPGDECNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta i flags N e C
                XOR     AH,01H               ;Complementa il flag C
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
INCZPG:         XOR     BH,BH                ;Opcode E6H
                MOV     BL,[BYTE SI]         ;Carica indirizzo operando
                INC     SI                   ;Incrementa il Program Counter
                INC     [BYTE BX]            ;Incrementa l'operando
                JZ      INCZPGISZERO         ;Setta i flags in accordo col
                JS      INCZPGISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
INCZPGISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
INCZPGISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
INXIMP:         XOR     BH,BH                ;Opcode E8H
                INC     DL                   ;Incrementa il registro X
                JZ      INXIMPISZERO         ;Setta i flags in accordo col
                JS      INXIMPISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
INXIMPISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
INXIMPISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
SBCIMM:         MOV     BL,AH                ;Opcode E9H
                AND     BL,3CH               ;Res. flags da settare in seguito
                TEST    AH,08H               ;Sceglie routine binaria o decimale
                JNZ     SBCIMMDEC            ;a seconda del valore del flag D

;Routine di sottrazione binaria
                TEST    AH,01H               ;Pone C negato nel carry dell'80x86
                JNZ     SBCIMMNODNOC         ;(TEST pone il carry a zero)
                STC
SBCIMMNODNOC:   SBB     AL,[BYTE SI]         ;Sottrae l'operando ad A
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     SBCIMMNODNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
SBCIMMNODNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      SBCIMMNODNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
SBCIMMNODNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta i flags N e C
                XOR     AH,01H               ;Complementa il flag C
                INC     SI                   ;Incrementa il Program Counter
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.

;Routine di sottrazione BCD
SBCIMMDEC:      INC     CH                   ;In modo decimale SBC richiede
                                             ;un ciclo di clock in pió
                TEST    AH,01H               ;Pone C negato nel carry dell'80x86
                JNZ     SBCIMMDECNOC         ;(TEST pone il carry a zero)
                STC
SBCIMMDECNOC:   SBB     AL,[BYTE SI]         ;Sottrae l'operando ad A
                DAS                          ;Converte il risultato in BCD
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     SBCIMMDECNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
SBCIMMDECNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      SBCIMMDECNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
SBCIMMDECNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta i flags N e C
                XOR     AH,01H               ;Complementa il flag C
                INC     SI                   ;Incrementa il Program Counter
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
CPXABS:         MOV     BX,[WORD SI]         ;Opcode ECH
                AND     AH,0FEH              ;Prepara C=0, C verrÖ settato
                                             ;in seguito se necessario
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                CALL    READBLBX             ;Legge l'operando dalla memoria
                CMP     DL,BL                ;Confronta X con l'operando
                JZ      CPXABSISZERO         ;Setta i flags in accordo col
                JS      CPXABSISNEG          ;risultato
;NOTA: C viene settato al contrario del flag carry dell'80x86
                JC      CPXABSNOCARRY        ;Z=0, N=0
                OR      AH,01H               ;C=1
CPXABSNOCARRY:  AND     AH,7DH
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
CPXABSISNEG:    JC      CPXABSISNEGNC        ;Z=0, N=1
                OR      AH,01H               ;C=1
CPXABSISNEGNC:  AND     AH,7DH
                OR      AH,80H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
CPXABSISZERO:   JC      CPXABSISZERONC       ;Z=1, N=0
                OR      AH,01H               ;C=1
CPXABSISZERONC: AND     AH,7DH
                OR      AH,02H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
SBCABS:         MOV     BX,[WORD SI]         ;Opcode EDH
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                CALL    READBLBX             ;Legge l'operando dalla memoria
                MOV     BH,BL                ;Copia l'operando in BH
                MOV     BL,AH                ;Copia P in BL
                AND     BL,3CH               ;Res. flags da settare in seguito
                TEST    AH,08H               ;Sceglie routine binaria o decimale
                JNZ     SBCABSDEC            ;a seconda del valore del flag D

;Routine di sottrazione binaria
                TEST    AH,01H               ;Pone C negato nel carry dell'80x86
                JNZ     SBCABSNODNOC         ;(TEST pone il carry a zero)
                STC
SBCABSNODNOC:   SBB     AL,BH                ;Sottrae l'operando ad A
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     SBCABSNODNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
SBCABSNODNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      SBCABSNODNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
SBCABSNODNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta i flags N e C
                XOR     AH,01H               ;Complementa il flag C
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.

;Routine di sottrazione BCD
SBCABSDEC:      INC     CH                   ;In modo decimale SBC richiede
                                             ;un ciclo di clock in pió
                TEST    AH,01H               ;Pone C negato nel carry dell'80x86
                JNZ     SBCABSDECNOC         ;(TEST pone il carry a zero)
                STC
SBCABSDECNOC:   SBB     AL,BH                ;Sottrae l'operando ad A
                DAS                          ;Converte il risultato in BCD
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     SBCABSDECNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
SBCABSDECNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      SBCABSDECNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
SBCABSDECNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta i flags N e C
                XOR     AH,01H               ;Complementa il flag C
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
INCABS:         MOV     BX,[WORD SI]         ;Opcode EEH - Carica ind. operando
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                MOV     CL,BL                ;Salva LSB indir. operando in CL
                CALL    READBLBX             ;Carica l'operando in memoria
                XCHG    BL,CL                ;Rimette operando in CL e LSB in BL
                INC     CL                   ;Incrementa l'operando
                JZ      INCABSISZERO         ;Setta i flags in accordo col
                JS      INCABSISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                CALL    WRITEBXCL            ;Salva l'operando in memoria
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
INCABSISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                CALL    WRITEBXCL            ;Salva l'operando in memoria
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
INCABSISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                CALL    WRITEBXCL            ;Salva l'operando in memoria
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
BEQREL:         TEST    AH,02H               ;Opcode F0H - Verifica il flag Z
                JZ      BEQRELNOZ            ;Se Z=0 non esegue la diramazione
                INC     CH                   ;Se salta richiede un ciclo in pió
                MOV     BX,AX                ;Salva temporaneamente A e P in BX
                MOV     AL,[SI]              ;Carica spiazzamento (-128..+127)
                CBW                          ;Converte spiazzamento in una word
                ADD     SI,AX                ;Somma lo spiazzamento al PC
                MOV     AX,BX                ;Riporta A e P rispett. in AL ed AH
BEQRELNOZ:      XOR     BH,BH                ;Azzera parte alta indice istr.
                INC     SI                   ;Incrementa il Program Counter
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
SBCIPO:         MOV     BL,[BYTE SI]         ;Opcode F1H
                INC     SI                   ;Incrementa il Program Counter
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                MOV     BX,[WORD BX]         ;Carica indirizzo base operando
                ADD     BL,DH                ;Somma Y all'indir. base operando
                ADC     BH,00H
                CALL    READBLBX             ;Legge l'operando dalla memoria
                MOV     BH,BL                ;Copia l'operando in BH
                MOV     BL,AH                ;Copia P in BL
                AND     BL,3CH               ;Res. flags da settare in seguito
                TEST    AH,08H               ;Sceglie routine binaria o decimale
                JNZ     SBCIPODEC            ;a seconda del valore del flag D

;Routine di sottrazione binaria
                TEST    AH,01H               ;Pone C negato nel carry dell'80x86
                JNZ     SBCIPONODNOC         ;(TEST pone il carry a zero)
                STC
SBCIPONODNOC:   SBB     AL,BH                ;Sottrae l'operando ad A
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     SBCIPONODNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
SBCIPONODNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      SBCIPONODNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
SBCIPONODNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta i flags N e C
                XOR     AH,01H               ;Complementa il flag C
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.

;Routine di sottrazione BCD
SBCIPODEC:      INC     CH                   ;In modo decimale SBC richiede
                                             ;un ciclo di clock in pió
                TEST    AH,01H               ;Pone C negato nel carry dell'80x86
                JNZ     SBCIPODECNOC         ;(TEST pone il carry a zero)
                STC
SBCIPODECNOC:   SBB     AL,BH                ;Sottrae l'operando ad A
                DAS                          ;Converte il risultato in BCD
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     SBCIPODECNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
SBCIPODECNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      SBCIPODECNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
SBCIPODECNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta i flags N e C
                XOR     AH,01H               ;Complementa il flag C
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
SBCIZP:         MOV     BL,[BYTE SI]         ;Opcode F2H
                INC     SI                   ;Incrementa il Program Counter
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                MOV     BX,[WORD BX]         ;Carica l'indirizzo dell'operando
                CALL    READBLBX             ;Legge l'operando dalla memoria
                MOV     BH,BL                ;Copia l'operando in BH
                MOV     BL,AH                ;Copia P in BL
                AND     BL,3CH               ;Res. flags da settare in seguito
                TEST    AH,08H               ;Sceglie routine binaria o decimale
                JNZ     SBCIZPDEC            ;a seconda del valore del flag D

;Routine di sottrazione binaria
                TEST    AH,01H               ;Pone C negato nel carry dell'80x86
                JNZ     SBCIZPNODNOC         ;(TEST pone il carry a zero)
                STC
SBCIZPNODNOC:   SBB     AL,BH                ;Sottrae l'operando ad A
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     SBCIZPNODNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
SBCIZPNODNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      SBCIZPNODNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
SBCIZPNODNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta i flags N e C
                XOR     AH,01H               ;Complementa il flag C
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.

;Routine di sottrazione BCD
SBCIZPDEC:      INC     CH                   ;In modo decimale SBC richiede
                                             ;un ciclo di clock in pió
                TEST    AH,01H               ;Pone C negato nel carry dell'80x86
                JNZ     SBCIZPDECNOC         ;(TEST pone il carry a zero)
                STC
SBCIZPDECNOC:   SBB     AL,BH                ;Sottrae l'operando ad A
                DAS                          ;Converte il risultato in BCD
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     SBCIZPDECNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
SBCIZPDECNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      SBCIZPDECNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
SBCIZPDECNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta i flags N e C
                XOR     AH,01H               ;Complementa il flag C
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
SBCIZX:         MOV     BL,[BYTE SI]         ;Opcode F5H
                INC     SI                   ;Incrementa il Program Counter
                ADD     BL,DL                ;Somma X all'indir. base operando
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                MOV     BH,[BYTE BX]         ;Carica l'operando dalla memoria
                MOV     BL,AH                ;Copia P in BL
                AND     BL,3CH               ;Res. flags da settare in seguito
                TEST    AH,08H               ;Sceglie routine binaria o decimale
                JNZ     SBCIZXDEC            ;a seconda del valore del flag D

;Routine di sottrazione binaria
                TEST    AH,01H               ;Pone C negato nel carry dell'80x86
                JNZ     SBCIZXNODNOC         ;(TEST pone il carry a zero)
                STC
SBCIZXNODNOC:   SBB     AL,BH                ;Sottrae l'operando ad A
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     SBCIZXNODNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
SBCIZXNODNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      SBCIZXNODNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
SBCIZXNODNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta i flags N e C
                XOR     AH,01H               ;Complementa il flag C
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.

;Routine di sottrazione BCD
SBCIZXDEC:      INC     CH                   ;In modo decimale SBC richiede
                                             ;un ciclo di clock in pió
                TEST    AH,01H               ;Pone C negato nel carry dell'80x86
                JNZ     SBCIZXDECNOC         ;(TEST pone il carry a zero)
                STC
SBCIZXDECNOC:   SBB     AL,BH                ;Sottrae l'operando ad A
                DAS                          ;Converte il risultato in BCD
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     SBCIZXDECNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
SBCIZXDECNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      SBCIZXDECNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
SBCIZXDECNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta i flags N e C
                XOR     AH,01H               ;Complementa il flag C
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
INCIZX:         XOR     BH,BH                ;Opcode F6H
                MOV     BL,[BYTE SI]         ;Carica indirizzo base operando
                INC     SI                   ;Incrementa il Program Counter
                ADD     BL,DL                ;Somma X all'indir. base operando
                INC     [BYTE BX]            ;Incrementa l'operando
                JZ      INCIZXISZERO         ;risultato
                JS      INCIZXISNEG
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
INCIZXISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
INCIZXISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
SEDIMP:         OR      AH,08H               ;Opcode F8H - Setta D=1
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
SBCINY:         MOV     BL,DH                ;Opcode F9H
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                ADD     BX,[WORD SI]         ;BX = Y + indirizzo base operando
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                CALL    READBLBX             ;Carica l'operando dalla memoria
                MOV     BH,BL                ;Copia l'operando in BH
                MOV     BL,AH                ;Copia P in BL
                AND     BL,3CH               ;Res. flags da settare in seguito
                TEST    AH,08H               ;Sceglie routine binaria o decimale
                JNZ     SBCINYDEC            ;a seconda del valore del flag D

;Routine di sottrazione binaria
                TEST    AH,01H               ;Pone C negato nel carry dell'80x86
                JNZ     SBCINYNODNOC         ;(TEST pone il carry a zero)
                STC
SBCINYNODNOC:   SBB     AL,BH                ;Sottrae l'operando ad A
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     SBCINYNODNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
SBCINYNODNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      SBCINYNODNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
SBCINYNODNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta i flags N e C
                XOR     AH,01H               ;Complementa il flag C
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.

;Routine di sottrazione BCD
SBCINYDEC:      INC     CH                   ;In modo decimale SBC richiede
                                             ;un ciclo di clock in pió
                TEST    AH,01H               ;Pone C negato nel carry dell'80x86
                JNZ     SBCINYDECNOC         ;(TEST pone il carry a zero)
                STC
SBCINYDECNOC:   SBB     AL,BH                ;Sottrae l'operando ad A
                DAS                          ;Converte il risultato in BCD
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     SBCINYDECNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
SBCINYDECNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      SBCINYDECNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
SBCINYDECNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta i flags N e C
                XOR     AH,01H               ;Complementa il flag C
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
PLXIMP:         INC     DI                   ;Opcode FAH - Incrementa S
                MOV     DL,[BYTE DI]         ;Carica X dallo stack
                TEST    DL,DL                ;Setta i flags in accordo col
                JZ      PLXIMPISZERO         ;valore di X
                JS      PLXIMPISNEG
                AND     AH,7DH               ;Z=0, N=0
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
PLXIMPISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
PLXIMPISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
SBCINX:         MOV     BL,DL                ;Opcode FDH
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                ADD     BX,[WORD SI]         ;BX = X + indirizzo base operando
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                CALL    READBLBX             ;Carica l'operando dalla memoria
                MOV     BH,BL                ;Copia l'operando in BH
                MOV     BL,AH                ;Copia P in BL
                AND     BL,3CH               ;Res. flags da settare in seguito
                TEST    AH,08H               ;Sceglie routine binaria o decimale
                JNZ     SBCINXDEC            ;a seconda del valore del flag D

;Routine di sottrazione binaria
                TEST    AH,01H               ;Pone C negato nel carry dell'80x86
                JNZ     SBCINXNODNOC         ;(TEST pone il carry a zero)
                STC
SBCINXNODNOC:   SBB     AL,BH                ;Sottrae l'operando ad A
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     SBCINXNODNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
SBCINXNODNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      SBCINXNODNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
SBCINXNODNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta i flags N e C
                XOR     AH,01H               ;Complementa il flag C
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.

;Routine di sottrazione BCD
SBCINXDEC:      INC     CH                   ;In modo decimale SBC richiede
                                             ;un ciclo di clock in pió
                TEST    AH,01H               ;Pone C negato nel carry dell'80x86
                JNZ     SBCINXDECNOC         ;(TEST pone il carry a zero)
                STC
SBCINXDECNOC:   SBB     AL,BH                ;Sottrae l'operando ad A
                DAS                          ;Converte il risultato in BCD
                LAHF                         ;Copia i flags dell'80x86 in AH
                JNO     SBCINXDECNOO         ;Copia il flag O dell'80x86 nel
                OR      BL,40H               ;flag V del 65C12
SBCINXDECNOO:   TEST    AH,40H               ;Controlla il flag Z dell'80x86
                JZ      SBCINXDECNOZ         ;Copia il flag Z dell'80x86 nel
                OR      BL,02H               ;flag Z del 65C12
SBCINXDECNOZ:   AND     AH,81H               ;Maschera i flags N e C
                OR      AH,BL                ;Setta i flags N e C
                XOR     AH,01H               ;Complementa il flag C
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
;------------------------------------------------------------------------------;
INCINX:         MOV     BL,DL                ;Opcode FEH
                XOR     BH,BH                ;Fa puntare BX alla pagina 0
                ADD     BX,[WORD SI]         ;BX = X + indirizzo base operando
                INC     SI                   ;Incrementa il Program Counter
                INC     SI                   ;Incrementa il Program Counter
                MOV     CL,BL                ;Salva LSB indir. operando in CL
                CALL    READBLBX             ;Carica l'operando in memoria
                XCHG    BL,CL                ;Rimette operando in CL e LSB in BL
                INC     CL                   ;Incrementa l'operando
                JZ      INCINXISZERO         ;Setta i flags in accordo col
                JS      INCINXISNEG          ;risultato
                AND     AH,7DH               ;Z=0, N=0
                CALL    WRITEBXCL            ;Salva l'operando in memoria
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
INCINXISNEG:    AND     AH,7DH               ;Z=0, N=1
                OR      AH,80H
                CALL    WRITEBXCL            ;Salva l'operando in memoria
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
INCINXISZERO:   AND     AH,7DH               ;Z=1, N=0
                OR      AH,02H
                CALL    WRITEBXCL            ;Salva l'operando in memoria
                XOR     BH,BH                ;Azzera parte alta indice istr.
                JMP     NEWINS               ;Torna all'inizio del ciclo princ.
ENDP            EMU65C12

EXTRN           READ_IO:PROC                 ;In HARDWARE.ASM
;------------------------------------------------------------------------------;
;Questa procedura carica in BL il contenuto della locazione di memoria         ;
;puntata da BX all'interno dello spazio di indirizzamento del 65C12, tenendo   ;
;conto del tipo di memoria in questione (RAM, ROM, I/O). Dato che si tratta di ;
;un'operazione di lettura, la RAM e la ROM vengono trattate allo stesso modo,  ;
;mentre se la memoria ä di tipo I/O viene richiamata l'apposita subroutine.    ;
;                                                                              ;
;In ingresso: BX = Locazione di memoria dalla quale leggere                    ;
;In uscita:   BL = Valore letto dalla memoria                                  ;
;Registri utilizzati: Nessuno                                                  ;
;Subroutines richiamate: READ_IO                                               ;
;------------------------------------------------------------------------------;
PROC            READBLBX
                PUSH    BX                   ;Salva l'indirizzo da leggere
                MOV     BL,BH                ;Crea un puntatore alla tabella
                XOR     BH,BH                ;di utilizzazione della memoria
                CMP     [BYTE CS:MEMORY_TABLE+BX],02H ;La pagina selezionata
                JE      RDBLBXIO             ;ä di I/O?
                POP     BX                   ;Se no, legge normalmente la
                MOV     BL,[BYTE BX]         ;locazione di memoria
                RET
RDBLBXIO:       POP     BX                   ;Se sç, richiama la subroutine
                CALL    READ_IO              ;di lettura I/O
                RET
ENDP            READBLBX

EXTRN           WRITE_IO:PROC                ;In HARDWARE.ASM
;------------------------------------------------------------------------------;
;Questa procedura salva il contenuto di CL nella locazione di memoria puntata  ;
;da BX all'interno dello spazio di indirizzamento del 65C12, tenendo conto del ;
;tipo di memoria in questione (RAM, ROM, I/O).                                 ;
;                                                                              ;
;In ingresso: BX = Locazione di memoria in cui scrivere                        ;
;             CL = Valore da scrivere nella memoria                            ;
;Registri utilizzati: Nessuno                                                  ;
;Subroutines richiamate: WRITE_IO                                              ;
;------------------------------------------------------------------------------;
PROC            WRITEBXCL
                PUSH    BX                   ;Salva l'indirizzo in cui scrivere
                MOV     BL,BH                ;Crea un puntatore alla tabella
                XOR     BH,BH                ;di utilizzazione della memoria
                MOV     BL,[BYTE CS:MEMORY_TABLE+BX]
                CMP     BL,00H               ;La pagina selezionata ä una RAM?
                JE      WRBXCLRAM
                CMP     BL,01H               ;La pagina selezionata ä una ROM?
                JE      WRBXCLROM
                POP     BX                   ;E' memoria I/O, usa la subroutine
                CALL    WRITE_IO             ;di scrittura I/O
                RET
WRBXCLRAM:      POP     BX                   ;E' una RAM, scrive normalmente
                MOV     [BYTE BX],CL         ;nella locazione di memoria
                RET
WRBXCLROM:      POP     BX                   ;E' memoria ROM, non fa nulla
                RET
ENDP            WRITEBXCL

;˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛;
; AREA DATI NEL CS PER L'EMULAZIONE DELLE ISTRUZIONI                           ;
;˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛˛;
PUBLIC          INSTRTABLE
PUBLIC          MEMORY_TABLE
PUBLIC          IRQ
PUBLIC          NMI
;------------------------------------------------------------------------------;
;Tabella degli indirizzi del codice di emulazione dei codici operativi         ;
;------------------------------------------------------------------------------;
INSTRTABLE:     DW      OFFSET BRKIMP,OFFSET ORAIPR,OFFSET NOPZPG,OFFSET NOPIMP
                DW      OFFSET TSBZPG,OFFSET ORAZPG,OFFSET ASLZPG,OFFSET NOPIMP
                DW      OFFSET PHPIMP,OFFSET ORAIMM,OFFSET ASLACC,OFFSET NOPIMP
                DW      OFFSET TSBABS,OFFSET ORAABS,OFFSET ASLABS,OFFSET NOPIMP
;Opcode 10H
                DW      OFFSET BPLREL,OFFSET ORAIPO,OFFSET ORAIZP,OFFSET NOPIMP
                DW      OFFSET TRBZPG,OFFSET ORAIZX,OFFSET ASLIZX,OFFSET NOPIMP
                DW      OFFSET CLCIMP,OFFSET ORAINY,OFFSET INCACC,OFFSET NOPIMP
                DW      OFFSET TRBABS,OFFSET ORAINX,OFFSET ASLINX,OFFSET NOPIMP
;Opcode 20H
                DW      OFFSET JSRABS,OFFSET ANDIPR,OFFSET NOPZPG,OFFSET NOPIMP
                DW      OFFSET BITZPG,OFFSET ANDZPG,OFFSET ROLZPG,OFFSET NOPIMP
                DW      OFFSET PLPIMP,OFFSET ANDIMM,OFFSET ROLACC,OFFSET NOPIMP
                DW      OFFSET BITABS,OFFSET ANDABS,OFFSET ROLABS,OFFSET NOPIMP
;Opcode 30H
                DW      OFFSET BMIREL,OFFSET ANDIPO,OFFSET ANDIZP,OFFSET NOPIMP
                DW      OFFSET BITIZX,OFFSET ANDIZX,OFFSET ROLIZX,OFFSET NOPIMP
                DW      OFFSET SECIMP,OFFSET ANDINY,OFFSET DECACC,OFFSET NOPIMP
                DW      OFFSET BITINX,OFFSET ANDINX,OFFSET ROLINX,OFFSET NOPIMP
;Opcode 40H
                DW      OFFSET RTIIMP,OFFSET EORIPR,OFFSET NOPZPG,OFFSET NOPIMP
                DW      OFFSET NOPZPG,OFFSET EORZPG,OFFSET LSRZPG,OFFSET NOPIMP
                DW      OFFSET PHAIMP,OFFSET EORIMM,OFFSET LSRACC,OFFSET NOPIMP
                DW      OFFSET JMPABS,OFFSET EORABS,OFFSET LSRABS,OFFSET NOPIMP
;Opcode 50H
                DW      OFFSET BVCREL,OFFSET EORIPO,OFFSET EORIZP,OFFSET NOPIMP
                DW      OFFSET NOPZPG,OFFSET EORIZX,OFFSET LSRIZX,OFFSET NOPIMP
                DW      OFFSET CLIIMP,OFFSET EORINY,OFFSET PHYIMP,OFFSET NOPIMP
                DW      OFFSET NOPABS,OFFSET EORINX,OFFSET LSRINX,OFFSET NOPIMP
;Opcode 60H
                DW      OFFSET RTSIMP,OFFSET ADCIPR,OFFSET NOPZPG,OFFSET NOPIMP
                DW      OFFSET STZZPG,OFFSET ADCZPG,OFFSET RORZPG,OFFSET NOPIMP
                DW      OFFSET PLAIMP,OFFSET ADCIMM,OFFSET RORACC,OFFSET NOPIMP
                DW      OFFSET JMPIND,OFFSET ADCABS,OFFSET RORABS,OFFSET NOPIMP
;Opcode 70H
                DW      OFFSET BVSREL,OFFSET ADCIPO,OFFSET ADCIZP,OFFSET NOPIMP
                DW      OFFSET STZIZX,OFFSET ADCIZX,OFFSET RORIZX,OFFSET NOPIMP
                DW      OFFSET SEIIMP,OFFSET ADCINY,OFFSET PLYIMP,OFFSET NOPIMP
                DW      OFFSET JMPIPA,OFFSET ADCINX,OFFSET RORINX,OFFSET NOPIMP
;Opcode 80H
                DW      OFFSET BRAREL,OFFSET STAIPR,OFFSET NOPZPG,OFFSET NOPIMP
                DW      OFFSET STYZPG,OFFSET STAZPG,OFFSET STXZPG,OFFSET NOPIMP
                DW      OFFSET DEYIMP,OFFSET BITIMM,OFFSET TXAIMP,OFFSET NOPIMP
                DW      OFFSET STYABS,OFFSET STAABS,OFFSET STXABS,OFFSET NOPIMP
;Opcode 90H
                DW      OFFSET BCCREL,OFFSET STAIPO,OFFSET STAIZP,OFFSET NOPIMP
                DW      OFFSET STYIZX,OFFSET STAIZX,OFFSET STXIZY,OFFSET NOPIMP
                DW      OFFSET TYAIMP,OFFSET STAINY,OFFSET TXSIMP,OFFSET NOPIMP
                DW      OFFSET STZABS,OFFSET STAINX,OFFSET STZINX,OFFSET NOPIMP
;Opcode A0H
                DW      OFFSET LDYIMM,OFFSET LDAIPR,OFFSET LDXIMM,OFFSET NOPIMP
                DW      OFFSET LDYZPG,OFFSET LDAZPG,OFFSET LDXZPG,OFFSET NOPIMP
                DW      OFFSET TAYIMP,OFFSET LDAIMM,OFFSET TAXIMP,OFFSET NOPIMP
                DW      OFFSET LDYABS,OFFSET LDAABS,OFFSET LDXABS,OFFSET NOPIMP
;Opcode B0H
                DW      OFFSET BCSREL,OFFSET LDAIPO,OFFSET LDAIZP,OFFSET NOPIMP
                DW      OFFSET LDYIZX,OFFSET LDAIZX,OFFSET LDXIZY,OFFSET NOPIMP
                DW      OFFSET CLVIMP,OFFSET LDAINY,OFFSET TSXIMP,OFFSET NOPIMP
                DW      OFFSET LDYINX,OFFSET LDAINX,OFFSET LDXINY,OFFSET NOPIMP
;Opcode C0H
                DW      OFFSET CPYIMM,OFFSET CMPIPR,OFFSET NOPZPG,OFFSET NOPIMP
                DW      OFFSET CPYZPG,OFFSET CMPZPG,OFFSET DECZPG,OFFSET NOPIMP
                DW      OFFSET INYIMP,OFFSET CMPIMM,OFFSET DEXIMP,OFFSET NOPIMP
                DW      OFFSET CPYABS,OFFSET CMPABS,OFFSET DECABS,OFFSET NOPIMP
;Opcode D0H
                DW      OFFSET BNEREL,OFFSET CMPIPO,OFFSET CMPIZP,OFFSET NOPIMP
                DW      OFFSET NOPZPG,OFFSET CMPIZX,OFFSET DECIZX,OFFSET NOPIMP
                DW      OFFSET CLDIMP,OFFSET CMPINY,OFFSET PHXIMP,OFFSET NOPIMP
                DW      OFFSET NOPABS,OFFSET CMPINX,OFFSET DECINX,OFFSET NOPIMP
;Opcode E0H
                DW      OFFSET CPXIMM,OFFSET SBCIPR,OFFSET NOPZPG,OFFSET NOPIMP
                DW      OFFSET CPXZPG,OFFSET SBCZPG,OFFSET INCZPG,OFFSET NOPIMP
                DW      OFFSET INXIMP,OFFSET SBCIMM,OFFSET NOPIMP,OFFSET NOPIMP
                DW      OFFSET CPXABS,OFFSET SBCABS,OFFSET INCABS,OFFSET NOPIMP
;Opcode F0H
                DW      OFFSET BEQREL,OFFSET SBCIPO,OFFSET SBCIZP,OFFSET NOPIMP
                DW      OFFSET NOPZPG,OFFSET SBCIZX,OFFSET INCIZX,OFFSET NOPIMP
                DW      OFFSET SEDIMP,OFFSET SBCINY,OFFSET PLXIMP,OFFSET NOPIMP
                DW      OFFSET NOPABS,OFFSET SBCINX,OFFSET INCINX,OFFSET NOPIMP
;------------------------------------------------------------------------------;
;Tabella di utilizzazione della memoria - ogni byte di questa tabella          ;
;identifica il tipo di memoria associata ad una pagina (256 bytes) dello spazio;
;di indirizzamento: 00H = RAM, 01H = ROM, 02H = I/O.                           ;
;------------------------------------------------------------------------------;
MEMORY_TABLE    DB      256 DUP(0)

IRQ             DB      0                    ;<>0 se IRQ in corso

NMI             DB      0                    ;<>0 se NMI in corso

ENDS            CSEG

SEGMENT         MSEG    PUBLIC
                DB      65536 DUP(?)
ENDS            MSEG

END
