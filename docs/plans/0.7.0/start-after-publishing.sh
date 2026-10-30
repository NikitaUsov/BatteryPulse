#!/bin/bash
# Starts the short local Claude Code session of BatteryPulse 0.6.2's after-publishing check, which
# follows the section "After publishing" of SESSION-B.md beside this file, read from main. The
# maintainer runs two short commands, from any folder, once v0.6.2 is published:
#
#   git -C ~/BatteryPulse fetch origin main
#   bash <(git -C ~/BatteryPulse show FETCH_HEAD:docs/plans/0.7.0/start-after-publishing.sh)
#
# It must run from a terminal, never through a pipe, so Claude Code gets the terminal as its input
# (`bash <(...)` keeps it). No allow rule: under auto mode the session runs only the sentence's two
# git commands and two read-only checks, and does everything else by computer use.
cd ~/BatteryPulse || exit 1
DISABLE_AUTOUPDATER=1 exec claude --permission-mode auto 'Run the BatteryPulse 0.6.2 after-publishing check: run git -C ~/BatteryPulse fetch origin main && git -C ~/BatteryPulse show FETCH_HEAD:docs/plans/0.7.0/SESSION-B.md, then follow its section After publishing.'
