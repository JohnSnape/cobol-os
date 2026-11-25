* TEST3.S  the stage-3 test: writing.
* Merlin 8, 65C02.  Like TEST2, an ordinary system
* program that uses only MLI calls, run as
* COBOL.SYSTEM on both test disks (mktest.ps1
* -Test TEST3): every expectation must hold on
* ProDOS 8 and on COBOL.OS.
*
* It makes files of every storage type by WRITE,
* reads them back, grows a file sparse, cuts a
* tree back with SET_EOF, renames, checks the
* access bits, grows a subdirectory, fills the
* volume directory to its 51 entries, and puts
* back a block with WRITE_BLOCK.  After every file
* it made is destroyed, the volume's blocks in use
* must be what they were at the start - the
* bitmap balances.
*
* Some answers are printed whole (GET_FILE_INFO's
* fifteen bytes) to compare the two systems by eye.
*
* AND IT LEAVES FILES BEHIND, for tools/emu to
* check on the PC with cp2: KEEP2 (70,000 bytes,
* sapling), KEEP3 (140,000, tree), KEEPS (sparse,
* EOF 280,000, the pattern only at 279,000-
* 279,999), KDIR (a directory grown to two blocks)
* with KDIR/DATA (5,000 bytes) in it.
*
* Must end below KBLK, $BD00 (m32build.sh checks).

 XC
COUT EQU $FDED
CROUT EQU $FD8E
PRBYTE EQU $FDDA
HOME EQU $FC58
MLI EQU $BF00
DEVNUM EQU $BF30
DATELO EQU $BF90
DBUF EQU $6000
IOB1 EQU $40
IOB2 EQU $44
P0 EQU $80
P1 EQU $81
P2 EQU $82
PK EQU $83
VPTR EQU $84
VCNT EQU $86
SPTR EQU $8A
TPTR EQU $8C

 ORG $2000
START JSR HOME
 JSR PRS
 ASC 'STAGE 3 TEST: WRITING'
 DFB $0D,$00
* the volume's blocks in use, before anything
 LDA #<NVOL
 LDX #>NVOL
 JSR GFI
 LDA GFP+8
 STA USED0
 LDA GFP+9
 STA USED0+1

* ==== A. a new seedling ===========================
 LDA #<NNEW1
 LDX #>NNEW1
 LDY #$01
 JSR CREATF
 JSR CHKI
 DFB $00
 LDA #<NNEW1
 LDX #>NNEW1
 LDY #$01
 JSR CREATF
 JSR CHKI
 DFB $47
 LDA #<NNEW1
 LDX #>NNEW1
 JSR GFI
 LDA GFP+7
 JSR CHKI
 DFB $01
 LDA GFP+8
 JSR CHKI
 DFB $01
* printed: the access CREATE gave it
 JSR PRS
 ASC 'NEW '
 DFB $00
 JSR PRGFP
* its date is the system's date
 LDA GFP+$0E
 CMP DATELO
 BNE A1
 LDA GFP+$0F
 CMP DATELO+1
A1 JSR CHKI
 DFB $00

* ==== B. 300 bytes written, read back ============
 LDA #<NNEW1
 LDX #>NNEW1
 LDY #IOB1
 JSR OPENF
 JSR CHKI
 DFB $00
 STZ VPOS
 STZ VPOS+1
 STZ VPOS+2
 LDA #<300
 LDX #>300
 JSR GENP
 LDA #<300
 LDX #>300
 JSR WRITEN
 JSR CHKI
 DFB $00
 JSR CHKTR
 DFB $2C,$01
 JSR GETEOF
 JSR CHKPOS
 DFB $2C,$01,$00
 JSR GETMRK
 JSR CHKPOS
 DFB $2C,$01,$00
 JSR SETPOS
 DFB $00,$00,$00
 JSR SETMRK
 LDA #<1000
 LDX #>1000
 JSR READN
 JSR CHKTR
 DFB $2C,$01
 JSR VERTR
 JSR CHKI
 DFB $00
 JSR CLOSEF
 JSR CHKI
 DFB $00

