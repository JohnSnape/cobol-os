# COBOL.OS — decisions

Every design decision and trade-off, for the build guide. The user's
own calls are marked **(user)**. `DESIGN.md` is the plan these
decisions shape.

## 1. Starting out (2026-11-22)

### 1.1 A COBOL system on an OS of our own (user)

The user: *"Now that we have our COBOL system almost complete, I want
to make an offshoot that runs on our own OS that sits on the language
card, like ProDOS does, but is our own system."*

### 1.2 A new small kernel, not SWA (user)

Offered: build on SWA (`P:\SWA`), whose plan already makes COBOL its
Book 4, or write a new kernel that supplies only the calls COBOL
makes. The user chose the new kernel.

- SWA's file system isn't written yet, its ABI is 117 frozen calls
  COBOL doesn't need, and its aux bank 0 block cache and `$BE00`
  page collide with COBOL's source records and prefix buffers.
- SWA's proven boot-block reader and SmartPort driver are reused as
  parts. SWA itself is not changed.

### 1.3 ProDOS-format volumes (user)

Offered: ProDOS's disk format, or one of our own. The user chose
ProDOS's.

- Existing disks and data files keep working; cp2 and CiderPress read
  them, so the test harness carries over and cp2 becomes an
  independent check that the kernel writes the format correctly.
- Booting is decided by blocks 0-1 and the `COBOL.OS` file alone.

### 1.4 A fork in its own folder (user)

`P:\COBOLOS`. `P:\COBOL` stays the ProDOS build, untouched.

### 1.5 Design now, finish the pending COBOL tests later (user)

The file-name ACCEPT deploy and the stopped regression run wait.

### 1.6 ProDOS's call numbers, parameter blocks and error codes

Chosen so the COBOL binaries run unchanged on the new kernel. That
makes the existing COBOL disk the kernel's first test, and the whole
existing suite its acceptance test. The code is written from the
ProDOS Technical Reference Manual's description, not from ProDOS.

### 1.7 Sixteen calls, plus two

Counted from the sources: the 16 calls in DESIGN §3. `READ_BLOCK`
and `WRITE_BLOCK` are added for the turnkey copier and "Make a disk
bootable". Everything else returns `$01`.

### 1.8 SmartPort only in v1

It covers AppleWin's hard disk card and the user's 3.5" and 32MB
SmartPort drives. A Disk II driver would cost about 1.5K for disks
too small to hold the system. Open question 4.

### 1.9 The COBOL source forks late (stage 4)

Stages 1-3 test the kernel against the unchanged COBOL binaries, so
there is nothing to fork until `QUIT`, reset, the `$BD00` move and the
turnkey copier need changing. Forking later means fewer ProDOS-side
fixes to port by hand.

## 2. The answers to the design's questions (user, 2026-11-22)

### 2.1 The OS is COBOL.OS (user)

Also the kernel's file name in the root of a bootable disk.

### 2.2 QUIT asks for a disk and reboots (user)

The kernel clears the screen and shows "Change the disk and press
RETURN to restart the system" centred in 80 columns. It waits for
RETURN, then boots the slot it booted from (`JMP $Cs00`).

- **Why.** There's no program selector to quit to, and this lets one
  machine move between disks without a power cycle.
- **How.** The kernel draws the line itself, because by then the
  screen switches are whatever COBOL left them as.

### 2.3 The kernel's block buffer is $BD00-$BEFF (user)

The SmartPort firmware runs with the ROM in, so it can't read or
write a buffer in the language card. COBOL's ERRBUF, SYSPFX, WRKPFX
and CPYBUF move into COBOL.SYSTEM's free space at the fork.

- **Stop-gap until the fork (mine):** `$2E00`-`$2FFF`, which nothing
  in the unchanged binaries uses.
- **Turned down:** text page 2. The compiler fills it with
  descriptors and calls the MLI while they're there.

### 2.4 Only 3.5" and hard-drive SmartPort devices (user)

No Disk II 5.25" driver.

### 2.5 Formatting blank disks comes later, in Utilities (user)

Until then disks are formatted on the PC with cp2, or with any ProDOS
utility.

### 2.6 Still open: what happens to P:\COBOL after the fork

The user doesn't know yet. It's needed at stage 4.

## 3. Stage 1 (2026-11-22)

### 3.1 The boot block is block 0 only

ProDOS gives a loader blocks 0 and 1, but the firmware loads only
block 0. Our loader fits in 348 bytes, so block 1 is left as it was.
Writing ProDOS's block 0 back makes the disk a ProDOS disk again.

- It loads seedling and sapling files up to 32K. A tree file is
  refused.
- It trusts ProDOS's fixed 39-byte entries, 13 to a block, rather than
  reading them from the header.

### 3.2 The kernel saves its zero page around every card call

