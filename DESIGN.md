# COBOL on its own OS — the design

Started 2026-11-22.  **Stages 1 and 2 are built and pass in AppleWin
(2026-11-22, 2026-11-23); `STATUS.md` says where things stand.**
The OS is **COBOL.OS**, which is also the kernel file's name on disk
(the user, 2026-11-22).

The user's brief: *"an offshoot that runs on our own OS that sits on
the language card, like ProDOS does, but is our own system."*

The user's four decisions (2026-11-22), which everything below
follows from:

| | decided |
|---|---|
| Which OS | **a new, small COBOL kernel**, not SWA. It supplies just the calls COBOL makes, and reuses SWA's proven boot and SmartPort code as parts |
| Disk format | **ProDOS-format volumes** — same blocks, directories and bitmap |
| Source | **a fork in its own folder** (`P:\COBOLOS`); `P:\COBOL` stays the ProDOS build, untouched |
| Timing | **design now**; the pending COBOL tests wait |

---

## 1. What the kernel is

A file system and a block driver, living in the **main** language
card at `$D000`–`$FFFF`, entered through `JSR $BF00` with the call
number and parameter pointer inline. That is ProDOS's shape exactly,
and on purpose:

- **The calls are ProDOS's calls**: same numbers, same parameter
  blocks, same error codes, same `$BF00` page addresses. COBOL's
  call sites (85 `JSR MLI`s) don't change, and neither do the
  binaries. **The first test of the kernel is the unchanged COBOL
  disk.**
- **The code is ours**, written from the ProDOS Technical Reference
  Manual's description of the format and the calls, not from
  ProDOS's code.
- **It does less.** ProDOS 8 is ~16K because it carries a Disk II
  driver, the /RAM driver, clock drivers, interrupt handling,
  BASIC.SYSTEM support and 26 calls. This kernel carries the 16 calls
  COBOL makes (§3), plus two for disk utilities, and one driver.

What "our own" buys, beyond the satisfaction of it: the language card
space ProDOS fills becomes ours. §7 estimates the kernel at about 8K
of the 16K. **The rest is room COBOL can grow into** — the library
has 2 bytes free in main memory today (§9).

## 2. Why not SWA, and what is borrowed from it

SWA (`P:\SWA`) is a whole operating system with a frozen ABI of 117
calls, its own file system and a seven-book plan, and it is at the
boot/console/SmartPort stage. COBOL needs neither its calls nor its
format, and two parts of SWA's memory plan collide with COBOL's:

| | SWA | COBOL |
|---|---|---|
| aux bank 0 `$1000`–`$BFFF` | command history, clipboard, 41K block cache | source records `$0C00` up, p-code `$AC00`–`$BEFF` |
| main `$BE00`–`$BEFF` | SmartPort trampoline, parameter list | `SYSPFX`, `WRKPFX`, `CPYBUF` |

Neither has to give way if the COBOL kernel is its own thing. **SWA is
the parts bin**, as `D:\Claude Projects\NEWOS` was for SWA:

| part | from | state |
|---|---|---|
| reading blocks from firmware inside a boot block | `BOOT.S` (310 bytes) | runs on AppleWin |
| SmartPort find / STATUS / READ / WRITE, called through a main-RAM trampoline | `SMARTPORT.S` (413 bytes) | `SPTEST PASS`, 2026-11-09 |
| bank-1 call gate (`CALLB1`, with its A-register fix) | `JUMPTABLE.md` §5 | runs |
| Merlin32 build + AppleWin driver | `tools/` in both trees | runs |

SWA keeps its own course. Nothing here changes a SWA document.

## 3. The calls

Counted from the sources on 2026-11-22 (`JSR MLI` followed by the
call byte):

