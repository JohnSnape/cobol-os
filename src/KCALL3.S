* KCALL3.S  the calls that change a directory or
* free blocks: SET_EOF, CREATE, DESTROY, RENAME;
* and KTRUNC, which frees a file's blocks.  Stage 3.
*
* KBLK IS SHARED with the bitmap (KBMAP.S): a
* directory block read into it is used before the
* next KALLOC or KFREEB, never after.  An index or
* master index whose entries are being freed is
* first copied up into the language card (KIDC,
* KMSC), where the bitmap cannot touch it.

* ---- KCPUP / KCPDN: KBLK to and from (KPTR) ----
* KPTR -> 512 bytes in the language card.
KCPUP LDY #$00
KCU1 LDA KBLK,Y
 STA (KPTR),Y
 INY
 BNE KCU1
 INC KPTR+1
KCU2 LDA KBLK+256,Y
 STA (KPTR),Y
 INY
 BNE KCU2
 RTS
KCPDN LDY #$00
KCD1 LDA (KPTR),Y
 STA KBLK,Y
 INY
 BNE KCD1
 INC KPTR+1
KCD2 LDA (KPTR),Y
 STA KBLK+256,Y
 INY
 BNE KCD2
 RTS

* ---- KISOPEN: is KWALK's find an open file? ----
* Compared by where its entry is - the one thing
* about a file that never changes while it is
* open.  Out: carry set, A = $50, if it is.
KISOPEN LDX #$00
KIO1 LDA FUSE,X
 BEQ KIO2
 LDA FDEV,X
 CMP KDEVX
 BNE KIO2
 LDA FEBLL,X
 CMP KWEBLL
 BNE KIO2
 LDA FEBLH,X
 CMP KWEBLH
 BNE KIO2
 LDA FEOFF,X
 CMP KWEOFF
 BNE KIO2
 LDA #EOPEN
 SEC
 RTS
KIO2 TXA
 CLC
 ADC #$20
 TAX
 BNE KIO1
 CLC
 RTS

* ---- KPATHP: the path at (KPRM)+Y, parsed ------
KPATHP LDA (KPRM),Y
 STA KNAM
 INY
 LDA (KPRM),Y
 STA KNAM+1
 JMP KPARSE

* ==== SET_EOF $D0 ================================
* +1 ref  +2/+3/+4 the new end of file
* Longer: only the EOF moves; the new space reads
* as zeros, a hole, until written.  Shorter: what
* the buffer holds goes back first, then every
* block wholly past the new end is freed (index
* blocks too, when nothing they name is kept),
* the buffer is forgotten, and the mark comes back
* to the new end if it was past it.  Block 0 is
* always kept.  The storage type does not shrink.
KSTEOF JSR KFREF
 BCS KSE9
 LDA FSTOR,X
 CMP #$D0
 BCS KSEAC
 LDA FACC,X
 AND #$02
 BNE KSE1
KSEAC LDA #EACCES
KSE9 RTS
KSE1 LDY #$04
 LDA (KPRM),Y
 CMP FEOF2,X
 BCC KSE3
 BNE KSE2
 DEY
 LDA (KPRM),Y
 CMP FEOF1,X
 BCC KSE3
 BNE KSE2
 DEY
 LDA (KPRM),Y
 CMP FEOF0,X
 BCC KSE3
KSE2 JSR KSESET
 LDA #$00
 RTS
* ---- shorter ------------------------------------
KSE3 JSR KDFLUSH
 BCS KSE9
 JSR KIFLUSH
 BCS KSE9
* keep = (new EOF + 511) / 512, and at least 1
 LDY #$02
 LDA (KPRM),Y
 CLC
 ADC #$FF
 INY
 LDA (KPRM),Y
 ADC #$01
 STA KTMP
 INY
 LDA (KPRM),Y
 ADC #$00
 LSR
 STA KKPH
 LDA KTMP
 ROR
 STA KKPL
 ORA KKPH
 BNE KSE4
 INC KKPL
