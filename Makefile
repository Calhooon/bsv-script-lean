# [export: 1 target withheld by tools/export_public.py, its recipe runs a binary the Cargo transform dropped; the original is in the private history]
# bsv-script-lean: the tripwire. `make check` must be GREEN before anything lands
# (CLAUDE.md rule 6). Seeded 2026-09-22 (#3): `lake build` sorry-free + the axiom
# check on the theorems listed in lean/AxiomCheck.lean + the evaluator self-test
# (eval/bsvs --self-test, real since #14) + the harness smoke run (real since #4).
# A stub, if one ever returns, says so on its own line; a stub is not a pass.
.PHONY: check check-local check-modal check-box check-pins fmtcheck clippy citecheck jscpd deny gosdk-build gosdk-signer-build gobdk-build tssdk-install tssdk-signer-build tslint enginesdiff lean axioms numcheck flowcheck sighashcheck arithcheck stackcheck cryptocheck seedcheck scripttests txtests flagscheck spec speccheck teranode-map bytescheck versiongatecheck erascheck witnesscheck eval harness diff seed numvectors flowcases sighashvectors arithvectors arithcases stackcases ecdsavectors cryptocases bytescases eracases policywitnesses opnames mainnetread clean-lean export-public export-gate bench verify
# `make check` routes itself (tools/check_route.sh; D17b, 2026-09-24, as D156 amended it, 2026-09-28): the twenty-nine legs run
# locally under a 1-minute load of 20 (or on the box itself) and ON THE BOX above it (tools/check_box.sh); in a container on
# Modal (tools/modal_check.py, profile <modal-name>, cpu 16 / 32 GiB, retries 0, the price in the source) only when MAKE_CHECK=modal;
# MAKE_CHECK=local|box|modal forces a home. Every home runs tools/check.sh all and writes its record (docs/records/).
# THE MAKEFILE'S SHELLS AND ITS PATH (RULES-TREE (28), 2026-09-28; the maintainers' ruling of 2026-09-29, from a review's
# Finding): GNU make 3.81 finds a recipe's FIRST WORD on its OWN startup PATH, the caller's, never on the PATH
# exported below; so every shell a recipe starts is named by absolute path (/usr/bin/env, /bin/bash), with BASH_ENV unset and no
# startup file (a ~/.zshenv with NO_EXEC or a BASH_ENV with `set -n` reads a script without running it and exits 0). The PATH the
# recipes' children read is the toolchains' directories (elan, cargo, the container's Go and Node, the box's spec toolchains),
# then the system's (Homebrew, /usr/local, /usr/bin, /bin), then the caller's. tools/node_bin.sh still prefers $NODE_BIN and nvm v22.
SHELL := /bin/sh
TOOLCHAIN_DIRS := $(HOME)/.elan/bin $(HOME)/.cargo/bin /usr/local/cargo/bin /usr/local/go/bin /usr/local/node/bin \
  $(HOME)/bsv/targets/spec-box/toolchains/go/bin $(HOME)/bsv/targets/spec-box/toolchains/node/bin
SYSTEM_DIRS := /opt/homebrew/bin /opt/homebrew/sbin /usr/local/bin /usr/bin /bin /usr/sbin /sbin
empty :=
space := $(empty) $(empty)
export PATH := $(subst $(space),:,$(strip $(TOOLCHAIN_DIRS) $(SYSTEM_DIRS))):$(PATH)
unexport BASH_ENV ENV
CLEAN_BASH = /usr/bin/env -u BASH_ENV /bin/bash --noprofile --norc
CLEAN_BASH_WITH = /usr/bin/env -u BASH_ENV $(1) /bin/bash --noprofile --norc
# `make` alone prints the targets (#174): every .PHONY target carries a `## <one line>` directly above its rule line, and a
# `## @group <name>` line opens a group; `make help` prints them by group (tools/make_help_check.py, the fmt leg, refuses
# a .PHONY target without its line).
.DEFAULT_GOAL := help
.PHONY: help
## @group verify and build

