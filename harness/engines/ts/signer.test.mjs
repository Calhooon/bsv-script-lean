// #145: observable transaction behavior, method coverage, and failure isolation.
// All keys below are small public test scalars; no network or node is used.
import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { test } from 'node:test'
import { LockingScript, P2PKH, PrivateKey, Script, Spend, Transaction, UnlockingScript } from '@bsv/sdk'
import { checkRuntime, signEntry } from './signer.mjs'

const keys = [1, 2, 3].map(n => n.toString(16).padStart(64, '0'))
const pubs = keys.map(k => PrivateKey.fromHex(k).toPublicKey().toString())
const key = keys[0]
const pub = pubs[0]
assert.ok(key !== undefined && pub !== undefined)
const lock = new P2PKH().lock(PrivateKey.fromHex(key).toPublicKey().toHash()).toHex()

/** @param {number} [scope] @param {number} [version] */
function fixture(scope = 0x41, version = 2) {
  const tx = new Transaction(version, [0, 1].map(index => ({
    sourceTXID: (index + 1).toString(16).padStart(64, '0'), sourceOutputIndex: index,
    unlockingScript: UnlockingScript.fromHex(''), sequence: 0xffffffff
  })), [0, 1].map(() => ({ satoshis: 900, lockingScript: LockingScript.fromHex(lock) })), 0)
  return {
    id: 'test-public-keys', family: 'signer/p2pkh', rule: 'crypto.checksig', tx: tx.toHex(), params: {}, expect: {},
    prevouts: tx.inputs.map(i => ({ txid: i.sourceTXID, vout: i.sourceOutputIndex, satoshis: 1000, script: lock })),
    signing: {
      version, locktime: 5,
      inputs: tx.inputs.map((_, index) => ({
        index, template: 'p2pkh', privkeys: [key], pubkeys: [pub], sighash_type: scope,
        sequence: index === 0 ? 0 : 0xfffffffd, scriptcode_hex: [lock], sig_sites: [0], unlock_template: '<sig0><pub0>'
      }))
    }
  }
}

/** @param {string} raw @param {ReturnType<typeof fixture>} row */
function validate(raw, row) {
  const tx = Transaction.fromHex(raw)
  return tx.inputs.every((input, index) => {
    const prevout = row.prevouts[index]
    assert.ok(prevout !== undefined && input.sourceTXID !== undefined && input.unlockingScript !== undefined)
    return new Spend({
      sourceTXID: input.sourceTXID, sourceOutputIndex: input.sourceOutputIndex, sourceSatoshis: prevout.satoshis,
      lockingScript: LockingScript.fromHex(prevout.script), transactionVersion: tx.version,
      otherInputs: tx.inputs.filter((_, i) => i !== index), inputIndex: index,
      unlockingScript: input.unlockingScript, inputSequence: input.sequence ?? 0xffffffff,
      outputs: tx.outputs, lockTime: tx.lockTime
    }).validate()
  })
}

await test('all FORKID scopes: methods agree, preserve metadata, and sign every input', async () => {
  checkRuntime()
  for (const scope of [0x41, 0x42, 0x43, 0xc1, 0xc2, 0xc3]) {
    for (const version of [1, 2]) {
      const row = fixture(scope, version)
      const results = await signEntry(row)
      assert.equal(results.length, 3)
      assert.equal(new Set(results.map(r => r.tx_hex)).size, 1)
      for (const result of results) {
        assert.ok(result.tx_hex, result.note)
        assert.ok(validate(result.tx_hex, row))
        const tx = Transaction.fromHex(result.tx_hex)
        assert.equal(tx.version, version)
        assert.equal(tx.lockTime, 5)
        assert.deepEqual(tx.inputs.map(i => i.sequence), [0, 0xfffffffd])
        assert.equal(result.inputs.length, 2)
        for (const input of result.inputs) {
          const once = createHash('sha256').update(Buffer.from(input.preimage_hex, 'hex')).digest()
          assert.equal(input.digest_hex, createHash('sha256').update(once).digest('hex'))
          assert.equal(input.scriptcode_used_hex, lock)
        }
      }
      assert.deepEqual(await signEntry(row), results)
    }
  }
})

