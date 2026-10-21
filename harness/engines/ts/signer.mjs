#!/usr/bin/env node
// #145: sign the shared corpus Entry + signing object with the pinned SDK.
// No node, fee/change calculation, scriptCode derivation, or signature repair.
// Template pushes include their push opcode. A scriptcode_hex array names sites
// in execution order; sig_sites[K] maps key K to its site. Keys can share a site,
// and the OP_PUSH_TX site can have no host signing key.
import { closeSync, openSync, readFileSync, writeSync } from 'node:fs'
import { resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { Hash, P2PKH, PrivateKey, Script, Transaction, TransactionSignature, UnlockingScript, Utils } from '@bsv/sdk'

/** @typedef {'template' | 'api-default' | 'api-scriptcode'} Method */
/** @typedef {{index: number, template: string, privkeys: string[], pubkeys: string[], sighash_type: number, sequence: number, scriptcodes: string[], sig_sites: number[], unlock_template: string}} SigningInput */
/** @typedef {{script: string, satoshis: number}} Coin */
/** @typedef {{index: number, site: number, preimage_hex: string, digest_hex: string, scriptcode_used_hex: string, scriptcode_serialized_hex: string}} Trace */
/** @typedef {{id: string, engine: 'ts-sdk', method: Method, tx_hex: string | null, inputs: Trace[], note: string}} Result */
/** @typedef {Parameters<typeof TransactionSignature.format>[0]} FormatParams */

/** @type {readonly Method[]} */
export const METHODS = ['template', 'api-default', 'api-scriptcode']

/** @param {unknown} value @param {string} name @returns {Record<string, unknown>} */
function object(value, name) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) throw new Error(`${name} must be an object`)
  return /** @type {Record<string, unknown>} */ (value)
}

/** @param {unknown} value @param {string} name */
function string(value, name) {
  if (typeof value !== 'string') throw new Error(`${name} must be a string`)
  return value
}

/** @param {unknown} value @param {string} name */
function hex(value, name) {
  const text = string(value, name)
  if (!/^(?:[0-9a-fA-F]{2})*$/.test(text)) throw new Error(`${name} must be even-length hexadecimal`)
  return text.toLowerCase()
}

/** @param {unknown} value @param {string} name @param {number} [max] @param {number} [min] */
function integer(value, name, max = 0xffffffff, min = 0) {
  if (typeof value !== 'number' || !Number.isSafeInteger(value) || value < min || value > max) {
    throw new Error(`${name} must be an integer in [${min}, ${max}]`)
  }
  return value
}

/** @param {unknown} value @param {string} name @returns {unknown[]} */
function array(value, name) {
  if (!Array.isArray(value)) throw new Error(`${name} must be an array`)
  return /** @type {unknown[]} */ (value)
}

/** @param {unknown} value @returns {SigningInput} */
function signingInput(value) {
  const s = object(value, 'signing input')
  const codes = array(s['scriptcode_hex'], 'scriptcode_hex')
  if (codes.length === 0) throw new Error('scriptcode_hex must name a signature site')
  const template = string(s['template'], 'template')
  if (!/^(?:p2pkh|p2pk|multisig-[1-9][0-9]*-of-[1-9][0-9]*|checksig-in-unlock-[ab])$/.test(template)) {
    throw new Error(`unknown template ${template}`)
  }
  const privkeys = array(s['privkeys'], 'privkeys').map(k => hex(k, 'private key'))
  const pubkeys = array(s['pubkeys'], 'pubkeys').map(k => hex(k, 'public key'))
  const sigSites = array(s['sig_sites'], 'sig_sites').map(n => integer(n, 'sig_sites entry', codes.length - 1))
  if (privkeys.length === 0 || sigSites.length !== privkeys.length || pubkeys.length !== privkeys.length) {
    throw new Error('pubkeys and sig_sites must match privkeys')
  }
  return {
    index: integer(s['index'], 'index'),
    template, privkeys, pubkeys, sig_sites: sigSites,
    sighash_type: integer(s['sighash_type'], 'sighash_type', 255),
    sequence: integer(s['sequence'], 'sequence'),
    scriptcodes: codes.map(c => hex(c, 'scriptcode_hex')),
    unlock_template: string(s['unlock_template'], 'unlock_template')
  }
}

/** @param {unknown} value */
function prepare(value) {
  const row = object(value, 'row')
  const signing = object(row['signing'], 'signing')
  const tx = Transaction.fromHex(hex(row['tx'], 'tx'))
  if (tx.inputs.some(i => i.unlockingScript === undefined || i.unlockingScript.toHex() !== '')) {
    throw new Error('tx must be unsigned, with every unlocking script empty')
  }
  tx.version = integer(signing['version'], 'version', 0x7fffffff, -0x80000000)
  tx.lockTime = integer(signing['locktime'], 'locktime')
  const inputs = array(signing['inputs'], 'signing.inputs').map(signingInput).sort((a, b) => a.index - b.index)
  const prevouts = array(row['prevouts'], 'prevouts')
  if (inputs.length !== tx.inputs.length || prevouts.length !== tx.inputs.length) {
    throw new Error('signing.inputs and prevouts must cover every transaction input')
  }
  const coins = inputs.map((s, index) => {
    const input = tx.inputs[index]
    if (s.index !== index || input === undefined) throw new Error('input indices must cover the transaction exactly once')
    input.sequence = s.sequence
    const p = object(prevouts[index], 'prevout')
    if (hex(p['txid'], 'prevout.txid') !== input.sourceTXID || integer(p['vout'], 'prevout.vout') !== input.sourceOutputIndex) {
      throw new Error(`prevout ${index} does not match the transaction outpoint`)
    }
    return { script: hex(p['script'], 'prevout.script'), satoshis: integer(p['satoshis'], 'satoshis', Number.MAX_SAFE_INTEGER) }
  })
  return { tx, inputs, coins }
}

