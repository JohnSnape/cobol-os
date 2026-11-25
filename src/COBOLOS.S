* COBOLOS.S  the file COBOL.OS: the installer, the
* $BF00 page and the kernel, in one object.
* Merlin 8, 65C02.  DESIGN.md is the plan.
*
* HOW THE FILE IS LAID OUT
* The boot block loads this whole file at $2000 and
* jumps to its first byte.  Three pieces follow one
* another in the file, each assembled for the
* address it will RUN at:
*
*   in the file    runs at  what
*   $2000          $2000    INSTALL
*   INSEND+1       $BF00    the $BF00 page
*                           (KPAGE.S), 256 bytes
*   INSEND+257     $E000    the kernel, to KEND
*
* An ORG changes the address labels get, not where
* the bytes go in the file.  So INSTALL works out
* where the page and the kernel sit in the file at
* RUN time, from the label INSEND, the last byte
* before the page.  An EQU after the code would
* not do: Merlin 8 cannot use an EQU in an
* instruction before the EQU's own line.
* (Stage 1 measured: INSEND $2402, the kernel
* $E000-$E530, 1,328 bytes, with the stage-1 test
* in the installer.  Stage 2 dropped the test.)
*
* WHY THE INSTALLER COPIES BEFORE IT DOES ANYTHING
* During stages 1-3 the kernel's block buffer was
* $2E00-$2FFF - inside this file once the kernel
* was big enough - so INSTALL copies the page and
* the kernel out FIRST, and only then calls KINIT,
* which reads blocks.  Since stage 4 the buffer is
* $BD00 (KEQU.S), far above this file, and the
* order no longer matters; it is kept because it
* costs nothing.  tools/m32build.sh still checks
* that INSTALL ends below KBLK.

 XC
 PUT KEQU

 ORG $2000

* ==== INSTALL ====================================
* X = the boot unit, from the boot block.
*
* Where the two images are in the file is worked
* out HERE, at run time, from INSEND - the last
* byte of the installer - rather than with EQUs
* after the code: Merlin 8 cannot use an EQU in an
* instruction before the EQU's line.  The page
* starts at INSEND+1 and the kernel 256 bytes on.
INSTALL STX IBOOT
 LDA #<INSEND
 CLC
 ADC #$01
 STA $06
 LDA #>INSEND
 ADC #$00
 STA $07
* ---- the $BF00 page ------------------------------
 LDY #$00
IN1 LDA ($06),Y
 STA $BF00,Y
 INY
 BNE IN1
 INC $07
* ---- the kernel into the language card ----------
* Bank 1, read ROM and write RAM: two reads of
* $C089.  The copy reads this file in main memory
* and writes the card, whole pages, as many as it
* takes to reach KEND: (KEND's page) - $E0 + 1.
 LDA LCWR1
 LDA LCWR1
 STZ $08
 LDA #$E0
 STA $09
 LDA #>KEND
 SEC
 SBC #$DF
 TAX
IN2 LDA ($06),Y
 STA ($08),Y
 INY
 BNE IN2
 INC $07
 INC $09
 DEX
 BNE IN2
* ---- the vectors at $FFFA ------------------------
* NMI and IRQ return at once (KRTI); RESET is the
* ROM's.  The IIe switches the card out on reset,
* so the ROM's own vector is the one used anyway -
* this is only in case something reads ours.
 LDA #<KRTI
 STA $FFFA
 STA $FFFE
 LDA #>KRTI
 STA $FFFB
 STA $FFFF
 LDA #$62
 STA $FFFC
 LDA #$FA
 STA $FFFD
* ---- KINIT, with the card in for reading --------
 LDA LCRW1
 LDA LCRW1
 LDA IBOOT
 JSR KINIT
* ---- and COBOL.SYSTEM --------------------------
* KLDSYS never comes back: it loads COBOL.SYSTEM
* over this code and starts it, or says why not
* and stops.  (Stage 1 ran KTEST1 here; stage 2's
* test is a program of its own, TEST2.S, that the
* test disk carries AS its COBOL.SYSTEM.)
 JMP KLDSYS

IBOOT DFB $00

* INSEND: the last byte of what must stay below
* KBLK, and the byte before the $BF00 page
INSEND DFB $00

* ==== the $BF00 page =============================
 ORG $BF00
 PUT KPAGE

* ==== the kernel =================================
 ORG $E000
 PUT KMLI
 PUT KDEV
 PUT KPATH
 PUT KCALL1
 PUT KFILE
 PUT KRW
 PUT KBMAP
 PUT KCALL2
 PUT KCALL3
 PUT KCALL4
* KEND: one byte past the kernel, for INSTALL
KEND DFB $00
