// fwdref.js - find Merlin 8's ILLEGAL FORWARD REFERENCE before Merlin does.
//
//   cd src && node ../tools/fwdref.js            all fifteen assemblies
//   cd src && node ../tools/fwdref.js LIB.S      just one stub
//
// Merlin 8 assembles in two passes, and in the first it has to know how
// big every line is.  So two kinds of line need their symbols already
// defined when Merlin reaches them, in the order the stub PUTs its files:
//
//   1. pseudo-ops whose operand sets a value or a size - EQU, =, DS, ORG,
//      DUM, LUP, DO, IF.  A forward symbol there is the error, and in an
//      EQU it can silently leave a wrong value behind.
//   2. an instruction naming a symbol that is defined LATER and turns out
//      to be zero page.  Pass 1 has already counted three bytes for the
//      absolute form, so pass 2 cannot use the two-byte form.
//
// Merlin32 resolves both without complaint, which is why this exists.
// Like check.js it is not an assembler: expressions it cannot evaluate
// are skipped for test 2, never guessed.
const fs = require('fs');

const STUBS = ['LIB.S', 'AUXLC.S', 'COBOLSYS.S', 'UTIL.S', 'EDIT.S', 'FORMAT.S', 'QUERY.S', 'REPORT.S',
  'VM.S', 'COMPILE1.S', 'COMPILE2.S', 'QRYTEST.S', 'KEYTEST.S', 'OBJTEST.S',
  'LEXTEST.S', 'BCDTEST.S', 'PICTEST.S'];
const VALUE_OPS = new Set(['EQU', '=', 'DS', 'ORG', 'DUM', 'LUP', 'DO', 'IF']);
// mnemonics that have a zero-page form for a plain address operand
const ZP_OPS = new Set(('LDA LDX LDY STA STX STY STZ ADC SBC AND ORA EOR CMP ' +
  'CPX CPY INC DEC ASL LSR ROL ROR BIT TRB TSB').split(' '));

function expand(stub) {
  const out = [];
  fs.readFileSync(stub, 'utf8').split(/\r?\n/).forEach((t, i) => {
    out.push({ f: stub, n: i + 1, t });
    const m = t.match(/^\s+PUT\s+([A-Z0-9]+)/);
    if (m) fs.readFileSync(m[1] + '.S', 'utf8').split(/\r?\n/)
      .forEach((u, j) => out.push({ f: m[1] + '.S', n: j + 1, t: u }));
  });
  return out;
}

// split a source line into label / opcode / operand (Merlin fields)
function fields(t) {
  if (/^\s*$/.test(t) || /^[*;]/.test(t)) return null;
  const label = (t.match(/^([^\s]+)/) || [])[1] || '';
  let rest = t.slice(label.length).trimStart();
  const op = (rest.match(/^(\S+)/) || [])[1] || '';
  rest = rest.slice(op.length).trimStart();
  let operand = '', q = null;
  for (const c of rest) {
    if (q) { operand += c; if (c === q) q = null; continue; }
    if (c === '"' || c === "'") { q = c; operand += c; continue; }
    if (c === ' ' || c === ';') break;
    operand += c;
  }
  return { label, op: op.toUpperCase(), operand };
}

function symbolsIn(operand) {
  const s = operand.replace(/"[^"]*"?|'[^']*'?/g, ' ')
    .replace(/\$[0-9A-Fa-f]+|%[01]+/g, ' ')
    .replace(/,[XYxy]\)?$/, '').replace(/^#?[<>^]?/, '');
  return (s.match(/[A-Za-z_][A-Za-z0-9_.]*/g) || []).filter(x => !/^[XYA]$/i.test(x));
}

