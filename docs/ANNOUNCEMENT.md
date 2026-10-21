# The announcement (archived #34)

The maintainers' ruling of 2026-10-17 chose the recommended sentence of the draft (2026-10-17, against `main` at `0b997779`; its two alternates are not landed) [M]; the ruling is quoted on archived #34. Nothing here is posted automatically: the maintainers post it on the publication day, after the public repository's first push (archived #113).

The slots filled for the publication day, and only these: the public repository's address, `https://github.com/Calhooon/bsv-script-lean` (the maintainers' word of 2026-10-21: the Calhooon organisation, the name unchanged); and the pin, which reads v1.2.3 at `6504a3a` on `main` at `662bae70` (read 2026-10-18) [M] and is re-read from `NOTICE` on the publication day's tree. No figure is carried: the counts move with every landing, and `docs/WRITE-UP.md` carries them with their records.

## The sentence

> bsv-script-lean is now public: the consensus rules of the bitcoin-sv node at release v1.2.3 for script, the transaction checks and the transaction state machine, written down as a Lean 4 definition that runs, every rule cited to the node's source at that release, and a harness that runs the same transactions through the definition and the node and reports a disagreement as a witness transaction (a class under a maintainer's open disclosure is withheld by name and counted until its fix); it is a specification and a test harness, not a node or a wallet, and it is read at `https://github.com/Calhooon/bsv-script-lean`, starting with `docs/WRITE-UP.md`.

## The five lines, for a forum post

> 1. **What it is.** bsv-script-lean: the consensus rules of the bitcoin-sv node at v1.2.3 written as a Lean 4 definition that runs, from script through the transaction checks and the state machine around them, every rule cited to the node's source at that release.
> 2. **How it is judged.** A corpus of transactions runs through the definition and through the node at the pin, and through bsv-rs, go-sdk, @bsv/sdk and Teranode; each published disagreement is a witness transaction with the rule it exercises, and every published run has its record in the repository.
> 3. **What it is not.** Not a node, a wallet or an application; it does not prove the node correct, and where the two disagree the chain follows the node until people decide; policy limits are named parameters with their defaults, never consensus.
> 4. **Check it yourself.** `cd lean && lake build` (no `sorry`), `tools/axiom_check.py` (only Lean's three standard axioms) and `eval/bsvs --self-test`; the harness by `harness/README.md`'s prerequisites; read `docs/WRITE-UP.md`, then `docs/HYPOTHESES.md` for the trust boundary.
> 5. **Licence and contact.** The spec and the material derived from the node are under the Open BSV License Version 5 (use on the BSV blockchains); the tooling is under Apache-2.0, by path as `NOTICE` says; a divergence goes to the issue tracker and a security concern goes privately through the private vulnerability reporting form (the "Report a vulnerability" button under the Security tab), as `docs/WRITE-UP.md` section 11 says; every pinned upstream is read monthly and in the week it releases, and a consensus change opens an issue that week (`docs/WRITE-UP.md` section 12): `https://github.com/Calhooon/bsv-script-lean`.

## The checks applied to both

- No ordinal priority word, no novelty adjective, no unqualified conformance word, no licence adjective the maintainers retired, no long dash (`tools/wording_gate.sh` over this page).
- "Consensus" names only what the spec defines as consensus; the policy limits are named as parameters in line 3.
- Nothing of the withheld classes and no name of a filed report: the implementations named in line 2 are the ones `README.md` already names.
- The contact route of line 5 is the one `docs/WRITE-UP.md` section 11 and `README.md` name (the maintainers' rule: the association's email is not used).
