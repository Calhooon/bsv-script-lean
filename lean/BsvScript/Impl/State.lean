import BsvScript.Impl.Elem
/-!
# BsvScript.Impl.State: the implementation state of lean #50, slice (a)

The machine's state for the compiled evaluator, with the main stack as an array held bottom-first (the top at
`back`), as SV-node's `LimitedStack` holds its `std::vector` (`limitedstack.h:88`): the element `k` below the
top is one index (`stacktop(-(k+1))`, `limitedstack.cpp:226–233`), the depth is `size` (`307–310`), a push
and a pop are at the end. `IState.abs` reads an implementation state as the spec's `Machine.State` (the list
top-first); every helper below is proven to commute with `abs`, so a family written over them computes what
the spec's family computes (#50's design, its comment 5884618665). Nothing here is the semantics: the
definitions stay `Machine.State` and its functions, and every theorem about them stays about them. Since #143 every
element is an `Impl.Elem` (a packed `ByteArray`, `Impl/Elem.lean`), read as the spec's `Bytes` by `Elem.toBytes`.
-/

set_option autoImplicit false

namespace BsvScript.Impl
open BsvScript.Params BsvScript.Numbers BsvScript.Machine BsvScript.Ops.Stack

/-! ## Three facts about a reversed list -/

/-- **`reverse_set`.** *What it says:* setting index `i` of a list and reversing is setting index
`length − 1 − i` of the reversed list. *What it assumes:* `i` is inside the list. *Why it matters:* the
implementation writes the element `k` below the top at array index `size − 1 − k` (#50). -/
theorem reverse_set {α : Type} (l : List α) (i : Nat) (x : α) (h : i < l.length) :
    (l.set i x).reverse = l.reverse.set (l.length - 1 - i) x := by
  apply List.ext_getElem
  · simp
  · intro j h1 h2
    have hj : j < l.length := by simpa using h1
    rw [List.getElem_reverse, List.getElem_set, List.getElem_set, List.getElem_reverse]
    simp only [List.length_set]
    split_ifs <;> first | rfl | (exfalso; omega)

/-- **`reverse_eraseIdx`.** *What it says:* erasing index `i` of a list and reversing is erasing index
`length − 1 − i` of the reversed list. *What it assumes:* `i` is inside the list. *Why it matters:* the
implementation's `OP_ROLL` erases the element `k` below the top at array index `size − 1 − k` (#50). -/
theorem reverse_eraseIdx {α : Type} (l : List α) (i : Nat) (h : i < l.length) :
    (l.eraseIdx i).reverse = l.reverse.eraseIdx (l.length - 1 - i) := by
  rw [List.eraseIdx_eq_take_drop_succ, List.eraseIdx_eq_take_drop_succ, List.reverse_append,
    List.take_reverse, List.drop_reverse]
  have h1 : l.length - (l.length - 1 - i) = i + 1 := by omega
  have h2 : l.length - (l.length - 1 - i + 1) = i := by omega
  rw [h1, h2]

/-- **`reverse_insertIdx`.** *What it says:* inserting at index `i` of a list and reversing is inserting at
index `length − i` of the reversed list. *What it assumes:* `i ≤ length`. *Why it matters:* the
implementation's `OP_TUCK` inserts `k` below the top at array index `size − k` (#50). -/
theorem reverse_insertIdx {α : Type} (l : List α) (i : Nat) (x : α) (h : i ≤ l.length) :
    (l.insertIdx i x).reverse = l.reverse.insertIdx (l.length - i) x := by
  apply List.ext_getElem
  · simp [List.length_insertIdx, h]
  · intro j h1 h2
    have hj : j < l.length + 1 := by simpa [List.length_insertIdx, h] using h1
    rw [List.getElem_reverse, List.getElem_insertIdx, List.getElem_insertIdx]
    simp only [List.length_insertIdx, h, ↓reduceIte]
    by_cases hlt : j < l.length - i
    · have hA : ¬ (l.length + 1 - 1 - j < i) := by omega
      have hB : ¬ (l.length + 1 - 1 - j = i) := by omega
      simp only [hlt, hA, hB, ↓reduceDIte, List.getElem_reverse]
      congr 1; omega
    · by_cases heq : j = l.length - i
      · subst heq
        have hB : l.length + 1 - 1 - (l.length - i) = i := by omega
        have hC : ¬ (l.length - i < l.length - i) := by omega
        have hD : ¬ (i < i) := Nat.lt_irrefl i
        simp only [hB, hC, hD, ↓reduceDIte]
      · have hA : l.length + 1 - 1 - j < i := by omega
        simp only [hlt, heq, hA, ↓reduceDIte, List.getElem_reverse]
        congr 1; omega

/-! ## The implementation state and its abstraction -/

/-- The implementation state (#50): `Machine.State`'s fields, the main stack as an array held bottom-first
(its top at `back`). The alt stack stays a list: only its top is ever touched (`interpreter.cpp:876–888`). Every
element is a packed `Elem` (#143). The scriptCode's start `codeSep` stays the script's own suffix (`Bytes`): it is
not a stack element, `OP_CODESEPARATOR` takes it by `drop` without a copy, and a packed copy at every separator
would cost the rest of the script each time. -/
structure IState where
  stack : Array Elem := #[]
  alt : List Elem := []
  memUsed : Nat := 0
  cond : Cond := {}
  opCount : Nat := 0
  nonTopLevelReturn : Bool := false
  codeSep : Bytes := []

namespace IState

/-- The spec's state an implementation state stands for: the array reversed into the top-first list, every
element read as its bytes (`Elem.toBytes`, #143), every other field copied. -/
def abs (s : IState) : State :=
  { stack := s.stack.toList.reverse.map Elem.toBytes, alt := s.alt.map Elem.toBytes, memUsed := s.memUsed,
    cond := s.cond, opCount := s.opCount, nonTopLevelReturn := s.nonTopLevelReturn, codeSep := s.codeSep }

/-- An implementation state for a spec state (the loop's entry): each element packed (`Elem.ofBytes`). -/
def ofState (st : State) : IState :=
  { stack := (st.stack.reverse.map Elem.ofBytes).toArray, alt := st.alt.map Elem.ofBytes, memUsed := st.memUsed,
    cond := st.cond, opCount := st.opCount, nonTopLevelReturn := st.nonTopLevelReturn, codeSep := st.codeSep }

/-- **`abs_ofState`.** *What it says:* the implementation state made from a spec state whose elements are bytes
stands for it. *What it assumes:* every element of both stacks is `Bytes.valid` (a byte at or above 256 has no
packed form). *Why it matters:* the implementation loop starts from the spec's initial state. -/
theorem abs_ofState (st : State) (hs : ∀ x ∈ st.stack, Bytes.valid x) (ha : ∀ x ∈ st.alt, Bytes.valid x) :
    (ofState st).abs = st := by
  have e1 : st.stack.reverse.reverse.map (Elem.toBytes ∘ Elem.ofBytes) = st.stack := by
    rw [List.reverse_reverse]
    conv_rhs => rw [← List.map_id st.stack]
    exact List.map_congr_left (fun x hx => Elem.toBytes_ofBytes x (hs x hx))
  have e2 : st.alt.map (Elem.toBytes ∘ Elem.ofBytes) = st.alt := by
    conv_rhs => rw [← List.map_id st.alt]
    exact List.map_congr_left (fun x hx => Elem.toBytes_ofBytes x (ha x hx))
  simp only [abs, ofState, List.toList_toArray, List.map_map, ← List.map_reverse, e1, e2]

/-- **`ofState_abs`.** *What it says:* reading an implementation state as the spec's and back gives it again:
`abs` loses nothing. *What it assumes:* nothing. *Why it matters:* the machine's refinement states each step
as the spec's step read back (#50). -/
theorem ofState_abs (s : IState) : ofState s.abs = s := by
  rcases s with ⟨a, alt, mem, cond, opc, ntr, cs⟩
  have e : (Elem.ofBytes ∘ Elem.toBytes) = id := funext Elem.ofBytes_toBytes
  simp [abs, ofState, List.map_reverse, e]

/-- **`abs_cond`.** *What it says:* the spec state's `cond` is the implementation's. *What it assumes:*
nothing. *Why it matters:* the conditionals' state, read by the loop's `fExec` and the flow opcodes (#50). -/
theorem abs_cond (s : IState) : s.abs.cond = s.cond := rfl
/-- **`abs_alt`.** *What it says:* the spec state's `alt` is the implementation's. *What it assumes:*
nothing. *Why it matters:* the alt stack, read by the pre-Genesis depth test (#50). -/
theorem abs_alt (s : IState) : s.abs.alt = s.alt.map Elem.toBytes := rfl
/-- **`abs_memUsed`.** *What it says:* the spec state's `memUsed` is the implementation's. *What it assumes:*
nothing. *Why it matters:* the memory counter, read by every push and pop (#50). -/
theorem abs_memUsed (s : IState) : s.abs.memUsed = s.memUsed := rfl
/-- **`abs_nonTopLevelReturn`.** *What it says:* the spec state's `nonTopLevelReturn` is the implementation's. *What it assumes:*
nothing. *Why it matters:* the post-Genesis `OP_RETURN` mark, read by the loop's `fExec` (#50). -/
theorem abs_nonTopLevelReturn (s : IState) : s.abs.nonTopLevelReturn = s.nonTopLevelReturn := rfl
/-- **`abs_codeSep`.** *What it says:* the spec state's `codeSep` is the implementation's. *What it assumes:*
nothing. *Why it matters:* the scriptCode's start, read by the signature checks (#50). -/
theorem abs_codeSep (s : IState) : s.abs.codeSep = s.codeSep := rfl

/-- **`ofState_size`.** *What it says:* the implementation state made from a spec state has the spec's depth.
*What it assumes:* nothing. *Why it matters:* the pre-Genesis depth test after each step (#50). -/
theorem ofState_size (st : State) : (ofState st).stack.size = st.stack.length := by
  simp [ofState]

end IState

/-! ## The array's top, read as the top-first list -/

/-- **`arr_back_none`.** *What it says:* an array with no last element reads as the empty top-first list.
*What it assumes:* `a.back? = none`. *Why it matters:* the flow opcodes' and the verdict's empty-stack cases
(#50). -/
theorem arr_back_none (a : Array Elem) (h : a.back? = none) : a.toList.reverse.map Elem.toBytes = [] := by
  rw [Array.back?_eq_none_iff] at h
  subst h
  rfl

/-- **`arr_back_some`.** *What it says:* an array whose last element is `x` reads as `x`'s bytes on top of its
`pop`. *What it assumes:* `a.back? = some x`. *Why it matters:* the flow opcodes' and the verdict's reads of the
top (#50). -/
theorem arr_back_some (a : Array Elem) (x : Elem) (h : a.back? = some x) :
    a.toList.reverse.map Elem.toBytes = Elem.toBytes x :: a.pop.toList.reverse.map Elem.toBytes := by
  obtain ⟨ys, rfl⟩ := Array.back?_eq_some_iff.mp h
  simp [Array.pop_push]

namespace IState

/-- **`abs_stack_of_back_none`.** *What it says:* an implementation state with no top stands for the empty
stack. *What it assumes:* `s.stack.back? = none`. *Why it matters:* the flow opcodes' empty-stack cases (#50). -/
theorem abs_stack_of_back_none (s : IState) (h : s.stack.back? = none) : s.abs.stack = [] :=
  arr_back_none s.stack h

/-- **`abs_stack_of_back_some`.** *What it says:* an implementation state whose top is `x` stands for `x` on
top of its `pop`. *What it assumes:* `s.stack.back? = some x`. *Why it matters:* the flow opcodes' reads of the
top (#50). -/
theorem abs_stack_of_back_some (s : IState) (x : Elem) (h : s.stack.back? = some x) :
    s.abs.stack = Elem.toBytes x :: s.stack.pop.toList.reverse.map Elem.toBytes :=
  arr_back_some s.stack x h

end IState

/-! ## The array helpers, each proven to commute with `abs` -/

/-- The element `k` below the top (`stacktop(-(k+1))`, `limitedstack.cpp:226–233`), the empty element past the
depth as `Ops.Stack.topAt` reads `[]`. -/
def topArr (a : Array Elem) (k : Nat) : Elem :=
  if h : k < a.size then a[a.size - 1 - k] else Elem.empty

/-- **`topArr_eq`.** *What it says:* the bytes of the array's element `k` below the top are the top-first list's
element `k`. *What it assumes:* nothing. *Why it matters:* `OP_PICK`'s fetch in one step (#50). -/
theorem topArr_eq (a : Array Elem) (k : Nat) :
    Elem.toBytes (topArr a k) = (a.toList.reverse.map Elem.toBytes).getD k [] := by
  unfold topArr
  rw [List.getD_eq_getElem?_getD]
  split
  · rename_i h
    rw [List.getElem?_eq_getElem (by rw [List.length_map, List.length_reverse, Array.length_toList]; omega)]
    simp [List.getElem_reverse]
  · rename_i h
    rw [List.getElem?_eq_none (by rw [List.length_map, List.length_reverse, Array.length_toList]; omega)]
    rfl

/-- The element `k` below the top replaced (`swapElements`'s halves, `limitedstack.cpp:285–288`); past the
depth nothing moves, as `List.set` past the end. -/
def setTopArr {α : Type} (a : Array α) (k : Nat) (x : α) : Array α :=
  if k < a.size then a.setIfInBounds (a.size - 1 - k) x else a

/-- **`setTopArr_eq`.** *What it says:* replacing the array's element `k` below the top is `List.set k` on
the top-first list. *What it assumes:* nothing. *Why it matters:* the swaps and rotations (#50). -/
theorem setTopArr_eq {α : Type} (a : Array α) (k : Nat) (x : α) :
    (setTopArr a k x).toList.reverse = a.toList.reverse.set k x := by
  unfold setTopArr
  split
  · rename_i h
    rw [Array.toList_setIfInBounds, reverse_set _ _ _ (by rw [Array.length_toList]; omega)]
    congr 1
    simp; omega
  · rename_i h
    rw [List.set_eq_of_length_le (by rw [List.length_reverse, Array.length_toList]; omega)]

/-- The element `k` below the top erased (`erase(-(k+1))`, `limitedstack.cpp:260–267`); past the depth
nothing moves, as `List.eraseIdx` past the end. -/
def eraseTopArr {α : Type} (a : Array α) (k : Nat) : Array α :=
  if k < a.size then a.eraseIdxIfInBounds (a.size - 1 - k) else a

/-- **`eraseTopArr_eq`.** *What it says:* erasing the array's element `k` below the top is
`List.eraseIdx k` on the top-first list. *What it assumes:* nothing. *Why it matters:* `OP_ROLL` (#50). -/
theorem eraseTopArr_eq {α : Type} (a : Array α) (k : Nat) :
    (eraseTopArr a k).toList.reverse = a.toList.reverse.eraseIdx k := by
  unfold eraseTopArr
  split
  · rename_i h
    rw [Array.toList_eraseIdxIfInBounds, reverse_eraseIdx _ _ (by rw [Array.length_toList]; omega)]
    congr 1
    simp; omega
  · rename_i h
    rw [List.eraseIdx_of_length_le (by rw [List.length_reverse, Array.length_toList]; omega)]

/-- An element inserted `k` below the top (`insert(position, element)`, `limitedstack.cpp:269–283`); past the
depth nothing moves, as `List.insertIdx` past the end. -/
def insertTopArr {α : Type} (a : Array α) (k : Nat) (x : α) : Array α :=
  if h : k ≤ a.size then a.insertIdx (a.size - k) x (by omega) else a

/-- **`insertTopArr_eq`.** *What it says:* inserting `k` below the array's top is `List.insertIdx k` on the
top-first list. *What it assumes:* nothing. *Why it matters:* `OP_TUCK` (#50). -/
theorem insertTopArr_eq {α : Type} (a : Array α) (k : Nat) (x : α) :
    (insertTopArr a k x).toList.reverse = a.toList.reverse.insertIdx k x := by
  unfold insertTopArr
  split
  · rename_i h
    rw [Array.toList_insertIdx, reverse_insertIdx _ _ _ (by rw [Array.length_toList]; omega)]
    congr 1
    simp; omega
  · rename_i h
    rw [List.insertIdx_of_length_lt (by rw [List.length_reverse, Array.length_toList]; omega)]

/-! ## The state's helpers, each proven to commute with `abs` (the spec's `Machine` and `Ops.Stack` helpers) -/

namespace IState

/-- `Machine.pushElem` on the implementation state: the element at the array's end, charged its size plus the
overhead (`limitedstack.h:163–173`). -/
def pushElemI (env : Env) (s : IState) (x : Elem) : Except ScriptError IState :=
  let need := s.memUsed + x.size + elementOverhead
  if need > env.params.limits.maxStackMemoryUsage then .error .stackSize
  else .ok { s with stack := s.stack.push x, memUsed := need }

/-- **`pushElemI_abs`.** *What it says:* the implementation's push stands for the spec's push of the element's
bytes. *What it assumes:* nothing. *Why it matters:* every push of every family (#50). -/
theorem pushElemI_abs (env : Env) (s : IState) (x : Elem) :
    (pushElemI env s x).map abs = pushElem env s.abs (Elem.toBytes x) := by
  unfold pushElemI pushElem
  rw [Elem.length_toBytes]
  by_cases hc : s.memUsed + x.size + elementOverhead > env.params.limits.maxStackMemoryUsage
  · simp [hc, Except.map, abs]
  · simp [hc, Except.map, abs]

/-- `Machine.popElem` on the implementation state: the array's last element, its charge released
(`limitedstack.cpp:211–219`). -/
def popElemI (s : IState) : Except ScriptError (Elem × IState) :=
  match s.stack.back? with
  | none => .error .invalidStackOperation
  | some x => .ok (x, { s with stack := s.stack.pop, memUsed := s.memUsed - (x.size + elementOverhead) })

/-- **`popElemI_abs`.** *What it says:* the implementation's pop stands for the spec's, the popped element's
bytes the same. *What it assumes:* nothing. *Why it matters:* every pop of every family (#50). -/
theorem popElemI_abs (s : IState) :
    (popElemI s).map (fun p => (Elem.toBytes p.1, p.2.abs)) = popElem s.abs := by
  rcases s with ⟨a, alt, mem, cond, opc, ntr, cs⟩
  unfold popElemI popElem abs
  cases h : a.back? with
  | none =>
    rw [Array.back?_eq_none_iff] at h
    subst h
    simp [Except.map]
  | some x =>
    obtain ⟨ys, rfl⟩ := Array.back?_eq_some_iff.mp h
    simp [Except.map, Array.pop_push]

/-- `Ops.Stack.topAt` on the implementation state: one index. -/
def topAtI (s : IState) (k : Nat) : Elem := topArr s.stack k

/-- **`topAtI_abs`.** *What it says:* the implementation reads the element `k` below the top that the spec
reads. *What it assumes:* nothing. *Why it matters:* `OP_PICK`'s fetch and every read below the top (#50). -/
theorem topAtI_abs (s : IState) (k : Nat) : Elem.toBytes (topAtI s k) = topAt s.abs k := by
  unfold topAtI topAt abs
  exact topArr_eq s.stack k

/-- `Ops.Stack.swapTop` on the implementation state. -/
def swapTopI (s : IState) (i j : Nat) : IState :=
  let a := topAtI s i
  let b := topAtI s j
  { s with stack := setTopArr (setTopArr s.stack i b) j a }

/-- **`swapTopI_abs`.** *What it says:* the implementation's swap stands for the spec's. *What it assumes:*
nothing. *Why it matters:* `OP_SWAP`, `OP_ROT`, `OP_2SWAP`, `OP_2ROT` (#50). -/
theorem swapTopI_abs (s : IState) (i j : Nat) : (swapTopI s i j).abs = swapTop s.abs i j := by
  unfold swapTopI swapTop
  simp only [← topAtI_abs]
  simp only [abs, setTopArr_eq, List.map_set]

/-- `Ops.Stack.eraseTop` on the implementation state. -/
def eraseTopI (s : IState) (k : Nat) : IState :=
  let x := topAtI s k
  { s with stack := eraseTopArr s.stack k, memUsed := s.memUsed - (x.size + elementOverhead) }

/-- **`eraseTopI_abs`.** *What it says:* the implementation's erase stands for the spec's, the charge
released the same. *What it assumes:* nothing. *Why it matters:* `OP_ROLL`, `OP_NIP` (#50). -/
theorem eraseTopI_abs (s : IState) (k : Nat) : (eraseTopI s k).abs = eraseTop s.abs k := by
  unfold eraseTopI eraseTop
  simp only [← topAtI_abs, Elem.length_toBytes]
  simp only [abs, eraseTopArr_eq, List.eraseIdx_map]

/-- `Ops.Stack.insertTop` on the implementation state. -/
def insertTopI (env : Env) (s : IState) (k : Nat) (x : Elem) : Except ScriptError IState :=
  let need := s.memUsed + x.size + elementOverhead
  if need > env.params.limits.maxStackMemoryUsage then .error .stackSize
  else .ok { s with stack := insertTopArr s.stack k x, memUsed := need }

/-- **`insertTopI_abs`.** *What it says:* the implementation's insert stands for the spec's, charged the
same. *What it assumes:* nothing. *Why it matters:* `OP_TUCK` (#50). -/
theorem insertTopI_abs (env : Env) (s : IState) (k : Nat) (x : Elem) :
    (insertTopI env s k x).map abs = insertTop env s.abs k (Elem.toBytes x) := by
  unfold insertTopI insertTop
  rw [Elem.length_toBytes]
  by_cases hc : s.memUsed + x.size + elementOverhead > env.params.limits.maxStackMemoryUsage
  · simp [hc, Except.map, abs]
  · simp [hc, Except.map, abs, insertTopArr_eq, List.map_insertIdx]

/-- `Ops.Stack.pushCount` on the implementation state. -/
def pushCountI (env : Env) (s : IState) (n : Nat) : Except ScriptError IState :=
  let bs := Elem.encode n
  if env.params.limits.maxScriptNumLength < bs.size then .error .scriptnumOverflow
  else pushElemI env s bs

/-- **`pushCountI_abs`.** *What it says:* the implementation's count push stands for the spec's. *What it
assumes:* nothing. *Why it matters:* `OP_DEPTH`, `OP_SIZE` (#50). -/
theorem pushCountI_abs (env : Env) (s : IState) (n : Nat) :
    (pushCountI env s n).map abs = pushCount env s.abs n := by
  unfold pushCountI pushCount
  simp only [← Elem.length_toBytes, Elem.toBytes_encode]
  by_cases hc : env.params.limits.maxScriptNumLength < (encode (n : Int)).length
  · simp [hc, Except.map]
  · simp only [hc, ↓reduceIte]
    rw [pushElemI_abs, Elem.toBytes_encode]

/-- `Ops.Stack.need` on the implementation state: the depth is `size`, read in one step. -/
def needI (s : IState) (n : Nat) : Except ScriptError Unit :=
  if s.stack.size < n then .error .invalidStackOperation else .ok ()

/-- **`needI_abs`.** *What it says:* the implementation's depth test answers as the spec's. *What it
assumes:* nothing. *Why it matters:* every depth test of every family, in constant time (#50). -/
theorem needI_abs (s : IState) (n : Nat) : needI s n = need s.abs n := by
  unfold needI need abs
  simp

/-- **`depth_abs`.** *What it says:* the implementation's depth is the spec's. *What it assumes:* nothing.
*Why it matters:* `OP_DEPTH` and the pre-Genesis depth test, in constant time (#50). -/
theorem depth_abs (s : IState) : s.stack.size = s.abs.stack.length := by
  simp [abs]

/-- `Ops.Stack.toAlt` on the implementation state. -/
def toAltI (s : IState) : Except ScriptError IState := do
  needI s 1
  match s.stack.back? with
  | some x => pure { s with stack := s.stack.pop, alt := x :: s.alt }
  | none => throw .invalidStackOperation

/-- **`toAltI_abs`.** *What it says:* the implementation's move to the alt stack stands for the spec's.
*What it assumes:* nothing. *Why it matters:* `OP_TOALTSTACK` (#50). -/
theorem toAltI_abs (s : IState) : (toAltI s).map abs = toAlt s.abs := by
  rcases s with ⟨a, alt, mem, cond, opc, ntr, cs⟩
  unfold toAltI toAlt
  rw [← needI_abs]
  unfold needI abs
  cases h : a.back? with
  | none =>
    rw [Array.back?_eq_none_iff] at h
    subst h
    rfl
  | some x =>
    obtain ⟨ys, rfl⟩ := Array.back?_eq_some_iff.mp h
    simp [Except.map, Array.pop_push]

/-- `Ops.Stack.fromAlt` on the implementation state. -/
def fromAltI (s : IState) : Except ScriptError IState :=
  match s.alt with
  | x :: rest => pure { s with stack := s.stack.push x, alt := rest }
  | [] => throw .invalidAltstackOperation

/-- **`fromAltI_abs`.** *What it says:* the implementation's move from the alt stack stands for the spec's.
*What it assumes:* nothing. *Why it matters:* `OP_FROMALTSTACK` (#50). -/
theorem fromAltI_abs (s : IState) : (fromAltI s).map abs = fromAlt s.abs := by
  rcases s with ⟨a, alt, mem, cond, opc, ntr, cs⟩
  unfold fromAltI fromAlt abs
  cases alt with
  | nil => rfl
  | cons x rest =>
    show Except.ok _ = Except.ok _
    simp [Array.toList_push]

/-! ## The helpers' lemmas in the form the family proofs rewrite with (the spec's call on the left) -/

/-- **`need_abs`.** *What it says:* `needI_abs` with the spec's side on the left. *What it assumes:* nothing.
*Why it matters:* the family proofs rewrite the spec's side with it (#50). -/
theorem need_abs (s : IState) (n : Nat) : need s.abs n = needI s n := (needI_abs s n).symm
/-- **`topAt_abs`.** *What it says:* `topAtI_abs` with the spec's side on the left. *What it assumes:* nothing.
*Why it matters:* the family proofs rewrite the spec's side with it (#50). -/
theorem topAt_abs (s : IState) (k : Nat) : topAt s.abs k = Elem.toBytes (topAtI s k) := (topAtI_abs s k).symm
/-- **`pushElem_abs`.** *What it says:* `pushElemI_abs` with the spec's side on the left. *What it assumes:* nothing.
*Why it matters:* the family proofs rewrite the spec's side with it (#50). -/
theorem pushElem_abs (env : Env) (s : IState) (x : Elem) :
    pushElem env s.abs (Elem.toBytes x) = abs <$> pushElemI env s x := (pushElemI_abs env s x).symm
/-- **`popElem_abs`.** *What it says:* `popElemI_abs` with the spec's side on the left. *What it assumes:* nothing.
*Why it matters:* the family proofs rewrite the spec's side with it (#50). -/
theorem popElem_abs (s : IState) :
    popElem s.abs = (fun p : Elem × IState => (Elem.toBytes p.1, p.2.abs)) <$> popElemI s := (popElemI_abs s).symm
/-- **`swapTop_abs`.** *What it says:* `swapTopI_abs` with the spec's side on the left. *What it assumes:* nothing.
*Why it matters:* the family proofs rewrite the spec's side with it (#50). -/
theorem swapTop_abs (s : IState) (i j : Nat) : swapTop s.abs i j = (swapTopI s i j).abs :=
  (swapTopI_abs s i j).symm
/-- **`eraseTop_abs`.** *What it says:* `eraseTopI_abs` with the spec's side on the left. *What it assumes:* nothing.
*Why it matters:* the family proofs rewrite the spec's side with it (#50). -/
theorem eraseTop_abs (s : IState) (k : Nat) : eraseTop s.abs k = (eraseTopI s k).abs := (eraseTopI_abs s k).symm
/-- **`insertTop_abs`.** *What it says:* `insertTopI_abs` with the spec's side on the left. *What it assumes:* nothing.
*Why it matters:* the family proofs rewrite the spec's side with it (#50). -/
theorem insertTop_abs (env : Env) (s : IState) (k : Nat) (x : Elem) :
    insertTop env s.abs k (Elem.toBytes x) = abs <$> insertTopI env s k x := (insertTopI_abs env s k x).symm
/-- **`pushCount_abs`.** *What it says:* `pushCountI_abs` with the spec's side on the left. *What it assumes:* nothing.
*Why it matters:* the family proofs rewrite the spec's side with it (#50). -/
theorem pushCount_abs (env : Env) (s : IState) (n : Nat) :
    pushCount env s.abs n = abs <$> pushCountI env s n := (pushCountI_abs env s n).symm
/-- **`toAlt_abs`.** *What it says:* `toAltI_abs` with the spec's side on the left. *What it assumes:* nothing.
*Why it matters:* the family proofs rewrite the spec's side with it (#50). -/
theorem toAlt_abs (s : IState) : toAlt s.abs = abs <$> toAltI s := (toAltI_abs s).symm
/-- **`fromAlt_abs`.** *What it says:* `fromAltI_abs` with the spec's side on the left. *What it assumes:* nothing.
*Why it matters:* the family proofs rewrite the spec's side with it (#50). -/
theorem fromAlt_abs (s : IState) : fromAlt s.abs = abs <$> fromAltI s := (fromAltI_abs s).symm
/-- **`length_abs`.** *What it says:* `depth_abs` with the spec's side on the left. *What it assumes:* nothing.
*Why it matters:* the family proofs rewrite the spec's side with it (#50). -/
theorem length_abs (s : IState) : s.abs.stack.length = s.stack.size := (depth_abs s).symm

/-- **`headD_abs`.** *What it says:* the spec's read of the top with `[]` for an empty stack is the
implementation's `topAtI s 0`. *What it assumes:* nothing. *Why it matters:* `OP_NUMEQUALVERIFY`'s and the
verdict's reads of the top (#50). -/
theorem headD_abs (s : IState) : s.abs.stack.headD [] = Elem.toBytes (topAtI s 0) := by
  rw [topAtI_abs]
  unfold topAt
  cases s.abs.stack <;> rfl

/-- **`isEmpty_abs`.** *What it says:* the spec's stack is empty exactly when the array is. *What it
assumes:* nothing. *Why it matters:* `OP_CHECKMULTISIG`'s dummy test and the verdict (#50). -/
theorem isEmpty_abs (s : IState) : s.abs.stack.isEmpty = s.stack.isEmpty := by
  simp [abs]

/-- **`throw_bind_except`.** *What it says:* a failure followed by anything is the failure. *What it assumes:*
nothing. *Why it matters:* the `do` blocks' `if … then throw …` lines, whose continuation the elaborator copies
into both branches; this collapses the failing copy (#50). -/
theorem throw_bind_except {α β : Type} (e : ScriptError) (f : α → Except ScriptError β) :
    ((throw e : Except ScriptError α) >>= f) = throw e := rfl

/-- **`map_throw_except`.** *What it says:* a failure read through any function is the failure. *What it
assumes:* nothing. *Why it matters:* the families' failures, read as the spec's (#50). -/
theorem map_throw_except {α β : Type} (f : α → β) (e : ScriptError) :
    (f <$> (throw e : Except ScriptError α)) = throw e := rfl

/-- **`abs_opCount`.** *What it says:* the spec state's op count is the implementation's. *What it assumes:*
nothing. *Why it matters:* the op-count tests of the loop and of `OP_CHECKMULTISIG` (#50). -/
theorem abs_opCount (s : IState) : s.abs.opCount = s.opCount := rfl

/-- **`abs_withOpCount`.** *What it says:* the spec state with its op count replaced is the implementation
state with its op count replaced, read as the spec's. *What it assumes:* nothing. *Why it matters:* the op
count's charges in the loop (`466–467`) and in `OP_CHECKMULTISIG` (`1527–1536`) (#50). -/
theorem abs_withOpCount (s : IState) (n : Nat) :
    ({ stack := s.abs.stack, alt := s.abs.alt, memUsed := s.abs.memUsed, cond := s.abs.cond, opCount := n,
       nonTopLevelReturn := s.abs.nonTopLevelReturn, codeSep := s.abs.codeSep } : State) =
      ({ s with opCount := n } : IState).abs := rfl

/-- **`popTail_abs`.** *What it says:* the implementation's "pop the top and continue with the rest" stands for
the spec's `match popElem st with | .ok (_, st') => pure st' | .error e => throw e`. *What it assumes:*
nothing. *Why it matters:* the `VERIFY` forms' final pop (`OP_EQUALVERIFY`, `OP_NUMEQUALVERIFY`), closed by
`exact` against each family's own `match` (#50). -/
theorem popTail_abs (x : IState) :
    (popElemI x >>= fun t => pure t.2.abs) =
      (match (fun p : Elem × IState => (Elem.toBytes p.1, p.2.abs)) <$> popElemI x with
        | .ok (_, st') => pure st'
        | .error e => throw e : Except ScriptError State) := by
  cases popElemI x <;> rfl

end IState

/-! ## A family's result over the implementation state, and what a family refinement is -/

/-- `Machine.HookR` over the implementation state. -/
inductive HookRI where
  | ok (s : IState)
  | fail (e : ScriptError)
  | undefined (family : String)

namespace HookRI

/-- The spec's result a family result stands for. -/
def abs : HookRI → HookR
  | .ok s => .ok s.abs
  | .fail e => .fail e
  | .undefined f => .undefined f

/-- `Machine.HookR.ofExcept` over the implementation state. -/
def ofExcept : Except ScriptError IState → HookRI
  | .ok s => .ok s
  | .error e => .fail e

/-- **`abs_ofExcept`.** *What it says:* reading an `Except` result as a family result commutes with `abs`.
*What it assumes:* nothing. *Why it matters:* the families written with `Except` (#50). -/
theorem abs_ofExcept (e : Except ScriptError IState) :
    (ofExcept e).abs = HookR.ofExcept (IState.abs <$> e) := by
  cases e <;> rfl

end HookRI

/-- A family's `Except` result is a `HookRI` (as `Machine`'s coercion for `HookR`). -/
instance : Coe (Except ScriptError IState) HookRI := ⟨HookRI.ofExcept⟩

/-- `Machine.OpExec` over the implementation state. -/
abbrev OpExecI := Nat → Bytes → Env → IState → Option HookRI

/-- The family proofs' descent: through the `if`s and the binds both sides share after the helpers' lemmas have
rewritten the spec's side, down to the leaves, each left for the proof to close. -/
macro "impl_descend" : tactic =>
  `(tactic| repeat' (first | (apply ite_congr rfl <;> intro _) | (apply bind_congr; intro _)))

/-- An implementation hook refines a spec hook when, on every opcode, push data, environment and state, it
answers what the spec's hook answers on the spec state the implementation state stands for: `none` for
`none`, the same failure, the same undefined family, or a state standing for the spec's. -/
def Refines (exec : OpExec) (execI : OpExecI) : Prop :=
  ∀ op data env s, (execI op data env s).map HookRI.abs = exec op data env s.abs

/-- **`dispatch_abs`.** *What it says:* a dispatcher that asks a family first whether it owns the opcode, and
gives the state to it alone if so, refines the spec's "try this family, else the rest". *What it assumes:* the
family answers `none` off its opcodes and some answer on them, and the rest refines the spec's rest. *Why it
matters:* the machine's hook hands its state to one family, so the array is never shared (#50). -/
theorem dispatch_abs (o : Bool) (x rest : Option HookRI) (restS : Option HookR)
    (hn : o = false → x = none) (hs : o = true → x.isSome = true) (hr : rest.map HookRI.abs = restS) :
    (if o then x else rest).map HookRI.abs = (x.map HookRI.abs <|> restS) := by
  cases o with
  | false =>
    rw [hn rfl]
    simp only [Bool.false_eq_true, ↓reduceIte]
    exact hr
  | true =>
    obtain ⟨r, hx⟩ := Option.isSome_iff_exists.mp (hs rfl)
    subst hx
    rfl

end BsvScript.Impl
