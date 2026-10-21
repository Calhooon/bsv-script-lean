#!/usr/bin/env python3
"""check-pins (bsv-script-lean #40): every pin recorded ONCE in docs/PROVENANCE.md §1a, checked at every
site that must agree with it; RED on any drift. A leg of `make check` (tools/check.sh pins).

Sites, in-repo (every one is checked; a missing site is drift):
  the Lean toolchain and the Mathlib manifest · the harness crate's rust-toolchain.toml · Cargo.toml's
  exact bsv-rs requirement, Cargo.lock's version and crates.io checksum, lib.rs's BSV_RS_VERSION/BSV_RS_KEY ·
  the corpus manifests' recorded bsv-rs version (a moved pin with un-re-recorded verdicts is drift) and the
  witness manifest · the bsv-rs vector files named by the pin (and no other version string in the tripwire) ·
  the go-sdk module's go.mod/go.sum · the GoBDK shim's go.mod/go.sum (the pseudo-version Teranode requires at its
  tag, 2026-09-27) · the ts-sdk package's package.json/package-lock.json · the --locked
  discipline of every cargo invocation in the tripwire and the Makefile · the toolchains in use (rustc under
  harness/, go, the node tools/node_bin.sh resolves).
Sites, on this machine (checked when the clone or binary is present, SKIPPED by name when absent; a present
site at the wrong commit is drift): the reference clone at its tag · Teranode's tag, and at that tag its go.mod's
go-chaincfg requirement with go.sum's two sums (2026-09-27) · the go-chaincfg clone at its tag · GoBDK · bsv-rs's tag ·
go-sdk's tag · ts-stack at the publish commit with the package version · the pattern sources' commits · the
vendored reference vectors against `git show <tag>:src/test/data/…` · the built SV-node's version string · the built
GoBDK shim runner's banner (the module's commit and the linked library's reference commit prefix).

A SKIP is printed by name and counted; it is never a pass. CHECK_PINS_REQUIRE_CLONES=1 turns every skip
into drift (for the machine that holds the clones)."""
import hashlib
import json
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import host_vars  # noqa: E402  tools/host_vars.py, the maintainers' host values (#177)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PROVENANCE = os.path.join(ROOT, "docs", "PROVENANCE.md")

rows = []          # (status, site, expected, found)
skipped = []


def ok(site, value):
    rows.append(("OK", site, value, value))


def drift(site, expected, found):
    rows.append(("DRIFT", site, expected, found))


def skip(site, why):
    rows.append(("SKIP", site, why, ""))
    skipped.append(site)


