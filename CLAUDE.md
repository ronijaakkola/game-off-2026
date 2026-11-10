# Godot jam game

Godot 4.7.2, GDScript only, Compatibility renderer, played on the web (itch.io) first.

- `CODING_STANDARDS.md`: layout, naming, typing, autoloads, scene composition, signals, script size, merges. Read it before writing code or adding or moving any file.
- `DESIGN.md`: the design decisions the game logic follows. Read it before gameplay work. When a rule or one of its numbers changes, rewrite its bullet; how a thing looks or moves doesn't go there.
- `docs/ui.md`: the look, and what each part of the screen shows and how it moves. Read it before work on the look, the HUD, a panel or an animation, and rewrite its bullet when that changes.
- `CONTEXT.md`: the glossary. Use its terms in code, UI text and handoffs; `lint` fails on the ones it lists as _Never_.
- `docs/web-constraints.md`: read it before touching shaders, environment, lighting, loading or audio.
- `docs/cameras.md`: read it before touching a camera, a shot, or anything placed from the camera.
- `docs/online.md`: read it before wiring analytics, stats or leaderboards.

Before changing a balance number (fares, costs, happiness, who turns up), measure it: `uv run tools/balance.py run` plays the real game headless on fixed seeds with a scripted player and prints ratings, income and pace, and `--variants` compares changes side by side (`uv run tools/balance.py --help`).

Both design docs hold the current state only: change a bullet in place, never append what happened, and leave out what the code already says.

Ask the human before changing anything outside the repo, such as export templates, editor settings or global git config.

## Checks

Run checks exactly as `uv run tools/check.py <command>`. That text is allowlisted, and the script owns every Godot flag.

Keep the loop short while a feature takes shape: `load` (10 s) and the suites for what you touched (about 7 s). The full `test` and `smoke` take about 15 s each, so they run in `all` when the feature works, not after every edit. CI runs everything again on the PR.

| Command | When |
|---|---|
| `lint [files]` | Runs by itself after every edit to a `.gd`, `.tscn` or `.gdshader` file; fix what it reports. `format [files]` fixes what it reports as formatting. |
| `load` | After editing scripts, scenes or resources. |
| `ids [files]` | After writing a `.tscn` or `.tres` as text (the `edit-tscn` skill). Saves every one missing a `uid` or `unique_id` the way the editor does, so Godot assigns them; commit the result. `lint` fails until it runs. |
| `test [files] [--verbose]` | While building, only the suites or folders for what you changed: `test test/game/bus/`. The whole run is part of `all`. A feature still taking shape gets no new tests; they come once it's settled, apart from a regression test for a fixed bug (the `gdunit-tests` skill). `--verbose` shows the tests' `print()` lines. |
| `smoke [scenes]` | While building, only a scene you changed that might error on start: `smoke res://game/bus/bus.tscn`. With no scenes it runs every scene the game reaches, each on its own, which `all` does. |
| `capture <scene> [--size WxH] [--frames N] [-- args]` | When a visual change is done, not after every tweak. Then open the last frame it names and look at it. `--size` scales the game as a browser window does (text and UI sharpness show only then); args after `--` reach the scene through `OS.get_cmdline_user_args()`. |
| `evidence [frame]` | When a PR body needs a frame. Pushes the last capture frame, or the one given, to the `pr-evidence` branch and prints the image line to paste under Evidence. |
| `api <query>` | Before using a Godot API you aren't sure exists in 4.7.2. `Class`, `Class.member`, or a word to search for. |
| `all` | Once, before handoff, when the feature works. Runs `lint` and `load`, then `test` and `smoke` at the same time, in about 20 s. Give it `timeout: 600000` anyway: a hung test stops only at the 300 s Godot timeout. When it fails, fix it with the failing step on just what failed (`test <suite>`, `smoke <scene>`), then run `all` once more. |
| `export [--preview]` | After changes to export presets, `project.godot` or `addons/`. Exports Web to `build/web/` and boots it; `--preview` exports the preview build to `build/web-preview/` instead. |

## Handoff

- Paste the result lines of `uv run tools/check.py all` exactly as printed, failing step included.
- When a change is about feel (the soft look, lighting, camera, motion, sound), end with "Needs a visual check: `<scene>`".
- When `lint` warned that a script you added to is near its size limit (`script-size`), say which job you moved out, or the split you would make and why it didn't come out cleanly.
- When a check can't run (Godot not found, no window for `capture`), say which ones didn't run and name the editor equivalent for the human, from the last column of README.md, Checks.

## Issues

Work lives in this repo's GitHub Issues and the team's GitHub Project. Read one with `gh issue view <n>`.

## Git conventions

- **Commit messages and PR titles** follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/): `<type>(<optional scope>)!: <description>`, with type one of `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`. Example: `feat(player): add double jump`. The `commit-msg` hook checks commits; nothing checks PR titles, and GitHub writes the squash commit from the title, so get it right by hand.
- **Every change reaches `main` through a PR**, merged with GitHub's **Squash and merge**. Update a branch however you like, merge or rebase — the squash flattens it either way.

Working on a PR:

- The body follows `.github/pull_request_template.md`: what changed, the evidence it works, what it can reach.
- Check the PR is still open before pushing to its branch: `gh pr view <n> --json state`.
- Wait for CI with `gh pr checks <n> --watch`. Never write a polling loop.
- Never close or reopen a PR. Merge only when the human asks for it in the conversation, with Squash and merge, once CI is green on the current head.

The hooks in `.githooks/` (`commit-msg`, `pre-commit`) enforce the commit message and lint what you commit. Enable them once per clone with `git config core.hooksPath .githooks` (cloud sessions do it for you).

## Cloud sessions

When `CLAUDE_CODE_REMOTE` is `true`, GitHub's GraphQL API is blocked, so `gh issue`, `gh pr` and `gh project` fail with HTTP 403. Use the REST API through `gh api` instead (it fills in `{owner}/{repo}` from the remote), or the GitHub MCP tools:

| Instead of | Use |
|---|---|
| `gh issue view <n>` | `gh api 'repos/{owner}/{repo}/issues/<n>'`, and `.../issues/<n>/comments` for the comments |
| `gh pr view <n> --json state` | `gh api 'repos/{owner}/{repo}/pulls/<n>' --jq .state` |
| `gh pr checks <n> --watch` | Subscribe to the PR's activity; CI results arrive as events |
| `gh pr create` | `gh api 'repos/{owner}/{repo}/pulls' -f base=main -f head=<branch> -f title=<title> -F body=@<file>` |

For a one-off look at CI: `gh api 'repos/{owner}/{repo}/commits/<sha>/check-runs' --jq '.check_runs[] | "\(.name): \(.conclusion)"'`.

Only repository-scoped endpoints are reachable, so the team's GitHub Project isn't. Ask the human when an issue's place on the board matters.

When the SessionStart hook reports that Godot or the Web templates are missing, run `bash tools/cloud_setup.sh` and tell the human to add it to the environment's setup script (README.md, Setup › Cloud sessions).