| call | # | sites | used for |
|---|---|---|---|
| `CLOSE` | `$CC` | 13 | everything |
| `OPEN` | `$C8` | 12 | everything; directories too (CATALOG reads them as files) |
| `READ` | `$CA` | 10 | everything |
| `GET_PREFIX` | `$C7` | 8 | building full paths |
| `WRITE` | `$CB` | 7 | saves, RECMAN |
| `DESTROY` | `$C1` | 7 | safe replace, Utilities |
| `CREATE` | `$C0` | 7 | saves, OPEN OUTPUT |
| `SET_PREFIX` | `$C6` | 6 | boot, `0/` |
| `SET_MARK` | `$CE` | 3 | RECMAN random access, EDIT, clipboard |
| `RENAME` | `$C2` | 3 | safe replace, Utilities |
| `ON_LINE` | `$C5` | 2 | the volume name when no prefix is set |
| `GET_FILE_INFO` | `$C4` | 2 | RECMAN, Utilities |
| `QUIT` | `$65` | 2 | leaving the system (§8) |
| `GET_EOF` | `$D1` | 1 | RECMAN |
| `SET_EOF` | `$D0` | 1 | RECMAN |
| `NEWLINE` | `$C9` | 1 | the COPY reader in the lexer |

Added for the kernel's own utilities (§8): **`READ_BLOCK` `$80`** and
**`WRITE_BLOCK` `$81`**, with ProDOS's parameter blocks.

Also `GET_MARK` `$CF`, added at stage 2 for the test (DECISIONS
4.5). Not provided, and nothing calls them: `FLUSH`,
`SET_FILE_INFO`, `GET_TIME`, `ALLOC_INTERRUPT`,
`DEALLOC_INTERRUPT`, `GET_BUF`, `SET_BUF`. An unknown call number
returns `$01`, as ProDOS does.

**Error codes are ProDOS's**, because COBOL tests them by number:
`$40` bad pathname (DECISIONS 8.10's "31"), `$44` path not found,
`$46` file not found, `$48` disk full, `$4C` end of file, `$52` not a
ProDOS volume, and the rest of ProDOS's list where they apply (`$27`
I/O error, `$2B` write-protected, `$42` too many files open, `$43` bad
reference, `$45` volume not found, `$47` duplicate name, `$49`
directory full, `$4D` position out of range, `$4E` access, `$50` file
open, `$51` directory damaged).

### 3.1 Behaviour that has to match exactly

These are the places a "nearly ProDOS" kernel would break COBOL
quietly:

- **The root directory holds 51 entries and does not grow**; a
  subdirectory grows a block at a time. The 51-entry trap in
  `tools/emu/README.txt` must reproduce.
- **All three storage types**, seedling (≤ 512 bytes), sapling
  (≤ 128K) and tree (≤ 16M), for reading *and* for a file that grows
  across the boundaries. A data file of records passes 128K easily.
- **Sparse files**: `SET_MARK` past the end and a `WRITE` leaves holes
  that read back as zeros and own no blocks. RECMAN's random files
  may do exactly this.
- **The 1,024-byte file buffer** the caller passes to `OPEN` is the
  kernel's for as long as the file is open: data block in the first
  half, index block in the second. COBOL already gives every open
  file one (`$B000`–`$BBFF`).
- **Paths**: the ProDOS name rules DECISIONS 8.10 checks (1–15
  characters, letter first, letters/digits/periods, 64 in all), the
  prefix, partial paths, and `$40` for a partial path with no prefix.
- **`NEWLINE`** mode with its mask and character.
- **Dates**: create and modify stamps from `$BF90`–`$BF93`, after
  calling the clock hook at `$BF06`.

## 4. Memory

### 4.1 The main language card — the kernel

| range | contents |
|---|---|
| `$D000`–`$DFFF` bank 1 | the file system's working data: the volume control blocks, the file control blocks (8 open files, like ProDOS), the prefix, a cached bitmap block |
| `$D000`–`$DFFF` bank 2 | spare — the first place §9's dividend goes |
| `$E000`–`$FFF9` | the kernel's code: dispatcher, path parser, directory, file I/O, allocation, the SmartPort driver |
| `$FFFA`–`$FFFF` | NMI, RESET, IRQ vectors (§8.3) |

