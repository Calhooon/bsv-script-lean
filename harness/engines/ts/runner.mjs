#!/usr/bin/env node
// bsv-script-lean #29: the ts-sdk adapter (this repo's; docs/DESIGN.md §7, docs/PROVENANCE.md §1).
//
// One process, JSON lines: a request per corpus entry on stdin, a response per request on stdout.
// @bsv/sdk is pinned exactly in package.json (docs/PROVENANCE.md §1a `ts-sdk.version`); the source it
// was published from is bsv-blockchain/ts-stack at `ts-sdk.commit`, packages/sdk/src/script/Spend.ts.
//
// Two modes per run (the harness asks for each):
//   "flags":   `verifyFlags` = the names of the reference's flag word (script_flags.h at the pin), bit by
//              bit; Spend consults UTXO_AFTER_GENESIS, UTXO_AFTER_CHRONICLE, CHRONICLE, MINIMALDATA, LOW_S,
//              NULLDUMMY, SIGPUSHONLY, CLEANSTACK, DERSIG, STRICTENC, SIGHASH_FORKID,
//              DISCOURAGE_UPGRADABLE_NOPS, CHECKLOCKTIMEVERIFY, CHECKSEQUENCEVERIFY, MINIMALIF, NULLFAIL,
//              P2SH (Spend.ts:323–345 and the sites; the 17 names `#hasFlag` reads at 2.8.10 and 3.0.0) and no
//              other: the GENESIS and COMPRESSED_PUBKEYTYPE bits are passed by name and never consulted
//              (reported as `unconsulted`; at 2.8.0 GENESIS was read and CHECKLOCKTIMEVERIFY and CHRONICLE
//              were not, 2.8.8 moved all three). With explicit flags the SDK's own version-relaxation
//              (`#isRelaxed`, Spend.ts:319–321) is bypassed: since 2.8.8 the seven gated restrictions follow
//              the word under the reference's version gate (`#enforceNonMalleability`, Spend.ts:343–345: the
//              CHRONICLE bit and a version above 1, as interpreter.cpp:40–44).
//   "default": no `verifyFlags`: the SDK's own derivation from the transaction version
//              (`#isRelaxed()` = version > 1; `#isAfterGenesis()`/`#isAfterChronicle()` = isRelaxed when
//              no flags are given, Spend.ts:331–341): what an application gets out of the box.
// Every input is run in order through `new Spend({...}).validate()`; the transaction's verdict is the
// first non-valid input's (DESIGN §6, Q5). The SDK's error message is returned verbatim
// (ScriptEvaluationError; no error enum exists); the harness maps it to the reference's SCRIPT_ERR_*
// through its cited table (harness/src/tssdk_codes.rs). A throw that is not a ScriptEvaluationError,
// or a transaction the SDK cannot parse, is `undecided`.
//
// The codes of an `undecided` run say WHOSE it is (the owner's ruling R3 on #32, 2026-10-05):
//   "tx-decode": the SDK's own decoder refused the transaction (`Transaction.fromHex` threw; @bsv/sdk 3.0.0
//                Transaction.ts:548–553, an output amount read by `readUInt64LEBn().toNumber()` at 497, which throws
//                above 2^53 at BigNumber.ts:625–629). The engine's refusal, never the adapter's: when the spec decides
//                the entry the harness files it as an engine abort under D15 (harness/src/gosdk_codes.rs,
//                DECODE_REFUSALS), the engine's script status undecided. It says nothing of the transaction's validity.
//   "adapter":   the adapter's own failure: a request whose `tx` is not a hex string, a prevout or flag-word count that
//                does not match the decoded transaction. An undecided run, never a witness.
//   any other:   the constructor name of a throw from the SDK's engine (`Spend.validate`), an abort under D15 that is a
//                witness only where a row of harness/rules/ts-sdk.json names its mechanism (at this tree the BigInt-size
//                RangeError and the ScriptResourceLimitError; the table has no catch-all exception class); a throw no row
//                names reaches the table's STOP row: unexplained, the run RED (#32 A-N2).
//
// Request:  {"id":..,"tx":"<hex>","prevouts":[{"txid":"<display hex>","vout":N,"script":"<hex>","satoshis":N},..],
//            "runs":[{"key":"block","mode":"flags","flags":[w,..]},{"key":"default","mode":"default"},..]}
// Response: {"id":..,"runs":{"block":{"verdict":"valid|invalid|undecided","input":i,"code":"ScriptEvaluationError","message":"..","engine_flags":[["P2SH",..],..],"unconsulted":[..]},..}}
import { createInterface } from 'node:readline'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'
import { Transaction, Spend, LockingScript } from '@bsv/sdk'

