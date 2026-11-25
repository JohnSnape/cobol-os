* KPAGE.S  the $BF00 page, as the installer copies
* it.  PUT by COBOLOS.S right after ORG $BF00, so
* every label here has its final address, and the
* installer copies these 256 bytes from the file to
* $BF00.  DESIGN.md section 5.
*
* WHAT IS ProDOS'S AND WHAT IS OURS
* COBOL reads and writes a handful of these bytes
* at ProDOS's addresses, and the COBOL binaries are
* not changed, so those addresses are kept exactly:
*   $BF00  the MLI entry, JSR'd by every call
*   $BF06  the clock vector, and $BF07/$BF08 where
*          a clock driver is to be copied
*   $BF10  the device vectors (RAMOFF compares
*          $BF26 with $BF10)
*   $BF30  DEVNUM, $BF31 DEVCNT, $BF32 DEVLST
*   $BF58  the memory bitmap
*   $BF90  the date and time
*   $BF98  MACHID
* The rest of the page is ProDOS's private code in
* ProDOS.  Here it is ours: the entry stub and the
* SmartPort trampoline, which have to be in main
* memory below the language card (section 5.1).
*
* Each block below ends with a DS to the next fixed
* address.  If code grows past one, the DS goes
* negative and the assembly fails - which is the
* point: these addresses may never move.

* ---- $BF00: the MLI entry -----------------------
 JMP MLIENT
* $BF03: ProDOS's quit vector; nothing uses it.
 JMP NODEV
* $BF06: the clock.  RTS until a clock driver is
* installed, when it becomes JMP CLKAREA.
 RTS
 DA CLKAREA
* $BF09-$BF0F: ProDOS's error vectors, unused
 DS $BF10-*

* ---- $BF10: sixteen device vectors --------------
* Every one points at NODEV.  Nothing here calls a
* device through them - the kernel has its own
* table - but COBOL's RAMOFF looks for /RAM by
* comparing slot 3 drive 2 ($BF26) with the "no
* device" vector ($BF10).  Equal means no /RAM,
* and it leaves the list alone.
 DA NODEV,NODEV,NODEV,NODEV
 DA NODEV,NODEV,NODEV,NODEV
 DA NODEV,NODEV,NODEV,NODEV
 DA NODEV,NODEV,NODEV,NODEV

* ---- $BF30: the device list ---------------------
* DEVNUM: the last unit used.  DEVCNT: the number
* of devices MINUS ONE, ProDOS's convention.
* DEVLST: up to 14 unit numbers.  KINIT fills all
* three.
 DFB $00
 DFB $FF
 DS 14

* ---- $BF40: ours, 24 bytes ----------------------
* NODEV: what a call to no device gets.
NODEV LDA #ENODEV
 SEC
 RTS
* SPPARM: the SmartPort parameter list.  The
* firmware reads it with the ROM in, so it must be
* in main memory.  Count, unit, buffer (or status
* list), then a block number - or, for STATUS, the
* status code in the block's first byte.
SPPARM DS 7
* SPSTAT: where STATUS answers, 8 bytes
SPSTAT DS 8
* the entry stub's two bytes of memory
MSAVX DS 1
MREST DS 1
 DS $BF58-*

* ---- $BF58: the memory bitmap -------------------
* One bit per page, $00-$BF.  ProDOS's start-up
* value: pages 0, 1 and 4-7 (zero page, stack,
* text page 1) and page $BF in use.  Nothing reads
* it here; it is kept because it is ProDOS's.
 DFB $CF
 DS 22
 DFB $01

* ---- $BF70: ours, 32 bytes ----------------------
* SPTRAMP: the SmartPort trampoline.  The kernel
* lives in the language card, and the card's
* firmware runs with the ROM in.  The instant the
* kernel switched the ROM in itself, its own next
* instruction would be fetched from ROM.  So the
* kernel stores the card's entry and the command
* into this code and JSRs here.  This code banks
* the ROM in, calls the card, and banks the kernel
* back - read and write - before returning.
*   The card's carry and A come back unchanged:
* TAX/TXA carry A across the two switch reads, and
* neither LDA nor TAX touches the carry.
*   The JSR operand and the command byte are
* patched by KDIO before every call.
SPTRAMP LDA LCROM1
SPTJSR JSR $0000
SPTCMD DFB $00
 DA SPPARM
 TAX
 LDA LCRW1
 LDA LCRW1
 TXA
 RTS
