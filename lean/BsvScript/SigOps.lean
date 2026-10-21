import BsvScript.Machine
/-!
# BsvScript.SigOps

The node's count of signature operations, `CScript::GetSigOpCount` (`src/script/script.cpp:30–166`
at the pin, `docs/PROVENANCE.md`), on every path (2026-09-27, S1: the spec gap
`tx.gate.policy-caps.unmodelled`'s remainder, CLAUDE.md rule 1; the transaction-level counts and the
mempool's test over them are `BsvScript.TxPolicy`'s).

The count walks the instructions once, carrying the last instruction (`30`, `37`, `120`;
default-constructed as `OP_INVALIDOPCODE` with an empty operand, `instruction.h:23–29`), the scope level
(`33`) and the count (`29`). An instruction whose opcode is `OP_INVALIDOPCODE` ends the walk (`40–41`):
a push that fails to decode, and a literal `0xff`, which `decode_instruction` returns as a valid
instruction (`instruction_iterator.h:26–27`). Under `fAccurate` or Genesis (`43–65`) a top-level
`OP_RETURN` ends it (`45–49`), `OP_IF`/`OP_NOTIF`/`OP_VERIF`/`OP_VERNOTIF` open a scope (`50–54`) and
`OP_ENDIF` closes one, an unbalanced `OP_ENDIF` setting `sigOpCountError` (`55–63`).
`OP_CHECKSIG`/`OP_CHECKSIGVERIFY` count one (`67–70`); a multisig counts `multisigSigOps` (`71–119`).
`sigOpCountError` is `none` here; every caller refuses on it before it reads a count
(`validation.cpp:1242`).

The paths: before Genesis without `fAccurate` (the consensus gate's count, `validation.cpp:437–459`
at `validation.cpp:559–566`) no scope is tracked, a multisig counts 20 and nothing fails (`sigOpCount_legacy_isSome`);
with `fAccurate` before Genesis (a P2SH redeem script, `script.cpp:159–165`) the scopes are tracked and a
multisig after `OP_1`–`OP_16` counts its number; after Genesis (every count the mempool takes then,
`validation.cpp:1235–1238`) a multisig counts the preceding push's number, up to 2,147,483,647 from a
four-byte push (`sigOpCount_multisig_max`), so three output scripts of six bytes each (`04 ffffff7f ae`)
count past `UINT32_MAX`, the default and largest policy cap (`BsvScript.TxPolicy`). Every count is at
most 2,147,483,647 per byte of its script (`sigOpCount_le`).

Bare line numbers are `src/script/script.cpp` at the pin (`docs/PROVENANCE.md`).
-/

namespace BsvScript.SigOps
open BsvScript.Numbers BsvScript.Machine BsvScript.Params

/-- The number a multisig adds (`script.cpp:75–123`) after the instruction `lastOp` with operand
`lastData`; `none` is `sigOpCountError`. Under `fAccurate` or Genesis a preceding `OP_1`–`OP_16` counts
its number (`74–77`; `DecodeOP_N`, `script.h:333`); otherwise after Genesis `OP_0` counts nothing
(`81–84`) and any other instruction's operand is read as a script number of at most four bytes (`85–91`),
minimally encoded (`98–104`) and non-negative (`106–111`), which `readNum … true 4` checks in that order,
the value added (`112`; within four bytes `getint` never clamps, `script_num.cpp:413–419`); before Genesis
without `fAccurate`, `MAX_PUBKEYS_PER_MULTISIG_BEFORE_GENESIS` = 20 (`115–118`, `consensus.h:50`). -/
def multisigSigOps (accurate genesis : Bool) (lastOp : Nat) (lastData : Bytes) : Option Nat :=
  if (accurate || genesis) && decide (Op.OP_1 ≤ lastOp) && decide (lastOp ≤ Op.OP_16) then
    some (lastOp - (Op.OP_1 - 1))
  else if genesis then
    if lastOp = Op.OP_0 then some 0
    else match readNum lastData true 4 with
      | .ok v => if v < 0 then none else some v.toNat
      | .error _ => none
  else some Consensus.maxPubKeysPerMultisigBeforeGenesis

