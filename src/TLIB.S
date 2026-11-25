* TLIB.S  the test programs' shared pieces: printing,
* numbered checks, the MLI calls on fixed parameter
* blocks, the byte pattern, and RDALL.  PUT at the
* end of TEST2.S and TEST3.S, which define the
* equates (DBUF, IOB1, the zero page) first.

* ---- PRS: print the string after the JSR -------
* ending in a 0; the RTS goes past it.
PRS PLA
 STA SPTR
 PLA
 STA SPTR+1
PRS1 INC SPTR
 BNE PRS2
 INC SPTR+1
PRS2 LDA (SPTR)
 BEQ PRS3
 ORA #$80
 JSR COUT
 BRA PRS1
PRS3 LDA SPTR+1
 PHA
 LDA SPTR
 PHA
 RTS

* ---- INLB: the byte after the caller's JSR -----
* For CHKI, CHKTR, CHKPOS and SETPOS, which are
* followed by their expected bytes.  INLN = how
* many; they go to INLV, and the caller's return
* moves past them.  Called first thing, so the
* stack holds INLB's return, then the caller's.
INLB TSX
 LDA $0103,X
 STA SPTR
 LDA $0104,X
 STA SPTR+1
 LDY #$00
INL1 INY
 LDA (SPTR),Y
 STA INLV-1,Y
 CPY INLN
 BCC INL1
 CLC
 LDA $0103,X
 ADC INLN
 STA $0103,X
 LDA $0104,X
 ADC #$00
 STA $0104,X
 RTS

* ---- CHKI: A against the byte after the JSR ----
CHKI STA GOT
 LDA #1
 STA INLN
 JSR INLB
 LDA INLV
 STA WANT
* ---- CHKW: GOT against WANT --------------------
CHKW INC CNO
 LDA GOT
 CMP WANT
 BEQ CHK9
 INC FAILS
 LDA #'#'+$80
 JSR COUT
 LDA CNO
 JSR PRBYTE
 JSR PRS
 ASC ' G='
 DFB $00
 LDA GOT
 JSR PRBYTE
 JSR PRS
 ASC ' W='
 DFB $00
 LDA WANT
 JSR PRBYTE
 JSR CROUT
CHK9 RTS

* ---- CHKTR: the READ count against 2 bytes -----
CHKTR LDA #2
 STA INLN
 JSR INLB
 LDA RWP+6
 STA GOT
 LDA INLV
 STA WANT
 JSR CHKW
 LDA RWP+7
 STA GOT
 LDA INLV+1
 STA WANT
 JMP CHKW

* ---- CHKPOS: MKP's position against 3 bytes ----
CHKPOS LDA #3
 STA INLN
 JSR INLB
 LDX #$00
CP1 LDA MKP+2,X
 STA GOT
 LDA INLV,X
 STA WANT
 PHX
 JSR CHKW
 PLX
 INX
 CPX #3
 BCC CP1
 RTS

* ---- SETPOS: 3 bytes after the JSR -> MKP ------
SETPOS LDA #3
 STA INLN
 JSR INLB
 LDX #2
SP1 LDA INLV,X
 STA MKP+2,X
 DEX
 BPL SP1
 RTS

* ---- DOMLI: call A with the block at Y:X -------
* Back with A = the error, 0 for none, and the
* flags set from it.
DOMLI STA DMN
 STX DMP
 STY DMP+1
 JSR MLI
DMN DFB $00
DMP DA $0000
 CMP #$00
 RTS

* ---- the calls, on the blocks below ------------
* OPENF: A/X the name, Y the buffer's page.  The
* ref goes into every other block.
OPENF STA OPP+1
 STX OPP+2
 STY OPP+4
 STZ OPP+3
 LDA #$C8
 LDX #<OPP
 LDY #>OPP
 JSR DOMLI
 BNE OPF9
 LDA OPP+5
 JSR SETREF
 LDA #$00
OPF9 RTS
SETREF STA RWP+1
 STA MKP+1
 STA CLP+1
 STA NLP+1
 RTS
* READN: A/X bytes, into DBUF
READN STA RWP+4
 STX RWP+5
 LDA #<DBUF
 STA RWP+2
 LDA #>DBUF
 STA RWP+3
 LDA #$CA
 LDX #<RWP
 LDY #>RWP
 JMP DOMLI
GETEOF LDA #$D1
 BRA MK1
GETMRK LDA #$CF
 BRA MK1
SETMRK LDA #$CE
MK1 LDX #<MKP
 LDY #>MKP
 JMP DOMLI
CLOSEF LDA #$CC
 LDX #<CLP
 LDY #>CLP
 JMP DOMLI
* GFI: A/X the name
GFI STA GFP+1
 STX GFP+2
 LDA #$C4
 LDX #<GFP
 LDY #>GFP
 JMP DOMLI
* PRGFP: GFI's fifteen answers in hex, and Return
PRGFP LDX #$00
PG1 LDA GFP+3,X
 PHX
 JSR PRBYTE
 PLX
 INX
 CPX #15
 BCC PG1
 JMP CROUT

