;*****************************************************************************
;
; Program Name: KrowCalc
;
; Author: Kevin Wing
;
; Date: 04/27/2021
;
; Revision: 1.0
;
; Description:
;   A console programmer calculator with Decimal, Hexadecimal, Binary and Octal input modes.
;
;   Allowed input:
;       input mode operator: d = decimal, b = binary, h = hexadecimal
;       menu options: c = clear screen, q = quit
;       numerical input: 0 -> 9 + a -> f, mode dependent
;       precedence operators: ()
;       arithmetic operators: +, -, *, /, %
;       bitwise operators: ~, &, |, <, >
;
;   TRAPS:
;       OpOr     ; x40
;       OpAnd    ; x41
;       OpAdd    ; x42
;       OpSub    ; x43
;       OpMult   ; x44
;       OpDiv    ; x45
;       OpNot    ; x47
;
;****************************************************************************/

                .ORIG       x3000

                ; #3 = input pointer
                ; #2 = postfix pointer
                ; #1 = stack pointer
                ; #0 = ascii pointer
                JSR     Init                ; call init function

Calc            LD      R0, Input_Ptr
                LD      R1, MaxInputSize
                JSR     InitRange

                LD      R0, Postfix_Ptr
                LD      R1, MaxPostfixSize
                JSR     InitRange

                LD      R0, OpStack_Ptr
                LD      R1, MaxPostfixSize
                JSR     InitRange

                JSR     DisplayPrompt

        ; get input from user
                LD      R1, Input_Ptr      ; load input pointer
                JSR     Input

                LDR     R0, R1, #0         ; check for commands
                ; test for exit sentinel
                LD      R2, ExitChar
                ADD     R2, R0, R2
                BRz     Quit

                ; test for help command
                LD      R2, HelpChar
                ADD     R2, R0, R2
                BRz     display_help

                ; test for mode change
                LDR     R0, R1, #0
                JSR     TestModeChange
                ADD     R0, R0, #0
                BRp     Calc                ; return to start of loop if mode change detected

                JSR     ToPostfix

                JSR     Evaluate

                JSR     BtoA
                LEA     R0, ASCIIBUFF
                PUTS
                LD      R0, Newline
                OUT

                BRnzp   Calc

display_help    LD      R0, InstStrPtr
                PUTS
                BRnzp   Calc

Quit            HALT

;*****************************************************************************
; Pointers
;****************************************************************************/

TOS_PTR         .FILL       xF000           ; pointer to initial top of stack
SOH_PTR         .FILL       SOH

Input_Ptr       .FILL       InputBuffer     ; array to store input string
Postfix_Ptr     .FILL       PostfixArr      ; array to store converted postfix string
Operand_Ptr     .FILL       OperandStr      ; temporary storage of string operands before atoi conversion
OpStack_Ptr    .FILL       SOH             ; pointer to stack created on the heap

;*****************************************************************************
; Variables
;****************************************************************************/

PrevAns         .BLKW       #1              ; stored previous answer result
ModeVal         .BLKW       #1              ; location to store current input mode

MaxInputSize    .FILL       #50             ; max size of input
MaxPostfixSize  .FILL       #50             ; max size of evaluation stack
MaxStackSize    .FILL       #20             ; max size of operator stack

MaxBinLen       .FILL       #4
MaxDecLen       .FILL       #3
MaxHexLen       .FILL       #2

ExitChar        .FILL       xFF8F             ; letter 'q': exit sentinel
HelpChar        .FILL       xFF98             ; letter 'h': help command
; MemoryChar      .FILL       x6D             ; letter 'm': memory command

Newline         .FILL       x000A           ; ascii newline char
NewlineNeg      .FILL       xFFF6           ; negated ascii newline char

mode_d          .FILL       x44             ; ascii 'D'
mode_b          .FILL       x42             ; ascii 'B'
mode_x          .FILL       x58             ; ascii 'X'
; mode_o          .FILL       x4F             ; ascii 'O'

InstStrPtr      .FILL       Instructions    ; pointer to help/instructon string
ModeMrkrPtr     .FILL       ModeMarker      ; pointer to ModeMarker
ModeStrPtr      .FILL       ModeStr         ; pointer to ModeStr
PromptPtr       .FILL       Prompt          ; pointer to Prompt

;*****************************************************************************
; Subroutines
;****************************************************************************/

;
;  This algorithm takes the 2's complement representation of a signed
;  integer, within the range -999 to +999, and converts it into an ASCII
;  string consisting of a sign digit, followed by three decimal digits.
;  R0 contains the initial value being converted.
;
BtoA           ADD   R6, R6, #-1
               STR   R7, R6, #0

               LEA   R1, ASCIIBUFF  ; R1 points to string being generated
               ADD   R0,R0,#0      ; R0 contains the binary value
               BRn   NegSign       ;
               LD    R2,ASCIIplus  ; First store the ASCII plus sign
               STR   R2,R1,#0
               BRnzp Begin100
NegSign        LD    R2,ASCIIminus ; First store ASCII minus sign
               STR   R2,R1,#0
               NOT   R0,R0         ; Convert the number to absolute
               ADD   R0,R0,#1      ; value; it is easier to work with.
;
Begin100       LD    R2,ASCIIoffset ; Prepare for "hundreds" digit
;
               LD    R3,Neg100     ; Determine the hundreds digit
Loop100        ADD   R0,R0,R3
               BRn   End100
               ADD   R2,R2,#1
               BRnzp Loop100
;
End100         STR    R2,R1,#1   ; Store ASCII code for hundreds digit
               LD     R3,Pos100
               ADD    R0,R0,R3   ; Correct R0 for one-too-many subtracts
;
               LD     R2,ASCIIoffset ; Prepare for "tens" digit
;
Begin10        LD     R3,Neg10   ; Determine the tens digit
Loop10         ADD    R0,R0,R3
               BRn    End10
               ADD    R2,R2,#1
               BRnzp  Loop10
;
End10          STR    R2,R1,#2   ; Store ASCII code for tens digit
               ADD    R0,R0,#10  ; Correct R0 for one-too-many subtracts
Begin1         LD     R2,ASCIIoffset ; Prepare for "ones" digit
               ADD    R2,R2,R0
               STR    R2,R1,#3

               LDR    R7, R6, #0
               ADD    R6, R6, #1
               RET
;
ASCIIBUFF      .BLKW	5
ASCIIplus      .FILL  x002B
ASCIIminus     .FILL  x002D
ASCIIoffset    .FILL  x0030
Neg100         .FILL  xFF9C
Pos100         .FILL  x0064
Neg10          .FILL  xFFF6

;*****************************************************************************
;
; Function Name:   Init()
;
; Description:
;   Initialize program to starting values
;
; Entry Paramaters:
;   None
;
; Returns: Initialized stack pointer in R6
;
; Register Usage:
;   R0: heap initialization value: 0
;   R1: heap pointer
;   R2: heap/stack collision comparison
;   R3: Not used
;   R4: Not used
;   R5: Not used
;   R6: stack pointer
;   R7: return address
;
; R0 - R5 are initialized to zero
; R6 is returned with initialized stack pointer
; R7 is preserved
;
;****************************************************************************/

        ; need array for input
        ; need array for postfix
        ; need stack for operands and evaluation