/** @param {Transaction} tx @param {SigningInput} s @param {Coin} coin @param {string} subscript @returns {FormatParams} */
function formatParams(tx, s, coin, subscript) {
  const input = tx.inputs[s.index]
  if (input?.sourceTXID === undefined) throw new Error(`input ${s.index} has no sourceTXID`)
  return {
    sourceTXID: input.sourceTXID,
    sourceOutputIndex: input.sourceOutputIndex,
    sourceSatoshis: coin.satoshis,
    transactionVersion: tx.version,
    otherInputs: tx.inputs.filter((_, i) => i !== s.index),
    allInputs: tx.inputs,
    inputIndex: s.index,
    outputs: tx.outputs,
    inputSequence: s.sequence,
    subscript: Script.fromHex(subscript),
    lockTime: tx.lockTime,
    scope: s.sighash_type,
    cache: tx.getSignatureHashCache()
  }
}

// Read the script actually serialized by the SDK, including its OTDA removal of
// CODESEPARATOR. The selector mirrors @bsv/sdk 3.0.0 TransactionSignature.ts:429-440
// with sighashForkIdEnabled at its default true; re-read it at a pin move.
// No local sighash implementation supplies either bytes or digest.
/** @param {number[]} preimage @param {SigningInput} s */
function serializedScript(preimage, s) {
  const reader = new Utils.Reader(preimage)
  if ((s.sighash_type & 0x40) !== 0 && (s.sighash_type & 0x20) === 0) {
    reader.read(104)
    return Utils.toHex(reader.read(reader.readVarIntNum()))
  }
  reader.read(4)
  const count = reader.readVarIntNum()
  const target = (s.sighash_type & 0x80) !== 0 ? 0 : s.index
  for (let index = 0; index < count; index++) {
    reader.read(36)
    const script = reader.read(reader.readVarIntNum())
    if (index === target) return Utils.toHex(script)
    reader.read(4)
  }
  throw new Error('SDK preimage has no signing input')
}

/** @param {number[]} preimage @param {SigningInput} s @param {number} site @param {string} subscript @returns {Trace} */
function trace(preimage, s, site, subscript) {
  return {
    index: s.index, site,
    preimage_hex: Utils.toHex(preimage),
    digest_hex: Utils.toHex(Hash.hash256(preimage)),
    scriptcode_used_hex: subscript,
    scriptcode_serialized_hex: serializedScript(preimage, s)
  }
}

/** @param {string} data */
function pushHex(data) {
  return new Script().writeBin(Array.from(Buffer.from(data, 'hex'))).toHex()
}

/** @param {SigningInput} s @param {string[]} signatures @param {string[]} preimages */
function fillUnlock(s, signatures, preimages) {
  const filled = s.unlock_template.replace(/<([a-z]+)(\d+)>/g, (_, kind, n) => {
    if (kind !== 'sig' && kind !== 'pub' && kind !== 'preimage') {
      throw new Error(`unsupported unlock_template token <${kind}${n}>`)
    }
    const slot = Number(n)
    const data = kind === 'sig' ? signatures[slot] : kind === 'pub' ? s.pubkeys[slot] : preimages[slot]
    if (data === undefined) throw new Error(`missing ${String(kind)}${slot} for input ${s.index}`)
    return pushHex(data)
  })
  return UnlockingScript.fromHex(hex(filled, 'filled unlock_template'))
}

/** @param {SigningInput} s */
function templateScope(s) {
  const base = s.sighash_type & 31
  const expected = base | 0x40 | (s.sighash_type & 0x80)
  if (s.sighash_type !== expected || base < 1 || base > 3) {
    throw new Error('P2PKH.unlock supports ALL/NONE/SINGLE with FORKID and optional ANYONECANPAY; no legacy or Chronicle-bit parameter')
  }
  return /** @type {'all' | 'none' | 'single'} */ (base === 1 ? 'all' : base === 2 ? 'none' : 'single')
}

