* TEST2.S  the stage-2 test: reading files.
* Merlin 8, 65C02.  An ordinary system program, ORG
* $2000, that uses nothing but MLI calls - so the
* SAME binary runs on COBOL.OS and on ProDOS 8.
* tools/emu/mktest.ps1 puts it on two test disks
* as COBOL.SYSTEM: TESTOS.po boots our kernel,
* TESTPD.po boots ProDOS.  Every expectation below
* has to hold on BOTH, which is how the test knows
* its expectations are ProDOS's and not just ours.
*
* THE FILES (mktest.ps1 makes them).  Every data
* byte is a function of its position p, with p0,
* p1, p2 the three bytes of p:
*   byte = p0 + 7*p1 + 13*p2  (mod 256)
* so a byte read from the wrong place shows.
*   SEED   300 bytes        seedling
*   EMPTY  0 bytes          seedling, no data
*   SAP    70,000 bytes     sapling
*   TREE   140,000 bytes    tree, two index blocks
*   HOLES  20,480 bytes     sapling; blocks 5-9 are
*                           zeros (sparse, if the
*                           disk tool made it so)
*   TREEH  263,000 bytes    tree; 131072-262143 are
*                           zeros: a master index
*                           entry of 0
*   TEXT   "LINE 1" .. "LINE 30", each with a
*          Return, then "END" with none: 234 bytes
*   DIR    20 files F01-F20 and SUB, so 2 blocks
*   DIR/SUB/DEEP  100 bytes, the pattern
*
* THE OUTPUT.  Every check is numbered in order.
* One that fails prints its number, what it got
* and what it wanted, in hex:  #2A G=46 W=00
* Some GET_FILE_INFO answers are printed whole, to
* compare by eye between the two systems.  Last:
* the number of checks and failures, and PASS.
* Then it stops; reboot to leave.
*
* Memory: this program $2000 up, and it must end
* below KBLK, COBOL.OS's block buffer ($BD00 since
* stage 4; it was $2E00), which tools/m32build.sh
* checks.
* The file buffers are $4000-$5FFF, eight of them;
* data is read into $6000.

 XC
COUT EQU $FDED
CROUT EQU $FD8E
PRBYTE EQU $FDDA
HOME EQU $FC58
MLI EQU $BF00
DEVNUM EQU $BF30
* the data buffer, and the file buffers' pages
DBUF EQU $6000
IOB1 EQU $40
IOB2 EQU $44
* zero page: the pattern's position and its
* running sum, a pointer, a count, PRS's pointer
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
 ASC 'STAGE 2 TEST: READING'
 DFB $0D,$00

* ==== A. a seedling ==============================
 LDA #<NSEED
 LDX #>NSEED
 LDY #IOB1
 JSR OPENF
 JSR CHKI
 DFB $00
 JSR GETEOF
 JSR CHKI
 DFB $00
 JSR CHKPOS
 DFB $2C,$01,$00
 LDA #<1000
 LDX #>1000
 JSR READN
 JSR CHKI
 DFB $00
 JSR CHKTR
 DFB $2C,$01
 STZ VPOS
 STZ VPOS+1
 STZ VPOS+2
 STZ HMODE
 JSR VERTR
 JSR CHKI
 DFB $00
* at the end now: $4C, nothing read
 LDA #<1000
 LDX #>1000
 JSR READN
 JSR CHKI
 DFB $4C
 JSR CHKTR
 DFB $00,$00
 JSR GETMRK
 JSR CHKI
 DFB $00
 JSR CHKPOS
 DFB $2C,$01,$00
 JSR CLOSEF
 JSR CHKI
 DFB $00

* ==== B. an empty file ===========================
 LDA #<NEMPTY
 LDX #>NEMPTY
 LDY #IOB1
 JSR OPENF
 JSR CHKI
 DFB $00
 JSR GETEOF
 JSR CHKPOS
 DFB $00,$00,$00
 LDA #<100
 LDX #>100
 JSR READN
 JSR CHKI
 DFB $4C
 JSR CLOSEF

