import BsvScript.Sighash
import BsvScript.Tx
import Lean.Data.Json
/-!
# The sighash check of `BsvScript.Sighash` (#12)

Three corpora, every one a byte-exact comparison against a digest the spec did
not compute:

1. `corpus/sighash/bsv-rs-<version>.jsonl` (`harness/src/bin/sighash_vectors.rs`; the pinned version, `docs/PROVENANCE.md` §1a):
   500 random transactions; bsv-rs's BIP143 preimage and digest for one
   input under twelve scopes. The generator calls the crate's BIP143 functions
   directly (`build_sighash_preimage`, `compute_sighash_for_signing`,
   `harness/src/bin/sighash_vectors.rs:13`), whatever the scope's bits, so the
   comparison is against `sighashBIP143` called directly, not against the
   dispatch. The pinned crate implements the original digest and the
   reference's dispatch too (since 0.3.29, bsv-rs#22; at the pin 0.7.0
   `compute_sighash_dispatched_for_signing` and
   `compute_sighash_original_for_signing`, `src/primitives/bsv/sighash.rs:970–992`,
   the dispatch of `interpreter.cpp:2118–2123`); these vectors do not exercise
   them, and the original digest and the dispatch are checked against the
   reference's own rows (2 below).
2. `corpus/sighash/bitcoin-sv-v1.2.2-sighash.json`: the reference's own
   `src/test/data/sighash.json` at the pin (1,000 rows; `src/test/sighash_tests.cpp`:
   column 4 is `SignatureHash(scriptCode, tx, nIn, type, Amount(0))` with FORKID
   enabled, column 5 is `SignatureHashOriginal`; both printed by `uint256::GetHex`,
   the bytes reversed). The hash type is a random 32-bit word, so every bit of
   `SigHashType` and both digests are exercised, `OP_CODESEPARATOR` stripping
   included.
3. `corpus/sighash/mainnet.jsonl` (`tools/mainnet_read.py`): public P2PKH spends
   read from mainnet blocks 400,000 (pre-UAHF, the original digest) and 950,000
   (post-Chronicle, FORKID). This check prints `MAINNET <txid> <input> <digest>`;
   `harness/src/bin/sighash_verify.rs` then verifies each transaction's own
   signature against its public key and this digest (ECDSA through bsv-rs).

The FIPS 180-4 examples for SHA-256 run first. Exit 1 on any mismatch.
-/

open BsvScript BsvScript.Params BsvScript.Sighash BsvScript.Tx BsvScript.Numbers BsvScript.Hash
open Lean

/-- `uint256::GetHex`: the bytes reversed. -/
def hexDisplay (bs : Bytes) : String := hexEncode bs.reverse

def utf8 (s : String) : Bytes := s.toUTF8.toList.map (·.toNat)