/** @param {Transaction} tx @param {SigningInput} s @param {Coin} coin @param {Trace[]} traces */
async function signTemplate(tx, s, coin, traces) {
  if (s.template !== 'p2pkh') throw new Error(`@bsv/sdk has no public ${s.template} template (ships P2PKH, PushDrop, RPuzzle)`)
  const scope = templateScope(s)
  const key = s.privkeys[0]
  if (key === undefined) throw new Error('P2PKH requires privkeys[0]')
  // The template does not expose its preimage. Recompute with its own serializer
  // and the same parameters (SignatureUtils.ts:194-213), without replacing it.
  const unlock = await new P2PKH().unlock(
    PrivateKey.fromHex(key), scope, (s.sighash_type & 0x80) !== 0,
    coin.satoshis, Script.fromHex(coin.script)
  ).sign(tx, s.index)
  traces.push(trace(TransactionSignature.format(formatParams(tx, s, coin, coin.script)), s, 0, coin.script))
  return unlock
}

/** @param {Transaction} tx @param {SigningInput} s @param {Coin} coin @param {Method} method @param {Trace[]} traces */
function signAPI(tx, s, coin, method, traces) {
  const scripts = s.scriptcodes.map(code => method === 'api-default' ? coin.script : code)
  const sites = scripts.map(code => TransactionSignature.format(formatParams(tx, s, coin, code)))
  traces.push(...sites.map((preimage, site) => trace(preimage, s, site, scripts[site] ?? '')))
  const signatures = s.privkeys.map((key, index) => {
    const site = s.sig_sites[index]
    const preimage = site === undefined ? undefined : sites[site]
    if (preimage === undefined) throw new Error(`no scriptCode for sig${index} at input ${s.index}`)
    // PrivateKey.sign hashes its argument again, exactly as P2PKH.sign does.
    const signature = PrivateKey.fromHex(key).sign(Hash.sha256(preimage))
    return Utils.toHex(new TransactionSignature(signature.r, signature.s, s.sighash_type).toChecksigFormat())
  })
  return fillUnlock(s, signatures, sites.map(preimage => Utils.toHex(preimage)))
}

/** Sign each method independently so an unsupported path cannot hide another.
 * @param {unknown} value @returns {Promise<Result[]>}
 */
export async function signEntry(value) {
  const row = object(value, 'row')
  const id = string(row['id'], 'id')
  /** @type {Result[]} */
  const results = []
  for (const method of METHODS) {
    /** @type {Result} */
    const result = { id, engine: 'ts-sdk', method, tx_hex: null, inputs: [], note: '' }
    try {
      const { tx, inputs, coins } = prepare(row)
      for (const s of inputs) {
        const coin = coins[s.index]
        const input = tx.inputs[s.index]
        if (coin === undefined || input === undefined) throw new Error(`missing input ${s.index}`)
        input.unlockingScript = method === 'template'
          ? await signTemplate(tx, s, coin, result.inputs)
          : signAPI(tx, s, coin, method, result.inputs)
      }
      result.tx_hex = tx.toHex()
      result.note = method === 'template'
        ? 'P2PKH.unlock(...).sign; real prevout lock and amount, no sourceTransaction. Preimage recomputed with the SDK formatter; digest recomputed with SDK hash256.'
        : `TransactionSignature.format; subscript=${method === 'api-default' ? 'real prevout locking script' : 'row scriptcode_hex'}; PrivateKey.sign(sha256(preimage)). Digest recomputed with SDK hash256.`
      result.note += ' Deterministic SDK nonce; input index and site identify each trace in execution order. No era/flag override or digest correction.'
    } catch (error) {
      result.note = error instanceof Error ? error.message : String(error)
    }
    results.push(result)
  }
  return results
}

export function checkRuntime() {
  if (process.versions.node.split('.')[0] !== '22') throw new Error('signer requires Node 22; use tools/node_bin.sh')
  const pkg = object(JSON.parse(readFileSync(new URL('./node_modules/@bsv/sdk/package.json', import.meta.url), 'utf8')), 'SDK package')
  if (pkg['version'] !== '3.0.0') throw new Error('signer requires the pinned @bsv/sdk 3.0.0')
}

/** @param {string[]} args */
async function main(args) {
  checkRuntime()
  if (args.length === 1 && args[0] === '--version') {
    process.stdout.write('ts-sdk-signer@3.0.0\n')
    return
  }
  const [input, output] = args.length === 4 && args[0] === '--corpus' && args[2] === '--out'
    ? [args[1], args[3]] : args
  if (input === undefined || output === undefined || ![2, 4].includes(args.length)) {
    throw new Error('usage: signer.mjs --corpus <file.jsonl> --out <output.jsonl> (or the two positional paths)')
  }
  if (resolve(input) === resolve(output)) throw new Error('input and output files must differ')
  const lines = readFileSync(input, 'utf8').split(/\r?\n/).filter(line => line.trim() !== '')
  // Parse before opening the output: invalid JSON must not truncate a past run.
  const entries = lines.map(line => /** @type {unknown} */ (JSON.parse(line)))
  const fd = openSync(output, 'w')
  try {
    for (const entry of entries) {
      for (const result of await signEntry(entry)) writeSync(fd, JSON.stringify(result) + '\n')
    }
  } finally {
    closeSync(fd)
  }
}

if (process.argv[1] !== undefined && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main(process.argv.slice(2)).catch(error => {
    process.stderr.write(`ts-sdk signer: ${error instanceof Error ? error.message : String(error)}\n`)
    process.exitCode = 2
  })
}