await test('bare multisig: no public template; API paths emit both signatures with the dummy', async () => {
  const row = fixture()
  const multisig = Script.fromASM(`OP_2 ${pubs.join(' ')} OP_3 OP_CHECKMULTISIG`).toHex()
  row.prevouts.forEach(p => { p.script = multisig })
  row.signing.inputs.forEach(s => {
    s.template = 'multisig-2-of-3'
    s.privkeys = keys.slice(0, 2)
    s.pubkeys = pubs.slice(0, 2)
    s.sig_sites = [0, 0]
    s.scriptcode_hex = [multisig]
    s.unlock_template = '00<sig0><sig1>'
  })
  const [template, ...apis] = await signEntry(row)
  assert.equal(template?.tx_hex, null)
  assert.match(template.note, /no public multisig-2-of-3 template/)
  for (const api of apis) {
    assert.ok(api.tx_hex, api.note)
    assert.ok(validate(api.tx_hex, row))
    assert.equal(api.inputs.length, 2)
  }
})

await test('two CHECKSIG sites: only the caller scriptCodes sign the Chronicle unlock', async () => {
  for (const shape of ['a', 'b']) {
    const row = fixture()
    const otherKey = keys[1]
    assert.ok(otherKey !== undefined)
    const p2pk = shape === 'a' ? Script.fromASM(`${pubs[1]} OP_CHECKSIG`).toHex()
      : new P2PKH().lock(PrivateKey.fromHex(otherKey).toPublicKey().toHash()).toHex()
    /** @type {string} */
    const tail = shape === 'a' ? Script.fromASM(`${pub} OP_CHECKSIGVERIFY`).toHex() : 'ad68'
    row.prevouts.forEach(p => { p.script = p2pk })
    row.signing.inputs.forEach(s => {
      s.template = 'checksig-in-unlock-' + shape
      s.privkeys = keys.slice(0, 2)
      s.pubkeys = pubs.slice(0, 2)
      s.sig_sites = [0, 1]
      s.scriptcode_hex = [tail + p2pk, p2pk]
      s.unlock_template = shape === 'a' ? '<sig1><sig0>ab' + tail : '<sig1><pub1>5163<sig0><pub0>ab' + tail
    })
    const [template, defaults, explicit] = await signEntry(row)
    assert.equal(template?.tx_hex, null)
    assert.ok(defaults?.tx_hex, defaults?.note)
    assert.ok(explicit?.tx_hex, explicit?.note)
    assert.throws(() => validate(defaults.tx_hex ?? '', row), /OP_CHECKSIGVERIFY/)
    assert.ok(validate(explicit.tx_hex, row))
    assert.deepEqual(explicit.inputs.map(i => i.index), [0, 0, 1, 1])
    assert.deepEqual(explicit.inputs.map(i => i.scriptcode_used_hex), [tail + p2pk, p2pk, tail + p2pk, p2pk])
  }
})

await test('Chronicle and legacy scopes are explicit template absences, without changing the API scope', async () => {
  for (const scope of [0x61, 0x62, 0x63, 0xe1, 0xe2, 0xe3, 1, 2, 3, 0x81, 0x82, 0x83]) {
    const row = fixture(scope)
    const [template, ...apis] = await signEntry(row)
    assert.equal(template?.tx_hex, null)
    assert.match(template.note, /no legacy or Chronicle-bit parameter/)
    for (const api of apis) {
      assert.ok(api.tx_hex, api.note)
      assert.ok(validate(api.tx_hex, row))
      for (const input of api.inputs) assert.equal(Buffer.from(input.preimage_hex, 'hex').readUInt32LE(input.preimage_hex.length / 2 - 4), scope)
    }
  }
})