## list the targets by group (the default goal)
help:
	@awk -v order="verify and build|the harness|the generators|the gates and checks|the maintainers' routes" 'BEGIN { n = split(order, gs, "|") } /^## @group / { g = substr($$0, 11); d = ""; next } /^## / { d = substr($$0, 4); next } /^[A-Za-z0-9_.-]+:/ && d != "" { t = $$0; sub(/:.*/, "", t); rows[g] = rows[g] sprintf("  make %-20s %s\n", t, d); d = ""; next } { d = "" } END { print "bsv-script-lean: make <target>; make verify runs the four commands of README.md (Verify the base)"; for (i = 1; i <= n; i++) if (gs[i] in rows) printf "\n%s:\n%s", gs[i], rows[gs[i]] }' $(firstword $(MAKEFILE_LIST))
## @group the gates and checks

## the tripwire: every leg, routed by load (tools/check_route.sh); writes its record under docs/records/
check:
	@$(CLEAN_BASH) tools/check_route.sh
## the tripwire on this machine, whatever the load (tools/check.sh all)
check-local:
	@$(CLEAN_BASH) tools/check.sh all
## @group the maintainers' routes

## the tripwire in a cloud container (tools/modal_check.py; needs the maintainers' account)
check-modal:
	@$(call CLEAN_BASH_WITH,MAKE_CHECK=modal) tools/check_route.sh
## the tripwire on the maintainers' build machine (tools/check_box.sh)
check-box:
	@$(call CLEAN_BASH_WITH,MAKE_CHECK=box) tools/check_route.sh
## @group the gates and checks

# The pins leg alone (#40): docs/PROVENANCE.md §1a against every site; fails on drift.
# [M] 2026-10-13: pins includes the chain purity lint (#77).
## the pins leg alone: docs/PROVENANCE.md section 1a against every site, and the chain purity lint
check-pins:
	@$(CLEAN_BASH) tools/check.sh pins

## @group the harness

# #145, #147: on demand and once per signer pin move; outside the twenty-nine check legs.
.PHONY: check-signer
## the signer column, on demand once per signer pin move (archived #145)
check-signer:
	@$(CLEAN_BASH) tools/check_signer.sh

## @group the gates and checks

# Derived finality boundaries (#60). The scenario leg joins the tripwire at #66.
.PHONY: finalitycheck
## the derived finality boundaries (#60)
finalitycheck:
	@$(CLEAN_BASH) tools/finality_check.sh

# Derived UTXO boundaries (#61). The scenario leg joins the tripwire at #66.
.PHONY: utxocheck
## the derived UTXO boundaries (#61)
utxocheck:
	@$(CLEAN_BASH) tools/utxo_check.sh

# Script-oracle agreement (#76). Joins the scenario leg at #66.
.PHONY: oraclecheck
## the script oracle agreement (#76)
oraclecheck:
	@$(CLEAN_BASH) tools/oracle_check.sh

# #63: standalone corpus check; the scenario tripwire joins at #66.
.PHONY: blockcheck
## the public headers and the derived block boundaries (#63)
blockcheck:
	@$(CLEAN_BASH) tools/block_check.sh

# Derived mempool policy boundaries (#62). Node scenarios remain #66.
.PHONY: mempoolcheck
## the derived mempool policy boundaries (#62)
mempoolcheck:
	@$(CLEAN_BASH) tools/mempool_check.sh

# Derived chain transitions (#64). Standalone until the #66 scenario leg.
.PHONY: chaincheck
## the derived chain transitions (#64)
chaincheck:
	@$(CLEAN_BASH) tools/chain_check.sh

## @group the generators

