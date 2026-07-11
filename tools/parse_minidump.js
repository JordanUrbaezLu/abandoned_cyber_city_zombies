#!/usr/bin/env node
// Minimal MDMP parser: exception record + faulting module (no symbols needed).
// Streams: 6 = ExceptionStream, 4 = ModuleListStream. Module names = MINIDUMP_STRING (UTF-16LE, u32 len).
'use strict';
const fs = require('fs');

for (const file of process.argv.slice(2)) {
  const b = fs.readFileSync(file);
  if (b.toString('ascii', 0, 4) !== 'MDMP') { console.log(file + ': not a minidump'); continue; }
  const nStreams = b.readUInt32LE(8);
  const dirRva = b.readUInt32LE(12);
  let excStream = null, modStream = null;
  for (let i = 0; i < nStreams; i++) {
    const off = dirRva + i * 12;
    const type = b.readUInt32LE(off);
    const size = b.readUInt32LE(off + 4);
    const rva = b.readUInt32LE(off + 8);
    if (type === 6) excStream = { rva, size };
    if (type === 4) modStream = { rva, size };
  }
  console.log('=== ' + file.split(/[\\/]/).pop());
  let excAddr = null;
  if (excStream) {
    const e = excStream.rva;
    const tid = b.readUInt32LE(e);
    const code = b.readUInt32LE(e + 8);
    const flags = b.readUInt32LE(e + 12);
    excAddr = b.readBigUInt64LE(e + 24);
    const nParams = b.readUInt32LE(e + 32);
    const params = [];
    for (let i = 0; i < Math.min(nParams, 4); i++) params.push(b.readBigUInt64LE(e + 40 + i * 8));
    console.log('  exception code 0x' + code.toString(16) + ' flags ' + flags + ' tid ' + tid + ' addr 0x' + excAddr.toString(16));
    if (code === 0xc0000005 && params.length >= 2)
      console.log('  access violation: ' + (params[0] === 0n ? 'READ' : params[0] === 1n ? 'WRITE' : 'DEP') + ' of address 0x' + params[1].toString(16));
  } else console.log('  (no exception stream)');
  if (modStream && excAddr != null) {
    const m = modStream.rva;
    const nMods = b.readUInt32LE(m);
    let hit = null;
    const mods = [];
    for (let i = 0; i < nMods; i++) {
      const off = m + 4 + i * 108;                     // MINIDUMP_MODULE = 108 bytes
      const base = b.readBigUInt64LE(off);
      const size = BigInt(b.readUInt32LE(off + 8));
      const nameRva = b.readUInt32LE(off + 20);   // BaseOfImage(8)+SizeOfImage(4)+CheckSum(4)+TimeDateStamp(4) -> ModuleNameRva @20
      const nameLen = b.readUInt32LE(nameRva);
      const name = b.toString('utf16le', nameRva + 4, nameRva + 4 + nameLen);
      mods.push({ base, size, name });
      if (excAddr >= base && excAddr < base + size) hit = { base, name };
    }
    if (hit) console.log('  faulting module: ' + hit.name + ' +0x' + (excAddr - hit.base).toString(16));
    else console.log('  faulting address is in NO module (dynamic/JIT/stomped memory)');
    const exe = mods.find(x => /blackops3\.exe/i.test(x.name));
    if (exe) console.log('  blackops3.exe base 0x' + exe.base.toString(16) + (excAddr >= exe.base && excAddr < exe.base + exe.size ? ' -> exe offset 0x' + (excAddr - exe.base).toString(16) : ''));
  }
}
