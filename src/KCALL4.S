* KCALL4.S  QUIT, and the warm restart behind
* Ctrl-Reset.  Stage 4.  DESIGN.md sections 8.1
* and 8.3.

* ==== QUIT $65 ====================================
* +1 quit type, +2/+3, +4, +5/+6: ProDOS's, and
* nothing here reads them.  ProDOS's QUIT goes to a
* program selector; there is none here.  QUIT:
*   1  closes every file, writing each back, and
*      writes the bitmap block back - what the
*      dispatcher's epilogue would have done, but
*      QUIT never returns to it;
*   2  clears the screen, 80 columns, and puts the
*      user's line in the middle of it:
*        Change the disk and press RETURN to
*        restart the system
*      (one line; the user's wording, 2026-11-22);
*   3  waits for RETURN and nothing else;
*   4  boots the slot it booted from.  The same
*      disk gives the COBOL menu again, a turnkey
*      disk its program, and another disk whatever
*      is on it.
* A failed write-back has nobody to tell: the
* program that asked has finished.  It is the same
* as switching off with a file open.
*
* THE SCREEN is drawn straight into text page 1,
* not through any firmware: whatever the program
* left in the soft switches and in CSW cannot be
* trusted now.  80STORE off, so RAMWRT picks the
* bank: in 80 columns column 2k is in AUX memory
* and column 2k+1 in MAIN, at the same address.
* Only the 40 bytes of each row are written, never
* the "screen holes" between rows, which belong to
* the slots' firmware.  ALTCHAR on, so lower case
* shows as lower case.
KQUIT JSR KCLALL
 JSR KBMFL
 STZ KBMVAL
 STA S80STOFF
 STA SRAMWRTM
 STA S80COLON
 STA SALTCHON
 LDA STXTON
 LDA SPAGE1
* ---- every row blank, both banks ----------------
 LDA #23
 STA KT2
KQ1 LDA KT2
 JSR KQROW
 STA SRAMWRTA
 JSR KQFILL
 STA SRAMWRTM
 JSR KQFILL
 DEC KT2
 BPL KQ1
* ---- the line, centred on row 11 ----------------
* 54 characters in 80 columns: 13 either side.
* X counts characters, and 13 + X is the column;
* LSR leaves the column's half in A for Y and its
* odd/even bit in the carry: odd = main.
 LDA #11
 JSR KQROW
 LDX #$00
KQ2 LDA KQMSG,X
 BEQ KQ4
 ORA #$80
 PHA
 TXA
 CLC
 ADC #13
 LSR
 TAY
 PLA
 BCS KQ3
 STA SRAMWRTA
 STA (KT0),Y
 STA SRAMWRTM
 INX
 BRA KQ2
KQ3 STA (KT0),Y
 INX
 BRA KQ2
* ---- RETURN, and only RETURN --------------------
* A key typed before the line appeared is thrown
* away first, so it cannot answer for the user.
KQ4 STA KSTROBE
KQ5 LDA KBD
 BPL KQ5
 STA KSTROBE
 CMP #$8D
 BNE KQ5
* ---- and boot -----------------------------------
* Back to 40 columns and the standard characters,
* as the boot firmware expects them.  KBOOT is the
* boot unit, DSSS0000: the slot is bits 4-6, and
* $C0 + slot is the page of its firmware.  Slot
* ROMs on ($C006): the card's firmware has to be
* the one that answers at $Cs00.
 STA S80COLOF
 STA SALTCHOF
 STA SSLOTCX
 LDA KBOOT
 LSR
 LSR
 LSR
 LSR
 AND #$07
 ORA #$C0
 STA KQBJ+2
 STZ KQBJ+1
 JMP KQBOOT

* ---- KQROW: A = a row, 0-23 -> KT0/KT1 ----------
* Text page 1's rows are not in order.  Row r's
* address is $0400 + (r AND 7) * $80 + (r / 8) * 40:
* the high byte is $04 + (r AND 7) / 2, and the low
* byte is $80 if r is odd (r AND 7 has the same
* lowest bit) plus 0, 40 or 80 for its third of the
* screen.  The most that can be is $80 + 80 = $D0,
* so the add never carries.
KQROW PHA
 AND #$07
 LSR
 ORA #$04
 STA KT1
 PLA
 PHA
 LSR
 LDA #$00
 ROR
 STA KT0
 PLA
 LSR
 LSR
 LSR
 TAX
 LDA KT0
 CLC
 ADC KQ40,X
 STA KT0
 RTS
KQ40 DFB 0,40,80

* ---- KQFILL: the row at KT0, 40 spaces -----------
* In whichever bank RAMWRT has chosen.
KQFILL LDY #39
 LDA #$A0
KQF1 STA (KT0),Y
 DEY
 BPL KQF1
 RTS

KQMSG ASC 'Change the disk and press RETURN to '
 ASC 'restart the system'
 DFB $00

* ==== KWARM: Ctrl-Reset ===========================
* KRESET in the $BF00 page has banked the kernel in
* and jumped here.  The machine has reset its own
* switches (main memory, main zero page, 80STORE
* off), so this starts again from KINIT: every
* open file forgotten, the drives found, the
* prefix the boot volume, the reset vector set -
* then KLDSYS loads COBOL.SYSTEM and starts it, as
* at boot.
*
* OPEN FILES ARE FORGOTTEN, NOT WRITTEN BACK
* (DESIGN 8.3: they "lose only what was in their
* buffers").  A reset can land in the middle of a
* call - half a block allocated, an index half
* written - and writing back from that state could
* make a sound file unsound.  Forgetting it cannot.
* The worst it leaves is a block the bitmap says is
* in use that no file owns, which loses 512 bytes
* and nothing else.
KWARM CLD
 LDX #$FF
 TXS
 LDA KBOOT
 JSR KINIT
 JMP KLDSYS