* ==== C. a sapling and a tree, written ===========
 LDA #$70
 STA WTOT
 LDA #$11
 STA WTOT+1
 LDA #$01
 STA WTOT+2
 LDA #<1000
 LDX #>1000
 LDY #$00
 JSR SETCH
 LDA #<NNEW2
 LDX #>NNEW2
 JSR WRALL
 JSR CHKI
 DFB $00
 LDA #<777
 LDX #>777
 LDY #$00
 JSR SETCH
 LDA #<NNEW2
 LDX #>NNEW2
 JSR RDALL
 JSR CHKI
 DFB $00
 LDA #<NNEW2
 LDX #>NNEW2
 JSR GFI
 LDA GFP+7
 JSR CHKI
 DFB $02
 LDA GFP+8
 JSR CHKI
 DFB 138
 LDA #$E0
 STA WTOT
 LDA #$22
 STA WTOT+1
 LDA #$02
 STA WTOT+2
 LDA #<4000
 LDX #>4000
 LDY #$00
 JSR SETCH
 LDA #<NNEW3
 LDX #>NNEW3
 JSR WRALL
 JSR CHKI
 DFB $00
 LDA #<NNEW3
 LDX #>NNEW3
 JSR RDALL
 JSR CHKI
 DFB $00
 LDA #<NNEW3
 LDX #>NNEW3
 JSR GFI
 LDA GFP+7
 JSR CHKI
 DFB $03
 LDA GFP+8
 JSR CHKI
 DFB $15
 LDA GFP+9
 JSR CHKI
 DFB $01

* ==== D. sparse: SET_EOF out, one piece written ==
 LDA #<NNEW4
 LDX #>NNEW4
 JSR SPARSE
 JSR CHKI
 DFB $00
 LDA #<NNEW4
 LDX #>NNEW4
 LDY #IOB1
 JSR OPENF
 LDA #<1000
 LDX #>1000
 JSR READN
 JSR CHKTR
 DFB $E8,$03
 JSR ZCHK
 JSR CHKI
 DFB $00
 JSR SETPOS
 DFB $D8,$41,$04
 JSR SETMRK
 LDA #<1000
 LDX #>1000
 JSR READN
 JSR CHKTR
 DFB $E8,$03
 LDA #$D8
 STA VPOS
 LDA #$41
 STA VPOS+1
 LDA #$04
 STA VPOS+2
 JSR VERTR
 JSR CHKI
 DFB $00
 JSR CLOSEF

* ==== E. SET_EOF cuts the tree back to 1,000 =====
 LDA #<NNEW3
 LDX #>NNEW3
 LDY #IOB1
 JSR OPENF
 JSR SETPOS
 DFB $E8,$03,$00
 JSR SETEOF
 JSR CHKI
 DFB $00
 JSR GETEOF
 JSR CHKPOS
 DFB $E8,$03,$00
 JSR CLOSEF
 JSR CHKI
 DFB $00
 LDA #<NNEW3
 LDX #>NNEW3
 JSR RDALL
 JSR CHKI
 DFB $00
* the two systems' answers, side by side
 LDA #<NNEW3
 LDX #>NNEW3
 JSR GFI
 JSR PRS
 ASC 'CUT '
 DFB $00
 JSR PRGFP
 LDA #<NNEW4
 LDX #>NNEW4
 JSR GFI
 JSR PRS
 ASC 'SPR '
 DFB $00
 JSR PRGFP

* cut further: NEW3 to 300, NEW2 (a sapling) to 600
 LDA #<NNEW3
 LDX #>NNEW3
 JSR CUTTO
 DFB $2C,$01,$00
 LDA #<NNEW2
 LDX #>NNEW2
 JSR CUTTO
 DFB $58,$02,$00

