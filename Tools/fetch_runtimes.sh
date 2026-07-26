#!/usr/bin/env bash
#
# Downloads the WebAssembly language runtimes that ship inside the app.
#
# They are fetched at build time rather than committed, because they are tens
# of megabytes of third-party binaries. Everything ends up in
# CodeForge/Resources/Runtimes/, which the Xcode project copies into the bundle
# as a folder, so the app runs them completely offline afterwards.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/CodeForge/Resources/Runtimes"

PYODIDE_VERSION="${PYODIDE_VERSION:-0.26.4}"
FENGARI_VERSION="${FENGARI_VERSION:-0.1.4}"
SQLJS_VERSION="${SQLJS_VERSION:-1.11.0}"

mkdir -p "$DEST"

log() { printf '==> %s\n' "$*"; }

fetch() {
  local url="$1" out="$2"
  log "fetch $(basename "$out")"
  curl -fsSL --retry 3 --retry-delay 2 -o "$out" "$url"
}

# ---- Python (Pyodide: CPython built for WebAssembly) ------------------------
if [ ! -f "$DEST/pyodide/pyodide.js" ]; then
  TMP="$(mktemp -d)"
  ARCHIVE="$TMP/pyodide-core.tar.bz2"
  fetch "https://github.com/pyodide/pyodide/releases/download/${PYODIDE_VERSION}/pyodide-core-${PYODIDE_VERSION}.tar.bz2" "$ARCHIVE"
  log "unpack pyodide ${PYODIDE_VERSION}"
  tar -xjf "$ARCHIVE" -C "$TMP"
  rm -rf "$DEST/pyodide"
  mv "$TMP/pyodide" "$DEST/pyodide"
  # Source maps, type definitions and the ES-module entry point are dead weight
  # inside an app bundle — the runtime page loads the classic pyodide.js.
  find "$DEST/pyodide" \
    \( -name '*.map' -o -name '*.ts' -o -name 'console.html' \
       -o -name 'pyodide.mjs' -o -name 'package.json' -o -name 'README.md' \) -delete
  rm -rf "$TMP"
else
  log "pyodide already present"
fi

# ---- Lua (Fengari: a Lua VM in JavaScript) ----------------------------------
mkdir -p "$DEST/fengari"
if [ ! -f "$DEST/fengari/fengari-web.js" ]; then
  fetch "https://unpkg.com/fengari-web@${FENGARI_VERSION}/dist/fengari-web.js" \
        "$DEST/fengari/fengari-web.js"
else
  log "fengari already present"
fi

# ---- SQLite (sql.js) ---------------------------------------------------------
mkdir -p "$DEST/sqljs"
if [ ! -f "$DEST/sqljs/sql-wasm.js" ]; then
  fetch "https://cdn.jsdelivr.net/npm/sql.js@${SQLJS_VERSION}/dist/sql-wasm.js" \
        "$DEST/sqljs/sql-wasm.js"
  fetch "https://cdn.jsdelivr.net/npm/sql.js@${SQLJS_VERSION}/dist/sql-wasm.wasm" \
        "$DEST/sqljs/sql-wasm.wasm"
else
  log "sql.js already present"
fi

cat > "$DEST/manifest.json" <<JSON
{
  "pyodide": "${PYODIDE_VERSION}",
  "fengari": "${FENGARI_VERSION}",
  "sqljs": "${SQLJS_VERSION}",
  "fetched": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
JSON

# ---- sanity check -------------------------------------------------------------
missing=0
for required in \
  "pyodide/pyodide.js" \
  "pyodide/pyodide.asm.wasm" \
  "pyodide/python_stdlib.zip" \
  "fengari/fengari-web.js" \
  "sqljs/sql-wasm.js" \
  "sqljs/sql-wasm.wasm" \
  "pages/python.html" \
  "pages/lua.html" \
  "pages/sql.html"
do
  if [ ! -s "$DEST/$required" ]; then
    echo "missing runtime file: $required" >&2
    missing=1
  fi
done
[ "$missing" -eq 0 ] || exit 1

log "runtimes ready ($(du -sh "$DEST" | cut -f1))"
