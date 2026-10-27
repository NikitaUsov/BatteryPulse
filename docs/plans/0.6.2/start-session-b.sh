#!/bin/bash
# Starts Session B's local Claude Code session with SESSION-B.md's start line, so the maintainer
# runs two short commands instead of pasting the long line (a paste broke it on 2026-10-27: the
# terminal got it split, with long dashes for the double hyphens). It must run from a terminal,
# never through a pipe, so Claude Code gets the terminal as its input.
cd ~/BatteryPulse || exit 1
DISABLE_AUTOUPDATER=1 exec claude --allowedTools 'Bash(bash ~/bp-062/B/run/docs/plans/0.6.2/m5-session.sh:*)' --permission-mode auto 'Run the BatteryPulse M5 Session B hands-free: in ~/BatteryPulse run git fetch origin claude/nice-faraday-k08mhb && git show FETCH_HEAD:docs/plans/0.6.2/SESSION-B.md, then follow that runbook from its first step.'
