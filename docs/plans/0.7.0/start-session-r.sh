#!/bin/bash
# Starts Session R's local Claude Code session with PLAN.md §6.2's start line, so the maintainer runs
# two short commands instead of pasting the long line (a paste broke 0.6.2's on 2026-10-27). From
# any folder:
#
#   git -C ~/BatteryPulse fetch origin claude/070-integration
#   bash <(git -C ~/BatteryPulse show FETCH_HEAD:docs/plans/0.7.0/start-session-r.sh)
#
# It must run from a terminal, never through a pipe, so Claude Code gets the terminal as its input
# (`bash <(...)` keeps it). It changes to ~/BatteryPulse first. The sentence prints SESSION-R.md only
# up to its short sessions, which Session R doesn't need (0.6.2's after-publishing check: a whole
# runbook printed at once was too long). An earlier attempt's ~/bp-070/R is moved aside by the
# session itself (SESSION-R.md, R0 step 1), never here.
cd ~/BatteryPulse || exit 1
DISABLE_AUTOUPDATER=1 exec claude --allowedTools 'Bash(bash ~/bp-070/R/run/docs/plans/0.7.0/m5-session.sh:*)' --permission-mode auto 'Run the BatteryPulse M5 Session R hands-free: in ~/BatteryPulse run git fetch origin claude/070-integration && git show FETCH_HEAD:docs/plans/0.7.0/SESSION-R.md | sed "/^## The short sessions/,\$d", then follow that runbook from its first step.'