Init            LD      R6, TOS_PTR         ; initialize stack
                ; ADD     R6, R6, #-1         ; push R7
                ; STR     R7, R6, #0

                LD      R0, mode_d          ; set initial mode to decimal
                ST      R0, ModeVal

                ; initialize operations service routines
                LD      R1, TrapPtr

                LD      R0, OpOrPtr     ; x40
                STR     R0, R1, #0
                ADD     R1, R1, #1

                LD      R0, OpAndPtr    ; x41
                STR     R0, R1, #0
                ADD     R1, R1, #1

                LD      R0, OpAddPtr    ; x42
                STR     R0, R1, #0
                ADD     R1, R1, #1

                LD      R0, OpSubPtr    ; x43
                STR     R0, R1, #0
                ADD     R1, R1, #1

                LD      R0, OpMultPtr   ; x44
                STR     R0, R1, #0
                ADD     R1, R1, #1

                LD      R0, OpDivPtr    ; x45
                STR     R0, R1, #0
                ADD     R1, R1, #1

                LD      R0, OpNotPtr    ; x46
                STR     R0, R1, #0
                ADD     R1, R1, #1

                LD      R5, SOH_PTR         ; load start of heap

                ; create input buffer
                ADD     R6, R6, #-1         ; make room for array pointers
                STR     R5, R6, #0          ; push input buffer
                LD      R1, MaxInputSize    ; create array of MaxInputSize + 1
                ADD     R5, R5, R1
                ADD     R5, R5, #2          ; allow for null terminator and start of
                                            ; next data structure: null + next = 2

                ; create postfix buffer
                ADD     R6, R6, #-1         ; make room for array pointers
                STR     R5, R6, #0
                LD      R1, MaxPostfixSize  ; create array of MaxInputSize + 1
                ADD     R5, R5, R1
                ADD     R5, R5, #2          ; allow for null terminator

                ; create operator/eval stack
                ADD     R6, R6, #-1         ; make room for array pointers
                STR     R5, R6, #0
                LD      R1, MaxStackSize  ; create array of MaxInputSize + 1
                ADD     R5, R5, R1
                ADD     R5, R5, #2          ; allow for null terminator

                AND     R0, R0, #0          ; clear R0 - R5
                AND     R1, R1, #0
                AND     R2, R2, #0
                AND     R3, R3, #0
                AND     R4, R4, #0
                AND     R5, R5, #0

                ; LDR     R7, R6, #0      ; pop R7
                ; ADD     R6, R6, #1
                RET

TrapPtr         .FILL   x40

OpOrPtr         .FILL   OpOr
OpAndPtr        .FILL   OpAnd

OpAddPtr        .FILL   OpAdd
OpSubPtr        .FILL   OpSub

OpMultPtr       .FILL   OpMult
OpDivPtr        .FILL   OpDiv
; OpModPtr        .FILL   OpMod

OpNotPtr        .FILL   OpNot

;*****************************************************************************
;
; Function Name: InitRange(char *ptr)
;
; Description:
;   Initialize array elements to 0
;
; Entry Paramaters:
;   R0 = pointer to start of range
;   R1 = size of range to initialize
;
; Returns: void
;
; Register Usage:
;   R0: pointer to start of range
;   R1: size of range
;   R2: Not used
;   R3: Not used
;   R4: Not used
;   R5: Not used
;   R6: stack pointer
;   R7: return address
;
; All registers but R0 and R1 are preserved by this function
;
;****************************************************************************/

InitRange       ADD     R6, R6, #-1         ; push R7
                STR     R7, R6, #0
                ADD     R6, R6, #-1         ; push R2
                STR     R2, R6, #0
                ADD     R6, R6, #-1         ; push R3
                STR     R3, R6, #0
                ADD     R6, R6, #-1         ; push R4
                STR     R4, R6, #0
                ADD     R6, R6, #-1         ; push R5
                STR     R5, R6, #0

range_loop      AND     R2, R2, #0      ; set init value
                STR     R2, R0, #0
                ADD     R0, R0, #1
                ADD     R1, R1, #-1
                BRp     range_loop

                LDR     R5, R6, #0      ; pop R5
                ADD     R6, R6, #1
                LDR     R4, R6, #0      ; pop R4
                ADD     R6, R6, #1
                LDR     R3, R6, #0      ; pop R3
                ADD     R6, R6, #1
                LDR     R2, R6, #0      ; pop R2
                ADD     R6, R6, #1
                LDR     R7, R6, #0      ; pop R7
                ADD     R6, R6, $1
                RET

;*****************************************************************************
;
; Function Name:   DisplayPrompt()
;
; Description:
;   Check mode and display prompt to console
;
; Entry Paramaters:
;   None
;
; Returns: length of integer string in R0
;
; Register Usage:
;   R0: temporary heap pointer
;   R1: load heap/stack pointers comparison
;   R2: Not used
;   R3: Not used
;   R4: Not used
;   R5: Not used
;   R6: stack pointer
;   R7: return address
;
; All registers are preserved by this function
;
;****************************************************************************/

DisplayPrompt   ADD     R6, R6, #-1     ; push R7
                STR     R7, R6, #0
                ADD     R6, R6, #-1     ; push R0
                STR     R0, R6, #0
                ADD     R6, R6, #-1     ; push R1
                STR     R1, R6, #0
                ADD     R6, R6, #-1     ; push R2
                STR     R2, R6, #0

                LD      R0, ModeVal     ; load current mode

                LD      R1, mode_d      ; check if decimal mode
                NOT     R1, R1
                ADD     R1, R1, #1
                ADD     R2, R0, R1
                BRz     print_mode       ; no leading spaces, branch directly to print

                LD      R1, mode_b      ; check if binary mode
                NOT     R1, R1
                ADD     R1, R1, #1
                ADD     R2, R0, R1
                BRz     bin_mode

                LD      R1, mode_x      ; check if hex mode
                NOT     R1, R1
                ADD     R1, R1, #1
                ADD     R2, R0, R1
                BRz     hex_mode

;DecMode        BRnzp   print_mode

bin_mode        AND     R1, R1, #0      ; set number leading of spaces to 4
                ADD     R1, R1, #4
                BRnzp   print_spaces

hex_mode        AND     R1, R1, #0      ; set number of leading spaces to 8
                ADD     R1, R1, #8

print_spaces    LDI     R0, SpacePtr   ; print number of spaces defined in R1
                OUT
                ADD     R1, R1, #-1
                BRp     print_spaces

print_mode      LD      R0, ModeMrkrPtr ; print mode marker string
                PUTS
                LD      R0, ModeStrPtr  ; print mode string
                PUTS
                LD      R0, PromptPtr   ; print prompt string
                PUTS

                LDR     R2, R6, #0      ; pop R2
                ADD     R6, R6, #1
                LDR     R1, R6, #0      ; pop R1
                ADD     R6, R6, #1
                LDR     R0, R6, #0      ; pop R0
                ADD     R6, R6, #1
                LDR     R7, R6, #0      ; pop R7
                ADD     R6, R6, #1
                RET

SpacePtr        .FILL   BlankSpace

;*****************************************************************************
;
; Function Name: input()
;
; Description:
;   Get an integer input from user and store in ascii form starting at address from R0 input parameter
;
; Entry Paramaters:
;   R6 = stack pointer
;   R7 = return address
;
; Returns: void
;
; Register Usage:
;   R0: input and output
;   R1: contains buffer pointer
;   R2: contains comparison offset values
;   R3: used for comparison operation destination
;   R4: contains counter value
;   R5: not used
;   R6: stack pointer
;   R7: return address
;
; All registers are preserved by this function
;
;****************************************************************************/

Input           ADD     R6, R6, #-1         ; push R7
                STR     R7, R6, #0
                ADD     R6, R6, #-1         ; push R1   preserve starting pointer
                STR     R1, R6, #0
                ADD     R6, R6, #-1         ; push R2
                STR     R2, R6, #0
                ADD     R6, R6, #-1         ; push R3
                STR     R3, R6, #0
                ADD     R6, R6, #-1         ; push R4
                STR     R4, R6, #0

                ; LD      R1, InputBufferPtr  ; load address of input buffer
                LD      R2, NewlineNeg      ; test for newline character
                LD      R4, MaxInputSize    ; load max buffer size in R4

InpLoop         GETC                        ; get character from keyboard
                OUT                         ; echo character to console
                ADD     R3, R2, R0          ; test for newline
                BRz     EndInput            ; end input if newline

                STR     R0, R1, #0          ; insert character to buffer
                ADD     R1, R1, #1          ; increment buffer pointer
                ADD     R4, R4, #-1         ; decrement max loop count
                BRp     InpLoop             ; return invalid input

EndInput        AND     R0, R0, #0
                STR     R0, R1, #0          ; insert null terminator at end of string

                LDR     R4, R6, #0          ; pop R4
                ADD     R6, R6, #1
                LDR     R3, R6, #0          ; pop R3
                ADD     R6, R6, #1
                LDR     R2, R6, #0          ; pop R2
                ADD     R6, R6, #1
                LDR     R1, R6, #0          ; pop R1, starting pointer
                ADD     R6, R6, #1
                LDR     R7, R6, #0          ; pop R7
                ADD     R6, R6, #1
                RET

;*****************************************************************************
;
; Function Name: TestModeChange(char *ptr)
;
; Description:
;   Accept pointer to start of buffer and test first character for mode change.
;   Return 0 if mode is not set and 1 if mode is changed
;
; Entry Paramaters:
;   R0 = Starting address of buffer to store input
;
; Returns: 1 if mode set, 0 if not
;
; Register Usage:
;   R0: input parameter
;   R1: first character of input string
;   R2: mode character to compare
;   R3: Not used
;   R4: Not used
;   R5: not used
;   R6: stack pointer
;   R7: return address
;
; All registers but R0 are preserved by this function
;
;****************************************************************************/

