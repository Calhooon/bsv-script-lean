import BsvScript.Machine
import BsvScript.Ops.Arith
/-!
# BsvScript.Ops.Stack

The stack opcodes (#10; `docs/DESIGN.md` §3): `OP_TOALTSTACK` … `OP_TUCK`
(`interpreter.cpp:876–1055`) and `OP_SIZE` (`1057–1064`), on the `LimitedStack`
(`src/script/limitedstack.cpp`): a copy pushed costs its size plus the overhead
against the budget (`push_back`, `limitedstack.h:163–173`), an erased element
releases it (`erase`, `limitedstack.cpp:260–267`), a swap costs nothing
(`:285–288`), an insert costs like a push (`:269–283`), and a move between the
main stack and its child alt stack costs nothing (`moveTopToStack`, `:290–302`).
Bare line numbers are `interpreter.cpp` at the pin (`docs/PROVENANCE.md`).
The stack is held top-first (`State.stack`), so the element `k` below the top
is index `k`.
-/

namespace BsvScript.Ops.Stack
open BsvScript.Params BsvScript.Numbers BsvScript.Machine

/-- `stacktop(-(k+1))` (`limitedstack.cpp:226–233`); every caller checks the depth first. -/
def topAt (st : State) (k : Nat) : Bytes := st.stack.getD k []

/-- `swapElements` (`limitedstack.cpp:285–288`) on two positions counted from the top. -/
def swapTop (st : State) (i j : Nat) : State :=
  let a := topAt st i
  let b := topAt st j
  { st with stack := (st.stack.set i b).set j a }

/-- `erase(-(k+1))` (`limitedstack.cpp:260–267`): the element `k` below the top
removed, its size and overhead released. -/
def eraseTop (st : State) (k : Nat) : State :=
  let x := topAt st k
  { st with stack := st.stack.eraseIdx k, memUsed := st.memUsed - (x.length + elementOverhead) }

/-- `insert(position, element)` (`limitedstack.cpp:269–283`): the element inserted
`k` below the top, charged like a push. -/
def insertTop (env : Env) (st : State) (k : Nat) (x : Bytes) : Except ScriptError State :=
  let need := st.memUsed + x.length + elementOverhead
  if need > env.params.limits.maxStackMemoryUsage then .error .stackSize
  else .ok { st with stack := st.stack.insertIdx k x, memUsed := need }

/-- `CScriptNum(bsv::bint{n}, params.MaxScriptNumLength())` pushed (`OP_DEPTH`
`968`, `OP_SIZE` `1062`): the constructor refuses an encoding wider than the
number width in force (`script_num.cpp:45–51`, `scriptnum_overflow_error`; 4
bytes for a pre-Genesis coin on either path, and after Genesis the consensus width
on the block path and the node's policy setting on the mempool path, as for
`Ops.Arith.readOperand`). -/
def pushCount (env : Env) (st : State) (n : Nat) : Except ScriptError State :=
  let bs := encode n
  if env.params.limits.maxScriptNumLength < bs.length then .error .scriptnumOverflow
  else pushElem env st bs

def need (st : State) (n : Nat) : Except ScriptError Unit :=
  if st.stack.length < n then .error .invalidStackOperation else .ok ()

-- `need`'s compiled form (#48): the depth test walks at most `n` elements (`Machine.atLeast`).
def needFast (st : State) (n : Nat) : Except ScriptError Unit :=
  if atLeast n st.stack then .ok () else .error .invalidStackOperation

/-- `@[csimp]` (#48): the compiler runs `needFast`, which walks at most `n` elements of the stack
(`Machine.atLeast_eq`) where `need`'s `st.stack.length < n` measures it whole: every compiled caller of `need`
declared after this lemma (`toAlt`, `execStack`, the splice and crypto families) runs it; nothing in the
semantics moves, every theorem about `need` is about the definition. -/
@[csimp] theorem need_eq_fast : @need = @needFast := by
  funext st n
  unfold need needFast
  by_cases h : st.stack.length < n
  · have h' : atLeast n st.stack = false := by rw [atLeast_eq, decide_eq_false_iff_not]; omega
    simp [h, h']
  · have h' : atLeast n st.stack = true := by rw [atLeast_eq, decide_eq_true_eq]; omega
    simp [h, h']

/-- `OP_TOALTSTACK` (`876–881`) and `OP_FROMALTSTACK` (`883–888`): a move
between the stacks, no accounting. -/
def toAlt (st : State) : Except ScriptError State := do
  need st 1
  match st.stack with
  | x :: rest => pure { st with stack := rest, alt := x :: st.alt }
  | [] => throw .invalidStackOperation
def fromAlt (st : State) : Except ScriptError State :=
  match st.alt with
  | x :: rest => pure { st with stack := x :: st.stack, alt := rest }
  | [] => throw .invalidAltstackOperation

def execStack (env : Env) (op : Nat) (st : State) : Except ScriptError State := do
  if op = Op.OP_TOALTSTACK then toAlt st
  else if op = Op.OP_FROMALTSTACK then fromAlt st
  else if op = Op.OP_2DROP then                                              -- 890–897
    need st 2
    let (_, st) ← popElem st
    let (_, st) ← popElem st
    pure st
  else if op = Op.OP_2DUP then                                               -- 899–908
    need st 2
    let st ← pushElem env st (topAt st 1)
    pushElem env st (topAt st 1)
  else if op = Op.OP_3DUP then                                               -- 910–921
    need st 3
    let st ← pushElem env st (topAt st 2)
    let st ← pushElem env st (topAt st 2)
    pushElem env st (topAt st 2)
  else if op = Op.OP_2OVER then                                              -- 923–932
    need st 4
    let st ← pushElem env st (topAt st 3)
    pushElem env st (topAt st 3)
  else if op = Op.OP_2ROT then                                               -- 934–944
    need st 6
    pure (swapTop (swapTop (swapTop (swapTop st 0 2) 1 3) 0 4) 1 5)
  else if op = Op.OP_2SWAP then                                              -- 946–953
    need st 4
    pure (swapTop (swapTop st 3 1) 2 0)
  else if op = Op.OP_IFDUP then                                              -- 955–964
    need st 1
    if castToBool (topAt st 0) then pushElem env st (topAt st 0) else pure st
  else if op = Op.OP_DEPTH then pushCount env st st.stack.length            -- 966–970
  else if op = Op.OP_DROP then                                               -- 972–978
    need st 1
    let (_, st) ← popElem st
    pure st
  else if op = Op.OP_DUP then                                                -- 980–987
    need st 1
    pushElem env st (topAt st 0)
  else if op = Op.OP_NIP then                                                -- 989–995
    need st 2
    pure (eraseTop st 1)
  else if op = Op.OP_OVER then                                               -- 997–1004
    need st 2
    pushElem env st (topAt st 1)
  else if op = Op.OP_PICK || op = Op.OP_ROLL then                            -- 1006–1027
    need st 2
    let (top, st) ← popElem st
    let n ← Arith.readOperand env top
    if n < 0 || (st.stack.length : Int) ≤ n then throw .invalidStackOperation
    let k := n.toNat
    let x := topAt st k
    let st := if op = Op.OP_ROLL then eraseTop st k else st
    pushElem env st x
  else if op = Op.OP_ROT then                                                -- 1029–1038
    need st 3
    pure (swapTop (swapTop st 2 1) 1 0)
  else if op = Op.OP_SWAP then                                               -- 1040–1046
    need st 2
    pure (swapTop st 1 0)
  else if op = Op.OP_TUCK then                                               -- 1048–1055
    need st 2
    insertTop env st 2 (topAt st 0)
  else                                                                       -- OP_SIZE, 1057–1064
    need st 1
    pushCount env st (topAt st 0).length

-- `execStack`'s compiled form (#48): `OP_PICK`/`OP_ROLL`'s bound (`1017–1018`) and its fetch share ONE walk to
-- the picked depth (`st.stack[n]?`: `none` is the bound's refusal, `some x` the element `topAt` reads), where the
-- definition measures the whole stack and then walks again to fetch; its `need` calls run `needFast`
-- (`need_eq_fast`).
def execStackFast (env : Env) (op : Nat) (st : State) : Except ScriptError State := do
  if op = Op.OP_TOALTSTACK then toAlt st
  else if op = Op.OP_FROMALTSTACK then fromAlt st
  else if op = Op.OP_2DROP then                                              -- 890–897
    need st 2
    let (_, st) ← popElem st
    let (_, st) ← popElem st
    pure st
  else if op = Op.OP_2DUP then                                               -- 899–908
    need st 2
    let st ← pushElem env st (topAt st 1)
    pushElem env st (topAt st 1)
  else if op = Op.OP_3DUP then                                               -- 910–921
    need st 3
    let st ← pushElem env st (topAt st 2)
    let st ← pushElem env st (topAt st 2)
    pushElem env st (topAt st 2)
  else if op = Op.OP_2OVER then                                              -- 923–932
    need st 4
    let st ← pushElem env st (topAt st 3)
    pushElem env st (topAt st 3)
  else if op = Op.OP_2ROT then                                               -- 934–944
    need st 6
    pure (swapTop (swapTop (swapTop (swapTop st 0 2) 1 3) 0 4) 1 5)
  else if op = Op.OP_2SWAP then                                              -- 946–953
    need st 4
    pure (swapTop (swapTop st 3 1) 2 0)
  else if op = Op.OP_IFDUP then                                              -- 955–964
    need st 1
    if castToBool (topAt st 0) then pushElem env st (topAt st 0) else pure st
  else if op = Op.OP_DEPTH then pushCount env st st.stack.length            -- 966–970
  else if op = Op.OP_DROP then                                               -- 972–978
    need st 1
    let (_, st) ← popElem st
    pure st
  else if op = Op.OP_DUP then                                                -- 980–987
    need st 1
    pushElem env st (topAt st 0)
  else if op = Op.OP_NIP then                                                -- 989–995
    need st 2
    pure (eraseTop st 1)
  else if op = Op.OP_OVER then                                               -- 997–1004
    need st 2
    pushElem env st (topAt st 1)
  else if op = Op.OP_PICK || op = Op.OP_ROLL then                            -- 1006–1027
    need st 2
    let (top, st) ← popElem st
    let n ← Arith.readOperand env top
    let r := st.stack[n.toNat]?
    if n < 0 || r.isNone then throw .invalidStackOperation
    let k := n.toNat
    let x := r.getD []
    let st := if op = Op.OP_ROLL then eraseTop st k else st
    pushElem env st x
  else if op = Op.OP_ROT then                                                -- 1029–1038
    need st 3
    pure (swapTop (swapTop st 2 1) 1 0)
  else if op = Op.OP_SWAP then                                               -- 1040–1046
    need st 2
    pure (swapTop st 1 0)
  else if op = Op.OP_TUCK then                                               -- 1048–1055
    need st 2
    insertTop env st 2 (topAt st 0)
  else                                                                       -- OP_SIZE, 1057–1064
    need st 1
    pushCount env st (topAt st 0).length

/-- **`pickBound_eq`.** *What it says:* `OP_PICK`/`OP_ROLL`'s refusal test, a negative index or an index at or
past the depth, reads the same as "negative, or the stack has no element at that index". *What it assumes:*
nothing. *Why it matters:* it lets `execStackFast` decide the bound and fetch the element in one walk to the
picked depth, where the definition measures the whole stack first (#48). -/
theorem pickBound_eq (n : Int) (l : List Bytes) :
    (decide (n < 0) || decide ((l.length : Int) ≤ n)) = (decide (n < 0) || (l[n.toNat]?).isNone) := by
  rcases Int.lt_or_le n 0 with h | h
  · simp [h]
  · have hn : ((n.toNat : Nat) : Int) = n := Int.toNat_of_nonneg h
    have h0 : ¬ n < 0 := by omega
    by_cases h2 : (l.length : Int) ≤ n
    · have h3 : l.length ≤ n.toNat := by omega
      simp [h0, h2, h3]
    · have h3 : n.toNat < l.length := by omega
      simp [h0, h2, h3]

/-- `@[csimp]` (#48): the compiler runs `execStackFast`, whose `OP_PICK`/`OP_ROLL` bound and fetch share one walk
to the picked depth (`pickBound_eq`, with `topAt`'s `getD` read as the same lookup) and whose depth tests run
`needFast`; nothing in the semantics moves, every theorem about `execStack` is about the definition. -/
@[csimp] theorem execStack_eq_fast : @execStack = @execStackFast := by
  funext env op st
  unfold execStack execStackFast
  simp only [pickBound_eq, topAt, List.getD_eq_getElem?_getD]

/-- The family hook: `OP_TOALTSTACK` `0x6b` … `OP_TUCK` `0x7d`, and `OP_SIZE` `0x82`. -/
def exec : OpExec := fun op _ env st =>
  if (Op.OP_TOALTSTACK ≤ op && op ≤ Op.OP_TUCK) || op = Op.OP_SIZE then some (execStack env op st)
  else none

end BsvScript.Ops.Stack

namespace BsvScript.Ops.Stack
open BsvScript.Numbers BsvScript.Machine

/-! ## Widths -/

/-- T-S1: a swap keeps the depth (`swapElements`, `limitedstack.cpp:285–288`). -/
theorem swapTop_length (st : State) (i j : Nat) : (swapTop st i j).stack.length = st.stack.length := by
  simp [swapTop]

/-- T-S2: an erase below the top removes one element (`erase`, `limitedstack.cpp:260–267`). -/
theorem eraseTop_length (st : State) (k : Nat) (h : k < st.stack.length) :
    (eraseTop st k).stack.length = st.stack.length - 1 := by
  simp [eraseTop, List.length_eraseIdx, h]

end BsvScript.Ops.Stack