Code goes above `$E000` so it is always visible whichever `$D000`
bank is switched in, the rule SYMAUX already follows on the aux side.

### 4.2 Main memory the kernel needs

Two things, both as ProDOS has them:

- **The `$BF00` page** (§5).
- **One 512-byte block buffer in main RAM.** The SmartPort firmware
  runs from slot ROM and may call the monitor ROM, so the kernel
  calls it with the ROM switched in (through the trampoline, as SWA
  does). The firmware cannot then read a buffer in the language card.
  Directory blocks and bitmap blocks need somewhere to land. File
  data does not: it lands in the caller's file buffer.

**Decided: `$BD00`–`$BEFF`** (the user, 2026-11-22). COBOL keeps
`ERRBUF`, `SYSPFX`, `WRKPFX` and `CPYBUF` (about 250 bytes) there
today. In the fork they move into the free space above COBOL.SYSTEM
(`$2872`–`$2FFF`, 1.9K, always resident). That is a fork-only source
change: the equates and a `DS`. No firmware probe: even if the
firmware could read a block into the language card, it could not
write one from there, so the buffer is needed either way.

**Until stage 4 makes that move**, the unchanged COBOL binaries still
use `$BD00`–`$BEFF`, so for stages 1–3 the kernel's buffer is
**`$2E00`–`$2FFF`**, the top of COBOL.SYSTEM's free space, which
nothing uses (MEMMAP: "1.9K free to `$2FFF`"). It's one equate in the
kernel, and it changes to `$BD00` at stage 4. Not text page 2: the
compiler fills all of it with descriptors and makes MLI calls while
they're there.

### 4.3 What does not change

- **The aux language card is COBOL's** (COBOL.AUX, SYMAUX, the prefix
  table at `$F800`). The kernel never switches ALTZP and never
  touches it.
- **Aux memory is COBOL's.** The kernel has no /RAM disk, and never
  selects a RamWorks bank.
- **Zero page**: the kernel uses `$40`–`$4F` only, which COBOL's
  ZP map already leaves to ProDOS. Nothing else.
- **COBOL.SYSTEM loads at `$2000`** and is entered there, as ProDOS
  does it.

## 5. The `$BF00` page

Address-compatible with ProDOS for everything COBOL reads or writes;
the rest of the page is ours (entry stub, trampolines).

| address | ProDOS meaning | here |
|---|---|---|
| `$BF00` | `JMP` MLI entry | same |
| `$BF06` | clock vector (`JMP` or `RTS`) | same; `RTS` until CLOCK.S installs its No-Slot Clock driver, exactly as now |
| `$BF10`–`$BF2F` | device driver vectors | all set to the "no device" address, so RAMOFF (SYSUTIL.S), which compares `$BF26` with `$BF10`, finds no /RAM and does nothing |
| `$BF30` | `DEVNUM`, last unit used | same |
| `$BF31` / `$BF32`– | device count / list | same format, the units found at boot |
| `$BF58`–`$BF6F` | memory bitmap | kept as bytes (nothing reads it; COBOL stopped writing it 2026-08-16) |
| `$BF90`–`$BF93` | date and time | same |
| `$BF98` | `MACHID` | same meaning; bit 0 = clock present |
| `$BFFE` / `$BFFF` | `KBAKVER` / `KVERSION` | **`$C0`**: no ProDOS uses it (2.4.x is `$24`), so `LDA $BFFF / CMP #$C0 / BCS` tells a program it is on COBOL.OS (§8.4) |
| `$BFxx` rest | ProDOS internals | **our entry stub and SmartPort trampoline** |

### 5.1 The entry stub

