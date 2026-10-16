# 0.6.1 plan: optimization and foundation (work in progress)

0.6.1 is an optimization and foundation release: readability, speed, energy, security, size and
less unneeded code, measured before and after, with no loss of functionality.

State on 2026-10-16: planning done, implementation paused until the maintainer says go.

- `research/` — best-practice research in five areas (SwiftUI, Swift 6.4, energy, security,
  size), each item checked against its source and the code by a second reviewer.
- `playbook.md` — the rules, the measurement protocol and the prioritized backlog with work
  packages, built from the research.
- `audit-*.md` — the codebase audited against the playbook in six areas (`core`, `kit`,
  `app-core`, `app-views`, `app-chrome`, `cli-build`); `audit-*-verified.md` — every finding
  checked by a second reviewer (keep, keep with changes, reject). The verified files win.
- `PLAN.md` — the executable plan: packages in run order with owned files, gates and defaults,
  acceptance checks, effort and the cut line; the measurements, the one M5 session, the proof of
  no lost functionality, the release steps, open questions and the traceability appendix.

Next: the maintainer's answers to `PLAN.md` §8 and the two look decisions (tile picker selection,
Clear's dimming), then Phase A.

These notes are planning material for this release; they leave the repository once 0.6.1 ships
(the decisions that last go to `docs/ROADMAP.md`).