KSE4 LDX KFX
 LDA FSTOR,X
 STA KTSTOR
 LDA FKEYL,X
 STA KTKEYL
 LDA FKEYH,X
 STA KTKEYH
 LDA FDEV,X
 STA KDEVX
 JSR KTRUNC
 BCS KSE9
 JSR KSHRNK
 BCS KSE9
 LDX KFX
 SEC
 LDA FBLKL,X
 SBC KFRCL
 STA FBLKL,X
 LDA FBLKH,X
 SBC KFRCH
 STA FBLKH,X
 STZ FDVAL,X
 STZ FIVAL,X
 JSR KSESET
* the mark, if past the new end, comes back to it
 LDA FEOF2,X
 CMP FMRK2,X
 BCC KSE5
 BNE KSE8
 LDA FEOF1,X
 CMP FMRK1,X
 BCC KSE5
 BNE KSE8
 LDA FEOF0,X
 CMP FMRK0,X
 BCS KSE8
KSE5 LDA FEOF0,X
 STA FMRK0,X
 LDA FEOF1,X
 STA FMRK1,X
 LDA FEOF2,X
 STA FMRK2,X
KSE8 LDA #$00
 RTS
* ---- KSHRNK: the storage type comes down -------
* As ProDOS does it: a tree that keeps no more
* than 256 blocks becomes a sapling (its master
* goes, index 0 is the key), and a sapling that
* keeps one block becomes a seedling (its index
* goes, data block 0 is the key).  Not when that
* first block is a hole: there is no block to make
* the key, and the type stays.  The freed block
* counts in KFRC with the rest.
KSHRNK LDX KFX
 LDA FSTOR,X
 CMP #$30
 BNE KSH2
 LDA KKPH
 BEQ KSH1
 CMP #$01
 BNE KSH8
 LDA KKPL
 BNE KSH8
KSH1 JSR KSHONE
 BCS KSH9
 LDX KFX
 LDA #$20
 STA FSTOR,X
KSH2 CMP #$20
 BNE KSH8
 LDA KKPH
 BNE KSH8
 LDA KKPL
 CMP #$02
 BCS KSH8
 JSR KSHONE
 BCS KSH9
 LDX KFX
 LDA #$10
 STA FSTOR,X
KSH8 CLC
KSH9 RTS
* KSHONE: entry 0 of the key block becomes the key
* and the old key is freed.  Carry set: an error.
* If entry 0 is a hole the type must not change,
* so KSHONE drops KSHRNK's return address and goes
* straight back to KSHRNK's caller, carry clear.
KSHONE LDX KFX
 LDA FKEYL,X
 STA KBLKL
 STA KFBL
 LDA FKEYH,X
 STA KBLKH
 STA KFBH
 JSR KRDK
 BCS KSO9
 LDA KBLK
 ORA KBLK+256
 BEQ KSO8
 LDX KFX
 LDA KBLK
 STA FKEYL,X
 LDA KBLK+256
 STA FKEYH,X
 JMP KFREEB
* a hole: drop KSHRNK's frame and stop there
KSO8 PLA
 PLA
 CLC
KSO9 RTS

* KSESET: the EOF from the parameters; X = KFX
KSESET LDX KFX
 LDY #$02
 LDA (KPRM),Y
 STA FEOF0,X
 INY
 LDA (KPRM),Y
 STA FEOF1,X
 INY
 LDA (KPRM),Y
 STA FEOF2,X
 LDA FDIRT,X
 ORA #$04
 STA FDIRT,X
 RTS

* ==== KTRUNC: free a file's blocks from KKP on ===
* In:  KTSTOR, KTKEY = the file, KDEVX its device,
*      KKPL/H = how many blocks to keep (0 = free
*      everything, the key block and every index
*      with it: DESTROY)
* Out: KFRC = blocks freed; carry set, A = error.
KTRUNC STZ KFRCL
 STZ KFRCH
 LDA KTSTOR
 CMP #$10
 BNE KTR2