def read(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as f:
        return f.read()


def pins_block():
    text = read("docs/PROVENANCE.md")
    m = re.search(r"```pins\n(.*?)```", text, re.S)
    if not m:
        print("check-pins: RED: docs/PROVENANCE.md has no ```pins block (§1a)")
        sys.exit(1)
    pins = {}
    for line in m.group(1).splitlines():
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        k, _, v = line.partition("=")
        pins[k.strip()] = v.strip()
    return pins


def expect_eq(site, expected, found):
    if found == expected:
        ok(site, found)
    else:
        drift(site, expected, found)


def git(clone, *args):
    r = subprocess.run(["git", "-C", clone] + list(args), capture_output=True, text=True)
    return r.returncode, r.stdout.strip(), r.stderr.strip()


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def host_path(p):
    """A pins value as a path (#177): `$NAME` from the environment, else tools/host_private.sh (tools/host_vars.py);
    unresolved, the name stays and the clone reads as absent, skipped by name (this leg is a gate, never a refusal)."""
    v = host_vars.path(p)
    return p if v is None else v


def absent_why(p):
    """The skip's reason when a `$NAME` value is unresolved on this host."""
    n = host_vars.name_of(p)
    return f" ({n} is unset and tools/host_private.sh does not name it)" if n and host_vars.path(p) is None else ""


def clone_path(p):
    return host_path(p)


def main():
    pins = pins_block()
    need = ["reference.tag", "reference.commit", "reference.clone", "reference.version_string", "reference.binary", "teranode.tag",
            "teranode.commit", "teranode.clone", "gobdk.commit", "gobdk.clone", "bsv-rs.crate", "bsv-rs.checksum",
            "bsv-rs.tag", "bsv-rs.commit", "bsv-rs.clone", "go-sdk.module", "go-sdk.version", "go-sdk.commit",
            "go-sdk.sum", "go-sdk.gomod_sum", "go-sdk.clone", "ts-sdk.package", "ts-sdk.version", "ts-sdk.integrity",
            "ts-sdk.commit", "ts-sdk.clone", "lean.toolchain", "lean.mathlib", "rust.toolchain", "go.major",
            "node.major", "cargo-deny.version", "predecessor-harness.commit", "predecessor-harness.clone", "predecessor-lean.commit",
            "predecessor-lean.clone",
            "go-chaincfg.module", "go-chaincfg.version", "go-chaincfg.commit", "go-chaincfg.sum",
            "go-chaincfg.gomod_sum", "go-chaincfg.clone",
            "gobdk.module", "gobdk.pseudo_version", "gobdk.sum", "gobdk.gomod_sum", "gobdk.reference_tag", "gobdk.reference_commit"]
    missing = [k for k in need if k not in pins]
    if missing:
        print("check-pins: RED: the pins block lacks " + ", ".join(missing))
        sys.exit(1)

    # --- the Lean pins
    expect_eq("lean/lean-toolchain", pins["lean.toolchain"], read("lean/lean-toolchain").strip())
    man = json.loads(read("lean/lake-manifest.json"))
    mathlib = next((p for p in man["packages"] if p["name"] == "mathlib"), {})
    expect_eq("lean/lake-manifest.json mathlib rev", pins["lean.mathlib"], mathlib.get("rev", "<absent>"))

    # --- the Rust toolchain
    tc = read("harness/rust-toolchain.toml")
    m = re.search(r'channel\s*=\s*"([^"]+)"', tc)
    expect_eq("harness/rust-toolchain.toml channel", pins["rust.toolchain"], m.group(1) if m else "<absent>")
    r = subprocess.run(["rustc", "--version"], cwd=os.path.join(ROOT, "harness"), capture_output=True, text=True)
    found = r.stdout.strip() if r.returncode == 0 else "<rustc missing>"
    if pins["rust.toolchain"] in found:
        ok("rustc in use under harness/", found)
    else:
        drift("rustc in use under harness/", pins["rust.toolchain"], found)

    # --- the deny leg's gate tool (#133): the wrapper's pin
    m = re.search(r'^DENY_VERSION=(\S+)$', read("tools/cargo_deny.sh"), re.M)
    expect_eq("tools/cargo_deny.sh DENY_VERSION", pins["cargo-deny.version"], m.group(1) if m else "<absent>")

    # --- bsv-rs: Cargo.toml, Cargo.lock, lib.rs
    crate = pins["bsv-rs.crate"]
    m = re.search(r'^bsv-rs\s*=\s*(?:\{\s*version\s*=\s*)?"([^"]+)"', read("harness/Cargo.toml"), re.M)  # #86: the table form
    expect_eq("harness/Cargo.toml bsv-rs requirement", "=" + crate, m.group(1) if m else "<absent>")
    lock = read("harness/Cargo.lock")
    m = re.search(r'name = "bsv-rs"\nversion = "([^"]+)"\nsource = "[^"]+"\nchecksum = "([0-9a-f]+)"', lock)
    expect_eq("harness/Cargo.lock bsv-rs version", crate, m.group(1) if m else "<absent>")
    expect_eq("harness/Cargo.lock bsv-rs checksum", pins["bsv-rs.checksum"], m.group(2) if m else "<absent>")
    lib = read("harness/src/lib.rs")
    m = re.search(r'pub const BSV_RS_VERSION: &str = "([^"]+)"', lib)
    expect_eq("harness/src/lib.rs BSV_RS_VERSION", crate, m.group(1) if m else "<absent>")
    m = re.search(r'pub const BSV_RS_KEY: &str = "([^"]+)"', lib)
    expect_eq("harness/src/lib.rs BSV_RS_KEY", "bsv-rs@" + crate, m.group(1) if m else "<absent>")

    # --- the corpus manifests record verdicts of the pinned engine
    for c in ["seed", "flow", "arith", "stack", "crypto", "bytes", "eras", "gen", "tx"]:
        for name in ["manifest.json", "cases-manifest.json"]:
            path = os.path.join(ROOT, "corpus", c, name)
            if os.path.exists(path):
                break
        else:
            drift(f"corpus/{c} manifest", "present", "<absent>")
            continue
        mj = json.load(open(path))
        v = next((i.get("version") for i in mj.get("implementations", []) if i.get("name") == "bsv-rs"), "<absent>")
        expect_eq(f"corpus/{c}/{name} implementations[bsv-rs].version", crate, v)
    wpath = os.path.join(ROOT, "corpus", "witnesses", "manifest.json")
    if os.path.exists(wpath):
        wm = json.load(open(wpath))
        for c, rec in sorted(wm.items()):
            if isinstance(rec, dict) and "bsv-rs" in rec:
                expect_eq(f"corpus/witnesses/manifest.json [{c}].bsv-rs", crate, rec["bsv-rs"])
    else:
        drift("corpus/witnesses/manifest.json", "present", "<absent>")

    # --- the bsv-rs vector files are the pin's, and the tripwire names no other version
    for vf in [f"corpus/numbers/bsv-rs-{crate}.jsonl", f"corpus/arith/bsv-rs-{crate}.jsonl",
               f"corpus/sighash/bsv-rs-{crate}.jsonl", f"corpus/crypto/ecdsa-bsv-rs-{crate}.jsonl"]:
        expect_eq(vf, "present", "present" if os.path.exists(os.path.join(ROOT, vf)) else "<absent>")
    for f in ["tools/check.sh", "Makefile"]:
        others = sorted(set(re.findall(r"bsv-rs-(\d+\.\d+\.\d+)", read(f))) - {crate})
        expect_eq(f"{f}: bsv-rs vector versions named", crate, crate if not others else f"also {', '.join(others)}")

    # --- the --locked discipline
    for f in ["tools/check.sh", "Makefile"]:
        bad = []
        for i, line in enumerate(read(f).splitlines(), 1):
            if re.search(r"\bcargo\s+(run|build|test|check|bench|clippy)\b", line) and "--locked" not in line:
                bad.append(str(i))
        expect_eq(f"{f}: every cargo invocation carries --locked", "yes", "yes" if not bad else "missing at lines " + ",".join(bad))

    # --- the crate facts the runners rely on (harness/tests/crate_pins.rs; #40's post-close ask, carried to #31):
    #     ProtocolEra::at_height is None below Genesis; block(era)/standard(era) carry both UTXO markers from the block's era
    r = subprocess.run(["cargo", "test", "--release", "--locked", "--quiet", "--test", "crate_pins"],
                       cwd=os.path.join(ROOT, "harness"), capture_output=True, text=True,
                       env={**os.environ, "CARGO_BUILD_JOBS": os.environ.get("CARGO_BUILD_JOBS", "4")})
    if r.returncode == 0 and "test result: ok" in (r.stdout + r.stderr):
        ok("bsv-rs crate facts at the pin (harness/tests/crate_pins.rs)", "ProtocolEra::mainnet None below 620538; block/standard words carry the block era's UTXO markers")
    else:
        drift("bsv-rs crate facts at the pin (harness/tests/crate_pins.rs)", "the two facts hold", (r.stdout + r.stderr).strip()[-400:] or f"exit {r.returncode}")

    # --- the harness's own engine constants (the corpus keys)
    eng = read("harness/src/engines.rs")
    m = re.search(r'pub const GO_SDK_VERSION: &str = "([^"]+)"', eng)
    expect_eq("harness/src/engines.rs GO_SDK_VERSION", pins["go-sdk.version"], m.group(1) if m else "<absent>")
    m = re.search(r'pub const TS_SDK_VERSION: &str = "([^"]+)"', eng)
    expect_eq("harness/src/engines.rs TS_SDK_VERSION", pins["ts-sdk.version"], m.group(1) if m else "<absent>")

    # --- go-sdk: go.mod and go.sum
    gomod = read("harness/engines/go/go.mod")
    m = re.search(r"^require\s+" + re.escape(pins["go-sdk.module"]) + r"\s+(\S+)", gomod, re.M)
    expect_eq("harness/engines/go/go.mod go-sdk requirement", pins["go-sdk.version"], m.group(1) if m else "<absent>")
    gosum = read("harness/engines/go/go.sum")
    want = f"{pins['go-sdk.module']} {pins['go-sdk.version']} {pins['go-sdk.sum']}"
    expect_eq("harness/engines/go/go.sum module hash", want, want if want in gosum.splitlines() else "<absent or different>")
    want = f"{pins['go-sdk.module']} {pins['go-sdk.version']}/go.mod {pins['go-sdk.gomod_sum']}"
    expect_eq("harness/engines/go/go.sum go.mod hash", want, want if want in gosum.splitlines() else "<absent or different>")
    # --- the GoBDK shim's module pin (#28, harness/engines/gobdk; 2026-09-27): go.mod's requirement and go.sum's two sums
    gomod = read("harness/engines/gobdk/go.mod")
    m = re.search(r"^require\s+" + re.escape(pins["gobdk.module"]) + r"\s+(\S+)", gomod, re.M)
    expect_eq("harness/engines/gobdk/go.mod gobdk requirement", pins["gobdk.pseudo_version"], m.group(1) if m else "<absent>")
    gosum = read("harness/engines/gobdk/go.sum")
    want = f"{pins['gobdk.module']} {pins['gobdk.pseudo_version']} {pins['gobdk.sum']}"
    expect_eq("harness/engines/gobdk/go.sum module hash", want, want if want in gosum.splitlines() else "<absent or different>")
    want = f"{pins['gobdk.module']} {pins['gobdk.pseudo_version']}/go.mod {pins['gobdk.gomod_sum']}"
    expect_eq("harness/engines/gobdk/go.sum go.mod hash", want, want if want in gosum.splitlines() else "<absent or different>")
    expect_eq("gobdk.pseudo_version names gobdk.commit", pins["gobdk.commit"][:12], pins["gobdk.pseudo_version"].rsplit("-", 1)[-1])
    r = subprocess.run(["go", "version"], capture_output=True, text=True)
    found = r.stdout.strip() if r.returncode == 0 else "<go missing>"
    if re.search(r"\bgo" + re.escape(pins["go.major"]) + r"(\.|\s)", found):
        ok("go in use", found)
    else:
        drift("go in use", "go" + pins["go.major"] + ".x", found)

    # --- ts-sdk: package.json and package-lock.json
    pj = json.loads(read("harness/engines/ts/package.json"))
    expect_eq("harness/engines/ts/package.json @bsv/sdk (exact)", pins["ts-sdk.version"], pj.get("dependencies", {}).get(pins["ts-sdk.package"], "<absent>"))
    pl = json.loads(read("harness/engines/ts/package-lock.json"))
    node = pl.get("packages", {}).get("node_modules/" + pins["ts-sdk.package"], {})
    expect_eq("harness/engines/ts/package-lock.json @bsv/sdk version", pins["ts-sdk.version"], node.get("version", "<absent>"))
    expect_eq("harness/engines/ts/package-lock.json @bsv/sdk integrity", pins["ts-sdk.integrity"], node.get("integrity", "<absent>"))
    r = subprocess.run([os.path.join(ROOT, "tools", "node_bin.sh")], capture_output=True, text=True)
    node_bin = r.stdout.strip() if r.returncode == 0 else ""
    if node_bin:
        r2 = subprocess.run([node_bin, "--version"], capture_output=True, text=True)
        found = r2.stdout.strip()
        if found.startswith("v" + pins["node.major"] + "."):
            ok("node in use (tools/node_bin.sh)", f"{found} at {node_bin}")
        else:
            drift("node in use (tools/node_bin.sh)", "v" + pins["node.major"] + ".x", f"{found} at {node_bin}")
    else:
        drift("node in use (tools/node_bin.sh)", "v" + pins["node.major"] + ".x", "<no node found>")

    # --- the clones on this machine (skipped by name when absent)
    def clone_check(site, clone, fn):
        c = clone_path(clone)
        if not os.path.isdir(os.path.join(c, ".git")) and not os.path.isfile(os.path.join(c, ".git")):
            skip(site, f"clone absent: {clone}" + absent_why(clone))
            return
        fn(c)

    def ref_clone(c):
        _, head, _ = git(c, "rev-parse", "HEAD")
        expect_eq(f"{pins['reference.clone']} HEAD", pins["reference.commit"], head)
        _, tag, _ = git(c, "describe", "--tags", "--exact-match")
        expect_eq(f"{pins['reference.clone']} tag at HEAD", pins["reference.tag"], tag or "<no exact tag>")
        # the vendored reference vectors are the pin's files
        for f in ["script_tests.json", "tx_valid.json", "tx_invalid.json", "sighash.json"]:
            local = os.path.join(ROOT, "corpus", "reference" if f != "sighash.json" else "sighash", f"bitcoin-sv-{pins['reference.tag']}-{f}")
            if not os.path.exists(local):
                drift(f"corpus vendored {f}", "present", "<absent>")
                continue
            r = subprocess.run(["git", "-C", c, "show", f"{pins['reference.tag']}:src/test/data/{f}"], capture_output=True)
            if r.returncode != 0:
                drift(f"git show {pins['reference.tag']}:src/test/data/{f}", "readable", r.stderr.decode(errors="replace").strip())
                continue
            expect_eq(f"vendored {f} == the pin's", hashlib.sha256(r.stdout).hexdigest(), sha256_file(local))
    clone_check("the reference clone", pins["reference.clone"], ref_clone)

    def tag_commit(site, clone, tag, commit):
        rc, out, err = git(clone, "rev-parse", f"{tag}^{{commit}}")
        expect_eq(site, commit, out if rc == 0 else f"<{err or 'no such tag'}>")

    clone_check("GoBDK's embedded reference clone", pins["reference.clone"],
                lambda c: tag_commit("GoBDK's embedded reference tag", c, pins["gobdk.reference_tag"], pins["gobdk.reference_commit"]))

    def teranode(c):
        tag_commit(f"{pins['teranode.clone']} {pins['teranode.tag']}", c, pins["teranode.tag"], pins["teranode.commit"])
        # go-chaincfg (the chain parameters Teranode reads; §1a, 2026-09-27): the version Teranode's go.mod requires AT THE
        # TAG and the two sums its go.sum carries there, read with `git show <tag>:<path>` (the working tree is beyond the tag)
        rc, gomod_t, err = git(c, "show", f"{pins['teranode.tag']}:go.mod")
        m = re.search(r"^\s*" + re.escape(pins["go-chaincfg.module"]) + r"\s+(\S+)", gomod_t, re.M) if rc == 0 else None
        expect_eq(f"teranode {pins['teranode.tag']} go.mod go-chaincfg requirement", pins["go-chaincfg.version"],
                  m.group(1) if m else f"<{err or 'absent'}>")
        rc, gosum_t, err = git(c, "show", f"{pins['teranode.tag']}:go.sum")
        lines = gosum_t.splitlines() if rc == 0 else []
        want = f"{pins['go-chaincfg.module']} {pins['go-chaincfg.version']} {pins['go-chaincfg.sum']}"
        expect_eq(f"teranode {pins['teranode.tag']} go.sum go-chaincfg module hash", want, want if want in lines else "<absent or different>")
        want = f"{pins['go-chaincfg.module']} {pins['go-chaincfg.version']}/go.mod {pins['go-chaincfg.gomod_sum']}"
        expect_eq(f"teranode {pins['teranode.tag']} go.sum go-chaincfg go.mod hash", want, want if want in lines else "<absent or different>")
        # GoBDK: the pseudo-version Teranode requires at the tag is the shim's (harness/engines/gobdk/go.mod) and its sums
        m2 = re.search(r"^\s*" + re.escape(pins["gobdk.module"]) + r"\s+(\S+)", gomod_t, re.M) if gomod_t else None
        expect_eq(f"teranode {pins['teranode.tag']} go.mod gobdk requirement", pins["gobdk.pseudo_version"], m2.group(1) if m2 else "<absent>")
        want = f"{pins['gobdk.module']} {pins['gobdk.pseudo_version']} {pins['gobdk.sum']}"
        expect_eq(f"teranode {pins['teranode.tag']} go.sum gobdk module hash", want, want if want in lines else "<absent or different>")
        want = f"{pins['gobdk.module']} {pins['gobdk.pseudo_version']}/go.mod {pins['gobdk.gomod_sum']}"
        expect_eq(f"teranode {pins['teranode.tag']} go.sum gobdk go.mod hash", want, want if want in lines else "<absent or different>")
    clone_check("the Teranode clone", pins["teranode.clone"], teranode)

    # --- the built GoBDK shim runner on this machine (harness/target/engines/gobdk-runner; skipped by name when absent):
    #     its banner names the module's commit and the reference's commit prefix the linked library carries (§1)
    runner = os.path.join(ROOT, "harness", "target", "engines", "gobdk-runner")
    if os.path.exists(runner):
        r = subprocess.run([runner, "--describe"], capture_output=True, text=True)
        try:
            banner = json.loads(r.stdout).get("banner", "") if r.returncode == 0 else f"<exit {r.returncode}>"
        except json.JSONDecodeError:
            banner = f"<unparsed: {r.stdout[:120]}>"
        want = f"gobdk {pins['gobdk.commit'][:8]}"
        expect_eq("the built gobdk-runner's banner: the module commit", want, want if want in banner else banner[:160])
        want = pins["gobdk.reference_commit"][:9]
        expect_eq("the built gobdk-runner's banner: the linked library's reference commit", want, want if want in banner else banner[:160])
    else:
        skip("the built gobdk-runner", f"binary absent: {runner}")
    clone_check("the go-chaincfg clone", pins["go-chaincfg.clone"],
                lambda c: tag_commit(f"{pins['go-chaincfg.clone']} {pins['go-chaincfg.version']}", c, pins["go-chaincfg.version"], pins["go-chaincfg.commit"]))

    def gobdk(c):
        _, head, _ = git(c, "rev-parse", "HEAD")
        expect_eq(f"{pins['gobdk.clone']} HEAD", pins["gobdk.commit"], head)
    clone_check("the GoBDK clone", pins["gobdk.clone"], gobdk)

    clone_check("the bsv-rs clone", pins["bsv-rs.clone"],
                lambda c: tag_commit(f"{pins['bsv-rs.clone']} {pins['bsv-rs.tag']}", c, pins["bsv-rs.tag"], pins["bsv-rs.commit"]))
    clone_check("the go-sdk clone", pins["go-sdk.clone"],
                lambda c: tag_commit(f"{pins['go-sdk.clone']} {pins['go-sdk.version']}", c, pins["go-sdk.version"], pins["go-sdk.commit"]))

    def ts_stack(c):
        rc, _, err = git(c, "cat-file", "-e", f"{pins['ts-sdk.commit']}^{{commit}}")
        if rc != 0:
            drift(f"{pins['ts-sdk.clone']} has {pins['ts-sdk.commit'][:9]}", "present", f"<{err or 'absent'}>")
            return
        ok(f"{pins['ts-sdk.clone']} has {pins['ts-sdk.commit'][:9]}", "present")
        rc, out, err = git(c, "show", f"{pins['ts-sdk.commit']}:packages/sdk/package.json")
        v = json.loads(out).get("version") if rc == 0 else f"<{err}>"
        expect_eq(f"{pins['ts-sdk.clone']} packages/sdk/package.json at {pins['ts-sdk.commit'][:9]}", pins["ts-sdk.version"], v)
    clone_check("the ts-stack clone", pins["ts-sdk.clone"], ts_stack)

    for name in ["predecessor-harness", "predecessor-lean"]:
        def pattern_src(c, name=name):
            rc, out, err = git(c, "rev-parse", "--verify", f"{pins[name + '.commit']}^{{commit}}")
            if rc == 0 and out.startswith(pins[name + ".commit"]):
                ok(f"{pins[name + '.clone']} has {pins[name + '.commit']}", out)
            else:
                drift(f"{pins[name + '.clone']} has {pins[name + '.commit']}", "present", f"<{err or out}>")
        clone_check(f"the {name} clone", pins[name + ".clone"], pattern_src)

    # --- the node adapters and oracle defaults must agree with the reference pin (#57)
    for f in ["harness/src/bin/run_svnode.rs", "harness/src/txroad.rs"]:
        src = read(f)
        for constant, key in [("SV_NODE_KEY", "sv-node@" + pins["reference.tag"]),
                              ("SV_NODE_MEMPOOL_KEY", "sv-node-mempool@" + pins["reference.tag"])]:
            m = re.search(r'pub const ' + constant + r': &str = "([^"]+)"', src)
            expect_eq(f + " " + constant, key, m.group(1) if m else "<absent>")
    m = re.search(r'pub const SV_NODE_TAG: &str = "([^"]+)"', read("harness/src/lib.rs"))
    expect_eq("harness/src/lib.rs SV_NODE_TAG", pins["reference.tag"], m.group(1) if m else "<absent>")
    src = read("harness/src/bin/run_svnode.rs")
    m = re.search(r'pub const SV_NODE_VERSION_STRING: &str = "([^"]+)"', src)
    expect_eq("run_svnode build version", pins["reference.version_string"], m.group(1) if m else "<absent>")
    scenario = read("harness/src/scenarios/core.rs")
    for constant, key in [("VERSION", "reference.version_string"), ("PIN", "reference.commit")]:
        m = re.search(r'const ' + constant + r': &str = "([^\"]+)"', scenario)
        expect_eq("run_scenarios " + constant, pins[key], m.group(1) if m else "<absent>")
    oracle = read("harness/oracle/spec-node.sh")
    m = re.search(r'SV_BIN:=\$(BSV_SPEC_[A-Z_]+)\}', oracle)
    expect_eq("spec-node.sh default binary", pins["reference.binary"], "$" + m.group(1) if m else "<absent>")

    # --- the built SV-node on this machine
    node_bin = clone_path(pins["reference.binary"])
    if os.path.exists(node_bin):
        r = subprocess.run([node_bin, "-version"], capture_output=True, text=True)
        first = (r.stdout or r.stderr).splitlines()[0] if (r.stdout or r.stderr) else ""
        # exact: `Bitcoin SV version <string>`, the string being the pin to the last character (the `-dev`
        # suffix is the build's own, from an export without a repository; PROVENANCE §1a names it)
        m = re.match(r"Bitcoin SV version (\S+)", first)
        expect_eq("the built SV-node's version string", pins["reference.version_string"], m.group(1) if m else f"<unparsed: {first}>")
    else:
        skip("the built SV-node", f"binary absent: {node_bin}" + absent_why(pins["reference.binary"]))

    # --- the zmq build (#84): read as the node of record is, its sha256 against the one its row's comment names; absent
    # (the box, the Modal container) it is skipped by name, never RED
    zmq_bin = clone_path(pins.get("reference.binary_zmq", ""))
    zm = re.search(r"bitcoind sha256 ([0-9a-f]{64})[^\n]*\n(?:#[^\n]*\n)*reference\.binary_zmq ", read("docs/PROVENANCE.md"))
    if "reference.binary_zmq" not in pins:
        drift("the zmq build's pin row", "reference.binary_zmq", "<absent>")
    elif os.path.exists(zmq_bin):
        expect_eq("the zmq build's sha256", zm.group(1) if zm else "<no sha256 in the row's comment>", sha256_file(zmq_bin))
        r = subprocess.run([zmq_bin, "-version"], capture_output=True, text=True)
        top = (r.stdout or r.stderr).splitlines()[0] if (r.stdout or r.stderr) else ""
        m = re.match(r"Bitcoin SV version (\S+)", top)
        expect_eq("the zmq build's version string", pins["reference.version_string"], m.group(1) if m else f"<unparsed: {top}>")
    else:
        skip("the zmq build", f"binary absent: {zmq_bin}" + absent_why(pins.get("reference.binary_zmq", "")))

    # --- the report
    width = max(len(r[1]) for r in rows)
    n_ok = n_drift = 0
    for status, site, expected, found in rows:
        if status == "OK":
            n_ok += 1
            print(f"  OK     {site.ljust(width)}  {expected}")
        elif status == "SKIP":
            print(f"  SKIP   {site.ljust(width)}  {expected}")
        else:
            n_drift += 1
            print(f"  DRIFT  {site.ljust(width)}  expected {expected!r}, found {found!r}")
    strict = os.environ.get("CHECK_PINS_REQUIRE_CLONES") == "1"
    if n_drift or (strict and skipped):
        print(f"check-pins: RED ({n_drift} drift, {len(skipped)} skipped{' = drift under CHECK_PINS_REQUIRE_CLONES' if strict and skipped else ''})")
        sys.exit(1)
    print(f"check-pins: GREEN ({n_ok} sites agree with docs/PROVENANCE.md §1a; {len(skipped)} skipped by name" + (": " + ", ".join(skipped) if skipped else "") + ")")


if __name__ == "__main__":
    main()
