#!/usr/bin/env node
// bsv-script-lean #146 (lane fixtures-146, 2026-10-16): the loader proof of corpus/fixtures/ts-sdk/evaluation.json.
//
// [SRC] ts-stack 4d0ea63c85a836e3509291babb0d8e0c784b70a0, read with git show:
// conformance/runner/ts/dispatchers/sdkHelpers.ts:613-645,682-782 and sdk.ts:789-800.
// node-transaction: round-trip tx_hex, then every input under every flag_strings entry;
// expected.valid=false requires at least one rejected spend. flag_sets is not consumed.
// node-sighash: sourceSatoshis=0; hash and reverse both format and formatOTDA results;
// only format receives ignoreChronicle from sources. Both expected hashes are required.
// runner.test.ts:91-133 reads ids, parity_class, skip_reason, skip, input and expected;
// notes and other descriptive metadata are not consulted. This proof additionally refuses
// empty files/classes and requires the advertised counts in manifest.json to match.
// Differences use the class listed for the same spend and column by
// `RULES_CHECK_LIST=<file> rules_check --engine ts-sdk` (harness/src/bin/rules_check.rs, list_class), or, for
// regenerated signer controls, the existing crypto.checksig.unlock.ungated predicate in harness/rules/ts-sdk.json.
// Other unclassified differences are RED. No network; the files are read only.
//
// Run: "$(tools/node_bin.sh)" harness/engines/ts/fixtures.mjs <repo root> <the listing>
import { readFileSync, readdirSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { Transaction, Spend, LockingScript, Script, TransactionSignature, Hash } from '@bsv/sdk'

/**
 * @typedef {{ txid: string, vout: number, script_pubkey_hex: string, amount_satoshis: number }} Prevout
 * @typedef {{ fixture_type: string, sources?: string[], tx_hex: string, prevouts?: Prevout[], flag_strings?: string[], script_hex?: string, input_index?: number, hash_type?: number, source_id?: string, signer_method?: string }} Input
 * @typedef {{ valid?: boolean, regular_hash?: string, original_hash?: string }} Expected
 * @typedef {{ id: string, input: Input, expected: Expected, skip?: boolean, parity_class?: string }} Vector
 */

/**
 * JSON.parse as `unknown` (its own type is `any`; the callers name the shape they read)
 * @param {string} text
 * @returns {unknown}
 */
function parseJson (text) { return JSON.parse(text) }

function main () {
  const root = process.argv[2] ?? join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..')
  const list = process.argv[3] ?? ''

  // the classifier's own class per (spend txid, column): the listing rules_check writes under RULES_CHECK_LIST
  // (harness/src/bin/rules_check.rs, list_class): engine key, column, txid, class, entry id
  const table = /** @type {{ classes: Record<string, unknown>, rows: { class: string, when: Record<string, unknown> }[] }} */ (parseJson(readFileSync(join(root, 'harness', 'rules', 'ts-sdk.json'), 'utf8')))
  const classes = new Set(Object.keys(table.classes))
  // Reuse only the existing #144 predicate for newly regenerated controls. A
  // signer refusal is never excused by a signer class or by this control rule.
  const unlockRule = table.rows.find(r => r.class === 'crypto.checksig.unlock.ungated')
  /** @type {Set<string>} */
  const unlockControls = new Set()
  if (unlockRule?.when['column'] === 'word' && unlockRule.when['rule'] === 'crypto.checksig.unlock' &&
      unlockRule.when['verdicts_differ'] === true && typeof unlockRule.when['spend_height_lt'] === 'number') {
    for (const name of readdirSync(join(root, 'corpus', 'signer')).filter(n => n.endsWith('.jsonl'))) {
      for (const line of readFileSync(join(root, 'corpus', 'signer', name), 'utf8').trim().split('\n')) {
        const row = /** @type {{ id: string, rule: string, params: { spend_height: number } }} */ (parseJson(line))
        if (row.rule === unlockRule.when['rule'] && row.params.spend_height < unlockRule.when['spend_height_lt']) unlockControls.add(row.id)
      }
    }
  }
  /** @type {Map<string, string[]>} */
  const listed = new Map()
  for (const line of readFileSync(list, 'utf8').split('\n')) {
    const f = line.split('\t')
    if (f.length !== 5 || !(f[0] ?? '').startsWith('ts-sdk@')) continue
    const col = f[1] === 'spec' ? 'block' : f[1] === 'spec-mempool' ? 'relay' : ''
    if (col === '') continue
    const key = `${f[2] ?? ''}|${col}`
    listed.set(key, [...(listed.get(key) ?? []), f[3] ?? ''])
  }

  /**
   * one input through Spend under the named flags
   * @param {Transaction} tx
   * @param {number} i
   * @param {Prevout} prev
   * @param {string[]} names
   * @returns {string | null} null when the input verifies, else the reason
   */
  function runInput (tx, i, prev, names) {
    const input = /** @type {import('@bsv/sdk').TransactionInput} */ (tx.inputs[i])
    try {
      const ok = new Spend({
        sourceTXID: /** @type {string} */ (input.sourceTXID),
        sourceOutputIndex: input.sourceOutputIndex,
        sourceSatoshis: prev.amount_satoshis,
        lockingScript: LockingScript.fromHex(prev.script_pubkey_hex),
        transactionVersion: tx.version,
        otherInputs: tx.inputs.filter((_, j) => j !== i),
        outputs: tx.outputs,
        unlockingScript: /** @type {import('@bsv/sdk').UnlockingScript} */ (input.unlockingScript),
        inputSequence: /** @type {number} */ (input.sequence),
        inputIndex: i,
        lockTime: tx.lockTime,
        verifyFlags: names
      }).validate()
      return ok ? null : 'validate() returned false'
    } catch (e) {
      const m = /** @type {{ message?: unknown } | null | undefined} */ (e)
      // one line per row: the SDK's message with its whitespace runs folded
      return String(m && m.message !== undefined ? m.message : e).replace(/\s+/g, ' ')
    }
  }

  /**
   * @param {Vector} v
   * @returns {{ got: boolean, detail: string }}
   */
  function nodeTransaction (v) {
    const tx = Transaction.fromHex(v.input.tx_hex)
    if (tx.toHex() !== v.input.tx_hex) return { got: false, detail: 'the round trip differs' }
    let rejected = ''
    for (const csv of v.input.flag_strings ?? []) {
      const names = csv.split(',').filter((n) => n !== '')
      for (let i = 0; i < tx.inputs.length; i++) {
        const input = /** @type {import('@bsv/sdk').TransactionInput} */ (tx.inputs[i])
        const prev = (v.input.prevouts ?? []).find((p) => p.txid === input.sourceTXID && (p.vout >>> 0) === input.sourceOutputIndex)
        if (prev === undefined) return { got: false, detail: `no prevout for input ${i}` }
        const why = runInput(tx, i, prev, names)
        if (why !== null && rejected === '') rejected = `input ${i}: ${why}`
      }
    }
    return { got: rejected === '', detail: rejected }
  }

  /**
   * @param {number[] | Uint8Array} b
   * @returns {string}
   */
  function reversedHex (b) { return Array.from(b).reverse().map((x) => x.toString(16).padStart(2, '0')).join('') }

  /**
   * @param {Vector} v
   * @returns {{ regular: string, original: string }}
   */
  function nodeSighash (v) {
    const tx = Transaction.fromHex(v.input.tx_hex)
    const i = v.input.input_index ?? 0
    const input = /** @type {import('@bsv/sdk').TransactionInput} */ (tx.inputs[i])
    const params = {
      sourceTXID: /** @type {string} */ (input.sourceTXID),
      sourceOutputIndex: input.sourceOutputIndex,
      sourceSatoshis: 0,
      transactionVersion: tx.version,
      otherInputs: tx.inputs.filter((_, j) => j !== i),
      outputs: tx.outputs,
      inputIndex: i,
      subscript: Script.fromHex(v.input.script_hex ?? ''),
      inputSequence: /** @type {number} */ (input.sequence),
      lockTime: tx.lockTime,
      scope: v.input.hash_type ?? 0
    }
    const regular = reversedHex(Hash.hash256(TransactionSignature.format({ ...params, ignoreChronicle: (v.input.sources ?? []).includes('teranode') })))
    const pre = TransactionSignature.formatOTDA(params)
    const original = reversedHex(Hash.hash256(Array.from(pre)))
    return { regular, original }
  }

  const manifest = /** @type {{ files: Record<string, Record<string, unknown>> }} */ (parseJson(readFileSync(join(root, 'corpus', 'fixtures', 'manifest.json'), 'utf8')))
  let red = 0
  for (const filename of ['evaluation.json', 'signer/evaluation.json']) {
    const file = /** @type {{ id: string, parity_class?: string, vectors: Vector[] }} */ (parseJson(readFileSync(join(root, 'corpus', 'fixtures', 'ts-sdk', filename), 'utf8')))
    const advertised = manifest.files[`ts-sdk/${filename}`]
    if (!Array.isArray(file.vectors) || file.vectors.length === 0) throw new Error(`empty ts-sdk/${filename}`)
    if (typeof file.id !== 'string' || file.id === '' || (file.parity_class ?? 'required') !== 'required') throw new Error('invalid file metadata')
    /** @type {Record<string, number>} */
    const counts = { vectors: file.vectors.length }
    for (const v of file.vectors) {
      const kind = v.input.fixture_type
      if (kind !== 'node-sighash' && kind !== 'node-transaction') throw new Error(`unsupported fixture class ${kind}`)
      if (v.skip === true || (v.parity_class ?? 'required') !== 'required') throw new Error(`skipped fixture ${v.id}`)
      counts[kind] = (counts[kind] ?? 0) + 1
      if (kind === 'node-transaction') {
        if (!Array.isArray(v.input.flag_strings) || v.input.flag_strings.length === 0 || v.input.flag_strings.some((s) => typeof s !== 'string')) throw new Error(`missing flag_strings in ${v.id}`)
        if (!Array.isArray(v.input.prevouts) || v.input.prevouts.length === 0 || typeof v.expected.valid !== 'boolean') throw new Error(`incomplete transaction fixture ${v.id}`)
      } else if (typeof v.expected.regular_hash !== 'string' || typeof v.expected.original_hash !== 'string') {
        throw new Error(`missing expected hashes in ${v.id}`)
      }
    }
    for (const [kind, n] of Object.entries(counts)) {
      if (n <= 0 || advertised?.[kind] !== n) throw new Error(`${kind} coverage ${n}, manifest ${String(advertised?.[kind])} (must be positive and equal)`)
    }
    for (const kind of Object.keys(advertised ?? {})) {
      if (kind.startsWith('node-') && !(kind in counts)) throw new Error(`missing advertised class ${kind}`)
    }
    /** @type {Record<string, { agree: number, red: number, classes: Record<string, number>, reds: string[] }>} */
    const tallies = {}
    for (const v of file.vectors) {
      const kind = v.input.fixture_type
      const t = (tallies[kind] ??= { agree: 0, red: 0, classes: {}, reds: [] })
      if (kind === 'node-sighash') {
        const { regular, original } = nodeSighash(v)
        if (regular === v.expected.regular_hash && original === v.expected.original_hash) {
          t.agree++
          console.log(`ROW ${filename} ${v.id} node-sighash AGREE`)
        } else {
          t.red++
          t.reds.push(v.id)
          console.log(`ROW ${filename} ${v.id} node-sighash file=${v.expected.regular_hash ?? ''}/${v.expected.original_hash ?? ''} sdk=${regular}/${original} RED`)
        }
        continue
      }
      const col = v.id.endsWith(':relay') ? 'relay' : 'block'
      const want = v.expected.valid === true
      /** @type {{ got: boolean, detail: string }} */
      let run
      try {
        run = nodeTransaction(v)
      } catch (e) {
        run = { got: false, detail: `decode: ${String(e)}` }
      }
      const { got, detail } = run
      const verdict = (/** @type {boolean} */ b) => (b ? 'valid' : 'invalid')
      if (got === want) {
        t.agree++
        console.log(`ROW ${filename} ${v.id} ${col} file=${verdict(want)} sdk=${verdict(got)} AGREE`)
        continue
      }
      const txid = Transaction.fromHex(v.input.tx_hex).id('hex')
      const controlClass = want && v.input.signer_method === 'reference' && unlockControls.has(v.input.source_id ?? '') &&
        !(v.input.flag_strings ?? []).some(csv => csv.split(',').includes('CHRONICLE')) && classes.has('crypto.checksig.unlock.ungated')
        ? 'crypto.checksig.unlock.ungated' : undefined
      const cls = (listed.get(`${txid}|${col}`) ?? []).find((c) => classes.has(c)) ?? controlClass
      if (!want && got && v.id.startsWith('bsl:signer:')) console.log(`NEW FINDING ts-sdk/${filename} ${v.id}: verifier accepts node-refused signer transaction`)
      if (cls !== undefined) {
        t.classes[cls] = (t.classes[cls] ?? 0) + 1
        console.log(`ROW ${filename} ${v.id} ${col} file=${verdict(want)} sdk=${verdict(got)} DIVERGE class=${cls} (${detail})`)
      } else {
        t.red++
        t.reds.push(`${v.id}`)
        console.log(`ROW ${filename} ${v.id} ${col} file=${verdict(want)} sdk=${verdict(got)} RED no class (${detail})`)
      }
    }
    for (const [kind, t] of Object.entries(tallies)) {
      const div = Object.values(t.classes).reduce((a, b) => a + b, 0)
      const parts = Object.keys(t.classes).sort().map((k) => `${k} ${t.classes[k] ?? 0}`)
      console.log(`SUMMARY ts-sdk/${filename} ${kind}: ${t.agree + div + t.red} rows, agree ${t.agree}, divergent by class ${div} [${parts.join('; ')}], RED ${t.red}`)
      for (const id of t.reds) console.log(`RED ts-sdk/${filename} ${id}`)
      red += t.red
    }
  }
  process.exitCode = red > 0 ? 1 : 0

}

try {
  main()
} catch (error) {
  console.error(`fixtures: RED: ${String(error)}`)
  process.exitCode = 2
}