ProDOS's own problem, solved the same way: the caller runs with the
ROM visible (COBOL's startup calls `COUT` and `HOME`, and `AUXMOVE`
lives in `$C3xx`). The stub in `$BFxx`:

1. saves the language-card state (`$C011` bank 2?, `$C012` RAM read?),
2. switches the main card's RAM in, read and write, bank 1,
3. `JSR`s the dispatcher above `$E000`,
4. puts the card back as it found it — normally ROM read,
5. returns with ProDOS's conventions: carry clear and `A` = 0, or
   carry set and `A` = the error; `RTS` lands past the three inline
   bytes.

The SmartPort trampoline is the same idea backwards: from the
kernel, switch ROM in, call the card, switch the kernel back.

## 6. Disks and booting

### 6.1 The driver

**SmartPort only, 3.5" and hard drives** (the user, 2026-11-22), by
unit number. That covers AppleWin's hard disk card in slot 7
(`COBOL32.po`), the user's 3.5" SmartPort drive and 32MB SmartPort
hard drive. **No Disk II 5.25" driver**: a 140K floppy can't hold the
system anyway, and the driver would be ~1.5K of nibble code.

At boot the kernel scans slots 7 down to 1 for SmartPort firmware,
asks each unit its size, and builds the `$BF31` device list in
ProDOS's slot/drive format, so `ON_LINE` with unit 0 works as COBOL
expects. One volume per unit, up to 65,535 blocks (32MB), the ProDOS
limit.

### 6.2 The boot

A ProDOS volume gives a loader exactly two blocks, 0 and 1. The
firmware loads block 0 at `$0800` and jumps to `$0801`.

1. **Block 0 (and 1 if needed)**: our loader. It reads the volume
   directory (block 2 onward), finds the file **`COBOL.OS`**, follows
   its index block and loads it at `$2000`. It does what ProDOS's own
   boot block does with the file `PRODOS`, in our code. SWA's `BOOT.S`
   already reads blocks through the firmware from a boot block.
2. **`COBOL.OS` at `$2000`**: copies the kernel into the main language
   card, builds the `$BF00` page, scans for devices, sets the prefix to
   the boot volume, then loads **`COBOL.SYSTEM`** at `$2000` and jumps
   to it. COBOL.SYSTEM boots exactly as it does under ProDOS.

A disk boots our OS when its blocks 0–1 are ours and `COBOL.OS` is in
its root. **Everything else on the disk is unchanged.** Put ProDOS's
boot blocks back and it boots ProDOS again, files and all. Testing
needs no new disk tools: `cp2` adds `COBOL.OS`, a two-line script
writes blocks 0–1 of the `.po` (block *n* is at byte *n* × 512).

## 7. Size estimate

Arithmetic, to be replaced by measurement as soon as pieces assemble
(the SWA lesson — its first measured driver came in 190 bytes under
the estimate):

| piece | bytes |
|---|---|
| entry stub, dispatcher, error exit | 300 |
| SmartPort driver + device scan | 600 |
| path parsing, prefix, directory search | 900 |
| `OPEN` / `CLOSE`, file control blocks | 500 |
| `READ` / `WRITE` / `NEWLINE`, seedling/sapling/tree, growth | 1,900 |
| bitmap: allocate and free | 400 |
| `CREATE` (with subdirectory growth) | 650 |
| `DESTROY` (frees all three storage types) | 450 |
| `RENAME`, `GET_FILE_INFO`, `ON_LINE`, prefixes | 600 |
| `SET_MARK`, `GET_EOF`, `SET_EOF` (truncation frees blocks) | 550 |
| `READ_BLOCK`, `WRITE_BLOCK`, `QUIT`, reset | 300 |
| **total** | **about 7,150** |

Against `$E000`–`$FFF9`, 8,186 bytes, with `$D000` bank 1 for data
and bank 2 spare. The boot loader and the stage-2 installer are not
resident and do not count.

