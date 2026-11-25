# keepcheck.py IMAGE - the files TEST3 leaves behind, checked on the PC
#
# Extracts KEEP2, KEEP3, KEEPS and KDIR/DATA with cp2 and compares each
# byte with the pattern TEST3 wrote: byte(p) = p0 + 7*p1 + 13*p2 mod 256,
# p its position; KEEPS is zeros except 279,000-279,999.  Then runs
# pdcheck.py on the image: every block in use owned by exactly one file,
# every entry's "blocks used" right.  Run it on TESTOS.po and TESTPD.po
# after `mktest.ps1 -Test TEST3` and a run of each.
import os, subprocess, sys, tempfile

CP2 = r"D:\cp2_1.2.0_win-x64_sc\cp2.exe"
img = os.path.abspath(sys.argv[1])

def pat(n, keep=None):
    return bytes(0 if keep and not keep(p) else
                 ((p & 255) + 7 * ((p >> 8) & 255) + 13 * (p >> 16)) & 255
                 for p in range(n))

want = {
    "KEEP2": pat(70000),
    "KEEP3": pat(140000),
    "KEEPS": pat(280000, lambda p: 279000 <= p < 280000),
    "KDIR/DATA": pat(5000),
}
bad = 0
with tempfile.TemporaryDirectory() as d:
    subprocess.run([CP2, "extract", "--preserve=none", img, "KEEP2", "KEEP3",
                    "KEEPS", "KDIR"], cwd=d, capture_output=True)
    for name, w in want.items():
        p = os.path.join(d, *name.split("/"))
        got = open(p, "rb").read() if os.path.exists(p) else None
        ok = got == w
        bad += not ok
        print(f"{name:10} {'OK' if ok else 'WRONG'}"
              f" ({'missing' if got is None else len(got)} bytes)")
subprocess.run([sys.executable, os.path.join(os.path.dirname(__file__),
                "pdcheck.py"), img])
sys.exit(1 if bad else 0)
