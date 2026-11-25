* KDEV.S  the devices: finding them, and moving a
* block to or from one.  DESIGN.md section 6.1.
*
* ONLY SMARTPORT (the user, 2026-11-22): 3.5"
* drives and hard drives, which is AppleWin's hard
* disk card and the user's two real drives.  A
* card is a SmartPort card when its ROM carries
* both signatures:
*   $Cn01 = $20, $Cn03 = $00   ProDOS block device
*   $Cn05 = $03, $Cn07 = $00   and SmartPort
*
* UNITS: the card numbers its drives 1, 2, ...
* ProDOS numbers them by slot and drive, DSSS0000:
* drive 1 of slot 7 is $70, drive 2 is $F0.  The
* first two SmartPort units of each card are drives
* 1 and 2.  A third or fourth unit (ProDOS 2.x maps
* those onto "phantom" slots) is not used in v1.
*
* ADAPTED FROM SWA's SMARTPORT.S, where the
* trampoline idea and the STATUS call ran first
* (SPTEST, 2026-11-09).  The differences: one
* table row per drive rather than one card, the
* zero page saved by the kernel rather than the
* trampoline, and ProDOS's error codes.

* ==== KSCAN: find every drive ====================
* Slots 7 down to 1.  For each SmartPort card, ask
* the card (STATUS, unit 0) how many units it has,
* and enter the first two.  Fills KNDEV and the
* KD tables, then the ProDOS device list at $BF31.
* Slots are scanned high to low, so the hard disk
* card in slot 7 is device 0.
KSCAN STZ KNDEV
 STZ KT0
 LDA #$C7
 STA KT1
KS1 LDY #$01
 LDA (KT0),Y
 CMP #$20
 BNE KSNXT
 LDY #$03
 LDA (KT0),Y
 BNE KSNXT
 LDY #$05
 LDA (KT0),Y
 CMP #$03
 BNE KSNXT
 LDY #$07
 LDA (KT0),Y
 BNE KSNXT
* ---- a card: its entry is $Cn00 + [$CnFF] + 3 --
 LDY #$FF
 LDA (KT0),Y
 CLC
 ADC #$03
 STA KT2
 LDA KT1
 ADC #$00
 STA KT3
* ---- STATUS, unit 0: how many units? ------------
* The answer is the first byte of the list.  A
* card that will not answer is passed over.
 LDA #$00
 STA KT4
 JSR KSTAT0
 BCS KSNXT
 LDA SPSTAT
 BEQ KSNXT
 CMP #$03
 BCC KS2
 LDA #$02
KS2 STA KT5
* ---- one row per unit, up to two ----------------
* unit number: the slot ($Cn -> $n0), plus $80 for
* drive 2
 LDA #$01
 STA KT4
KS3 LDX KNDEV
 CPX #KDMAX
 BCS KSNXT
 LDA KT1
 ASL
 ASL
 ASL
 ASL
 LDY KT4
 CPY #$02
 BCC KS4
 ORA #$80
KS4 STA KDUNIT,X
 LDA KT4
 STA KDSPU,X
 LDA KT2
 STA KDENTL,X
 LDA KT3
 STA KDENTH,X
 INC KNDEV
 INC KT4
 LDA KT4
 CMP KT5
 BCC KS3
 BEQ KS3
KSNXT DEC KT1
 LDA KT1
 CMP #$C0
 BEQ KSDONE
 JMP KS1
* ---- the ProDOS device list ---------------------
* DEVCNT is the count MINUS ONE ($FF for none).
* The low nibble of a DEVLST entry is a device
* type to ProDOS; nothing in COBOL reads it, and
* it is left zero.
KSDONE LDX KNDEV
 DEX
 STX DEVCNT
 LDX #$00
KS5 CPX KNDEV
 BCS KS6
 LDA KDUNIT,X
 STA DEVLST,X
 INX
 BRA KS5
KS6 RTS

