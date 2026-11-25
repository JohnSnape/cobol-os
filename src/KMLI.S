* KMLI.S  the dispatcher.  First in the kernel's
* code at $E000.
*
* KMLI is what the entry stub at $BF99 calls, with
* the language card switched in, bank 1, read and
* write.  It finds the call, checks the parameter
* count, runs the handler and returns the error in
* A (0 = none).  The stub does the rest.
*
* THE CALLER'S RETURN ADDRESS
* A call is   JSR MLI / DFB number / DA parms.
* Two JSRs deep (the caller's to $BF00, the stub's
* to here), the stack holds, from the top:
*   $0101,X / $0102,X  the stub's return
*   $0103,X / $0104,X  the CALLER'S return, which
*                      points at the last byte of
*                      the caller's JSR - so +1 is
*                      the call number, +2/+3 the
*                      parameter pointer
* KMLI reads the three bytes through it and then
* adds three to it IN PLACE, so the stub's final
* RTS lands past them.  The stub never has to know.
*
* THE PARAMETER COUNT
* Every ProDOS parameter block starts with its own
* count, and ProDOS refuses a call whose count is
* wrong ($04) before doing anything.  KCTAB and
* KPCTAB give each call its number and count;
* KHTAB its handler.
*
* A HANDLER returns A = 0 or an error.  It may use
* every register, KT0-KT6 and the kernel's data;
* KMLI restores the caller's Y, and the stub X.

* ---- the call tables ----------------------------
* One row per call: number, parameter count,
* handler.  Each stage adds rows here and nothing
* else changes.  The tables come FIRST in the
* kernel: Merlin 8 wants both KNCALL and the
* JMP (KHTAB,X) pointer defined before the code
* that uses them.
*   stage 1: READ_BLOCK, ON_LINE, SET_PREFIX,
*            GET_PREFIX
*   stage 2: OPEN, NEWLINE, READ, CLOSE,
*            SET_MARK, GET_MARK, GET_EOF,
*            GET_FILE_INFO
*   stage 3: WRITE, SET_EOF, CREATE, DESTROY,
*            RENAME, WRITE_BLOCK
*   stage 4: QUIT
KNCALL EQU 19
KCTAB DFB $80,$C5,$C6,$C7
 DFB $C8,$C9,$CA,$CC
 DFB $CE,$CF,$D1,$C4
 DFB $CB,$D0,$C0,$C1
 DFB $C2,$81,$65
KPCTAB DFB $03,$02,$01,$01
 DFB $03,$03,$04,$01
 DFB $02,$02,$02,$0A
 DFB $04,$02,$07,$01
 DFB $02,$03,$04
KHTAB DA KRDBLK,KONLIN,KSETPF,KGETPF
 DA KOPEN,KNEWLN,KREAD,KCLOSE
 DA KSTMRK,KGTMRK,KGTEOF,KGFI
 DA KWRITE,KSTEOF,KCREAT,KDESTR
 DA KRENAM,KWRBLK,KQUIT

KMLI STY KSAVY
 TSX
 LDA $0103,X
 STA KPTR
 LDA $0104,X
 STA KPTR+1
 CLC
 LDA $0103,X
 ADC #$03
 STA $0103,X
 LDA $0104,X
 ADC #$00
 STA $0104,X
 LDY #$01
 LDA (KPTR),Y
 STA KCALL
 INY
 LDA (KPTR),Y
 STA KPRM
 INY
 LDA (KPTR),Y
 STA KPRM+1
* ---- which call? --------------------------------
 LDX #KNCALL-1
KM1 LDA KCTAB,X
 CMP KCALL
 BEQ KM2
 DEX
 BPL KM1
 LDA #EBADCL
 BRA KMX
KM2 LDA (KPRM)
 CMP KPCTAB,X
 BEQ KM3
 LDA #EBADCT
 BRA KMX
KM3 TXA
 ASL
 TAX
 JSR KM4
* ---- the bitmap back to disk, and forgotten ----
* (KBMAP.S says why).  The handler's error wins; a
* failed write-back is reported only if the call
* itself succeeded.
KMX PHA
 JSR KBMFL
 BCS KMX1
 PLA
 BRA KMX2
KMX1 TAX
 PLA
 BNE KMX2
 TXA
KMX2 STZ KBMVAL
 LDY KSAVY
 RTS
KM4 JMP (KHTAB,X)

