# COBOL.OS: a small ProDOS-compatible kernel for the Apple IIe

> **SmartPort devices only.** COBOL.OS drives 3.5" disks and hard disks
> through SmartPort firmware, and nothing else. It has no Disk II (5.25")
> driver, no /RAM disk, and no support for ProDOS block-device drivers.
> A volume it boots from, or reads, must be on a SmartPort device.

COBOL.OS is a 7K replacement for ProDOS 8, written in 65C02 assembly. It
sits in the main language card, is entered at `$BF00`, and answers ProDOS's
own MLI calls with ProDOS's call numbers, parameter blocks and error codes on
ordinary ProDOS volumes. A program written for ProDOS that sticks to the calls
below runs on it unchanged.

It was written for [COBOL SYSTEM](https://github.com/JohnSnape/apple2-cobol),
which runs unchanged on it. It is published on its own for anyone who wants a
small, readable ProDOS-compatible kernel under their own program, with the
rest of the language card left free.

The code is new. It was written from the published description of the ProDOS
disk format and calls, not from ProDOS's code.

## What it does

### The ProDOS calls it handles

These are the 19 calls in the kernel's dispatch table (`src/KMLI.S`), each
with ProDOS's call number, parameter count and parameter block. You call
them exactly as you would under ProDOS:

```
 JSR $BF00
 DFB call_number
 DA  parameter_block
```

On return, carry clear means success. Carry set means an error, with the
code in A. The error codes are ProDOS's.

| Call | Name | Params | Notes |
|---|---|---|---|
| `$C0` | `CREATE` | 7 | Files and subdirectories. Gives `$49` when the root directory's 51 entries are full; a subdirectory grows instead. Sets the backup bit and the creation date. |
| `$C1` | `DESTROY` | 1 | Frees every block, whatever the storage type |
| `$C2` | `RENAME` | 2 | Both names in the same directory (`$40` if not), as in ProDOS. Renaming a directory changes its header too. |
| `$C4` | `GET_FILE_INFO` | 10 | Files, directories and volumes. A volume gives what ProDOS gives: type `$0F` and its size in blocks as the aux type. |
| `$C5` | `ON_LINE` | 2 | Unit 0 lists every drive |
| `$C6` | `SET_PREFIX` | 1 | |
| `$C7` | `GET_PREFIX` | 1 | |
| `$C8` | `OPEN` | 3 | Up to 8 files at once. The caller's 1,024-byte buffer holds the file's data block and index block while it's open. A second `OPEN` of a file that can be written gives `$50`, as in ProDOS. |
| `$C9` | `NEWLINE` | 3 | |
| `$CA` | `READ` | 4 | All three storage types; sparse files read back as zeros |
| `$CB` | `WRITE` | 4 | Files grow from seedling to sapling to tree |
| `$CC` | `CLOSE` | 1 | Reference 0 closes every open file. There are no file levels. |
| `$CE` | `SET_MARK` | 2 | From 0 to the end of the file; past it gives `$4D`, as in ProDOS. To leave a hole, `SET_EOF` first. |
| `$CF` | `GET_MARK` | 2 | |
| `$D0` | `SET_EOF` | 2 | Shortening frees blocks and brings the storage type back down |
| `$D1` | `GET_EOF` | 2 | |
| `$80` | `READ_BLOCK` | 3 | One 512-byte block from a unit |
| `$81` | `WRITE_BLOCK` | 3 | One 512-byte block to a unit |
| `$65` | `QUIT` | 4 | No program selector: see below |

**Not provided:** `FLUSH` (`$CD`), `SET_FILE_INFO` (`$C3`), `GET_TIME`
(`$82`), `ALLOC_INTERRUPT` (`$40`), `DEALLOC_INTERRUPT` (`$41`), `GET_BUF`
(`$D3`) and `SET_BUF` (`$D2`). These, and any other number, return error
`$01`, as ProDOS does for a call it doesn't know.

### The rest

**The file system:**
- seedling, sapling and tree files, read and written, growing across the
  boundaries;
- sparse files;
- subdirectories, which grow a block at a time;
- the 51-entry root directory;
- the backup bit and the creation and modification dates.

`SET_EOF` frees blocks and brings the storage type back down, as ProDOS
does. Up to 8 files can be open at once.

**Devices:** SmartPort only, so 3.5" drives and hard disks, up to 65,535
blocks (32 MB) a volume. At boot it scans slots 7 down to 1 and builds the
device list at `$BF31` in ProDOS's format.

**`QUIT`** closes every file and shows "Change the disk and press RETURN to
restart the system". Then it boots the slot it started from.

**Ctrl-Reset** starts the system again: it finds the drives, resets the
prefix and reloads the system program. Open files are forgotten, not written
back. That's because a reset can land in the middle of a call, and writing
back from that state could damage a sound file.

## What it leaves out

Compared with ProDOS 8, it has:
- no Disk II (5.25") driver;
- no /RAM disk;
- no clock driver: `$BF06` is an `RTS` until your program installs one;
- no interrupt handling: the vectors point at an `RTI`;
- no program selector;
- no BASIC.SYSTEM support.

## Memory

| | |
|---|---|
| `$E000`–`$FBB9`, main language card | The kernel's code. 1,089 bytes are free below `$FFFA`. |
| `$D000`–`$DFFF` bank 1, main card | Its data: the file control blocks, the prefix, the cached bitmap block |
| `$D000`–`$DFFF` bank 2, main card | **Free** |
| `$BF00` page | ProDOS-compatible: `$BF00` entry, `$BF06` clock hook, `$BF30` `DEVNUM`, device list, `$BF90` date and time, `$BF98` `MACHID`. The rest holds the entry stub and the SmartPort trampoline. |
| `$BD00`–`$BEFF` | Its 512-byte block buffer. The SmartPort firmware can't reach the language card, so the buffer has to be in main RAM. |
| Zero page `$40`–`$4F` | The only zero page it uses |
| Auxiliary memory, aux language card | Never touched. They're yours. |

`$BFFF` (`KVERSION`) is **`$C0`**, a value no ProDOS has used. A program can
tell which system it's on with `LDA $BFFF / CMP #$C0 / BCS`.

## Starting your own program

A volume boots COBOL.OS when it has these:
1. **block 0:** `BOOTBLK.BIN`, padded to 512 bytes;
2. **`COBOL.OS`** in the root directory: type `$FF` (SYS), aux type `$2000`;
3. **`COBOL.SYSTEM`** in the root directory: your program, type `$FF`. It
   is loaded at `$2000` and entered there, as ProDOS starts a `.SYSTEM`
   file.

Everything else on the volume is ordinary ProDOS. Put ProDOS's block 0 back
and the disk boots ProDOS again.

**To start a file with another name,** change `KLNAM` in `src/KCALL2.S`: a
length byte and up to 15 characters. Also change the message `KLEMSG` just
above it.

## Building

Merlin32, from Brutal Deluxe, builds it on a PC:

```sh
sh tools/m32build.sh     # build/obj/BOOTBLK.BIN, COBOLOS.BIN, TEST2.BIN, TEST3.BIN
```

- Set the path to `Merlin32.exe` at the top of the script.
- The script also checks the sizes Merlin can't. The boot block must fit in
  one block. The installer and the tests must end below `$BD00`. The kernel
  must end below `$FFFA`.
- **Merlin 8 on the Apple** is the assembler of record:
  - every line is 60 columns or less;
  - every `PUT` file is far under Merlin 8's limit;
  - `tools/fwdref.js` finds no forward `EQU`s, which Merlin 8 would assemble
    wrong without saying so.

  **A Merlin 8 assembly hasn't been done yet.**

## Testing

| | |
|---|---|
| `src/TEST2.S` | 165 checks of reading |
| `src/TEST3.S` | 85 checks of writing |
| `tools/emu/mktest.ps1` | Makes two 800K disks with the same test files. One boots COBOL.OS and the other ProDOS 8, with the test as the system program. Passing on ProDOS proves the test's expectations; passing on COBOL.OS proves the kernel. |
| `tools/pdcheck.py` | Checks a volume from outside: every block owned, the bitmap right |
| `tools/keepcheck.py` | Checks the files TEST3 leaves, byte for byte |

Both tests pass on ProDOS 8 and on COBOL.OS in
[AppleWin](https://github.com/AppleWin/AppleWin). After them, the independent
`cp2` disk tool and `pdcheck.py` both find the disks sound.

The PowerShell scripts in `tools/emu/` drive AppleWin on Windows and name the
folders they use at the top. Change those to your own.

## Documents

| | |
|---|---|
| [`DESIGN.md`](../DESIGN.md) | The plan: the calls, memory, the `$BF00` page, booting, the edge cases |
| [`DECISIONS.md`](../DECISIONS.md) | Every decision and why, in order, including what testing found |
| [`STATUS.md`](../STATUS.md) | Where it stands, and the build and test commands |

These documents also cover the build of COBOL SYSTEM that runs on this kernel
(their stage 4). That build isn't part of this repository.

## Licence

MIT. See [`LICENSE`](../LICENSE).