* ==== C-E. whole files, in odd-sized pieces ======
 LDA #<777
 LDX #>777
 LDY #$00
 JSR SETCH
 LDA #<NSAP
 LDX #>NSAP
 JSR RDALL
 JSR CHKI
 DFB $00
 LDA #<4000
 LDX #>4000
 LDY #$00
 JSR SETCH
 LDA #<NTREE
 LDX #>NTREE
 JSR RDALL
 JSR CHKI
 DFB $00
 LDA #<1000
 LDX #>1000
 LDY #$01
 JSR SETCH
 LDA #<NHOLES
 LDX #>NHOLES
 JSR RDALL
 JSR CHKI
 DFB $00

* ==== F. a tree with a missing index block =======
 LDA #<NTREEH
 LDX #>NTREEH
 LDY #IOB1
 JSR OPENF
 JSR CHKI
 DFB $00
 LDA #$02
 STA HMODE
 LDA #<SPOTH
 LDX #>SPOTH
 LDY #5
 JSR SPOTS
 JSR CLOSEF

* ==== G. SET_MARK and GET_MARK on TREE ===========
 LDA #<NTREE
 LDX #>NTREE
 LDY #IOB1
 JSR OPENF
 JSR CHKI
 DFB $00
 STZ HMODE
 LDA #<SPOTT
 LDX #>SPOTT
 LDY #2
 JSR SPOTS
* the mark after the last spot: 139999 + 1
 JSR GETMRK
 JSR CHKPOS
 DFB $E0,$22,$02
* the mark AT the end is allowed, past it is not
 JSR SETPOS
 DFB $E0,$22,$02
 JSR SETMRK
 JSR CHKI
 DFB $00
 LDA #<10
 LDX #>10
 JSR READN
 JSR CHKI
 DFB $4C
 JSR SETPOS
 DFB $E1,$22,$02
 JSR SETMRK
 JSR CHKI
 DFB $4D
 JSR CLOSEF

* ==== H. NEWLINE: one line per READ ==============
* LNS counts the reads, LNCR those whose last byte
* was the Return, LNTOT the bytes.
 LDA #<NTEXT
 LDX #>NTEXT
 LDY #IOB1
 JSR OPENF
 JSR CHKI
 DFB $00
 LDA #$7F
 STA NLP+2
 LDA #$0D
 STA NLP+3
 LDA #$C9
 LDX #<NLP
 LDY #>NLP
 JSR DOMLI
 JSR CHKI
 DFB $00
 STZ LNS
 STZ LNCR
 STZ LNTOT
 STZ LNTOT+1
LN1 LDA #<100
 LDX #>100
 JSR READN
 BNE LN3
 INC LNS
 CLC
 LDA LNTOT
 ADC RWP+6
 STA LNTOT
 LDA LNTOT+1
 ADC RWP+7
 STA LNTOT+1
* the last byte read: DBUF + count - 1
 LDA RWP+6
 STA TPTR
 LDA #>DBUF
 STA TPTR+1
 LDA TPTR
 BNE LN2
 DEC TPTR+1
LN2 DEC TPTR
 LDA (TPTR)
 CMP #$0D
 BNE LN1
 INC LNCR
 BRA LN1
LN3 JSR CHKI
 DFB $4C
 LDA LNS
 JSR CHKI
 DFB 31
 LDA LNCR
 JSR CHKI
 DFB 30
 LDA LNTOT
 JSR CHKI
 DFB 234
 LDA LNTOT+1
 JSR CHKI
 DFB $00
* newline off: a READ of 100 reads 100
 STZ NLP+2
 LDA #$C9
 LDX #<NLP
 LDY #>NLP
 JSR DOMLI
 JSR SETPOS
 DFB $00,$00,$00
 JSR SETMRK
 LDA #<100
 LDX #>100
 JSR READN
 JSR CHKTR
 DFB 100,$00
 JSR CLOSEF