# The public edition (#46; NORTH-STAR constitution 05; docs/PROVENANCE.md §4): the tree of COMMIT (default HEAD) less
# tools/export_withheld.txt's paths, into an empty directory under $(HOME)/bsv/targets/spec-export/ (default a UTC stamp),
# with its manifest; then the grep gate on it (default the newest export): mechanism, pointer and wording legs, exit 0
# clean, 1 on a hit, 2 when a sibling tree of tools/mechanism_check.sh is absent on this machine. BUILD=1 adds the build leg
# (#107; the flip day's FULL gate): the exported harness built offline and cold as a stranger would (tools/export_gate.py --build).
## write the public edition of COMMIT (default HEAD) with its manifest under the export directory
export-public:
	@$(CLEAN_BASH) tools/export_public.sh "$(or $(COMMIT),HEAD)" $(TARGET)
## @group the gates and checks

## the grep gate on the newest export (or EXPORT=<dir>); BUILD=1 adds the cold offline build
export-gate:
	@$(CLEAN_BASH) tools/export_gate.sh "$(or $(EXPORT),$(shell ls -td $(HOME)/bsv/targets/spec-export/*/ 2>/dev/null | head -1))" $(if $(BUILD),--build)

# The formatting leg alone (#134, 2026-10-14): cargo fmt --check on the harness crate at the pinned rustfmt.
## the fmt leg alone: cargo fmt --check on the harness, and every .PHONY target's help line
fmtcheck:
	@$(CLEAN_BASH) tools/check.sh fmt
# The clippy leg alone (#132): the harness under harness/Cargo.toml's lint table (unwrap, expect, panic denied), -D warnings.
## the clippy leg alone: the harness under -D warnings
clippy:
	@$(CLEAN_BASH) tools/check.sh clippy
# The citation leg alone (#43, S4b): every anchored file:line citation of lean/ and docs/ against the pinned sources.
## the citation leg alone: every file:line citation against the pinned sources
citecheck:
	@$(CLEAN_BASH) tools/check.sh cite
# The copy-paste leg alone (#138, 2026-10-14): jscpd over harness/ and tools/ under tools/jscpd/.jscpd.json's threshold.
## the copy-paste leg alone over harness/ and tools/
jscpd:
	@$(CLEAN_BASH) tools/check.sh jscpd
# The deny leg alone (#133, 2026-10-14): tools/cargo_deny.sh, cargo-deny at its pin against harness/deny.toml.
## the deny leg alone: cargo-deny on the harness crate
deny:
	@$(CLEAN_BASH) tools/check.sh deny
## @group verify and build

## build the Lean libraries and the check executables (the lean leg)
lean:
	@$(CLEAN_BASH) tools/check.sh lean
# `make axioms` builds first: `lake env lean` builds nothing, so alone it checked the previous build's oleans
# (lean #32's second lens, C-13).
## build, then the axiom check on the theorems of lean/AxiomCheck.lean
axioms: lean
	@$(CLEAN_BASH) tools/check.sh axioms
## @group the gates and checks

## the numbers leg: the Numbers module against the bsv-rs vectors
numcheck:
	@$(CLEAN_BASH) tools/check.sh numbers
## the flow leg: the flow corpus and the kernel sample
flowcheck:
	@$(CLEAN_BASH) tools/check.sh flow
## the sighash leg: the digests against the vectors and mainnet signatures
sighashcheck:
	@$(CLEAN_BASH) tools/check.sh sighash
## the arithmetic and bitwise leg
arithcheck:
	@$(CLEAN_BASH) tools/check.sh arith
## the stack and splice leg
stackcheck:
	@$(CLEAN_BASH) tools/check.sh stack
## the crypto leg: the hash and ECDSA vectors, mainnet inputs, signature cases
cryptocheck:
	@$(CLEAN_BASH) tools/check.sh crypto
## the seed leg: the seed corpus through the evaluator, and the records index
seedcheck:
	@$(CLEAN_BASH) tools/check.sh seed
