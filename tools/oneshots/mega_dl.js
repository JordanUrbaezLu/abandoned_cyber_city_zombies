// Download a MEGA file link to a local path using megajs.
// Usage: node mega_dl.js <mega-url> <out-path>
const { File } = require('megajs')
const fs = require('fs')

const [url, out] = process.argv.slice(2)
if (!url || !out) { console.error('usage: node mega_dl.js <url> <out>'); process.exit(2) }

async function main() {
  const file = File.fromURL(url)
  await file.loadAttributes()
  console.log('name:', file.name, 'size:', file.size)
  const ws = fs.createWriteStream(out)
  const rs = file.download()
  rs.pipe(ws)
  await new Promise((res, rej) => { ws.on('finish', res); rs.on('error', rej); ws.on('error', rej) })
  console.log('DONE', out, fs.statSync(out).size)
}
main().catch(e => { console.error('FAIL:', e.message); process.exit(1) })