## 8. The edges

### 8.1 `QUIT`

ProDOS's `QUIT` goes to a program selector. There is none here.
**`QUIT` closes every file, clears the screen and shows, in 80
columns, centred:**

```
Change the disk and press RETURN to restart the system
```

(the user's wording, 2026-11-22). It waits for RETURN alone and then
**boots the slot it booted from** (`JMP $Cs00`), so whatever disk is
in that drive now starts up: the same disk gives the COBOL menu again
(or a turnkey disk's program), and a different disk boots whatever
is on it.

The kernel draws the line itself, straight into text page 1 (main and
aux alternating, 80STORE off, the way COBOL's TEXTDRV does), because
whatever COBOL left on the screen and in the switches can't be
trusted at that point. About 80 bytes.

COBOL calls `QUIT` in two places, SYSBOOT (a refused start) and
SYSMENU (leaving the system). Neither needs to change.

### 8.2 Making a disk bootable

The Utilities turnkey copier (UTILD.S `UTURN`) copies `PRODOS`
today, onto a disk the user formatted with ProDOS. In the fork it
copies `COBOL.OS` and writes our blocks 0–1 with `WRITE_BLOCK`. The
same code becomes a new Utilities item, **"Make a disk bootable"**.

**Formatting a blank disk** (SmartPort FORMAT, then an empty root
directory and a bitmap) **comes later, as a Utilities menu item** (the
user, 2026-11-22). Until then disks come formatted from the PC (cp2)
or from any ProDOS utility.

### 8.3 Reset and interrupts

- **Ctrl-Reset**: the kernel points the reset vector (`$3F2`–`$3F4`)
  at a warm restart that closes every file and reloads COBOL.SYSTEM.
  Open files lose only what was in their buffers.
- **Interrupts**: nothing in this system raises one (no mouse, no
  interrupting clock). The vectors at `$FFFA` point at an `RTI`. If a
  card ever needs interrupts, that is a later decision.

### 8.4 Two builds of COBOL, each refusing the other system

**COBOL stays two builds** (the user, 2026-11-23): the ProDOS one in
`P:\COBOL` and a COBOL.OS one made at stage 4. One build that checks
the system and branches was considered and turned down. The reason
is the user's: a disk shipped with COBOL.OS *will* get started under
ProDOS by someone who isn't thinking, and a system built for the
other one then overwrites part of it. The ProDOS build keeps data at
`$BD00`, which is our block buffer; ours expects the main language
card to be free and ProDOS is sitting in it.

So **each build makes one test before it touches anything**:
`LDA $BFFF / CMP #$C0`. ProDOS's version byte is small (`$24` for
2.4.x, `$23` for 2.0.3, lower for 1.x) and COBOL.OS's is `$C0` (§5).
On the wrong system it says so and goes no further, through `QUIT`.
If the right build's system file is on the same disk, it can load
that instead, which is what "loading the correct version" means
here. The file names, and whether both builds ever share a disk, are
stage-4 details.

## 9. The dividend

Once the kernel is measured, the main language card has roughly 8K
nothing uses — more than half of it in `$D000` bank 2 and the top of
`$E000`. COBOL's tightest spaces today:

| | free |
|---|---|
| COBOL.LIB (`$3000`–`$5FFF`) | 2 bytes |
| FORMAT | 339 |
| VM | 1,068 |

Library code can run in the main card **while no MLI call is in
progress**. The catch is the ROM: code in the card can't call the
monitor, which only COBOL's startup does. That move is **phase 2**,
after the kernel runs the whole test suite unchanged, and it is the
point where the fork's COBOL starts to differ from the ProDOS one.

## 10. The order of work

Each stage is tested before the next, on AppleWin, and the first
three need **no COBOL source change at all**: the kernel runs the
existing COBOL binaries off a copy of `COBOL32.po`.

| stage | delivers | the test |
|---|---|---|
| 0 | `P:\COBOLOS` with `src/`, `tools/` (copied build + emu scripts) | builds. **DONE 2026-11-22** |
| 1 | boot loader + `COBOL.OS` skeleton: `$BF00` page, entry stub, SmartPort driver, device list, `ON_LINE`, `GET_PREFIX`, `SET_PREFIX`, `READ_BLOCK` | boots to a test program that prints the volume name and dumps block 2. **DONE 2026-11-22**: `KTEST1`, 20 table tests plus register, flag and ROM checks, PASS with one drive and with two |
| 2 | **reading**: `OPEN`, `READ`, `NEWLINE`, `SET_MARK`, `GET_EOF`, `GET_FILE_INFO`, `CLOSE`, all storage types, directories as files | **COBOL.SYSTEM boots on our OS and shows the menu**; EDIT opens a program; VIEW and RUN work on programs that only read. **DONE 2026-11-23**: `TEST2`, 165 checks, passes on ProDOS and on COBOL.OS; the unchanged COBOL disk boots to the menu, EDIT opens RPTT.COB, VIEW shows LEADS.DAT, RUN prints RPTT's report, CATALOG lists the volume |
| 3 | **writing**: bitmap, `WRITE`, growth, `SET_EOF`, `CREATE`, `DESTROY`, `RENAME`, dates, `WRITE_BLOCK` | **the whole existing suite** (`suite.ps1`, `a26run.ps1`, the tools tests) passes unchanged **DONE 2026-11-24**: `TEST3`, 85 checks, passes on ProDOS and on COBOL.OS. `suite.ps1` and `a26run.ps1` give the same screens on both, apart from dates and ProDOS-run flakes that a rerun cleared. cp2 and `pdcheck.py` find both disks sound |
| 4 | the fork of COBOL itself: `QUIT`, reset, the `$BD00` move (the kernel buffer leaves `$2E00`), the turnkey copier, "Make a disk bootable" | turnkey test; boot a disk the system made. **DONE 2026-11-25**: `s4test.ps1` (a turnkey disk and a disk made bootable both boot and run); the whole suite on each build, overnight 2026-11-24/25, gives the same screens apart from the menu's item 9, Utilities' item 9, QUIT, the clock, the cursor's blink and SALESDB's root-full COPY (DECISIONS 5.11); both guards refuse the wrong system; DELETE and the case fold pass |
| 5 | phase 2, §9 | per piece |

**The independent check**: after every stage-3 test run, `cp2` reads
the disk image. cp2 is someone else's ProDOS implementation, so if it
lists and extracts every file our kernel wrote, byte for byte, the
format is right. That is the known-good reference SWA's own format
never had.

## 11. Rules carried over from the COBOL tree

Merlin 8 is the assembler of record and Merlin32 stands in; every
line ≤ 60 columns; verbose comments; no `#'a'` constants; no forward
`EQU`s; PUT files under ~24K; listings via `PR#1`; never `LST OFF`;
decisions logged in `DECISIONS.md` here with the user's calls marked
**(user)**; no keystrokes into the live desktop (aw.ps1 checks
AppleWin is in front).

## 12. Questions

Answered by the user on 2026-11-22:

| | question | answer |
|---|---|---|
| 1 | the OS's name | **COBOL.OS** |
| 2 | what `QUIT` does | **"Change the disk and press RETURN to restart the system"** (§8.1) |
| 3 | the kernel's block buffer | **`$BD00`–`$BEFF`** (§4.2) |
| 4 | which drives | **only 3.5" and hard-drive SmartPort** (§6.1) |
| 5 | formatting blank disks | **later, in the Utilities menu** (§8.2) |

6. **What happens to P:\COBOL at stage 4**: **two builds, one for
   each system** (the user, 2026-11-23), even though fixes then have
   to be made in both. Each build checks `$BFFF` at start-up and
   refuses to run on the other system (§8.4).
