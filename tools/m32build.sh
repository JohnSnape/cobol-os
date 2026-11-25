#!/bin/sh
# m32build.sh - assemble COBOL.OS with Merlin32, on the PC.
#
#   sh tools/m32build.sh          build all, into build/obj/
#
# Merlin32 stands in for Merlin 8, as in the COBOL tree: it has no 24K
# PUT limit and forgives forward references, so tools/fwdref.js and a
# real Merlin 8 run still follow.  src/ is never touched - the copies
# in build/src get a DSK and a TYP line.
#
# Checks made here because Merlin cannot make them:
#   BOOTBLK  fits in one block (512 bytes)
#   COBOLOS  INSTALL ends below KBLK ($BD00 since stage 4; it was
#            $2E00), and the kernel ends
#            below the vectors at $FFFA
#   TEST2    the stage-2 test (run AS COBOL.SYSTEM on the test disks)
#            ends below KBLK too: the kernel's buffer would land on it
M32=/d/Merlin32/v1.2/Merlin32_v1.2_b2/Windows/Merlin32.exe
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
B="$ROOT/build"
MAIN="BOOTBLK COBOLOS TEST2 TEST3"

rm -rf "$B/src" "$B/obj"; mkdir -p "$B/src" "$B/obj"
cp "$ROOT/src/"*.S "$B/src/"
cd "$B/src" || exit 1
for s in $MAIN; do
  sed -i "0,/^ ORG/s#^ ORG# DSK $s.BIN\n TYP \$06\n ORG#" $s.S
done

fail=0
for s in $MAIN; do
  err=$("$M32" -V . $s.S 2>&1 | grep -iE "=> \[|error" | head -6 | tr -s ' ')
  if [ -f "$s.BIN" ]; then
    mv "$s.BIN" "$B/obj/$s.BIN"; size=$(stat -c %s "$B/obj/$s.BIN")
  else size="-"; fail=1; fi
  printf "%-9s %6s  %s\n" "$s" "$size" "$err"
done

# symbol values, from Merlin32's symbol file (-V): lines are
#   Segment1;line;file;line;00/2402;INSEND;Data;...
sym() { grep -h ";$1;" "$B/src/"${2:-COBOLOS}.BIN_Symbols.txt 2>/dev/null \
  | head -1 | cut -d';' -f5 | cut -d/ -f2; }
if [ -f "$B/obj/BOOTBLK.BIN" ] && [ $(stat -c %s "$B/obj/BOOTBLK.BIN") -gt 512 ]; then
  echo "BOOTBLK is over 512 bytes"; fail=1; fi
ie=$(sym INSEND); ke=$(sym KEND)
# KBLK is an EQU, and EQUs are not in the symbol file: read it from KEQU.S
kb=$(grep -m1 '^KBLK EQU' "$ROOT/src/KEQU.S" | sed 's/.*[$]//' | tr -d ' ')
if [ -n "$ie" ]; then
  printf "INSEND \$%s  (must be below KBLK, \$%s)\n" "$ie" "$kb"
  [ $((0x$ie)) -ge $((0x$kb)) ] && { echo "INSEND reaches KBLK"; fail=1; }
fi
if [ -n "$ke" ]; then
  printf "KEND   \$%s  kernel %d bytes, %d free below \$FFFA\n" "$ke" \
    $((0x$ke - 0xE000)) $((0xFFFA - 0x$ke))
  [ $((0x$ke)) -ge $((0xFFFA)) ] && { echo "kernel reaches the vectors"; fail=1; }
fi
for t in TEST2 TEST3; do
  te=$(sym TEND $t)
  if [ -n "$te" ]; then
    printf "TEND   \$%s  (%s, must be below \$%s)\n" "$te" "$t" "$kb"
    [ $((0x$te)) -ge $((0x$kb)) ] && { echo "$t reaches KBLK"; fail=1; }
  fi
done
rm -f "$B/src/"*_Output*.txt "$B/src/_FileInformation.txt"
# the symbol files stay, for pdis-style debugging
exit $fail