* ---- seedling: its block goes only with all ----
 LDA KKPL
 ORA KKPH
 BNE KTR0
KTRK LDA KTKEYL
 STA KFBL
 LDA KTKEYH
 STA KFBH
 JMP KFREEB
* (nothing to free, within the branches' reach)
KTR0 LDA #$00
 CLC
KTRE RTS
KTR2 CMP #$20
 BNE KTR4
* ---- sapling: from entry KKP of its index ------
 LDA KKPH
 BNE KTR0
 LDA KTKEYL
 STA KIXL
 LDA KTKEYH
 STA KIXH
 STZ KTWHOL
 LDA KKPL
 STA KTFROM
 BNE KTR3
 INC KTWHOL
KTR3 JMP KTRIX
KTR4 CMP #$30
 BEQ KTR5
 JMP KTRDIR
* ---- tree: the master, copied up ---------------
KTR5 LDA KTKEYL
 STA KBLKL
 LDA KTKEYH
 STA KBLKH
 JSR KBIO1
 BCS KTRE
 LDA #<KMSC
 STA KPTR
 LDA #>KMSC
 STA KPTR+1
 JSR KCPUP
 STZ KTM
 STZ KMCHG
* each master entry m names the index of blocks
* m*256 to m*256+255: kept whole below KKPH, cut
* from KKPL at KKPH, freed whole above it
KTR6 LDY KTM
 LDA KMSC,Y
 STA KIXL
 LDA KMSC+256,Y
 STA KIXH
 ORA KIXL
 BEQ KTR7
 LDA KTM
 CMP KKPH
 BCC KTR7
 BEQ KTR6A
 STZ KTFROM
 LDA #$01
 STA KTWHOL
 BRA KTR6B
KTR6A STZ KTWHOL
 LDA KKPL
 STA KTFROM
 BNE KTR6B
 INC KTWHOL
KTR6B JSR KTRIX
 BCS KTR9
 LDA KTWHOL
 BEQ KTR7
 LDY KTM
 LDA #$00
 STA KMSC,Y
 STA KMSC+256,Y
 LDA #$01
 STA KMCHG
KTR7 INC KTM
 LDA KTM
 CMP #$80
 BCC KTR6
* the master: freed with everything, or rewritten
 LDA KKPL
 ORA KKPH
 BNE KTR7A
 JMP KTRK
KTR7A LDA KMCHG
 BEQ KTR8
 LDA #<KMSC
 STA KPTR
 LDA #>KMSC
 STA KPTR+1
 JSR KCPDN
 LDA KTKEYL
 STA KBLKL
 LDA KTKEYH
 STA KBLKH
 JMP KBIO2
KTR8 LDA #$00
 CLC
KTR9 RTS

* ---- KTRIX: free index KIX's entries -----------
* from KTFROM up, and the index block itself if
* KTWHOL; otherwise write it back if it changed.
KTRIX LDA KIXL
 STA KBLKL
 LDA KIXH
 STA KBLKH
 JSR KBIO1
 BCS KTX9
 LDA #<KIDC
 STA KPTR
 LDA #>KIDC
 STA KPTR+1
 JSR KCPUP
 STZ KICHG
 LDY KTFROM
KTX1 LDA KIDC,Y
 STA KFBL
 LDA KIDC+256,Y
 STA KFBH
 ORA KFBL
 BEQ KTX2
 STY KTY
 JSR KFREEB
 BCS KTX9
 LDY KTY
 LDA #$00
 STA KIDC,Y
 STA KIDC+256,Y
 LDA #$01
 STA KICHG
KTX2 INY
 BNE KTX1
 LDA KTWHOL
 BEQ KTX3
 LDA KIXL
 STA KFBL
 LDA KIXH
 STA KFBH
 JMP KFREEB
KTX3 LDA KICHG
 BEQ KTR8
 LDA #<KIDC
 STA KPTR
 LDA #>KIDC
 STA KPTR+1
 JSR KCPDN
 LDA KIXL
 STA KBLKL
 LDA KIXH
 STA KBLKH
 JMP KBIO2
KTX9 RTS

* ---- KTRDIR: every block of a directory --------
* Each block's "next" is taken before the block is
* freed: freeing may use KBLK.
KTRDIR LDA KTKEYL
 STA KBLKL
 LDA KTKEYH
 STA KBLKH
KTD1 JSR KBIO1
 BCS KTX9
 LDA KBLKL
 STA KFBL
 LDA KBLKH
 STA KFBH
 LDA KBLK+2
 STA KCNL
 LDA KBLK+3
 STA KCNH
 JSR KFREEB
 BCS KTX9
 LDA KCNL
 STA KBLKL
 LDA KCNH
 STA KBLKH
 ORA KBLKL
 BNE KTD1
 CLC
 RTS

* ==== DESTROY $C1 ================================
* +1/+2 pathname
* Not a volume, not an open file ($50), only with
* the entry's destroy bit ($4E), and a directory
* only when empty ($4E).  Every block goes back to
* the bitmap; the entry's first byte becomes 0; the
* parent directory's file count goes down by one.
KDESTR LDY #$01
 JSR KPATHP
 BCS KDS9
 JSR KWALK
 BCS KDS9
 LDA KWTYPE
 CMP #$F0
 BEQ KDSAC
 JSR KISOPEN
 BCS KDS9
 JSR KENTRY
 LDY #$1E
 LDA (KT0),Y
 BMI KDS1
KDSAC LDA #EACCES
KDS9 RTS
* ---- what the entry says ------------------------
KDS1 LDY #$25
 LDA (KT0),Y
 STA DPKEYL
 INY
 LDA (KT0),Y
 STA DPKEYH
 LDA KWEBLL
 STA DEBLL
 LDA KWEBLH
 STA DEBLH
 LDA KWEOFF
 STA DEOFF
 LDA KWTYPE
 STA KTSTOR
 LDA KWKEYL
 STA KTKEYL
 LDA KWKEYH
 STA KTKEYH
* ---- a directory must be empty ------------------
 LDA KWTYPE
 CMP #$D0
 BNE KDS2
 LDA KWKEYL
 STA KBLKL
 LDA KWKEYH
 STA KBLKH
 JSR KBIO1
 BCS KDS9
 LDA KBLK+$25
 ORA KBLK+$26
 BNE KDSAC
* ---- its blocks ---------------------------------
KDS2 STZ KKPL
 STZ KKPH
 JSR KTRUNC
 BCS KDS9
* ---- its entry ----------------------------------
 LDA DEBLL
 STA KBLKL
 LDA DEBLH
 STA KBLKH
 JSR KBIO1
 BCS KDS9
 LDA DEOFF
 STA KWEOFF
 JSR KENTRY
 LDA #$00
 STA (KT0)
 JSR KBIO2
 BCS KDS9
* ---- one file fewer in the parent --------------
 LDA DPKEYL
 STA KBLKL
 LDA DPKEYH
 STA KBLKH
 JSR KBIO1
 BCC KZ01
 JMP KDS9
KZ01 LDA KBLK+$25
 BNE KDS3
 DEC KBLK+$26
KDS3 DEC KBLK+$25
 JSR KBIO2
 BCC KZ02
 JMP KDS9
KZ02 LDA #$00
 RTS

* ==== CREATE $C0 =================================
* +1/+2 pathname  +3 access  +4 file type
* +5/+6 aux type  +7 storage type ($01-$03 a
* file, $0D a directory)  +8/+9 date  +A/+B time
* A date of 0 means now: $BF90-$BF93, after the
* clock.  $47 if the name is there already; $49
* if the volume directory is full (it never
* grows); a full subdirectory grows a block.
*
* The order matters because of KBLK: find the free
* entry (reading directory blocks), grow the
* directory if there is none, make the key block,
* and only then write the entry - each step reads
* the block it changes afresh.
KCREAT LDY #$01
 JSR KPATHP
 BCS KCR9
 JSR KWALK
 BCS KCR1
 LDA #EDUP
 RTS
KCR1 CMP #EFILE
 BEQ KCR2
KCR9 RTS
* ---- which kind -----------------------------------
KCR2 LDY #$07
 LDA (KPRM),Y
 CMP #$0D
 BEQ KCR3
 CMP #$01
 BCC KCRST
 CMP #$04
 BCS KCRST
 LDA #$10
 BRA KCR4
KCRST LDA #ESTYPE
 RTS
KCR3 LDA #$D0
KCR4 STA CSTOR
* ---- the parent: KWALK stopped in it -----------
 LDA KWKEYL
 STA CPKEYL
 LDA KWKEYH
 STA CPKEYH
 LDA KWTYPE
 STA CPTYP
 LDA KWEBLL
 STA CPEBLL
 LDA KWEBLH
 STA CPEBLH
 LDA KWEOFF
 STA CPEOFF
 JSR DATETIME
* ---- a free entry ---------------------------------
* (the key block's entry 0 is the header)
 LDA CPKEYL
 STA KBLKL
 LDA CPKEYH
 STA KBLKH
 LDA #$01
 STA CIX
KCR5 JSR KBIO1
 BCS KCR9
 LDA CIX
 STA KWEOFF
 JSR KENTRY
KCR6 LDA (KT0)
 AND #$F0
 BEQ KCRFND
 LDA KT0
 CLC
 ADC #39
 STA KT0
 BCC KCR7
 INC KT1
KCR7 INC CIX
 LDA CIX
 CMP #13
 BCC KCR6
 LDA KBLKL
 STA CLASTL
 LDA KBLKH
 STA CLASTH
 LDA KBLK+2
 STA KBLKL
 LDA KBLK+3
 STA KBLKH
 ORA KBLKL
 BEQ KCRGRO
 STZ CIX
 BRA KCR5
KCRFND LDA KBLKL
 STA CSLBL
 LDA KBLKH
 STA CSLBH
 LDA CIX
 STA CSLIX
 JMP KCRKEY
* ---- none: grow the directory ------------------
KCRGRO LDA CPTYP
 CMP #$F0
 BNE KCRG1
 LDA #EVFULL
 RTS
KCRG1 JSR KALLOC
 BCC KZ03
 JMP KCRG9
KZ03 LDA KNBL
 STA CSLBL
 LDA KNBH
 STA CSLBH
 STZ CSLIX
* the new block: empty, its "previous" the last
 JSR KBLK0
 LDA CLASTL
 STA KBLK
 LDA CLASTH
 STA KBLK+1
 LDA CSLBL
 STA KBLKL
 LDA CSLBH
 STA KBLKH
 JSR KBIO2
 BCS KCRG9
* the last block's "next" is the new one
 LDA CLASTL
 STA KBLKL
 LDA CLASTH
 STA KBLKH
 JSR KBIO1
 BCS KCRG9
 LDA CSLBL
 STA KBLK+2
 LDA CSLBH
 STA KBLK+3
 JSR KBIO2
 BCS KCRG9
* the directory's entry, in its own parent: one
* block more, 512 bytes longer
 LDA CPEBLL
 STA KBLKL
 LDA CPEBLH
 STA KBLKH
 JSR KBIO1
 BCS KCRG9
 LDA CPEOFF
 STA KWEOFF
 JSR KENTRY
 LDY #$13
 LDA (KT0),Y
 CLC
 ADC #$01
 STA (KT0),Y
 INY
 LDA (KT0),Y
 ADC #$00
 STA (KT0),Y
 LDY #$16
 LDA (KT0),Y
 CLC
 ADC #$02
 STA (KT0),Y
 INY
 LDA (KT0),Y
 ADC #$00
 STA (KT0),Y
 JSR KBIO2
 BCC KCRKEY
KCRG9 RTS
* ---- the new key block --------------------------
KCRKEY JSR KALLOC
 BCS KCRG9
 LDA KNBL
 STA CKEYL
 LDA KNBH
 STA CKEYH
 JSR KBLK0
 LDA CSTOR
 CMP #$D0
 BNE KCRK2
* a directory's header, as ProDOS makes one
 LDA #<KBLK+4
 STA KT0
 LDA #>KBLK
 STA KT1
 LDA #$E0
 JSR KCRNM
 LDA #$75
 STA KBLK+4+$10
 LDY #$18
 JSR KCRDT
 LDA #$C3
 STA KBLK+4+$1E
 LDA #$27
 STA KBLK+4+$1F
 STA KBLK+4+$26
 LDA #$0D
 STA KBLK+4+$20
 LDA CSLBL
 STA KBLK+4+$23
 LDA CSLBH
 STA KBLK+4+$24
 LDX CSLIX
 INX
 STX KBLK+4+$25
KCRK2 LDA CKEYL
 STA KBLKL
 LDA CKEYH
 STA KBLKH
 JSR KBIO2
 BCS KCRG9
* ---- the entry ------------------------------------
 LDA CSLBL
 STA KBLKL
 LDA CSLBH
 STA KBLKH
 JSR KBIO1
 BCS KCRG9
 LDA CSLIX
 STA KWEOFF
 JSR KENTRY
 LDY #38
 LDA #$00
KCE1 STA (KT0),Y
 DEY
 BPL KCE1
 LDA CSTOR
 JSR KCRNM
 LDY #$04
 LDA (KPRM),Y
 LDY #$10
 STA (KT0),Y
 INY
 LDA CKEYL
 STA (KT0),Y
 INY
 LDA CKEYH
 STA (KT0),Y
 INY
 LDA #$01
 STA (KT0),Y
* a directory is one block long already
 LDA CSTOR
 CMP #$D0
 BNE KCE2
 LDY #$16
 LDA #$02
 STA (KT0),Y
KCE2 LDY #$18
 JSR KCRDT
 LDY #$03
 LDA (KPRM),Y
* with the backup bit, as ProDOS sets it on CREATE
 ORA #$20
 LDY #$1E
 STA (KT0),Y
 LDY #$05
 LDA (KPRM),Y
 LDY #$1F
 STA (KT0),Y
 LDY #$06
 LDA (KPRM),Y
 LDY #$20
 STA (KT0),Y
 LDY #$21
 JSR KCRDT
 LDY #$25
 LDA CPKEYL
 STA (KT0),Y
 INY
 LDA CPKEYH
 STA (KT0),Y
 JSR KBIO2
 BCC KZ04
 JMP KCRG9
* ---- one file more in the parent ----------------
KZ04 LDA CPKEYL
 STA KBLKL
 LDA CPKEYH
 STA KBLKH
 JSR KBIO1
 BCC KZ05
 JMP KCRG9
KZ05 INC KBLK+$25
 BNE KCE3
 INC KBLK+$26
KCE3 JSR KBIO2
 BCC KZ06
 JMP KCRG9
KZ06 LDA #$00
 RTS

* ---- KBLK0: KBLK all zeros ---------------------
KBLK0 LDA #<KBLK
 STA KBUF
 LDA #>KBLK
 STA KBUF+1
 JMP KZERO

* ---- KCRNM: A ORed with the name's length, then
* the name, at (KT0) - KWALK's last name, KWCOMP
KCRNM ORA KWCLEN
 STA (KT0)
 LDY KWCLEN
KCN1 LDA KWCOMP-1,Y
 STA (KT0),Y
 DEY
 BNE KCN1
 RTS

* ---- KCRDT: the create date and time at (KT0)+Y
* from +8-+B, or from $BF90-$BF93 if the date there
* is 0
KCRDT STY KTY
 LDY #$08
 LDA (KPRM),Y
 INY
 ORA (KPRM),Y
 STA KTMP
 LDX #$00
KCT1 LDA KTMP
 BEQ KCT2
 TXA
 CLC
 ADC #$08
 TAY
 LDA (KPRM),Y
 BRA KCT3
KCT2 LDA DATELO,X
KCT3 LDY KTY
 STA (KT0),Y
 INC KTY
 INX
 CPX #$04
 BCC KCT1
 RTS

* ==== RENAME $C2 =================================
* +1/+2 the pathname  +3/+4 the new pathname
* Both in the same directory ($40 if not), the new
* one not there yet ($47), the file not open ($50)
* and its rename bit set ($4E).  The entry's name
* changes, and a directory's header name with it.
KRENAM LDY #$03
 JSR KPATHP
 BCS KRE9
* the new full path, kept for the comparison
 LDX KWLEN
KRE1 LDA KWLEN,X
 STA KRNP,X
 DEX
 BPL KRE1
 JSR KWALK
 BCS KRE2
 LDA #EDUP
 RTS
KRE2 CMP #EFILE
 BNE KRE9
* the new last name
 LDX KWCLEN
 STX KRNN
KRE3 LDA KWCOMP-1,X
 STA KRNN,X
 DEX
 BNE KRE3
* ---- the old path, and the same directory -----
 LDY #$01
 JSR KPATHP
 BCS KRE9
* the last "/" in each must be at the same place,
* and everything up to it the same
 LDX KWLEN
KRE4 DEX
 LDA KWPATH,X
 CMP #'/'
 BNE KRE4
 STX KTMP
 LDX KRNP
KRE5 DEX
 LDA KRNP+1,X
 CMP #'/'
 BNE KRE5
 CPX KTMP
 BNE KREBP
KRE6 LDA KWPATH,X
 CMP KRNP+1,X
 BNE KREBP
 DEX
 BPL KRE6
 JSR KWALK
 BCS KRE9
 LDA KWTYPE
 CMP #$F0
 BEQ KREBP
 JSR KISOPEN
 BCS KRE9
 JSR KENTRY
 LDY #$1E
 LDA (KT0),Y
 AND #$40
 BNE KRE7
 LDA #EACCES
KRE9 RTS
KREBP LDA #EBADPA
 RTS
* ---- the entry: KBLK holds its block -----------
KRE7 JSR KRNPUT
 LDA KWEBLL
 STA KBLKL
 LDA KWEBLH
 STA KBLKH
 JSR KBIO2
 BCS KRE9
 LDA KWTYPE
 CMP #$D0
 BNE KRE8
* ---- and a directory's own header --------------
 LDA KWKEYL
 STA KBLKL
 LDA KWKEYH
 STA KBLKH
 JSR KBIO1
 BCS KRE9
 LDA #<KBLK+4
 STA KT0
 LDA #>KBLK
 STA KT1
 JSR KRNPUT
 JSR KBIO2
 BCS KRE9
KRE8 LDA #$00
 RTS

* ---- KRNPUT: KRNN as the name at (KT0) ---------
* The storage nibble stays; unused name bytes are
* cleared.
KRNPUT LDA (KT0)
 AND #$F0
 ORA KRNN
 STA (KT0)
 LDY #$01
KRP1 LDA #$00
 CPY KRNN
 BEQ KRP2
 BCS KRP3
KRP2 LDA KRNN,Y
KRP3 STA (KT0),Y
 INY
 CPY #16
 BCC KRP1
 RTS