* KGO: KLDSYS's last step.  The ROM in, and into
* the program it loaded at $2000.  Here and not in
* the kernel for the trampoline's reason: code in
* the card that switched the ROM in would fetch
* its next instruction from ROM.
KGO LDA LCROM1
 JMP $2000
 DS $BF90-*

* ---- $BF90: the date and time, MACHID ----------
* Four bytes ProDOS stamps files from; zero is
* "no date".  $BF94-$BF97 are ProDOS's and unused.
 DFB $00,$00,$00,$00
 DS 4
* MACHID $BF98: %10 IIe, %11 128K, bit 1 an
* 80-column card, bit 0 a clock (CLOCK.S sets it
* when it installs a driver).
 DFB $B2

* ---- $BF99: the entry stub ----------------------
* Every MLI call lands here, from code running with
* the ROM switched in.  The stub:
*   1  saves X (the kernel saves Y itself),
*   2  works out which switch puts the language
*      card back the way the caller had it - ROM
*      or RAM, bank 1 or bank 2 - into MREST,
*   3  banks the kernel in, read and write,
*   4  calls KMLI, which returns the error in A
*      and has already moved the caller's return
*      address past the call's three inline bytes,
*   5  puts the card back,
*   6  sets the flags ProDOS returns: carry set
*      and A the error, or carry clear and A zero,
*      with Z and N following A.
* CMP #1 sets the carry exactly when A is not zero;
* ORA #0 then sets Z and N from A without touching
* the carry.  BIT abs,X (a 65C02 opcode) reads a
* switch without disturbing A.
*
* THE CALLER'S DUTY, as under ProDOS: the main zero
* page and stack (ALTZP off), and RAMRD and RAMWRT
* on main memory.
MLIENT STX MSAVX
 LDX #$8A
 BIT RDLCBNK2
 BPL ME1
 LDX #$82
ME1 BIT RDLCRAM
 BPL ME2
 INX
ME2 STX MREST
 LDX LCRW1
 LDX LCRW1
 JSR KMLI
 LDX MREST
 BIT $C000,X
 BIT $C000,X
 LDX MSAVX
 CMP #$01
 ORA #$00
 RTS

* ---- after the stub: Ctrl-Reset and QUIT --------
* Both here and not in the card, for KGO's reason:
* the switch and the jump have to happen in code
* that stays put when the card's state changes.
*
* KRESET: where the reset vector points (KINIT sets
* it).  A reset leaves the ROM in, so this banks
* the kernel in, read and write, and goes to its
* warm restart.
KRESET LDA LCRW1
 LDA LCRW1
 JMP KWARM
* KQBOOT: QUIT's last step.  The ROM in, the
* monitor's own start-up (a text window, COUT and
* the keyboard back to the ROM's), then the boot
* slot's firmware.  KQUIT patches the slot into the
* JMP: $Cs00.
KQBOOT LDA LCROM1
 JSR MINIT
 JSR MSETVID
 JSR MSETKBD
KQBJ JMP $C700
 DS $BFFC-*

* ---- $BFFC: version bytes -----------------------
* ProDOS's layout: $BFFC/$BFFD belong to the
* system program (IBAKVER, IVERSION), which sets
* them if it wants to; $BFFE/$BFFF are the
* kernel's (KBAKVER, KVERSION).
*
* KVERSION IS HOW A PROGRAM TELLS THE TWO SYSTEMS
* APART.  Real ProDOS keeps a small number here:
* $24 for 2.4.x, $23 for 2.0.3, lower for 1.x.
* COBOL.OS puts $C0, which no ProDOS has used, so
*   LDA $BFFF / CMP #$C0 / BCS on COBOL.OS
* is the whole test.  There are two builds of
* COBOL (the user, 2026-11-23), one for each
* system, and each one makes this test at start-up
* so that it never runs on the other system: the
* ProDOS build's $BD00 data would land on our
* block buffer, and ours would run with ProDOS in
* the language card it means to use.  $C0 is
* version "0" of COBOL.OS; a later kernel that
* changes what programs may rely on counts up
* from it, and KBAKVER names the oldest version it
* is still compatible with.
 DFB $00,$00,$C0,$C0
