* KRW.S  CLOSE, READ, WRITE, and the machinery
* that moves a file's blocks through its buffer:
* KLOAD, the index loaders, the write-backs and
* KPLACE, which gives a new block its place in
* the file - growing the file from seedling to
* sapling to tree as it goes.  Stages 2 and 3.
*
* WHAT IS HELD, AND WHEN IT GOES BACK TO DISK
* An open file's buffer holds one data block (the
* first half) and one index block (the second).
* FDIRT says which of them has changed, and
* whether the directory entry must be rewritten:
*   bit 0  the data half      written back when
*          KLOAD moves to another block, and at
*          CLOSE
*   bit 1  the index half     when another index
*          is loaded over it, and at CLOSE
*   bit 2  the entry          at CLOSE: EOF,
*          blocks used, key block, storage type,
*          and the modified date
* which is what ProDOS does, so a program that
* writes a record at a time pays one block write
* per 512 bytes, not one per record.
*
* A NEW BLOCK.  Writing into a hole - past the end,
* or a block never written - puts the bytes in the
* data half like any other.  Only when that half
* goes back to disk does it get a block of its own
* (KDFLUSH -> KALLOC), and KPLACE writes that
* block's number into the index - making an index,
* or a master index, first if the file is about to
* outgrow what it is.

* ==== CLOSE $CC ==================================
* +1 ref; 0 closes every open file.  Each file's
* buffer and entry are written back first
* (KFLUSHF).  A file closes even if that fails,
* as under ProDOS, and the call reports the error:
* the last one, when closing them all.
KCLOSE LDY #$01
 LDA (KPRM),Y
 BNE KCL3
* KCLALL: every open file, written back and closed.
* QUIT's first act too (KCALL4.S).
KCLALL STZ KTMP
 LDX #$00
KCL1 LDA FUSE,X
 BEQ KCL2
 STX KFX
 JSR KFLUSHF
 BCC KCL1A
 STA KTMP
KCL1A LDX KFX
 STZ FUSE,X
KCL2 TXA
 CLC
 ADC #$20
 TAX
 BNE KCL1
 LDA KTMP
 RTS
KCL3 JSR KFREF
 BCS KCL9
 JSR KFLUSHF
 LDX KFX
 STZ FUSE,X
KCL9 RTS

* ==== KRUN: this pass's share of a READ/WRITE ====
* In:  X = KFX, the mark, KREQ = what is left of
*      the request
* Out: KPTR -> the mark's byte in the data half,
*      KRUN = the bytes from there to the block's
*      end, or the request if that is fewer
KRUN LDA FMRK1,X
 AND #$01
 STA KT1
 LDA FMRK0,X
 STA KT0
 CLC
 ADC FBUFL,X
 STA KPTR
 LDA KT1
 ADC FBUFH,X
 STA KPTR+1
 SEC
 LDA #$00
 SBC KT0
 STA KRUNL
 LDA #$02
 SBC KT1
 STA KRUNH
 CMP KREQH
 BCC KRN9
 BNE KRN1
 LDA KRUNL
 CMP KREQL
 BCC KRN9
KRN1 LDA KREQL
 STA KRUNL
 LDA KREQH
 STA KRUNH
KRN9 RTS

* ==== KADV: KT0/KT1 bytes moved ==================
* The mark goes on by them, the count moved goes
* up and the request down.  X = KFX on return.
KADV LDX KFX
 CLC
 LDA FMRK0,X
 ADC KT0
 STA FMRK0,X
 LDA FMRK1,X
 ADC KT1
 STA FMRK1,X
 LDA FMRK2,X
 ADC #$00
 STA FMRK2,X
 CLC
 LDA KTRNL
 ADC KT0
 STA KTRNL
 LDA KTRNH
 ADC KT1
 STA KTRNH
 SEC
 LDA KREQL
 SBC KT0
 STA KREQL
 LDA KREQH
 SBC KT1
 STA KREQH
 RTS

* ==== KRWSET: what READ and WRITE both take ======
* +2/+3 the caller's memory -> KNAM, +4/+5 the
* count -> KREQ; KTRN = 0.
KRWSET LDY #$02
 LDA (KPRM),Y
 STA KNAM
 INY
 LDA (KPRM),Y
 STA KNAM+1
 INY
 LDA (KPRM),Y
 STA KREQL
 INY
 LDA (KPRM),Y
 STA KREQH
 STZ KTRNL
 STZ KTRNH
 RTS

