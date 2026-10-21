#!/usr/bin/env node
// bsv-script-lean #86 (lane wire-86, 2026-10-15): the ts-sdk column of the wire views.
//
// Reads corpus/wire/<format>.jsonl files named on the command line and writes one JSON line per row: the fields
// of the spec column (lean/Test/WireCheck.lean), from @bsv/sdk's own codecs at the pin (package.json; the source,
// bsv-blockchain/ts-stack at 4d0ea63c, packages/sdk/src/transaction/, the same bytes at edf6e03d [X]):
// Transaction.fromEF and toEF (Transaction.ts:370-420,1171-1213), MerklePath.fromBinary, toHex and computeRoot
// (MerklePath.ts:113-162,271-293,375-410), Beef.fromBinaryStrict, toBinary, toBinaryAtomic and isValid
// (Beef.ts:1002,1188,1210,1240-1308; the strict reader, "for untrusted or independently framed input", :1291-1297).
// `parse` is the reader's success, `valid` the SDK's own check (the MerklePath constructor's root check; Beef.isValid
// with txid-only entries allowed), `reencode` its writer on what it read. No network; the corpus is read only.
import { readFileSync } from 'node:fs'
import { Transaction, MerklePath, Beef } from '@bsv/sdk'

/**
 * @typedef {{ id: string, format: string, hex: string, subject?: string, bump_hex?: string }} Row
 * @typedef {Record<string, unknown>} Out
 */

/**
 * JSON.parse as `unknown` (its own type is `any`; the caller names the shape it reads)
 * @param {string} text
 * @returns {unknown}
 */
function parseJson (text) { return JSON.parse(text) }

/**
 * @param {string} hex
 * @returns {number[]}
 */
function bytes (hex) {
  /** @type {number[]} */
  const out = []
  for (let i = 0; i + 1 < hex.length; i += 2) out.push(parseInt(hex.slice(i, i + 2), 16))
  return out
}

/**
 * @param {number[]} bin
 * @returns {string}
 */
function hexOf (bin) {
  return bin.map(b => b.toString(16).padStart(2, '0')).join('')
}

/**
 * @param {() => unknown} f
 * @returns {unknown}
 */
function attempt (f) {
  try { return f() } catch { return null }
}

/**
 * @param {number[]} b
 * @returns {Out}
 */
function efFields (b) {
  /** @type {Transaction} */
  let tx
  try { tx = Transaction.fromEF(b) } catch { return { parse: false } }
  const spent = tx.inputs.map(i => {
    const o = i.sourceTransaction?.outputs[i.sourceOutputIndex]
    return o === undefined ? null : [o.satoshis ?? null, o.lockingScript.toHex()]
  })
  return { parse: true, valid: null, reencode: attempt(() => tx.toHexEF()), txid: tx.id('hex'), tx: tx.toHex(), spent }
}

/**
 * @param {MerklePath} mp
 * @returns {Out}
 */
function bumpObjects (mp) {
  const level0 = mp.path[0] ?? []
  const txids = level0.filter(l => l.txid === true && l.hash !== undefined)
    .map(l => ({ offset: l.offset, txid: l.hash, root: attempt(() => mp.computeRoot(l.hash)) }))
  return { height: mp.blockHeight, root: attempt(() => mp.computeRoot()), txids }
}

/**
 * @param {number[]} b
 * @returns {Out}
 */
function bumpFields (b) {
  /** @type {MerklePath} */
  let mp
  try { mp = MerklePath.fromBinary(b) } catch { return { parse: false } }
  return { ...bumpObjects(mp), parse: true, valid: true, reencode: mp.toHex() }
}

/**
 * @param {Beef} beef
 * @returns {Out}
 */
function beefObjects (beef) {
  const bumps = beef.bumps.map(x => ({ height: x.blockHeight, root: attempt(() => x.computeRoot()) }))
  const txs = beef.txs.map(t => {
    const kind = t.isTxidOnly ? 'txid' : (t.bumpIndex === undefined ? 'raw' : 'raw+bump')
    /** @type {unknown} */
    let mined = null
    if (t.bumpIndex !== undefined) {
      const x = beef.bumps[t.bumpIndex]
      const leaf = x?.path[0]?.find(l => l.hash === t.txid)
      mined = x === undefined || leaf === undefined
        ? 'unresolved'
        : { height: x.blockHeight, index: leaf.offset, root: attempt(() => x.computeRoot(t.txid)) }
    }
    return { txid: t.txid, kind, bump: t.bumpIndex ?? null, mined }
  })
  return { version: beef.version === 4022206465 ? 1 : 2, bumps, txs }
}

/**
 * @param {number[]} b
 * @param {boolean} atomic
 * @returns {Out}
 */
function beefFields (b, atomic) {
  /** @type {Beef} */
  let beef
  try { beef = Beef.fromBinaryStrict(b) } catch { return { parse: false } }
  if ((beef.atomicTxid !== undefined) !== atomic) return { parse: false }
  const out = { ...beefObjects(beef), parse: true, valid: attempt(() => beef.isValid(true)) }
  const subject = beef.atomicTxid
  if (subject !== undefined) {
    return { ...out, subject, reencode: attempt(() => hexOf(beef.toBinaryAtomic(subject))) }
  }
  return { ...out, reencode: attempt(() => hexOf(beef.toBinary())) }
}

/**
 * The TSC rows: no @bsv/sdk codec reads the TSC binary form; the SDK reads the BUMP WhatsOnChain serves for the
 * same transaction and computes the subject's root, which the comparison sets against the spec's.
 * @param {Row} row
 * @returns {Out}
 */
function tscFields (row) {
  const root = attempt(() => MerklePath.fromHex(row.bump_hex ?? '').computeRoot(row.subject))
  return { parse: null, read_bump_root: root }
}

/**
 * @param {Row} row
 * @returns {Out}
 */
function line (row) {
  const b = bytes(row.hex)
  /** @type {Record<string, () => Out>} */
  const by = {
    ef: () => efFields(b),
    bump: () => bumpFields(b),
    beef: () => beefFields(b, false),
    'atomic-beef': () => beefFields(b, true),
    tsc: () => tscFields(row)
  }
  const f = by[row.format]
  if (f === undefined) throw new Error(`${row.id}: unknown format ${row.format}`)
  return { id: row.id, format: row.format, impl: 'ts-sdk@3.0.0', ...f() }
}

const paths = process.argv.slice(2)
if (paths.length === 0) {
  process.stderr.write('usage: wire.mjs corpus/wire/<format>.jsonl ...\n')
  process.exit(2)
}
let rows = 0
for (const path of paths) {
  for (const text of readFileSync(path, 'utf8').split('\n')) {
    if (text.trim() === '') continue
    const row = /** @type {Row} */ (parseJson(text))
    process.stdout.write(JSON.stringify(line(row)) + '\n')
    rows++
  }
}
process.stderr.write(`wire.mjs: ${rows} rows (ts-sdk@3.0.0)\n`)
