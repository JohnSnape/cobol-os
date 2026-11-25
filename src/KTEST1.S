* KTEST1.S  the stage-1 test.  PUT by COBOLOS.S
* after INSTALL, which jumps to KTEST once the
* kernel is in.  DESIGN.md section 10, stage 1.
*
* It talks to the screen through the monitor (COUT,
* 40 columns), which also proves the ROM is back
* after every call: if the stub left the card in,
* COUT would be whatever the kernel has at $FDED.
*
* WHAT IT PRINTS
*   the device list ($BF31, $BF32-)
*   ON_LINE for every drive: unit, then the volume
*     name or ERR and the code
*   the prefix the kernel set at boot
*   the table tests, five to a line: "nn:rr" with
*     the test's number and what came back; a "*"
*     after one that came back wrong
*   block 2 of the boot drive, 32 bytes
*   the X/Y, flag and ROM checks
*   >>> STAGE 1 PASS, or >>> STAGE 1 FAIL nn
*
* THE TABLE (TTAB), four bytes a test:
*   the call number, the parameter block, and the
*   error expected back.  Call $00 is not an MLI
*   call: it compares the prefix with the string
*   its "parameter block" points at, $00 = same.
* The tests run in order and the prefix carries
* from one to the next, so the order matters.
*
* It needs the test disk: volume /COBOL with a
* directory OBJ and a file COBOL.SYSTEM in the
* root, which is what COBOL32.po holds.

* TBUF: 512 bytes for ON_LINE (up to 14 x 16),
* GET_PREFIX and READ_BLOCK.  $1000 is clear of
* this file, the boot block's buffers and KBLK.
TBUF EQU $1000

KTEST JSR HOME
 STZ TFAIL
 LDA #<TMHEAD
 LDX #>TMHEAD
 JSR TPRS
* ---- the device list ----------------------------
 LDA #<TMDEV
 LDX #>TMDEV
 JSR TPRS
 LDA DEVCNT
 JSR PRBYTE
* DEVCNT is the count minus one, so X runs while
* X <= DEVCNT
 LDX #$00
TL1 TXA
 CMP DEVCNT
 BEQ TL2
 BCS TL3
TL2 LDA #$A0
 JSR COUT
 LDA DEVLST,X
 JSR PRBYTE
 INX
 CPX #14
 BCC TL1
TL3 JSR CROUT
* ---- ON_LINE, every drive -------------------------
 JSR MLI
 DFB $C5
 DA TPOL
 BCC TL4
 JSR TERR
TL4 LDA #<TBUF
 STA $06
 LDA #>TBUF
 STA $07
TL5 LDA ($06)
 BEQ TL9
 PHA
 LDA #$A0
 JSR COUT
 PLA
 PHA
 AND #$F0
 JSR PRBYTE
 LDA #$A0
 JSR COUT
 PLA
 AND #$0F
 BEQ TL7
 TAX
 LDY #$01
TL6 LDA ($06),Y
 ORA #$80
 JSR COUT
 INY
 DEX
 BNE TL6
 BRA TL8
TL7 LDA #<TMERR
 LDX #>TMERR
 JSR TPRS
 LDY #$01
 LDA ($06),Y
 JSR PRBYTE
TL8 JSR CROUT
 LDA $06
 CLC
 ADC #16
 STA $06
 BCC TL5
 INC $07
 BRA TL5
* ---- the prefix set at boot ---------------------
TL9 LDA #<TMPFX
 LDX #>TMPFX
 JSR TPRS
 JSR MLI
 DFB $C7
 DA TPGP
 BCC TL10
 JSR TERR
TL10 LDX TBUF
 BEQ TL12
 LDY #$01
TL11 LDA TBUF,Y
 ORA #$80
 JSR COUT
 INY
 DEX
 BNE TL11
TL12 JSR CROUT

* ---- the table ----------------------------------
 STZ TIDX
 STZ TCOL
TL13 LDY TIDX
 LDA TTAB,Y
 CMP #$FF
 BEQ TL20
 STA TCALL
 LDA TTAB+1,Y
 STA TPL
 LDA TTAB+2,Y
 STA TPL+1
 LDA TCALL
 BNE TL14
 JSR TPCMP
 BRA TL15
TL14 JSR MLI
TCALL DFB $00
TPL DA $0000
TL15 STA TGOT
* print "nn:rr"
 LDA TIDX
 LSR
 LSR
 CLC
 ADC #$01
 JSR PRBYTE
 LDA #$BA
 JSR COUT
 LDA TGOT
 JSR PRBYTE
 LDY TIDX
 LDA TGOT
 CMP TTAB+3,Y
 BEQ TL16
 INC TFAIL
 LDA #$AA
 BRA TL17