## the reference's script_tests.json at the pin
scripttests:
	@$(CLEAN_BASH) tools/check.sh scripttests
## the reference's tx_valid.json and tx_invalid.json under every flag word
txtests:
	@$(CLEAN_BASH) tools/check.sh txtests
## both branches under the derived block and mempool words against bsv-rs
flagscheck:
	@$(CLEAN_BASH) tools/check.sh flags
## every byte 0x00 to 0xff under both versions against bsv-rs
bytescheck:
	@$(CLEAN_BASH) tools/check.sh bytes
## the four version-gated restrictions at every read site
versiongatecheck:
	@$(CLEAN_BASH) tools/check.sh versiongate
## the era boundaries, the activation heights and P2SH
erascheck:
	@$(CLEAN_BASH) tools/check.sh eras
## the policy-default witnesses under both nodes' derived parameters
witnesscheck:
	@$(CLEAN_BASH) tools/check.sh witnesses
## @group verify and build

## the evaluator's self-test (eval/bsvs --self-test)
eval:
	@$(CLEAN_BASH) tools/check.sh eval
## @group the gates and checks

## the harness leg: the smoke run, the differential and the classifier replay on the seed
harness:
	@$(CLEAN_BASH) tools/check.sh harness
## @group verify and build

# The stranger's check (#171), README.md's one command: four steps (the Lean build, the axiom check, the evaluator
# self-test, the smoke run), in order, each announced, stopping at the first failure. Step 1 fetches Mathlib's
# built files before the build (`lake exe cache get`, so a cold tree never compiles Mathlib from source) and also builds the exe
# `bsvs` that eval/bsvs runs; step 2 is the axioms leg of tools/check.sh (the same function, so the two agree); step 4
# is README.md's smoke build and run. VERIFY_LIGHT=1 (a machine under the kernel witness's memory, about 28 GB,
# docs/records/20261014-061809-stale-cost-s1.md): step 1 builds the libraries without StaleRunCheck, and step 2, whose
# AxiomCheck.lean imports that witness, prints its SKIPPED BY NAME lines and runs nothing; the last line is never GREEN.
## the Lean build, the axiom check, the evaluator self-test and the smoke run, in order (README.md; VERIFY_LIGHT=1 skips the kernel witness by name)
verify:
	@if [ "$(VERIFY_LIGHT)" = 1 ]; then echo "== verify 1/4 (VERIFY_LIGHT=1): cd lean && lake exe cache get && lake build BsvScript BsvChain Bsvs && lake build bsvs =="; \
	else echo "== verify 1/4: cd lean && lake exe cache get && lake build && lake build bsvs =="; fi
	cd lean && lake exe cache get && if [ "$(VERIFY_LIGHT)" = 1 ]; then lake build BsvScript BsvChain Bsvs; else lake build; fi && lake build bsvs
	@echo "== verify 2/4: the axiom check (tools/check.sh axioms) =="
	@if [ "$(VERIFY_LIGHT)" = 1 ]; then echo "axioms: kernel witness SKIPPED BY NAME (VERIFY_LIGHT=1)"; \
	echo "axioms: the axiom check SKIPPED BY NAME (VERIFY_LIGHT=1; lean/AxiomCheck.lean imports the kernel witness), not a pass"; \
	else $(CLEAN_BASH) tools/check.sh axioms; fi
	@echo "== verify 3/4: eval/bsvs --self-test =="
	eval/bsvs --self-test
	@echo "== verify 4/4: the harness smoke run (run_bsvrs on corpus/seed) =="
	cd harness && CARGO_TARGET_DIR=target CARGO_BUILD_JOBS=4 cargo build --release --locked --bin run_bsvrs
	harness/target/release/run_bsvrs --corpus corpus/seed --smoke
	@if [ "$(VERIFY_LIGHT)" = 1 ]; then echo "verify: LIGHT, not GREEN (steps 1, 3 and 4 passed; step 2 SKIPPED BY NAME, VERIFY_LIGHT=1)"; \
	else echo "verify: GREEN (the four steps passed)"; fi
