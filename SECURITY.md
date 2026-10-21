# Security

## Report privately

Report a security concern through GitHub's private vulnerability reporting form: the "Report a vulnerability" button under this repository's Security tab.
Never open an issue for it on the tracker.

`docs/WRITE-UP.md` §11 states the rule in these words:

> **A security concern.** A divergence that lets a transaction be accepted by one implementation and refused by another is a chain-split or a theft risk for whoever runs the weaker side. Send it privately through the public repository's private vulnerability reporting form (the "Report a vulnerability" button under its Security tab), not on the issue tracker. The program's own findings follow the same discipline (§7, the withheld classes).

A divergence with no such risk goes to the issue tracker as a divergence report (`CONTRIBUTING.md`, "Report a divergence").

## What to include

Send the witness, the same fields a divergence report carries:

- the transaction hex;
- its previous outputs and their heights;
- the parameters: the era and the flags;
- both verdicts, with the implementation and its version;
- the rule it exercises;
- the citations at the pins (`docs/PROVENANCE.md` §1a names the pins);
- how you ran it: the harness command and its record.

Say which implementations you believe are affected and whether the risk is a chain split, a theft, or both.

## Withheld classes

A divergence class under an open disclosure is withheld from the public pages by name until its fix: its row keeps its kind, its ruling, its corpus, its column and its count, and its name, witness and citation stay out.
The counts on the public pages include it, and the class is published when the fix ships or 90 days after the report (`docs/WRITE-UP.md` §7).

## After a report

The maintainers report a concern to the affected project through that project's own channel.
They also read every pinned upstream once a month and in the week any of them releases, open an issue for each consensus change the week it lands, and the spec's page carries its source citation the week after (`docs/WRITE-UP.md` §12, `docs/recon.md`).
