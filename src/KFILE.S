* KFILE.S  open files: OPEN, NEWLINE, SET_MARK,
* GET_MARK and GET_EOF.  DESIGN.md section 3;
* stage 2.  READ, WRITE, CLOSE and the block
* machinery behind them are in KRW.S.
*
* AN OPEN FILE is one FCB (KEQU.S): where the file
* is, how long it is, the mark, the newline mode,
* and the caller's 1,024-byte buffer.  The ref
* number OPEN hands back is the FCB's number, 1-8.
*
* WHERE A BYTE IS.  The mark is 24 bits.  Shifted
* right nine it is the block OF THE FILE the byte
* is in (0, 1, 2 ...); its low nine bits are the
* byte's place in that block.  What block ON THE
* DISK that is depends on the storage type:
*   seedling  block 0 is the key block itself
*   sapling   the key block is an index: entry n
*             (low byte n, high byte 256+n) is
*             block n's number
*   tree      the key block is a master index: its
*             entry (block / 256) names an index
*             block, whose entry (block AND 255)
*             names the data block
*   directory the blocks are a chain: bytes 2-3 of
*             each are the next one's number
* A zero in an index is a HOLE: the block was never
* written and reads as 512 zeros.  ProDOS writes
* sparse files that way, and a master index entry
* of zero is a hole 128K long.
*
* KLOAD does all of that, and keeps what it found:
* the data block stays in the buffer's first half
* and the index block in its second, so reading on
* through a file costs one block read per 512
* bytes and one more per 128K.

* ==== KFREF: the caller's ref number, checked ====
* In:  (KPRM)+1 = the ref number
* Out: carry clear, X = KFX = the FCB's offset;
*      or carry set, A = $43 (no such open file)
KFREF LDY #$01
 LDA (KPRM),Y
 BEQ KFR9
 CMP #KNFCB+1
 BCS KFR9
* (ref - 1) * 32
 SEC
 SBC #$01
 ASL
 ASL
 ASL
 ASL
 ASL
 TAX
 LDA FUSE,X
 BEQ KFR9
 STX KFX
 CLC
 RTS
KFR9 LDA #EBADRF
 SEC
 RTS

* ==== KENTRY: KT0/KT1 -> the entry KWALK found ===
* KWALK leaves the directory block that holds the
* entry in KBLK, and the entry's number in that
* block in KWEOFF.  Entry n is at KBLK + 4 + 39n.
* For a volume KWEOFF is 0, and KBLK holds block 2
* (KWALK read it to match the name), so this finds
* the volume header - which has the access byte
* and the creation date where a file entry does.
KENTRY LDA #<KBLK+4
 STA KT0
 LDA #>KBLK
 STA KT1
 LDX KWEOFF
KEN1 CPX #$00
 BEQ KEN3
 LDA KT0
 CLC
 ADC #39
 STA KT0
 BCC KEN2
 INC KT1
KEN2 DEX
 BRA KEN1
KEN3 RTS

* ==== OPEN $C8 ===================================
* +1/+2 pathname  +3/+4 the 1,024-byte buffer
* +5 the ref number, returned
* $42 when eight files are open already.  $50 when
* the file is open already and may be written -
* ProDOS's rule: two opens of one file are allowed
* only when neither can change it.  $4B for a
* storage type this kernel does not read (Pascal
* areas, extended files).
KOPEN LDY #$01
 LDA (KPRM),Y
 STA KNAM
 INY
 LDA (KPRM),Y
 STA KNAM+1
 JSR KPARSE
 BCS KOP9
 JSR KWALK
 BCS KOP9
* ---- a storage type we read? -------------------
 LDA KWTYPE
 CMP #$F0
 BEQ KOP1
 CMP #$D0
 BEQ KOP1
 CMP #$40
 BCC KOP1
 LDA #ESTYPE
KOP9 RTS
* ---- open already? ------------------------------
* Matched by where the entry is, which never moves
* while a file is open (its key block can: a file
* that grows gets a new one).
KOP1 JSR KENTRY
 LDX #$00
KOP2 LDA FUSE,X
 BEQ KOP3
 LDA FDEV,X
 CMP KDEVX
 BNE KOP3
 LDA FEBLL,X
 CMP KWEBLL
 BNE KOP3
 LDA FEBLH,X
 CMP KWEBLH
 BNE KOP3
 LDA FEOFF,X
 CMP KWEOFF
 BNE KOP3
 LDY #$1E
 LDA (KT0),Y
 AND #$02
 BEQ KOP3
 LDA #EOPEN
 RTS
KOP3 TXA
 CLC
 ADC #$20
 TAX
 BNE KOP2
* ---- a free FCB ---------------------------------
KOP4 LDA FUSE,X
 BEQ KOP5
 TXA
 CLC
 ADC #$20
 TAX
 BNE KOP4
 LDA #ENFILE
 RTS