/-- What an instruction adds to the count (`script.cpp:71–123`): one for `OP_CHECKSIG` and
`OP_CHECKSIGVERIFY`, `multisigSigOps` for `OP_CHECKMULTISIG` and `OP_CHECKMULTISIGVERIFY`, nothing
otherwise; `none` is `sigOpCountError`. -/
def opSigOps (accurate genesis : Bool) (op lastOp : Nat) (lastData : Bytes) : Option Nat :=
  if op = Op.OP_CHECKSIG ∨ op = Op.OP_CHECKSIGVERIFY then some 1
  else if op = Op.OP_CHECKMULTISIG ∨ op = Op.OP_CHECKMULTISIGVERIFY then
    multisigSigOps accurate genesis lastOp lastData
  else some 0

/-- The scope level after an instruction (`script.cpp:47–69`), tracked only under `fAccurate` or Genesis
(`tracked`): `OP_IF`, `OP_NOTIF`, `OP_VERIF`, `OP_VERNOTIF` open a scope (`50–54`), `OP_ENDIF` closes one
(`55–58`). -/
def scopeAfter (tracked : Bool) (op : Nat) (scope : Int) : Int :=
  if tracked && (decide (op = Op.OP_IF) || decide (op = Op.OP_NOTIF) || decide (op = Op.OP_VERIF) ||
      decide (op = Op.OP_VERNOTIF)) then scope + 1
  else if tracked && decide (op = Op.OP_ENDIF) then scope - 1
  else scope

/-- `CScript::GetSigOpCount(fAccurate, era, sigOpCountError)` (`script.cpp:30–128`), the walk: `fuel`
bounds the steps (`sigOpCount` gives the script's length, enough since every step consumes a byte); the
state is the last instruction's opcode and operand (`37`, `120`), the scope level (`33`) and the count
(`29`); a failed decode or a literal `0xff` ends it (`40–41`), a top-level `OP_RETURN` under `fAccurate`
or Genesis ends it (`45–49`), an unbalanced `OP_ENDIF` there is `none` (`55–63`), as is an instruction's
error (`opSigOps`). -/
def sigOpWalk (accurate genesis : Bool) : Nat → Bytes → Nat → Bytes → Int → Nat → Option Nat
  | 0, _, _, _, _, n => some n
  | _ + 1, [], _, _, _, n => some n
  | fuel + 1, op :: rest, lastOp, lastData, scope, n =>
    match getOpTail op rest with
    | none => some n
    | some (data, k) =>
      if op = Op.OP_INVALIDOPCODE then some n
      else if (accurate || genesis) && decide (op = Op.OP_RETURN) && decide (scope = 0) then some n
      else if scopeAfter (accurate || genesis) op scope < 0 then none
      else match opSigOps accurate genesis op lastOp lastData with
        | none => none
        | some a =>
          sigOpWalk accurate genesis fuel (rest.drop k) op data (scopeAfter (accurate || genesis) op scope) (n + a)

/-- `CScript::GetSigOpCount(fAccurate, era, …)` (`script.cpp:30–128`) on a whole script: the walk from
the default last instruction (`OP_INVALIDOPCODE`, an empty operand; `instruction.h:23–29`), scope 0,
count 0, with the script's length as fuel. `accurate` is `fAccurate`; `genesis` is
`IsProtocolActive(era, ProtocolName::Genesis)`. -/
def sigOpCount (accurate genesis : Bool) (s : Bytes) : Option Nat :=
  sigOpWalk accurate genesis s.length s Op.OP_INVALIDOPCODE [] 0 0

/-- The operand of an unlocking script's last instruction when every instruction is a push
(`script.cpp:141–150`: `std::all_of` refuses an opcode above `OP_16`, `OP_INVALIDOPCODE` among them, and
a push that fails to decode); `none` otherwise. -/
def lastPushOperand : Nat → Bytes → Bytes → Option Bytes
  | 0, _, last => some last
  | _ + 1, [], last => some last
  | fuel + 1, op :: rest, _ =>
    match getOpTail op rest with
    | none => none
    | some (data, k) => if Op.OP_16 < op then none else lastPushOperand fuel (rest.drop k) data

/-- `CScript::GetSigOpCount(scriptSig, era, …)` (`script.cpp:130–166`) on a P2SH locking script spent
from a pre-Genesis coin (the only case its caller reaches, `validation.cpp:481–486`): the accurate count
of the redeem script, the unlocking script's last push (`155–161`, the coin's era pre-Genesis); `0` when
the unlocking script is not push-only (`147–148`). -/
def p2shRedeemSigOps (scriptSig : Bytes) : Option Nat :=
  match lastPushOperand scriptSig.length scriptSig [] with
  | none => some 0
  | some redeem => sigOpCount true false redeem