// The shapes above as types (#136, 2026-10-14: the tslint leg checks this file under strict tsc with checkJs; the
// annotations are comments and change nothing the runner does).
/**
 * @typedef {{ txid: string, vout: number, script: string, satoshis: number }} Prevout
 * @typedef {{ key: string, mode: string, flags?: number[] }} Run
 * @typedef {{ id: unknown, tx: unknown, prevouts: Prevout[], runs: Run[] }} Request
 * @typedef {{ verdict: string, input?: number, code?: string, message?: string, engine_flags?: (string[] | null)[], unconsulted?: string[] }} RunResult
 * @typedef {ConstructorParameters<typeof Spend>[0]} SpendParams
 */

/**
 * JSON.parse as `unknown` (its own type is `any`; the callers name the shape they read)
 * @param {string} text
 * @returns {unknown}
 */
function parseJson (text) { return JSON.parse(text) }

// the installed package's own version (its `exports` map hides package.json from import resolution)
const SDK_VERSION = /** @type {{ version: string }} */ (parseJson(readFileSync(join(dirname(fileURLToPath(import.meta.url)), 'node_modules', '@bsv', 'sdk', 'package.json'), 'utf8'))).version

// bitcoin-sv v1.2.2 src/script/script_flags.h:13–115 → the names Spend.ts reads (2.8.10; 3.0.0 ships Spend.ts byte-identical, its source map sha256 f4337015…)
/** @type {ReadonlyArray<readonly [number, string, boolean]>} */
const BITS = [
  [0, 'P2SH', true], [1, 'STRICTENC', true], [2, 'DERSIG', true], [3, 'LOW_S', true], [4, 'NULLDUMMY', true],
  [5, 'SIGPUSHONLY', true], [6, 'MINIMALDATA', true], [7, 'DISCOURAGE_UPGRADABLE_NOPS', true], [8, 'CLEANSTACK', true],
  [9, 'CHECKLOCKTIMEVERIFY', true], [10, 'CHECKSEQUENCEVERIFY', true], [13, 'MINIMALIF', true], [14, 'NULLFAIL', true],
  [15, 'COMPRESSED_PUBKEYTYPE', false], [16, 'SIGHASH_FORKID', true], [18, 'GENESIS', false],
  [19, 'UTXO_AFTER_GENESIS', true], [20, 'CHRONICLE', true], [21, 'UTXO_AFTER_CHRONICLE', true]
]

/** @param {number} word */
function namesOf (word) {
  /** @type {string[]} */
  const names = []
  /** @type {string[]} */
  const unconsulted = []
  let known = 0
  for (const [bit, name, consulted] of BITS) {
    known |= (1 << bit)
    if ((word & (1 << bit)) === 0) continue
    names.push(name)
    if (!consulted) unconsulted.push(name)
  }
  const rest = (word & ~known) >>> 0
  if (rest !== 0) unconsulted.push(`0x${rest.toString(16)} (no such reference bit)`)
  return { names, unconsulted }
}

/**
 * @param {Transaction} tx
 * @param {number} i
 * @param {Prevout} prev
 * @param {string} mode
 * @param {string[] | undefined} names
 * @returns {RunResult}
 */
function runInput (tx, i, prev, mode, names) {
  // i < tx.inputs.length (the caller's loop); a decoded input always carries its source txid, its unlocking script and
  // its sequence (Transaction.fromHex sets all three)
  const input = /** @type {import('@bsv/sdk').TransactionInput} */ (tx.inputs[i])
  /** @type {SpendParams} */
  const params = {
    sourceTXID: /** @type {string} */ (input.sourceTXID),
    sourceOutputIndex: input.sourceOutputIndex,
    sourceSatoshis: prev.satoshis,
    lockingScript: LockingScript.fromHex(prev.script),
    transactionVersion: tx.version,
    otherInputs: tx.inputs.filter((_, j) => j !== i),
    allInputs: tx.inputs,
    outputs: tx.outputs,
    unlockingScript: /** @type {import('@bsv/sdk').UnlockingScript} */ (input.unlockingScript),
    inputSequence: /** @type {number} */ (input.sequence),
    inputIndex: i,
    lockTime: tx.lockTime
  }
  if (mode === 'flags' && names !== undefined) params.verifyFlags = names
  try {
    const ok = new Spend(params).validate()
    return ok ? { verdict: 'valid' } : { verdict: 'invalid', input: i, code: 'validate-false', message: 'validate() returned false' }
  } catch (e) {
    const name = e && e.constructor ? e.constructor.name : typeof e
    const m = /** @type {{ message?: unknown } | null | undefined} */ (e)
    // the SDK's message verbatim, whatever its type (the harness maps the text, harness/src/tssdk_codes.rs)
    // eslint-disable-next-line @typescript-eslint/no-base-to-string -- String() of the thrown message is the runner's contract
    const message = m && m.message !== undefined ? String(m.message) : String(e)
    if (name === 'ScriptEvaluationError') return { verdict: 'invalid', input: i, code: name, message }
    return { verdict: 'undecided', input: i, code: name, message }
  }
}

