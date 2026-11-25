* KBMAP.S  the volume bitmap: KALLOC finds a free
* block and takes it, KFREEB gives one back, KBMFL
* writes the cached bitmap block back.  Stage 3.
*
* THE BITMAP is ProDOS's: one bit per block, set
* means free, the bits of each byte from bit 7
* down, 4,096 blocks to a bitmap block, starting at
* the block the volume header names ($27/$28 of
* block 2, with the volume's size at $29/$2A).
*
* ONE BITMAP BLOCK IS HELD, at KBMC in bank 1,
* with the device and which of the bitmap's blocks
* it is.  It is read through KBLK and copied up,
* so nothing else may hold anything in KBLK across
* a KALLOC or a KFREEB.  KMLI calls KBMFL and then
* forgets the cache at the end of every call:
* within one call an allocation costs no I/O at
* all, and between calls the disk is always whole.

* ---- KBITM: the bit for each position, 7 down ---
KBITM DFB $80,$40,$20,$10,$08,$04,$02,$01

* ==== KBMSET: bitmap block KBMWT of KDEVX ========
* into the cache, writing back the one there if it
* changed.  The volume's header is read again
* whenever the cache was for another device or
* for none.  Out: carry set, A = the error.
KBMSET LDA KBMVAL
 BEQ KBS1
 LDA KBMDV
 CMP KDEVX
 BNE KBS0
 LDA KBMIX
 CMP KBMWT
 BNE KBS0
 CLC
 RTS
KBS0 JSR KBMFL
 BCC KBS0A
 RTS
KBS0A LDA KBMDV
 CMP KDEVX
 BEQ KBS2
* ---- the volume's header: block 2 --------------
KBS1 STZ KBMVAL
 LDA #$02
 STA KBLKL
 STZ KBLKH
 JSR KBIO1
 BCS KBS9
 LDA KBLK+$27
 STA KBMPL
 LDA KBLK+$28
 STA KBMPH
 LDA KBLK+$29
 STA KBMTL
 LDA KBLK+$2A
 STA KBMTH
* (size + 4095) / 4096 bitmap blocks
 LSR
 LSR
 LSR
 LSR
 STA KBMNB
 LDA KBMTH
 AND #$0F
 ORA KBMTL
 BEQ KBS1A
 INC KBMNB
KBS1A LDA KDEVX
 STA KBMDV
* ---- the bitmap block itself -------------------
KBS2 CLC
 LDA KBMPL
 ADC KBMWT
 STA KBLKL
 LDA KBMPH
 ADC #$00
 STA KBLKH
 JSR KBIO1
 BCS KBS9
 LDY #$00
KBS3 LDA KBLK,Y
 STA KBMC,Y
 LDA KBLK+256,Y
 STA KBMC+256,Y
 INY
 BNE KBS3
 LDA KBMWT
 STA KBMIX
 STZ KBMDTY
 LDA #$01
 STA KBMVAL
 CLC
KBS9 RTS

* ---- KBIO1/KBIO2: KBLKL/H of KDEVX via KBLK ----
KBIO1 LDA #$01
 BRA KBIO
KBIO2 LDA #$02
KBIO PHA
 LDA #<KBLK
 STA KBUF
 LDA #>KBLK
 STA KBUF+1
 LDX KDEVX
 PLA
 JMP KDIO

* ==== KBMFL: the cached block back, if changed ===
* Out: carry set, A = the error.
KBMFL LDA KBMVAL
 BEQ KBF8
 LDA KBMDTY
 BEQ KBF8
 LDY #$00
KBF1 LDA KBMC,Y
 STA KBLK,Y
 LDA KBMC+256,Y
 STA KBLK+256,Y
 INY
 BNE KBF1
 CLC
 LDA KBMPL
 ADC KBMIX
 STA KBLKL
 LDA KBMPH
 ADC #$00
 STA KBLKH
* (the cache's own device, which KBIO uses)
 LDA KDEVX
 PHA
 LDA KBMDV
 STA KDEVX
 JSR KBIO2
 PLX
 STX KDEVX
 BCS KBF9
 STZ KBMDTY
KBF8 LDA #$00
 CLC
KBF9 RTS

* ==== KALLOC: a free block of KDEVX ==============
* Out: carry clear, KNBL/H = the block, now marked
*      in use; or carry set, A = the error ($48
*      when the volume is full).
* The search starts in the bitmap block held, if it
* is this device's, else in the first; it goes on
* through the rest and round to the start, once.
KALLOC LDA KBMVAL
 BEQ KA0
 LDA KBMDV
 CMP KDEVX
 BEQ KA1
KA0 STZ KBMWT
 JSR KBMSET
 BCS KA9
KA1 LDA KBMNB
 STA KACNT
* ---- the first byte with a bit set -------------
KA2 LDY #$00
KA3 LDA KBMC,Y
 BNE KAF0
 INY
 BNE KA3
KA4 LDA KBMC+256,Y
 BNE KAF1
 INY
 BNE KA4
* ---- none here: the next bitmap block ----------
 DEC KACNT
 BEQ KAFULL
 LDA KBMIX
 CLC
 ADC #$01
 CMP KBMNB
 BCC KA5
 LDA #$00
KA5 STA KBMWT
 JSR KBMSET
 BCC KA2
KA9 RTS
KAFULL LDA #EFULL
 SEC
 RTS
KAF0 STZ KABH
 BRA KAF
KAF1 LDX #$01
 STX KABH
* ---- A = the byte, Y and KABH its place --------
* The first set bit from bit 7 is the lowest
* block.  Its number:
*   KBMIX * 4096 + (KABH * 256 + Y) * 8 + bit
KAF LDX #$00
KAF2 ASL
 BCS KAF3
 INX
 BRA KAF2
KAF3 STX KABIT
 TYA
 ASL
 ASL
 ASL
 ORA KABIT
 STA KNBL
 TYA
 LSR
 LSR
 LSR
 LSR
 LSR
 STA KTMP
 LDA KABH
 ASL
 ASL
 ASL
 ORA KTMP
 STA KTMP
 LDA KBMIX
 ASL
 ASL
 ASL
 ASL
 ORA KTMP
 STA KNBH
* past the volume's end is "full" (ProDOS leaves
* those bits clear anyway)
 CMP KBMTH
 BCC KAF4
 BNE KAFULL
 LDA KNBL
 CMP KBMTL
 BCS KAFULL
* ---- take it: clear the bit --------------------
KAF4 LDA KBITM,X
 EOR #$FF
 LDX KABH
 BNE KAF5
 AND KBMC,Y
 STA KBMC,Y
 BRA KAF6
KAF5 AND KBMC+256,Y
 STA KBMC+256,Y
KAF6 LDA #$01
 STA KBMDTY
 CLC
 RTS

* ==== KFREEB: block KFBL/H of KDEVX is free ======
* Sets its bit and counts it in KFRC.  Out: carry
* set, A = the error.
KFREEB LDA KFBH
 LSR
 LSR
 LSR
 LSR
 STA KBMWT
 JSR KBMSET
 BCS KFE9
* the byte: (block / 8) AND 511; the bit: block
* AND 7
 LDA KFBH
 ASL
 ASL
 ASL
 ASL
 ASL
 STA KTMP
 LDA KFBL
 LSR
 LSR
 LSR
 ORA KTMP
 TAY
 LDA KFBL
 AND #$07
 TAX
 LDA KFBH
 AND #$08
 BNE KFE2
 LDA KBMC,Y
 ORA KBITM,X
 STA KBMC,Y
 BRA KFE3
KFE2 LDA KBMC+256,Y
 ORA KBITM,X
 STA KBMC+256,Y
KFE3 LDA #$01
 STA KBMDTY
 INC KFRCL
 BNE KFE4
 INC KFRCH
KFE4 CLC
KFE9 RTS