function evaluate(expr, vals) {
  let e = expr.replace(/^[#<>^]+/, '');
  if (/[(),]/.test(e) || /["']/.test(e) || e.includes('*')) return null;
  const tokens = e.match(/\$[0-9A-Fa-f]+|%[01]+|\d+|[A-Za-z_][A-Za-z0-9_.]*|[-+]/g);
  if (!tokens || tokens.join('') !== e) return null;
  let v = 0, sign = 1;
  for (const k of tokens) {
    if (k === '+') { sign = 1; continue; }
    if (k === '-') { sign = -1; continue; }
    let n;
    if (k[0] === '$') n = parseInt(k.slice(1), 16);
    else if (k[0] === '%') n = parseInt(k.slice(1), 2);
    else if (/^\d/.test(k)) n = parseInt(k, 10);
    else if (vals.has(k)) n = vals.get(k);
    else return null;
    v += sign * n;
  }
  return v & 0xFFFF;
}

function check(stub) {
  const L = expand(stub);
  const where = new Map(), equ = new Map(), vals = new Map(), isEqu = new Set();
  L.forEach((r, i) => {
    const f = fields(r.t); if (!f || !f.label || /^[:\]]/.test(f.label)) return;
    if (!where.has(f.label)) where.set(f.label, i);
    if (f.op === 'EQU' || f.op === '=') { equ.set(f.label, f.operand); isEqu.add(f.label); }
  });
  for (let pass = 0; pass < 20; pass++)          // resolve EQU chains
    for (const [k, x] of equ) if (!vals.has(k)) {
      const v = evaluate(x, vals); if (v !== null) vals.set(k, v);
    }
  const hits = [];
  L.forEach((r, i) => {
    const f = fields(r.t); if (!f || !f.op) return;
    const later = symbolsIn(f.operand).filter(s => where.has(s) && where.get(s) > i);
    if (!later.length) return;
    if (VALUE_OPS.has(f.op))
      hits.push(`${r.f}:${r.n}  ${f.op} uses ${later.join(', ')} before it is defined`);
    else if (/^\(.*(\),[Yy]|,[Xx]\))$/.test(f.operand) || /^\([^,]*\)$/.test(f.operand) && f.op !== 'JMP')
      // (zp),Y  (zp,X)  (zp) exist only in zero page, so pass 1 must
      // already know the pointer.  Merlin 8 reports the forward
      // reference in pass 1, then BAD ADDRESS MODE too if it is not zp.
      hits.push(`${r.f}:${r.n}  ${f.op} ${f.operand} - indirect pointer ${later.join(', ')} defined later`);
    else if (ZP_OPS.has(f.op) && !f.operand.startsWith('#')) {
      const base = f.operand.replace(/^\(/, '').replace(/\)?,[XYxy]\)?$|\)$/g, '');
      const v = evaluate(base, vals);
      if (v !== null && v < 0x100)
        hits.push(`${r.f}:${r.n}  ${f.op} ${f.operand} is zero page ($${v.toString(16).toUpperCase()}) but defined later, so it stays absolute`);
    }
  });
  // 4. An EQU that gives a SMALL value (under $100) to a symbol some
  // earlier line already used - in any mode, immediate included.  Pass 1
  // took the unknown symbol for a two-byte address; when the EQU turns
  // out to be zero-page sized, Merlin 8 reports ILLEGAL FORWARD
  // REFERENCE once, AT THE EQU LINE.  Proven 2026-11-07 on CLOCK.S:
  // LDY #NSCLEN-1 above NSCLEN EQU *-NSCDRV ($7A) gave one error;
  // STA NSCUAD above NSCUAD EQU NSCU1+1 ($5B11) gave none.
  // A value this pass cannot work out is listed as "maybe".
  const firstUse = new Map();
  L.forEach((r, i) => {
    const f = fields(r.t); if (!f || !f.op || f.op === 'EQU' || f.op === '=') return;
    for (const s of symbolsIn(f.operand))
      if (isEqu.has(s) && where.get(s) > i && !firstUse.has(s)) firstUse.set(s, r);
  });
  for (const [s, u] of firstUse) {
    const d = L[where.get(s)], v = vals.has(s) ? vals.get(s) : null;
    if (v !== null && v >= 0x100) continue;
    if (v === null) {
      // built from code labels: LABEL+n is an address (never zero page),
      // LABEL-LABEL or *-LABEL is a length (small, so it counts)
      const x = equ.get(s);
      if (!/^\*?[-]|[A-Za-z0-9_]-[A-Za-z_*]/.test(x) && !x.startsWith('*-')) continue;
    }
    const vs = v === null ? 'value unknown - maybe' : '$' + v.toString(16).toUpperCase();
    hits.push(`${d.f}:${d.n}  ${s} EQU (${vs}) - used first at ${u.f}:${u.n}`);
  }
  return hits;
}

const pick = process.argv.slice(2);
let total = 0;
for (const s of (pick.length ? pick : STUBS)) {
  if (!fs.existsSync(s)) continue;
  const h = check(s); total += h.length;
  console.log(`${s.replace('.S', '').padEnd(9)} ${h.length ? h.length + ' forward reference(s)' : 'clean'}`);
  h.forEach(x => console.log('   ' + x));
}
if (total) process.exitCode = 1;