TL16 LDA #$A0
TL17 JSR COUT
 LDA #$A0
 JSR COUT
 INC TCOL
 LDA TCOL
 CMP #5
 BCC TL18
 STZ TCOL
 JSR CROUT
TL18 LDA TIDX
 CLC
 ADC #4
 STA TIDX
 BRA TL13
TL20 LDA TCOL
 BEQ TL21
 JSR CROUT

* ---- block 2 of the boot drive ------------------
TL21 LDA DEVNUM
 STA TPRB+1
 JSR MLI
 DFB $80
 DA TPRB
 BCC TL22
 JSR TERR
TL22 LDA #<TMBLK
 LDX #>TMBLK
 JSR TPRS
 LDX #$00
TL23 LDA TBUF,X
 JSR PRBYTE
 INX
 TXA
 AND #$0F
 BNE TL23
 JSR CROUT
 CPX #32
 BCC TL23
* the volume header's storage type must be $F
 LDA TBUF+4
 AND #$F0
 CMP #$F0
 BEQ TL24
 JSR TERR

* ---- X and Y come back, flags follow A ----------
* A good call: carry clear and Z set.  A bad call
* ($99): carry set, Z clear, A = $01.  X and Y
* must be what they were before both.
TL24 LDX #$5A
 LDY #$A5
 JSR MLI
 DFB $C7
 DA TPGP
 BCS TL25
 BNE TL25
 CPX #$5A
 BNE TL25
 CPY #$A5
 BNE TL25
 LDX #$3C
 LDY #$C3
 JSR MLI
 DFB $99
 DA TPGP
 BCC TL25
 BEQ TL25
 CMP #$01
 BNE TL25
 CPX #$3C
 BNE TL25
 CPY #$C3
 BEQ TL26
TL25 JSR TERR
* ---- the ROM is back ------------------------------
* $F800 is the monitor's PLOT, which starts with
* LSR A ($4A).  The kernel's card has something
* else there, or nothing.
TL26 LDA $F800
 CMP #$4A
 BEQ TL27
 JSR TERR
TL27 LDA #<TMRES
 LDX #>TMRES
 JSR TPRS
 LDA TFAIL
 BNE TL28
 LDA #<TMPASS
 LDX #>TMPASS
 JSR TPRS
 BRA TL29
TL28 LDA #<TMFAIL
 LDX #>TMFAIL
 JSR TPRS
 LDA TFAIL
 JSR PRBYTE
TL29 JSR CROUT
KTHANG BRA KTHANG

* ==== helpers ====================================
* TERR: count a failure and mark it on screen
TERR INC TFAIL
 LDA #$A1
 JMP COUT

* TPRS: print the $00-ended string at A (low),
* X (high)
TPRS STA $08
 STX $09
 LDY #$00
TPR1 LDA ($08),Y
 BEQ TPR2
 ORA #$80
 JSR COUT
 INY
 BNE TPR1
TPR2 RTS

* TPCMP: GET_PREFIX, then compare it with the
* length-first string at TPL.  A = 0 if the same.
TPCMP JSR MLI
 DFB $C7
 DA TPGP
 LDA TPL
 STA $08
 LDA TPL+1
 STA $09
 LDA TBUF
 CMP ($08)
 BNE TPC2
 TAY
 BEQ TPC3
TPC1 LDA TBUF,Y
 CMP ($08),Y
 BNE TPC2
 DEY
 BNE TPC1
TPC3 LDA #$00
 RTS
TPC2 LDA #$FF
 RTS

* ==== the tests ==================================
* call, parameter block, expected
TTAB DFB $C6
 DA TPSP1
 DFB $45
 DFB $C6
 DA TPSP2
 DFB $40
 DFB $C6
 DA TPSP3
 DFB $40
 DFB $C6
 DA TPSP4
 DFB $44
 DFB $C6
 DA TPSP5
 DFB $46
 DFB $C6
 DA TPSP6
 DFB $4B
 DFB $C6
 DA TPSP7
 DFB $00
 DFB $00
 DA TSOBJ
 DFB $00
 DFB $C6
 DA TPSP8
 DFB $46
 DFB $C6
 DA TPSP9
 DFB $40
 DFB $C6
 DA TPSPA
 DFB $40
 DFB $C6
 DA TPSPB
 DFB $00
 DFB $00
 DA TSNONE
 DFB $00
 DFB $C6
 DA TPSPC
 DFB $40
 DFB $C6
 DA TPSPD
 DFB $00
 DFB $00
 DA TSVOL
 DFB $00
 DFB $80
 DA TPRB2
 DFB $28
 DFB $C5
 DA TPOL2
 DFB $28
 DFB $99
 DA TPGP
 DFB $01
 DFB $80
 DA TPRB3
 DFB $04
 DFB $FF

