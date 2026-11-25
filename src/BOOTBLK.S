* BOOTBLK.S  block 0 of a COBOL.OS disk
* Merlin 8, 65C02.  One block, 512 bytes at most.
*
* WHAT THIS IS
* The firmware of the boot slot reads block 0 of
* its first unit into $0800 and jumps to $0801.
* That is all the firmware does, and it is the
* only help we get.  This block must find the file
* COBOL.OS in the volume directory, load it at
* $2000 and jump to it - the same job ProDOS's own
* boot block does with the file PRODOS, in our
* code.  DESIGN.md section 6.2.
*
* WHY ONLY BLOCK 0
* A ProDOS volume gives a loader blocks 0 AND 1,
* but the firmware loads only block 0.  ProDOS
* needs the second block; this loader fits in the
* first, so block 1 is left exactly as it was.
* Writing ProDOS's block 0 back makes the disk a
* ProDOS disk again.
*
* THE VOLUME, AS FAR AS THIS BLOCK CARES
* The volume directory starts at block 2.  Each
* directory block is
*   +0   previous block (2 bytes)
*   +2   next block (2 bytes), 0 = the last
*   +4   13 entries of 39 bytes
* and the first entry of block 2 is the volume
* header, not a file.  An entry is
*   +$00 storage type (high nibble), name length
*   +$01 the name, 15 bytes
*   +$11 key block (2 bytes)
*   +$15 end of file (3 bytes)
* Every ProDOS volume uses 39 and 13; the header
* records them, and this loader trusts them rather
* than spending bytes reading them.
*
* STORAGE TYPES THIS LOADER TAKES
*   $1x seedling - one block, the key block IS
*       the data
*   $2x sapling - the key block is an INDEX: the
*       low bytes of up to 256 block numbers in
*       its first half, the high bytes in its
*       second
* A tree file ($3x) is over 128K and cannot be
* COBOL.OS, so it is refused rather than loaded.
*
* SMARTPORT, CALLED DIRECTLY
* The ROM is switched in, as the firmware left it,
* so this block calls the card itself: JSR to the
* entry, the command byte and the parameter list
* inline after it.  The kernel has to use a
* trampoline for the same call because it lives in
* the language card; this block does not.
*
* Errors print COBOL.OS BOOT ERROR x and hang:
*   S  no SmartPort card in the boot slot
*   R  a block read failed
*   F  no file COBOL.OS in the volume directory
*   L  COBOL.OS is a tree file, or over 32K
*
* HANDED TO COBOL.OS: X = the boot slot times 16,
* which is also the ProDOS unit number of the boot
* drive (drive 1).  The same register the firmware
* handed to us.

COUT EQU $FDED
LOADAT EQU $2000
DIRBUF EQU $0C00
IDXBUF EQU $0E00
* the length of the name KNAME holds, COBOL.OS
KNAMEL EQU 8

* ---- zero page: nothing else is alive yet -----
BUNIT EQU $06
PTR EQU $07
EPTR EQU $09
ECNT EQU $0B
NBLK EQU $0C
BLKI EQU $0D
BLK EQU $0E

 XC
 ORG $0800

* ---- the head of the block ----------------------
* $01 at $0800 is the Apple boot signature: the
* number of 256-byte sectors the Disk II firmware
* should load.  A SmartPort card looks at it only
* to see that it is not zero.
 DFB $01

* ---- BOOT, entered at $0801 ---------------------
* The slot arrives in X as slot times 16.  The
* Disk II ROM leaves it in $2B instead, so a zero
* in X tries $2B, and a zero there too assumes
* slot 7, where the hard disk card normally lives.
* X is read BEFORE the stack is set, because TXS
* needs X.
BOOT CLD
 SEI
 TXA
 AND #$70
 BNE B1
 LDA $2B
 AND #$70
 BNE B1
 LDA #$70
B1 STA BUNIT
 LDX #$FF
 TXS
* the slot ROM page, $Cn00
 LSR
 LSR
 LSR
 LSR
 ORA #$C0
 STA PTR+1
 STZ PTR

* ---- is it a SmartPort card? --------------------
* $Cn05 = $03 and $Cn07 = $00 are the SmartPort
* signature.  The ProDOS one, $Cn01 = $20 and
* $Cn03 = $00, comes with it on every card we
* support, so one check is enough here; the kernel
* checks all four when it scans the slots.
 LDY #$05
 LDA (PTR),Y
 CMP #$03
 BNE ERRS
 LDY #$07
 LDA (PTR),Y
 BNE ERRS

