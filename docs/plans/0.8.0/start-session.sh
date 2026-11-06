#!/bin/bash
# Starts one of 0.8's M5 sessions with its start line (PLAN.md §6.1, §6.4, §6.6, and §6.0's hold
# watch), so the maintainer runs two short commands instead of pasting the long line (a paste broke
# 0.6.2's on 2026-10-27): its one allow rule (the session's own frozen worktree), auto mode, and a
# sentence whose section.sh prints that session's runbook section alone (§6.0 rule 1), the one way
# every start line reads its runbook (T-1 item 4). From any folder:
#
#   git -C ~/BatteryPulse fetch origin claude/080-integration
#   bash <(git -C ~/BatteryPulse show FETCH_HEAD:docs/plans/0.8.0/start-session.sh) look-shoot
#   bash <(git -C ~/BatteryPulse show FETCH_HEAD:docs/plans/0.8.0/start-session.sh) r8
#   bash <(git -C ~/BatteryPulse show FETCH_HEAD:docs/plans/0.8.0/start-session.sh) hold-watch
#
# After publishing, D3 posts the line with the release PR's number <n> and <keep>, the last commit
# that holds docs/plans/0.8.0/ (PLAN.md §13 step 4 removes it; the PR's head ref keeps its
# history), and the sentence "Don't press Install and Relaunch yourself; the session does it."
# (§6.0 rule 6):
#
#   git -C ~/BatteryPulse fetch origin refs/pull/<n>/head
#   bash <(git -C ~/BatteryPulse show <keep>:docs/plans/0.8.0/start-session.sh) after-publishing <n> <keep>
#
# It must run from a terminal, never through a pipe, so Claude Code gets the terminal as its input
# (`bash <(...)` keeps it). It changes to ~/BatteryPulse first. An earlier attempt's worktree is
# moved aside by the session itself (its section's first step), never here. Each case names its
# runbook and section as `runbook=<file> section="<heading>"`, which the dry run reads.
cd ~/BatteryPulse || exit 1
tail=""
case "${1:-}" in
  look-shoot)
    folder=L runbook=SESSION-L.md section="Look shoot" what="the BatteryPulse 0.8 look shoot"
    fetch=claude/080-integration show=FETCH_HEAD
    ;;
  r8)
    folder=R runbook=SESSION-R.md section="R8" what="the BatteryPulse 0.8 Session R8"
    fetch=claude/080-integration show=FETCH_HEAD
    ;;
  hold-watch)
    folder=H runbook=SESSION-R.md section="Hold watch" what="the BatteryPulse 0.8 hold watch"
    fetch=claude/080-integration show=FETCH_HEAD
    ;;
  after-publishing)
    case "${2:-}:${3:-}" in
      [0-9]*:[0-9a-f]*) ;;
      *)
        echo "usage: start-session.sh after-publishing <release PR number> <keep commit>" >&2
        exit 2
        ;;
    esac
    folder=D3 runbook=SESSION-R.md section="After publishing" what="the BatteryPulse 0.8.0 after-publishing check"
    fetch="refs/pull/$2/head" show="$3"
    tail=" Do not let anyone install the update before the before-picture."
    ;;
  *)
    echo "usage: start-session.sh look-shoot | r8 | hold-watch | after-publishing <n> <keep>" >&2
    exit 2
    ;;
esac
DISABLE_AUTOUPDATER=1 exec claude --allowedTools "Bash(bash ~/bp-080/$folder/run/docs/plans/0.8.0/m5-session.sh:*)" --permission-mode auto "Run $what hands-free: in ~/BatteryPulse run git fetch origin $fetch && bash <(git show $show:docs/plans/0.8.0/section.sh) $show $runbook $section, then follow only what it prints.$tail"