* ---- the parameter blocks -----------------------
* ON_LINE, every drive, into TBUF
TPOL DFB $02,$00
 DA TBUF
* ON_LINE, slot 3 drive 1: no such drive
TPOL2 DFB $02,$30
 DA TBUF
* GET_PREFIX into TBUF
TPGP DFB $01
 DA TBUF
* READ_BLOCK, the boot drive (unit set at run
* time), block 2, into TBUF
TPRB DFB $03,$00
 DA TBUF
 DA $0002
* READ_BLOCK, slot 3: no such drive
TPRB2 DFB $03,$30
 DA TBUF
 DA $0002
* READ_BLOCK with a count of 2: refused
TPRB3 DFB $02,$70
 DA TBUF
 DA $0002
* SET_PREFIX, one path each
TPSP1 DFB $01
 DA TS1
TPSP2 DFB $01
 DA TS2
TPSP3 DFB $01
 DA TS3
TPSP4 DFB $01
 DA TS4
TPSP5 DFB $01
 DA TS5
TPSP6 DFB $01
 DA TS6
TPSP7 DFB $01
 DA TS7
TPSP8 DFB $01
 DA TS8
TPSP9 DFB $01
 DA TS9
TPSPA DFB $01
 DA TSA
TPSPB DFB $01
 DA TSB
TPSPC DFB $01
 DA TSC
TPSPD DFB $01
 DA TSD

* ---- the paths ----------------------------------
* 01 no such volume: $45
TS1 DFB 7
 ASC '/NOSUCH'
* 02 a partial name starting with a digit: $40
TS2 DFB 4
 ASC '9BAD'
* 03 "/" alone: $40
TS3 DFB 1
 ASC '/'
* 04 a missing directory on the way: $44
TS4 DFB 13
 ASC '/COBOL/NOPE/X'
* 05 a missing last name: $46
TS5 DFB 11
 ASC '/COBOL/NOPE'
* 06 a file, not a directory: $4B
TS6 DFB 19
 ASC '/COBOL/COBOL.SYSTEM'
* 07 lower case, trailing slash: "/cobol/obj/"
* (hex, so no editor can change the case)
TS7 DFB 11
 DFB $2F,$63,$6F,$62,$6F,$6C
 DFB $2F,$6F,$62,$6A,$2F
* 08 the prefix is now /COBOL/OBJ/
TSOBJ DFB 11
 ASC '/COBOL/OBJ/'
* 09 a partial path under it, missing: $46
TS8 DFB 4
 ASC 'NOPE'
* 10 a name of 16 characters: $40
TS9 DFB 23
 ASC '/COBOL/ABCDEFGHIJKLMNOP'
* 11 a character no name may hold: $40
TSA DFB 10
 ASC '/COBOL/A*B'
* 12 an empty path clears the prefix
TSB DFB 0
* 13 so the prefix is empty
TSNONE DFB 0
* 14 and a partial path is now $40
TSC DFB 3
 ASC 'OBJ'
* 15 the volume alone, no trailing slash
TSD DFB 6
 ASC '/COBOL'
* 16 the prefix is /COBOL/ again
TSVOL DFB 7
 ASC '/COBOL/'
* 17 READ_BLOCK slot 3: $28
* 18 ON_LINE slot 3: $28
* 19 call $99: $01
* 20 READ_BLOCK, count 2: $04

* ---- messages -----------------------------------
TMHEAD ASC 'COBOL.OS STAGE 1'
 DFB $8D,$00
TMDEV ASC 'DEVICES '
 DFB $00
TMERR ASC 'ERR '
 DFB $00
TMPFX ASC 'PREFIX '
 DFB $00
TMBLK ASC 'BLOCK 2:'
 DFB $8D,$00
TMRES ASC '>>> STAGE 1 '
 DFB $00
TMPASS ASC 'PASS'
 DFB $00
TMFAIL ASC 'FAIL '
 DFB $00

* ---- variables ----------------------------------
TFAIL DFB $00
TIDX DFB $00
TCOL DFB $00
TGOT DFB $00
