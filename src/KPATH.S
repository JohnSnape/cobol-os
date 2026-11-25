* KPATH.S  pathnames: checking them, and walking
* them down the directories to what they name.
*
* THE RULES ARE ProDOS'S, and COBOL already checks
* them before it calls (PXCHK, DECISIONS 8.10):
*   a name is 1-15 characters, a letter first,
*   then letters, digits and periods;
*   a full path starts with "/" and its first name
*   is a volume; a partial path is added to the
*   prefix; one trailing "/" is allowed.
* Lower case is folded to upper case, and bit 7 is
* ignored, as ProDOS does - so /cobol/obj and
* /COBOL/OBJ are the same directory.
*
* Two steps, because every call that takes a path
* needs both and some need only the first:
*   KPARSE  the caller's path -> KWPATH, the full
*           path in capitals, with no trailing "/",
*           checked.  Bad: $40.
*   KWALK   KWPATH -> the thing it names: its
*           storage type, key block, and where its
*           directory entry is.  Missing volume
*           $45; a missing directory on the way $44;
*           a missing last name $46.

* ==== KPARSE =====================================
* In:  KNAM -> the caller's pathname, a length
*      then the characters
* Out: carry clear, KWLEN/KWPATH; or carry set,
*      A = $40
KPARSE LDA (KNAM)
 BEQ KPB0
 CMP #65
 BCC KP0
