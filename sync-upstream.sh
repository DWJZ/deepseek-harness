#!/bin/sh
# Merge deepseek-ai/deepseek-harness `master` into this fork's `master`.
#
# `master` carries local commits (the plugin-facing session-event write side,
# the Trajectory extension row, and their docs), so this can never fast-forward
# and a conflict is possible whenever upstream edits the same regions. A
# conflict aborts the merge and leaves the branch exactly as it was; resolve it
# by hand and run the script again. Needs the `origin` (this fork) and
# `upstream` (deepseek-ai) remotes.
set -eu

BRANCH=master

if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  echo 'sync-upstream: tracked files have uncommitted changes; commit or stash them first' >&2
  exit 1
fi

git fetch --no-tags upstream "$BRANCH"
git fetch --no-tags origin "$BRANCH"
git checkout "$BRANCH"

if git merge-base --is-ancestor "upstream/$BRANCH" HEAD; then
  echo "sync-upstream: $BRANCH already contains upstream/$BRANCH"
  exit 0
fi

if ! git merge --no-edit "upstream/$BRANCH"; then
  git merge --abort
  echo "sync-upstream: upstream/$BRANCH conflicts with the local commits on $BRANCH; nothing changed" >&2
  exit 1
fi

git push origin "$BRANCH"
echo "sync-upstream: $BRANCH now contains upstream/$BRANCH"
