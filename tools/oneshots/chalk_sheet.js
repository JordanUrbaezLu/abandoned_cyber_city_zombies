// Build a contact sheet of every gun's chalk icon so we can audit color/quality at a glance.
const fs = require("fs"), zlib = require("zlib"), path = require("path"), cp = require("child_process");
const TOOLS = process.env.TA_TOOLS_PATH || "C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130";
const SRC = path.join(TOOLS, "source_data");
const ME = path.join(TOOLS, "model_export");

// gun -> chalk image name (from AetheriumWeapons.lua). The 4 missing guns get their best candidate.
const GUNS = [
  ["Tac-19", "i_uts_19_wall_chalk_c"],
  ["Five-Seven(B23R)", "i_t6_wpn_pistol_b2023r_wall_chalk_c"],
  ["Blast-O-Matic", "i_semiauto_cosplay_chaulk_new_c"],
  ["AK-47", "i_weapon_vm_ar_t9damage_wall_chalk_c"],
  ["AE4", "i_dear_wall_chalk_c"],
  ["PPSH-41", "i_ppapa41_wall_chalk_c"],
  ["AK-74u", "i_weapon_vm_sm_t9heavy_wall_chalk_c"],
  ["Paladin", "i_t8_wpn_sniper_paladin_hb50_wall_chalk_c"],
  ["Olympia", "i_t6_wpn_shotty_olympia_wall_chalk_c"],
  ["Grav", "i_wpn_vm_ar_t9season6_wall_chalk_c"],
  ["MK14(M14)", "i_t6_wpn_ar_m14_wall_chalk_c"],
  ["MORS(SDM)", "i_t8_wpn_sniper_sdm_wall_chalk_c"],
  ["M60", "i_weapon_vm_lm_t9slowfire_wall_chalk_c"],
  ["RPD", "i_weapon_vm_lm_t9rpapa_wall_chalk_c"],
  ["RW1(RK7)", "i_t8_wpn_pistol_rk7_garrison_wall_chalk_c"],
  ["Thundergun", "i_wpn_t5_asl_thundergun_wall_chalk_c"],
  // MISSING from mapping - candidate chalks (found earlier by scanning each gun's GDT):
  ["XM4", "i_weapon_vm_ar_t9standard_wall_chalk_c"],
  ["Streetsweeper", "i_weapon_vm_sh_t9fullauto_wall_chalk_c"],
  ["ChicomCQB", "i_t6_wpn_smg_chicom_wall_chalk_c"],
  ["Klauser(Kard?)", "i_t6_wpn_pistol_kard_wall_chalk_c"],
];