* ==== KSTAT0: STATUS for the scan ================
* KT2/KT3 = the card's entry, KT4 = the unit
* (0 = the card itself).  Answers at SPSTAT.
KSTAT0 LDA KT2
 STA SPTJSR+1
 LDA KT3
 STA SPTJSR+2
 LDA #$03
 STA SPPARM
 LDA KT4
 STA SPPARM+1
 LDA #<SPSTAT
 STA SPPARM+2
 LDA #>SPSTAT
 STA SPPARM+3
 STZ SPPARM+4
 LDA #$00
 JMP KCARD

* ==== KFDEV: a ProDOS unit number to a device ====
* In:  A = unit number (DSSS, low nibble ignored)
* Out: carry clear, X = the device's index
*      carry set, A = $28, no such device
KFDEV AND #$F0
 LDX #$00
KF1 CPX KNDEV
 BCS KF2
 CMP KDUNIT,X
 BEQ KF3
 INX
 BRA KF1
KF2 LDA #ENODEV
 SEC
 RTS
KF3 CLC
 RTS

* ==== KDIO: one block to or from a device ========
* In:  X = the device's index, KBUF = a 512-byte
*      buffer in main memory, KBLKL/KBLKH = the
*      block, A = the SmartPort command (1 read,
*      2 write)
* Out: carry clear, A = 0; or carry set, A = a
*      ProDOS error ($27, $28 or $2B)
KDIO PHA
 LDA KDENTL,X
 STA SPTJSR+1
 LDA KDENTH,X
 STA SPTJSR+2
 LDA #$03
 STA SPPARM
 LDA KDSPU,X
 STA SPPARM+1
 LDA KBUF
 STA SPPARM+2
 LDA KBUF+1
 STA SPPARM+3
 LDA KBLKL
 STA SPPARM+4
 LDA KBLKH
 STA SPPARM+5
 STZ SPPARM+6
 PLA

* ==== KCARD: call the card =======================
* A = the command; SPPARM and the trampoline's
* JSR are set.  Saves the kernel's zero page
* around the call (the firmware uses $42-$47),
* then maps the card's error to ProDOS's:
*   $27 I/O error, $28 no device, $2B write
*   protected pass through; $11 (bad unit) is $28;
*   anything else is reported as $27.
KCARD STA SPTCMD
 LDX #$0E
KC1 LDA KPTR,X
 STA KZSAVE,X
 DEX
 BPL KC1
 JSR SPTRAMP
 PHP
 PHA
 LDX #$0E
KC2 LDA KZSAVE,X
 STA KPTR,X
 DEX
 BPL KC2
 PLA
 PLP
 BCC KC4
 CMP #ENODEV
 BEQ KC3
 CMP #EWPROT
 BEQ KC3
 CMP #$11
 BEQ KC5
 LDA #EIO
KC3 SEC
 RTS
KC5 LDA #ENODEV
 SEC
 RTS
KC4 LDA #$00
 RTS

* ==== KRDVOL: a device's volume name =============
* In:  X = the device's index
* Out: carry clear, KVLEN/KVNAME = the name; or
*      carry set, A = the error ($52 if block 2
*      is not a ProDOS volume directory)
* Leaves block 2 in KBLK, and X unchanged.
KRDVOL STX KDEVX
 LDA #<KBLK
 STA KBUF
 LDA #>KBLK
 STA KBUF+1
 LDA #$02
 STA KBLKL
 STZ KBLKH
 LDA #$01
 JSR KDIO
 LDX KDEVX
 BCS KRV3
* the header: storage type $F, previous block 0
 LDA KBLK
 ORA KBLK+1
 BNE KRV2
 LDA KBLK+4
 AND #$F0
 CMP #$F0
 BNE KRV2
 LDA KBLK+4
 AND #$0F
 BEQ KRV2
 STA KVLEN
 TAY
KRV1 LDA KBLK+4,Y
 STA KVNAME-1,Y
 DEY
 BNE KRV1
 CLC
 RTS
KRV2 LDA #ENOTPD
 SEC
KRV3 RTS
