#!/bin/bash
# Prints one section of a runbook beside it (SESSION-L.md, SESSION-R.md) by its heading, as a
# commit holds it, so a session's start sentence shows it that section alone (PLAN.md §6.0 rule
# 1, T-1 item 4): a session never reads, or acts on, another session's section, and nothing it
# reads comes from a checkout that may have moved. Every start line runs it the same way, from
# ~/BatteryPulse, right after fetching the commit:
#
#   git fetch origin claude/080-integration &&
#     bash <(git show FETCH_HEAD:docs/plans/0.8.0/section.sh) FETCH_HEAD SESSION-L.md Look shoot
#
# <commit> is FETCH_HEAD, or after publishing <keep>, the last commit that holds docs/plans/0.8.0/
# (PLAN.md §13 step 4 then removes it). The heading is the section's `## ` line without its
# hashes, its words as they are; the section runs to the next `## ` heading, its `### `
# subsections with it. `--worktree` in place of the commit reads the runbook beside this file
# instead (the dry run's size check). Exit status 0 printed, 1 no such runbook or section (its
# headings listed), 2 a wrong call. It reads git's objects only: no file in the checkout changes.
set -euo pipefail

if [ $# -lt 3 ]; then
  echo "usage: section.sh <commit> | --worktree <SESSION-L.md|SESSION-R.md> <heading words...>" >&2
  exit 2
fi
commit="$1"
runbook="$2"
shift 2
heading="## $*"
case "$runbook" in
  SESSION-L.md | SESSION-R.md) ;;
  *)
    echo "section.sh: the runbooks are SESSION-L.md and SESSION-R.md" >&2
    exit 2
    ;;
esac
if [ "$commit" = --worktree ]; then
  text="$(cat "$(cd "$(dirname "$0")" && pwd)/$runbook" 2>/dev/null)" || {
    echo "section.sh: no $runbook beside section.sh" >&2
    exit 1
  }
  where="the worktree"
else
  text="$(git show "$commit:docs/plans/0.8.0/$runbook" 2>/dev/null)" || {
    echo "section.sh: no docs/plans/0.8.0/$runbook at $commit (fetch it first)" >&2
    exit 1
  }
  where="$(git rev-parse --short "$commit" 2>/dev/null || echo "$commit")"
fi
section="$(awk -v h="$heading" '$0 == h { on = 1; print; next } on && /^## / { exit } on { print }' <<<"$text")"
if [ -z "$section" ]; then
  echo "section.sh: no section \"$heading\" in $runbook at $where; its sections:" >&2
  grep '^## ' <<<"$text" >&2 || true
  exit 1
fi
printf '%s\n\n(section.sh printed this section of %s at %s alone: follow it, and read no other section\nbut those it names.)\n' \
  "$section" "$runbook" "$where"
