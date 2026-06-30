#!/usr/bin/env node
// list_zones.js - print every player_volume / info_volume entity's targetname + AABB (the zone footprints).
// Used to scope the per-zone material art pass (paint_region regions). Read-only.
'use strict';
const fs = require('fs');
const MAP = process.argv[2] || 'map_source/zm/zm_abandoned_cyber_city.map';
const N = '(-?[\\d.]+)';
const FACE_RE = new RegExp('^\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)');
function boundsOf(faces){if(faces.length!==6)return null;const A=[[],[],[]];for(const[p1,p2,p3]of faces){const u=[p2[0]-p1[0],p2[1]-p1[1],p2[2]-p1[2]],v=[p3[0]-p1[0],p3[1]-p1[1],p3[2]-p1[2]];const n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]];const ab=n.map(Math.abs),mx=Math.max(...ab);if(mx<1e-6)return null;const ax=ab.indexOf(mx);if(ab[(ax+1)%3]+ab[(ax+2)%3]>mx*1e-4)return null;A[ax].push(p1[ax]);}if(A.some(g=>g.length!==2))return null;return[Math.min(...A[0]),Math.max(...A[0]),Math.min(...A[1]),Math.max(...A[1]),Math.min(...A[2]),Math.max(...A[2])];}

const lines = fs.readFileSync(MAP,'utf8').split('\n');
let depth=0, ent=null, brush=null;
const zones=[];
for(let i=0;i<lines.length;i++){
  const opens=(lines[i].match(/{/g)||[]).length, closes=(lines[i].match(/}/g)||[]).length;
  for(let o=0;o<opens;o++){ if(depth===0) ent={keys:{},brushes:[]}; else if(depth===1) brush={faces:[]}; depth++; }
  const km = lines[i].match(/^\s*"([^"]+)"\s+"([^"]*)"/);
  if(km && ent && depth===1) ent.keys[km[1]]=km[2];
  const fm = lines[i].match(FACE_RE);
  if(fm && brush) brush.faces.push([[+fm[1],+fm[2],+fm[3]],[+fm[4],+fm[5],+fm[6]],[+fm[7],+fm[8],+fm[9]]]);
  for(let c=0;c<closes;c++){ depth--;
    if(depth===1 && brush){ if(brush.faces.length===6){const b=boundsOf(brush.faces); if(b) ent.brushes.push(b);} brush=null; }
    else if(depth===0 && ent){
      if((ent.keys.script_noteworthy==='player_volume' || ent.keys.classname==='info_volume') && ent.brushes.length){
        let u=[Infinity,-Infinity,Infinity,-Infinity,Infinity,-Infinity];
        for(const b of ent.brushes) u=[Math.min(u[0],b[0]),Math.max(u[1],b[1]),Math.min(u[2],b[2]),Math.max(u[3],b[3]),Math.min(u[4],b[4]),Math.max(u[5],b[5])];
        zones.push({tn:ent.keys.targetname||'?', nw:ent.keys.script_noteworthy||'', cls:ent.keys.classname||'', b:u});
      }
      ent=null;
    }
  }
}
zones.sort((a,b)=>a.tn.localeCompare(b.tn));
for(const z of zones) console.log(`${z.tn.padEnd(26)} [${z.nw||z.cls}]  x[${z.b[0]},${z.b[1]}] y[${z.b[2]},${z.b[3]}] z[${z.b[4]},${z.b[5]}]`);
console.log(`\n${zones.length} volumes`);
