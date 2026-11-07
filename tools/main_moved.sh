#!/usr/bin/env bash
# Claude Code UserPromptSubmit hook (.claude/settings.json). Tells the agent when main has
# commits the current branch lacks, once per new main, so work starts from the latest
# main rather than the one the session cloned. Prints nothing otherwise, and never blocks.
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
GIT_TERMINAL_PROMPT=0 timeout 15 git fetch -q origin main 2>/dev/null || exit 0
main=$(git rev-parse -q --verify origin/main) || exit 0
seen=$(git rev-parse --git-path main_moved_seen)
[ "$(cat "$seen" 2>/dev/null)" = "$main" ] && exit 0
echo "$main" >"$seen"
missing=$(git rev-list --count HEAD..origin/main)
[ "$missing" -gt 0 ] || exit 0
own=$(git rev-list --count origin/main..HEAD)
echo "main has $missing commit(s) this branch doesn't:"
git log --format='  %s' -n 5 HEAD..origin/main
if [ "$own" -eq 0 ]; then
  echo "The branch has no commits of its own: before new work, git checkout -B" \
    "$(git branch --show-current) origin/main."
else
  echo "Before new work, merge origin/main (git merge origin/main --no-edit)."
fi
exit 0