* ==== the count moved, whatever happened =========
* READ's and WRITE's one exit: +6/+7, then A.
KRWX PHA
 LDY #$06
 LDA KTRNL
 STA (KPRM),Y
 INY
 LDA KTRNH
 STA (KPRM),Y
 PLA
 RTS

* ==== READ $CA ===================================
* +1 ref  +2/+3 where to  +4/+5 how many
* +6/+7 how many were read, returned
* Reads from the mark, never past the end of file:
* a request for more than is left reads what is
* left, with no error.  Nothing left at all is $4C
* with 0 read.  In newline mode the read also ends
* just after the newline character.
*
* One pass of the loop is one block's share: KLOAD
* puts the block the mark is in into the buffer,
* and the bytes from the mark to the block's end -
* or fewer, if the request ends first - are copied.
*   KPTR  in the file buffer, KNAM  the caller's
*   KT3/KT4 bytes left in this pass
*   KT5/KT6 the newline mask and character
KREAD JSR KFREF
 BCS KRD0
 LDA FACC,X
 AND #$01
 BNE KRD1
 LDA #EACCES
KRD0 RTS
KRD1 JSR KRWSET
* ---- what is left: EOF - mark, into KT0-KT2 ----
 LDX KFX
 SEC
 LDA FEOF0,X
 SBC FMRK0,X
 STA KT0
 LDA FEOF1,X
 SBC FMRK1,X
 STA KT1
 LDA FEOF2,X
 SBC FMRK2,X
 STA KT2
 ORA KT1
 ORA KT0
 BNE KRD2
 LDA #EEOF
 BRA KRWX
* the request, cut to what is left (only if what
* is left is under 64K can it be smaller)
KRD2 LDA KT2
 BNE KRD3
 LDA KT1
 CMP KREQH
 BCC KRD2A
 BNE KRD3
 LDA KT0
 CMP KREQL
 BCS KRD3
KRD2A LDA KT0
 STA KREQL
 LDA KT1
 STA KREQH
* ---- one block's share per pass ----------------
KRD3 LDA KREQL
 ORA KREQH
 BNE KRD4
KRD3A LDA #$00
 BRA KRWX
KRD4 JSR KLOAD
 BCS KRWX
 LDX KFX
 JSR KRUN
* ---- copy the run, watching for the newline ----
 LDA KRUNL
 STA KT3
 LDA KRUNH
 STA KT4
 LDA FNLMK,X
 STA KT5
 LDA FNLCH,X
 STA KT6
 STZ KNLHIT
KRC1 LDA (KPTR)
 STA (KNAM)
 INC KPTR
 BNE KRC2
 INC KPTR+1
KRC2 INC KNAM
 BNE KRC3
 INC KNAM+1
KRC3 LDY KT3
 BNE KRC4
 DEC KT4
KRC4 DEC KT3
* A is still the byte: none of that touched it
 LDY KT5
 BEQ KRC5
 AND KT5
 CMP KT6
 BNE KRC5
 INC KNLHIT
 BRA KRC6
KRC5 LDA KT3
 ORA KT4
 BNE KRC1
* ---- what the run moved: run - bytes left ------
KRC6 SEC
 LDA KRUNL
 SBC KT3
 STA KT0
 LDA KRUNH
 SBC KT4
 STA KT1
 JSR KADV
 LDA KNLHIT
 BNE KRD3A
 BRA KRD3

* ==== WRITE $CB ==================================
* +1 ref  +2/+3 from where  +4/+5 how many
* +6/+7 how many were written, returned
* Writes at the mark, through the data half, and
* moves the end of file out past what it wrote.
* A directory is never written this way ($4E),
* nor a file whose access has no write bit.
KWRITE JSR KFREF
 BCS KWR0
 LDA FSTOR,X
 CMP #$D0
 BCS KWR0A
 LDA FACC,X
 AND #$02
 BNE KWR1
KWR0A LDA #EACCES
KWR0 RTS
KWR1 JSR KRWSET
KWR2 LDA KREQL
 ORA KREQH
 BNE KWR3
 LDA #$00