TestModeChange  ADD     R6, R6, #-1     ; push R7
                STR     R7, R6, #0
                ADD     R6, R6, #-1     ; push R1
                STR     R1, R6, #0
                ADD     R6, R6, #-1     ; push R2
                STR     R2, R6, #0

                ; char ch = R0;
                ADD     R1, R0, #0
                ; result = false;
                AND     R0, R0, #0      ; set return to false

                ; if (ModeVal == ch) {result = true;}
                LD      R2, mode_d      ; test for decimal mode change
                NOT     R2, R2
                ADD     R2, R2, #1
                ADD     R2, R1, R2
                BRz     test_true

                ; else if (ModeVal == ch) {result = true;}
                LD      R2, mode_b      ; test for binary mode change
                NOT     R2, R2
                ADD     R2, R2, #1
                ADD     R2, R1, R2
                BRz     test_true

                ; else if (ModeVal == ch) {result = true;}
                LD      R2, mode_x      ; test for hex mode change
                NOT     R2, R2
                ADD     R2, R2, #1
                ADD     R2, R1, R2
                BRz     test_true

                ; else {result = false}
                BRnzp   test_mode_end     ; return false

                ; ModeVal = ch;
test_true       ST      R1, ModeVal     ; update ModeVal and return true
                ADD     R0, R0, #1

                ; return result;
test_mode_end   LDR     R2, R6, #0      ; pop R2
                ADD     R6, R6, #1
                LDR     R1, R6, #0      ; pop R1
                ADD     R6, R6, #1
                LDR     R7, R6, #0      ; pop R7
                ADD     R6, R6, #1
                RET

;*****************************************************************************
;
; Function Name: Evaluate
;
; Description:
;   Convert infix expression to postFix expression and return 1 if valid expression
;   or 0 if invalid expression
;
; Entry Paramaters:
;   R0 = pointer to string buffer containing expression
;   R1 = pointer to postfix string array
;
; Returns: an infix string conveted to a postfix string
;
; Register Usage:
;   R0: current character/ results of subroutines
;   R1: current input string index
;   R2: comparison char/result of comparison
;   R3: temporary storage
;   R4: temporary storage
;   R5: operator stack pointer
;   R6: stack pointer
;   R7: return address
;
; All registers but R0 are preserved by this function
;
;****************************************************************************/

Evaluate        ADD     R6, R6, #-1     ; push R7
                STR     R7, R6, #0
                ADD     R6, R6, #-1     ; push R1
                STR     R1, R6, #0
                ADD     R6, R6, #-1     ; push R2
                STR     R2, R6, #0
                ADD     R6, R6, #-1     ; push R3
                STR     R3, R6, #0
                ADD     R6, R6, #-1     ; push R4
                STR     R4, R6, #0
                ADD     R6, R6, #-1     ; push R5
                STR     R5, R6, #0

                LD      R0, stkPtr      ; clear stack
                LD      R1, MaxSizePtr
                JSR     InitRange

                LD      R5, stkPtr
                LD      R4, PfPtr

eval_loop       LDR     R1, R4, #0
                BRz     eval_ret
                ; if char is operand, push to stack
                ADD     R0, R1, #0
                JSR     IsOperator
                ADD     R0, R0, #0
                BRp     eval_operator
                ADD     R5, R5, #1      ; push operand to stack
                STR     R1, R5, #0
                BRnzp   eval_cont

eval_operator   LDI     R2, PlusPtr
                ADD     R2, R2, R1
                BRz     eval_add

                LDI     R2, MinusPtr
                ADD     R2, R2, R1
                BRz     eval_sub

                LDI     R2, MultPtr
                ADD     R2, R2, R1
                BRz     eval_mult

                LDI     R2, DivPtr
                ADD     R2, R2, R1
                BRz     eval_div

                LDI     R2, ModPtr
                ADD     R2, R2, R1
                BRz     eval_mod

                LDI     R2, AndPtr
                ADD     R2, R2, R1
                BRz     eval_and

                LDI     R2, OrPtr
                ADD     R2, R2, R1
                BRz     eval_or

                LDI     R2, NotPtr
                ADD     R2, R2, R1
                BRz     eval_not


                ; pop appropriate operands
                ; perform calculation
eval_add        LDR     R1, R5, #0      ; pop R3
                ADD     R5, R5, #-1
                LDR     R0, R5, #0      ; pop R2
                ADD     R5, R5, #-1
                TRAP    x42
                ADD     R5, R5, #1
                STR     R0, R5, #0
                BRnzp   eval_cont

eval_sub        LDR     R1, R5, #0      ; pop R3
                ADD     R5, R5, #-1
                LDR     R0, R5, #0      ; pop R2
                ADD     R5, R5, #-1
                TRAP    x43
                ADD     R5, R5, #1
                STR     R0, R5, #0
                BRnzp   eval_cont

eval_mult       LDR     R1, R5, #0      ; pop R3
                ADD     R5, R5, #-1
                LDR     R0, R5, #0      ; pop R2
                ADD     R5, R5, #-1
                TRAP    x44
                ADD     R5, R5, #1
                STR     R0, R5, #0
                BRnzp   eval_cont

eval_div        LDR     R1, R5, #0      ; pop R3
                ADD     R5, R5, #-1
                LDR     R0, R5, #0      ; pop R2
                ADD     R5, R5, #-1
                TRAP    x45
                ADD     R5, R5, #1
                STR     R0, R5, #0
                BRnzp   eval_cont

eval_mod        LDR     R1, R5, #0      ; pop R3
                ADD     R5, R5, #-1
                LDR     R0, R5, #0      ; pop R2
                ADD     R5, R5, #-1
                TRAP    x45
                ADD     R5, R5, #1
                STR     R1, R5, #0
                BRnzp   eval_cont

eval_not        LDR     R0, R5, #0      ; pop R3
                ADD     R5, R5, #-1
                TRAP    x46
                ADD     R5, R5, #1
                STR     R0, R5, #0
                BRnzp   eval_cont

eval_and        LDR     R1, R5, #0      ; pop R3
                ADD     R5, R5, #-1
                LDR     R0, R5, #0      ; pop R2
                ADD     R5, R5, #-1
                TRAP    x41
                ADD     R5, R5, #1
                STR     R0, R5, #0
                BRnzp   eval_cont

eval_or         LDR     R1, R5, #0      ; pop R3
                ADD     R5, R5, #-1
                LDR     R0, R5, #0      ; pop R2
                ADD     R5, R5, #-1
                TRAP    x40
                ADD     R5, R5, #1
                STR     R0, R5, #0

eval_cont       ADD     R4, R4, #1
                BRnzp   eval_loop
                ; return result in R0

eval_ret        LDR     R0, R5, #0      ; load result in R0

                LDR     R5, R6, #0      ; pop R5
                ADD     R6, R6, #1
                LDR     R4, R6, #0      ; pop R4
                ADD     R6, R6, #1
                LDR     R3, R6, #0      ; pop R3
                ADD     R6, R6, #1
                LDR     R2, R6, #0      ; pop R2
                ADD     R6, R6, #1
                LDR     R1, R6, #0      ; pop R1
                ADD     R6, R6, #1
                LDR     R7, R6, #0      ; pop R7
                ADD     R6, R6, #1
                RET

PfPtr           .FILL   PostfixArr
stkPtr          .FILL   SOH
MaxSizePtr      .FILL   MaxStackSize
PlusPtr         .FILL   PlusSign
MinusPtr        .FILL   MinusSign
MultPtr         .FILL   MultSign
DivPtr          .FILL   DivSign
ModPtr          .FILL   ModSign
NotPtr          .FILL   NotSign
AndPtr          .FILL   AndSign
OrPtr           .FILL   OrSign

;*****************************************************************************
;
; Function Name: ToPostfix(char *ptr)
;
; Description:
;   Convert infix expression to postFix expression and return 1 if valid expression
;   or 0 if invalid expression
;
; Entry Paramaters:
;   R0 = pointer to string buffer containing expression
;   R1 = pointer to postfix string array
;
; Returns: an infix string conveted to a postfix string
;
; Register Usage:
;   R0: current character/ results of subroutines
;   R1: current input string index
;   R2: comparison char/result of comparison
;   R3: temporary storage
;   R4: temporary storage
;   R5: operator stack pointer
;   R6: stack pointer
;   R7: return address
;
; All registers but R0 are preserved by this function
;
;****************************************************************************/