* ==== F. RENAME ==================================
 LDA #<NREN1
 LDX #>NREN1
 LDY #<NNEW1
 JSR RENF
 JSR CHKI
 DFB $00
 LDA #<NREN1
 LDX #>NREN1
 JSR GFI
 JSR CHKI
 DFB $00
 LDA #<NNEW1
 LDX #>NNEW1
 JSR GFI
 JSR CHKI
 DFB $46
 LDA #<NSEED
 LDX #>NSEED
 LDY #<NREN1
 JSR RENF
 JSR CHKI
 DFB $47
 LDA #<NDREN
 LDX #>NDREN
 LDY #<NREN1
 JSR RENF
 JSR CHKI
 DFB $40

* ==== G. the access bits =========================
* $81: read and destroy, not write, not rename
 LDA #$81
 STA CRACC
 LDA #<NRO1
 LDX #>NRO1
 LDY #$01
 JSR CREATF
 JSR CHKI
 DFB $00
 LDA #<NRO1
 LDX #>NRO1
 LDY #IOB1
 JSR OPENF
 LDA #<10
 LDX #>10
 JSR WRITEN
 JSR CHKI
 DFB $4E
 JSR SETPOS
 DFB $00,$01,$00
 JSR SETEOF
 JSR CHKI
 DFB $4E
 JSR CLOSEF
 LDA #<NRO2
 LDX #>NRO2
 LDY #<NRO1
 JSR RENF
 JSR CHKI
 DFB $4E
 LDA #<NRO1
 LDX #>NRO1
 JSR DESTF
 JSR CHKI
 DFB $00

* ==== H. a subdirectory that has to grow =========
 LDA #<NNDIR
 LDX #>NNDIR
 LDY #$0D
 JSR CREATF
 JSR CHKI
 DFB $00
 LDA #<NNDIR
 LDX #>NNDIR
 JSR GFI
 LDA GFP+7
 JSR CHKI
 DFB $0D
 LDA GFP+8
 JSR CHKI
 DFB $01
* fourteen files: the key block holds twelve
 LDA #<DNAM
 LDX #>DNAM
 JSR MANY
 JSR CHKI
 DFB $00
 LDA #<NNDIR
 LDX #>NNDIR
 JSR GFI
 LDA GFP+8
 JSR CHKI
 DFB $02
 LDA #<NNDIR
 LDX #>NNDIR
 LDY #IOB1
 JSR OPENF
 JSR GETEOF
 JSR CHKPOS
 DFB $00,$04,$00
 JSR CLOSEF
* not while it holds anything
 LDA #<NNDIR
 LDX #>NNDIR
 JSR DESTF
 JSR CHKI
 DFB $4E
 LDA #<DNAM
 LDX #>DNAM
 JSR UNMANY
 JSR CHKI
 DFB $00
 LDA #<NNDIR
 LDX #>NNDIR
 JSR DESTF
 JSR CHKI
 DFB $00

* ==== everything made so far goes ================
 LDX #$00
DE1 LDA GONE,X
 PHX
 TAY
 LDA GONE+1,X
 TAX
 TYA
 JSR DESTF
 JSR CHKI
 DFB $00
 PLX
 INX
 INX
 CPX #8
 BCC DE1
* and the bitmap balances
 JSR USEDCK

* ==== I. the volume directory's 51 entries =======
* ten files are there; 41 more fit, the 42nd is
* $49.  MANY stops at the first error: here it
* must be that one, after 41.
 LDA #$51
 STA MANYN
 LDA #<RNAM
 LDX #>RNAM
 JSR MANY
 JSR CHKI
 DFB $49
 LDA MANYC
 JSR CHKI
 DFB $41
 LDA MANYC
 STA MANYN
 LDA #<RNAM
 LDX #>RNAM
 JSR UNMANY
 JSR CHKI
 DFB $00
 JSR USEDCK