* (KRWX is past a branch's reach)
KWRX JMP KRWX
KWR3 JSR KLOAD
 BCS KWRX
 LDX KFX
 JSR KRUN
* ---- copy the run into the data half -----------
 LDA KRUNL
 STA KT3
 LDA KRUNH
 STA KT4
KWC1 LDA (KNAM)
 STA (KPTR)
 INC KPTR
 BNE KWC2
 INC KPTR+1
KWC2 INC KNAM
 BNE KWC3
 INC KNAM+1
KWC3 LDY KT3
 BNE KWC4
 DEC KT4
KWC4 DEC KT3
 LDA KT3
 ORA KT4
 BNE KWC1
 LDA KRUNL
 STA KT0
 LDA KRUNH
 STA KT1
 JSR KADV
* the data half and the entry have changed
 LDA FDIRT,X
 ORA #$05
 STA FDIRT,X
* ---- past the end?  Then the end moves ---------
 LDA FEOF2,X
 CMP FMRK2,X
 BCC KWE1
 BNE KWE2
 LDA FEOF1,X
 CMP FMRK1,X
 BCC KWE1
 BNE KWE2
 LDA FEOF0,X
 CMP FMRK0,X
 BCC KWE1
KWE2 JMP KWR2
KWE1 LDA FMRK0,X
 STA FEOF0,X
 LDA FMRK1,X
 STA FEOF1,X
 LDA FMRK2,X
 STA FEOF2,X
 JMP KWR2

* ==== KLOAD: the mark's block into the buffer ====
* In:  KFX = the open file
* Out: carry clear, the buffer's first half holds
*      the block the mark is in; or carry set and
*      A = the error.
* If the data half holds a changed block, it goes
* back to disk first (KDFLUSH).  Uses KBUF and the
* kernel's own bytes - not KNAM, KT3-KT6 or KPTR,
* which READ and WRITE are holding.
KLOAD LDX KFX
 LDA FMRK2,X
 LSR
 STA KBIH
 LDA FMRK1,X
 ROR
 STA KBIL
* already there?
 LDA FDVAL,X
 BEQ KLD1
 LDA FDBIL,X
 CMP KBIL
 BNE KLD0
 LDA FDBIH,X
 CMP KBIH
 BNE KLD0
 CLC
 RTS
* ---- another block: the one held goes back -----
KLD0 JSR KDFLUSH
 BCS KLD9
KLD1 LDX KFX
 LDA FSTOR,X
 CMP #$D0
 BCC KLD2
 JMP KLDIR
KLD2 CMP #$30
 BEQ KLTREE
 CMP #$20
 BEQ KLSAP
* ---- seedling: block 0 is the key block --------
 LDA KBIL
 ORA KBIH
 BNE KLHOLE
 LDA FKEYL,X
 STA KBLKL
 LDA FKEYH,X
 STA KBLKH
 BRA KLRD
* ---- sapling: the key block is the index -------
* Only blocks 0-255 exist; past them is a hole.
KLSAP LDA KBIH
 BNE KLHOLE
 JSR KSAPIX
 BCC KLDATA
KLD9 RTS
* ---- tree: the master index names the index ----
KLTREE JSR KTREIX
 BCS KLD9
* ---- the data block's number, from the index ---
KLDATA LDX KFX
 JSR KIXPTR
 LDY KBIL
 LDA (KBUF),Y
 STA KBLKL
 INC KBUF+1
 LDA (KBUF),Y
 STA KBLKH
 ORA KBLKL
 BEQ KLHOLE
* ---- read it into the first half ---------------
KLRD LDA FBUFL,X
 STA KBUF
 LDA FBUFH,X
 STA KBUF+1
 LDA KBLKL
 STA FDBKL,X
 LDA KBLKH
 STA FDBKH,X
 LDA FDEV,X
 TAX
 LDA #$01
 JSR KDIO
 BCC KLOK
 LDX KFX
 STZ FDVAL,X
 RTS
* ---- a hole: 512 zeros, and no block yet -------
KLHOLE LDA FBUFL,X
 STA KBUF
 LDA FBUFH,X
 STA KBUF+1
 STZ FDBKL,X
 STZ FDBKH,X
 JSR KZERO
KLOK LDX KFX
 LDA KBIL
 STA FDBIL,X
 LDA KBIH
 STA FDBIH,X
 LDA #$01
 STA FDVAL,X
 CLC
 RTS

* ---- KLDIR: a directory's blocks are a chain ---
* Reading straight on (block n+1 after block n) is
* one step from the block in hand; anything else
* walks from the key block.  A chain that ends
* before the mark's block is a damaged directory,
* $51: its length says there are more blocks.
KLDIR LDA FBUFL,X
 STA KBUF
 LDA FBUFH,X
 STA KBUF+1
 LDA FDVAL,X
 BEQ KLD5
 LDA FDBIL,X
 CLC
 ADC #$01
 STA KCNL
 LDA FDBIH,X
 ADC #$00
 CMP KBIH
 BNE KLD5
 LDA KCNL
 CMP KBIL
 BNE KLD5
* the next one, named in the block in hand
 STZ KCNL
 STZ KCNH
 BRA KLD7
KLD5 LDA FKEYL,X
 STA KBLKL
 LDA FKEYH,X
 STA KBLKH
 LDA KBIL
 STA KCNL
 LDA KBIH
 STA KCNH
KLD6 LDX KFX
 LDA FDEV,X
 TAX
 LDA #$01
 JSR KDIO
 BCS KLDE
 LDA KCNL
 ORA KCNH
 BEQ KLOK
 LDA KCNL
 BNE KLD6A
 DEC KCNH
KLD6A DEC KCNL
KLD7 LDY #$02
 LDA (KBUF),Y
 STA KBLKL
 INY
 LDA (KBUF),Y
 STA KBLKH
 ORA KBLKL
 BNE KLD6
 LDA #EDIRDM
KLDE LDX KFX
 STZ FDVAL,X
 SEC
 RTS

* ==== the index half =============================
* KIXPTR: KBUF -> the index half (X = KFX)
KIXPTR LDA FBUFL,X
 STA KBUF
 LDA FBUFH,X
 CLC
 ADC #$02
 STA KBUF+1
 RTS

* KSAPIX: a sapling's index (its key block) into
* the index half, if it is not there already.
KSAPIX STZ KMIX
 LDX KFX
 LDA FKEYL,X
 STA KIXL
 LDA FKEYH,X
 STA KIXH
 BRA KGETIX

* (KTREIX's own exits, within its branches' reach)
KTI8 CLC
KTI9 RTS

* KTREIX: a tree's index for block KBI - master
* entry KBIH - into the index half.  If it is not
* there already, the master is read through KBLK
* to find it.
KTREIX LDA KBIH
 STA KMIX
 LDX KFX
 LDA FIVAL,X
 BEQ KTI1
 LDA FIMIX,X
 CMP KMIX
 BEQ KTI8
KTI1 LDA FKEYL,X
 STA KBLKL
 LDA FKEYH,X
 STA KBLKH
 JSR KRDK
 BCS KTI9
 LDY KMIX
 LDA KBLK,Y
 STA KIXL
 LDA KBLK+256,Y
 STA KIXH
 LDX KFX
 STZ FIVAL,X

* KGETIX: index block KIX (0 = a hole: zeros), for
* master entry KMIX, into the index half - after
* writing back the one there if it changed.
KGETIX LDX KFX
 LDA FIVAL,X
 BEQ KGI1
 LDA FIMIX,X
 CMP KMIX
 BEQ KGI8
KGI1 JSR KIFLUSH
 BCS KGI9
 LDX KFX
 STZ FIVAL,X
 JSR KIXPTR
 LDA KIXL
 ORA KIXH
 BNE KGI2
 JSR KZERO
 BRA KGI3
KGI2 LDA KIXL
 STA KBLKL
 LDA KIXH
 STA KBLKH
 LDA FDEV,X
 TAX
 LDA #$01
 JSR KDIO
 BCS KGI9
KGI3 LDX KFX
 LDA KMIX
 STA FIMIX,X
 LDA KIXL
 STA FIXBL,X
 LDA KIXH
 STA FIXBH,X
 LDA #$01
 STA FIVAL,X
KGI8 CLC
KGI9 RTS

* ---- KRDK / KWRK: block KBLKL/H through KBLK ---
* on the open file's device
KRDK LDA #$01
 BRA KRWK
KWRK LDA #$02
KRWK PHA
 LDA #<KBLK
 STA KBUF
 LDA #>KBLK
 STA KBUF+1
 LDX KFX
 LDA FDEV,X
 TAX
 PLA
 JMP KDIO

* ==== KIFLUSH: the index half, if it changed =====
KIFLUSH LDX KFX
 LDA FDIRT,X
 AND #$02
 BEQ KIF8
 JSR KIXPTR
 LDA FIXBL,X
 STA KBLKL
 LDA FIXBH,X
 STA KBLKH
 LDA FDEV,X
 TAX
 LDA #$02
 JSR KDIO
 BCS KIF9
 LDX KFX
 LDA FDIRT,X
 AND #$FD
 STA FDIRT,X
KIF8 LDA #$00
 CLC
KIF9 RTS

* ==== KDFLUSH: the data half, if it changed ======
* A block that has none yet (FDBK = 0) gets one
* now, and KPLACE puts it in the file.  KBIL/H are
* KLOAD's, so they are kept aside while the block
* being written back borrows them.
KDFLUSH LDX KFX
 LDA FDIRT,X
 AND #$01
 BEQ KIF8
 LDA KBIL
 STA KSVBL
 LDA KBIH
 STA KSVBH
 LDA FDBKL,X
 ORA FDBKH,X
 BNE KDF2
* ---- a block of its own ------------------------
 LDA FDEV,X
 STA KDEVX
 JSR KALLOC
 BCS KDF9
 LDX KFX
 LDA KNBL
 STA FDBKL,X
 LDA KNBH
 STA FDBKH,X
 LDA FDBIL,X
 STA KBIL
 LDA FDBIH,X
 STA KBIH
 JSR KBUMP
 JSR KPLACE
 BCS KDF9
* ---- and out to it -----------------------------
KDF2 LDX KFX
 LDA FBUFL,X
 STA KBUF
 LDA FBUFH,X
 STA KBUF+1
 LDA FDBKL,X
 STA KBLKL
 LDA FDBKH,X
 STA KBLKH
 LDA FDEV,X
 TAX
 LDA #$02
 JSR KDIO
 BCS KDF9
 LDX KFX
 LDA FDIRT,X
 AND #$FE
 STA FDIRT,X
 LDA #$00
 CLC
* KBIL/H back; LDY/STY leave A and the carry be
KDF9 LDY KSVBL
 STY KBIL
 LDY KSVBH
 STY KBIH
 RTS

* ---- KBUMP: one more block used ----------------
KBUMP LDX KFX
 INC FBLKL,X
 BNE KBU1
 INC FBLKH,X
KBU1 LDA FDIRT,X
 ORA #$04
 STA FDIRT,X
 RTS

* ==== KPLACE: block FDBK becomes the file's KBI ==
* Growing the file as it must:
*   seedling, any block but 0: a new index block,
*     whose entry 0 is the old key block -> sapling
*   sapling, a block past 255: a new master index
*     block, whose entry 0 is the old index -> tree
*     (the index half, if loaded, is still right:
*     it is master entry 0's index)
*   tree: the index for master entry KBIH - made
*     now if that entry is 0
* and then the block's number goes in the index
* half, which is marked changed.  Every new index
* or master block counts in "blocks used".
KPLACE LDX KFX
 LDA FSTOR,X
 CMP #$10
 BNE KPL2
* ---- seedling -> sapling ------------------------
 JSR KALLOC
 BCS KPL9
 JSR KIFLUSH
 BCS KPL9
 LDX KFX
 JSR KIXPTR
 JSR KZERO
 LDX KFX
 JSR KIXPTR
 LDA FKEYL,X
 STA (KBUF)
 INC KBUF+1
 LDA FKEYH,X
 STA (KBUF)
 LDA KNBL
 STA FKEYL,X
 STA FIXBL,X
 LDA KNBH
 STA FKEYH,X
 STA FIXBH,X
 LDA #$20
 STA FSTOR,X
 STZ FIMIX,X
 LDA #$01
 STA FIVAL,X
 LDA FDIRT,X
 ORA #$02
 STA FDIRT,X
 JSR KBUMP
KPL2 LDA FSTOR,X
 CMP #$20
 BNE KPL4
 LDA KBIH
 BNE KPL3
* ---- a sapling block ----------------------------
 JSR KSAPIX
 BCS KPL9
 JMP KPLSET
KPL9 RTS
* ---- sapling -> tree ----------------------------
KPL3 JSR KALLOC
 BCS KPL9
 LDA #<KBLK
 STA KBUF
 LDA #>KBLK
 STA KBUF+1
 JSR KZERO
 LDX KFX
 LDA FKEYL,X
 STA KBLK
 LDA FKEYH,X
 STA KBLK+256
 LDA KNBL
 STA KBLKL
 STA FKEYL,X
 LDA KNBH
 STA KBLKH
 STA FKEYH,X
 LDA #$30
 STA FSTOR,X
 JSR KWRK
 BCS KPL9
 JSR KBUMP
* ---- a tree block -------------------------------
KPL4 JSR KTREIX
 BCS KPL9
 LDX KFX
 LDA FIXBL,X
 ORA FIXBH,X
 BNE KPLSET
* the index is a hole: it gets a block, and the
* master (read again: KALLOC may have used KBLK)
* gets its number
 JSR KALLOC
 BCS KPL9
 LDX KFX
 LDA FKEYL,X
 STA KBLKL
 LDA FKEYH,X
 STA KBLKH
 JSR KRDK
 BCS KPL9
 LDY KMIX
 LDA KNBL
 STA KBLK,Y
 LDA KNBH
 STA KBLK+256,Y
 JSR KWRK
 BCS KPL9
 LDX KFX
 LDA KNBL
 STA FIXBL,X
 LDA KNBH
 STA FIXBH,X
 JSR KBUMP
* ---- the entry, in the index half ---------------
KPLSET LDX KFX
 JSR KIXPTR
 LDY KBIL
 LDA FDBKL,X
 STA (KBUF),Y
 INC KBUF+1
 LDA FDBKH,X
 STA (KBUF),Y
 LDA FDIRT,X
 ORA #$02
 STA FDIRT,X
 CLC
 RTS

* ==== KFLUSHF: everything an open file holds =====
* The data half, the index half, then the entry:
* storage type, key block, blocks used, EOF, and
* the modified date and time - after calling the
* clock at $BF06, as ProDOS does.
KFLUSHF JSR KDFLUSH
 BCS KFF0
 JSR KIFLUSH
 BCC KFF2
KFF0 RTS
KFF2 LDX KFX
 LDA FDIRT,X
 AND #$04
 BEQ KFF8
 JSR DATETIME
 LDX KFX
 LDA FEBLL,X
 STA KBLKL
 LDA FEBLH,X
 STA KBLKH
 LDA FEOFF,X
 STA KWEOFF
 JSR KRDK
 BCS KFF9
 JSR KENTRY
 LDX KFX
 LDA (KT0)
 AND #$0F
 ORA FSTOR,X
 STA (KT0)
 LDY #$11
 LDA FKEYL,X
 STA (KT0),Y
 INY
 LDA FKEYH,X
 STA (KT0),Y
 INY
 LDA FBLKL,X
 STA (KT0),Y
 INY
 LDA FBLKH,X
 STA (KT0),Y
 INY
 LDA FEOF0,X
 STA (KT0),Y
 INY
 LDA FEOF1,X
 STA (KT0),Y
 INY
 LDA FEOF2,X
 STA (KT0),Y
* the backup bit: ProDOS sets it whenever a file
* changes
 LDY #$1E
 LDA (KT0),Y
 ORA #$20
 STA (KT0),Y
 LDY #$21
 LDX #$00
KFF1 LDA DATELO,X
 STA (KT0),Y
 INY
 INX
 CPX #$04
 BCC KFF1
 JSR KWRK
 BCS KFF9
 LDX KFX
 LDA FDIRT,X
 AND #$FB
 STA FDIRT,X
KFF8 LDA #$00
 CLC
KFF9 RTS

* ---- KZERO: 512 zeros at KBUF ------------------
* Leaves KBUF+1 two pages on; X is lost.
KZERO LDA #$00
 TAY
 LDX #$02
KZ1 STA (KBUF),Y
 INY
 BNE KZ1
 INC KBUF+1
 DEX
 BNE KZ1
 RTS
