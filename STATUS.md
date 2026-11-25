# COBOL.OS — status

**Read this first**, then `DESIGN.md` (the plan; §10 is the order of
work) and `DECISIONS.md`.

## Where it stands — 2026-11-25

**Stages 0 to 4 are done and pass in AppleWin.** The COBOL.OS build
of COBOL (`cobol/`) ran the whole suite overnight on 2026-11-24/25.
Its screens match the ProDOS build's apart from what is meant to
differ (item 9 on both menus, QUIT), the clock, the cursor's blink, and
SALESDB's root-full COPY. DECISIONS 6.15 has the list.
- **Both builds guard themselves** (6.1, 6.11), and both guards passed
  again overnight.
- **DELETE erases** in every one-line input (6.12), and **command
  letters fold** (6.13). Both are in both builds. The overnight run
  passed FORMAT, ACCEPT and the lowercase type answer. The
  Utilities/GETLN80 step (`deltest.ps1 -Only 1`) passed on 2026-11-25.
- **ESC now cancels a typed name** in Utilities and RUN (DECISIONS
  6.16, the user's yes, 2026-11-25). Before, `UNAME` ignored GETLN80's
  carry, so ESC at "DELETE a file" destroyed the file. Fixed in both
  builds and tested on both 800K disks. It is not on COBOL32.po yet.
- **`cobol/src/UTILD.S` is 23,775 bytes**, close to Merlin 8's PUT
  limit. The next thing added to Utilities should go in a new PUT file.
- **800K disks:** `tools/emu/mk800.ps1` makes `COBOL800PD.po` and
  `COBOL800OS.po` from the current builds (6.14). Both were tested in
  the hard-disk slot, but not booted from a 3.5-inch drive.
- **Next:**
  - the Merlin 8 assembly of the sources;
  - P:\COBOL's 8.11 test and the 8.11 + 8.14 + 8.15 deploy (the
    user's go-ahead);
  - the OA-D against SA-D question (COBOL's KEYS.md §9);
  - stage 5.

### Stages 0 to 3

COBOL.OS reads and writes every kind of ProDOS file, and the COBOL
suite runs on it with the same results as on ProDOS 8.

- **The kernel** answers 18 calls: `READ_BLOCK`, `WRITE_BLOCK`,
  `ON_LINE`, `SET_PREFIX`, `GET_PREFIX`, `OPEN`, `NEWLINE`, `READ`,
  `WRITE`, `CLOSE`, `SET_MARK`, `GET_MARK`, `GET_EOF`, `SET_EOF`,
  `GET_FILE_INFO`, `CREATE`, `DESTROY` and `RENAME`. Any other call
  returns `$01`. `QUIT` is stage 4.
- **Writing**:
  - files grow from seedling to sapling to tree;
  - `SET_EOF` frees blocks and brings the storage type back down, as
    ProDOS does;
  - `CREATE` grows a subdirectory, and gives `$49` when the volume
    directory has all 51 entries;
  - the backup bit and the modified date are set as ProDOS sets them;
  - the bitmap block is cached, then written back and forgotten after
    every call.
- **The version byte**: `$BFFE`/`$BFFF` = `$C0`, which no ProDOS has
  used. The two builds of COBOL planned for stage 4 test it at
  start-up (DESIGN §8.4).
- **TEST3**, 85 checks, **passes on ProDOS 8 and on COBOL.OS**.
  Afterwards `tools/keepcheck.py` compares the files it leaves byte
  for byte. `tools/pdcheck.py` and cp2's `test` both find the disks
  sound. TEST2 (165 checks) still passes.
- **The COBOL suite** (`suite.ps1` and `a26run.ps1`, through
  `tools/suite/both.ps1`) ran on both systems, each from a fresh copy
  of `COBOL32.po`, 170 minutes each.
  - Every screenshot matches apart from these, all accounted for:
    - **dates and times on screen**: the two runs were on different
      days;
    - **ProDOS timing flakes**: e43, ln, e50d, rg-qsort and rp
      (with rs, which follows from rp). The file wasn't opened in time.
      `rerun.ps1` ran them again and they match COBOL.OS;
    - **SALESDB's COPY** on COBOL.OS. The COBOL.OS disk has one more
      root entry (the file COBOL.OS), so WEST.DAT would have been the
      52nd. `rootfull.ps1` gave real ProDOS the same 48 entries,
      and it failed the same way, with the same "00 30" and the same
      screens after it.
  - Disks afterwards: cp2 `test` finds no failures and `pdcheck.py`
    accounts for every block, on both.
  - Results are in `tools/suite/results/` (PD, OS, PD-rerun,
    OS-rerun, PD-full, OS-full).
  - `cmpshots.ps1` compares two runs pixel by pixel.

| piece | size |
|---|---|
| `BOOTBLK` (block 0) | 348 of 512 bytes |
| `COBOL.OS` file | 7,457 bytes (2026-11-25, after stage 4) |
| kernel at `$E000` | 7,097 bytes, `$E000`–`$FBB9`; 1,089 free below `$FFFA` |
| installer | `$2000`–`$2066` |
| `TEST2` | 2,391 bytes, up to `$2956` (must stay below `$2E00`) |
| `TEST3` | 2,936 bytes, up to `$2B77` |

Stage 4 added `QUIT`, Ctrl-Reset, the `$BD00` move, the turnkey
copier, "Make a disk bootable" and each build's `$BFFF` test
(DECISIONS 6.1–6.11). The two builds keep the same file names (6.8).

## Building and testing

```
sh tools/m32build.sh              # build/obj/BOOTBLK.BIN, COBOLOS.BIN, TEST2.BIN, TEST3.BIN
tools/emu/mktest.ps1 [-Test TEST3]  # TESTOS.po + TESTPD.po: the test on both systems
python tools/keepcheck.py D:/AppleWin1.32.0.0/TESTOS.po   # after TEST3 runs
tools/suite/both.ps1 [-Only PD|OS]  # the COBOL suite on each system, ~3 h each
tools/suite/cmpshots.ps1          # results/PD against results/OS
tools/suite/overnight.ps1         # both.ps1, guards, deltest, cmpshots: ~6 h
tools/suite/deltest.ps1 [-Only 1,2,2b,3]   # DELETE and the case fold
tools/emu/mk800.ps1               # COBOL800PD.po + COBOL800OS.po
tools/emu/aw.ps1 start "D:\AppleWin1.32.0.0\TESTOS.po"   # or TESTPD.po
tools/emu/mkdisk.ps1              # COBOL32.po -> COBOLOS.po, block 0 + COBOL.OS
tools/emu/mkdisk.ps1 -Update      # keep COBOLOS.po, replace only those two
tools/emu/aw.ps1 start            # boots D:\AppleWin1.32.0.0\COBOLOS.po
tools/emu/aw.ps1 shot out.png
tools/emu/aw.ps1 keys "RPTT~"     # ~ = Return
tools/emu/aw.ps1 oa O             # Open-Apple-O   (sa = Solid-Apple)
tools/emu/aw.ps1 stop
```

- The build also checks the sizes Merlin can't:
  - the boot block fits one block;
  - `INSEND` and `TEST2`'s `TEND` are below `KBLK` (`$2E00`);
  - `KEND` is below `$FFFA`.

  It keeps Merlin32's symbol files in `build/src/`.
- Run `tools/fwdref.js` on `COBOLOS.S`, `BOOTBLK.S`, `TEST2.S` and
  `TEST3.S` from `src/` to catch Merlin 8 forward references. All four
  are clean (2026-11-24).
  Node isn't on PATH; it's
  `%LOCALAPPDATA%\claude-tools\node-v22.14.0-win-x64\node.exe`.
- `mktest.ps1` builds the test files from a formula (every byte is
  `p0 + 7·p1 + 13·p2` of its position), and cp2 stores the zero
  blocks of HOLES and TREEH as holes. It reads `COBOL32.po` only, for
  ProDOS's boot blocks and `PRODOS`.
- `COBOLOS2.po` is an empty 800K volume `/NEWDISK`, for drive 2.
- `mkdisk.ps1` and `mktest.ps1` never write `COBOL32.po`, and both
  refuse to run while AppleWin is open.
- `KTEST1.S` (stage 1's test) is no longer assembled. It's kept as
  the record of what stage 1 checked, and TEST2 covers its calls
  again.

## Not yet run in Merlin 8

Only Merlin32 has assembled these sources. Every line is 60 columns or
less, and `fwdref.js` is clean. A Merlin 8 assembly in AppleWin is
still to come, as in the COBOL tree.