ToPostfix           ADD     R6, R6, #-1     ; push R7
                    STR     R7, R6, #0
                    ADD     R6, R6, #-1     ; push R2
                    STR     R2, R6, #0
                    ADD     R6, R6, #-1     ; push R3
                    STR     R3, R6, #0
                    ADD     R6, R6, #-1     ; push R4
                    STR     R4, R6, #0
                    ADD     R6, R6, #-1     ; push R5
                    STR     R5, R6, #0

            ; initialize operator stack
                    LD      R5, OpStackPtr      ; initialize stack pointer
                    LD      R1, InputBufferPtr
                    LD      R2, PostfixArrPtr

                    ; If operand, push to stack
start_loop          LDR     R0, R1, #0
                    BRz     pf_end              ; check for null terminator

                    LD      R3, BlankSpace      ; if char is space loop again
                    NOT     R3, R3
                    ADD     R3, R3, #1
                    ADD     R3, R3, R0
                    BRz     cont_loop

                    LDR     R0, R1, #0
                    JSR     IsOperand           ; check if char is operand
                    ADD     R0, R0, #0
                    BRz     check_operator      ; if not, check if operator

                    ; ADD     R6, R6, #1      ; push current pointer position
                    ; STR     R1, R6, #0
                    LDR     R0, R1, #0
                    JSR     GetOperand
                    BRnzp   append_operand

                    ; If operator, test for empty stack or left paren at top of operator stack
check_operator      LDR     R0, R1, #0      ; load char
                    JSR     IsOperator
                    ADD     R0, R0, #0
                    BRz     check_open

                    ADD     R4, R0, #0      ; store precedence in temp

                    LDR     R0, R5, #0      ; load and test for empty stack
                    BRz     push_operator

                    LD      R3, LeftParen   ; test for left paren at top of stack
                    ADD     R3, R3, R0
                    BRz     push_operator

                    ; If the incoming symbol has higher precedence than the top of the stack, push it on the stack.
higher_prec         LDR     R0, R5, #0      ; get precedence for top of stack
                    JSR     IsOperator
                    NOT     R3, R0          ; negate R0 into R3
                    ADD     R3, R3, #1
                    ADD     R3, R3, R4
                    BRp     push_operator   ; higher precedence
                    BRn     lower_prec      ; lower precedence

                    ; If the incoming symbol has equal precedence with the top of the stack, use association.
                    ;   If the association is left to right, pop and print the top of the stack and then push
                    ;   the incoming operator. If the association is right to left, push the incoming operator.
equal_prec          LDR     R0, R5, #0      ; pop top of stack and push incoming operator
                    ADD     R5, R5, #-1
                    STR     R0, R2, #0      ; append top of stack to postfix array
                    ADD     R2, R2, #1
                    ; push incoming operator to stack
                    BRnzp   push_operator

                    ; If the incoming symbol has lower precedence than the symbol on the top of the stack, pop the stack and print the top operator.
                    ;   Then test the incoming operator against the new top of stack.
lower_prec          LDR     R0, R5, #0      ; pop top, check for empty stack
                    ADD     R5, R5, #-1
                    ADD     R0, R0, #0
                    BRz     stack_empty

                    STR     R0, R2, #0      ; append to postfix array
                    ADD     R2, R2, #1

                    JSR     IsOperator      ; compare precedence with new top, if incoming is still lower, continue popping
                    NOT     R3, R0
                    ADD     R3, R3, #1
                    ADD     R3, R3, R4
                    BRn     lower_prec

                    BRnzp   push_operator   ; finally, push incoming operator to stack

                    ; If the incoming symbol is a left parenthesis, push it on the stack.
check_open          LDR     R0, R1, #0
                    LD      R3, LeftParen
                    ADD     R3, R3, R0
                    BRz     push_operator

                    ; If the incoming symbol is a right parenthesis, pop the stack and print the operators until you see a left parenthesis. Discard the pair of parentheses.
check_close         LDR     R0, R1, #0
                    LD      R3, RightParen
                    ADD     R3, R3, R0
                    BRz     pop_till_open

                    ; At the end of the expression, pop and print all operators on the stack. (No parentheses should remain.)

pop_till_open       LDR     R0, R5, #0      ; pop top of stack
                    ADD     R5, R5, #-1
                    ADD     R0, R0, #0      ; test for empty stack
                    BRz     stack_empty

                    LD      R3, LeftParen   ; if left paren, break;
                    ADD     R3, R3, R0
                    BRz     cont_loop

                    STR     R0, R2, #0      ; append to postfix string
                    ADD     R2, R2, #1      ; increment postfix pointer
                    BRnzp   pop_till_open

stack_empty         ADD     R5, R5, #1      ; fix stack underflow
                    BRnzp   cont_loop

push_operator       LDR     R0, R1, #0
                    ADD     R5, R5, #1
                    STR     R0, R5, #0
                    BRnzp   cont_loop

append_operand      STR     R0, R2, #0
                    ADD     R2, R2, #1
                    BRnzp   cont_loop

append_operator     LDR     R0, R1, #0
                    STR     R0, R2, #0
                    ADD     R2, R2, #1

cont_loop           ADD     R1, R1, #1
                    BRnzp   start_loop

                    ; pop remaining operators from stack
pf_end              LDR     R0, R5, #0      ; read top
                    ADD     R5, R5, #-1     ; pop from stack
                    ADD     R0, R0, #0
                    BRz     pf_ret
                    STR     R0, R2, #0
                    ADD     R2, R2, #1
                    BRnzp   pf_end

pf_ret              AND     R0, R0, #0      ; append null to string
                    STR     R0, R2, #0
                    LDR     R5, R6, #0      ; pop R5
                    ADD     R6, R6, #1
                    LDR     R4, R6, #0      ; pop R4
                    ADD     R6, R6, #1
                    LDR     R3, R6, #0      ; pop R3
                    ADD     R6, R6, #1
                    LDR     R2, R6, #0      ; pop R2
                    ADD     R6, R6, #1
                    LDR     R7, R6, #0      ; pop R7
                    ADD     R6, R6, #1
                    RET


; grouping operators
LeftParen           .FILL   xFFD8 ; '('
RightParen          .FILL   xFFAD ; ')'
; arithmetic operators
PlusSign        .FILL   xFFD5     ; '+'
MinusSign       .FILL   xFFD3     ; '-'
MultSign        .FILL   xFFD6     ; '*'
DivSign         .FILL   xFFD1     ; '/'
ModSign         .FILL   xFFDB     ; '%' modulus
; bitwise operators
NotSign         .FILL   xFF82     ; '~' bitwise NOT
AndSign         .FILL   xFFDA     ; '&' bitwise AND
OrSign          .FILL   xFF84     ; '|' bitwise OR

; space char
BlankSpace      .FILL   x20   ; negated space

; previous result operator
; AnsChar         .FILL   x6D     ; 'm' will be replaced with value stored in PrevAns

InputBufferPtr  .FILL       InputBuffer     ; array to store input string
PostfixArrPtr   .FILL       PostfixArr      ; array to store converted postfix string
OperandStrPtr   .FILL       OperandStr      ; temporary storage of string operands before atoi conversion
OpStackPtr      .FILL       SOH             ; pointer to stack created on the heap

;*****************************************************************************
;
; Function Name: GetOperand()
;
; Description:
;   get operand
;
; Entry Paramaters:
;   R1 = pointer to start of operand range
;
; Returns: 1 if digit, 0 if not
;
; Register Usage:
;   R0: return value
;   R1: character being checked
;   R2: Not used
;   R3: Not used
;   R4: Not used
;   R5: Not used
;   R6: stack pointer
;   R7: return address
;
; All registers but R0, R1, R5 are preserved by this function
;
;****************************************************************************/

GetOperand      ADD     R6, R6, #-1     ; push R7
                STR     R7, R6, #0
                ADD     R6, R6, #-1     ; push R2
                STR     R2, R6, #0
                ADD     R6, R6, #-1     ; push R3
                STR     R3, R6, #0
                ADD     R6, R6, #-1     ; push R4
                STR     R4, R6, #0

                LEA     R4, AsciiDigits
                AND     R2, R2, #0          ; R2 is number of characters in operand
                AND     R3, R3, #0
                ADD     R3, R3, #4          ; max operand string length

                ; read digits until non-digit
