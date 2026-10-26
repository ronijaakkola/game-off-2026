# Godot Jam Boilerplate

Godot 4.7.2 GDScript project, web (itch.io) first, Compatibility renderer.

## Setup

1. Install **Godot 4.7.2** exactly. The whole team and CI are pinned to it.
2. Install the **4.7.2 Web export templates**. In the editor: **Editor → Manage Export Templates…**, download only the Web templates. Templates from another version (even 4.7.1) fail with "No export template found".
3. Install [uv](https://docs.astral.sh/uv/). `tools/check.py` runs through it and fetches its own Python packages.
4. Point the checks at Godot. They use the `GODOT` environment variable, or `godot` on the PATH.
   - **Windows:** `setx GODOT "C:\path\to\Godot_v4.7.2-stable_win64_console.exe"`, then open a new terminal and start Claude Code from that one, since terminals that were already open don't see the variable. Use the `_console` executable; the other one prints nothing. Clone to a short path (under about 120 characters). gdUnit4's files and Godot's `.godot/` cache are deeply nested, and git stops at Windows' 260-character limit unless `git config --global core.longpaths true` is set.
   - **Mac:** `export GODOT=/Applications/Godot.app/Contents/MacOS/Godot` in your shell profile, or `brew install godot` if it installs 4.7.2.
5. Enable the git hooks once per clone: `git config core.hooksPath .githooks`.
6. Run `uv run tools/check.py all`. It imports the project and should end with `PASS all`.

### Cloud sessions

A Claude Code cloud session starts without Godot. `tools/cloud_setup.sh` installs Godot 4.7.2, its Web export templates, uv, and a `godot` wrapper that runs windowed commands such as `capture` under Xvfb. It checks each download's hash, resumes a download the proxy cuts off, and skips what is already installed. Run it from the cloud environment's setup script:

1. Open the cloud environment menu in the session's title bar, then **Edit**.
2. Add these lines to **Setup script**, with this repo's owner and name:

   ```bash
   curl -fsSL -o /tmp/cloud_setup.sh https://raw.githubusercontent.com/<owner>/<repo>/main/tools/cloud_setup.sh
   bash /tmp/cloud_setup.sh
   ```

   The setup script can't count on the repo being cloned yet, so it downloads the script from `main`. For a private repo, paste the contents of `tools/cloud_setup.sh` instead.
3. Start a new session. The first one downloads 1.4 GB, about a minute.

In cloud sessions only, a SessionStart hook (`tools/cloud_session_start.sh`) enables the git hooks and tells the agent when Godot or the templates are missing.

## Layout

| Folder | What goes there |
|---|---|
| `addons/` | Vendored plugins at pinned versions. Never hand-edited. |
| `core/<system>/` | One folder per autoload. |
| `ui/` | Main menu, settings screen, Theme, shared widgets. |
| `game/` | The example game scene, replaced on jam day. |
| `shared/` | Assets used by more than one feature. |
| `test/` | gdUnit4 tests, mirroring the `res://` path of what they test. |
| `tools/` | `check.py`, `blender.py` and their helper scripts. Not exported. |
| `art/` | The model library, `art/models.blend`. Not committed. |

## Making models

Only whoever makes 3D models needs Blender. Everyone else, and CI, uses the committed `.glb` files. Models are built by agents (the `blender-models` skill) and sometimes finished by hand, all in one Blender file per modeller, `art/models.blend`, which git ignores. A human exports with the same command as an agent.

1. Install **Blender 5.2**.
2. Point the tool at it with the `BLENDER` environment variable, or `blender` on the PATH.
   - **Mac:** `export BLENDER=/Applications/Blender.app/Contents/MacOS/Blender` in your shell profile.
   - **Windows:** `setx BLENDER "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"` (not yet tried on Windows).
3. Optional, so the agent can work in your open Blender: set up the [Blender Lab MCP](https://www.blender.org/lab/mcp-server/).
   1. `git clone https://projects.blender.org/lab/blender_mcp.git ~/blender_mcp`, then `git -C ~/blender_mcp checkout v1.0.3`.
   2. Drag the add-on link from the MCP page into Blender, twice (the first adds the repository, the second installs).
   3. In Blender, Preferences › System › **Allow Online Access** on. Without it the add-on doesn't start.
   4. `claude mcp add blender -- uv --directory ~/blender_mcp/mcp run blender-mcp`, then restart Claude Code.

| Command | What it does |
|---|---|
| `uv run tools/blender.py run <script>` | Runs a build script against `art/models.blend` and saves it. Creates the library on first use. Close the library in Blender first. |
| `uv run tools/blender.py preview <model>` | Renders the model from four sides to `build/preview/<model>.png`. |
| `uv run tools/blender.py export <model>` | Exports the model to its `.glb`, imports it into Godot and captures it in `build/capture/`. |

Save in Blender before `preview` or `export`: both read the file on disk.

## Pinned versions

| Tool | Version |
|---|---|
| Godot | 4.7.2 |
| gdUnit4 | 6.2.2 (`addons/gdUnit4/`) |
| LimboConsole | 0.8.0 (`addons/limbo_console/`) |
| Talo | 1.2.0 (`addons/talo/`) |
| gdtoolkit | 4.5.0 (pinned in `tools/check.py`) |
| Blender | 5.2 (checked by `tools/blender.py`), only for making models |

## Checks

Every check is a `tools/check.py` subcommand, and works the same on Windows, Mac and Linux. Each one prints `PASS` or `FAIL` and exits non-zero on failure. Agents run them; humans working in the editor have an equivalent for each.

| Command | What it does | In the editor |
|---|---|---|
| `uv run tools/check.py lint [files]` | `gdlint`, `gdformat --check` and the rules in `CODING_STANDARDS.md` that need no Godot, on the given files or the whole project, skipping `addons/`. Runs on every commit and after every Claude Code edit. No Godot needed. | The pre-commit hook does it for you |
| `uv run tools/check.py format [files]` | Applies `gdformat` to the given scripts or every script outside `addons/`. Fixes what `lint` reports as formatting. | The same command |
| `uv run tools/check.py load` | Loads every script, scene and resource. Fails on parse and type errors and missing dependencies. | Errors in the Output panel, or F5 |
| `uv run tools/check.py test` | Runs the gdUnit4 tests in `test/`. Reports go to `build/reports/`. | The gdUnit panel's run button |
| `uv run tools/check.py smoke [scenes]` | Runs every scene the game reaches from the main scene and the autoloads, each on its own, the main scene first (or the given ones), headless for 300 frames each and fails if any error is logged. | F5 or F6, then the Output panel |
| `uv run tools/check.py capture <scene>` | Renders a second of the scene in a window and saves the frames to `build/capture/`. | Run the scene and look |
| `uv run tools/check.py evidence [frame]` | Pushes the last capture frame, or the one given, to the `pr-evidence` branch and prints a markdown image line for a PR body. Not a check; see Evidence frames. | Drag the frame into the PR description |
| `uv run tools/check.py api <query>` | Looks up the Godot 4.7.2 class reference: a class (`api Tween`), one member (`api Tween.kill`) or a search (`api volume_linear`). Not a check: it prints the reference, or `FAIL api` when nothing matches. The first run builds it into `build/api/`. | The Help search (F1) in the script editor |
| `uv run tools/check.py all` | `lint`, `load`, `test` and `smoke`. | All of the above |
| `uv run tools/check.py export` | Exports the web build to `build/web/` (needs the Web templates, step 2), prints the `.pck` size and boots it headless, on the main scene and on `game/game.tscn`. Fails on any logged error except LimboConsole's missing autoload. The deploy runs it too. | Project → Export… → Web |
| `uv run tools/check.py export --preview` | Exports the preview build (below) to `build/web-preview/game/`, puts the itch-style frame page at `build/web-preview/index.html` and boots the build headless. Fails on any logged error. | Project → Export… → Web Preview, with Export With Debug on |

Pull requests run two CI checks: `gdUnit4 tests` (`uv run tools/check.py test`) and `Lint, load check, smoke run`. Both must pass to merge into `main`. Every push to `main` runs `uv run tools/check.py all` on the merged commit and, if it passes, deploys the web build to itch.io. A failure leaves the last good build there.

## Preview builds

Every pull request gets a playable web build at `https://<owner>.github.io/<repo>/pr-preview/pr-<number>/`. A comment on the PR links it, and the link works about a minute later, once GitHub Pages has deployed. It updates on each push and is removed when the PR closes. The `pr-preview` workflow builds it with `uv run tools/check.py export --preview` and publishes it to the `gh-pages` branch. It isn't a required check and doesn't wait for the tests. PRs from forks get no preview.

The page frames the game like itch.io's embed: the game runs in an iframe at the project's 1152×648, and the **Fullscreen** button under it fullscreens that iframe, as itch's button does. Use it to test fullscreen. **Open without the frame** runs the game on its own page.

A preview build differs from the itch.io build in two ways:

- **It has the dev console.** Click into the game, then F1. `goto <scene path>` jumps to a scene.
- **It uses the debug template.** Script errors show in the browser's devtools console with a file and line; the itch build silently skips past them.

Both make it slower and larger (a `.pck` of about 9 MB instead of 1.3 MB), so don't judge performance from a preview. Play the itch.io build for that. Pages caches files for 10 minutes, so hard-reload after a new push.

## Evidence frames

A PR body can't show a file from `build/`, which git ignores, and agents can't upload an image through GitHub's API. `uv run tools/check.py evidence` works around both: it commits the frame on its own to the `pr-evidence` branch, without touching the working tree or the current branch, and prints a `raw.githubusercontent.com` link pinned to that commit. The link keeps working after later pushes, and the repo must stay public for it to show.

The branch only grows, and every full clone fetches it. The main menu's frame is 15 KB; a 3D scene's is larger. After the jam, deleting the branch frees the space and breaks the images in old PR bodies.
