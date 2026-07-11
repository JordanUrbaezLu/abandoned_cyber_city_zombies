const fs=require('fs'),zlib=require('zlib');
const p="C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/usermaps/zm_abandoned_cyber_city/zone/en_zm_abandoned_cyber_city.ff";
const buf=fs.readFileSync(p);
console.log("file size",buf.length,"header",buf.slice(0,8).toString('latin1'));
// scan for zlib streams (0x78 0x01/0x9C/0xDA) and inflate each
let chunks=[];
for(let i=0;i<buf.length-1;i++){
  if(buf[i]===0x78 && (buf[i+1]===0x01||buf[i+1]===0x9c||buf[i+1]===0xda)){
    try{
      const inf=zlib.inflateSync(buf.slice(i));
      if(inf.length>200){chunks.push({off:i,len:inf.length,data:inf});}
    }catch(e){
      // try inflateRaw or partial - ignore
    }
  }
}
let all=Buffer.concat(chunks.map(c=>c.data));
console.log("inflated bytes total",all.length,"streams",chunks.length);
const txt=all.toString('latin1');
function count(s){let n=0,idx=0;while((idx=txt.indexOf(s,idx))!==-1){n++;idx+=s.length;}return n;}
for(const k of ["ZM_AETHERIUM_ZM_AETHERIUM_","ZM_AETHERIUM_KF_MELEE","ZM_AETHERIUM_KF_CRITICAL","Melee Kill","Critical Kill","Elimination","Ragnarok Kill","KF_MELEE"]){
  console.log(JSON.stringify(k),"=>",count(k));
}
// show context around first Melee Kill
let mi=txt.indexOf("Melee Kill");
if(mi>=0){console.log("--- ctx Melee Kill ---");console.log(JSON.stringify(txt.slice(mi-60,mi+20)));}
let ki=txt.indexOf("ZM_AETHERIUM_KF_MELEE");
if(ki>=0){console.log("--- ctx key ---");console.log(JSON.stringify(txt.slice(ki-10,ki+80)));}
