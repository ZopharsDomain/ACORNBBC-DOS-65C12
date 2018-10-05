                    -------------------------------------
                     6 5 C 1 2   E M U L A T O R   1 . 1
                    -------------------------------------


1. Description
2. Disclaimer
3. Use of 65C12 Emulator
4. Adding more hardware
5. Technical notes
6. History
7. Contacting the author


 1. DESCRIPTION
----------------

  65C12 Emulator is a DOS-based program that emulates the 65C12 microprocessor.
It is supplied with a simple text-mode user interface that enables the user to
control the many features it offers and with some simple programs to test its
functionality.
65C12 Emulator comes with full source code and can easily be modified; please
let me know if you modify it.
I wrote this program for my Electronic Calculators exam at University; this
version differs from the exam one in that the user interface has been translated
into English, and for some bugfixes.
The interface is rather simple and essential because it is only intended for
the user to see how the program works. In fact, the emulator is primarily
intended to be a "first stone" to build an emulated microcomputer system on.
The user may easily add emulated hardware to the emulator, and the user
interface can be eliminated to allow the program to start in emulation mode, or
modified to add new functions.
Currently this program is the heart of my Acorn Master Compact emulator, and
since it works correctly I think there are no more bugs in the instruction
emulation section.
If you find bugs, please contact me (see section 7).


 2. DISCLAIMER
---------------

  65C12 EMULATOR is freeware. The author of 65C12 EMULATOR hereby grants
unlimited license to freely copy and install it for any use. 65C12 EMULATOR is
supplied as-is; the author WILL NOT be held responsible for ANY damages that may
occur as a direct or indirect result of using 65C12 EMULATOR.
The author will not be held responsible for damages resulting from the loss of
business or productivity due to the use of 65C12 EMULATOR.
You are encouraged to use, distribute and modify 65C12 EMULATOR, although if you
modify it you must let the author know via e-mail or ordinary mail (see the
address at the end of this document).


 3. USE OF 65C12 EMULATOR
--------------------------

  Use of 65C12 Emulator is simple. After a presentation screen, the program
displays the main menu. A function in the main menu is selected by pressing
the appropriate key among the ones listed below. The program will display
appropriate messages at the bottom of the screen.
Here is a list and a brief explanation of the available options.
 
 R: Read memory zone from file
The emulated processor can access a 64 KB memory area, that is initially set to
all zeroes. This function allows the user to load programs or data into memory.
The user must enter the starting address to load the file at (in hexadecimal
format) and the name of the file to load. If the file is too long (that is if
start address + file length > 65535) it will be partially loaded.

 W: Write memory zone to file
This function allows the user to save a zone of the 64 KB emulated memory.
Just enter the starting and ending addresses of the zone to be saved (in
hexadecimal format) and the name of the file to be created.

 A: Assign memory type by pages
The user can define RAM, ROM and memory-mapped I/O zones among the 64 KB area
of processor memory, by blocks of 256 bytes (pages). Note that pages 0 and 1
(zero page and stack page) must be RAM memory, and cannot be changed.

 M: Modify interrupt vectors
The 65C12 uses three vectors in page &FF to know where to jump on certain
events: NMI (&FFFA), RESET (&FFFC) and IRQ (&FFFE).
This function allows the user to easily modify the vectors without having to
load a file in processor memory. Just enter the new vectors in hexadecimal
format. Default vectors are set by the emulator at &0200.

 B: BRK executes normally/terminates the emulation
The B key toggles the way the emulator handles the BRK instruction. It can be
executed normally (thus generating a software interrupt) or it can be used to
terminate the emulation.

 I: Instruction timing ON/OFF
This function controls the timing of instructions. If timing is off, the
emulator just runs at maximum speed. With timing enabled, the emulator tries to
execute instructions at the speed a real 65C12 would execute them. Note that a
80486sx-25 runs the emulator approximately three or four times faster than a
real 2 MHz 65C12: thereby, with today's computers there should'nt be any problem
in running the emulator at full speed.
For more information about how timing is performed, see the technical notes
below.

 C: Clock rate = 2 MHz/1 MHz
This function allows the user to select between two clock rates. Note that this
setting has no meaning if instruction timing is disabled (see above).

 L: Log file ON/OFF
The emulator can create a 65C12EM.LOG file containing the history of executed
instructions and the values of the registers for every instruction. This
function allows the user to enable or disable the log file feature.
Note that with today's computers it's impossible to achieve full speed with log
file on (it requires a disk transfer rate greater than 20 MB/s!)
Maybe we'll see in the future... :)

 S: Start emulation
This function starts the instruction emulation. The emulated processor will
start executing the instruction in the memory location pointed by the RESET
vector (&FFFC). Emulation can be stopped by pressing the ESC key or by executing
a BRK instruction if the exit-on-BRK feature is enabled (see above).

 E: Exit program
