// bsv-script-lean #144 (lane xsig-144): @bsv/sdk 3.0.0's SIGNER side for the checksig-in-unlock witness.
//
// One JSON request on stdin, one JSON reply on stdout; the package is the ts-sdk adapter's installed copy
// (harness/engines/ts/node_modules, its lockfile the tree's), imported by path, nothing fetched.
//   template_sig      the leading push of P2PKH().unlock(key).sign(tx, input) with the input's sourceTransaction attached
//                     (the default wallet path: the template passes the source output's locking script as the
//                     subscript, SignatureUtils.ts resolveSourceDetails/formatPreimage, P2PKH.ts unlock/sign);
//   template_sig_sub  the same template with sourceTransaction detached, sourceTXID set and the caller's scriptCode in
//                     unlock()'s fifth parameter `lockingScript` (P2PKH.ts unlock: "Otherwise the input.sourceTransaction
//                     is required"; a lockingScript that differs from an attached source output throws);
//   preimage_lock     TransactionSignature.format({ subscript: lock }) (TransactionSignature.ts format/formatBip143);
//   preimage_sub      TransactionSignature.format({ subscript: scriptCode }) with the caller's scriptCode;
//   sig_sub           PrivateKey.sign(sha256(preimage_sub)) in checksig form, the template's own signing step by hand.
import { readFileSync } from 'node:fs'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { dirname, join } from 'node:path'

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..')
const sdk = await import(pathToFileURL(join(root, 'harness', 'engines', 'ts', 'node_modules', '@bsv', 'sdk', 'dist', 'esm', 'mod.js')).href)
const { Transaction, PrivateKey, P2PKH, Script, TransactionSignature, Hash, Utils } = sdk

const req = JSON.parse(readFileSync(0, 'utf8'))
const key = PrivateKey.fromHex(req.key)
const lock = Script.fromHex(req.lock)
const sub = Script.fromHex(req.script_code)
const scope = TransactionSignature.SIGHASH_ALL | TransactionSignature.SIGHASH_FORKID
const hex = (a) => Utils.toHex(Array.from(a))

const tx = Transaction.fromHex(req.tx)
const input = tx.inputs[req.input]
input.sourceTransaction = Transaction.fromHex(req.source_tx)
const signed = await new P2PKH().unlock(key).sign(tx, req.input)
const templateSig = signed.chunks[0].data

const txid = input.sourceTransaction.id('hex')
input.sourceTransaction = undefined
input.sourceTXID = txid
const signedSub = await new P2PKH().unlock(key, 'all', false, req.satoshis, sub).sign(tx, req.input)

const preimage = (subscript) => TransactionSignature.format({
  sourceTXID: txid,
  sourceOutputIndex: input.sourceOutputIndex,
  sourceSatoshis: req.satoshis,
  transactionVersion: tx.version,
  otherInputs: tx.inputs.filter((_, i) => i !== req.input),
  allInputs: tx.inputs,
  outputs: tx.outputs,
  inputIndex: req.input,
  subscript,
  inputSequence: input.sequence,
  lockTime: tx.lockTime,
  scope
})
const preSub = preimage(sub)
const raw = key.sign(Hash.sha256(preSub))
const sigSub = new TransactionSignature(raw.r, raw.s, scope).toChecksigFormat()

process.stdout.write(JSON.stringify({
  template_sig: hex(templateSig),
  template_sig_sub: hex(signedSub.chunks[0].data),
  preimage_lock: hex(preimage(lock)),
  preimage_sub: hex(preSub),
  sig_sub: hex(sigSub)
}) + '\n')