## @group the gates and checks

# The bench leg alone (#137): the walls of the newest box record and the export record against tools/bench_baseline.json,
# and the fuzz smoke (tools/bench_leg.sh's header).
## the bench leg alone: the walls against tools/bench_baseline.json, and the fuzz smoke
bench:
	@$(CLEAN_BASH) tools/check.sh bench
## @group the generators

# Regenerate the seed corpus (deterministic; see corpus/INDEX.md). Only after #4.
## regenerate the seed corpus (deterministic)
seed:
	cd harness && cargo run --release --locked --bin seed_gen -- --out ../corpus/seed
# Regenerate the bsv-rs number vectors (deterministic; corpus/INDEX.md §3).
## regenerate the bsv-rs number vectors
numvectors:
	cd harness && cargo run --release --locked --bin num_vectors -- --count 1000 > ../corpus/numbers/bsv-rs-0.7.0.jsonl
# Regenerate the hand-written flow corpus with bsv-rs's verdicts (corpus/INDEX.md §1).
## regenerate the flow corpus with bsv-rs's verdicts
flowcases:
	cd harness && cargo run --release --locked --bin flow_cases -- --out ../corpus/flow
# Regenerate the bsv-rs BIP143 sighash vectors (deterministic; corpus/INDEX.md §4).
## regenerate the bsv-rs sighash vectors
sighashvectors:
	cd harness && cargo run --release --locked --bin sighash_vectors -- --count 500 > ../corpus/sighash/bsv-rs-0.7.0.jsonl
# Regenerate the bsv-rs arithmetic value vectors (deterministic; corpus/INDEX.md §3).
## regenerate the bsv-rs arithmetic value vectors
arithvectors:
	cd harness && cargo run --release --locked --bin arith_vectors -- --count 10000 > ../corpus/arith/bsv-rs-0.7.0.jsonl
# Regenerate the bitwise and arithmetic engine cases with bsv-rs's verdicts (corpus/INDEX.md §1).
## regenerate the arithmetic and bitwise engine cases
arithcases:
	cd harness && cargo run --release --locked --bin arith_cases -- --out ../corpus/arith
# Regenerate the stack and splice engine cases with bsv-rs's verdicts (corpus/INDEX.md §1).
## regenerate the stack and splice engine cases
stackcases:
	cd harness && cargo run --release --locked --bin stack_cases -- --out ../corpus/stack
# Regenerate the ECDSA vectors and the signature cases with bsv-rs (corpus/INDEX.md §1, §3).
## regenerate the bsv-rs ECDSA vectors
ecdsavectors:
	cd harness && cargo run --release --locked --bin ecdsa_vectors -- --count 200 > ../corpus/crypto/ecdsa-bsv-rs-0.7.0.jsonl
## regenerate the signature cases with bsv-rs
cryptocases:
	cd harness && cargo run --release --locked --bin crypto_cases -- --out ../corpus/crypto
# Regenerate the every-byte corpus with bsv-rs's verdicts (corpus/INDEX.md §1).
## regenerate the every-byte corpus
bytescases:
	cd harness && cargo run --release --locked --bin bytes_cases -- --out ../corpus/bytes
# Regenerate the hand-built eras corpus from the leg's table (#20, #23), then bsv-rs's verdicts under the
# per-input words (run_bsvrs --record); the spec's verdicts follow from `make diff` (corpus/INDEX.md §1).
## regenerate the eras corpus and bsv-rs's verdicts on it
eracases:
	cd lean && lake build erascheck 2>&1 | grep -v "^trace:" | tail -1 && .lake/build/bin/erascheck --write-corpus ../corpus/eras
	cd harness && CARGO_BUILD_JOBS=4 cargo run --release --locked --quiet --bin run_bsvrs -- --corpus ../corpus/eras --record
