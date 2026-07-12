# hksc.exe — HavokScript (T7) Lua compiler

Compiles Lua **source** (that may freely name `io`/`os`/`EnableGlobals` — no
whitelist) into **T7 HavokScript bytecode** (header `1b 4c 75 61 51 0e …`,
byte-identical to the shipped map MACHIN[A]). We need this because L3akMod's
rawfile compiler blocks `io`/`os` in source AND chokes on bytecode rawfiles, so
the leaderboard ships its io/os logic as **bytecode embedded in a source string**
and `load(reader)`s it at runtime (docs/40 "✅ THE WORKING RECIPE").

- **Source:** https://github.com/Jake-NotTheMuss/hksc (built 2026-07-11).
- **Build (if you need to rebuild):** portable w64devkit (MinGW-w64) →
  `sh ./configure --game=t7 && make` → `src/hksc.exe`. This binary is 64-bit
  **static** (no libhksc.dll needed); `--game=t7` is baked in at configure time.
- **Compile a chunk:** `hksc.exe -s -o out.luac in.lua` (`-s` strips debug).
- **Do NOT pass `--game=t7` at runtime** — it's a configure-time option; the
  binary is already a t7 compiler.

Used by `tools/build_lui_bytecode.js`.