get_loop        LDR     R0, R1, #0
                JSR     IsOperand
                ADD     R0, R0, #0
                BRz     get_cont
                LDR     R0, R1, #0
                ADD     R2, R2, #1      ; increment count

                STR     R0, R4, #0      ; append digit
                ADD     R4, R4, #1      ; advance pointers
                ADD     R1, R1, #1
                BRnzp   get_loop

get_cont        ADD     R1, R1, #-1     ; back off pointer to last char in input

                AND     R0, R0, #0      ; append null to operand string
                STR     R0, R4, #0

                ADD     R6, R6, #-1     ; preserve current input pointer
                STR     R1, R6, #0
                ADD     R6, R6, #-1     ; preserve length
                STR     R2, R6, #0

                LDI     R0, Mode_Val_Ptr
                LDI     R1, mode_d_ptr
                NOT     R1, R1
                ADD     R1, R1, #1
                ADD     R1, R1, R0
                BRz     get_dec

                LDI     R1, mode_b_ptr
                NOT     R1, R1
                ADD     R1, R1, #1
                ADD     R1, R1, R0
                BRz     get_bin

                LDI     R1, mode_x_ptr
                NOT     R1, R1
                ADD     R1, R1, #1
                ADD     R1, R1, R0
                BRz     get_hex

get_dec         ADD     R1, R2, #0      ; move count to R1 as arg
                LEA     R2, AsciiDigits
                JSR     DtoI            ; convert to binary
                BRnzp   get_end

get_bin         ADD     R1, R2, #0      ; move count to R1 as arg
                LEA     R2, AsciiDigits
                JSR     BtoI            ; convert to binary
                BRnzp   get_end

get_hex         ADD     R1, R2, #0      ; move count to R1 as arg
                LEA     R2, AsciiDigits
                JSR     XtoI            ; convert to binary


get_end         LDR     R2, R6, #0      ; pop length
                ADD     R6, R6, #1
                LDR     R1, R6, #0      ; pop input pointer
                ADD     R6, R6, #1

                LDR     R4, R6, #0      ; pop R4
                ADD     R6, R6, #1
                LDR     R3, R6, #0      ; pop R3
                ADD     R6, R6, #1
                LDR     R2, R6, #0      ; pop R2
                ADD     R6, R6, #1
                LDR     R7, R6, #0      ; pop R7
                ADD     R6, R6, #1
                RET

AsciiDigits     .BLKW   #5

;*****************************************************************************
;
; Function Name: IsOperand
;
; Description:
;   check if character is a valid digit from 0-9, return 1 if true and 0 if not
;
; Entry Paramaters:
;   R1 = character to check
;
; Returns: 1 if digit, 0 if not
;
; Register Usage:
;   R0: return value
;   R1: character being checked
;   R2: Not used
;   R3: Not used
;   R4: Not used
;   R5: Not used
;   R6: stack pointer
;   R7: return address
;
; All registers but R0 are preserved by this function
;
;****************************************************************************/

IsOperand           ADD     R6, R6, #-1     ; push R7
                    STR     R7, R6, #0
                    ADD     R6, R6, #-1     ; push R1
                    STR     R1, R6, #0
                    ADD     R6, R6, #-1     ; push R2
                    STR     R2, R6, #0

                    ; read mode value and perform mode based operand checking
                    LDI     R2, Mode_Val_Ptr

                    LDI     R1, mode_d_ptr
                    NOT     R1, R1
                    ADD     R1, R1, #1
                    ADD     R1, R1, R2
                    BRz     check_dec

                    LDI     R1, mode_b_ptr
                    NOT     R1, R1
                    ADD     R1, R1, #1
                    ADD     R1, R1, R2
                    BRz     check_bin

                    LDI     R1, mode_x_ptr
                    NOT     R1, R1
                    ADD     R1, R1, #1
                    ADD     R1, R1, R2
                    BRz     check_hex

check_dec           JSR     IsDec
                    BRnzp   is_operand_end

check_bin           JSR     IsBin
                    BRnzp   is_operand_end

check_hex           JSR     IsHex

is_operand_end      LDR     R2, R6, #0      ; pop R2
                    ADD     R6, R6, #1
                    LDR     R1, R6, #0      ; pop R1
                    ADD     R6, R6, #1
                    LDR     R7, R6, #0      ; pop R7
                    ADD     R6, R6, #1
                    RET

; DigitLower          .FILL   x30     ; '0' char
; DigitUpper          .FILL   x39     ; '9' char

Mode_Val_Ptr        .FILL   ModeVal
mode_d_ptr          .FILL   mode_d
mode_b_ptr          .FILL   mode_b
mode_x_ptr          .FILL   mode_x

;*****************************************************************************
;
; Function Name: IsDec
;
; Description:
;   check if character is a valid digit from 0-9, return 1 if true and 0 if not
;
; Entry Paramaters:
;   R1 = character to check
;
; Returns: 1 if digit, 0 if not
;
; Register Usage:
;   R0: return value
;   R1: character being checked
;   R2: Not used
;   R3: Not used
;   R4: Not used
;   R5: Not used
;   R6: stack pointer
;   R7: return address
;
; All registers but R0 are preserved by this function
;
;****************************************************************************/

IsDec               ADD     R6, R6, #-1     ; push R7
                    STR     R7, R6, #0
                    ADD     R6, R6, #-1     ; push R1
                    STR     R1, R6, #0

                    LD      R1, DigitLower  ; check lower bound
                    ADD     R1, R1, R0
                    BRn     not_decimal

                    LD      R1, DigitUpper  ; check upper bound
                    ADD     R1, R1, R0
                    BRp     not_decimal

                    AND     R0, R0, #0      ; return 1
                    ADD     R0, R0, #1
                    BRnzp   is_dec_end

not_decimal         AND     R0, R0, #0      ; return 0

is_dec_end          LDR     R1, R6, #0      ; pop R1
                    ADD     R6, R6, #1
                    LDR     R7, R6, #0      ; pop R7
                    ADD     R6, R6, #1

                    RET

DigitLower          .FILL   xFFD0     ; '0' char
DigitUpper          .FILL   xFFC7    ; '9' char

;*****************************************************************************
;
; Function Name: IsBin
;
; Description:
;   Check if character is 1 or 0, return 1 if true, 0 if false
;
; Entry Paramaters:
;   R1 = character to check
;
; Returns: 1 if binary digit, 0 if not
;
; Register Usage:
;   R0: return value
;   R1: second operand/loop counter
;   R2: Not used
;   R3: Not used
;   R4: Not used
;   R5: Not used
;   R6: stack pointer
;   R7: return address
;
; All registers but R0 are preserved by this function
;
;****************************************************************************/

IsBin           ADD     R7, R6, #-1     ; push R7
                STR     R7, R6, #0
                ADD     R6, R6, #-1     ; push R1, preserve input character
                STR     R1, R6, #0
                ADD     R6, R6, #-1     ; push R2
                STR     R2, R6, #0

                AND     R0, R0, #0      ; set return value to false

                LD      R2, BinLower    ; load '0'
                ADD     R2, R2, R1      ; test for less than '0'
                BRn     is_bin_false

                LD      R2, BinUpper    ; load '1'
                ADD     R2, R2, R1      ; test for greater than '1'
                BRp     is_bin_false

                ADD     R0, R0, #1      ; return true

is_bin_false    LDR     R2, R6, #0      ; pop R2
                ADD     R6, R6, #1
                LDR     R1, R6, #0      ; pop R1
                ADD     R6, R6, #1
                LDR     R7, R6, #0      ; pop R7
                ADD     R6, R6, #1
                RET

BinLower        .FILL   xFFD0
BinUpper        .FILL	xFFFF

;*****************************************************************************
;
; Function Name: IsHex
;
; Description:
;   Check if character is 1 or 0, return 1 if true, 0 if false
;
; Entry Paramaters:
;   R1 = character to check
;
; Returns: 1 if binary digit, 0 if not
;
; Register Usage:
;   R0: return value
;   R1: second operand/loop counter
;   R2: Not used
;   R3: Not used
;   R4: Not used
;   R5: Not used
;   R6: stack pointer
;   R7: return address
;
; All registers but R0 are preserved by this function
;
;****************************************************************************/