The SmartPort firmware writes to `$42`-`$47`, which is inside the
kernel's `$40`-`$4E`. SWA's trampoline saved those six bytes. Here
KCARD saves all fifteen instead, so the trampoline in the `$BF00` page
shrinks to 18 bytes, and no kernel pointer is lost whatever a card
does.

### 3.3 The entry stub is in the `$BF00` page, in ProDOS's unused gaps

Every address COBOL reads stays where ProDOS has it. The stub (at
`$BF99`), the trampoline (at `$BF70`), NODEV and the SmartPort
parameter list (at `$BF40`) fill holes ProDOS uses for its own code.
Each block ends with a `DS` to the next fixed address, so one that
grows fails to assemble instead of moving an address.

- The stub saves X; the kernel saves Y and moves the caller's return
  address past the three inline bytes, in place on the stack.
- Its last two instructions are `CMP #1` (carry = error) and `ORA #0`
  (Z and N follow A), which give ProDOS's exit flags in 4 bytes.

### 3.4 Two drives per SmartPort card

Units 1 and 2 of each card become drives 1 and 2 of its slot (`$s0`,
`$s0+$80`). A third or fourth unit, which ProDOS 2.x maps to a
"phantom" slot, is ignored in v1.

### 3.5 Errors COBOL can't tell from ProDOS's

The card's `$27`, `$28` and `$2B` pass through. Its `$11` (bad unit)
becomes `$28`, and anything else becomes `$27`. `SET_PREFIX` naming a
file returns `$4B`. A path that runs through a missing directory
returns `$44`, a missing last name `$46`, and a missing volume `$45`.

### 3.6 No EQU after the code that uses it

Merlin 8 can't size an instruction that names a later EQU. So the
installer finds the `$BF00` page and the kernel in its own file at run
time, from the label `INSEND`. The kernel's call tables come before
the dispatcher, and `tools/fwdref.js` is run on both sources.

## 4. Stage 2: reading (2026-11-23)

### 4.1 Eight file control blocks, 32 bytes each, at `$D300`

ProDOS allows eight open files, and so does this. FCB *n* is at
`$D300 + (n-1)*32`, and the ref number `OPEN` returns is *n*. Every
field is read as `FIELD,X`, with X the FCB's offset. Each FCB holds
the device, the storage type, the key block, where the file's own
entry is (stage 3 writes EOF and dates back there), the caller's
buffer, the mark, the EOF, the newline mask and character, and what
the buffer holds now. KINIT clears them with the rest of bank 1, now
`$D000`-`$D3FF`.

### 4.2 The caller's 1,024 bytes hold the data block and the index block

The first half holds the data block the mark is in, and the second
half holds the index block that names it. Each half records what it
holds: the data block's number within the file, and which master-index
entry the index block came from. So reading straight through a file
costs one block read per 512 bytes, plus one more every 128K.

A tree file's master index is read through the kernel's own block
buffer, and only when the needed index block isn't already held. A
zero in any index is a hole that reads as 512 zeros. That includes a
zero master entry, which is a 128K hole.

### 4.3 Directories are read by following the chain

A directory's blocks are linked through bytes 2-3 of each block.
Reading straight on costs one step from the block in hand. Anything
else walks from the key block. A chain that ends before the block the
mark is in returns `$51`. A subdirectory's EOF comes from its entry.
The volume directory has no entry, so its EOF is counted at `OPEN`:
blocks in the chain × 512. ProDOS gives `$800` for a four-block
volume directory, and so does this (TEST2, on both systems).

### 4.4 `READ` copies through the file buffer, a byte at a time

`READ` never reads a whole block straight into the caller's memory,
which ProDOS does as an optimisation. Every byte goes through the file
buffer, with the newline test in the same loop. It's simpler, and the
COBOL boot shows no slowdown. If a measurement ever says otherwise,
the direct read can be added later inside `READ` alone.

### 4.5 `GET_MARK` added

COBOL never calls it, so DESIGN §3 left it out. The test needs it to
check the mark, it costs 27 bytes, and ProDOS has it. That makes 12 calls
in all, `$C4`-`$D1` and `$80`.

### 4.6 Opening a file twice is `$50` when the file can be written

This is ProDOS's rule: a second `OPEN` is allowed only while neither
open can change the file. TEST2 opens an unlocked file twice and gets
`$50` on both systems.

### 4.7 `GET_FILE_INFO` on a volume follows ProDOS

The volume returns:

- storage type `$F` and type `$0F`;
- the volume's size in blocks as the aux type;
- no modified date;
- the header's creation date;
- "blocks used" counted from the bitmap as size minus free.

Both systems print the same bytes, and the used count agrees with
cp2's free count (761 used of 1,600 on TESTOS, where cp2 says 839
free).

### 4.8 `KLDSYS` starts COBOL.SYSTEM from the kernel