def fipsCheck : IO Nat := do
  let cases : List (String × String) :=
    [("abc", "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"),
     ("", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
     ("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
      "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"),
     ("abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu",
      "cf5b16a778af8380036ce59e7b0492370b249b11e8f07a51afac45037afee9d1")]
  let mut bad := 0
  for (msg, want) in cases do
    if hexEncode (sha256 (utf8 msg)) != want then
      IO.println s!"  FIPS sha256 mismatch on {repr msg}"; bad := bad + 1
  if hexEncode (sha256d []) != "5df6e0e2761359d30a8275058e299fcc0381534545f55cf43e41983f5d4c9456" then
    IO.println "  sha256d(\"\") mismatch"; bad := bad + 1
  IO.println s!"sighash: FIPS 180-4 SHA-256 examples {cases.length} + sha256d: {bad} mismatches"
  pure bad

def hexOrFail (s : String) (what : String) : IO Bytes :=
  match hexDecode s with
  | some b => pure b
  | none => throw (IO.userError s!"bad hex in {what}")

def txOrFail (hex : String) (what : String) : IO Tx := do
  match decodeTx (← hexOrFail hex what) with
  | some tx => pure tx
  | none => throw (IO.userError s!"undecodable tx in {what}")

/-- The bsv-rs version a vector file names (`…/bsv-rs-<x.y.z>.jsonl`, `…/ecdsa-bsv-rs-<x.y.z>.jsonl`:
the harness writes the pinned version into the file's name, `docs/PROVENANCE.md` §1a; lean #47): the
verdict line names the vectors it read, never a literal version. -/
def bsvRsVersionOfPath (path : String) : String :=
  let file := (path.splitOn "/").getLastD path
  match file.splitOn "bsv-rs-" with
  | [_, rest] => (rest.splitOn ".jsonl").headD rest
  | _ => file

def bsvrsCheck (path : String) : IO (Nat × Nat) := do
  let lines ← IO.FS.lines path
  let mut n := 0
  let mut bad := 0
  for line in lines do
    if line.trim.isEmpty then continue
    let j ← match Json.parse line with | .ok j => pure j | .error e => throw (IO.userError s!"json: {e}")
    let get := fun (k : String) => match j.getObjValAs? String k with
      | .ok v => pure v | .error e => throw (IO.userError s!"{k}: {e}")
    let getN := fun (k : String) => match j.getObjValAs? Nat k with
      | .ok v => pure v | .error e => throw (IO.userError s!"{k}: {e}")
    let tx ← txOrFail (← get "tx") "bsv-rs vector"
    let nIn ← getN "input_index"
    let sub ← hexOrFail (← get "subscript") "subscript"
    let sats ← getN "satoshis"
    let scope ← getN "scope"
    let t : SigHashType := { raw := scope }
    let pre := preimageBIP143 sub tx nIn t sats
    let dig := sighashBIP143 sub tx nIn t sats
    n := n + 1
    if hexEncode pre != (← get "preimage") then
      IO.println s!"  bsv-rs #{n}: preimage mismatch (scope 0x{Nat.toDigits 16 scope |> String.mk})"; bad := bad + 1
    else if hexEncode dig != (← get "digest") then
      IO.println s!"  bsv-rs #{n}: digest mismatch"; bad := bad + 1
  IO.println s!"sighash: bsv-rs {bsvRsVersionOfPath path} BIP143 vectors: {n} entries, {bad} mismatches (preimage and digest)"
  pure (n, bad)

def referenceCheck (path : String) : IO (Nat × Nat) := do
  let text ← IO.FS.readFile path
  let j ← match Json.parse text with | .ok j => pure j | .error e => throw (IO.userError s!"json: {e}")
  let rows ← match j.getArr? with | .ok a => pure a | .error e => throw (IO.userError e)
  let mut n := 0
  let mut bad := 0
  let mut bip := 0
  for row in rows do
    let cells ← match row.getArr? with | .ok a => pure a | .error e => throw (IO.userError e)
    if cells.size < 6 then continue   -- the comment row
    let str := fun (i : Nat) => match cells[i]!.getStr? with
      | .ok v => pure v | .error e => throw (IO.userError s!"cell {i}: {e}")
    let tx ← txOrFail (← str 0) "reference row"
    let script ← hexOrFail (← str 1) "reference script"
    let nIn ← match cells[2]!.getNat? with | .ok v => pure v | .error e => throw (IO.userError e)
    let ht ← match cells[3]!.getInt? with | .ok v => pure v | .error e => throw (IO.userError e)
    let t : SigHashType := { raw := (ht % (2 ^ 32 : Int)).toNat }
    let regular := sighash script tx nIn t 0 true
    let original := sighashOriginal script tx nIn t
    n := n + 1
    if t.hasForkId && !t.hasChronicle then bip := bip + 1
    if hexDisplay regular != (← str 4) then
      IO.println s!"  reference row {n}: SignatureHash mismatch (type 0x{String.mk (Nat.toDigits 16 t.raw)})"; bad := bad + 1
    if hexDisplay original != (← str 5) then
      IO.println s!"  reference row {n}: SignatureHashOriginal mismatch (type 0x{String.mk (Nat.toDigits 16 t.raw)})"; bad := bad + 1
  IO.println s!"sighash: the reference's sighash.json at the pin: {n} rows × 2 columns ({bip} rows take the BIP143 path in column 4), {bad} mismatches"
  pure (n, bad)

def mainnetDigests (path : String) : IO Nat := do
  let lines ← IO.FS.lines path
  let mut n := 0
  for line in lines do
    if line.trim.isEmpty then continue
    let j ← match Json.parse line with | .ok j => pure j | .error e => throw (IO.userError s!"json: {e}")
    let get := fun (k : String) => match j.getObjValAs? String k with
      | .ok v => pure v | .error e => throw (IO.userError s!"{k}: {e}")
    let getN := fun (k : String) => match j.getObjValAs? Nat k with
      | .ok v => pure v | .error e => throw (IO.userError s!"{k}: {e}")
    let txid ← get "txid"
    let height ← getN "height"
    let input ← getN "input"
    let tx ← txOrFail (← get "tx") s!"mainnet {txid}"
    let prevout ← match j.getObjVal? "prevout" with | .ok p => pure p | .error e => throw (IO.userError e)
    let script ← hexOrFail (← match prevout.getObjValAs? String "script" with
      | .ok v => pure v | .error e => throw (IO.userError e)) "prevout script"
    let sats ← match prevout.getObjValAs? Nat "satoshis" with | .ok v => pure v | .error e => throw (IO.userError e)
    let sig ← hexOrFail (← get "sig") "sig"
    -- The block flags by height: FORKID enabled from the UAHF height (`verify_script_flags.cpp:54–58`).
    let enabled := decide (Consensus.uahfHeight ≤ height)
    let t := SigHashType.ofSig sig
    let scriptCode := cleanupScriptCode script sig enabled
    let digest := sighash scriptCode tx input t sats enabled
    IO.println s!"MAINNET {txid} {input} {hexEncode digest}"
    n := n + 1
  IO.println s!"sighash: {n} mainnet digests printed for harness/sighash_verify (the ECDSA leg)"
  pure n

def main (args : List String) : IO UInt32 := do
  match args with
  | [bsvrs, reference, mainnet] =>
    let f ← fipsCheck
    let (_, b1) ← bsvrsCheck bsvrs
    let (_, b2) ← referenceCheck reference
    let m ← mainnetDigests mainnet
    if f + b1 + b2 == 0 && m > 0 then
      IO.println "sighash: GREEN (the ECDSA leg follows)"; pure 0
    else
      IO.println "sighash: RED"; pure 1
  | _ => IO.println "usage: sighashcheck <bsv-rs.jsonl> <reference sighash.json> <mainnet.jsonl>"; pure 2