* ---- SETCH: RDALL's piece size and hole mode ---
SETCH STA CHL
 STX CHH
 STY HMODE
 RTS

* ---- RDALL: read a whole file and check it -----
* A/X the name; CHL/CHH the piece size; HMODE.
* Reads to the end in pieces, checking every byte,
* then that the end came where GET_EOF says.
* Out: A = 0, or the step that failed (1-5).
RDALL LDY #IOB1
 JSR OPENF
 BEQ RA1
 LDA #1
 RTS
RA1 STZ VPOS
 STZ VPOS+1
 STZ VPOS+2
RA2 LDA CHL
 LDX CHH
 JSR READN
 BEQ RA3
 CMP #$4C
 BEQ RA5
 LDA #2
 BRA RA9
RA3 JSR VERTR
 BEQ RA4
 LDA #3
 BRA RA9
RA4 CLC
 LDA VPOS
 ADC RWP+6
 STA VPOS
 LDA VPOS+1
 ADC RWP+7
 STA VPOS+1
 LDA VPOS+2
 ADC #$00
 STA VPOS+2
 BRA RA2
* the end: nothing read, and where GET_EOF says
RA5 LDA RWP+6
 ORA RWP+7
 BEQ RA6
 LDA #4
 BRA RA9
RA6 JSR GETEOF
 LDX #2
RA7 LDA MKP+2,X
 CMP VPOS,X
 BNE RA8
 DEX
 BPL RA7
 LDA #0
 BRA RA9
RA8 LDA #5
RA9 PHA
 JSR CLOSEF
 PLA
 RTS

* ---- VERTR: check the READ's bytes at DBUF -----
* Against the pattern from VPOS, for RWP+6/7
* bytes, with HMODE's holes.  Out: A = 0, or 1 for
* a wrong byte.
VERTR LDA RWP+6
 STA VCNT
 LDA RWP+7
 STA VCNT+1
 LDA #<DBUF
 STA VPTR
 LDA #>DBUF
 STA VPTR+1
 LDA VPOS
 STA P0
 LDA VPOS+1
 STA P1
 LDA VPOS+2
 STA P2
* PK = 7*P1 + 13*P2, by adding
 STZ PK
 LDX P1
VT1 BEQ VT2
 LDA PK
 CLC
 ADC #7
 STA PK
 DEX
 BRA VT1
VT2 LDX P2
VT3 BEQ VT4
 LDA PK
 CLC
 ADC #13
 STA PK
 DEX
 BRA VT3
VT4 LDA VCNT
 ORA VCNT+1
 BNE VT5
 LDA #$00
 RTS
* in a hole?  mode 1: P2 = 0 and P1 10-19 (blocks
* 5-9); mode 2: P2 = 2 or 3
VT5 LDA HMODE
 BEQ VT7
 CMP #1
 BNE VT6
 LDA P2
 BNE VT7
 LDA P1
 CMP #10
 BCC VT7
 CMP #20
 BCS VT7
 BRA VTZ
VT6 LDA P2
 AND #$FE
 CMP #2
 BNE VT7
VTZ LDA #$00
 BRA VT8
VT7 LDA P0
 CLC
 ADC PK
* VGEN set: write the pattern instead of checking
* it - how TEST3 makes what it writes
VT8 LDY VGEN
 BEQ VT8A
 STA (VPTR)
 BRA VT9
VT8A CMP (VPTR)
 BEQ VT9
 LDA #$01
 RTS
VT9 INC VPTR
 BNE VT10
 INC VPTR+1
VT10 LDA VCNT
 BNE VT11
 DEC VCNT+1
VT11 DEC VCNT
 INC P0
 BNE VT4
 LDA PK
 CLC
 ADC #7
 STA PK
 INC P1
 BNE VT4
 LDA PK
 CLC
 ADC #13
 STA PK
 INC P2
 BRA VT4

* ==== data ========================================
* the ProDOS parameter blocks
OPP DFB $03
 DA $0000
 DA $0000
 DFB $00
RWP DFB $04
 DFB $00
 DA $0000
 DA $0000
 DA $0000
MKP DFB $02
 DFB $00
 DFB $00,$00,$00
CLP DFB $01
 DFB $00
NLP DFB $03
 DFB $00,$00,$00
GFP DFB $0A
 DA $0000
 DS 15
PFP DFB $01
 DA DBUF
RBP DFB $03
 DFB $00
 DA DBUF
 DA $0002

* the working bytes
CNO DFB $00
FAILS DFB $00
GOT DFB $00
WANT DFB $00
INLN DFB $00
INLV DS 3
VPOS DS 3
HMODE DFB $00
VGEN DFB $00
CHL DFB $00
CHH DFB $00
REFA DFB $00
REFB DFB $00
LNS DFB $00
LNCR DFB $00
LNTOT DS 2
SPN DFB $00
SPW DS 2
DBLKS DFB $00
DHDR DFB $00
DENT DFB $00
TEND DFB $00