COBOL.SYSTEM loads at `$2000`, on top of the installer, so the load
runs in the language card. `KLDSYS` calls the kernel's own `OPEN`,
`READ` (up to `$9F00` bytes, the whole of main memory below the page)
and `CLOSE` directly, with a file buffer at `$1C00`. It then resets
the stack and jumps to `KGO`, six bytes in the `$BF00` page that
switch the ROM in and `JMP $2000`. `KGO` has to sit in main memory for
the trampoline's reason. If the load fails, the top line of the screen
says `CANNOT LOAD COBOL.SYSTEM - ERROR $xx` and the system stops,
because nothing else is left to report it. Stage 4's warm restart will
call the same routine.

### 4.9 The stage-2 test is a program of its own, run on both systems

`TEST2.S` is an ordinary system program that uses only MLI calls.
`tools/emu/mktest.ps1` builds two 800K disks with the same files on
them:

- `TESTOS.po` boots our kernel;
- `TESTPD.po` boots ProDOS 8, with its boot blocks and `PRODOS` copied
  from `COBOL32.po`.

The test is each disk's `COBOL.SYSTEM`, and it has to pass on both.
Passing on ProDOS proves the expectations are ProDOS's, and passing on
COBOL.OS proves the kernel. It's the stage-1 idea of an independent
check (DESIGN §10's cp2), applied to the calls themselves. Stage 1's
`KTEST1` left the installer, and its source stays in `src/`.

### 4.10 This tree's printer file is its own

`applewin-cobolos.ini` had been copied from the COBOL tree with its
printer file at `P:\COBOL\tools\emu\print-test.txt`. It now points at
`P:\COBOLOS\tools\emu\print-test.txt`, so running a program here
never touches the ProDOS tree.

## 5. Stage 3: writing (2026-11-23)

### 5.1 Writes are held in the file buffer, as ProDOS holds them

A WRITE changes the data half of the caller's file buffer and marks it
changed. It goes to disk when the file moves on to another block, and
at CLOSE. The index half and the directory entry are handled the same
way. `FDIRT`'s three bits say which of the three changed. So a program
that writes a record at a time costs one block write per 512 bytes. A
written-through design would cost three per record, which would be
fine on AppleWin but slow on the user's 3.5" drive.

### 5.2 A new block is taken when the data goes out

Writing into a hole (past the end, or a block never written) costs
nothing until the data half goes back to disk. Then `KDFLUSH` takes a
block (`KALLOC`), and `KPLACE` writes that block's number into the
file's structure, growing the structure first when the file outgrows
it:

- seedling → sapling: a new index, whose entry 0 is the old key;
- sapling → tree: a new master, whose entry 0 is the old index;
- a tree's empty master entry: a new index.

Every new block counts in "blocks used". The index half loaded for a
sapling stays correct once the file becomes a tree, because the
sapling's index becomes master entry 0's index.

### 5.3 One bitmap block cached, written back and forgotten after every call

The bitmap block being worked on is kept in bank 1 at `$D400`. It is
read through `KBLK` and copied there. At the end of every call, `KMLI`
writes it back if it changed and then forgets it. Within one call,
taking blocks costs no I/O after the first. Between calls the disk is
always complete, and a disk swapped between two calls can never be
written with another disk's bitmap.

The rule that comes with it: nothing may hold anything in `KBLK`
across a `KALLOC` or `KFREEB`, because a bitmap block may pass through
`KBLK` at that moment. So the routines that free blocks (`KTRUNC`)
first copy an index or master index up to `$D600`/`$D800`. CREATE
reads each directory block afresh after taking its blocks.

### 5.4 SET_EOF frees blocks and brings the storage type down, as ProDOS does

Making a file longer only moves the EOF, and the new space is a hole.
Making it shorter writes back what the buffer holds, then frees every
block wholly past the new end. That includes index blocks with nothing
left to name, and the buffer is then forgotten. The type then comes
down:

- a tree that keeps 256 blocks or fewer becomes a sapling;
- a sapling that keeps one block becomes a seedling.

I hadn't planned the second part. The first TEST3 run on ProDOS
showed it: a 140,000-byte tree cut to 1,000 bytes came back as a
3-block sapling. Block 0 is always kept. If block 0 is a hole, the
type stays where it is, because there's no block to make the key.

### 5.5 The backup bit, on CREATE and on every write-back of an entry

ProDOS sets access bit 5 ("needs backup") when it creates a file and
whenever a changed file's entry is written. Files that TEST3 created
as `$C3` came back as `$E3` on ProDOS, and COBOL.OS now does the same.

### 5.6 What CREATE writes

The directory entry and the subdirectory header follow the ProDOS
Technical Reference:

- a subdirectory's key block has a header with `$75` at +$10, access
  `$C3`, entry length `$27`, 13 entries per block, and the parent
  pointer, entry number (counted from 1) and entry length;
- a new directory is one block long, with EOF `$200`;
- a date of 0 in the parameters means now, after calling the clock.

ProDOS 2.4 also writes its version number (`$24`) into the version
bytes and copies a few header fields into the header's reserved bytes.
COBOL.OS writes 0 to the version bytes, since it isn't ProDOS, and
leaves the reserved bytes zero. cp2 accepts both.

### 5.7 An open file is recognised by where its entry is

OPEN's "already open" test (`$50`) and DESTROY's and RENAME's
(`KISOPEN`) compare the device and the entry's block and position, not
the key block. A file that grows gets a new key block while it's open,
but its entry never moves.

### 5.8 TEST3, and checking the disk from outside

TEST3 is TEST2's method applied to writing. It's a system program that
uses only MLI calls, run on ProDOS and on COBOL.OS (`mktest.ps1 -Test
TEST3`), and it passes all 85 checks on both, printing the same
GET_FILE_INFO bytes. It leaves files behind for the PC to check:

- `tools/keepcheck.py` extracts them with cp2 and compares every byte;
- `tools/pdcheck.py` walks the whole volume. Every block in use must
  belong to exactly one file, every "blocks used" must be right, and
  the bitmap must agree with both.

The shared helpers of TEST2 and TEST3 moved to `TLIB.S`.

### 5.9 The COBOL suite runs from a copy of its harness

`tools/suite/` is the COBOL tree's `tools/emu` scripts, copied, with
the disk taken from `$env:SUITEIMG` instead of `COBOL32.po`, and the
printer file kept in this tree. `both.ps1` runs `suite.ps1` and
`a26run.ps1` twice, each time on a fresh copy of `COBOL32.po`:

- once on ProDOS (`SUITEPD.po`);
- once on COBOL.OS (`SUITEOS.po`).

`cmpshots.ps1` then compares the two runs screenshot by screenshot,
and the printer files as text. `COBOL32.po` is only ever copied from,
and the COBOL tree's scripts are untouched.

### 5.10 Branches out of range, fixed by a script

A long routine's `BCS` to a far exit becomes `BCC` past a `JMP`. Most
of them were fixed by a throwaway script that read Merlin32's "Bad
Jump" errors. The labels it added are `KZnn`, and they mean nothing
more than that.

### 5.11 The suite on both systems, and what the differences were

`both.ps1` ran on 2026-11-23/24, 170 minutes per system. Every
screenshot matched apart from three kinds, each traced:

- **Dates and times on screen.** The two runs were on different days.
- **Flakes in the ProDOS run.** e43, ln, e50d, rg-qsort and rp (with
  rs after it) compiled an empty program because the file hadn't
  opened in time. `rerun.ps1` ran them again on ProDOS, and they then
  matched COBOL.OS.
- **SALESDB's COPY on COBOL.OS ("00 30").** The root directory was
  full. The COBOL.OS disk carries one more root entry, the file
  COBOL.OS, so WEST.DAT would have been entry 52, and `CREATE` gave
  `$49`. `rootfull.ps1` gave real ProDOS the same 48 entries before the
  test. It failed identically, every SALESDB screen matching but for
  the clock. **This is a limit of a crowded disk, not a kernel
  difference.** A shipped COBOL.OS disk has one root entry less to
  spare than the ProDOS disk. That is worth remembering when stage 4
  decides what goes in the root.

## 6. Stage 4: the fork (2026-11-23)

### 6.1 Two builds of COBOL, not one that checks **(user)**

I suggested one COBOL build for both systems. It would read `$BFFF`
at start-up and branch in the two places that differ, the turnkey
copier and "Make a disk bootable". The `$BD00` move works under
ProDOS too, so it would need no branch.

**The user chose two builds.** That means more work, since every fix
has to be made in both. The reason: once COBOL ships with our OS,
someone will start it under ProDOS without thinking. A build that
expects the other system then overwrites part of it and breaks the
system. The ProDOS build's `$BD00` data lands on the kernel's block
buffer. Our build would take the language card while ProDOS is in it.

So each build guards itself. Its first act is `LDA $BFFF / CMP #$C0`.
On the wrong system it says so and quits, or it chains to the right
build's file if that file is on the disk. DESIGN §8.4 has the details.
This settles open question 6.

### 6.2 COBOL.OS's version byte is `$C0`

The kernel's `$BFFE`/`$BFFF` (KBAKVER, KVERSION) were `$00`. They are
now `$C0`. Real ProDOS uses small numbers there: `$24` for 2.4.x,
`$23` for 2.0.3, and 0 to 9 for 1.x. `$00` can't be the mark,
because some ProDOS 1.x versions use it. Nothing in ProDOS's
history comes near `$C0`. `$BFFC`/`$BFFD` stay `$00`: they belong to
the system program, as in ProDOS. A later kernel that changes what
programs may rely on counts up from `$C0`, and KBAKVER then names the
oldest version it is still compatible with. Put in KPAGE.S and built
2026-11-23 (the kernel size is unchanged). It is not yet run in
AppleWin, because the suite had AppleWin busy.

### 6.3 The fork: `P:\COBOLOS\cobol`, with its origin kept

- `cobol/src` is a copy of `P:\COBOL\src` taken on 2026-11-24, and it
  builds with `tools/cobbuild.sh`.
- `cobol/origin` keeps that copy, `src` and `obj`, untouched.
  `cobbuild.sh compare` lists the objects the fork has changed.
  `tools/forkdiff.sh` lists the changed sources. `forkdiff.sh up` lists
  what `P:\COBOL` has changed since the fork, and those fixes are ported
  by hand (6.1).
- Before any change, the fork built byte-identical to the origin.
- **`P:\COBOL`'s source was ahead of its disk when it was copied.**
  The file-name ACCEPT work (COBOL's DECISIONS 8.11, untested) makes
  LIB and COMPILE2 differ from `COBOL32.po`. So the fork carries it,
  and from stage 4 `both.ps1`'s ProDOS pass uses `origin/obj` instead
  of `COBOL32.po`'s own files, so both passes run the same source.

### 6.4 The `$BD00` move: a swap with the kernel's stop-gap

- COBOL's four items keep their offsets and move up as one block to
  `$2E00`–`$2FFF`: ERRBUF `$2E00`, SYSPFX `$2F00`, WRKPFX `$2F40`,
  CPYBUF `$2F80`. That is where the kernel's buffer sat during stages
  1–3.
- The kernel's `KBLK` goes to `$BD00`.
- It is four equates in the fork: EQUATES2.S ×3 and CMPLEX.S.
- Five objects changed: AUXLC, COBOLSYS, COMPILE1, COMPILE2 and
  LEXTEST. In every one, each changed byte is a high byte, `$BD`→`$2E`
  or `$BE`→`$2F`.
- COBOLSYS.S ends with `ERR */$2E00`, which stops the assembly if
  COBOL.SYSTEM ever reaches the block. It was tested by moving the
  limit down: it fires.
- `m32build.sh` now reads `KBLK` from KEQU.S for its limit checks.
- **A COBOL.OS disk must carry the COBOL.OS build**: the ProDOS
  build's ERRBUF would land on the block buffer. `mkdisk.ps1` puts it
  there through `tools/emu/putcobol.ps1`.

### 6.5 QUIT

As DESIGN §8.1 says:

1. It writes back and closes every file (`KCLALL`, the old ref-0 path
   of CLOSE), then the bitmap block.
2. It clears the screen and draws the line straight into text page 1:
   80 columns, ALTCHAR on, row 11, column 13.
3. It waits for RETURN alone. A key already typed is thrown away
   first.
4. It boots the slot in KBOOT through `KQBOOT` in the `$BF00` page.
   `KQBOOT` switches the ROM in and calls the monitor's INIT, SETVID
   and SETKBD, so the boot firmware finds the screen as at power-up.
   QUIT first sets 40 columns and the standard character set.

### 6.6 Ctrl-Reset forgets open files; it does not write them back

KINIT points `$3F2` at `KRESET` in the `$BF00` page. `KRESET` banks
the kernel in and goes to `KWARM`: `KINIT` again, then `KLDSYS`.
Tested with an AppleWin breakpoint on `KRESET`. Ctrl-Reset from
Utilities stopped there and went on to the menu.

**Open files are forgotten, not written back. This is my reading of
DESIGN §8.3** ("lose only what was in their buffers"). A reset can
land in the middle of a call. Writing back from a half-done state could
damage a sound file. Forgetting it can at worst leave a block marked
used that no file owns.

### 6.7 The guard's wording, and menu item 9 (mine)

- **The COBOL.OS build's start-up check under ProDOS** prints two
  40-column lines, waits for a key, and QUITs:
  - "This COBOL needs COBOL.OS, not ProDOS."
  - "Boot its disk to start it - press a key"

  Seen on ProDOS 2.4: it returns to its selector.
- **Menu item 9** read "Exit to ProDOS". In the fork it reads
  **"9) Quit"**.

### 6.8 The two builds keep the same file names and never share a disk (mine)

DESIGN §8.4 left the names open. Both builds call their files
`COBOL.SYSTEM`, `COBOL.LIB`, `COBOL.AUX` and so on. Every one of the
eleven differs between the builds, or will once fixes diverge. So
putting both on one disk would mean a second name for each. A COBOL.OS
disk carries only the COBOL.OS build, and a ProDOS disk only the
ProDOS build.

That makes the guard **refuse** rather than **chain**: there is never
another build on the same disk to load. To change this, give one build
its own names; the guard could then load the other.

### 6.9 Turnkey disks and bootable disks

- **Utilities 7, the turnkey copier**, copies `COBOL.OS` where the
  ProDOS build copied `PRODOS`.
- Before any file is copied, it writes our boot block (`UBOOTB`):
  - The block is block 0 of the volume `*/` names, the disk the system
    booted from, copied as it is.
  - It goes to block 0 of the volume the user names.
  - Units come from ON_LINE, matching names in capitals.
- **It refuses the system's own volume**: "That is the system disk:
  use another". Copying onto it would DESTROY each file before reading
  it.
- **A volume that is not on line gives `$45`.**
- **Utilities 9, "Make a disk BOOTABLE"** (new) writes the same boot
  block. It then copies COBOL.OS and the eleven system files from
  `*/`, but nothing of the user's. The disk boots to the menu.

### 6.10 Stage 4's own test: `tools/suite/s4test.ps1`

Run 2026-11-24, on a fresh COBOL.OS disk from `mkdisk.ps1`.

- **Turnkey.** `turntest.ps1`, unchanged, made TURN.po. Booted alone,
  it boots COBOL.OS, runs UNTITLED, prints `000055`, and STOP RUN ends
  in QUIT's line.
- **Bootable.**
  - Utilities 9 refused `/COBOL` ("That is the system disk") and
    `/NOPE` (`$45`).
  - On a blank `/NEWDISK` it wrote the boot block and twelve files.
  - BOOT.po, booted alone, comes up at the COBOL menu with
    "9) Quit".
- **Disks.** cp2 `test` and `pdcheck.py` are clean on all three.
- Two length bytes in the new strings were wrong. They are fixed, and
  every `DFB n` / `ASC` pair in UTILD.S was checked by script.

### 6.11 The ProDOS build's guard, in `P:\COBOL` **(user)**

The user said yes (2026-11-24) to the mirror-image test in the ProDOS
build. It is COBOL's DECISIONS 8.13:

- **The test:** COLD reads `$BFFF`. If it is `$C0` or more, the build
  prints "This COBOL needs ProDOS, not COBOL.OS." and "Start it from
  ProDOS - press a key", then QUITs.
- **What changed:** only COBOL.SYSTEM, from 2,201 to 2,293 bytes.
- **Not deployed to `COBOL32.po`.** That belongs to the COBOL tree's
  own `deploy.ps1`, and the suite was running from copies of
  `COBOL32.po`.
- **The test of both guards** is `tools/suite/guards.ps1`.
- `forkdiff.sh up` now lists SYSBOOT.S and EQUATES2.S. That change is
  the ProDOS side's alone, and it is not ported.


### 6.12 DELETE erases in every one-line input **(user)**

The user said yes (2026-11-24) to making DELETE erase the way the left
arrow does, everywhere one line is typed.

- **What was wrong.** EDIT took DELETE (`$7F`, `DBS`) as erase-left,
  but the five one-line input routines threw it away:
  - `TDGETLN` (`GETLN80`): Utilities, EDIT's own prompts, the clock;
  - `CONGETLN`: a program's plain `ACCEPT`;
  - `DSACC`: `ACCEPT ... AT`;
  - `SCRINP`'s `EDITFLD`: screen forms;
  - `PROMPT`'s `LINEIN`: row 23 in FORMAT, QUERY and REPORT.

  The //e's DELETE key is where a typist reaches to fix a slip, so
  someone correcting a file name pressed it and nothing happened.
- **The first try was four bytes a routine.** `CMP #$7F / BEQ erase`
  after the left-arrow test put `COBOL.LIB` 15 bytes past `$6000`,
  into `LOWBASE`, where EDIT, REPORT, the VM and the compiler load.
  It was taken out before anything ran.
- **What went in costs nothing.** Each routine has the key at seven
  bits before it tests, so its existing `CMP #$7F / BCS ignore` was
  only ever true for `$7F`. That line *was* the "ignore DELETE"
  rule. The `BCS ignore` became `BEQ erase`.
  - Every object is the same size.
  - Exactly two bytes changed at each of the seven places: four in
    LIB, and PROMPT's copy in FORMAT, QUERY and REPORT.
  - LIB still ends at `$5FFE`.
- **Also in `P:\COBOL`** (user, the same day), as its DECISIONS 8.14.
  The five files were copied across, since they differed only by
  this change. P:\COBOL's build changed the same 14 bytes at the same
  offsets. It was deployed to `COBOL32.po` and rolled back, because
  that LIB also carries 8.11's untested CGWARN. It goes on with 8.11
  (COBOL's DECISIONS 8.14). Tonight's PD pass
  still runs `cobol\origin\obj`, the build without it.
- **The test** is `tools/suite/deltest.ps1`, step 3 of `overnight.ps1`.
  - Utilities: at first the catalog, `/COBOLX` then DELETE. That
    was a mistake, because item 1 catalogs at once and asks nothing.
    Since 2026-11-25 it is item 4's "Rename which?", where
    `SKEL.COBX` then DELETE must leave `SKEL.COB`; ESC then cancels.
  - FORMAT's first prompt.
  - `caseup.cob`, through both ACCEPT routines.
  - `EDITFLD` has no test of its own.
  - `runfile.ps1` steps starting with `@` now go through
    `aw.ps1 raw`, so `@{DEL}` presses the PC's Delete key.

### 6.13 Command letters are folded everywhere **(user)**

This is the same day as 6.12, and it is COBOL's DECISIONS 8.15, which has
the detail.
- **The fix:** five places tested a command letter without `AND #$DF`, so
  with Caps Lock up they did nothing:
  - `LINEIN`'s `CMDLIST` walk;
  - its SA-D and SA-C;
  - FORMAT's field-type answer;
  - REPORT's OA-G, OA-A and OA-D.

  They now fold.
- **Sizes:** FORMAT +8, QUERY +4, REPORT +4. Every overlay is still under
  its ceiling.
- **Both trees:** the change is in PROMPT.S, FORMATD.S and RPTENT.S,
  copied to `P:\COBOL`, and both builds' FORMAT, QUERY and REPORT are
  byte-identical.
- **The test:** `deltest.ps1` step 2b answers FORMAT's type question with
  a pasted lowercase `a`.

### 6.14 The system on 800K disks **(user)**

On 2026-11-24 the user asked whether COBOL fits an 800K disk, then for
both builds on one, with DELETE and the fold, tested.
- **It fits.** Without its source the system takes about 136K:
  - the ProDOS disk keeps 1,329 blocks free;
  - the COBOL.OS disk keeps 1,346, because its 8K COBOL.OS replaces the
    17K PRODOS file.

  The 112 source files alone take 983K, so the source stays on the 32 MB
  disk.
- **The disks:**
  - `COBOL800PD.po` carries the ProDOS build from `P:\COBOL\build\obj`.
  - `COBOL800OS.po` carries this tree's build, our block 0 and COBOL.OS,
    and no PRODOS file.
  - Both are in the AppleWin folder, and the volume is named COBOL on
    both.
- **They are made by `tools/emu/mk800.ps1`.** It starts each from a
  blank 800K volume, and takes PRODOS, COBOL.SETTINGS, CLIPBOARD.CLP and
  PROCS from `COBOL32.po`, which it only reads.
- **The guard is the existing one (the user's choice).** Each build
  refuses the other system, and that was retested on 800K disks:
  - the COBOL.OS build on a ProDOS disk says it needs COBOL.OS, then
    goes to ProDOS's selector;
  - the ProDOS build on a COBOL.OS disk says it needs ProDOS, then goes
    to the "Change the disk" screen.

  No size check was added.
- **The test, on both disks, in AppleWin's hard-disk slot:**
  - boot to the menu;
  - the Utilities catalog;
  - FORMAT, where "1X" then DELETE left "1";
  - FINANCE through EDIT's OA-O, compile and run, where PAYCHECKX then
    DELETE was saved as PAYCHECK, and the balance came to $1,299.50.

  The test files were deleted afterwards.
- **8.11 is on the ProDOS disk.** That build's COBOL.LIB and COMPILE2
  carry 8.11's untested file-name ACCEPT, the reason COBOL32.po was
  rolled back. The 800K disk is a separate image, so that is allowed
  there.
- **Not tried:** booting from a 3.5-inch drive rather than the hard-disk
  slot.

### 6.15 The overnight run of 2026-11-24/25

At the user's request, `overnight.ps1` ran from 20:55 to 02:39, 344
minutes. It ran `both.ps1`, then `guards.ps1`, `deltest.ps1` and
`cmpshots.ps1`.
- **The suite:** the ProDOS pass took 169 minutes and the COBOL.OS
  pass 170. The ProDOS pass ran `cobol\origin\obj`; the COBOL.OS pass
  ran this tree's build. That makes it the first full run of the fork.
- **Every screenshot pair matches** except the following, each looked
  at:
  - **1,080 pixels** on every compile shot and a few others: the menu's
    "9) Quit" against "9) Exit to ProDOS".
  - **About 6,400 pixels** on `u-menu`, `tk-ask` and `tk-made`:
    Utilities' "9) Make a disk BOOTABLE". `tk-quit` differs as a whole,
    because QUIT's screen is not ProDOS's.
  - **37,855 pixels** on `e34-compile` and `perf2-compile`: the same menu
    line, plus AppleWin's title bar caught inactive in the ProDOS
    shot.
  - **168 and 448 pixels:** the clock, and one character cell where
    the cursor was caught in the other half of its blink.
  - **SALESDB from `sdb-12-copy` on:** "CANNOT COPY - 00 30" on
    COBOL.OS. This is the root-full limit of 5.11, as before. So
    `print-test.txt` is missing on COBOL.OS, because SALESDB's
    printout comes after the copy.
- **Disks afterwards:** cp2 `test` finds no failures on either one,
  and the bitmap accounts for every block (2,671 and 2,688 used).
- **Guards (6.11):** both refuse, and each ends where it should:
  Bitsy Bye on ProDOS, and QUIT's "Change the disk" on COBOL.OS.
- **DELETE (6.12):** FORMAT's "1X" then DELETE left "1". A program's
  `ACCEPT` and `ACCEPT ... AT` ended with `C2 [ABC  ] [DEF  ] [Q]`.
  **The Utilities step tested nothing**, because item 1 catalogs at
  once. It was moved to item 4's "Rename which?" and run on 2026-11-25
  (`deltest.ps1 -Only 1`). `SKEL.COBX` then DELETE left `SKEL.COB`, so
  GETLN80's DELETE passes.
- **That run found a bug, not yet fixed: ESC does not cancel a
  Utilities name once something is typed.** ESC at "Rename which?
  SKEL.COB" went on to "New name?".
  - `TDGETLN` returns C=1 on ESC, as documented, but with Y set to the
    length typed.
  - Both copies of `UNAME` (`SYSUTIL.S` and `UTILD.S`) test only
    `CPY #0` and never the carry, and they end with `CLC`. So ESC
    after a typed name acts as RETURN.
  - The callers already test `BCS` for a cancel.
  - **What it hits:**
    - DELETE a file: ESC destroys the file named;
    - RENAME and COPY: ESC goes on to the second name;
    - the turnkey copier;
    - the main menu's RUN: ESC runs the program.
  - **P:\COBOL has the same code**, and so does `COBOL32.po`.
  - **Fixed the same day (6.16).**
- **The case fold (6.13):** FORMAT's type question took a lowercase
  `a`, added the field and asked "Row?" again.

### 6.16 ESC cancels a typed name **(user)**

The user said yes on 2026-11-25 to fixing the bug that 6.15 found. It is
COBOL's DECISIONS 8.17.
- **The fix:** `BCS UNX` right after `JSR UPROMPT` in both copies of
  `UNAME`, in `SYSUTIL.S` and `UTILD.S`.
  - Each copy is two bytes longer, so COBOL.SYSTEM and UTILITIES each
    gain 2 bytes. In this tree they are 2,290 and 3,286 bytes, and both
    are under their ceilings (`check.js`).
  - The header now says C=1 means ESC or nothing typed.
  - `UTILD.S` gets a one-line comment, because it is 23,775 bytes, close
    to Merlin 8's PUT limit. `SYSUTIL.S` has the long one.
- **The same edit is in `P:\COBOL`.** There COBOL.SYSTEM is 2,295 bytes
  and UTILITIES 2,778. It is not on `COBOL32.po`, and goes on with the
  8.11 deploy.
- **The test** (scratchpad `esctest.ps1`) ran on both 800K disks, rebuilt
  by `mk800.ps1`, after `ESCTEST` was put on each:
  - Utilities 3, `ESCTEST` then ESC: the file is still on the disk (cp2);
  - Utilities 4, `ESCTEST` then ESC: back to Utilities, with no "New
    name?";
  - main menu 6, `NOSUCH` then ESC: back to the menu, with no
    "not found";
  - Utilities 3, `ESCTEST` then RETURN: the file is gone, so RETURN
    still deletes.

  Both disks then passed cp2's `test`.
- **Not run again:** the full suite. Nothing it covers types a name and
  then presses ESC.

### 6.17 The kernel on GitHub, alone: JohnSnape/cobol-os **(user)**

On 2026-11-25 the user asked for COBOL.OS to have its own repository,
separate from COBOL SYSTEM's (`JohnSnape/apple2-cobol`, COBOL's 8.18).
The reason is that other people may want a small ProDOS-compatible kernel
for their own projects.
- **Only the kernel goes public:**
  - `src/`: the kernel, BOOTBLK, and the tests TEST2, TEST3 and TLIB,
    with KTEST1 kept as the record of stage 1;
  - the build and check tools;
  - `mktest.ps1`, `aw.ps1` and the AppleWin ini;
  - DESIGN, DECISIONS and STATUS.
- **These stay here, through `.gitignore`:**
  - the COBOL fork (`cobol/`) and its suite (`tools/suite/`);
  - the COBOL-only scripts (cobbuild, forkdiff, check.js, putcobol,
    mkdisk, mk800);
  - `build/`, the screenshots and all disk images.
- **The licence is MIT**, the same as apple2-cobol. The public README is
  `.github/README.md`. It covers:
  - the calls;
  - what is left out;
  - the memory the kernel takes;
  - how to boot your own program: block 0, `COBOL.OS`, and the program
    as `COBOL.SYSTEM`, or another name set at `KLNAM` in `KCALL2.S`.
- **STATUS.md's node path** now reads `%LOCALAPPDATA%`, with no user
  name in it.
