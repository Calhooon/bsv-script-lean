import BsvScript.Eval
import BsvScript.Ops.Crypto
import BsvScript.Tx
import Test.Common
import Lean.Data.Json
/-!
# The crypto check (#11)

1. The hashes on the standard vectors: SHA-1 (FIPS 180-4 examples), RIPEMD-160
   (the examples of the RIPEMD-160 specification), `hash160` of the generator's
   uncompressed encoding (the key of the private key 1, address
   `1EHNa6Q4Jz2uvNExL497mE43ikXhwF6kZm`).
2. The ECDSA equation on `corpus/crypto/ecdsa-bsv-rs-<version>.jsonl` (the pinned version, `docs/PROVENANCE.md` §1a)
   (`harness/src/bin/ecdsa_vectors.rs`): 200 signatures bsv-rs made through RustCrypto's `k256` (not
   libsecp256k1) on random keys and digests, expanded into 620 genuine cases (compressed, uncompressed,
   hybrid keys; the high-S twin the reference normalizes) and 720 mutated ones (a flipped digest bit, a
   flipped signature byte, another key, r = 0, s = 0, r = n, s = n, a wrong hybrid parity, a key off the
   curve). The generator sets each expectation by construction (`true` genuine, `false` mutated): no
   library's verdict is in the file. Every expectation must match.
3. The eight mainnet P2PKH inputs of `corpus/sighash/mainnet.jsonl` through the
   evaluator with `Context.checkSig := txCheckSig`: the five of block 400,000
   under the block flags of that height (P2SH, DERSIG, CLTV;
   `verify_script_flags.cpp:32–83` with `chainparams.cpp`: BIP66 363,725, BIP65
   388,381, CSV 419,328 not yet, UAHF 478,558 not yet) and the pre-Genesis
   limits; the three of block 950,000 under the relay word. All must be valid,
   and a flipped signature byte must make each invalid.
4. `corpus/crypto/cases.jsonl` (`harness/src/bin/crypto_cases.rs`): the
   signature opcodes through the engine with real signatures, bsv-rs's verdicts;
   `crypto/` comparable, `crypto-candidate/` recorded.
5. The curve's own facts on the definitions as compiled: `2·G`'s `x`, `n·G = O`,
   `(n−1)·G = −G`; and the secp256k1 signature RFC 6979's nonce procedure gives for the
   private key 1 and SHA-256("Satoshi Nakamoto"), in low-S form (a community vector,
   bsv-rs 0.3.30 `tests/ec_tests.rs:331–347`; the values re-derived independently), which
   verifies with the compressed and the uncompressed key of 1 and fails on a flipped
   digest bit.
