#!/usr/bin/env node
// find_region.js <x1> <x2> <y1> <y2> <z1> <z2> [map]
// List worldspawn brushes whose CENTROID falls inside the AABB, with bounds + material + nearest comment.
// Used to scope a bounds-aware material repaint (e.g. the Lab / Paradise hex-tile pass). Read-only.
'use strict';
const fs = require('fs');
const a = process.argv.slice(2);
const [X1, X2, Y1, Y2, Z1, Z2] = a.slice(0, 6).map(Number);
const MAP = a[6] || 'map_source/zm/zm_abandoned_cyber_city.map';
const N = '(-?[\\d.]+)';
const FACE_RE = new RegExp('^\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s+(\\S+)');
function boundsOf(faces){if(faces.length!==6)return null;const A=[[],[],[]];for(const[p1,p2,p3]of faces){const u=[p2[0]-p1[0],p2[1]-p1[1],p2[2]-p1[2]],v=[p3[0]-p1[0],p3[1]-p1[1],p3[2]-p1[2]];const n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]];const ab=n.map(Math.abs),mx=Math.max(...ab);if(mx<1e-6)return null;const ax=ab.indexOf(mx);if(ab[(ax+1)%3]+ab[(ax+2)%3]>mx*1e-4)return null;A[ax].push(p1[ax]);}if(A.some(g=>g.length!==2))return null;return[Math.min(...A[0]),Math.max(...A[0]),Math.min(...A[1]),Math.max(...A[1]),Math.min(...A[2]),Math.max(...A[2])];}

const lines = fs.readFileSync(MAP, 'utf8').split('\n');
const stack = []; let depth = 0; let curComment = '';
const hits = []; const mats = {};
let comb = [Infinity,-Infinity,Infinity,-Infinity,Infinity,-Infinity];
for (let i = 0; i < lines.length; i++) {
  const t = lines[i].trim();
  if (t.startsWith('//')) curComment = t.replace(/^\/\/\s*/, '');
  const opens = (lines[i].match(/{/g) || []).length, closes = (lines[i].match(/}/g) || []).length;
  for (let o = 0; o < opens; o++) { stack.push({ faces: [], mat: null, isEntity: depth === 0, cmt: curComment }); depth++; }
  const m = lines[i].match(FACE_RE);
  if (m && stack.length) { const tk = stack[stack.length-1]; tk.faces.push([[+m[1],+m[2],+m[3]],[+m[4],+m[5],+m[6]],[+m[7],+m[8],+m[9]]]); if(!tk.mat) tk.mat = m[10]; }
  for (let c = 0; c < closes; c++) { depth--; const blk = stack.pop(); if (!blk || blk.isEntity || blk.faces.length !== 6) continue;
    const b = boundsOf(blk.faces); if (!b) continue;
    const cx=(b[0]+b[1])/2, cy=(b[2]+b[3])/2, cz=(b[4]+b[5])/2;
    if (cx>=X1&&cx<=X2&&cy>=Y1&&cy<=Y2&&cz>=Z1&&cz<=Z2) {
      hits.push({ b, mat: blk.mat, cmt: blk.cmt });
      mats[blk.mat] = (mats[blk.mat]||0)+1;
      comb=[Math.min(comb[0],b[0]),Math.max(comb[1],b[1]),Math.min(comb[2],b[2]),Math.max(comb[3],b[3]),Math.min(comb[4],b[4]),Math.max(comb[5],b[5])];
    }
  }
}
console.log(`Region x[${X1},${X2}] y[${Y1},${Y2}] z[${Z1},${Z2}] -> ${hits.length} brushes (centroid-in)`);
for (const h of hits) console.log(`  ${(h.mat||'?').padEnd(28)} x[${h.b[0]},${h.b[1]}] y[${h.b[2]},${h.b[3]}] z[${h.b[4]},${h.b[5]}]  // ${h.cmt.slice(0,60)}`);
console.log(`\nMaterials:`, mats);
if (hits.length) console.log(`Combined bounds: x[${comb[0]},${comb[1]}] y[${comb[2]},${comb[3]}] z[${comb[4]},${comb[5]}]`);