* ==== J. WRITE_BLOCK: block 2 out and back =======
 LDA DEVNUM
 STA RBP+1
 LDA #$80
 LDX #<RBP
 LDY #>RBP
 JSR DOMLI
 JSR CHKI
 DFB $00
 LDA #$81
 LDX #<RBP
 LDY #>RBP
 JSR DOMLI
 JSR CHKI
 DFB $00

* ==== K. the files left for cp2 ==================
 LDA #$70
 STA WTOT
 LDA #$11
 STA WTOT+1
 LDA #$01
 STA WTOT+2
 LDA #<1000
 LDX #>1000
 LDY #$00
 JSR SETCH
 LDA #<NKEEP2
 LDX #>NKEEP2
 JSR WRALL
 JSR CHKI
 DFB $00
 LDA #$E0
 STA WTOT
 LDA #$22
 STA WTOT+1
 LDA #$02
 STA WTOT+2
 LDA #<NKEEP3
 LDX #>NKEEP3
 JSR WRALL
 JSR CHKI
 DFB $00
 LDA #<NKEEPS
 LDX #>NKEEPS
 JSR SPARSE
 JSR CHKI
 DFB $00
 LDA #<NKDIR
 LDX #>NKDIR
 LDY #$0D
 JSR CREATF
 JSR CHKI
 DFB $00
 LDA #$14
 STA MANYN
 LDA #<KNAM
 LDX #>KNAM
 JSR MANY
 JSR CHKI
 DFB $00
 LDA #<5000
 STA WTOT
 LDA #>5000
 STA WTOT+1
 STZ WTOT+2
 LDA #<NKDATA
 LDX #>NKDATA
 JSR WRALL
 JSR CHKI
 DFB $00

* ==== the verdict ================================
 JSR PRS
 ASC 'CHECKS '
 DFB $00
 LDA CNO
 JSR PRBYTE
 JSR PRS
 ASC ' FAILS '
 DFB $00
 LDA FAILS
 JSR PRBYTE
 JSR CROUT
 LDA FAILS
 BNE V1
 JSR PRS
 ASC '>>> STAGE 3 PASS'
 DFB $00
 BRA V2
V1 JSR PRS
 ASC '>>> STAGE 3 FAIL'
 DFB $00
V2 BRA V2

* ==== the pieces ==================================

* ---- CREATF: A/X the name, Y the storage type --
* Access CRACC (then back to $C3), type $06 for a
* file and $0F for a directory, date 0: now.
CREATF STA CRP+1
 STX CRP+2
 STY CRP+7
 LDA CRACC
 STA CRP+3
 LDA #$C3
 STA CRACC
 LDA #$06
 CPY #$0D
 BNE CRF1
 LDA #$0F
CRF1 STA CRP+4
 LDA #$C0
 LDX #<CRP
 LDY #>CRP
 JMP DOMLI

* ---- DESTF: A/X the name ------------------------
DESTF STA DSP+1
 STX DSP+2
 LDA #$C1
 LDX #<DSP
 LDY #>DSP
 JMP DOMLI

* ---- RENF: A/X the new name, Y the old's low ---
* byte (every name here is in one page: NAMES)
RENF STA RNP+3
 STX RNP+4
 STY RNP+1
 STX RNP+2
 LDA #$C2
 LDX #<RNP
 LDY #>RNP
 JMP DOMLI

* ---- WRITEN: A/X bytes from DBUF ---------------
WRITEN STA RWP+4
 STX RWP+5
 LDA #<DBUF
 STA RWP+2
 LDA #>DBUF
 STA RWP+3
 LDA #$CB
 LDX #<RWP
 LDY #>RWP
 JMP DOMLI

* ---- CUTTO: A/X the name, SET_EOF to the 3 -----
* bytes after the JSR, read it all back, and print
* its GET_FILE_INFO
CUTTO STA WNAM
 STX WNAM+1
 LDA #3
 STA INLN
 JSR INLB
 LDA WNAM
 LDX WNAM+1
 LDY #IOB1
 JSR OPENF
 LDX #2