The E key lets the user return back to DOS.

I have included a few ready-to-use test programs (PROG?.PRG); they can be loaded
into memory and executed. Read the source code files (PROG?.ASM) for further
information.


 4. ADDING MORE HARDWARE
-------------------------

  As stated above, 65C12 Emulator is mainly intended to be expanded by adding
emulated hardware.
Since the 65C12 has got no I/O ports, the attached hardware must be memory
mapped. Any reads or writes that occur in memory locations defined for memory
mapped I/O are redirected to the routines READ_IO and WRITE_IO in the
HARDWARE.ASM file. At present no hardware device is emulated, so the above
routines do nothing.
Thus, in order to add hardware to the 65C12 you have to:

 a)Correctly initialize the MEMORY-TABLE in 65C12.ASM to reflect the memory-map
   you want to emulate;
 b)Eventually add a simple routine to load ROM code and do other initializations
   on startup;
 c)Write your own routines to emulate the attached hardware;
 d)Correctly set the TIMER_ON and F_CLOCK variables in TIMER.ASM  in order to
   have a precise timing;
 e)Eliminate the user interface from MAIN.ASM, or modify it to add the functions
   your implementation requires.

To carry on tasks that happen in background (e.g. events that are not triggered
by a read or write to or from a memory-mapped I/O location, like video refresh,
timers, etc.) you can add some code starting from line 127 of 65C12.ASM; your
code will be executed on every 128 emulated clock ticks.

IRQs and NMIs can be stated by incrementing the variables IRQ and NMI; these
variables must be decremented when the processor acknowledges the interrupts by
reading or writing certain memory-mapped I/O locations, depending on the
hardware device that requested the interrupt.

You may have noticed that I translated the user interface into English but not
the comments in the ASM code, that are still in Italian; well, it would take me
too much time to do that, and after all most labels are in English and the code
is quite self-explanatory... I hope :->. If you have any problems don't hesitate
to contact me (see below), I'll be very happy to help you.
Also, if you use and modify 65C12 Emulator, let me know.


 5. TECHNICAL NOTES
--------------------

  TIMING - The timing is carried out using channel 2 of the PIT (Programmable
Interval Timer) that runs at 1.19318 MHz; the WAIT_TIMER routine in TIMER.ASM
waits for 128 emulated cycles (that is 64 microseconds for 2 MHz clock and 128
for a 1 MHz clock) to elapse since last time it was called; so it must be called
at least every 128 emulated cycles to supply a good timing.
The emulator executes 128 cycles of the 65C12 and then it calls the WAIT_TIMER
routine; i.e. it does not time every instruction correctly, but it does a timing
that is correct in average for a large amount of instructions. This way the
emulator can do a very good timing and reach at the same time a very high speed
of execution. Of course, for this to work, the emulation of 128 cycles must be
faster than the real 65C12, to allow the WAIT_TIMER routine to be called before
128 clock ticks.
To achieve even more precision the timing routine works in a Bresenham-like way,
that allows for a very precise fine-tuning of the timer.

  SPEED - To allow for a faster emulation, the emulated 65C12 differs from the
real one in some ways:

 - Stack overflows and underflows are not revealed; the stack will overwrite
   pages 0 and 2.

 - Additional cycles are not added in case of page boundary crossing.

 - In the following situations, memory type (RAM, ROM, I/O) is not taken in
   account, and memory is treated as RAM:
   - Access to stack or page 0; in this way efficiency is improved (istructions
     that access the stack or zero page are executed very fast) without a great
     functionality loss (it is a nonsense to put ROM or I/O in pages 0 and 1).
   - Instruction and operand fetch at the PC address.                                                                   ;
   - Loading of the address to jump to during execution of opcodes 6CH (absolute
     indirect JMP) and 7CH (absolute pre-indexed indirect JMP).

65C12 Emulator is fully written is 8086 real-mode Assembly language; it was
compiled under TASM 3.0 Ideal mode.

Feel free to contact me for further information or more detailed explanations
about how my emulator works.


 6. HISTORY
------------

  Version 1.0 - 29 September 1998
First publicly available release.

  Version 1.1 - 04 November 1998
Corrected a bug that caused a zero bytes length file to be created when saving
the whole 64KB memory; cleaned up the documentation.


 7. CONTACTING THE AUTHOR
--------------------------

  For any problems, bug reports, or for notifying any changes you made to 65C12
Emulator, feel free to contact me by e-mail or ordinary mail (the former is
preferable):

conca@neworldfl.com

Carlo Concari
Loc. Parola, 115
43030 Fontanellato (PR)
Italy