/**
 * @param {Request} req
 * @returns {{ id: unknown, runs: Record<string, RunResult> }}
 */
function handle (req) {
  /** @type {{ id: unknown, runs: Record<string, RunResult> }} */
  const resp = { id: req.id, runs: {} }
  for (const r of req.runs) {
    // the request's own shape first: a `tx` that is not a hex string is the adapter's failure, never the SDK's refusal
    if (typeof req.tx !== 'string' || !/^(?:[0-9a-fA-F]{2})*$/.test(req.tx)) {
      resp.runs[r.key] = { verdict: 'undecided', code: 'adapter', message: 'the request\'s tx is not a hex string' }
      continue
    }
    let tx
    try {
      tx = Transaction.fromHex(req.tx)
    } catch (e) {
      const m = /** @type {{ message?: unknown } | null | undefined} */ (e)
      resp.runs[r.key] = { verdict: 'undecided', code: 'tx-decode', message: String(m && m.message !== undefined ? m.message : e) }
      continue
    }
    if (tx.inputs.length !== req.prevouts.length) {
      resp.runs[r.key] = { verdict: 'undecided', code: 'adapter', message: `${tx.inputs.length} inputs but ${req.prevouts.length} prevouts` }
      continue
    }
    if (r.mode === 'flags' && (!Array.isArray(r.flags) || r.flags.length !== tx.inputs.length)) {
      resp.runs[r.key] = { verdict: 'undecided', code: 'adapter', message: `${tx.inputs.length} inputs but ${(r.flags || []).length} flag words` }
      continue
    }
    /** @type {(string[] | null)[]} */
    const engineFlags = []
    /** @type {Set<string>} */
    const unconsulted = new Set()
    /** @type {RunResult} */
    let result = { verdict: 'valid' }
    for (let i = 0; i < tx.inputs.length; i++) {
      let names
      if (r.mode === 'flags') {
        // r.flags is an array of tx.inputs.length words (checked above)
        const m = namesOf(/** @type {number} */ (/** @type {number[]} */ (r.flags)[i]) >>> 0)
        names = m.names
        engineFlags.push(names)
        for (const u of m.unconsulted) unconsulted.add(u)
      } else {
        engineFlags.push(null)
      }
      const v = runInput(tx, i, /** @type {Prevout} */ (req.prevouts[i]), r.mode, names)
      if (v.verdict !== 'valid') { result = v; break }
    }
    result.engine_flags = engineFlags
    if (unconsulted.size > 0) result.unconsulted = Array.from(unconsulted)
    resp.runs[r.key] = result
  }
  return resp
}

if (process.argv.includes('--version')) {
  console.log(`tssdk-runner (bsv-script-lean #29) @bsv/sdk ${SDK_VERSION} on node ${process.version} (docs/PROVENANCE.md §1a)`)
  process.exit(0)
}

const rl = createInterface({ input: process.stdin, crlfDelay: Infinity })
const out = process.stdout
let pending = Promise.resolve()
rl.on('line', (line) => {
  if (line.trim() === '') return
  /** @type {Request} */
  let req
  try { req = /** @type {Request} */ (parseJson(line)) } catch (e) { process.stderr.write(`tssdk-runner: request decode: ${/** @type {Error} */ (e).message}\n`); process.exit(2) }
  const resp = handle(req)
  if (!out.write(JSON.stringify(resp) + '\n')) {
    rl.pause()
    out.once('drain', () => rl.resume())
  }
})
rl.on('close', () => { void pending.then(() => process.exit(0)) })