CUT1 LDA INLV,X
 STA MKP+2,X
 DEX
 BPL CUT1
 JSR SETEOF
 JSR CHKI
 DFB $00
 JSR CLOSEF
 LDA WNAM
 LDX WNAM+1
 JSR RDALL
 JSR CHKI
 DFB $00
 LDA WNAM
 LDX WNAM+1
 JSR GFI
 JSR PRS
 ASC 'CUT '
 DFB $00
 JMP PRGFP

* ---- SETEOF: MKP's position as the EOF ---------
SETEOF LDA #$D0
 LDX #<MKP
 LDY #>MKP
 JMP DOMLI

* ---- GENP: A/X bytes of the pattern at DBUF ----
* from VPOS
GENP STA RWP+6
 STX RWP+7
 LDA #$01
 STA VGEN
 JSR VERTR
 STZ VGEN
 RTS

* ---- ZCHK: are the READ's bytes all zero? ------
ZCHK LDA #<DBUF
 STA VPTR
 LDA #>DBUF
 STA VPTR+1
 LDY RWP+6
 LDX RWP+7
 INX
ZC1 CPY #$00
 BNE ZC2
 DEX
 BEQ ZC9
ZC2 DEY
 LDA (VPTR)
 BNE ZC8
 INC VPTR
 BNE ZC1
 INC VPTR+1
 BRA ZC1
ZC8 LDA #$01
 RTS
ZC9 LDA #$00
 RTS

* ---- WRALL: make a file of WTOT pattern bytes --
* A/X the name; written CHL/CHH at a time.  Out:
* A = 0, or the step that failed (1-4).
WRALL STA WNAM
 STX WNAM+1
 LDY #$01
 JSR CREATF
 BEQ WA1
 LDA #1
 RTS
WA1 LDA WNAM
 LDX WNAM+1
 LDY #IOB1
 JSR OPENF
 BEQ WA2
 LDA #2
 RTS
WA2 STZ VPOS
 STZ VPOS+1
 STZ VPOS+2
* this piece: the chunk, or what is left
WA3 SEC
 LDA WTOT
 SBC VPOS
 STA WLFT
 LDA WTOT+1
 SBC VPOS+1
 STA WLFT+1
 LDA WTOT+2
 SBC VPOS+2
 BNE WA4
 LDA WLFT
 ORA WLFT+1
 BEQ WA8
 LDA WLFT+1
 CMP CHH
 BCC WA5
 BNE WA4
 LDA WLFT
 CMP CHL
 BCC WA5
WA4 LDA CHL
 STA WLFT
 LDA CHH
 STA WLFT+1
WA5 LDA WLFT
 LDX WLFT+1
 JSR GENP
 LDA WLFT
 LDX WLFT+1
 JSR WRITEN
 BEQ WA6
 LDA #3
 BRA WA9
WA6 LDA RWP+6
 CMP WLFT
 BNE WA7
 LDA RWP+7
 CMP WLFT+1
 BEQ WA7A
WA7 LDA #4
 BRA WA9
WA7A CLC
 LDA VPOS
 ADC WLFT
 STA VPOS
 LDA VPOS+1
 ADC WLFT+1
 STA VPOS+1
 LDA VPOS+2
 ADC #$00
 STA VPOS+2
 JMP WA3
WA8 LDA #0
WA9 PHA
 JSR CLOSEF
 PLA
 RTS

* ---- SPARSE: A/X the name; EOF 280,000, and ----
* the pattern at 279,000-279,999.  Out: A = 0 or
* the step that failed.
SPARSE STA WNAM
 STX WNAM+1
 LDY #$01
 JSR CREATF
 BNE SP9
 LDA WNAM
 LDX WNAM+1
 LDY #IOB1
 JSR OPENF
 BNE SP9
 JSR SETPOS
 DFB $C0,$45,$04
 JSR SETEOF
 BNE SP8
 JSR SETPOS
 DFB $D8,$41,$04
 JSR SETMRK
 BNE SP8
 LDA #$D8
 STA VPOS
 LDA #$41
 STA VPOS+1
 LDA #$04
 STA VPOS+2
 LDA #<1000
 LDX #>1000
 JSR GENP
 LDA #<1000
 LDX #>1000
 JSR WRITEN
