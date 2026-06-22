#!/usr/bin/env node
// list_walls.js - list worldspawn script_wall box brushes with footprint + height,
// classifying THIN WALLS (one horizontal dim <= 40u = a real wall) vs BLOCKY/SHORT
// structures (freestanding obstacles). Optional near-point filter.
// Usage: node tools/list_walls.js <map> [cx cy radius]
const fs = require('fs');
const [, , inPath, cxS, cyS, radS] = process.argv;
const cx = cxS !== undefined ? +cxS : null, cy = cyS !== undefined ? +cyS : null, rad = radS !== undefined ? +radS : null;
const N = '(-?[\\d.]+)';
const FACE_RE = new RegExp('^\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s+(\\S+)');
function bounds(f){if(f.length!==6)return null;const A=[[],[],[]];for(const[p1,p2,p3]of f){const u=[p2[0]-p1[0],p2[1]-p1[1],p2[2]-p1[2]],v=[p3[0]-p1[0],p3[1]-p1[1],p3[2]-p1[2]];const n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]];const a=n.map(Math.abs),mx=Math.max(...a);if(mx<1e-6)return null;const ax=a.indexOf(mx);if(a[(ax+1)%3]+a[(ax+2)%3]>mx*1e-4)return null;A[ax].push(p1[ax]);}if(A.some(g=>g.length!==2))return null;return[Math.min(...A[0]),Math.max(...A[0]),Math.min(...A[1]),Math.max(...A[1]),Math.min(...A[2]),Math.max(...A[2])];}
const lines=fs.readFileSync(inPath,'utf8').split('\n');
const st=[];let depth=0,ent=-1;const rows=[];
for(let i=0;i<lines.length;i++){const o=(lines[i].match(/{/g)||[]).length,c=(lines[i].match(/}/g)||[]).length;if(depth===0&&o>0)ent++;for(let k=0;k<o;k++)st.push({faces:[],mat:null,ent});const m=lines[i].match(FACE_RE);if(m&&st.length){const t=st[st.length-1];t.faces.push([[+m[1],+m[2],+m[3]],[+m[4],+m[5],+m[6]],[+m[7],+m[8],+m[9]]]);if(!t.mat)t.mat=m[10];}depth+=o-c;for(let k=0;k<c;k++){const b=st.pop();if(!b||b.ent!==0||b.mat!==(process.env.MAT||'script_wall')||b.faces.length!==6)continue;const bd=bounds(b.faces);if(!bd)continue;const dx=bd[1]-bd[0],dy=bd[3]-bd[2],dz=bd[5]-bd[4];const mcx=(bd[0]+bd[1])/2,mcy=(bd[2]+bd[3])/2;if(cx!==null&&Math.hypot(mcx-cx,mcy-cy)>rad)continue;const thin=Math.min(dx,dy)<=40;rows.push({bd,dx,dy,dz,thin,mcx,mcy});}}
rows.sort((a,b)=>(a.thin===b.thin)?0:(a.thin?1:-1));
console.log(`worldspawn script_wall brushes${cx!==null?` within ${rad}u of (${cx},${cy})`:''}: ${rows.length}`);
const r=v=>Math.round(v);
for(const x of rows){console.log(`  ${x.thin?'WALL    ':'OBSTACLE'}  ${r(x.dx)}x${r(x.dy)} foot, h=${r(x.dz)}  center(${r(x.mcx)},${r(x.mcy)})  x[${r(x.bd[0])},${r(x.bd[1])}] y[${r(x.bd[2])},${r(x.bd[3])}] z[${r(x.bd[4])},${r(x.bd[5])}]`);}
console.log(`\nTHIN walls (keep): ${rows.filter(x=>x.thin).length}   BLOCKY/obstacles (candidate remove): ${rows.filter(x=>!x.thin).length}`);
