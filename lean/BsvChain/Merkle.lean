import BsvScript.Sighash

/-!
# Block merkle roots (#63)

[SRC] bitcoin-sv v1.2.3 at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`,
src/consensus/merkle.cpp:18–50,190–282. Each level pairs adjacent hashes;
an odd final hash is padded with itself without setting `mutated`. Equality
of actual siblings at any level sets the flag. This level-wise presentation
has the same pair/lift operations as the source's binary-counter traversal.
Hash inputs are internal-order 32-byte words.
[M] 2026-10-13, #65 adds the pinned branch operations, including the null marker.
-/

namespace BsvChain
open BsvScript.Numbers BsvScript.Hash BsvScript.Tx

/-- Root plus duplicate-sibling indication, including empty/singleton false.
[SRC] src/consensus/merkle.cpp:247–255,278–281 at 6504a3af. -/
structure MerkleResult where
  root : Bytes
  mutated : Bool
  deriving DecidableEq, Repr

/-- One level: actual equal siblings count; synthetic odd padding does not.
[SRC] src/consensus/merkle.cpp:210–236,263–270 at 6504a3af. -/
def merkleLevel : List Bytes → List Bytes × Bool
  | [] => ([], false)
  | [a] => ([sha256d (a ++ a)], false)
  | a :: b :: rest =>
    let (next, mutated) := merkleLevel rest
    (sha256d (a ++ b) :: next, (a == b) || mutated)

/-- Bounded level reduction. Leaf count is sufficient fuel since each
nonterminal level strictly shrinks; zero fuel is only a total extension.
[SRC] src/consensus/merkle.cpp:215–244,247–282 at 6504a3af. -/
def merkleReduce : Nat → List Bytes → MerkleResult
  | _, [] => ⟨BsvScript.Sighash.zero32, false⟩
  | _, [a] => ⟨a, false⟩
  | 0, a :: _ :: _ => ⟨a, false⟩
  | fuel + 1, a :: b :: rest =>
    let (next, mutated) := merkleLevel (a :: b :: rest)
    let r := merkleReduce fuel next
    ⟨r.root, mutated || r.mutated⟩

/-- Executable block merkle computation with its mutation flag.
[SRC] src/consensus/merkle.cpp:247–282 at 6504a3af. -/
def computeMerkleRoot (leaves : List Bytes) : MerkleResult := merkleReduce leaves.length leaves

/-- Hash the existing transaction serializer's identifiers in block order.
[SRC] src/consensus/merkle.cpp:312–319 at 6504a3af. -/
def blockMerkleRoot (txs : List Tx) : MerkleResult :=
  computeMerkleRoot (txs.map BsvScript.Sighash.txid)

/-- [SRC] 2026-10-13: the branch sibling, with an odd terminal hash
repeated. Total out-of-range behavior is an API extension; reference positions
are unsigned 32-bit and in range. src/consensus/merkle.cpp:57-178,284-289
at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b. -/
def siblingAt : List Bytes → Nat → Bytes
  | [], _ => BsvScript.Sighash.zero32
  | [a], _ => a
  | a :: b :: _, 0 => b
  | a :: _ :: _, 1 => a
  | _ :: _ :: rest, i + 2 => siblingAt rest i

/-- [SRC] 2026-10-13: source pair ordering before hashing. A null word is
interpreted as a duplicate marker even on an odd index, as the pin does.
src/consensus/merkle.cpp:291-308 at 6504a3af. -/
def branchPair (leaf sibling : Bytes) (index : Nat) : Bytes × Bytes :=
  if sibling == BsvScript.Sighash.zero32 then (leaf, leaf)
  else if index % 2 == 1 then (sibling, leaf) else (leaf, sibling)

/-- [SRC] 2026-10-13: executable ComputeMerkleRootFromBranch. Empty branches
return the supplied leaf for every index. Nat division by two is the source's
unsigned shift; the caller's source domain has index below 2^32.
src/consensus/merkle.cpp:291-310 at 6504a3af. -/
def computeRootFromBranch : Bytes → List Bytes → Nat → Bytes
  | leaf, [], _ => leaf
  | leaf, sibling :: rest, index =>
    let pair := branchPair leaf sibling index
    computeRootFromBranch (sha256d (pair.1 ++ pair.2)) rest (index / 2)

/-- [SRC] 2026-10-13: root equality, with no implicit chain or position claim.
src/consensus/merkle.cpp:291-310 at 6504a3af. -/
def verifyPath (leaf : Bytes) (path : List Bytes) (index : Nat) (root : Bytes) : Bool :=
  computeRootFromBranch leaf path index == root

/-- [SRC] 2026-10-13: bounded level-wise ComputeMerkleBranch, with the same
fuel as merkleReduce. Synthetic padding emits the actual repeated hash,
whereas the RPC's '*' marker denotes a null word (#75's codec).
src/consensus/merkle.cpp:57-178,284-289 at 6504a3af. -/
def branchReduce : Nat → List Bytes → Nat → List Bytes
  | _, [], _ => []
  | _, [_], _ => []
  | 0, _ :: _ :: _, _ => []
  | fuel + 1, a :: b :: rest, index =>
    siblingAt (a :: b :: rest) index ::
      branchReduce fuel (merkleLevel (a :: b :: rest)).1 (index / 2)

/-- [SRC] 2026-10-13: branch of the ordered transaction identifiers, beside
blockMerkleRoot; raw hash lists use branchReduce.
src/consensus/merkle.cpp:284-289,322-327 at 6504a3af. -/
def computeBranch (txs : List Tx) (index : Nat) : List Bytes :=
  branchReduce txs.length (txs.map BsvScript.Sighash.txid) index

end BsvChain