# Regenerate the policy-default witnesses (corpus/witnesses; #21). The large file is not committed.
## regenerate the policy-default witnesses
policywitnesses:
	cd harness && cargo run --release --locked --bin policy_witnesses -- --out ../corpus/witnesses
# Regenerate lean/Test/OpNames.lean from the pin (tools/opnames.py).
## regenerate lean/Test/OpNames.lean from the pin
opnames:
	tools/opnames.py
# Re-read the mainnet sighash entries (a network READ; record it in docs/PROVENANCE.md §6).
## read the mainnet sighash entries again (a network read)
mainnetread:
	tools/mainnet_read.py 400000:0de586d0c74780605c36c0f51dcd850d1772f41a92c549e3aa36f9e78e905284 400000:fc12dfcb4723715a456c6984e298e00c479706067da81be969e8085544b0ba08 400000:928c4275dfd6270349e76aa5a49b355eefeb9e31ffbe95dd75fed81d219a23f8 950000:676bfac5b548e7cd4901da30b57d611a9502d6fc022d15c42d07ec63a240749b 950000:df4a198421dbbfc19407c7551c4648a35a5153fd825c85cf486b53da180ee3fb 950000:2f541b43529b2371d30a2ad650537c82bcc1823a45c3119d92b8758838b02973 > corpus/sighash/mainnet.jsonl
## @group verify and build

## lake clean in lean/
clean-lean:
	cd lean && lake clean
## @group the harness

# The differential (#15): the spec's verdicts for every generated corpus through eval/bsvs,
# then run_diff against live bsv-rs; the witnesses in corpus/witnesses/, the spec's verdicts
# recorded into the corpora (spec@<commit>, spec-mempool@<commit>) and the manifests re-stamped.
# Update corpus/INDEX.md §1/§4 with the new shas after (the funnel rule). The wrapper refuses a binary Lake finds
# out of date (exit 3; lean #32's second lens, B-4): rebuild with BSVS_REBUILD=1 inside a held Lean-lock slot first.
## the differential: the spec's verdicts on every corpus against live bsv-rs
diff:
	@for c in seed/seed flow/flow arith/cases stack/cases crypto/cases eras/eras gen/gen tx/tx; do \
	  n=$$(echo $$c | tr / -); \
	  $(CLEAN_BASH) eval/bsvs corpus corpus/$$c.jsonl --out lean/.lake/spec-$$n.jsonl && \
	  ( cd harness && cargo run --release --quiet --locked --bin run_diff -- --corpus ../corpus/$$c.jsonl --spec ../lean/.lake/spec-$$n.jsonl --witnesses ../corpus/witnesses --record ) || exit 1; \
	done
## @group the generators

# Regenerate the specification document from the Lean sources (#17); `make check`'s spec leg refuses a stale tree.
## regenerate spec/ from the Lean sources
spec:
	tools/specgen.py
## @group the gates and checks

## the spec leg alone: spec/ and the RPC contract are current
speccheck:
	@$(CLEAN_BASH) tools/check.sh spec
## @group the generators

# The module map of #87 alone (2026-10-14): spec/teranode-map.md from corpus/teranode/map.json (`make spec` writes the
# same bytes), then every citation resolved at both pins (the cite leg runs the same --verify).
## regenerate spec/teranode-map.md and verify its citations
teranode-map:
	tools/teranode_map.py && tools/teranode_map.py --verify