* ---- the entry: $Cn00 + [$CnFF] + 3 -------------
* [$CnFF] is the ProDOS block entry's offset; the
* SmartPort entry is always three bytes past it.
 LDY #$FF
 LDA (PTR),Y
 CLC
 ADC #$03
 STA SPJSR+1
 LDA PTR+1
 ADC #$00
 STA SPJSR+2

* ==== find COBOL.OS in the volume directory ======
 LDA #$02
 STA BLK
 STZ BLK+1
DB1 LDA #>DIRBUF
 JSR RDBLK
 LDA #<DIRBUF+4
 STA EPTR
 LDA #>DIRBUF
 STA EPTR+1
 LDA #13
 STA ECNT

* ---- one entry ----------------------------------
* The storage type must be seedling or sapling and
* the name length must be COBOL.OS's.  The volume
* header ($Fx) and deleted entries ($0x) fail the
* type test, so they need no test of their own.
DE1 LDY #$00
 LDA (EPTR),Y
 AND #$F0
 CMP #$10
 BEQ DE2
 CMP #$20
 BNE DENXT
DE2 LDA (EPTR),Y
 AND #$0F
 CMP #KNAMEL
 BNE DENXT
 TAY
DE3 LDA (EPTR),Y
 CMP KNAME-1,Y
 BNE DENXT
 DEY
 BNE DE3
 BRA FOUND

DENXT LDA EPTR
 CLC
 ADC #39
 STA EPTR
 BCC DE4
 INC EPTR+1
DE4 DEC ECNT
 BNE DE1

* ---- the next directory block, if any -----------
 LDA DIRBUF+2
 STA BLK
 LDA DIRBUF+3
 STA BLK+1
 ORA BLK
 BNE DB1
 LDA #'F'
 BRA FAIL

* ---- errors, here so the branches reach ---------
ERRS LDA #'S'
 BRA FAIL
ERRL LDA #'L'
FAIL PHA
 LDY #$00
FL1 LDA MSG,Y
 BEQ FL2
 ORA #$80
 JSR COUT
 INY
 BNE FL1
FL2 PLA
 ORA #$80
 JSR COUT
HANG BRA HANG

* ==== load it ====================================
* The number of blocks is the end of file rounded
* up to 512: the top two EOF bytes shifted right
* once, plus one if anything is left over.  Over
* 64 blocks (32K) would run COBOL.OS into the
* $BF00 page, so it is refused.
FOUND LDY #$17
 LDA (EPTR),Y
 BNE ERRL
 DEY
 LDA (EPTR),Y
 LSR
 STA NBLK
 DEY
 LDA (EPTR),Y
 BNE FD1
 BCC FD2
FD1 INC NBLK
FD2 LDA NBLK
 CMP #65
 BCS ERRL
 LDY #$12
 LDA (EPTR),Y
 STA BLK+1
 DEY
 LDA (EPTR),Y
 STA BLK
 LDY #$00
 LDA (EPTR),Y
 CMP #$30
 BCS ERRL
 CMP #$20
 BCS SAP

* ---- a seedling: the key block is the file ------
 LDA #>LOADAT
 JSR RDBLK
 BRA GO

* ---- a sapling: read the index, then each block -
SAP LDA #>IDXBUF
 JSR RDBLK
 STZ BLKI
 LDA #>LOADAT
 STA PTR
SP1 LDX BLKI
 LDA IDXBUF,X
 STA BLK
 LDA IDXBUF+256,X
 STA BLK+1
 LDA PTR
 JSR RDBLK
 INC PTR
 INC PTR
 INC BLKI
 LDA BLKI
 CMP NBLK
 BCC SP1

GO LDX BUNIT
 JMP LOADAT

* ==== RDBLK: block BLK into page A, A+1 ==========
* Unit 1 of the boot slot is the drive we booted
* from.  The buffer is always page aligned, so only
* its high byte changes.
RDBLK STA SPBUF+1
 LDA BLK
 STA SPBLK
 LDA BLK+1
 STA SPBLK+1
SPJSR JSR $FFFF
 DFB $01
 DA SPPARM
 BCS ERRR
 RTS
ERRR LDA #'R'
 JMP FAIL

* ==== data =======================================
MSG ASC 'COBOL.OS BOOT ERROR '
 DFB $00
KNAME ASC 'COBOL.OS'
SPPARM DFB $03
 DFB $01
SPBUF DA $0000
SPBLK DFB $00,$00,$00
