# Million witness replay price, 2026-09-29T23:54:31.382945+00:00 [LIT]

Model: Codex GPT-6.1-Sol. Continue [LIT] 55 item [LIT] (3). No job launched.

Source commit: caeb866cd177eeb2fadd09d7d698420b4e25cf7b.
The permitted request is S2 sitting [LIT] 8, ask [LIT] 6, on `docs/lanes/lean.md`: replay `witness-million-spec-engine.resource-abort-million-seed-969309`.
Its inherited memory input is 68.9 GB [EST] for capacity planning, read afresh from that ask.
The underlying measurement is NOT independently re-derived: its evidence record is closed to this scope. This page makes no fresh [M] footprint or completion-time claim.

## Rates and derivation

The source is `tools/modal_check.py`, parsed as data without importing or calling Modal.
CPU rate: $0.00001314 per core-second [LIT]. Memory rate: $0.00000222 per GiB-second [LIT].
These are repository rates, not a fresh billing quotation.
Proposed container: 4 vCPU [EST], 128 GiB [EST], hard wall 1800 s [EST], retries [LIT] 0, single use.
Rate calculation: (4 [EST] * 0.00001314 [LIT]) + (128 [EST] * 0.00000222 [LIT]) = $0.00033672 per second [D].
Replay at the hard wall: 1800 s [EST] * $0.00033672 per second [D] = $0.60609600 [D].
Separate cold image reserve at the existing bake's [LIT] 16 cores, [LIT] 32 GiB and [LIT] 7200 s hard wall: $2.02521600 [D].
Replay plus cold reserve: $2.63131200 [D], rounded planning ceiling $2.64 [EST].
The reserve covers the existing image bake only; no extra data transfer, storage or failed image retries are priced.

## Proposed execution, held

Use a prepared image and compiled evaluator at a named commit. Ship only the selected million witness, its driver and rule table dependencies; ship no `docs/records/`.
Place that witness alone under the job's `corpus/witnesses/` so `tools/witness.sh` does not scan unrelated witnesses.
Capture `/usr/bin/time -v`, the exit status and every replay verdict line. Require the witness script's own GREEN line, the matching class and engine verdict, and the compiled evaluator's source pin.
The box cannot be selected from the inherited footprint input; the [EST] 128 GiB container is a bounded proposal, not proof that it will complete.
No checkpoint: the hard wall and [LIT] retries 0 end the attempt without an automatic restart.

No launch is authorized in this sitting. The next sitting must read the daily meter, establish the evaluator artifact and its source pin without closed records, and check the capacity class before launch. If it cannot do so, the replay remains held.
Money spent here: $0 [M] from this run's launch inventory (no Modal command or application).

Source draft: `origin/s3-c55-harness` at `20ff1d91726bccd690db3ae055bb617aafefe4c4`, pushed; no build verdict for this tree. [LIT]