# The SDK fixture export of #146: corpus/fixtures/ from the corpus in the shapes go-sdk v1.7.2's loaders and ts-stack's
# conformance runner read (tools/fixtures_export.py; the shapes cited in docs/records/20261016-192742-s3-146-fixtures-export-s3.md),
# and bsv-rs v0.7.0's tests/vectors/sighash.json shape (corpus/fixtures/bsv-rs/; its loader proof runs in bsv-rs's tree, the README).
# `fixtures-check` regenerates into a scratch directory and compares byte for byte (not a tripwire leg: the twenty-nine
# stand); `fixtures-proof` loads every go-sdk and ts-sdk file through its SDK (the bsv-rs files' loader proof runs in
# bsv-rs's tree) (harness/engines/go/fixtures, harness/engines/ts/fixtures.mjs on the installed adapter package). Differences use the same-spend class from rules_check (RULES_CHECK_LIST), or,
# for regenerated signer controls, the existing crypto.checksig.unlock.ungated predicate; other differences are RED.
.PHONY: fixtures fixtures-check fixtures-proof
## write the SDK fixture files under corpus/fixtures/
fixtures:
	tools/fixtures_export.py
## @group the gates and checks

## regenerate the SDK fixtures into scratch and compare byte for byte
fixtures-check:
	tools/fixtures_export.py --check
## @group the harness

## load every SDK fixture through its SDK
fixtures-proof:
	@command -v python3 >/dev/null 2>&1 || { echo 'fixtures-proof: SKIPPED BY NAME (python3 unavailable)'; exit 2; }; \
	python3 tools/fixtures_proof.py
## @group verify and build

# The engines under test beside bsv-rs (#29; docs/PROVENANCE.md §1a): the go-sdk adapter is built into
# harness/target/engines/ (no build step for the ts-sdk adapter: node runs harness/engines/ts/runner.mjs on the
# installed, pinned package). `make enginesdiff` = the spec's verdicts for every generated corpus through eval/bsvs,
# then run_engine for each SDK on the seven generated corpora (eras since #20/#23): both columns, every divergence a witness under a cited rule in corpus/witnesses/<engine>/.
## build the go-sdk adapter
gosdk-build:
	cd harness/engines/go && GOFLAGS=-mod=mod go build -o ../../target/engines/gosdk-runner .
# Signer column (#145): the same pinned module, with offline dependencies.
# Override the output for a checkout using a shared target directory.
GOSDK_GO ?= go
GOSDK_SIGNER_BIN ?= $(CURDIR)/harness/target/engines/gosdk-signer
## build the go-sdk signer, offline
gosdk-signer-build:
	cd harness/engines/go && GOPROXY=off GOSUMDB=off GOTOOLCHAIN=local GOFLAGS=-mod=readonly $(GOSDK_GO) build -p 4 -o "$(GOSDK_SIGNER_BIN)" ./signer
## install the ts-sdk adapter's pinned packages
tssdk-install:
	cd harness/engines/ts && npm ci --no-audit --no-fund --ignore-scripts
# #145: the signer has no emitted build files. Validate the installed pin offline,
# typecheck/lint the adapter, then exercise its signing paths in the foreground.
## check the ts-sdk signer: version, typecheck, lint, its tests
tssdk-signer-build:
	@$(CLEAN_BASH) -c 'set -euo pipefail; node="$$(tools/node_bin.sh)"; "$$node" harness/engines/ts/signer.mjs --version; cd harness/engines/ts; "$$node" node_modules/typescript/bin/tsc --noEmit -p tsconfig.json; "$$node" node_modules/eslint/bin/eslint.js --max-warnings 0 .; "$$node" --test signer.test.mjs'
## @group the gates and checks

# The tslint leg alone (#136, 2026-10-14): strict tsc and eslint over the ts-sdk adapter; `npm ci` when the install differs from the lockfile.
## the tslint leg alone: strict tsc and eslint on the ts-sdk adapter
tslint:
	@$(CLEAN_BASH) tools/check.sh tslint
## @group verify and build

## build the GoBDK shim
gobdk-build:
	$(CLEAN_BASH) harness/engines/gobdk/build.sh
ENGINES ?= gosdk tssdk gobdk
## @group the harness

