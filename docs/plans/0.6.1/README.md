# 0.6.1 plan: optimization and foundation (work in progress)

0.6.1 is an optimization and foundation release: readability, speed, energy, security, size and
less unneeded code, measured before and after, with no loss of functionality.

Paused on 2026-10-16 to save the weekly usage budget. State when paused:

- `research/` — best-practice research in five areas (SwiftUI, Swift 6.4, energy, security,
  size), each item checked against its source and the code by a second reviewer. Done.
- `playbook.md` — the rules, the measurement protocol and the prioritized backlog with work
  packages, built from the research. Done.
- `audit-*.md` — the codebase audited against the playbook. Done: `core`, `kit`, `app-core`,
  `app-views`; `app-chrome` (menu bar, Settings, Welcome, widget) may be incomplete; `cli-build`
  (bpulse, Package.swift, scripts, CI, resources, dead code) not started.

Next: finish the `app-chrome` and `cli-build` audits, have every finding checked by a second
reviewer, then implement the kept findings as the playbook's work packages, each in its own
branch with a review, and release 0.6.1 after CI and the measurements.

These notes are planning material for this release; they leave the repository once 0.6.1 ships
(the decisions that last go to `docs/ROADMAP.md`).
