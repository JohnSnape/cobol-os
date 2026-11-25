* KEQU.S  the kernel's equates
* PUT first by COBOLOS.S.  No code, no bytes.
*
* Everything the kernel, its installer and the
* stage tests share: the soft switches, the ProDOS
* addresses of the $BF00 page that COBOL reads,
* the kernel's zero page and its data in the
* language card.  All of it is defined BEFORE any
* code uses it, because Merlin 8 gives a small EQU
* met after its use a wrong value (the COBOL
* tree's CMPCON.S tells that story).

* ---- language card switches ---------------------
* Read once to select, twice in a row to enable
* writing as well.  Bank 1 is $C088-$C08B, bank 2
* $C080-$C083; the low two bits pick the mode:
*   x0  read RAM, no write
*   x1  read ROM, write RAM (read twice)
*   x2  read ROM, no write
*   x3  read RAM, write RAM (read twice)
LCRW1 EQU $C08B
LCWR1 EQU $C089
LCROM1 EQU $C08A
* bit 7: bank 2 is selected / RAM is being read
RDLCBNK2 EQU $C011
RDLCRAM EQU $C012
* bit 7: the alternate zero page is in
RDALTZP EQU $C016

* ---- the screen and keyboard, for QUIT ---------
* Writes to these switches set them; QUIT's screen
* is drawn straight into text page 1 (KCALL4.S).
KBD EQU $C000
KSTROBE EQU $C010
S80STOFF EQU $C000
SRAMWRTM EQU $C004
SRAMWRTA EQU $C005
SSLOTCX EQU $C006
S80COLOF EQU $C00C
S80COLON EQU $C00D
SALTCHOF EQU $C00E
SALTCHON EQU $C00F
STXTON EQU $C051
SPAGE1 EQU $C054
* the reset vector and its power-up byte
SOFTEV EQU $03F2
PWREDUP EQU $03F4
* the monitor's start-up trio, called by KQBOOT
* in the $BF00 page before it boots a slot
MINIT EQU $FB2F
MSETVID EQU $FE93
MSETKBD EQU $FE89

* ---- the monitor, for the installer and tests --
COUT EQU $FDED
CROUT EQU $FD8E
PRBYTE EQU $FDDA
HOME EQU $FC58
RDKEY EQU $FD0C

* ---- the $BF00 page, at ProDOS's addresses -----
* DESIGN.md section 5.  These are the bytes COBOL
* reads or writes; KPAGE.S builds the page.
MLI EQU $BF00
DATETIME EQU $BF06
DEVADR EQU $BF10
DEVNUM EQU $BF30
DEVCNT EQU $BF31
DEVLST EQU $BF32
MEMTAB EQU $BF58
DATELO EQU $BF90
TIMELO EQU $BF92
MACHID EQU $BF98

* ---- the kernel's zero page, $40-$4E -----------
* ProDOS's own range.  COBOL's zero page map
* already leaves $40-$4E alone, so the kernel may
* use all of it.  The SmartPort firmware scribbles
* in $42-$47 during a call, so KDIO saves all
* fifteen bytes across every call to the card.
KPTR EQU $40
KPRM EQU $42
KBUF EQU $44
KNAM EQU $46
KT0 EQU $48
KT1 EQU $49
KT2 EQU $4A
KT3 EQU $4B
KT4 EQU $4C
KT5 EQU $4D
KT6 EQU $4E

* ---- the block buffer, in MAIN memory ----------
* 512 bytes for directory blocks.  The firmware
* runs with the ROM in, so it cannot reach a buffer
* in the language card (DESIGN.md section 4.2).
* $BD00-$BEFF, the user's choice (DESIGN 4.2).
* COBOL kept ERRBUF, its two prefixes and CPYBUF
* here; the COBOL.OS build of COBOL moved them to
* $2E00-$2FFF (stage 4, 2026-11-24), and during
* stages 1-3, which ran the unchanged binaries,
* this buffer borrowed $2E00 instead.  So a disk
* with COBOL.OS on it needs the COBOL.OS build of
* COBOL: the ProDOS build's ERRBUF would land here.
KBLK EQU $BD00

* ---- the kernel's data: language card bank 1 ---
* $D000-$DFFF in bank 1.  The kernel always runs
* with bank 1 selected, so all of this is in view
* whenever kernel code is.  Not in the COBOL.OS
* file: KINIT clears it.
*
* CLKAREA: where a clock driver is copied.  The
* clock vector at $BF07 points here, and COBOL's
* CLOCK.S copies its No-Slot Clock driver to
* whatever that vector says, 125 bytes at most -
* ProDOS's limit, which CLOCK.S was written to.
CLKAREA EQU $D000
* the devices found at boot, up to 14
KDMAX EQU 14
KNDEV EQU $D080
* ProDOS unit numbers, DSSS0000
KDUNIT EQU $D081
* SmartPort unit numbers, 1 or 2
KDSPU EQU $D090
* the card's SmartPort entry, low and high
KDENTL EQU $D0A0
KDENTH EQU $D0B0
* the prefix: a length, then /VOL/DIR/ - always
* with both slashes, or length 0 for none
KPFX EQU $D100
* zero page $40-$4E while the card has the machine
KZSAVE EQU $D150
* the caller's Y, and the call number
KSAVY EQU $D160
KCALL EQU $D161
* the boot unit, ProDOS form
KBOOT EQU $D162
* a block number for KDIO, and its command
KBLKL EQU $D163
KBLKH EQU $D164
KCMD EQU $D165
* which device a call is using (an index)
KDEVX EQU $D166
* the path being resolved: a length, then text
KWLEN EQU $D200
KWPATH EQU $D201
* where KWALK leaves what it found
* KWTYPE: storage type, high nibble ($F0 = vol)
* KWKEYL/H: the key block
* KWEBLL/H: the directory block holding the
*   entry, and KWEOFF its offset in that block
KWTYPE EQU $D290
KWKEYL EQU $D291
KWKEYH EQU $D292
KWEBLL EQU $D293
KWEBLH EQU $D294
KWEOFF EQU $D295
* the walk's position in KWPATH, the component
* in hand, and its length
KWPOS EQU $D296
KWCLEN EQU $D297
KWCOMP EQU $D2A0
* a volume name read from block 2
KVLEN EQU $D2B0
KVNAME EQU $D2B1

* ---- the file layer's own working bytes --------
* KFX: the open file in hand, as its FCB's offset
*   (0, 32, 64 ... 224), for LDA Fxxxx,X
* KBIL/H: which block OF THE FILE the mark is in
*   (the mark shifted right 9 bits)
* KMIX: which master-index entry a tree file needs
* KIXL/H: the index block that entry names
* KCNL/H: a directory walk's counter
* KREQL/H, KTRNL/H, KRUNL/H: READ's request, the
*   bytes moved so far, and this block's share
* KNLHIT: READ stopped on the newline character
KFX EQU $D170
KBIL EQU $D171
KBIH EQU $D172
KMIX EQU $D173
KIXL EQU $D174
KIXH EQU $D175
KCNL EQU $D176
KCNH EQU $D177
KREQL EQU $D178
KREQH EQU $D179
KTRNL EQU $D17A
KTRNH EQU $D17B
KRUNL EQU $D17C
KRUNH EQU $D17D
KNLHIT EQU $D17E
* GET_FILE_INFO on a volume: the bitmap's first
* block, the volume's size, and a count of free
* blocks
KVBML EQU $D180
KVBMH EQU $D181
KVTOTL EQU $D182
KVTOTH EQU $D183
KVFREL EQU $D184
KVFREH EQU $D185
KVNBM EQU $D186

* ---- the open files: eight FCBs, $D300-$D3FF ---
* ProDOS allows eight open files and so does this.
* One file control block of 32 bytes each; file n
* (its ref number, 1-8) is at $D300 + (n-1)*32, so
* every field below is read as FIELD,X with X the
* FCB's offset.  KINIT's clear of $D000-$D2FF
* does not reach here: KINIT clears these itself.
*
* THE FILE BUFFER.  OPEN is handed 1,024 bytes of
* the caller's main memory and keeps them until
* CLOSE: the first 512 hold the data block the
* mark is in, the second 512 the index block that
* names it (sapling and tree files).  Main memory,
* because the SmartPort firmware reads and writes
* there and cannot see the language card.
KNFCB EQU 8
* 0 = free, else the ref number
FUSE EQU $D300
* the device's index (KDUNIT etc.)
FDEV EQU $D301
* storage type, high nibble: $10 seedling, $20
* sapling, $30 tree, $D0 directory, $F0 volume
FSTOR EQU $D302
FKEYL EQU $D303
FKEYH EQU $D304
* where the file's own directory entry is, for
* stage 3, which must write EOF and dates back
FEBLL EQU $D305
FEBLH EQU $D306
FEOFF EQU $D307
* the caller's 1,024-byte buffer
FBUFL EQU $D308
FBUFH EQU $D309
* the mark and the end of file, 24 bits each
FMRK0 EQU $D30A
FMRK1 EQU $D30B
FMRK2 EQU $D30C
FEOF0 EQU $D30D
FEOF1 EQU $D30E
FEOF2 EQU $D30F
* NEWLINE: the mask (0 = off) and the character
FNLMK EQU $D310
FNLCH EQU $D311
* the data half of the buffer holds block FDBI of
* the file when FDVAL is not 0
FDBIL EQU $D312
FDBIH EQU $D313
FDVAL EQU $D314
* the index half holds master entry FIMIX's index
* block when FIVAL is not 0 (sapling: entry 0, the
* key block itself)
FIVAL EQU $D315
FIMIX EQU $D316
* the entry's access byte: bit 0 read, bit 1
* write, bit 5 backup, bit 6 rename, bit 7 destroy
FACC EQU $D317
* stage 3, writing.  FDBK: the disk block the data
* half came from (0 = a hole, no block yet).
* FIXB: the disk block the index half came from
* (0 = a hole).  FBLK: the entry's "blocks used".
FDBKL EQU $D318
FDBKH EQU $D319
FIXBL EQU $D31A
FIXBH EQU $D31B
FBLKL EQU $D31C
FBLKH EQU $D31D
* what must be written back: bit 0 the data half,
* bit 1 the index half, bit 2 the directory entry
* (EOF, blocks used, key, storage type, date)
FDIRT EQU $D31E

* ---- stage 3: the bitmap and the writers -------
* THE BITMAP CACHE.  One bitmap block (4,096
* blocks' worth) is kept at KBMC in bank 1.  It is
* read through KBLK and copied up, and written
* back the same way, so KBLK is never held across
* an allocation or a free.  At the end of every
* call KMLI writes it back if it changed and
* forgets it, so a disk swapped between calls is
* never written from another disk's bitmap.
KBMC EQU $D400
* an index block and a master index block, copied
* up out of KBLK while their entries are freed
KIDC EQU $D600
KMSC EQU $D800
* RENAME's new path, a length and 64 characters
KRNP EQU $DA00
* the cache: valid, changed, for which device,
* which of the bitmap's blocks; the bitmap's first
* block, the volume's size and its bitmap blocks
KBMVAL EQU $D190
KBMDTY EQU $D191
KBMDV EQU $D192
KBMIX EQU $D193
KBMWT EQU $D194
KBMPL EQU $D195
KBMPH EQU $D196
KBMTL EQU $D197
KBMTH EQU $D198
KBMNB EQU $D199
* KALLOC's working bytes and its answer, KNB
KACNT EQU $D19A
KABH EQU $D19B
KABIT EQU $D19C
KNBL EQU $D19D
KNBH EQU $D19E
* KFREEB's block, and a count of blocks freed
KFBL EQU $D19F
KFBH EQU $D1A0
KFRCL EQU $D1A1
KFRCH EQU $D1A2
* KDFLUSH keeps KLOAD's block number here
KSVBL EQU $D1A3
KSVBH EQU $D1A4
* KTRUNC: keep blocks below KKP of the file whose
* storage type and key are KTSTOR, KTKEY
KKPL EQU $D1A5
KKPH EQU $D1A6
KTSTOR EQU $D1A7
KTKEYL EQU $D1A8
KTKEYH EQU $D1A9
KTM EQU $D1AA
KMCHG EQU $D1AB
KICHG EQU $D1AC
KTFROM EQU $D1AD
KTWHOL EQU $D1AE
KTY EQU $D1AF
KTMP EQU $D1B0
* CREATE: the parent directory, the free slot,
* the directory's last block, the new key block
CPKEYL EQU $D1B1
CPKEYH EQU $D1B2
CPTYP EQU $D1B3
CPEBLL EQU $D1B4
CPEBLH EQU $D1B5
CPEOFF EQU $D1B6
CSLBL EQU $D1B7
CSLBH EQU $D1B8
CSLIX EQU $D1B9
CLASTL EQU $D1BA
CLASTH EQU $D1BB
CSTOR EQU $D1BC
CKEYL EQU $D1BD
CKEYH EQU $D1BE
CIX EQU $D1BF
* RENAME's new last name: a length, 15 characters
KRNN EQU $D1C0
* DESTROY: the entry's block and place, and the
* parent directory's key block
DEBLL EQU $D1D0
DEBLH EQU $D1D1
DEOFF EQU $D1D2
DPKEYL EQU $D1D3
DPKEYH EQU $D1D4

* ---- ProDOS error codes -------------------------
EBADCL EQU $01
EBADCT EQU $04
EIO EQU $27
ENODEV EQU $28
EWPROT EQU $2B
EBADPA EQU $40
ENFILE EQU $42
EBADRF EQU $43
EPATH EQU $44
EVOL EQU $45
EFILE EQU $46
EDUP EQU $47
EFULL EQU $48
EVFULL EQU $49
ESTYPE EQU $4B
EEOF EQU $4C
EPOSN EQU $4D
EACCES EQU $4E
EOPEN EQU $50
EDIRDM EQU $51
ENOTPD EQU $52