IsHex           ADD     R7, R6, #-1     ; push R7
                STR     R7, R6, #0
                ADD     R6, R6, #-1     ; push R1, preserve input character
                STR     R1, R6, #0
                ADD     R6, R6, #-1     ; push R2
                STR     R2, R6, #0

                JSR     IsDec           ; will set true if 0-9
                ADD     R0, R0, #0
                BRz     is_hex_false

                ; return is already set to true so jump to
                ; false return if not hex alpha char
                LD      R2, HexLB
                ADD     R2, R1, R2
                BRn     is_hex_false

                LD      R2, HexUB
                ADD     R2, R2, R1
                BRp     is_hex_false

                BRnzp   is_hex_true

is_hex_false    AND     R0, R0, #0      ; set return value to false

is_hex_true     LDR     R2, R6, #0      ; pop R2
                ADD     R6, R6, #1
                LDR     R1, R6, #0      ; pop R1
                ADD     R6, R6, #1
                LDR     R7, R6, #0      ; pop R7
                ADD     R6, R6, #1
                RET

HexLB           .FILL   xFF9F     ; 'a'
HexUB           .FILL   xFF98     ; 'f'

;*****************************************************************************
;
; Precedence:
;   6: ~        ; r-l
;   5: *, /, %  ; l-r
;   4: +, -     ; l-r
;   3: <<, >>   ; l-r
;   2: &        ; l-r
;   1: |        ; l-r
IsOperator          ADD     R6, R6, #-1     ; push R7
                    STR     R7, R6, #0
                    ADD     R6, R6, #-1     ; push R1
                    STR     R1, R6, #0

                    LDI     R1, or_ptr      ; check modulus
                    ADD     R1, R0, R1
                    BRz     is_one

                    LDI     R1, and_ptr      ; check modulus
                    ADD     R1, R0, R1
                    BRz     is_two

                    LDI     R1, plus_ptr     ; check plus
                    ADD     R1, R0, R1
                    BRz     is_four

                    LDI     R1, minus_ptr    ; check minus
                    ADD     R1, R0, R1
                    BRz     is_four

                    LDI     R1, mult_ptr    ; check multiplication
                    ADD     R1, R0, R1
                    BRz     is_five

                    LDI     R1, div_ptr     ; check division
                    ADD     R1, R0, R1
                    BRz     is_five

                    LDI     R1, mod_ptr     ; check modulus
                    ADD     R1, R0, R1
                    BRz     is_five

                    LDI     R1, not_ptr     ; check modulus
                    ADD     R1, R0, R1
                    BRz     is_six

                    AND     R0, R0, #0      ; return 0 if not an operator
                    BRnzp   is_op_end

is_one              AND     R0, R0, #0      ; return 1 for plus/minus
                    ADD     R0, R0, #1
                    BRnzp   is_op_end

is_two              AND     R0, R0, #0      ; return 2 for mult/div/mod
                    ADD     R0, R0, #2
                    BRnzp   is_op_end

; is_three            AND     R0, R0, #0
;                     ADD     R0, R0, #3
;                     BRnzp   is_op_end

is_four             AND     R0, R0, #0
                    ADD     R0, R0, #4
                    BRnzp   is_op_end

is_five             AND     R0, R0, #0
                    ADD     R0, R0, #5
                    BRnzp   is_op_end

is_six              AND     R0, R0, #0
                    ADD     R0, R0, #6
                    BRnzp   is_op_end

is_op_end           LDR     R1, R6, #0      ; pop R1
                    ADD     R6, R6, #1
                    LDR     R7, R6, #0      ; pop R7
                    ADD     R6, R6, #1
                    RET

plus_ptr            .FILL   PlusSign
minus_ptr           .FILL   MinusSign
mult_ptr            .FILL   MultSign
div_ptr             .FILL   DivSign
mod_ptr             .FILL   ModSign

not_ptr             .FILL   NotSign
or_ptr              .FILL   OrSign
and_ptr             .FILL   AndSign

;*****************************************************************************
;
;  Function Name:   DtoB(char *n)
;
;  Description:
;	This algorithm takes an ASCII string of three decimal digits and
;	converts it into a binary number.  R0 is used to collect the result.
;	R1 keeps track of how many digits are left to process.  ASCIIBUFF
;	contains the most significant digit in the ASCII string.
;
;  Attribution:
;	Code is taken from "Introduction to Computing Systems, 2/e" by Yale N. Patt & Sanjay J. Patel
;
;
; Entry Paramaters:
;   R1 = number of digits in string
;   R2 = pointer to operand array
;
;  Returns: binary value of ascii integer string in R0
;
;  Register Usage:
;     R0 accumulator of converted value
;     R1 number of digits remaining
;     R2 buffer pointer
;     R3 ascii offset
;     R4 current digit
;     R5 lookup value
;     R6 Reserved for stack pointer
;     R7 Reserved for return address
;
;     All registers but R0, R1 are preserved by this function
;
;****************************************************************************/

DtoI            ADD     R6, R6, #-1     ; push R7
                STR     R7, R6, #0
                ; ADD     R6, R6, #-1     ; push R1
                ; STR     R1, R6, #0
                ADD     R6, R6, #-1     ; push R2
                STR     R2, R6, #0
                ADD     R6, R6, #-1     ; push R3
                STR     R3, R6, #0
                ADD     R6, R6, #-1     ; push R4
                STR     R4, R6, #0
                ADD     R6, R6, #-1     ; push R5
                STR     R5, R6, #0

                AND     R0, R0, #0      ; R0 will be used for our result
                ADD     R1, R1, #0      ; Test number of digits.
                BRz     dtoi_end        ; There are no digits

                LD      R3, AtoIoffset  ; R3 gets xFFD0, i.e., -x0030
                ADD     R2, R2, R1
                ADD     R2, R2, #-1     ; R2 now points to "ones" digit

                LDR     R4, R2, #0      ; R4 <-- "ones" digit
                ADD     R4, R4, R3      ; Strip off the ASCII template
                ADD     R0, R0, R4      ; Add ones contribution

                ADD     R1, R1, #-1
                BRz     dtoi_end        ; The original number had one digit
                ADD     R2, R2, #-1     ; R2  now points to "tens" digit

                LDR     R4, R2, #0      ; R4 <-- "tens" digit
                ADD     R4, R4,R3       ; Strip off ASCII  template
                LEA     R5, LookUp10    ; LookUp10 is BASE of tens values
                ADD     R5, R5, R4      ; R5 points to the right tens value
                LDR     R4, R5, #0
                ADD     R0, R0, R4      ; Add tens contribution to total

                ADD     R1, R1, #-1
                BRz     dtoi_end        ; The original number had two digits
                ADD     R2, R2, #-1     ; R2 now points to "hundreds" digit

                LDR     R4, R2, #0      ; R4 <-- "hundreds" digit
                ADD     R4, R4, R3      ; Strip off ASCII template
                LEA     R5, LookUp100   ; LookUp100 is hundreds BASE
                ADD     R5, R5, R4      ; R5 points to hundreds value
                LDR     R4, R5, #0
                ADD     R0, R0, R4      ; Add hundreds contribution to total

                ADD     R1, R1, #-1
                BRz     dtoi_end        ; The original number had three digits
                ADD     R2, R2, #-1     ; R2 now points to "thousands" digit

                LDR     R4, R2, #0      ; R4 <-- "thousands" digit
                ADD     R4, R4, R3      ; Strip off ASCII template
                LEA     R5, LookUp100   ; LookUp1000 is thousands BASE
                ADD     R5, R5, R4      ; R5 points to thousands value
                LDR     R4, R5, #0
                ADD     R0, R0, R4      ; Add thousands contribution to total

dtoi_end        LDR     R5, R6, #0      ; pop R5
                ADD     R6, R6, #1
                LDR     R4, R6, #0      ; pop R4
                ADD     R6, R6, #1
                LDR     R3, R6, #0      ; pop R3
                ADD     R6, R6, #1
                LDR     R2, R6, #0      ; pop R2
                ADD     R6, R6, #1
                ; LDR     R1, R6, #0      ; pop R1
                ; ADD     R6, R6, #1
                LDR     R7, R6, #0      ; pop R7
                ADD     R6, R6, #1
                RET

AtoIoffset      .FILL   xFFD0           ; ascii digit -> binary offset value
ItoAoffset      .FILL   x0030           ; binary digit -> ascii digit offset value

LookUp10       .FILL    #0
               .FILL    #10
               .FILL    #20
               .FILL    #30
               .FILL    #40
               .FILL    #50
               .FILL    #60
               .FILL    #70
               .FILL    #80
               .FILL    #90
