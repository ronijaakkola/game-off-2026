#!/usr/bin/env bash
# Claude Code SessionStart hook (.claude/settings.json). In a cloud session it enables
# the git hooks and checks that tools/cloud_setup.sh has installed Godot. Locally it
# does nothing. It never blocks the session: what it prints goes to the agent.
[ "${CLAUDE_CODE_REMOTE:-}" = true ] || exit 0
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

git config core.hooksPath .githooks

version=$(sed -n 's/^GODOT_VERSION = "\(.*\)"$/\1/p' tools/check.py)
templates=${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$version.stable
found=$(timeout 30 "${GODOT:-godot}" --headless --version 2>/dev/null)
problems=()
[[ $found == "$version.stable."* ]] ||
  problems+=("Godot $version is not installed (found: ${found:-nothing})")
[ -f "$templates/web_nothreads_release.zip" ] || problems+=("the Web export templates are missing")
command -v xvfb-run >/dev/null || problems+=("xvfb-run is missing")
command -v uv >/dev/null || problems+=("uv is missing")

if [ ${#problems[@]} -gt 0 ]; then
  message=""
  for problem in "${problems[@]}"; do message+="${message:+; }$problem"; done
  echo "Cloud setup incomplete: $message."
  echo "Run \`bash tools/cloud_setup.sh\` (downloads 1.4 GB, about a minute), then tell" \
    "the human to add it to the cloud environment's setup script" \
    "(README.md, Setup › Cloud sessions)."
fi
exit 0