* ---- fill it ------------------------------------
* The ref number is the FCB's offset / 32, plus 1.
KOP5 STX KFX
 TXA
 LSR
 LSR
 LSR
 LSR
 LSR
 CLC
 ADC #$01
 STA FUSE,X
 LDY #$05
 STA (KPRM),Y
 LDA KDEVX
 STA FDEV,X
 LDA KWTYPE
 STA FSTOR,X
 LDA KWKEYL
 STA FKEYL,X
 LDA KWKEYH
 STA FKEYH,X
 LDA KWEBLL
 STA FEBLL,X
 LDA KWEBLH
 STA FEBLH,X
 LDA KWEOFF
 STA FEOFF,X
 LDY #$03
 LDA (KPRM),Y
 STA FBUFL,X
 INY
 LDA (KPRM),Y
 STA FBUFH,X
 STZ FMRK0,X
 STZ FMRK1,X
 STZ FMRK2,X
 STZ FNLMK,X
 STZ FDVAL,X
 STZ FIVAL,X
 STZ FDIRT,X
 LDY #$1E
 LDA (KT0),Y
 STA FACC,X
* blocks used, for WRITE to keep up to date
 LDY #$13
 LDA (KT0),Y
 STA FBLKL,X
 INY
 LDA (KT0),Y
 STA FBLKH,X
* ---- the end of file ----------------------------
* A file's, and a subdirectory's, is in its entry.
* The volume directory has no entry, so its length
* is counted: the blocks in its chain, times 512.
 LDA KWTYPE
 CMP #$F0
 BEQ KOP7
 LDY #$15
 LDA (KT0),Y
 STA FEOF0,X
 INY
 LDA (KT0),Y
 STA FEOF1,X
 INY
 LDA (KT0),Y
 STA FEOF2,X
 LDA #$00
 RTS
KOP7 JSR KVCNT
 BCS KOP8
 LDX KFX
 STZ FEOF0,X
 LDA KCNL
 ASL
 STA FEOF1,X
 LDA KCNH
 ROL
 STA FEOF2,X
 LDA #$00
 RTS
* the chain could not be read: no file after all
KOP8 LDX KFX
 STZ FUSE,X
 RTS

* ---- KVCNT: the volume directory's blocks ------
* Follows the chain from the key block KWKEY on
* device KDEVX, through KBLK.  Out: KCNL/H = the
* count; or carry set, A = the error.
KVCNT STZ KCNL
 STZ KCNH
 LDA KWKEYL
 STA KBLKL
 LDA KWKEYH
 STA KBLKH
 LDA #<KBLK
 STA KBUF
 LDA #>KBLK
 STA KBUF+1
KVC1 LDX KDEVX
 LDA #$01
 JSR KDIO
 BCS KVC9
 INC KCNL
 BNE KVC2
 INC KCNH
KVC2 LDA KBLK+2
 STA KBLKL
 LDA KBLK+3
 STA KBLKH
 ORA KBLKL
 BNE KVC1
 CLC
KVC9 RTS

* ==== NEWLINE $C9 ================================
* +1 ref  +2 mask  +3 character
* While the mask is not zero, READ stops after a
* byte whose value ANDed with the mask equals the
* character.  A mask of zero turns it off.
KNEWLN JSR KFREF
 BCS KNL9
 LDY #$02
 LDA (KPRM),Y
 STA FNLMK,X
 INY
 LDA (KPRM),Y
 STA FNLCH,X
 LDA #$00
KNL9 RTS

* ==== GET_EOF $D1 ================================
* +1 ref  +2/+3/+4 the end of file, returned
KGTEOF JSR KFREF
 BCS KGE9
 LDY #$02
 LDA FEOF0,X
 STA (KPRM),Y
 INY
 LDA FEOF1,X
 STA (KPRM),Y
 INY
 LDA FEOF2,X
 STA (KPRM),Y
 LDA #$00
KGE9 RTS

* ==== GET_MARK $CF ===============================
* +1 ref  +2/+3/+4 the mark, returned
KGTMRK JSR KFREF
 BCS KGM9
 LDY #$02
 LDA FMRK0,X
 STA (KPRM),Y
 INY
 LDA FMRK1,X
 STA (KPRM),Y
 INY
 LDA FMRK2,X
 STA (KPRM),Y
 LDA #$00
KGM9 RTS

* ==== SET_MARK $CE ===============================
* +1 ref  +2/+3/+4 the new mark
* Anywhere from 0 to the end of file; past it is
* $4D.  Nothing is read here: the next READ finds
* the block the mark is now in (KLOAD).
KSTMRK JSR KFREF
 BCS KSM9
 LDY #$04
 LDA (KPRM),Y
 CMP FEOF2,X
 BCC KSM2
 BNE KSM8
 DEY
 LDA (KPRM),Y
 CMP FEOF1,X
 BCC KSM2
 BNE KSM8
 DEY
 LDA (KPRM),Y
 CMP FEOF0,X
 BCC KSM2
 BNE KSM8
KSM2 LDY #$02
 LDA (KPRM),Y
 STA FMRK0,X
 INY
 LDA (KPRM),Y
 STA FMRK1,X
 INY
 LDA (KPRM),Y
 STA FMRK2,X
 LDA #$00
 RTS
KSM8 LDA #EPOSN
KSM9 RTS