await test('unsupported or malformed rows get all methods, each with a reason', async () => {
  const row = fixture()
  row.signing.inputs[0]?.privkeys.splice(0)
  for (const result of await signEntry(row)) {
    assert.equal(result.tx_hex, null)
    assert.ok(result.note)
  }
  const malformed = fixture()
  malformed.prevouts[0] = { txid: 'ff'.repeat(32), vout: 0, satoshis: 1000, script: lock }
  for (const result of await signEntry(malformed)) {
    assert.equal(result.tx_hex, null)
    assert.match(result.note, /does not match/)
  }
  const absent = fixture()
  absent.signing.inputs.forEach(s => { s.template = 'unknown'; s.unlock_template = '<unknown>' })
  assert.deepEqual((await signEntry(absent)).map(r => r.tx_hex), [null, null, null])
})

await test('P2PK scriptCode list: telemetry distinguishes handed and serialized scripts', async () => {
  const row = fixture(0x61)
  const p2pk = Script.fromASM(`${pub} OP_CHECKSIG`).toHex()
  row.prevouts.forEach(p => { p.script = 'ab' + p2pk })
  const withSeparator = { ...row, signing: { ...row.signing, inputs: row.signing.inputs.map(s => ({
    ...s, template: 'p2pk', scriptcode_hex: ['ab' + p2pk], unlock_template: '<sig0>'
  })) } }
  const [template, ...apis] = await signEntry(withSeparator)
  assert.equal(template?.tx_hex, null)
  for (const api of apis) {
    assert.ok(api.tx_hex, api.note)
    assert.ok(validate(api.tx_hex, row))
    assert.deepEqual(api.inputs.map(i => i.scriptcode_used_hex), ['ab' + p2pk, 'ab' + p2pk])
    assert.deepEqual(api.inputs.map(i => i.scriptcode_serialized_hex), [p2pk, p2pk])
  }
})

await test('preimage token and later key site preserve exact SDK bytes', async () => {
  const row = fixture()
  row.signing.inputs.forEach(s => {
    s.template = 'checksig-in-unlock-b'
    s.scriptcode_hex = ['51', lock]
    s.sig_sites = [1]
    s.unlock_template = '<preimage0>75<sig0><pub0>'
  })
  const [template, ...apis] = await signEntry(row)
  assert.equal(template?.tx_hex, null)
  for (const api of apis) {
    assert.ok(api.tx_hex, api.note)
    assert.ok(validate(api.tx_hex, row))
    assert.deepEqual(api.inputs.map(i => [i.index, i.site]), [[0, 0], [0, 1], [1, 0], [1, 1]])
    const tx = Transaction.fromHex(api.tx_hex)
    for (const index of [0, 1]) {
      const trace = api.inputs.find(i => i.index === index && i.site === 0)
      assert.ok(trace !== undefined)
      const push = new Script().writeBin(Array.from(Buffer.from(trace.preimage_hex, 'hex'))).toHex()
      assert.ok(tx.inputs[index]?.unlockingScript?.toHex().startsWith(push + '75'))
    }
  }
})

await test('format rejections apply to all methods and unknown tokens are named', async () => {
  for (const field of ['pubkeys', 'unlock_template', 'sig_sites']) {
    const row = fixture()
    const input = row.signing.inputs[0]
    assert.ok(input !== undefined)
    Reflect.deleteProperty(input, field)
    for (const result of await signEntry(row)) {
      assert.equal(result.tx_hex, null)
      assert.ok(result.note.includes(field), result.note)
    }
  }
  const scalar = fixture()
  scalar.signing.inputs.forEach(s => Reflect.set(s, 'scriptcode_hex', lock))
  for (const result of await signEntry(scalar)) {
    assert.equal(result.tx_hex, null)
    assert.match(result.note, /scriptcode_hex must be an array/)
  }
  const unknown = fixture()
  unknown.signing.inputs.forEach(s => { s.template = 'version' })
  for (const result of await signEntry(unknown)) {
    assert.equal(result.tx_hex, null)
    assert.match(result.note, /unknown template/)
  }
  const token = fixture()
  token.signing.inputs.forEach(s => { s.unlock_template = '<unsupported0>' })
  for (const result of (await signEntry(token)).slice(1)) {
    assert.equal(result.tx_hex, null)
    assert.match(result.note, /unsupported unlock_template token <unsupported0>/)
  }
})