* ==== I-J. directories, read as files ============
 LDA #<NDIR
 LDX #>NDIR
 JSR DIRALL
 JSR CHKI
 DFB $00
 JSR CHKPOS
 DFB $00,$04,$00
 LDA DBLKS
 JSR CHKI
 DFB 2
 LDA DHDR
 JSR CHKI
 DFB $E3
 LDA DENT
 JSR CHKI
 DFB 21
 LDA #<NVOL
 LDX #>NVOL
 JSR DIRALL
 JSR CHKI
 DFB $00
 JSR CHKPOS
 DFB $00,$08,$00
 LDA DBLKS
 JSR CHKI
 DFB 4
 LDA DHDR
 JSR CHKI
 DFB $F7
 LDA DENT
 JSR CHKI
 DFB 10

* ==== the deep file, by a full path ==============
 LDA #<NDEEP
 LDX #>NDEEP
 LDY #IOB1
 JSR OPENF
 JSR CHKI
 DFB $00
 LDA #<200
 LDX #>200
 JSR READN
 JSR CHKTR
 DFB 100,$00
 STZ VPOS
 STZ VPOS+1
 STZ VPOS+2
 STZ HMODE
 JSR VERTR
 JSR CHKI
 DFB $00
 JSR CLOSEF

* ==== K. GET_FILE_INFO ============================
* SEED: type $06, storage 1, 1 block
 LDA #<NSEED
 LDX #>NSEED
 JSR GFI
 JSR CHKI
 DFB $00
 LDA GFP+4
 JSR CHKI
 DFB $06
 LDA GFP+7
 JSR CHKI
 DFB $01
 LDA GFP+8
 JSR CHKI
 DFB $01
* SAP: storage 2, 137 data blocks + the index
 LDA #<NSAP
 LDX #>NSAP
 JSR GFI
 LDA GFP+7
 JSR CHKI
 DFB $02
 LDA GFP+8
 JSR CHKI
 DFB 138
* TREE: storage 3, 274 + 2 + the master = 277
 LDA #<NTREE
 LDX #>NTREE
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
* DIR: storage $D, type $0F, 2 blocks
 LDA #<NDIR
 LDX #>NDIR
 JSR GFI
 LDA GFP+4
 JSR CHKI
 DFB $0F
 LDA GFP+7
 JSR CHKI
 DFB $0D
 LDA GFP+8
 JSR CHKI
 DFB $02
* the volume: storage $F, type $0F, 1,600 blocks
 LDA #<NVOL
 LDX #>NVOL
 JSR GFI
 JSR CHKI
 DFB $00
 LDA GFP+4
 JSR CHKI
 DFB $0F
 LDA GFP+5
 JSR CHKI
 DFB $40
 LDA GFP+6
 JSR CHKI
 DFB $06
 LDA GFP+7
 JSR CHKI
 DFB $0F
* printed whole, to compare between the systems
 JSR PRS
 ASC 'VOL '
 DFB $00
 JSR PRGFP
 LDA #<NHOLES
 LDX #>NHOLES
 JSR GFI
 JSR PRS
 ASC 'HOL '
 DFB $00
 JSR PRGFP
 LDA #<NTREEH
 LDX #>NTREEH
 JSR GFI
 JSR PRS
 ASC 'TRH '
 DFB $00
 JSR PRGFP

* ==== L. errors ==================================
 LDA #<NNONE
 LDX #>NNONE
 LDY #IOB1
 JSR OPENF
 JSR CHKI
 DFB $46
 LDA #<NNODIR
 LDX #>NNODIR
 LDY #IOB1
 JSR OPENF
 JSR CHKI
 DFB $44
 LDA #<NNOVOL
 LDX #>NNOVOL
 LDY #IOB1
 JSR OPENF
 JSR CHKI
 DFB $45
 LDA #9
 JSR SETREF
 LDA #<10
 LDX #>10
 JSR READN
 JSR CHKI
 DFB $43
 LDA #0
 JSR SETREF
 JSR GETEOF
 JSR CHKI
 DFB $43
