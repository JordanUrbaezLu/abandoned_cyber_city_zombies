#!/usr/bin/env node
// Extract the CRASHING thread's stack from a minidump and print ASCII + UTF-16 strings found on it,
// plus raw return-address candidates (pointers into blackops3.exe) in stack order.
'use strict';
const fs = require('fs');

const file = process.argv[2];
const b = fs.readFileSync(file);
if (b.toString('ascii', 0, 4) !== 'MDMP') throw new Error('not a minidump');
const nStreams = b.readUInt32LE(8), dirRva = b.readUInt32LE(12);
let exc = null, threads = null, mods = null;
for (let i = 0; i < nStreams; i++) {
  const off = dirRva + i * 12;
  const type = b.readUInt32LE(off), size = b.readUInt32LE(off + 4), rva = b.readUInt32LE(off + 8);
  if (type === 6) exc = rva;
  if (type === 3) threads = rva;          // ThreadListStream
  if (type === 4) mods = rva;
}
const crashTid = b.readUInt32LE(exc);
const excAddr = b.readBigUInt64LE(exc + 24);

// module ranges (for return-address classification)
const modList = [];
{
  const n = b.readUInt32LE(mods);
  for (let i = 0; i < n; i++) {
    const off = mods + 4 + i * 108;
    const base = b.readBigUInt64LE(off), size = BigInt(b.readUInt32LE(off + 8));
    const nameRva = b.readUInt32LE(off + 20);
    const nameLen = b.readUInt32LE(nameRva);
    const name = b.toString('utf16le', nameRva + 4, nameRva + 4 + nameLen);
    modList.push({ base, size, name: name.split('\\').pop() });
  }
}
const exe = modList.find(m => /blackops3\.exe/i.test(m.name));

// find crashing thread: MINIDUMP_THREAD = 48 bytes {ThreadId u32, ..., Stack: {StartOfMemoryRange u64, Memory:{DataSize u32, Rva u32}}, Teb...}
const nThreads = b.readUInt32LE(threads);
let stack = null;
for (let i = 0; i < nThreads; i++) {
  const off = threads + 4 + i * 48;
  const tid = b.readUInt32LE(off);
  if (tid !== crashTid) continue;
  const startAddr = b.readBigUInt64LE(off + 16);
  const dataSize = b.readUInt32LE(off + 24);
  const rva = b.readUInt32LE(off + 28);
  stack = { startAddr, dataSize, rva };
}
if (!stack) throw new Error('crashing thread ' + crashTid + ' not in thread list');
console.log('crash addr 0x' + excAddr.toString(16) + (exe ? ' (exe+0x' + (excAddr - exe.base).toString(16) + ')' : ''));
console.log('stack: start 0x' + stack.startAddr.toString(16) + ' size ' + stack.dataSize);
const s = b.subarray(stack.rva, stack.rva + stack.dataSize);

// 1) return addresses into modules (backtrace skeleton, stack order)
console.log('\n--- pointers into modules (stack order, exe offsets) ---');
const seen = [];
for (let off = 0; off + 8 <= s.length; off += 8) {
  const v = s.readBigUInt64LE(off);
  for (const m of modList) {
    if (v >= m.base && v < m.base + m.size) {
      seen.push((m.name === exe?.name ? 'exe+0x' + (v - m.base).toString(16) : m.name + '+0x' + (v - m.base).toString(16)));
      break;
    }
  }
  if (seen.length >= 40) break;
}
console.log(seen.join('\n'));

// 2) ASCII strings on the stack
console.log('\n--- ASCII strings (>=5 chars) on the crashing stack ---');
let cur = [], outA = [];
for (let i = 0; i < s.length; i++) {
  const c = s[i];
  if (c >= 32 && c < 127) cur.push(c);
  else { if (cur.length >= 5) outA.push(Buffer.from(cur).toString('ascii')); cur = []; }
}
console.log([...new Set(outA)].join('\n'));

// 3) UTF-16LE strings
console.log('\n--- UTF-16 strings (>=5 chars) ---');
cur = []; let outW = [];
for (let i = 0; i + 1 < s.length; i += 2) {
  const lo = s[i], hi = s[i + 1];
  if (hi === 0 && lo >= 32 && lo < 127) cur.push(lo);
  else { if (cur.length >= 5) outW.push(Buffer.from(cur).toString('ascii')); cur = []; }
}
console.log([...new Set(outW)].join('\n'));