;
LookUp100       .FILL    #0
                .FILL    #100
                .FILL    #200
                .FILL    #300
                .FILL    #400
                .FILL    #500
                .FILL    #600
                .FILL    #700
                .FILL    #800
                .FILL    #900

LookUp1000      .FILL   #0
                .FILL   #1000
                .FILL   #2000
                .FILL   #3000
                .FILL   #4000
                .FILL   #5000
                .FILL   #6000
                .FILL   #7000
                .FILL   #8000
                .FILL   #9000

;*****************************************************************************
;
; Function Name: BtoI
;
; Description:
;   Multiply op1 by op2 and return result in R0
;
; Entry Paramaters:
;   R4 = height of stack
;   R5 = pointer to top of operand stack
;
; Returns: product of the input operands
;
; Register Usage:
;   R0: result
;   R1: remaining digits
;   R2: pointer to ascii string
;   R3: Ascii offset
;   R4: temp storage
;   R5: multiplier value
;   R6: stack pointer
;   R7: return address
;
; All registers but R0 and R1 are preserved by this function
;
;****************************************************************************/

BtoI            ADD     R6, R6, #-1     ; push R7
                STR     R7, R6, #0
                ; ADD     R6, R6, #-1     ; push R1
                ; STR     R1, R6, #0
                ; ADD     R6, R6, #-1     ; push R2
                ; STR     R2, R6, #0
                ADD     R6, R6, #-1     ; push R3
                STR     R3, R6, #0
                ADD     R6, R6, #-1     ; push R4
                STR     R4, R6, #0
                ADD     R6, R6, #-1     ; push R5
                STR     R5, R6, #0

                AND     R0, R0, #0      ; R0 will be used for our result
                ADD     R1, R1, #0      ; Test number of digits.
                BRz     btoi_end        ; There are no digits

                ADD     R2, R2, R1
                ADD     R2, R2, #-1

                AND     R5, R5, #0      ; initialize multiplier to 1
                ADD     R5, R5, #1

                LD      R3, BinLower

bin_loop        LDR     R4, R2, #0
                ADD     R4, R4, R3
                BRz     loop_cont
                ADD     R0, R0, R5

loop_cont       ADD     R5, R5, R5
                ADD     R1, R1, #-1
                BRz     btoi_end
                ADD     R2, R2, #-1
                BRnzp   bin_loop

btoi_end        LDR     R5, R6, #0      ; pop R5
                ADD     R6, R6, #1
                LDR     R4, R6, #0      ; pop R4
                ADD     R6, R6, #1
                LDR     R3, R6, #0      ; pop R3
                ADD     R6, R6, #1
                ; LDR     R2, R6, #0      ; pop R2
                ; ADD     R6, R6, #1
                ; LDR     R1, R6, #0      ; pop R1
                ; ADD     R6, R6, #1
                LDR     R7, R6, #0      ; pop R7
                ADD     R6, R6, #1
                RET

AsciiDigitsPtr  .FILL   AsciiDigits

;*****************************************************************************
;
; Function Name: BtoI
;
; Description:
;   Multiply op1 by op2 and return result in R0
;
; Entry Paramaters:
;   R4 = height of stack
;   R5 = pointer to top of operand stack
;
; Returns: product of the input operands
;
; Register Usage:
;   R0: result
;   R1: remaining digits
;   R2: pointer to ascii string
;   R3: Ascii offset
;   R4: temp storage
;   R5: multiplier value
;   R6: stack pointer
;   R7: return address
;
; All registers but R0 and R1 are preserved by this function
;
;****************************************************************************/

XtoI            ADD     R6, R6, #-1     ; push R7
                STR     R7, R6, #0
                ; ADD     R6, R6, #-1     ; push R1
                ; STR     R1, R6, #0
                ; ADD     R6, R6, #-1     ; push R2
                ; STR     R2, R6, #0
                ADD     R6, R6, #-1     ; push R3
                STR     R3, R6, #0
                ADD     R6, R6, #-1     ; push R4
                STR     R4, R6, #0
                ADD     R6, R6, #-1     ; push R5
                STR     R5, R6, #0

                AND     R0, R0, #0      ; R0 will be used for our result
                ADD     R1, R1, #0      ; Test number of digits.
                BRz     xtoi_end        ; There are no digits

                LEA     R5, HexMultipliers
                ADD     R2, R2, R1
                ADD     R2, R2, #-1

hex_loop        LDR     R4, R2, #0

                LD      R3, DigitLB
                ADD     R3, R4, R3
                BRn     check_alpha

                LD      R3, DigitUB
                ADD     R3, R4, R3
                BRp     check_alpha

                LD      R3, AtoIoffset      ; strip ascii template
                ADD     R4, R4, R3

                ADD     R6, R6, #-1
                STR     R0, R6, #0
                ADD     R6, R6, #-1
                STR     R1, R6, #0

                ADD     R0, R4, #0      ; prepare operands for multiply
                LDR     R1, R5, #0

                JSR     OpMult          ; OpMult
                ADD     R4, R0, #0      ; move product to R4

                LDR     R1, R6, #0
                ADD     R6, R6, #1
                LDR     R0, R6, #0
                ADD     R6, R6, #1

                ADD     R0, R0, R4      ; add to result
                BRnzp   hex_cont

check_alpha     LD      R3, HexTemplate ; convert to decimal equivalent
                ADD     R4, R4, R3

                ADD     R6, R6, #-1
                STR     R0, R6, #0
                ADD     R6, R6, #-1
                STR     R1, R6, #0

                ADD     R0, R4, #0      ; prepare operands for multiply
                LDR     R1, R5, #0

                JSR     OpMult          ; OpMult
                ADD     R4, R0, #0      ; move product to R4

                LDR     R1, R6, #0
                ADD     R6, R6, #1
                LDR     R0, R6, #0
                ADD     R6, R6, #1

                ADD     R0, R0, R4      ; add to result

hex_cont        ADD     R2, R2, #-1
                ADD     R5, R5, #1      ; move to next multiplier
                ADD     R1, R1, #-1
                BRp     hex_loop

xtoi_end        LDR     R5, R6, #0      ; pop R5
                ADD     R6, R6, #1
                LDR     R4, R6, #0      ; pop R4
                ADD     R6, R6, #1
                LDR     R3, R6, #0      ; pop R3
                ADD     R6, R6, #1
                ; LDR     R2, R6, #0      ; pop R2
                ; ADD     R6, R6, #1
                ; LDR     R1, R6, #0      ; pop R1
                ; ADD     R6, R6, #1
                LDR     R7, R6, #0      ; pop R7
                ADD     R6, R6, #1
                RET

DigitLB         .FILL   xFFD0
DigitUB         .FILL   xFFC7
HexTemplate     .FILL   xFFCD   ; #-51

HexMultipliers  .FILL   #1
                .FILL   #16
                .FILL   #256
                .FILL   #4096

;*****************************************************************************
; Message strings
;****************************************************************************/
Instructions    .STRINGZ    "Commands: d = decimal mode, b = binary mode, h = hex mode h = help q = quit\nAllowed Symbols: +, -, *, /, %, (, )\nOperands: 0-9(Decimal), 0-1(Binary), 0-F(Hex), m(previous answer)"
ModeMarker      .STRINGZ    "___\n"
ModeStr         .STRINGZ    "DEC BIN HEX\nType h for help\n"
Prompt          .STRINGZ    "$> "

InputBuffer     .BLKW       #51     ; to hold input string
PostfixArr      .BLKW       #51     ; to store postfix string
OperandStr      .BLKW       #9      ; to hold operand string

;*****************************************************************************
; Service Routines
;****************************************************************************/

;*****************************************************************************
;
; Function Name: OpAnd()
;
; Description:
;   AND top 2 operands on stack and push result
;
; Entry Paramaters:
;   R5 = pointer to top of evaluation stack
;
; Returns: result of AND operation at top of stack
;
; Register Usage:
;   R0: left operand/ result
;   R1: right operand
;   R2: Not used
;   R3: Not used
;   R4: Not used
;   R5: Not used
;   R6: stack pointer
;   R7: return address
;
; All registers but R0 and are preserved by this function
;
;****************************************************************************/

OpAnd           ADD     R6, R6, #-1     ; push R7
                STR     R7, R6, #0

                AND     R0, R0, R1

                LDR     R7, R6, #0      ; pop R7
                ADD     R6, R6, #1
                RET