SP8 PHA
 JSR CLOSEF
 PLA
SP9 RTS

* ---- MANY / UNMANY: names 01, 02 ... ------------
* A/X a name whose last two characters are the
* number.  MANY creates them, MANYN of them
* (BCD), stopping at the first error, and counts
* in MANYC (BCD) those made; UNMANY destroys
* MANYN of them.  Out: A = 0 or the first error.
MANY CLC
 BRA MN0
UNMANY SEC
MN0 ROR MNDES
 STA TPTR
 STX TPTR+1
 STZ MANYC
MN1 LDA MANYC
 CMP MANYN
 BEQ MN8
* the number, in BCD, into the name's last two
 SED
 CLC
 ADC #$01
 CLD
 PHA
 LDA (TPTR)
 TAY
 PLA
 PHA
 AND #$0F
 ORA #$30
 STA (TPTR),Y
 DEY
 PLA
 PHA
 LSR
 LSR
 LSR
 LSR
 ORA #$30
 STA (TPTR),Y
 LDA TPTR
 LDX TPTR+1
 LDY #$01
 BIT MNDES
 BMI MN2
 JSR CREATF
 BRA MN3
MN2 JSR DESTF
MN3 PLY
 CMP #$00
 BNE MN9
 STY MANYC
 BRA MN1
MN8 LDA #$00
MN9 RTS

* ---- USEDCK: blocks in use as at the start -----
USEDCK LDA #<NVOL
 LDX #>NVOL
 JSR GFI
 LDA GFP+8
 JSR CHKU
 LDA USED0
 STA WANT
 JSR CHKW
 LDA GFP+9
 JSR CHKU
 LDA USED0+1
 STA WANT
 JMP CHKW
CHKU STA GOT
 RTS

* ==== data ========================================
CRP DFB $07
 DA $0000
 DFB $C3,$06
 DA $0000
 DFB $01
 DA $0000
 DA $0000
DSP DFB $01
 DA $0000
RNP DFB $02
 DA $0000
 DA $0000

* what section "everything made" destroys
GONE DA NREN1,NNEW2,NNEW3,NNEW4

* the names: all in this one page, which RENF
* relies on (it takes the old name's low byte)
 DS \
NNEW1 DFB 4
 ASC 'NEW1'
NNEW2 DFB 4
 ASC 'NEW2'
NNEW3 DFB 4
 ASC 'NEW3'
NNEW4 DFB 4
 ASC 'NEW4'
NREN1 DFB 4
 ASC 'REN1'
NDREN DFB 8
 ASC 'DIR/REN1'
NRO1 DFB 3
 ASC 'RO1'
NRO2 DFB 3
 ASC 'RO2'
NSEED DFB 4
 ASC 'SEED'
NNDIR DFB 4
 ASC 'NDIR'
NVOL DFB 8
 ASC '/TESTVOL'
DNAM DFB 8
 ASC 'NDIR/F00'
RNAM DFB 3
 ASC 'R00'
NKEEP2 DFB 5
 ASC 'KEEP2'
NKEEP3 DFB 5
 ASC 'KEEP3'
NKEEPS DFB 5
 ASC 'KEEPS'
NKDIR DFB 4
 ASC 'KDIR'
KNAM DFB 8
 ASC 'KDIR/F00'
NKDATA DFB 9
 ASC 'KDIR/DATA'

CRACC DFB $C3
USED0 DS 2
WTOT DS 3
WLFT DS 2
WNAM DS 2
MANYN DFB $14
MANYC DFB $00
MNDES DFB $00

 PUT TLIB
