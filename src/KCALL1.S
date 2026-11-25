* KCALL1.S  the stage-1 calls: READ_BLOCK, ON_LINE,
* SET_PREFIX and GET_PREFIX.  And KINIT, which the
* installer calls once.
*
* Each handler is entered from KMLI with KPRM
* pointing at the caller's parameter block, whose
* count KMLI has already checked, and returns
* A = 0 or a ProDOS error.  The parameter blocks
* are ProDOS's, byte for byte (ProDOS 8 Technical
* Reference Manual, chapter 4).

* ==== READ_BLOCK $80 =============================
* +1 unit  +2/+3 buffer  +4/+5 block
* The buffer is the caller's: 512 bytes of main
* memory.  ProDOS checks it against the memory
* bitmap; nothing here uses the bitmap (DESIGN.md
* section 5), so it is not checked.
* WRITE_BLOCK $81 is the same with the other
* command: stage 3.
KWRBLK LDA #$02
 BRA KRB0
KRDBLK LDA #$01
KRB0 STA KCMD
 LDY #$01
 LDA (KPRM),Y
 JSR KFDEV
 BCS KRB1
 INY
 LDA (KPRM),Y
 STA KBUF
 INY
 LDA (KPRM),Y
 STA KBUF+1
 INY
 LDA (KPRM),Y
 STA KBLKL
 INY
 LDA (KPRM),Y
 STA KBLKH
 LDA KCMD
 JMP KDIO
KRB1 RTS

* ==== ON_LINE $C5 ================================
* +1 unit (0 = every drive)  +2/+3 buffer
* One 16-byte record per drive: the unit number
* ORed with the volume name's length, then the
* name.  A drive whose volume cannot be read gets
* length 0 and the error in the record's second
* byte.  For every drive, a zero byte follows the
* last record if there are fewer than 14.  For one
* drive, its error is also the call's.
KONLIN LDY #$02
 LDA (KPRM),Y
 STA KNAM
 INY
 LDA (KPRM),Y
 STA KNAM+1
 LDY #$01
 LDA (KPRM),Y
 AND #$F0
 BEQ KON0
 JSR KFDEV
 BCS KON9
 JMP KONREC
KON0 STZ KT6
KON1 LDX KT6
 CPX KNDEV
 BCS KON2
 JSR KONREC
 INC KT6
 BRA KON1
KON2 LDA KNDEV
 CMP #14
 BCS KON3
 LDA #$00
 STA (KNAM)
KON3 LDA #$00
KON9 RTS

* ---- KONREC: drive X's record at KNAM ----------
* Moves KNAM on by 16.  Returns A = 0 or the error.
KONREC JSR KRDVOL
 BCS KOR2
 LDA KDUNIT,X
 ORA KVLEN
 STA (KNAM)
 LDY KVLEN
KOR1 LDA KVNAME-1,Y
 STA (KNAM),Y
 DEY
 BNE KOR1
 LDA #$00
 BRA KOR3
KOR2 PHA
 LDA KDUNIT,X
 STA (KNAM)
 PLA
 LDY #$01
 STA (KNAM),Y
KOR3 PHA
 LDA KNAM
 CLC
 ADC #16
 STA KNAM
 BCC KOR4
 INC KNAM+1
KOR4 PLA
 RTS

* ==== GET_PREFIX $C7 =============================
* +1/+2 buffer.  The prefix as held: a length, then
* /VOL/DIR/ with both slashes; length 0 for none.
KGETPF LDY #$01
 LDA (KPRM),Y
 STA KBUF
 INY
 LDA (KPRM),Y
 STA KBUF+1
 LDY KPFX
KGP1 LDA KPFX,Y
 STA (KBUF),Y
 DEY
 BPL KGP1
 LDA #$00
 RTS

* ==== SET_PREFIX $C6 =============================
* +1/+2 pathname.  An empty pathname clears the
* prefix.  Otherwise the path must name a volume or
* a directory that exists - the walk proves it -
* and the prefix becomes that path with a "/" on
* each end.  Naming a file is $4B, ProDOS's
* "unsupported storage type".  A prefix longer than
* 64 characters with its slash is $40.
KSETPF LDY #$01
 LDA (KPRM),Y
 STA KNAM
 INY
 LDA (KPRM),Y
 STA KNAM+1
 LDA (KNAM)
 BNE KSP1
 STZ KPFX
 RTS
KSP1 JSR KPARSE
 BCS KSP9
 JSR KWALK
 BCS KSP9
 LDA KWTYPE
 CMP #$F0
 BEQ KSP2
 CMP #$D0
 BEQ KSP2
 LDA #ESTYPE
 RTS
KSP2 LDX KWLEN
 CPX #64
 BCC KSP3
 LDA #EBADPA
 RTS
KSP3 LDA #'/'
 STA KPFX+1,X
KSP4 LDA KWPATH-1,X
 STA KPFX,X
 DEX
 BNE KSP4
 LDX KWLEN
 INX
 STX KPFX
 LDA #$00
KSP9 RTS

* ==== KINIT: once, from the installer ============
* In: A = the boot unit, ProDOS form.  Clears the
* kernel's data in bank 1 ($D000-$D3FF,
* the open files too), finds the
* drives, and makes the prefix /BOOTVOLUME/ - the
* prefix ProDOS gives a system program it starts.
* A boot volume that cannot be read leaves no
* prefix, and COBOL.SYSTEM's start-up then finds
* the volume with ON_LINE, as it already can.
KINIT PHA
 STZ KT0
 LDA #$D0
 STA KT1
 LDX #$04
 LDY #$00
 TYA
KI1 STA (KT0),Y
 INY
 BNE KI1
 INC KT1
 DEX
 BNE KI1
 PLA
 STA KBOOT
 STA DEVNUM
* Ctrl-Reset: the reset vector points at KRESET in
* the $BF00 page, which restarts the system
* (KCALL4.S).  The third byte is the second EOR
* $A5, or the ROM takes it for a cold start.  Set
* here, so a warm restart sets it again.
 LDA #<KRESET
 STA SOFTEV
 LDA #>KRESET
 STA SOFTEV+1
 EOR #$A5
 STA PWREDUP
 JSR KSCAN
 LDA KBOOT
 JSR KFDEV
 BCS KI9
 JSR KRDVOL
 BCS KI9
 LDX KVLEN
KI2 LDA KVNAME-1,X
 STA KPFX+1,X
 DEX
 BNE KI2
 LDA #'/'
 STA KPFX+1
 LDX KVLEN
 STA KPFX+2,X
 INX
 INX
 STX KPFX
KI9 RTS

* ==== KRTI: where an interrupt lands =============
* Nothing in this system raises one (DESIGN.md
* section 8.3).  If a card ever does, it returns
* at once rather than running into garbage.
KRTI RTI