/-- A sum of counts each of which may fail: `none` as soon as one does (the early returns of
`validation.cpp:445–448`, `validation.cpp:454–457`, `validation.cpp:487–489`, whose partial sums the caller never reads: `validation.cpp:1242`
refuses on the error before it compares). -/
def sumOpt : List (Option Nat) → Option Nat
  | [] => some 0
  | none :: _ => none
  | some a :: rest => (sumOpt rest).map (a + ·)

/-- No instruction of the walk is a literal `OP_INVALIDOPCODE` (`0xff`); a push that fails to decode
ends the walk as the count's does (`script.cpp:44–45`). -/
def noInvalidOp : Bytes → Bool
  | [] => true
  | op :: rest =>
    match getOpTail op rest with
    | none => true
    | some (_, k) => op != Op.OP_INVALIDOPCODE && noInvalidOp (rest.drop k)
termination_by s => s.length
decreasing_by all_goals simp [List.length_drop]

/-! The theorems (T-SO1 to T-SO9; the transaction-level ones are `BsvScript.TxPolicy`'s). -/

/-- An opcode above `OP_PUSHDATA4` parses as itself with no operand (`instruction_iterator.h:26–27`). -/
theorem getOpTail_above_pushdata4 (op : Nat) (rest : Bytes) (h : Op.OP_PUSHDATA4 < op) :
    getOpTail op rest = some ([], 0) := by
  simp [getOpTail, Nat.not_le.2 h]

/-- A push's operand is taken from the bytes after its opcode (`instruction_iterator.h:34–74`): every
byte of it is a byte of the script. -/
theorem getOpTail_mem {op : Nat} {rest data : Bytes} {k : Nat} (h : getOpTail op rest = some (data, k)) :
    ∀ b ∈ data, b ∈ rest := by
  intro b hb
  rw [getOpTail_eq_fast] at h
  unfold getOpTailFast at h
  split_ifs at h with h1
  · split at h
    · cases h
    · rename_i n p _
      rw [takeExact_eq] at h
      split_ifs at h with h2
      obtain ⟨rfl, -⟩ : List.take n (List.drop p rest) = data ∧ p + n = k := by simpa using h
      exact List.mem_of_mem_drop (List.mem_of_mem_take hb)
  · simp only [Option.some.injEq, Prod.mk.injEq] at h
    obtain ⟨rfl, -⟩ := h
    simp at hb

/-- A valid byte string of at most four bytes decodes to at most 2,147,483,647 (the magnitude below
`2^31`: the top byte's low seven bits and three bytes, `int_serialization.h:86–117`). -/
theorem decode_le_of_length_le_four (bs : Bytes) (hv : Bytes.valid bs) (hl : bs.length ≤ 4) :
    decode bs ≤ 2147483647 := by
  rw [decode_eq_signInt]
  cases hr : bs.reverse with
  | nil => simp [decodeRev, signInt]
  | cons t rest =>
    have hlen : rest.length ≤ 3 := by
      have := congrArg List.length hr; simp at this; omega
    have hvr : Bytes.valid rest := fun b hb => hv b (by
      rw [← List.mem_reverse, hr]; exact List.mem_cons_of_mem _ hb)
    have hbr : beNat rest < 256 ^ rest.length := beNat_lt rest hvr
    have hP : 256 ^ rest.length ≤ 256 ^ 3 := Nat.pow_le_pow_right (by decide) hlen
    have ht : t % 128 < 128 := Nat.mod_lt _ (by decide)
    have hm : beNat (t % 128 :: rest) < 128 * 256 ^ rest.length := by
      rw [beNat_cons]
      have : (t % 128) * 256 ^ rest.length ≤ 127 * 256 ^ rest.length := Nat.mul_le_mul_right _ (by omega)
      omega
    have hm' : beNat (t % 128 :: rest) ≤ 2147483647 := by
      have : 128 * 256 ^ rest.length ≤ 128 * 256 ^ 3 := Nat.mul_le_mul_left _ hP
      have h3 : (128 : Nat) * 256 ^ 3 = 2147483648 := by norm_num
      omega
    simp only [decodeRev]
    by_cases hs : 128 ≤ t
    · simp [signInt, hs]
    · simp [signInt, hs]
      omega

/-- The count a multisig adds is at most 2,147,483,647 when its operand is a valid byte string: 16 after
`OP_16`, 20 before Genesis, else a script number of at most four bytes (`multisigSigOps`). -/
theorem multisigSigOps_le (a g : Bool) (lo : Nat) (ld : Bytes) (hv : Bytes.valid ld) (x : Nat)
    (h : multisigSigOps a g lo ld = some x) : x ≤ 2147483647 := by
  unfold multisigSigOps at h
  split_ifs at h with h1 h2 h3
  · simp only [Option.some.injEq] at h
    simp only [Bool.and_eq_true, decide_eq_true_eq] at h1
    simp only [Op.OP_1, Op.OP_16] at h1 h
    omega
  · simp only [Option.some.injEq] at h; omega
  · split at h
    · rename_i v hv'
      split_ifs at h with h4
      simp only [Option.some.injEq] at h
      unfold readNum at hv'
      split_ifs at hv' with h5 h6
      simp only [Except.ok.injEq] at hv'
      subst hv'
      have := decode_le_of_length_le_four ld hv (by omega)
      omega
    · cases h
  · simp only [Option.some.injEq] at h
    simp only [Consensus.maxPubKeysPerMultisigBeforeGenesis] at h
    omega

/-- An instruction adds at most 2,147,483,647 (`opSigOps`). -/
theorem opSigOps_le (a g : Bool) (op lo : Nat) (ld : Bytes) (hv : Bytes.valid ld) (x : Nat)
    (h : opSigOps a g op lo ld = some x) : x ≤ 2147483647 := by
  unfold opSigOps at h
  split_ifs at h with h1 h2
  · simp only [Option.some.injEq] at h; omega
  · exact multisigSigOps_le a g lo ld hv x h
  · simp only [Option.some.injEq] at h; omega

/-- The walk's bound, generalized over the state (the induction behind T-SO1): from a count `n` on valid
bytes, every instruction adds at most 2,147,483,647 and consumes at least one byte. -/
theorem sigOpWalk_le (a g : Bool) : ∀ (fuel : Nat) (s : Bytes) (lo : Nat) (ld : Bytes) (sc : Int) (n m : Nat),
    Bytes.valid s → Bytes.valid ld → sigOpWalk a g fuel s lo ld sc n = some m →
      m ≤ n + 2147483647 * s.length := by
  intro fuel
  induction fuel with
  | zero =>
    intro s lo ld sc n m _ _ h
    simp only [sigOpWalk, Option.some.injEq] at h
    omega
  | succ f ih =>
    intro s lo ld sc n m hs hld h
    cases s with
    | nil =>
      simp only [sigOpWalk, Option.some.injEq] at h
      omega
    | cons op rest =>
      have hrest : Bytes.valid rest := fun b hb => hs b (List.mem_cons_of_mem _ hb)
      simp only [sigOpWalk] at h
      split at h
      · simp only [Option.some.injEq] at h
        omega
      · rename_i data k hgt
        have hdata : Bytes.valid data := fun b hb => hrest b (getOpTail_mem hgt b hb)
        split_ifs at h with h1 h2 h3
        · simp only [Option.some.injEq] at h; omega
        · simp only [Option.some.injEq] at h; omega
        · split at h
          · cases h
          · rename_i x hx
            have hxle := opSigOps_le a g op lo ld hld x hx
            have hdrop : Bytes.valid (rest.drop k) := fun b hb => hrest b (List.mem_of_mem_drop hb)
            have := ih (rest.drop k) op data _ (n + x) m hdrop hdata h
            simp only [List.length_drop, List.length_cons] at this ⊢
            have : 2147483647 * (rest.length - k) ≤ 2147483647 * rest.length :=
              Nat.mul_le_mul_left _ (Nat.sub_le _ _)
            rw [Nat.mul_succ]
            omega

/-- **T-SO1 (the bound).** *What it says:* on a script of valid bytes every count the node can take
(`fAccurate` or not, either era) is at most 2,147,483,647 per byte of the script. *What it assumes:*
the bytes are bytes. *Why it matters:* the count is linear in the script: an instruction adds at most
2,147,483,647 (a multisig after a four-byte push, `script.cpp:110–116`) and takes a byte; within the
after-Genesis consensus size of a transaction (1,000,000,000 bytes, `consensus.h:29`) the node's `uint64_t`
accumulator (`script.cpp:33`) never wraps, so the count modelled as a `Nat` is the node's. -/
theorem sigOpCount_le (a g : Bool) (s : Bytes) (hs : Bytes.valid s) (n : Nat)
    (h : sigOpCount a g s = some n) : n ≤ 2147483647 * s.length := by
  have := sigOpWalk_le a g s.length s Op.OP_INVALIDOPCODE [] 0 0 n hs (by simp [Bytes.valid]) h
  omega

/-- Before Genesis without `fAccurate` a multisig counts 20, whatever precedes it (`script.cpp:119–122`). -/
theorem multisigSigOps_legacy (lo : Nat) (ld : Bytes) :
    multisigSigOps false false lo ld = some Consensus.maxPubKeysPerMultisigBeforeGenesis := by
  simp [multisigSigOps]

/-- The legacy walk never fails, generalized over the state (the induction behind T-SO2): with neither
`fAccurate` nor Genesis no scope is tracked and a multisig counts 20. -/
theorem sigOpWalk_legacy_isSome : ∀ (fuel : Nat) (s : Bytes) (lo : Nat) (ld : Bytes) (n : Nat),
    ∃ m, sigOpWalk false false fuel s lo ld 0 n = some m := by
  intro fuel
  induction fuel with
  | zero => intro s lo ld n; exact ⟨n, by simp [sigOpWalk]⟩
  | succ f ih =>
    intro s lo ld n
    cases s with
    | nil => exact ⟨n, by simp [sigOpWalk]⟩
    | cons op rest =>
      simp only [sigOpWalk]
      split
      · exact ⟨n, rfl⟩
      · rename_i data k _
        have hsc : scopeAfter (false || false) op 0 = 0 := by simp [scopeAfter]
        have hadd : ∃ x, opSigOps false false op lo ld = some x := by
          unfold opSigOps
          split_ifs
          · exact ⟨1, rfl⟩
          · exact ⟨_, multisigSigOps_legacy lo ld⟩
          · exact ⟨0, rfl⟩
        obtain ⟨x, hx⟩ := hadd
        split_ifs with h1 h2 h3
        · exact ⟨n, rfl⟩
        · exact ⟨n, rfl⟩
        · rw [hsc] at h3; exact absurd h3 (by decide)
        · rw [hx]; simp only [hsc]; exact ih _ _ _ _

/-- **T-SO2 (the legacy path never fails).** *What it says:* before Genesis without `fAccurate` the count
is always a number. *What it assumes:* nothing. *Why it matters:* the error branches (`55–63`, `85–111`)
are guarded by `fAccurate || Genesis` (`43`, `74`, `79`): the consensus gate's pre-Genesis count
(`validation.cpp:559–566`) has no error to refuse on, and the mempool's before Genesis only the P2SH
part's (a redeem script's accurate count). -/
theorem sigOpCount_legacy_isSome (s : Bytes) : ∃ n, sigOpCount false false s = some n :=
  sigOpWalk_legacy_isSome s.length s Op.OP_INVALIDOPCODE [] 0

/-- **T-SO3 (an unbalanced `OP_ENDIF`).** *What it says:* under `fAccurate` or Genesis a script that
begins with `OP_ENDIF` has no count, whatever follows. *What it assumes:* `accurate || genesis`. *Why it
matters:* this is `sigOpCountError` (`script.cpp:59–67`), which the mempool refuses at any cap
(`validation.cpp:1242`): an output script opening with `OP_ENDIF` makes its transaction non-relayable
after Genesis, though no script ever runs it. -/
theorem sigOpCount_endif (a g : Bool) (h : (a || g) = true) (rest : Bytes) :
    sigOpCount a g (Op.OP_ENDIF :: rest) = none := by
  simp only [sigOpCount, List.length_cons, sigOpWalk]
  rw [getOpTail_above_pushdata4 _ _ (by decide)]
  simp [scopeAfter, h, Op.OP_ENDIF, Op.OP_INVALIDOPCODE, Op.OP_RETURN, Op.OP_IF, Op.OP_NOTIF,
    Op.OP_VERIF, Op.OP_VERNOTIF]

/-- **T-SO4 (a literal `0xff` ends the walk).** *What it says:* a script that begins with the byte `0xff`
counts nothing, whatever follows, on every path. *What it assumes:* nothing. *Why it matters:*
`decode_instruction` returns `0xff` as a valid instruction whose opcode is `OP_INVALIDOPCODE`
(`instruction_iterator.h:26–27`), and the walk stops at that opcode (`script.cpp:44–45`), as it stops at
a push that fails to decode. -/
theorem sigOpCount_ff (a g : Bool) (rest : Bytes) :
    sigOpCount a g (Op.OP_INVALIDOPCODE :: rest) = some 0 := by
  simp only [sigOpCount, List.length_cons, sigOpWalk]
  rw [getOpTail_above_pushdata4 _ _ (by decide)]
  simp

/-- **T-SO5 (a top-level `OP_RETURN` ends the walk).** *What it says:* under `fAccurate` or Genesis a script
that begins with `OP_RETURN` counts nothing, whatever follows. *What it assumes:* `accurate || genesis`.
*Why it matters:* "everything after `OP_RETURN` at top level scope is unexecutable" (`script.cpp:49–53`);
a data carrier's bytes never count after Genesis. -/
theorem sigOpCount_return (a g : Bool) (h : (a || g) = true) (rest : Bytes) :
    sigOpCount a g (Op.OP_RETURN :: rest) = some 0 := by
  simp only [sigOpCount, List.length_cons, sigOpWalk]
  rw [getOpTail_above_pushdata4 _ _ (by decide)]
  simp [h, Op.OP_RETURN, Op.OP_INVALIDOPCODE]

/-- **T-SO6 (the multisig count after Genesis reaches 2,147,483,647).** *What it says:* after Genesis
the output script `04 ffffff7f OP_CHECKMULTISIG` (six bytes) counts 2,147,483,647. *What it assumes:*
nothing. *Why it matters:* the preceding four-byte push is the largest non-negative minimal script number
(`script.cpp:102–116`); three such outputs count 6,442,450,941, past `UINT32_MAX`, the largest cap
`-maxtxsigopscountspolicy` admits (`config.cpp:2391–2415`), so the mempool refuses them at every setting
(`TxPolicy.mempoolTxPolicy_multisig_witness`). -/
theorem sigOpCount_multisig_max :
    sigOpCount false true [0x04, 0xff, 0xff, 0xff, 0x7f, Op.OP_CHECKMULTISIG] = some 2147483647 := by
  decide

/-- **T-SO7 (the multisig's three errors after Genesis).** *What it says:* after Genesis a multisig after a
five-byte push, after a non-minimal push (`05 00`) or after a negative number (`0x81`) has no count. *What it
assumes:* nothing. *Why it matters:* these are the three `sigOpCountError` cases of the operand
(`script.cpp:89–95`, `98–104`, `106–111`: a script that would fail at the opcode, "the coin unspendable"),
refused by the mempool at any cap (`validation.cpp:1242`). -/
theorem sigOpCount_multisig_errors :
    sigOpCount false true [0x05, 0x01, 0x00, 0x00, 0x00, 0x00, Op.OP_CHECKMULTISIG] = none ∧
    sigOpCount false true [0x02, 0x05, 0x00, Op.OP_CHECKMULTISIG] = none ∧
    sigOpCount false true [0x01, 0x81, Op.OP_CHECKMULTISIG] = none := by
  decide

/-- **T-SO8 (the three multisig paths).** *What it says:* `OP_2 OP_CHECKMULTISIG` counts 20 before Genesis
without `fAccurate`, 2 with it, and 2 after Genesis. *What it assumes:* nothing. *Why it matters:* the
consensus gate's pre-Genesis count charges every multisig the key limit (`script.cpp:119–122`); a P2SH
redeem script (`fAccurate`, `155–161`) and every count after Genesis read the key count from the preceding
`OP_1`–`OP_16` (`74–77`). -/
theorem sigOpCount_opN_paths :
    sigOpCount false false [Op.OP_1 + 1, Op.OP_CHECKMULTISIG] = some 20 ∧
    sigOpCount true false [Op.OP_1 + 1, Op.OP_CHECKMULTISIG] = some 2 ∧
    sigOpCount false true [Op.OP_1 + 1, Op.OP_CHECKMULTISIG] = some 2 := by
  decide

/-- **T-SO9 (the P2SH redeem count).** *What it says:* an unlocking script whose last push is the redeem
script `OP_2 OP_CHECKMULTISIG` gives the P2SH part 2; an unlocking script that is not push-only gives it 0.
*What it assumes:* nothing. *Why it matters:* the P2SH part of the mempool's count reads the redeem script
accurately (`script.cpp:159–165`) and gives up without an error on a non-push unlocking script
(`137–148`), which the script check refuses on its own (`SCRIPT_ERR_SIG_PUSHONLY`). -/
theorem p2shRedeemSigOps_examples :
    p2shRedeemSigOps [0x02, Op.OP_1 + 1, Op.OP_CHECKMULTISIG] = some 2 ∧
    p2shRedeemSigOps [Op.OP_CHECKSIG] = some 0 := by
  decide

/-- `sumOpt` fails exactly when one of its counts does. -/
theorem sumOpt_eq_none_iff (l : List (Option Nat)) : sumOpt l = none ↔ none ∈ l := by
  induction l with
  | nil => simp [sumOpt]
  | cons x rest ih =>
    cases x with
    | none => simp [sumOpt]
    | some a => simp [sumOpt, ih]

/-- `sumOpt` of an appended list. -/
theorem sumOpt_append (l₁ l₂ : List (Option Nat)) :
    sumOpt (l₁ ++ l₂) = (sumOpt l₁).bind (fun a => (sumOpt l₂).map (a + ·)) := by
  induction l₁ with
  | nil => cases h : sumOpt l₂ <;> simp [sumOpt, h]
  | cons x rest ih =>
    cases x with
    | none => simp [sumOpt]
    | some a =>
      simp only [List.cons_append, sumOpt, ih]
      cases sumOpt rest <;> cases sumOpt l₂ <;> simp [Nat.add_assoc]

/-- `sumOpt` of counts that are all zero. -/
theorem sumOpt_zeros (l : List (Option Nat)) (h : ∀ x ∈ l, x = some 0) : sumOpt l = some 0 := by
  induction l with
  | nil => rfl
  | cons x rest ih =>
    rw [h x (List.mem_cons_self ..)]
    simp [sumOpt, ih (fun y hy => h y (List.mem_cons_of_mem _ hy))]

end BsvScript.SigOps