6. The lax parser's SEQUENCE length (`pubkey.cpp:48–60`: a long form's length bytes are
   skipped unread): row 1 of the ECDSA file with its sequence length re-encoded as
   `88 01×8` and as `87 01×7` must still verify, and a long form claiming more length
   bytes than the signature holds must fail (lean #32's second lens, finding D-1). The
   expectation is a reading of the source `[SRC]`: no implementation has decided these
   signatures yet (the node oracle's and bsv-rs's verdicts are asks on #32).

Exit 1 on any mismatch.
-/

open BsvScript BsvScript.Params BsvScript.Machine BsvScript.Tx BsvScript.Numbers BsvScript.Hash BsvScript.Test
open BsvScript.Ops.Crypto
open Lean

def utf8 (s : String) : Bytes := s.toUTF8.toList.map (·.toNat)

def hexOrFail (s : String) (what : String) : IO Bytes :=
  match hexDecode s with
  | some b => pure b
  | none => throw (IO.userError s!"bad hex in {what}")

def hashCheck : IO Nat := do
  let cases : List (String × (Bytes → Bytes) × String × String) :=
    [("sha1", sha1, "abc", "a9993e364706816aba3e25717850c26c9cd0d89d"),
     ("sha1", sha1, "", "da39a3ee5e6b4b0d3255bfef95601890afd80709"),
     ("sha1", sha1, "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq", "84983e441c3bd26ebaae4aa1f95129e5e54670f1"),
     ("ripemd160", ripemd160, "abc", "8eb208f7e05d987a9b044a8e98c6b087f15a0bfc"),
     ("ripemd160", ripemd160, "", "9c1185a5c5e9fc54612808977ee8f548b2258d31"),
     ("ripemd160", ripemd160, "message digest", "5d0689ef49d2fae572b881b123a85ffa21595f36"),
     ("ripemd160", ripemd160, "abcdefghijklmnopqrstuvwxyz", "f71c27109c692c1b56bbdceb5b9d2865b3708dbc"),
     ("ripemd160", ripemd160, "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq", "12a053384a9c0c88e405a06c27dcf49ada62eb2b")]
  let mut bad := 0
  for (name, f, msg, want) in cases do
    if hexEncode (f (utf8 msg)) != want then
      IO.println s!"  {name} mismatch on {repr msg}"; bad := bad + 1
  let g ← hexOrFail "0479be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8" "G"
  if hexEncode (hash160 g) != "91b24bf9f5288532960ac687abb035127b1d28a5" then
    IO.println "  hash160(G) mismatch"; bad := bad + 1
  IO.println s!"crypto: hash vectors (SHA-1 3, RIPEMD-160 5, hash160 1): {bad} mismatches"
  pure bad

def ecdsaCheck (path : String) : IO (Nat × Nat) := do
  let lines ← IO.FS.lines path
  let mut n := 0
  let mut bad := 0
  let mut shown := 0
  for line in lines do
    if line.trim.isEmpty then continue
    let j ← match Json.parse line with | .ok j => pure j | .error e => throw (IO.userError s!"json: {e}")
    let get := fun (k : String) => match j.getObjValAs? String k with
      | .ok v => pure v | .error e => throw (IO.userError s!"{k}: {e}")
    let pk ← hexOrFail (← get "pubkey") "pubkey"
    let sig ← hexOrFail (← get "sig") "sig"
    let hash ← hexOrFail (← get "hash") "hash"
    let expect ← match j.getObjValAs? Bool "expect" with | .ok v => pure v | .error e => throw (IO.userError e)
    let what ← get "what"
    n := n + 1
    if Crypto.Secp256k1.verify pk sig hash != expect then
      bad := bad + 1
      if shown < 10 then
        shown := shown + 1
        IO.println s!"  ECDSA MISMATCH #{n} ({what}): spec {Crypto.Secp256k1.verify pk sig hash}, the file's label {expect}"
  IO.println s!"crypto: ECDSA vectors from bsv-rs {bsvRsVersionOfPath path}: {n} cases, {bad} mismatches"
  pure (n, bad)

/-- The block flags of mainnet height 400,000 (`GetBlockScriptFlags`,
`verify_script_flags.cpp:32–83`): P2SH, DERSIG (BIP66 at 363,725), CLTV (BIP65
at 388,381); CSV (419,328), UAHF (478,558), DAA, Genesis and Chronicle not yet. -/
def flags400000 : Flags := { noFlags with p2sh := true, derSig := true, checkLockTimeVerify := true }

def mainnetCheck (path : String) : IO (Nat × Nat) := do
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
    let txid ← get "txid"
    let height ← getN "height"
    let input ← getN "input"
    let txBytes ← hexOrFail (← get "tx") "tx"
    let tx ← match decodeTx txBytes with | some t => pure t | none => throw (IO.userError "tx frame")
    let prevout ← match j.getObjVal? "prevout" with | .ok p => pure p | .error e => throw (IO.userError e)
    let lock ← hexOrFail (← match prevout.getObjValAs? String "script" with
      | .ok v => pure v | .error e => throw (IO.userError e)) "prevout script"
    let sats ← match prevout.getObjValAs? Nat "satoshis" with | .ok v => pure v | .error e => throw (IO.userError e)
    let scriptSig ← match tx.inputs[input]? with | some i => pure i.scriptSig | none => throw (IO.userError "input")
    let flags := if height < Consensus.uahfHeight then flags400000 else relayFlags
    let params : EvalParams := { flags, limits := limitsFor flags }
    let ctx : Context := { version := tx.version, checkLockTime := fun _ => false, checkSequence := fun _ => false,
                           checkSig := txCheckSig tx input sats }
    let v := Eval.verifyScript params ctx scriptSig lock
    n := n + 1
    if v != .valid then
      bad := bad + 1
      IO.println s!"  MAINNET {txid}:{input} (height {height}): {verdictShow v}"
    -- the control: a flipped byte inside the signature must fail
    let flipped := scriptSig.set 5 ((scriptSig.getD 5 0) ^^^ 1)
    let v2 := Eval.verifyScript params ctx flipped lock
    if v2 == .valid then
      bad := bad + 1
      IO.println s!"  MAINNET {txid}:{input}: a flipped signature byte still verifies"
  IO.println s!"crypto: {n} mainnet P2PKH inputs verify through the evaluator (and fail with a flipped signature byte): {bad} failures"
  pure (n, bad)

def casesCheck (path : String) : IO (Nat × Nat × Nat) := do
  let lines ← IO.FS.lines path
  let mut n := 0
  let mut agree := 0
  let mut mismatch := 0
  let mut unimpl := 0
  let mut shown := 0
  let mut candidates : Array String := #[]
  for line in lines do
    if line.trim.isEmpty then continue
    let j ← match Json.parse line with | .ok j => pure j | .error e => throw (IO.userError s!"json: {e}")
    let c ← match parseEntry j with | .ok c => pure c | .error e => throw (IO.userError e)
    n := n + 1
    let (v, scriptSig, tx) ← runEntryWith c (fun tx lock sats => txCheckSig tx 0 sats)
    let kind := verdictKind v
    if c.family.startsWith "crypto-candidate/" then
      candidates := candidates.push s!"  {c.id} {c.family}: spec {verdictShow v} vs bsv-rs {c.expect}"
    else if kind == "unimplemented" then
      unimpl := unimpl + 1
      if shown < 20 then
        shown := shown + 1
        IO.println s!"UNIMPLEMENTED {c.id} ({c.family}): {verdictShow v}"
    else if kind == c.expect then agree := agree + 1
    else
      mismatch := mismatch + 1
      if shown < 20 then
        shown := shown + 1
        IO.println s!"MISMATCH {c.id} ({c.family}): spec {verdictShow v} vs bsv-rs {c.expect}; lock {c.lockHex.take 160} unlock {(hexEncode scriptSig).take 160} version {tx.version}"
  IO.println s!"crypto: {n} engine cases; comparable {n - candidates.size}: agree {agree}, mismatch {mismatch}, unimplemented {unimpl}; recorded (not counted) {candidates.size}"
  for s in candidates do IO.println s
  pure (agree, mismatch, unimpl)

open BsvScript.Crypto.Secp256k1 in
/-- The curve's own facts and a community test signature (item 5; `docs/HYPOTHESES.md` §1's first row): the
values checked here were re-derived by an independent Python computation before they were written down. -/
def curveCheck : IO Nat := do
  let mut bad := 0
  -- 2·G's x
  if (toAffine (mul 2 G)).map (·.1) != some 0xc6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5 then
    IO.println "  2·G mismatch"; bad := bad + 1
  -- n·G is the point at infinity; (n−1)·G is −G
  if (toAffine (mul n G)).isSome then
    IO.println "  n·G is not the point at infinity"; bad := bad + 1
  if toAffine (mul (n - 1) G) != some (Gx, p - Gy) then
    IO.println "  (n−1)·G is not −G"; bad := bad + 1
  -- RFC 6979's nonce procedure: private key 1, SHA-256("Satoshi Nakamoto"), the deterministic r and the low s
  -- (a community vector, bsv-rs 0.3.30 `tests/ec_tests.rs:331–347`; RFC 6979's own vectors are not on secp256k1)
  let digest := Hash.sha256 (utf8 "Satoshi Nakamoto")
  let r : Nat := 0x934b1ea10a4b3c1757e2b0c017d0b6143ce3c9a7e6a4a49860d7a6ab210ee3d8
  let s : Nat := 0x2442ce9d2b916064108014783e923ec36b49743e2ffa1c4496f01a512aafd9e5
  let be32 := fun (x : Nat) => (List.range 32).reverse.map (fun i => x / 256 ^ i % 256)
  -- DER: `r` has its top bit set, so it takes a zero pad; `s` does not
  let sig : Bytes := [0x30, 0x45, 0x02, 0x21, 0x00] ++ be32 r ++ [0x02, 0x20] ++ be32 s
  let compressed : Bytes := 0x02 :: be32 Gx
  let uncompressed : Bytes := 0x04 :: be32 Gx ++ be32 Gy
  if hexEncode digest != "a0dc65ffca799873cbea0ac274015b9526505daaaed385155425f7337704883e" then
    IO.println "  SHA-256(\"Satoshi Nakamoto\") mismatch"; bad := bad + 1
  if !verify compressed sig digest then
    IO.println "  the key-1 signature fails with the compressed key"; bad := bad + 1
  if !verify uncompressed sig digest then
    IO.println "  the key-1 signature fails with the uncompressed key"; bad := bad + 1
  let flipped := digest.set 31 ((digest.getD 31 0) ^^^ 1)
  if verify compressed sig flipped then
    IO.println "  the key-1 signature verifies a flipped digest bit"; bad := bad + 1
  IO.println s!"crypto: the curve's facts (2·G, n·G = O, (n−1)·G = −G) and the key-1 signature of RFC 6979's nonce procedure (two keys, a flipped digest bit): {bad} mismatches"
  pure bad

/-- The lax parser's SEQUENCE length (item 6): `pubkey.cpp:48–60` skips a long form's length bytes unread,
so row 1 of the ECDSA file still verifies with its sequence length re-encoded as `88 01×8` and as `87 01×7`
(lean #32's second lens, finding D-1: the spec read them as `r`'s and `s`'s lengths are read, with the
`sizeof(size_t)` rule, and refused the first), and a long form claiming more length bytes than the
signature holds refuses the parse (`56–58`). The expectations are the source's reading `[SRC]`; no
implementation has run these signatures yet. -/
def laxSeqCheck (path : String) : IO Nat := do
  let line ← match (← IO.FS.lines path).toList.find? (fun l => !l.trim.isEmpty) with
    | some l => pure l | none => throw (IO.userError "the ECDSA file is empty")
  let j ← match Json.parse line with | .ok j => pure j | .error e => throw (IO.userError s!"json: {e}")
  let get := fun (k : String) => match j.getObjValAs? String k with
    | .ok v => pure v | .error e => throw (IO.userError s!"{k}: {e}")
  let pk ← hexOrFail (← get "pubkey") "pubkey"
  let sig ← hexOrFail (← get "sig") "sig"
  let hash ← hexOrFail (← get "hash") "hash"
  let mut bad := 0
  if sig.take 1 != [0x30] || (sig.getD 1 0) ≥ 0x80 || !Crypto.Secp256k1.verify pk sig hash then
    IO.println "  row 1 is not a genuine short-form signature"; bad := bad + 1
  let body := sig.drop 2
  let eight : Bytes := [0x30, 0x88] ++ List.replicate 8 0x01 ++ body
  let seven : Bytes := [0x30, 0x87] ++ List.replicate 7 0x01 ++ body
  let overlong : Bytes := [0x30, 0x80 + (body.length + 1)] ++ body
  if !Crypto.Secp256k1.verify pk eight hash then
    IO.println "  the sequence length 88 01×8 refuses a signature pubkey.cpp:48–60 accepts (a source reading)"; bad := bad + 1
  if !Crypto.Secp256k1.verify pk seven hash then
    IO.println "  the sequence length 87 01×7 refuses a signature pubkey.cpp:48–60 accepts (a source reading)"; bad := bad + 1
  if Crypto.Secp256k1.verify pk overlong hash then
    IO.println "  a sequence length claiming more bytes than the signature holds still verifies"; bad := bad + 1
  IO.println s!"crypto: the lax parser's sequence length (88 01×8, 87 01×7 verify; an overlong form fails): {bad} mismatches"
  pure bad

def main (args : List String) : IO UInt32 := do
  match args with
  | [ecdsa, mainnet, cases] =>
    let h ← hashCheck
    let (ne, be) ← ecdsaCheck ecdsa
    let c ← curveCheck
    let l ← laxSeqCheck ecdsa
    let (nm, bm) ← mainnetCheck mainnet
    let (agree, mismatch, unimpl) ← casesCheck cases
    if ne == 0 || nm == 0 || agree == 0 then
      IO.println "crypto: ZERO vectors"
      return 1
    return (if h + be + c + l + bm + mismatch + unimpl == 0 then 0 else 1)
  | _ => IO.println "usage: cryptocheck <ecdsa.jsonl> <mainnet.jsonl> <cases.jsonl>"; return 2
