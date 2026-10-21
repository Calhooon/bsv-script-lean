> Original path: [redacted 2026-10-12: machine]
> Date: 2026-09-19
> Author window: the planning window (W0)
> [M] Moved into the spec's tree on 2026-10-12 under the uplift the owner ruled on 2026-10-11; checked by lane uplift-chk on 2026-10-12 from the supplied redacted copy; every cut is marked in place.
> [LIT] 2026-10-12: this page records the brief of 2026-09-19, including its proposed scope, schedule, funding and license; its claims stand at that historical date. The current spec and rulings are indexed in the repository's README.

---

# BRIEF: a public, executable, machine-checked specification of BSV script consensus (2026-09-19)

**Status: a decision brief for the owner. Nothing created yet.** The owner's
words: *"I feel like we'd want this ... might be able to ask for a grant for
all of this."* This page says what the deliverable would be, what it must not
contain, what it costs, who might fund it, what it does to the two private
programs, and the decisions it needs. Every number is `[E]`.

---

## 1. The deliverable, in one paragraph

A Lean 4 formalization of the BSV script interpreter's **consensus** semantics
after Genesis and under the current Chronicle branch: the full opcode set,
unbounded script numbers and their encoding rules, the sighash preimage and
its FORKID variants, both malleability-flag branches (version-1 spends with
the flags on, version-2 spends with them off), the activation rules that
select a branch, and the policy limits modelled as explicit parameters rather
than baked in. The semantics is **executable**: Lean compiles it to a
reference evaluator with a command-line interface that decides a spend given
the transaction and its previous outputs. Beside it, a **conformance harness**:
a corpus of transactions (generated and mutated; [redacted 2026-10-12: private program])
run against SV-node, Teranode, bsv-rs
and the Lean evaluator, with every disagreement reported as a witness
transaction and the rule it exercises. Public repository, a license allowing broad reuse,
from its opening commit.

What it is not: not [redacted 2026-10-12: private program], not our transactions. It is the machine everyone runs, written down once so that every
implementation can be checked against it.

## 2. Why it is worth publishing before the rest

- **It is the one artifact of this program that discloses nothing.** An
  interpreter semantics carries no [redacted 2026-10-12: private program]; [redacted 2026-10-12: private program] is untouched. The
  corpus must be synthetic (our own transactions never enter it).
- [redacted 2026-10-12: private program]
- **It answers a problem the ecosystem has now.** Teranode must match SV-node's
  interpreter, and the places implementations diverge are exactly the places
  a formal semantics pins: the bignum edge cases, minimal encoding, the sighash
  preimage, and branches like the one we read from source where four
  malleability flags hang on a single expression that is off for version-2
  spends under Chronicle. A conformance oracle with witnesses is how that
  parity gets settled instead of argued.
- **It compounds.** A [redacted 2026-10-12: private program], a verified script compiler, and [redacted 2026-10-12: private program] all stand on this semantics. So does
  every wallet library's test suite.
- **It is the credible public face** of "the public is the audit": a stranger
  runs `lake build` and the harness, and the claim checks itself.

Prior art to read before any claim: academic formalizations of pre-Genesis
Bitcoin script exist, and Simplicity is formalized in Coq. I found no public,
executable, machine-checked semantics of BSV's post-Genesis consensus with a
conformance harness; verify that before writing a sentence about it, and
avoid priority claims (the wording rule stands).

## 3. Scope, milestones, time

| milestone | what lands | `[E]` |
|---|---|---|
| S0 · Birth | the public repo, the license, the design note, the CI that runs `lake build` and the axiom check | 1 week |
| S1 · The core semantics | the opcode subset our machines use: stack, arithmetic on unbounded numbers, encodings, hashing, the sighash preimage, the version-2 branch; the evaluator compiled; the seed corpus passing against bsv-rs | 2 to 3 months |
| S2 · The full consensus | every opcode, the version-1 branch, the activation rules, policy limits as parameters, the FORKID sighash variants; the spec document generated from the Lean sources | 3 to 6 months |
| S3 · The conformance harness | generators and mutators; runs against SV-node, Teranode, bsv-rs; the divergence report with witness transactions; the harness usable by any implementation team | 1 to 2 months |
| S4 · Review and release | an independent Lean review, the hypotheses page, the write-up, v1.0 | 1 month |

Six to twelve months total on the booked pace, overlapping where it can. The
long pole is S2. Running a Teranode instance for S3 is infrastructure work in
its own right; the Teranode team providing a test endpoint would remove it.

## 4. Cost and the grant angle

Compute is a laptop plus one node host. The cost is time: six to twelve months
of one senior engineer with AI lanes, an independent Lean reviewer for S4, and
a node host. That is the shape of a grant proposal.

Candidates, to be checked rather than assumed:

| funder | why they would care | what to ask |
|---|---|---|
| [redacted 2026-10-12: funding] |  |  |
| [redacted 2026-10-12: private program] |  |  |
| infrastructure and wallet teams on BSV | every library ships an interpreter and a test suite; the harness replaces guesswork | co-funding or in-kind test corpora |

What a grant must never cover: [redacted 2026-10-12: private program]. Grant money brings disclosure and reporting; those programs
stay private until proven and ruled. The proposal is for the specification
and the harness only.

## 5. What it does to the two private programs

- [redacted 2026-10-12: private program]
- [redacted 2026-10-12: private program]
- **attention:** a third program forks the owner's attention again. The
  mitigation is that S1 is work [redacted 2026-10-12: private program], and that the fan-
  out machine now exists. S2 to S4 are the true increment, and a grant is what
  pays for that increment's time.
- **the joint plan:** the reuse map gains a row ([redacted 2026-10-12: private program]); the master plan gains a third column if the owner opens it.

## 6. Boundaries that must hold

- The corpus is synthetic. No transaction of ours, no txid, no block number
  of ours, ever enters the public repo.
- The repo's issues and discussion never reference [redacted 2026-10-12: private program].
- Policy limits are parameters of the semantics, not consensus facts; the
  spec says which is which, in the Atlas's five kinds.
- The wording rules apply: no priority claims; scope every claim to the hypotheses.

## 7. Decisions for the owner

1. **Open it or not**, and if so the name (working title: `bsv-script-lean`)
   and the license (allowing broad reuse).
2. **Public from the opening commit**, or private through S1 and public at S2.
   The brief recommends public from the opening commit: there is nothing in it to
   protect, and the early visibility is what makes the grant conversation real.
3. **The grant path**: write the proposal now (this page is its skeleton) and
   approach [redacted 2026-10-12: funding] before S1, or build S1 and approach with a
   working core. The brief recommends building S1 in public before the ask, because
   a running evaluator on a public corpus is the proposal.
4. **Its place in the machine**: a third conductor column in the master plan,
   worked by the same one-window fan-out.

*Update rule: delete the sentence you falsify, re-stamp the date, never a banner
over a wrong line.*