* (KPBAD is past a branch's reach from here)
KPB0 JMP KPBAD
KP0 STA KT0
 STZ KWLEN
 LDY #$01
 LDA (KNAM),Y
 AND #$7F
 CMP #'/'
 BEQ KP2
* ---- a partial path: the prefix first -----------
* No prefix and a partial path is $40, ProDOS's
* answer and the one DECISIONS 8.10 relies on.
 LDX KPFX
 BEQ KPB0
 STX KWLEN
KP1 LDA KPFX,X
 STA KWPATH-1,X
 DEX
 BNE KP1
* ---- the caller's characters, folded ------------
KP2 LDA (KNAM),Y
 AND #$7F
 CMP #$61
 BCC KP3
 CMP #$7B
 BCS KP3
 AND #$DF
KP3 LDX KWLEN
 STA KWPATH,X
 INC KWLEN
 INY
 CPY KT0
 BCC KP2
 BEQ KP2
* ---- one trailing "/" goes ----------------------
 LDX KWLEN
 CPX #$02
 BCC KP4
 LDA KWPATH-1,X
 CMP #'/'
 BNE KP4
 DEC KWLEN
* ---- check every name ---------------------------
KP4 LDA KWPATH
 CMP #'/'
 BNE KPBAD
 LDX #$01
KP5 CPX KWLEN
 BCS KPBAD
 LDA KWPATH,X
 JSR KLETR
 BCS KPBAD
 LDY #$01
 INX
KP6 CPX KWLEN
 BCS KPOK
 LDA KWPATH,X
 CMP #'/'
 BEQ KP7
 JSR KNMCH
 BCS KPBAD
 INY
 CPY #16
 BCS KPBAD
 INX
 BRA KP6
KP7 INX
 BRA KP5
KPOK CLC
 RTS
KPBAD LDA #EBADPA
 SEC
 RTS

* ---- KLETR: carry clear if A is A-Z ------------
KLETR CMP #'A'
 BCC KL1
 CMP #'Z'+1
 BCS KL1
 CLC
 RTS
KL1 SEC
 RTS

* ---- KNMCH: carry clear if A may follow --------
* the first letter: A-Z, 0-9 or a period
KNMCH CMP #'.'
 BEQ KN1
 CMP #'0'
 BCC KL1
 CMP #'9'+1
 BCC KN1
 BRA KLETR
KN1 CLC
 RTS

* ==== KNEXTC: the next name out of KWPATH ========
* Copies from KWPOS up to the next "/" or the end
* into KWCOMP, length KWCLEN, and moves KWPOS past
* the "/".  Afterwards KWPOS >= KWLEN means the name
* just taken was the last.
KNEXTC LDX KWPOS
 LDY #$00
KNC1 CPX KWLEN
 BCS KNC3
 LDA KWPATH,X
 INX
 CMP #'/'
 BEQ KNC3
 STA KWCOMP,Y
 INY
 BRA KNC1
KNC3 STX KWPOS
 STY KWCLEN
 RTS

* ==== KWALK ======================================
* In:  KWPATH, checked by KPARSE
* Out: carry clear and
*        KDEVX   the device the volume is on
*        KWTYPE  storage type, high nibble: $F0
*                for the volume itself, $D0 a
*                directory, $10-$30 a file
*        KWKEYL/H  its key block
*        KWEBLL/H, KWEOFF  the directory block
*                holding its entry and the entry's
*                number in that block (0 for a
*                volume, which has no entry)
*      or carry set and A = the error
KWALK LDA #$01
 STA KWPOS
 JSR KNEXTC
* ---- the volume: whichever drive has it --------
* A drive that cannot be read, or holds no ProDOS
* volume, is passed over, not reported: the name
* may well be on the next one.
 LDX #$00
KW1 CPX KNDEV
 BCC KW2
 LDA #EVOL
 SEC
 RTS
KW2 JSR KRDVOL
 BCS KW4
 LDA KVLEN
 CMP KWCLEN
 BNE KW4
 TAY
KW3 LDA KVNAME-1,Y
 CMP KWCOMP-1,Y
 BNE KW4
 DEY
 BNE KW3
 BRA KW5
KW4 INX
 BRA KW1
KW5 STX KDEVX
 LDA #$F0
 STA KWTYPE
 LDA #$02
 STA KWKEYL
 STZ KWKEYH
 STZ KWEBLL
 STZ KWEBLH
 STZ KWEOFF
* ---- each further name, one directory down -----
KW6 LDA KWPOS
 CMP KWLEN
 BCC KW7
 CLC
 RTS
* what we hold must be a directory to go further
KW7 LDA KWTYPE
 CMP #$F0
 BEQ KW8
 CMP #$D0
 BEQ KW8
 LDA #EPATH
 SEC
 RTS
KW8 JSR KNEXTC
 JSR KSRCH
 BCC KW6
 CMP #$00
 BNE KW9
* not there: the last name is a missing file, any
* earlier one a missing directory
 LDA #EFILE
 LDX KWPOS
 CPX KWLEN
 BCS KW9
 LDA #EPATH
KW9 SEC
 RTS

* ==== KSRCH: KWCOMP in the directory KWKEY =======
* Reads the directory's blocks in turn, following
* each block's "next" pointer, and compares every
* live entry's name.  The first entry of the KEY
* block is the directory's own header, not a file,
* and is skipped.
* Out: carry clear, and KWTYPE/KWKEY/KWEBL/KWEOFF
*      describe what was found; or carry set and
*      A = 0 (not there) or a device error.
KSRCH LDA KWKEYL
 STA KBLKL
 LDA KWKEYH
 STA KBLKH
 LDA #$01
 STA KT4
KSR1 LDA #<KBLK
 STA KBUF
 LDA #>KBLK
 STA KBUF+1
 LDX KDEVX
 LDA #$01
 JSR KDIO
 BCC KSR2
 RTS
KSR2 LDA #<KBLK+4
 STA KT0
 LDA #>KBLK
 STA KT1
 LDA #13
 STA KT2
 STZ KT3
 LDA KT4
 BEQ KSR3
* the key block: step over the header
 STZ KT4
 BRA KSRN
KSR3 LDA (KT0)
 AND #$F0
 BEQ KSRN
 LDA (KT0)
 AND #$0F
 CMP KWCLEN
 BNE KSRN
 TAY
KSR4 LDA (KT0),Y
 CMP KWCOMP-1,Y
 BNE KSRN
 DEY
 BNE KSR4
* ---- found ---------------------------------------
 LDA (KT0)
 AND #$F0
 STA KWTYPE
 LDY #$11
 LDA (KT0),Y
 STA KWKEYL
 INY
 LDA (KT0),Y
 STA KWKEYH
 LDA KBLKL
 STA KWEBLL
 LDA KBLKH
 STA KWEBLH
 LDA KT3
 STA KWEOFF
 CLC
 RTS
* ---- the next entry, or the next block ---------
KSRN LDA KT0
 CLC
 ADC #39
 STA KT0
 BCC KSR5
 INC KT1
KSR5 INC KT3
 DEC KT2
 BNE KSR3
 LDA KBLK+2
 STA KBLKL
 LDA KBLK+3
 STA KBLKH
 ORA KBLKL
 BEQ KSR6
 JMP KSR1
KSR6 LDA #$00
 SEC
 RTS