* SEED twice: the second is $50, file open
 LDA #<NSEED
 LDX #>NSEED
 LDY #$40
 JSR OPENF
 JSR CHKI
 DFB $00
 LDA OPP+5
 STA REFA
 LDA #<NSEED
 LDX #>NSEED
 LDY #$44
 JSR OPENF
 JSR CHKI
 DFB $50
* eight open, the ninth is $42.  SEED is one.
 LDX #$00
OP1 LDA OPNT,X
 STA TPTR
 LDA OPNT+1,X
 STA TPTR+1
 LDA OPNB,X
 TAY
 PHX
 LDA TPTR
 LDX TPTR+1
 JSR OPENF
 JSR CHKI
 DFB $00
 PLX
 INX
 INX
 CPX #14
 BCC OP1
 LDA #<NDEEP
 LDX #>NDEEP
 LDY #$78
 JSR OPENF
 JSR CHKI
 DFB $42
* CLOSE 0 closes them all
 LDA #0
 JSR SETREF
 JSR CLOSEF
 JSR CHKI
 DFB $00
 LDA REFA
 JSR SETREF
 JSR GETEOF
 JSR CHKI
 DFB $43

* ==== M. two files open, read in turn ============
 LDA #<NSAP
 LDX #>NSAP
 LDY #IOB1
 JSR OPENF
 LDA OPP+5
 STA REFA
 LDA #<NTREE
 LDX #>NTREE
 LDY #IOB2
 JSR OPENF
 LDA OPP+5
 STA REFB
 STZ HMODE
 STZ VPOS
 STZ VPOS+1
 STZ VPOS+2
 LDA #4
 STA LNS
M1 LDA REFA
 JSR SETREF
 JSR M600
 LDA REFB
 JSR SETREF
 JSR M600
 CLC
 LDA VPOS
 ADC #<600
 STA VPOS
 LDA VPOS+1
 ADC #>600
 STA VPOS+1
 DEC LNS
 BNE M1
 LDA #0
 JSR SETREF
 JSR CLOSEF

* ==== N. stage 1's calls, again ==================
* the prefix ProDOS gives a system program, and
* block 2 of the boot drive
 LDA #$C7
 LDX #<PFP
 LDY #>PFP
 JSR DOMLI
 JSR CHKI
 DFB $00
 LDX #9
N1 LDA DBUF,X
 CMP NPFX,X
 BNE N2
 DEX
 BPL N1
N2 TXA
 JSR CHKI
 DFB $FF
 LDA DEVNUM
 STA RBP+1
 LDA #$80
 LDX #<RBP
 LDY #>RBP
 JSR DOMLI
 JSR CHKI
 DFB $00
 LDA DBUF+4
 JSR CHKI
 DFB $F7

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
 ASC '>>> STAGE 2 PASS'
 DFB $00
 BRA V2
V1 JSR PRS
 ASC '>>> STAGE 2 FAIL'
 DFB $00
V2 BRA V2

* ==== the pieces ==================================

* ---- M600: read 600 at VPOS and check it -------
M600 LDA #<600
 LDX #>600
 JSR READN
 JSR CHKI
 DFB $00
 JSR CHKTR
 DFB $58,$02
 JSR VERTR
 JSR CHKI
 DFB $00
 RTS

* ---- SPOTS: SET_MARK, READ 1000, check ---------
* A/X a table of Y rows: the mark (3 bytes), then
* the count the READ should give (2).  The open
* file and HMODE are the caller's.
SPOTS STA TPTR
 STX TPTR+1
 STY SPN