## the spec's verdicts against each SDK engine (ENGINES) on every generated corpus
enginesdiff: $(if $(filter gosdk,$(ENGINES)),gosdk-build) $(if $(filter gobdk,$(ENGINES)),gobdk-build)
	@for c in seed/seed flow/flow arith/cases stack/cases crypto/cases bytes/cases eras/eras gen/gen tx/tx; do \
	  n=$$(echo $$c | tr / -); \
	  $(CLEAN_BASH) eval/bsvs corpus corpus/$$c.jsonl --out lean/.lake/spec-$$n.jsonl && \
	  for e in $(ENGINES); do \
	    ( cd harness && cargo run --release --locked --quiet --bin run_engine -- --engine $$e --corpus ../corpus/$$c.jsonl --spec ../lean/.lake/spec-$$n.jsonl --witnesses ../corpus/witnesses $(ENGINE_RECORD) ) || exit 1; \
	  done; \
	done

# One implementation's column on one release in one command (#124; tools/column.sh's header is the manual): PIN equal to
# the pin of docs/PROVENANCE.md section 1a is a dry run (nothing under corpus/ written, the run compared with the committed
# column); a different PIN moves that implementation's sites and re-records every corpus its column records. The record is
# docs/records/<stamp>-column-<impl>-<pin>-s3.md; the last line is the verdict. sv-node and teranode name their instance and
# never start one. [M] 2026-10-14
.PHONY: column
## one implementation's column on one release: IMPL=<impl> PIN=<version>
column:
	@$(call CLEAN_BASH_WITH,COMMIT="$(COMMIT)" PLAN="$(PLAN)" CORPUS="$(CORPUS)") tools/column.sh "$(IMPL)" "$(PIN)"

# The per-release divergence gate of #95 (tools/teranode_gate.sh's header is the manual; tools/teranode_gate.py the writer):
# Teranode against the reference at the pins of docs/PROVENANCE.md section 1a, on the scenario and script corpora, read through
# #88's obligation list; the page is docs/records/<stamp>-s8-95-gate-report-s3.md. DRY_RUN=1 builds it from the records on
# disk and starts nothing (the pair under docs/records, OUT_DIR=<dir> elsewhere); without it the target prints the plan, and
# STEP=<step> SINCE=<stamp> runs one measuring step. [D] 2026-10-17 (the dry run [M]; the live steps unexecuted until hz-95)
.PHONY: teranode-gate
## the per-release divergence gate against Teranode; DRY_RUN=1 builds it from the records
teranode-gate:
	@if [ -n "$(DRY_RUN)" ]; then /usr/bin/env python3 tools/teranode_gate.py --dry-run $(if $(OUT_DIR),--out-dir "$(OUT_DIR)"); else \
	  $(call CLEAN_BASH_WITH,STEP="$(STEP)" SINCE="$(SINCE)" FAMILY="$(FAMILY)" CORPUS="$(CORPUS)" FROM="$(FROM)" COUNT="$(COUNT)" MANIFEST="$(MANIFEST)" ORACLE_ROWS="$(ORACLE_ROWS)") tools/teranode_gate.sh; fi

## @group the maintainers' routes

# The maintainers' progress page (tools/progress.py, withheld from the public edition): served on 127.0.0.1 only, built on
# every request from tools/progress_state.json and the records. http://127.0.0.1:8766/
.PHONY: progress
## serve the maintainers' progress page on 127.0.0.1
progress:
	@/usr/bin/env python3 tools/progress.py --serve

## @group the harness

# #66: live pinned node measurements, separate from the chain tripwire.
.PHONY: node-scenarios
## the live pinned-node scenario measurements
node-scenarios:
	@$(CLEAN_BASH) tools/node_scenarios.sh $(ARGS)

# #66 R4: full S6 replay includes the derived chain rows beside the short scenario tripwire.
.PHONY: chain-check
## the full chain replay, with the derived chain rows
chain-check:
	@$(CLEAN_BASH) tools/chain_leg.sh --full
