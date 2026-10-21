---
name: Divergence
about: Two verdicts on one transaction disagree. Report it as a witness, never a sentence.
title: "divergence: <rule> on <implementation> <version>"
labels: divergence
---

<!--
A divergence that one implementation accepts and another refuses can split the chain.
If it puts funds or the chain at risk, do NOT file it here: use the "Report a vulnerability"
button under the Security tab (SECURITY.md).
The entry format is docs/DESIGN.md §6; the pins are docs/PROVENANCE.md §1a.
-->

## The transaction

```
<the spending transaction, hex>
```

## Its previous outputs and their heights

| input | txid | vout | script (hex) | satoshis | height |
|---|---|---|---|---|---|
| 0 | | | | | |

## The parameters

- era:
- flags (the word per input, or "derived from the heights"):
- spend height:
- consensus or policy (mempool) path:

## Both verdicts

| side | implementation and version (or `spec@<commit>`) | verdict | code or reason | input |
|---|---|---|---|---|
| a | | | | |
| b | | | | |

## The rule

<the rule it exercises, in the vocabulary of corpus/INDEX.md §2>

## The citations at the pins

<file:line at the pinned reference, and the Lean definition if you know it>

## How you ran it

- the harness command (for example `harness/run --impl <impl> --corpus <corpus>`, `eval/bsvs eval --tx ...`, or `tools/witness.sh <witness-id>`):
- the record (the run's output directory or its file under docs/records/):
