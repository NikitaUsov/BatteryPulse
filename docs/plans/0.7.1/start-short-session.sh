#!/bin/bash
# Starts one of Session R's short sessions (PLAN.md §6.2, "The short sessions"): its own frozen
# worktree in the one allow rule, and a sentence that prints only its section of SESSION-R.md
# (0.6.2's after-publishing check: a whole runbook printed at once was too long). From any folder:
#
#   git -C ~/BatteryPulse fetch origin claude/070-integration
#   bash <(git -C ~/BatteryPulse show FETCH_HEAD:docs/plans/0.7.1/start-short-session.sh) charge-limit
#   bash <(git -C ~/BatteryPulse show FETCH_HEAD:docs/plans/0.7.1/start-short-session.sh) hold-watch
#
# After publishing, D3 posts the line with the release PR's number <n> and <keep>, the last commit
# that holds docs/plans/0.7.1/ (§13 step 4 removes it; the PR's head ref keeps that history):
#
#   git -C ~/BatteryPulse fetch origin refs/pull/<n>/head
#   bash <(git -C ~/BatteryPulse show <keep>:docs/plans/0.7.1/start-short-session.sh) after-publishing <n> <keep>
#
# It must run from a terminal, never through a pipe, so Claude Code gets the terminal as its input.
cd ~/BatteryPulse || exit 1
case "${1:-}" in
  charge-limit)
    folder=C
    section="Charge limit"
    what="the BatteryPulse 0.7 charge-limit capture"
    fetch="claude/070-integration"
    show=FETCH_HEAD
    ;;
  hold-watch)
    folder=H
    section="Hold watch"
    what="the BatteryPulse 0.7 hold watch"
    fetch="claude/070-integration"
    show=FETCH_HEAD
    ;;
  after-publishing)
    case "${2:-}:${3:-}" in
      [0-9]*:[0-9a-f]*) ;;
      *)
        echo "usage: start-short-session.sh after-publishing <release PR number> <keep commit>" >&2
        exit 2
        ;;
    esac
    folder=D3
    section="After publishing"
    what="the BatteryPulse 0.7.0 after-publishing check"
    fetch="refs/pull/$2/head"
    show="$3"
    ;;
  *)
    echo "usage: start-short-session.sh charge-limit | hold-watch | after-publishing <n> <keep>" >&2
    exit 2
    ;;
esac
DISABLE_AUTOUPDATER=1 exec claude --allowedTools "Bash(bash ~/bp-070/$folder/run/docs/plans/0.7.1/m5-session.sh:*)" --permission-mode auto "Run $what hands-free: in ~/BatteryPulse run git fetch origin $fetch && git show $show:docs/plans/0.7.1/SESSION-R.md | sed -n \"/^## The short sessions/,/^## Charge limit/p;/^## $section/,/^## [A-Z]/p\", then follow its section $section, with the worktree ~/bp-070/$folder/run at $show."
