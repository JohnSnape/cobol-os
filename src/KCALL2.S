* KCALL2.S  GET_FILE_INFO, and KLDSYS, which loads
* COBOL.SYSTEM and starts it.  Stage 2.

* ==== GET_FILE_INFO $C4 ==========================
* +1/+2 pathname, and returned:
*   +3 access      +4 file type   +5/+6 aux type
*   +7 storage type (1, 2, 3, $D, or $F)
*   +8/+9 blocks used
*   +A/+B modified date   +C/+D modified time
*   +E/+F created date    +10/+11 created time
* Most of it is the directory entry's own bytes,
* in another order: KGFTAB gives, for each of
* those fifteen bytes, where it is in the entry.
* The storage type is the entry's high nibble,
* shifted down.
*
* A VOLUME has no entry, and ProDOS answers from
* its header: type $0F, storage $F, the aux type
* is the volume's size in blocks and "blocks
* used" is how many are in use - which means
* counting the free ones in the bitmap.
KGFTAB DFB $1E,$10,$1F,$20,$00,$13,$14,$21
 DFB $22,$23,$24,$18,$19,$1A,$1B

KGFI LDY #$01
 LDA (KPRM),Y
 STA KNAM
 INY
 LDA (KPRM),Y
 STA KNAM+1
 JSR KPARSE
 BCS KGF9
 JSR KWALK
 BCS KGF9
 JSR KENTRY
* ---- the fifteen bytes, through the table ------
 LDX #$00
KGF1 LDY KGFTAB,X
 LDA (KT0),Y
 PHA
 TXA
 CLC
 ADC #$03
 TAY
 PLA
 STA (KPRM),Y
 INX
 CPX #15
 BCC KGF1
 LDY #$07
 LDA KWTYPE
 LSR
 LSR
 LSR
 LSR
 STA (KPRM),Y
 LDA KWTYPE
 CMP #$F0
 BEQ KGFV
 LDA #$00
KGF9 RTS
* ---- a volume -----------------------------------
* The header's bitmap pointer ($23/$24 in the
* entry) and size ($25/$26) are saved first:
* counting reads the bitmap through KBLK, where
* the header is.
KGFV LDY #$04
 LDA #$0F
 STA (KPRM),Y
 LDY #$23
 LDA (KT0),Y
 STA KVBML
 INY
 LDA (KT0),Y
 STA KVBMH
 INY
 LDA (KT0),Y
 STA KVTOTL
 LDY #$05
 STA (KPRM),Y
 LDY #$26
 LDA (KT0),Y
 STA KVTOTH
 LDY #$06
 STA (KPRM),Y
* no modified date
 LDA #$00
 LDY #$0A
KGF2 STA (KPRM),Y
 INY
 CPY #$0E
 BCC KGF2
 JSR KFREE
 BCS KGF9
* used = size - free
 SEC
 LDA KVTOTL
 SBC KVFREL
 LDY #$08
 STA (KPRM),Y
 LDA KVTOTH
 SBC KVFREH
 INY
 STA (KPRM),Y
 LDA #$00
 RTS

* ---- KFREE: count the volume's free blocks -----
* One bit per block, set = free, 4,096 blocks to a
* bitmap block, so a volume of N blocks has
* (N + 4095) / 4096 of them, one after another
* from KVBML/H.  Every set bit is counted: ProDOS
* leaves the bits past the volume's end clear.
* Out: KVFREL/H; or carry set, A = the error.
KFREE STZ KVFREL
 STZ KVFREH
 LDA KVTOTH
 LSR
 LSR
 LSR
 LSR
 STA KVNBM
 LDA KVTOTH
 AND #$0F
 ORA KVTOTL
 BEQ KFB1
 INC KVNBM
KFB1 LDA KVBML
 STA KBLKL
 LDA KVBMH
 STA KBLKH
 LDA #<KBLK
 STA KBUF
 LDA #>KBLK
 STA KBUF+1
KFB2 LDX KDEVX
 LDA #$01
 JSR KDIO
 BCS KFB9
* every bit of the 512 bytes: KPTR walks them
 LDA #<KBLK
 STA KPTR
 LDA #>KBLK
 STA KPTR+1
 LDX #$02
 LDY #$00
KFB3 LDA (KPTR),Y
KFB4 ASL
 BCC KFB5
 INC KVFREL
 BNE KFB5
 INC KVFREH
KFB5 CMP #$00
 BNE KFB4
 INY
 BNE KFB3
 INC KPTR+1
 DEX
 BNE KFB3
* the next bitmap block
 INC KBLKL
 BNE KFB6
 INC KBLKH
KFB6 DEC KVNBM
 BNE KFB2
 CLC
KFB9 RTS

* ==== KLDSYS: load COBOL.SYSTEM and start it ======
* The installer's last act, and later the warm
* restart's (stage 4).  It runs HERE, in the
* language card, because COBOL.SYSTEM loads at
* $2000 - on top of the installer.
*
* It is ProDOS's own start-up, done with the
* kernel's calls made directly (KPRM set by hand,
* no trip through $BF00): OPEN COBOL.SYSTEM by the
* prefix KINIT set, READ up to $9F00 bytes to
* $2000 - all of main memory to the $BF00 page -
* CLOSE, then KGO in the $BF00 page switches the
* ROM in and jumps to $2000.  KGO has to be in
* main memory: the instant this code switched the
* ROM in, its next instruction would come from ROM.
*
* The file buffer is $1C00-$1FFF, under the load
* and above the screen; nothing is there yet.
*
* IF IT FAILS there is no program to tell, and the
* installer that might have is gone, so this says
* so itself, on the top line of the 40-column
* screen the boot left, and stops:
*   CANNOT LOAD COBOL.SYSTEM - ERROR $46
* ---- its message and parameter blocks --------
* Ahead of the code: Merlin 8 must meet KLEML's EQU
* before the LDX that uses it.
KLEMSG ASC 'CANNOT LOAD COBOL.SYSTEM - ERROR $'
KLEML EQU *-KLEMSG
* the three parameter blocks, filled in as it goes
KLOP DFB $03
 DA KLNAM
 DA $1C00
 DFB $00
KLRW DFB $04
 DFB $00
 DA $2000
 DA $9F00
 DA $0000
KLCL DFB $01
 DFB $00
KLNAM DFB 12
 ASC 'COBOL.SYSTEM'
KLDSYS LDA #<KLOP
 STA KPRM
 LDA #>KLOP
 STA KPRM+1
 JSR KOPEN
 CMP #$00
 BNE KLS9
 LDA KLOP+5
 STA KLRW+1
 STA KLCL+1
 LDA #<KLRW
 STA KPRM
 LDA #>KLRW
 STA KPRM+1
 JSR KREAD
 CMP #$00
 BNE KLS9
 LDA #<KLCL
 STA KPRM
 LDA #>KLCL
 STA KPRM+1
 JSR KCLOSE
* a fresh stack, as a program started from
* nothing expects
 LDX #$FF
 TXS
 JMP KGO
* ---- it failed ----------------------------------
KLS9 PHA
 LDX #KLEML-1
KLS1 LDA KLEMSG,X
 ORA #$80
 STA $0400,X
 DEX
 BPL KLS1
 PLA
 PHA
 LSR
 LSR
 LSR
 LSR
 JSR KHEXC
 STA $0400+KLEML
 PLA
 AND #$0F
 JSR KHEXC
 STA $0401+KLEML
KLS2 BRA KLS2
* A = 0-15 -> the screen code of its hex digit
KHEXC CMP #$0A
 BCC KHX1
 ADC #$06
KHX1 ADC #$B0
 RTS

