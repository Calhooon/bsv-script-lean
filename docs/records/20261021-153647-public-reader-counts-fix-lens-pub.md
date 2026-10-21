# The public reader's entry pages: process vocabulary and prose labels, before and after (#167)

- **Measured:** 2026-10-21 15:41 UTC [M], at the working tree of `ca8a7fb3` (branch `lane/fix-lens-pub`, built on the stack's tip `b16d13b7`); the counted pages are byte-equal after the branch's rebase onto the stack's later tip `9764d6c9`, which touches none of them.
- **Before:** `origin/main` at `5dc337e1`. **The stack before this fix:** `b16d13b7`. **After:** the working tree above.
- **The pages:** every entry page touched on 2026-10-21 by the public reader's stack and its fix: `README.md`, `docs/README.md`, `docs/STATE-OF-THE-WORLD.md`, `docs/GLOSSARY.md`, `CLAUDE.public.md`, `CONTRIBUTING.md`, `SECURITY.md`, `lean/README.md`, `harness/README.md`, `docs/WRITE-UP.md`, `NORTH-STAR.md`.

## The two counts

- **Process vocabulary:** whole-word, case-insensitive matches of `lanes?|seats?|captains?|sittings?|windows?|sessions?|dockets?|owner('s)?`, every line of the page.
- **Prose labels:** matches of `\[(M|X|D|EST|LIT|SRC)\]` on lines outside a table row (a line starting with `|`) and outside a code fence.

The command (Python 3, from the repository root; `<ref>` is `origin/main` or `b16d13b7`, the after column reads the working tree):

```text
VOC = re.compile(r"\b(lanes?|seats?|captains?|sittings?|windows?|sessions?|dockets?|owner('s)?)\b", re.I)
LAB = re.compile(r"\[(M|X|D|EST|LIT|SRC)\]")
for each line: v += len(VOC.findall(line)); skip it for labels when it opens or sits in a code fence or starts with '|'; l += len(LAB.findall(line))
before: git show <ref>:<page>; absent when the page does not exist at <ref>
```

## The figures [M]

| page | vocabulary, main | labels, main | vocabulary, stack | labels, stack | vocabulary, after | labels, after |
|---|---|---|---|---|---|---|
| `README.md` | 6 | 28 | 0 | 0 | 0 | 0 |
| `docs/README.md` | absent | absent | 0 | 6 | 0 | 6 |
| `docs/STATE-OF-THE-WORLD.md` | 147 | 41 | 0 | 0 | 0 | 0 |
| `docs/GLOSSARY.md` | absent | absent | 0 | 0 | 0 | 0 |
| `CLAUDE.public.md` | absent | absent | 0 | 8 | 0 | 8 |
| `CONTRIBUTING.md` | absent | absent | 0 | 7 | 0 | 7 |
| `SECURITY.md` | absent | absent | 0 | 0 | 0 | 0 |
| `lean/README.md` | 0 | 0 | 0 | 0 | 0 | 0 |
| `harness/README.md` | 28 | 35 | 3 | 0 | 3 | 0 |
| `docs/WRITE-UP.md` | 37 | 69 | 1 | 0 | 0 | 0 |
| `NORTH-STAR.md` | 11 | 0 | 11 | 0 | 11 | 0 |

## What the remaining hits are

- `docs/README.md` (6), `CLAUDE.public.md` (8) and `CONTRIBUTING.md` (7), labels: the legend that defines the six labels, one sentence or list item each; no label marks a claim in prose.
- `harness/README.md` (3), vocabulary: "window" as a time window of the P2P observation (the bounded window, the measured 2 s window); not process vocabulary.
- `NORTH-STAR.md` (11), vocabulary: the page is held to its first line by this fix's brief; the rest of the page is owed to its owner's re-cut.
- `docs/WRITE-UP.md`: the one hit at the stack ("The owner's earlier research") is re-cut to "The maintainers' earlier research".