// find the baseImage for an image asset name by scanning GDTs (recursive)
function walk(dir){ let out=[]; for(const e of fs.readdirSync(dir,{withFileTypes:true})){ const p=path.join(dir,e.name); if(e.isDirectory())out=out.concat(walk(p)); else if(e.name.endsWith(".gdt"))out.push(p); } return out; }
const gdtPaths = walk(SRC);
const CACHE = {}; for(const p of gdtPaths) CACHE[p]=fs.readFileSync(p,"utf8");
const gdts = gdtPaths;
function findBaseImage(imgName) {
  const needle = `"${imgName}" ( "image.gdf"`;
  for (const f of gdts) {
    const t = CACHE[f]; const i = t.indexOf(needle);
    if (i < 0) continue;
    const seg = t.slice(i, i + 1200);
    const m = seg.match(/"baseImage"\s+"([^"]+)"/);
    if (m) return m[1].replace(/\\\\/g, "/").replace(/\\/g, "/");
  }
  return null;
}
// decode PNG (8-bit) -> RGBA
function readPNG(buf){
  let pos=8,w,h,bd,ct,idat=[];
  while(pos<buf.length){ const len=buf.readUInt32BE(pos); const type=buf.toString("ascii",pos+4,pos+8); const d=buf.slice(pos+8,pos+8+len);
    if(type==="IHDR"){w=d.readUInt32BE(0);h=d.readUInt32BE(4);bd=d[8];ct=d[9];} else if(type==="IDAT")idat.push(d); else if(type==="IEND")break; pos+=12+len; }
  const raw=zlib.inflateSync(Buffer.concat(idat));
  const ch=ct===6?4:ct===2?3:ct===0?1:ct===4?2:4, bpp=ch*(bd/8), stride=w*bpp, px=Buffer.alloc(w*h*4); let prev=Buffer.alloc(stride);
  for(let y=0;y<h;y++){ const f=raw[y*(stride+1)]; const line=raw.slice(y*(stride+1)+1,y*(stride+1)+1+stride); const cur=Buffer.alloc(stride);
    for(let x=0;x<stride;x++){ const a=x>=bpp?cur[x-bpp]:0,b=prev[x],c=x>=bpp?prev[x-bpp]:0; let v=line[x];
      if(f===1)v=(v+a)&255; else if(f===2)v=(v+b)&255; else if(f===3)v=(v+((a+b)>>1))&255;
      else if(f===4){const p=a+b-c,pa=Math.abs(p-a),pb=Math.abs(p-b),pc=Math.abs(p-c);v=(v+(pa<=pb&&pa<=pc?a:pb<=pc?b:c))&255;} cur[x]=v; }
    for(let x=0;x<w;x++){ const o=(y*w+x)*4,s=x*bpp; if(ch>=3){px[o]=cur[s];px[o+1]=cur[s+1];px[o+2]=cur[s+2];px[o+3]=ch===4?cur[s+3]:255;} else {px[o]=px[o+1]=px[o+2]=cur[s];px[o+3]=ch===2?cur[s+1]:255;} }
    prev=cur; }
  return {W:w,H:h,px,spp:ch};
}
function loadImage(file){ const buf=fs.readFileSync(file); if(buf[0]===137&&buf[1]===80&&buf[2]===78&&buf[3]===71) return readPNG(buf); return readTiff(file); }
// list every *wall_chalk*_c image in a given gdt (for the missing guns)
function chalksInGdt(gdtName) {
  const t = CACHE[gdtName]; if (!t) return [];
  return [...t.matchAll(/"(i_[a-z0-9_]*wall_chalk_c)" \( "image\.gdf"/g)].map(m => m[1]);
}
// resolve the missing-gun candidates from their skye gdts
function resolveMissing() {
  const map = {
    "XM4?": chalksInGdt("skye_t9_xm4.gdt"),
    "Streetsweeper?": chalksInGdt("skye_t9_streetsweeper.gdt"),
    "ChicomCQB?": chalksInGdt("skye_t6_chicom_cqb.gdt"),
    "Klauser?": chalksInGdt("skye_s4_klauser.gdt"),
  };
  return map;
}
const missing = resolveMissing();
console.log("MISSING-gun chalk candidates:");
for (const k of Object.keys(missing)) console.log(`  ${k}: ${missing[k].join(", ") || "(none found)"}`);
// patch the GUNS list with resolved candidates
for (const row of GUNS) {
  if (missing[row[0]]) row[1] = missing[row[0]][0] || null;
  if (row[1] && row[1].endsWith("_XM4CANDIDATE")) row[1] = (chalksInGdt("skye_t9_xm4.gdt")[0] || null);
}
// Klauser has no chalk in its GDT -> evaluate a pistol lookalike (Kard)
{ const kl = GUNS.find(r => r[0] === "Klauser?"); if (kl && !kl[1]) kl[1] = "i_t6_wpn_pistol_kard_wall_chalk_c"; }

// --- TIFF (uncompressed 8-bit chunky RGBA/RGB) -> RGBA pixel buffer ---
function readTiff(file) {
  const buf = fs.readFileSync(file);
  const le = buf.toString("ascii", 0, 2) === "II";
  const u16 = o => le ? buf.readUInt16LE(o) : buf.readUInt16BE(o);
  const u32 = o => le ? buf.readUInt32LE(o) : buf.readUInt32BE(o);
  const ifd = u32(4), nE = u16(ifd), tags = {}, tsz = { 1:1,3:2,4:4 };
  for (let i=0;i<nE;i++){ const e=ifd+2+i*12, tag=u16(e), type=u16(e+2), count=u32(e+4); const ts=tsz[type]||1, total=ts*count;
    const base = total<=4 ? e+8 : u32(e+8); const vals=[];
    for(let k=0;k<count;k++){ vals.push(type===3?u16(base+k*2):type===4?u32(base+k*4):buf[base+k]); } tags[tag]=vals; }
  const W=tags[256][0], H=tags[257][0], spp=(tags[277]||[3])[0], comp=(tags[259]||[1])[0], planar=(tags[284]||[1])[0];
  const so=tags[273], sc=tags[279], rps=(tags[278]||[H])[0], predictor=(tags[317]||[1])[0];
  if (planar!==1 || (comp!==1 && comp!==5)) return { W, H, px:null, comp, spp };
  // gather raw (uncompressed) or LZW-decoded bytes per strip
  function lzw(data){ const out=[]; let acc=0,nb=0,p=0; const CLEAR=256,EOI=257; let dict,ds,cw,prev;
    const reset=()=>{ dict=[]; for(let i=0;i<256;i++)dict[i]=[i]; ds=258; cw=9; prev=null; };
    reset();
    const rd=()=>{ while(nb<cw){ if(p>=data.length)return EOI; acc=(acc<<8)|data[p++]; nb+=8; } nb-=cw; return (acc>>nb)&((1<<cw)-1); };
    let code;
    while((code=rd())!==EOI){
      if(code===CLEAR){ reset(); code=rd(); if(code===EOI)break; for(const b of dict[code])out.push(b); prev=code; continue; }
      let entry = dict[code] ? dict[code] : dict[prev].concat(dict[prev][0]);
      for(const b of entry) out.push(b);
      if(prev!==null) dict[ds++]=dict[prev].concat(entry[0]);
      prev=code;
      if(ds+1 >= (1<<cw) && cw<12) cw++;
    }
    return Buffer.from(out);
  }
  const spb = spp*W; // sample bytes per row
  const px=Buffer.alloc(W*H*4); let row=0;
  for (let s=0;s<so.length;s++){ const rows=Math.min(rps,H-row); let strip;
    if(comp===1){ strip=buf.slice(so[s], so[s]+ (sc?sc[s]:rows*spb)); }
    else { strip=lzw(buf.slice(so[s], so[s]+sc[s])); }
    let sp=0;
    for(let r=0;r<rows;r++){
      // horizontal differencing predictor
      if(predictor===2){ for(let x=1;x<W;x++){ for(let c=0;c<spp;c++){ strip[sp+x*spp+c]=(strip[sp+x*spp+c]+strip[sp+(x-1)*spp+c])&255; } } }
      for(let x=0;x<W;x++){ const o=sp+x*spp; const R=strip[o],G=strip[o+1],B=strip[o+2]; let A=255; if(spp>=4)A=strip[o+3];
        const di=((row+r)*W+x)*4; px[di]=R;px[di+1]=G;px[di+2]=B;px[di+3]=A; }
      sp+=spb;
    }
    row+=rows;
  }
  return { W, H, px, comp, spp };
}

// --- compose contact sheet ---
const COLS=4, CW=200, CH=110, PAD=6;
const rowsN=Math.ceil(GUNS.length/COLS);
const SW=COLS*(CW+PAD)+PAD, SH=rowsN*(CH+PAD)+PAD;
const sheet=Buffer.alloc(SW*SH*3, 40); // dark-gray canvas
function setpx(x,y,r,g,b){ if(x<0||y<0||x>=SW||y>=SH)return; const o=(y*SW+x)*3; sheet[o]=r;sheet[o+1]=g;sheet[o+2]=b; }
GUNS.forEach((row,idx)=>{
  const [name,img]=row; const cx=PAD+(idx%COLS)*(CW+PAD), cy=PAD+Math.floor(idx/COLS)*(CH+PAD);
  // cell bg checkerboard-ish mid-gray so white & dark art both show
  for(let y=0;y<CH;y++)for(let x=0;x<CW;x++){ const c=((x>>4)+(y>>4))&1?150:120; setpx(cx+x,cy+y,c,c,c); }
  let info="(no image)";
  if(img){ const tif=findBaseImage(img); if(tif){ const full=path.isAbsolute(tif)?tif:path.join(TOOLS,tif);
    try{ const _r=loadImage(full); const {W,H,px,spp}=_r; const comp=_r.comp;
      if(!px){ info=`comp=${comp}`; }
      else{
        // outline color = avg RGB of the OPAQUE (a>128) pixels = the chalk line color
        let or_=0,og=0,ob=0,on=0;
        for(let i=0;i<W*H;i++){ const o=i*4; if(px[o+3]>128){ or_+=px[o];og+=px[o+1];ob+=px[o+2];on++; } }
        const R=on?Math.round(or_/on):0,G=on?Math.round(og/on):0,B=on?Math.round(ob/on):0;
        const tag = (R>200&&G>200&&B>200)?"WHITE" : (B>R+15&&B>G+10)?"**BLUISH**" : (R<120&&G<120&&B<120)?"DARK" : "other";
        info=`spp=${spp} line=(${R},${G},${B}) ${tag}`;
        for(let y=0;y<CH;y++)for(let x=0;x<CW;x++){ const sx=Math.min(W-1,Math.floor(x*W/CW)), sy=Math.min(H-1,Math.floor(y*H/CH));
          const o=(sy*W+sx)*4, a=px[o+3]/255, bg=((x>>4)+(y>>4))&1?150:120;
          setpx(cx+x,cy+y, Math.round(px[o]*a+bg*(1-a)), Math.round(px[o+1]*a+bg*(1-a)), Math.round(px[o+2]*a+bg*(1-a))); }
      }
    }catch(e){ info="ERR "+e.message.slice(0,20); } } else info="NO GDT"; }
  console.log(`cell ${idx} [${idx%COLS},${Math.floor(idx/COLS)}] ${name} <- ${img||"?"} : ${info}`);
});
function chunk(type,data){ const l=Buffer.alloc(4);l.writeUInt32BE(data.length); const t=Buffer.from(type); const c=Buffer.alloc(4);c.writeUInt32BE(crc32(Buffer.concat([t,data]))>>>0); return Buffer.concat([l,t,data,c]); }
function crc32(b){let c=~0;for(let i=0;i<b.length;i++){c^=b[i];for(let k=0;k<8;k++)c=(c>>>1)^(0xEDB88320&-(c&1));}return ~c;}
const lines=[]; for(let y=0;y<SH;y++){ const ln=Buffer.alloc(1+SW*3); ln[0]=0; sheet.copy(ln,1,y*SW*3,(y+1)*SW*3); lines.push(ln); }
const ihdr=Buffer.alloc(13); ihdr.writeUInt32BE(SW,0);ihdr.writeUInt32BE(SH,4);ihdr[8]=8;ihdr[9]=2;
const png=Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk("IHDR",ihdr),chunk("IDAT",zlib.deflateSync(Buffer.concat(lines))),chunk("IEND",Buffer.alloc(0))]);
const out=path.join(process.argv[2]||".","chalk_sheet.png"); fs.writeFileSync(out,png);
console.log("wrote "+out+` (${SW}x${SH})`);
