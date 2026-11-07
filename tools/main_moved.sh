#!/usr/bin/env bash
# Claude Code UserPromptSubmit hook (.claude/settings.json). In a cloud session, tells the
# agent when it is about to start work on an old main: the branch has no commits of its
# own and main has moved since the session cloned it. A branch with its own commits hears
# nothing, since its PR reports a real conflict. Fetches at most every 10 minutes, says
# it once per new main, and never blocks. Locally it does nothing.
[ "${CLAUDE_CODE_REMOTE:-}" = true ] || exit 0
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
[ "$(git rev-list --count origin/main..HEAD 2>/dev/null)" = 0 ] || exit 0
stamp=$(git rev-parse --git-path main_moved_fetched)
if [ -z "$(find "$stamp" -mmin -10 2>/dev/null)" ]; then
  touch "$stamp"
  GIT_TERMINAL_PROMPT=0 timeout 15 git fetch -q origin main 2>/dev/null || exit 0
fi
main=$(git rev-parse -q --verify origin/main) || exit 0
seen=$(git rev-parse --git-path main_moved_seen)
[ "$(cat "$seen" 2>/dev/null)" = "$main" ] && exit 0
echo "$main" >"$seen"
missing=$(git rev-list --count HEAD..origin/main)
[ "$missing" -gt 0 ] || exit 0
echo "main has $missing commit(s) this branch doesn't, and the branch has none of its own:"
git log --format='  %s' -n 5 HEAD..origin/main
echo "Before new work: git checkout -B $(git branch --show-current) origin/main."
exit 0