;*****************************************************************************
;
; Function Name: OpOr()
;
; Description:
;   Perform OR on top 2 operands
;
; Entry Paramaters:
;   R5 = pointer to top of evaluation stack
;
; Returns: result of OR operation to stack
;
; Register Usage:
;   R0: left operand/ result
;   R1: right operand
;   R2: Not used
;   R3: Not used
;   R4: Not used
;   R5: Not used
;   R6: stack pointer
;   R7: return address
;
; All registers but R0 and are preserved by this function
;
;****************************************************************************/

OpOr            ADD     R6, R6, #-1     ; push R7
                STR     R7, R6, #0

                NOT     R0, R0
                NOT     R1, R1
                AND     R0, R0, R1
                NOT     R0, R0

                LDR     R7, R6, #0      ; pop R7
                ADD     R6, R6, #1
                RET

;*****************************************************************************
;
; Function Name: OpNot()
;
; Description:
;   Add top 2 operands on stack and push result
;
; Entry Paramaters:
;   R5 = pointer to top of evaluation stack
;
; Returns: Complimented value at top of Stack
;
; Register Usage:
;   R0: left operand/ result
;   R1: right operand
;   R2: Not used
;   R3: Not used
;   R4: Not used
;   R5: Not used
;   R6: stack pointer
;   R7: return address
;
; All registers but R0 and are preserved by this function
;
;****************************************************************************/

OpNot           ADD     R6, R6, #-1     ; push R7
                STR     R7, R6, #0

                NOT     R0, R0

                LDR     R7, R6, #0      ; pop R7
                ADD     R6, R6, #1
                RET

;*****************************************************************************
;
; Function Name: OpAdd()
;
; Description:
;   Add top 2 operands on stack and push result
;
; Entry Paramaters:
;   R5 = pointer to top of evaluation stack
;
; Returns: product in R0
;
; Register Usage:
;   R0: left operand/ result
;   R1: right operand
;   R2: Not used
;   R3: Not used
;   R4: Not used
;   R5: Not used
;   R6: stack pointer
;   R7: return address
;
; All registers but R0 and are preserved by this function
;
;****************************************************************************/

OpAdd           ADD     R6, R6, #-1     ; push R7
                STR     R7, R6, #0

                ADD     R0, R0, R1

                LDR     R7, R6, #0      ; pop R7
                ADD     R6, R6, #1
                RET

;*****************************************************************************
;
; Function Name: OpSub()
;
; Description:
;   Subtract right operand from left operand
;
; Entry Paramaters:
;   R5 = pointer to top of evaluation stack
;
; Returns: result pushed to eval stack
;
; Register Usage:
;   R0: left operand/ result
;   R1: right operand
;   R2: Not used
;   R3: Not used
;   R4: Not used
;   R5: Not used
;   R6: stack pointer
;   R7: return address
;
; All registers but R0 and are preserved by this function
;
;****************************************************************************/

OpSub           ADD     R6, R6, #-1     ; push R7
                STR     R7, R6, #0
                ADD     R6, R6, #-1     ; push R1
                STR     R1, R6, #0

                NOT     R1, R1          ; negate subtrahend
                ADD     R1, R1, #1
                ADD     R0, R0, R1      ; perform addition

                LDR     R1, R6, #0      ; pop R1
                ADD     R6, R6, #1
                LDR     R7, R6, #0      ; pop R7
                ADD     R6, R6, #1
                RET

;*****************************************************************************
;
; Function Name: OpMult(int op1, int op2)
;
; Description:
;   Multiply op1 by op2 and return result in R0
;
; Entry Paramaters:
;   R5 = right operand
;
; Returns: product in R0
;
; Register Usage:
;   R0: result
;   R1: left operand/multiplicand
;   R2: right operand/multiplier
;   R3: sign of operand
;   R4: Not used
;   R5: Not used
;   R6: stack pointer
;   R7: return address
;
; All registers but R0 and R1 are preserved by this function
;
;****************************************************************************/

OpMult          ADD     R6, R6, #-1     ; push R7
                STR     R7, R6, #0
                ADD     R6, R6, #-1     ; push R2
                STR     R2, R6, #0

                ADD     R2, R1, #0
                ADD     R1, R0, #0

                AND     R0, R0, #0      ; clear R0 for result
                ADD     R2, R2, #0      ; check for 0 multiplier
                BRz     mult_end

mult_loop       ADD     R0, R0, R1      ; add multiplicand to product
                ADD     R2, R2, #-1     ; decrement
                BRp     mult_loop

mult_end        LDR     R2, R6, #0      ; pop R2
                ADD     R6, R6, #1
                LDR     R7, R6, #0      ; pop R7
                ADD     R6, R6, #1
                RET

;*****************************************************************************
;
; Function Name: OpDiv
;
; Description:
;   Divide R0 by R1
;
; Entry Paramaters:
;   R5 = pointer to top of evaluation stack
;
; Returns: quotient in R0 and remainder in R1
;
; Register Usage:
;   R0: quotient
;   R1: numerator/remainder
;   R2: denominator
;   R3: Not used
;   R4: Not used
;   R5: operand stack pointer
;   R6: stack pointer
;   R7: return address
;
; All registers but R0 and R1 are preserved by this function
;
;****************************************************************************/

OpDiv           ADD     R6, R6, #-1     ; push R7
                STR     R7, R6, #0
                ADD     R6, R6, #-1     ; push R2
                STR     R2, R6, #0

                ADD     R2, R1, #0
                ADD     R1, R0, #0

                ADD     R2, R2, #0      ; check for divide by zero
                BRz     div_by_zero
                NOT     R2, R2          ; negate denominator
                ADD     R2, R2, #1

                AND     R0, R0, #0      ; clear for result
div_loop        ADD     R1, R1, R2
                BRn     has_remainder
                BRz     div_end
                ADD     R0, R0, #1
                BRnzp   div_loop

has_remainder   NOT     R2, R2          ; adjust for 1 too many subracts
                ADD     R2, R2, #1
                ADD     R1, R1, R2
                ; ADD     R0, R0, #-1
                BRnzp   div_end

div_by_zero     LEA     R0, DivZeroMsg  ; if div by zero, exit program
                PUTS
                HALT

div_end         LDR     R2, R6, #0      ; pop R2
                ADD     R6, R6, #1
                LDR     R7, R6, #0      ; pop R7
                ADD     R6, R6, #1
                RET

;*****************************************************************************
;
; Function Name: OpMod
;
; Description:
;   Perform modulus operation on top 2 operands
;
; Entry Paramaters:
;   R5 = pointer to top of eval stack
;
; Returns: remainder at top of stack
;
; Register Usage:
;   R0: remainder
;   R1: denominator
;   R2: not used
;   R3: Not used
;   R4: Not used
;   R5: operand stack pointer
;   R6: stack pointer
;   R7: return address
;
; All registers but R0 and R1 are preserved by this function
;
;****************************************************************************/

; OpMod           ADD     R6, R6, #-1     ; push R7
;                 STR     R7, R6, #0
;                 ADD     R6, R6, #-1     ; push R1
;                 STR     R1, R6, #0

;                 LDR     R1, R5, #0      ; pop denominator
;                 ADD     R5, R5, #-1
;                 LDR     R0, R5, #0      ; pop numerator
;                 ADD     R5, R5, #-1

;                 ADD     R1, R1, #0      ; check for divide by zero
;                 BRz     mod_by_zero
;                 NOT     R1, R1          ; negate denominator
;                 ADD     R1, R1, #1

; mod_loop        ADD     R0, R0, R1
;                 BRp     mod_loop
;                 BRnz    check_mod

; check_mod       ADD     R0, R0, #0
;                 BRz     mod_end
;                 NOT     R1, R1
;                 ADD     R1, R1, #1
;                 ADD     R0, R0, R1
;                 BRnzp   mod_end

; mod_by_zero     LEA     R0, DivZeroMsg  ; if div by zero, exit program
;                 PUTS
;                 HALT

; mod_end         ADD     R5, R5, #1      ; push remainder
;                 STR     R0, R5, #0

;                 LDR     R1, R6, #0      ; pop R1
;                 ADD     R6, R6, #1
;                 LDR     R7, R6, #0      ; pop R7
;                 ADD     R6, R6, #1
;                 RET

DivZeroMsg      .STRINGZ    "Divide by zero exception\n";

;*****************************************************************************
; Start of Heap
;****************************************************************************/

SOH             .FILL   x0      ; will be used for the operand stack

                .END