SPT1 LDY #$00
SPT2 LDA (TPTR),Y
 STA MKP+2,Y
 STA VPOS,Y
 INY
 CPY #3
 BCC SPT2
 LDA (TPTR),Y
 STA SPW
 INY
 LDA (TPTR),Y
 STA SPW+1
 JSR SETMRK
 JSR CHKI
 DFB $00
 LDA #<1000
 LDX #>1000
 JSR READN
 JSR CHKI
 DFB $00
 LDA RWP+6
 STA GOT
 LDA SPW
 STA WANT
 JSR CHKW
 LDA RWP+7
 STA GOT
 LDA SPW+1
 STA WANT
 JSR CHKW
 JSR VERTR
 JSR CHKI
 DFB $00
 CLC
 LDA TPTR
 ADC #5
 STA TPTR
 BCC SPT3
 INC TPTR+1
SPT3 DEC SPN
 BNE SPT1
 RTS

* ---- DIRALL: read a directory to its end -------
* A/X the name.  Out: A = 0 or the failing step;
* MKP = its EOF; DBLKS blocks read; DHDR the
* header's first byte (storage type and name
* length); DENT the live entries, the header not
* counted.
DIRALL LDY #IOB1
 JSR OPENF
 BEQ DA1
 LDA #1
 RTS
DA1 JSR GETEOF
 STZ DBLKS
 STZ DENT
DA2 LDA #<512
 LDX #>512
 JSR READN
 BEQ DA3
 CMP #$4C
 BEQ DA8
 LDA #2
 BRA DA9
DA3 LDA RWP+7
 CMP #$02
 BEQ DA4
 LDA #3
 BRA DA9
* entry n at DBUF + 4 + 39n; the key block's
* entry 0 is the header
DA4 LDA #<DBUF+4
 STA TPTR
 LDA #>DBUF
 STA TPTR+1
 LDX #13
 LDA DBLKS
 BNE DA5
 LDA (TPTR)
 STA DHDR
 BRA DA7
DA5 LDA (TPTR)
 AND #$F0
 BEQ DA7
 INC DENT
DA7 CLC
 LDA TPTR
 ADC #39
 STA TPTR
 BCC DA7A
 INC TPTR+1
DA7A DEX
 BNE DA5
 INC DBLKS
 BRA DA2
DA8 LDA #0
DA9 PHA
 JSR CLOSEF
 PLA
 RTS

* SPOTH: TREEH across both edges of its hole, in
* it, and to its end (263,000)
SPOTH DFB $00,$00,$00
 DA 1000
 DFB $0C,$FE,$01
 DA 1000
 DFB $40,$0D,$03
 DA 1000
 DFB $0C,$FE,$03
 DA 1000
 DFB $64,$01,$04
 DA 500
* SPOTT: TREE across its first index block's end
* (131072), and one byte before its end
SPOTT DFB $FE,$FF,$01
 DA 1000
 DFB $DF,$22,$02
 DA 1

* the seven others of the eight-file test
OPNT DA NEMPTY,NSAP,NTREE,NHOLES
 DA NTREEH,NTEXT,NDIR
* (their buffers' pages, at the same offsets; SEED
* holds $40, and the ninth open is given $78, a
* page nobody holds, so the only thing wrong with
* it is the count)
OPNB DFB $48,$00,$4C,$00,$50,$00,$54,$00
 DFB $58,$00,$5C,$00,$44,$00

NSEED DFB 4
 ASC 'SEED'
NEMPTY DFB 5
 ASC 'EMPTY'
NSAP DFB 3
 ASC 'SAP'
NTREE DFB 4
 ASC 'TREE'
NHOLES DFB 5
 ASC 'HOLES'
NTREEH DFB 5
 ASC 'TREEH'
NTEXT DFB 4
 ASC 'TEXT'
NDIR DFB 3
 ASC 'DIR'
NVOL DFB 8
 ASC '/TESTVOL'
NDEEP DFB 21
 ASC '/TESTVOL/DIR/SUB/DEEP'
NNONE DFB 6
 ASC 'NOSUCH'
NNODIR DFB 7
 ASC 'NODIR/X'
NNOVOL DFB 8
 ASC '/NOVOL/X'
NPFX DFB 9
 ASC '/TESTVOL/'

 PUT TLIB
