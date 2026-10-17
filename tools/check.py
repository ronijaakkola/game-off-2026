# /// script
# requires-python = ">=3.10"
# dependencies = ["gdtoolkit==4.5.0"]
# ///
"""Project checks. Run from anywhere: `uv run tools/check.py <command>`.

  lint [files]     gdlint, gdformat --check and the project rules on the given files, or
                   the whole project (no Godot needed)
  lint --hook      Claude Code PostToolUse hook: lint the edited file, or after a shell
                   command the files changed since the last one, exit 2 on problems
  format [files]   gdformat the given .gd files, or every script outside addons/
  load             compile every script outside addons/ (the load check)
  ids [files]      save the given scenes and resources, or every one outside addons/, that
                   lack a uid or unique_id, the way the editor does, so Godot assigns them
  test             run the gdUnit4 tests in test/
  smoke [scenes]   run the main scene and the game scene (or the given ones) headless,
                   fail on any logged error
  capture <scene>  render ~1 s of a scene in a window, save the frames to build/capture/
  all              lint, load, test, smoke
  export           export Web to build/web/ and boot the .pck headless (needs the Web templates)
  export --preview export Web Preview (dev console, debug template) to build/web-preview/
  evidence [frame] push a capture frame (default: the last one) to the pr-evidence branch
                   and print the markdown image line that shows it in a PR body
  api <query>      look up the Godot 4.7.2 class reference: `api Tween` (a class),
                   `api Tween.kill` (one member), `api volume` (a search)
  api --search <text>  search class and member names even when <text> is a class
  api <Class> --full   also print the class description
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from importlib.metadata import version as pkg_version
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GODOT_VERSION = "4.7.2"
TIMEOUT = 300
SMOKE_FRAMES = "300"
# The main menu reaches it only after a click, so smoke runs it on its own as well.
GAME_SCENE = "res://game/game.tscn"
CAPTURE_FRAMES = "60"
# Written by run_export and read by the main menu; ignored by git.
BUILD_COMMIT_FILE = "ui/main_menu/build_commit.txt"
ERROR_LINE = re.compile(r"^(SCRIPT )?ERROR", re.MULTILINE)
ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
# Godot 4.7.2 leaks an Ogg stream that is still playing when it quits, so any scene
# with music logs this at the end of a smoke run. It happens only at exit.
EXIT_LEAK = re.compile(r"^ERROR: 2 resources still in use at exit.*$", re.MULTILINE)
# The Web preset leaves LimboConsole out, so the exported pack can't load its autoload.
WEB_CONSOLE_MISSING = re.compile(
    r"^ERROR: (Attempt to open script '|Failed loading resource: "
    r"|Failed to instantiate an autoload, can't load from path: )"
    r"res://addons/limbo_console/limbo_console\.gd.*$",
    re.MULTILINE,
)
# -d with an unusable --remote-debug port (see run_godot) logs these at every test run.
DEBUGGER_NOISE = re.compile(
    r"^ERROR: (The remote port number|Remote Debugger: Unable to connect).*\n   at: .*\n",
    re.MULTILINE,
)
FAILED_TEST = re.compile(r"^  [^\n]* > [^\n]* FAILED.*?\n\n", re.MULTILINE | re.DOTALL)
LINT_STAMP = Path(".godot/lint_hook_stamp")


class CheckFailed(Exception):
    pass


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    commands = parser.add_subparsers(dest="command", required=True)
    lint = commands.add_parser("lint")
    lint.add_argument("files", nargs="*")
    lint.add_argument("--hook", action="store_true")
    commands.add_parser("format").add_argument("files", nargs="*")
    commands.add_parser("load")
    commands.add_parser("ids").add_argument("files", nargs="*")
    commands.add_parser("test")
    commands.add_parser("smoke").add_argument("scenes", nargs="*")
    commands.add_parser("capture").add_argument("scene")
    commands.add_parser("all")
    commands.add_parser("export").add_argument("--preview", action="store_true")
    commands.add_parser("evidence").add_argument("frame", nargs="?")
    api = commands.add_parser("api")
    api.add_argument("query")
    api.add_argument("--search", action="store_true")
    api.add_argument("--full", action="store_true")
    args = parser.parse_args()
    os.chdir(ROOT)
    # Windows pipes default to cp1252, which mangles non-ASCII paths (C:\Users\Mäkinen).
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

    if args.command == "lint" and args.hook:
        return lint_hook()
    if args.command == "api":
        return run_api(args.query, args.search, args.full)
    steps = {
        "lint": lambda: run_lint(getattr(args, "files", [])),
        "format": lambda: run_format(args.files),
        "load": run_load,
        "ids": lambda: run_ids(args.files),
        "test": run_test,
        "smoke": lambda: run_smoke(getattr(args, "scenes", [])),
        "capture": lambda: run_capture(args.scene),
        "export": lambda: run_export(args.preview),
        "evidence": lambda: run_evidence(args.frame),
    }
    names = ["lint", "load", "test", "smoke"] if args.command == "all" else [args.command]
    failed = [name for name in names if not run_step(name, steps[name])]
    if args.command == "all":
        print("FAIL all: " + ", ".join(failed) if failed else "PASS all")
    return 1 if failed else 0


def run_step(name, step) -> bool:
    try:
        note = step()
    except CheckFailed as failure:
        print(f"FAIL {name}: {failure}")
        return False
    print(f"PASS {name}" + (f": {note}" if note else ""))
    return True


# --- lint -------------------------------------------------------------------

# Written rules that a regex can check without Godot. Each message names its rule and
# the doc section behind it, so it can be fixed without reading the doc.
SCENE_COMPOSITION = "CODING_STANDARDS.md, Scene composition"
SIGNALS = "CODING_STANDARDS.md, Signals: local or bus"
DEV_CONSOLE = "CODING_STANDARDS.md, Dev console"
ONLINE = "CODING_STANDARDS.md, Online"
TESTS = "CODING_STANDARDS.md, Tests"
ASSETS = "CODING_STANDARDS.md, Assets"
FORMATTING = "CODING_STANDARDS.md, Naming"
SHADER_COMMENTS = "docs/web-constraints.md, Shader comments are //"
UNIQUE_IDS = ".claude/skills/edit-tscn/SKILL.md, uid and unique_id"
EVENTS_SCRIPT = "core/events/events.gd"
DEV_COMMANDS = "core/dev_console/dev_commands.gd"
ONLINE_FOLDER = "core/online/"
LINTED = (".gd", ".tscn", ".gdshader")
# Vendored, generated or ignored by git: nothing in these folders is ours to lint.
# Hidden folders (.godot, .claude) are skipped too, as Godot skips them.
NOT_OURS_AT_ROOT = {"addons", "android", "art"}
NOT_OURS_ANYWHERE = {"build", "reports", "__pycache__"}
ASSET_LIMIT_MB = 10
# A comment, or a string literal (group 2). One pattern, so a # inside a string isn't
# a comment and a quote inside a comment doesn't start a string.
GD_COMMENT_OR_STRING = re.compile(
    r"""(#[^\n]*)|("{3}[\s\S]*?"{3}|'{3}[\s\S]*?'{3}|"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*')"""
)
OWN_GET_PARENT = re.compile(r"(?<![\w.])get_parent\s*\(|\bself\s*\.\s*get_parent\s*\(")
SHADER_DIRECTIVE = re.compile(
    r"#\s*(define|undef|include|if|ifdef|ifndef|elif|else|endif|error|pragma)\b"
)
WOULD_REFORMAT = re.compile(r"^would reformat (.+)$", re.MULTILINE)


def project_path(path: str) -> str:
    """The path from the project root, with forward slashes."""
    return Path(os.path.relpath(Path(path).resolve(), ROOT)).as_posix()


def ours(path: str) -> bool:
    """A project path outside addons/ and the ignored folders. gdlint ignores its
    excluded_directories for explicit file paths (gdtoolkit#395), so they're filtered here."""
    folders = path.split("/")[:-1]
    return not (
        (folders and folders[0] in NOT_OURS_AT_ROOT)
        or NOT_OURS_ANYWHERE.intersection(folders)
        or any(folder.startswith(".") for folder in folders)
    )


def project_files() -> list[str]:
    files = []
    for directory, subdirectories, names in os.walk("."):
        subdirectories[:] = [
            d for d in subdirectories if ours(Path(directory, d, "file").as_posix())
        ]
        files += [Path(directory, name).as_posix() for name in names]
    return files


def gdtoolkit(tool: str, args: list[str]) -> subprocess.Popen:
    # gdtoolkit creates its grammar cache folder racily (gdtoolkit#428): parallel
    # runs on a cold cache crash. Creating it first avoids that.
    from gdtoolkit.parser.parser import get_cache_directory

    cache = Path(get_cache_directory(), "gdtoolkit", pkg_version("gdtoolkit"))
    cache.mkdir(parents=True, exist_ok=True)
    return subprocess.Popen(
        [sys.executable, "-m", f"gdtoolkit.{tool}", *args],
        env={**os.environ, "PYTHONUTF8": "1"},
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
    )


def given_or_all(files: list[str]) -> list[str]:
    """The given files that exist, or every file in the project, outside addons/."""
    paths = [project_path(f) for f in files if Path(f).is_file()] if files else project_files()
    return [path for path in paths if ours(path)]


def run_lint(files: list[str]):
    paths = given_or_all(files)
    if not paths:
        return "no files outside addons/"
    problems, warnings = lint_problems(paths, hook=False)
    for line in problems + warnings:
        print(line)
    if problems:
        raise CheckFailed("fix the problems above")
    return f"{len(warnings)} warnings above" if warnings else None


def lint_hook() -> int:
    # Claude Code sends UTF-8. Read bytes, since sys.stdin decodes as cp1252 on Windows.
    event = json.load(sys.stdin.buffer)
    if event.get("tool_name") == "Bash":
        paths = files_changed_since_last_bash()
    else:
        file_path = event.get("tool_input", {}).get("file_path", "")
        paths = given_or_all([file_path]) if file_path else []
    paths = [path for path in paths if path.endswith(LINTED)]
    if not paths:
        return 0
    problems, _ = lint_problems(paths, hook=True)
    if problems:
        print("\n".join(problems), file=sys.stderr)
        return 2
    return 0


def files_changed_since_last_bash() -> list[str]:
    """Shell commands (sed -i, heredocs) can edit any file, so after each one lint
    every file modified since the previous one. The stamp keeps the start time,
    so a file edited while this runs is linted next time."""
    started = time.time()
    since = LINT_STAMP.stat().st_mtime if LINT_STAMP.exists() else 0.0
    changed = [
        path
        for path in project_files()
        if path.endswith(LINTED) and os.path.getmtime(path) > since
    ]
    LINT_STAMP.parent.mkdir(exist_ok=True)
    LINT_STAMP.touch()
    os.utime(LINT_STAMP, (started, started))
    return changed


def lint_problems(paths: list[str], hook: bool) -> tuple[list[str], list[str]]:
    """Problems and warnings in the given project paths. The hook leaves out warnings,
    since Claude Code shows a hook's output only when it fails."""
    scripts = [path for path in paths if path.endswith(".gd")]
    # gdlint and gdformat each parse every script, so they run side by side.
    linter = gdtoolkit("linter", scripts) if scripts else None
    formatter = gdtoolkit("formatter", ["--check", *scripts]) if scripts else None
    rules = []
    for path in paths:
        if path.endswith(".gd"):
            rules += script_problems(path, hook)
        elif path.endswith(".tscn"):
            rules += scene_problems(path)
        elif path.endswith(".gdshader"):
            rules += shader_problems(path)
        # The hook leaves this out: a scene is missing its ids for as long as it is being
        # written, and check.py ids fills them in once. The commit hook and CI catch it.
        if path.endswith((".tscn", ".tres")) and not hook:
            rules += missing_id_problems(path)
    problems = []
    if linter and formatter:
        lint_output = linter.communicate()[1]
        if linter.returncode != 0:
            problems.append(lint_output.rstrip())
        problems += formatting_problems(formatter, gdlint_failed=linter.returncode != 0)
    warnings = [] if hook else asset_size_warnings(paths)
    return problems + rules, warnings


def problem(path: str, line: int | None, rule: str, message: str, doc: str) -> str:
    where = f"{path}:{line}:" if line else f"{path}:"
    return f"{where} Error: {message} ({rule}; {doc})"


def line_at(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def split_gdscript(source: str) -> tuple[str, list[tuple[int, str]]]:
    """Blanks comments and string literals out of a script, keeping every newline so an
    offset still maps to its line. Returns that code, and each string's line and text."""
    strings = []

    def blank(match: re.Match) -> str:
        if literal := match.group(2):
            quotes = 3 if literal[:3] in ('"""', "'''") else 1
            strings.append((line_at(source, match.start()), literal[quotes:-quotes]))
        return re.sub(r"[^\n]", " ", match.group(0))

    return GD_COMMENT_OR_STRING.sub(blank, source), strings


def script_problems(path: str, hook: bool) -> list[str]:
    source = Path(path).read_text(encoding="utf-8", errors="replace")
    code, strings = split_gdscript(source)
    problems = test_file_problems(path, check_target=not hook)
    # Tests and tools drive scenes from outside, so they may reach anywhere.
    outside = path.split("/")[0] in ("test", "tools")
    if not outside:
        problems += surroundings_problems(path, code, strings)
    if path == EVENTS_SCRIPT:
        problems += bus_event_problems(path, code, source)
    elif path.startswith("core/"):
        problems += core_signal_problems(path, code)
    if path != DEV_COMMANDS:
        problems += limbo_console_problems(path, code)
    if not (outside or path == DEV_COMMANDS or path.startswith(ONLINE_FOLDER)):
        problems += talo_problems(path, code)
    return problems


def surroundings_problems(path: str, code: str, strings: list[tuple[int, str]]) -> list[str]:
    """Scenes stay unaware of their surroundings. Only the node's own get_parent() is
    flagged: body.get_parent() (on a body that entered an Area3D, say) looks into
    another scene, not out of this one."""
    out = (
        "out of the scene. Signal up to the parent instead, or take the node in with an "
        "@export var or a setter the parent calls."
    )
    absolute = (
        "is an absolute node path. Reach an autoload by its name (Events, Audio), "
        "and anything else with an @export var or a setter the parent calls."
    )
    found = [
        (line_at(code, m.start()), "no-get-parent", f"get_parent() reaches {out}")
        for m in OWN_GET_PARENT.finditer(code)
    ]
    found += [
        (line_at(code, m.start()), "no-root-path", f"$/root {absolute}")
        for m in re.finditer(r"\$\s*/root\b", code)
    ]
    for line, text in strings:
        if re.match(r"\.\.(/|$)", text):
            found.append((line, "no-parent-path", f'"{text}" is a node path {out}'))
        elif re.match(r"/root(/|$)", text):
            found.append((line, "no-root-path", f'"{text}" {absolute}'))
    return [
        problem(path, line, rule, message, SCENE_COMPOSITION)
        for line, rule, message in sorted(found)
    ]


def bus_event_problems(path: str, code: str, source: str) -> list[str]:
    """Bus events are documented with ##, and commands are never bus events."""
    lines = source.splitlines()
    problems = []
    for m in re.finditer(r"^signal\s+(\w+)", code, re.MULTILINE):
        name, line = m.group(1), line_at(code, m.start())
        if name.endswith("_requested"):
            message = (
                f"{name} is a command, and commands are never bus events. Call the core "
                "system directly instead, e.g. SceneFlow.go_to(path) or Audio.play_sfx(stream)."
            )
            problems.append(problem(path, line, "no-request-signal", message, SIGNALS))
        above = line - 2
        while above >= 0 and lines[above].lstrip().startswith("@"):
            above -= 1
        if above < 0 or not lines[above].lstrip().startswith("##"):
            message = (
                f"bus event {name} has no ## comment right above it. "
                "Say what happened, and what each parameter is."
            )
            problems.append(problem(path, line, "bus-event-doc", message, SIGNALS))
    return problems


def core_signal_problems(path: str, code: str) -> list[str]:
    """Core systems emit on Events and declare no public signals of their own."""
    problems = []
    for m in re.finditer(r"^signal\s+(\w+)", code, re.MULTILINE):
        message = (
            f"core systems declare no public signals. Make {m.group(1)} a bus event "
            f"in {EVENTS_SCRIPT}, and emit it on Events."
        )
        problems.append(problem(path, line_at(code, m.start()), "no-core-signal", message, SIGNALS))
    return problems


def limbo_console_problems(path: str, code: str) -> list[str]:
    """The release web build leaves LimboConsole out, so a script that names it compiles
    in the editor and in CI, and breaks only the export that runs after a merge."""
    message = (
        f"only {DEV_COMMANDS} may name LimboConsole: the web build leaves it out, so this "
        f"script would fail to compile there. Put console commands in {DEV_COMMANDS}, or "
        'reach the node by path: get_tree().root.get_node_or_null(^"LimboConsole").'
    )
    return [
        problem(path, line_at(code, m.start()), "limbo-console", message, DEV_CONSOLE)
        for m in re.finditer(r"\bLimboConsole\b", code)
    ]


def talo_problems(path: str, code: str) -> list[str]:
    """Online keeps Talo offline without a key and in headless runs, and batches what it
    sends. A direct Talo call skips both, and errors when no player is identified. Talo's
    classes (TaloLeaderboardEntry) are other words, so they stay usable as types."""
    message = (
        f"only {ONLINE_FOLDER} may name the Talo autoload, so every call gets Online's "
        "offline guard and batching. Call Online instead, or add the method you need to "
        f"{ONLINE_FOLDER}online.gd. Bus events become analytics in {ONLINE_FOLDER}tracking.gd."
    )
    return [
        problem(path, line_at(code, m.start()), "talo-through-online", message, ONLINE)
        for m in re.finditer(r"\bTalo\b", code)
    ]


def test_file_problems(path: str, check_target: bool) -> list[str]:
    """Tests sit under test/ (check.py test runs only that folder, and the web build
    leaves only that folder out), named after the file they test. The hook skips the
    target check: a test written before its code would fail until the code exists."""
    if not path.endswith("_test.gd"):
        return []
    if not path.startswith("test/"):
        message = f"tests live under test/, mirroring what they test. Move it to test/{path}."
        return [problem(path, None, "test-outside-test-folder", message, TESTS)]
    target = path[len("test/") : -len("_test.gd")]
    if not check_target or any(Path(target + ext).is_file() for ext in (".gd", ".tscn", ".tres")):
        return []
    message = (
        f"there is no res://{target}.gd or .tscn for it to test. A test mirrors the res:// "
        "path of what it tests: core/audio/audio.gd -> test/core/audio/audio_test.gd."
    )
    return [problem(path, None, "test-mirror", message, TESTS)]


def scene_problems(path: str) -> list[str]:
    """A copied node block keeps its unique_id, and two nodes sharing one confuse the
    editor."""
    first: dict[str, int] = {}
    problems = []
    lines = Path(path).read_text(encoding="utf-8", errors="replace").splitlines()
    for number, line in enumerate(lines, 1):
        m = re.match(r"\[node .*\bunique_id=(\d+)", line)
        if not m:
            continue
        if m.group(1) not in first:
            first[m.group(1)] = number
            continue
        message = (
            f"unique_id={m.group(1)} is also on line {first[m.group(1)]}. Delete it from "
            "the copied node; the editor gives the node a new one on its next save."
        )
        problems.append(problem(path, number, "duplicate-unique-id", message, UNIQUE_IDS))
    return problems


def missing_ids(path: str) -> list[tuple[int, str]]:
    """The lines where Godot's next save would add an id: a header without a uid, a node
    without a unique_id, or an ext_resource without its target's uid. Agents writing a
    file as text leave these out, and check.py ids fills them in."""
    gaps = []
    lines = Path(path).read_text(encoding="utf-8", errors="replace").splitlines()
    for number, line in enumerate(lines, 1):
        if re.match(r"\[gd_(scene|resource)\b", line) and not re.search(r"\buid=", line):
            gaps.append((number, "header"))
        elif line.startswith("[node ") and not re.search(r"\bunique_id=", line):
            gaps.append((number, "node"))
        elif line.startswith("[ext_resource ") and not re.search(r"\buid=", line):
            gaps.append((number, "ext_resource"))
    return gaps


def missing_id_problems(path: str) -> list[str]:
    gaps = missing_ids(path)
    if not gaps:
        return []
    kinds = [kind for _, kind in gaps]
    missing = ["the uid in its header"] if "header" in kinds else []
    missing += [
        f"the {name} on {count} {kind}{'s' if count > 1 else ''}"
        for kind, name in (("node", "unique_id"), ("ext_resource", "uid"))
        if (count := kinds.count(kind))
    ]
    message = (
        f"is missing {', '.join(missing)}. Run: uv run tools/check.py ids {path}, which "
        "saves it the way the editor does, and commit the result."
    )
    return [problem(path, gaps[0][0], "missing-ids", message, UNIQUE_IDS)]


def shader_problems(path: str) -> list[str]:
    """In a shader, # starts a preprocessor directive. A # comment line before
    shader_type makes Godot drop the shader_type without an error (seen on 4.7.2)."""
    message = (
        "a # comment before shader_type makes Godot ignore the shader_type, so the "
        "shader loads as spatial. Start the comment with // instead."
    )
    problems = []
    lines = Path(path).read_text(encoding="utf-8", errors="replace").splitlines()
    for number, line in enumerate(lines, 1):
        text = line.strip()
        if re.match(r"shader_type\b", text):
            break
        if text.startswith("#") and not SHADER_DIRECTIVE.match(text):
            problems.append(problem(path, number, "shader-hash-comment", message, SHADER_COMMENTS))
    return problems


def formatting_problems(formatter: subprocess.Popen, gdlint_failed: bool) -> list[str]:
    output = formatter.communicate()[1]
    unformatted = WOULD_REFORMAT.findall(output)
    fix = "not laid out as gdformat would. Run: uv run tools/check.py format"
    problems = [
        problem(path, None, "gdformat", f"{fix} {path}", FORMATTING) for path in unformatted
    ]
    # A script gdformat can't parse fails gdlint too, and gdlint says where.
    if formatter.returncode != 0 and not unformatted and not gdlint_failed:
        problems.append(output.rstrip())
    return problems


def asset_size_warnings(paths: list[str]) -> list[str]:
    """A warning, not a failure: "about 10 MB" is a judgment call (a long music track
    can be worth it), and a failure would block every later commit and CI run."""
    warnings = []
    for path in paths:
        size = Path(path).stat().st_size / 1e6
        if size > ASSET_LIMIT_MB:
            warnings.append(
                f"{path}: Warning: {size:.1f} MB, over the {ASSET_LIMIT_MB} MB a single asset "
                "should take (no Git LFS). Compress it, or check with the team before "
                f"committing it. (asset-size; {ASSETS})"
            )
    return warnings


def run_format(files: list[str]):
    """Applies gdformat. The hooks only report, so a file never changes under an editor
    or an agent that has it open."""
    scripts = [path for path in given_or_all(files) if path.endswith(".gd")]
    if not scripts:
        return "no .gd files outside addons/"
    formatter = gdtoolkit("formatter", scripts)
    output, errors = formatter.communicate()
    *reformatted, summary = output.strip().splitlines() or [""]
    for line in reformatted:
        print(line)
    if formatter.returncode != 0:
        print(errors, end="")
        raise CheckFailed("gdformat could not parse the files above")
    return summary


# --- Godot ------------------------------------------------------------------

_godot: str | None = None
_binary: tuple[str, str] | None = None


def godot() -> str:
    """Finds Godot 4.7.2 and imports the project once per run. Importing every
    time keeps the global class cache current, so a new class_name resolves."""
    global _godot
    if _godot:
        return _godot
    binary, _ = godot_binary()
    # The import's exit code can't be trusted (it sometimes crashes on exit
    # after finishing), so check for its output instead.
    run([binary, "--headless", "--path", ".", "--import"])
    if not Path(".godot/global_script_class_cache.cfg").exists():
        raise CheckFailed("godot --import did not write .godot/global_script_class_cache.cfg")
    _godot = binary
    return binary


def godot_binary() -> tuple[str, str]:
    """Finds Godot 4.7.2 without importing the project. Returns its path and its
    full version, such as 4.7.2.stable.official.ed1daf0bf."""
    global _binary
    if _binary:
        return _binary
    binary = os.environ.get("GODOT") or shutil.which("godot")
    found = ""
    if binary:
        try:
            found = subprocess.run(
                [binary, "--version"], capture_output=True, text=True, timeout=30
            ).stdout.strip()
        except OSError:
            found = ""
    if not found.startswith(GODOT_VERSION + "."):
        raise CheckFailed(
            f"Godot {GODOT_VERSION} not found (got {found or binary or 'nothing'}). "
            "Set GODOT to its path, e.g. Windows: "
            'setx GODOT "C:\\Godot\\Godot_v4.7.2-stable_win64_console.exe", '
            "Mac: export GODOT=/Applications/Godot.app/Contents/MacOS/Godot"
        )
    # build/ holds exports, reports and captures. A .gdignore keeps Godot from importing it.
    Path("build").mkdir(exist_ok=True)
    Path("build/.gdignore").touch()
    _binary = (binary, found)
    return _binary


def run_godot(args: list[str]) -> subprocess.CompletedProcess:
    """Never pass -d without --remote-debug: a script error would wait for
    debugger input forever."""
    return run([godot(), *args])


def run(
    command: list[str], cwd: Path | None = None, env: dict[str, str] | None = None
) -> subprocess.CompletedProcess:
    """Runs a command with stdout and stderr merged and colour codes stripped."""
    try:
        result = subprocess.run(
            command,
            cwd=cwd,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=TIMEOUT,
        )
    except subprocess.TimeoutExpired as timeout:
        raise CheckFailed(f"Godot timed out after {TIMEOUT} s: {' '.join(command)}") from timeout
    result.stdout = ANSI.sub("", result.stdout)
    return result


def ensure_build_dir(path: str) -> Path:
    directory = Path(path)
    directory.mkdir(parents=True, exist_ok=True)
    return directory


def run_load():
    result = run_godot(["--headless", "--path", ".", "-s", "res://tools/load_check.gd"])
    summary = re.search(r"^checked (\d+), failures: (\d+)$", result.stdout, re.MULTILINE)
    # A parse error in load_check.gd itself makes Godot exit 0 with no summary.
    if not summary:
        print(result.stdout, end="")
        raise CheckFailed("the load check script did not run")
    if result.returncode != 0 or summary.group(2) != "0":
        print(result.stdout, end="")
        raise CheckFailed(f"{summary.group(2)} of {summary.group(1)} files failed to load")
    # A scene with a missing dependency still loads, but logs an error.
    if ERROR_LINE.search(result.stdout):
        print(result.stdout, end="")
        raise CheckFailed("errors logged while loading")
    return f"{summary.group(1)} files"


def run_ids(files: list[str]):
    """Saves the scenes and resources missing a uid or unique_id with Godot's own saver,
    in editor mode: outside it, the saver drops every uid. Dependencies are saved first,
    so a scene's ext_resource picks up the uid its new sub-scene was just given."""
    paths = [path for path in given_or_all(files) if path.endswith((".tscn", ".tres"))]
    gaps = [path for path in paths if missing_ids(path)]
    if not gaps:
        return "no scene or resource is missing an id"
    order = dependency_order(gaps)
    result = run_godot(
        [
            "--headless", "--editor", "--path", ".",
            "-s", "res://tools/resave.gd", "--", *(f"res://{path}" for path in order),
        ]
    )  # fmt: skip
    summary = re.search(r"^saved (\d+), failures: (\d+)$", result.stdout, re.MULTILINE)
    if not summary or result.returncode != 0 or summary.group(2) != "0":
        print(result.stdout, end="")
        raise CheckFailed("Godot could not save the files above")
    left = [path for path in order if missing_ids(path)]
    if left:
        for path in left:
            print("\n".join(missing_id_problems(path)))
        # A reference keeps no uid while its target has none, as when the target is
        # missing ids too but wasn't among the given files.
        raise CheckFailed(
            "saved, but these still miss ids. Run uv run tools/check.py ids with no files, "
            "so the files they reference are saved first"
        )
    return "saved " + ", ".join(order) + "; commit the result"


def dependency_order(paths: list[str]) -> list[str]:
    """The paths with each one after the paths it references by ext_resource."""
    pending = set(paths)
    order: list[str] = []

    def visit(path: str, seen: set[str]) -> None:
        if path not in pending or path in seen:
            return
        seen.add(path)
        text = Path(path).read_text(encoding="utf-8", errors="replace")
        references = re.findall(r'^\[ext_resource .*\bpath="res://([^"]+)"', text, re.MULTILINE)
        for target in references:
            visit(target, seen)
        pending.discard(path)
        order.append(path)

    for path in paths:
        visit(path, set())
    return order


def run_test():
    ensure_build_dir("build/reports")
    result = run_godot(
        [
            "--headless", "--path", ".",
            "-s", "-d", "--remote-debug", "tcp://127.0.0.1:0",
            "res://addons/gdUnit4/bin/GdUnitCmdTool.gd",
            "-a", "res://test", "-c", "-rd", "res://build/reports", "--ignoreHeadlessMode",
        ]
    )  # fmt: skip
    output = DEBUGGER_NOISE.sub("", result.stdout)
    # gdUnit4 exits 0 when it finds nothing, so a wrong path or deleted suites would pass.
    if "No test cases found" in output:
        raise CheckFailed("no test cases found in test/")
    summary = re.search(r"^Overall Summary: (\d+) test cases.*$", output, re.MULTILINE)
    if result.returncode not in (0, 101):
        failures = FAILED_TEST.findall(output)
        # A failing before() or after() has no FAILED test block, so print everything.
        print("".join(failures) + summary.group(0) if failures and summary else output)
        raise CheckFailed(f"gdUnit4 exit code {result.returncode} (report in build/reports/)")
    return f"{summary.group(1)} tests" if summary else None


def main_scene() -> str | None:
    match = re.search(
        r'^run/main_scene="([^"]+)"', Path("project.godot").read_text(), re.MULTILINE
    )
    return match.group(1) if match else None


def logged_error(output: str) -> bool:
    return bool(ERROR_LINE.search(EXIT_LEAK.sub("", output)))


def run_smoke(scenes: list[str]):
    if not scenes:
        main = main_scene()
        if not main:
            return "SKIPPED, no main scene set in project.godot"
        scenes = [main, GAME_SCENE]
    for scene in scenes:
        result = run_godot(
            ["--headless", "--path", ".", "--scene", scene, "--quit-after", SMOKE_FRAMES]
        )
        if logged_error(result.stdout):
            print(result.stdout, end="")
            raise CheckFailed(f"errors logged while running {scene}")
    return ", ".join(scenes)


def run_export(preview: bool):
    """Web is the itch.io build. Web Preview is the preview build: it keeps LimboConsole
    and uses the debug template, so its pack boots with no errors at all."""
    preset, folder = ("Web Preview", "build/web-preview") if preview else ("Web", "build/web")
    directory = ensure_build_dir(folder)
    pck = directory / "index.pck"
    pck.unlink(missing_ok=True)
    mode = "--export-debug" if preview else "--export-release"
    # Only the export sees the file, so the editor never shows a stale commit.
    commit = Path(BUILD_COMMIT_FILE)
    commit.write_text(build_commit() + "\n", encoding="utf-8")
    try:
        result = run_godot(["--headless", "--path", ".", mode, preset, f"{folder}/index.html"])
    finally:
        commit.unlink(missing_ok=True)
    if "No export template found" in result.stdout:
        raise CheckFailed(
            f"the Godot {GODOT_VERSION} Web export templates aren't installed. In the editor: "
            "Editor > Manage Export Templates..., download only the Web templates "
            "(README.md, Setup)"
        )
    if result.returncode != 0 or not pck.exists():
        print(result.stdout, end="")
        raise CheckFailed(f"the {preset} export failed")
    if BUILD_COMMIT_FILE.encode() not in pck.read_bytes():
        raise CheckFailed(
            f"{BUILD_COMMIT_FILE} isn't in the pack, so the menu shows no commit. "
            f"Add it to the {preset} preset's include_filter in export_presets.cfg"
        )
    # From the repo root, --main-pack would load the project instead of the pack.
    boot = run(
        [godot(), "--headless", "--main-pack", "index.pck", "--quit-after", SMOKE_FRAMES],
        cwd=directory,
    )
    log = boot.stdout if preview else WEB_CONSOLE_MISSING.sub("", boot.stdout)
    if boot.returncode != 0 or logged_error(log):
        print(boot.stdout, end="")
        raise CheckFailed("errors logged while booting the exported pack")
    return f"{pck.as_posix()} {pck.stat().st_size / 1e6:.1f} MB, boots clean"


def build_commit() -> str:
    """The short commit the main menu shows. CI sets BUILD_COMMIT where HEAD isn't the
    commit people know: a pull_request checkout is GitHub's merge commit, not the PR head."""
    commit = os.environ.get("BUILD_COMMIT") or git("rev-parse", "HEAD")
    commit = commit[:7]
    if not os.environ.get("BUILD_COMMIT") and git("status", "--porcelain", "--untracked-files=no"):
        commit += "-dirty"
    return commit


def run_capture(scene: str, user_args: tuple[str, ...] = ()):
    """Windowed only: --write-movie crashes under --headless. The scene reads
    user_args through OS.get_cmdline_user_args()."""
    directory = ensure_build_dir("build/capture")
    for old in directory.iterdir():
        old.unlink()
    result = run_godot(
        [
            "--path", ".", "--scene", scene,
            "--write-movie", str((directory / "frame.png").resolve()),
            "--quit-after", CAPTURE_FRAMES,
            "--", *user_args,
        ]
    )  # fmt: skip
    (directory / "frame.wav").unlink(missing_ok=True)
    frames = sorted(directory.glob("frame*.png"))
    if not frames:
        print(result.stdout, end="")
        raise CheckFailed(f"no frames written for {scene}")
    errors = " (errors logged, see above)" if logged_error(result.stdout) else ""
    if errors:
        print(result.stdout, end="")
    return f"{len(frames)} frames, look at {frames[-1].as_posix()}{errors}"


# --- evidence ---------------------------------------------------------------

EVIDENCE_BRANCH = "pr-evidence"
# owner/repo: the last two parts of the URL, which also holds for a proxy's URL.
REMOTE_REPO = re.compile(r"[:/]([^/:]+/[^/]+?)(\.git)?/?$")


def git(*args: str, stdin: str | None = None) -> str:
    result = subprocess.run(
        ["git", *args], input=stdin, capture_output=True, text=True, encoding="utf-8"
    )
    if result.returncode != 0:
        raise CheckFailed(f"git {args[0]} failed: {result.stderr.strip()}")
    return result.stdout.strip()


def run_evidence(frame: str | None):
    """A PR body can't link a gitignored file, and GitHub's API can't attach an image.
    So the frame goes into a commit of its own on the pr-evidence branch, and the URL
    pins that commit, so later pushes never change it. Plumbing only: the working tree,
    the index and the current branch are left alone. Parallel publishes race for the
    branch, so a rejected push rebuilds the commit on the new tip and tries again."""
    frames = sorted(Path("build/capture").glob("frame*.png"))
    path = Path(frame) if frame else (frames[-1] if frames else None)
    if path is None:
        raise CheckFailed("no frames in build/capture/, run capture <scene> first")
    if path.suffix != ".png" or not path.is_file():
        raise CheckFailed(f"no .png file at {path.as_posix()} (paths are from the repo root)")
    repo = REMOTE_REPO.search(git("remote", "get-url", "origin"))
    if not repo:
        raise CheckFailed("can't read owner/repo from the origin remote's URL")
    blob = git("hash-object", "-w", "--", str(path))
    tree = git("mktree", stdin=f"100644 blob {blob}\t{path.name}\n")
    message = f"Evidence for {git('branch', '--show-current') or 'a detached HEAD'}: {path.name}"
    for attempt in range(5):
        try:
            tip = git("ls-remote", "origin", f"refs/heads/{EVIDENCE_BRANCH}").split("\t")[0]
            if tip:
                git("fetch", "--quiet", "origin", tip)
            parent = ["-p", tip] if tip else []
            # Unsigned, so a signing setup that prompts or fails can't block it.
            commit = git("commit-tree", "--no-gpg-sign", *parent, tree, "-m", message)
            git("push", "--quiet", "origin", f"{commit}:refs/heads/{EVIDENCE_BRANCH}")
            break
        except CheckFailed:
            if attempt == 4:
                raise
            time.sleep(2**attempt)
    print(f"![{path.stem}](https://raw.githubusercontent.com/{repo.group(1)}/{commit}/{path.name})")
    return f"{path.as_posix()} pushed to the {EVIDENCE_BRANCH} branch as {commit[:7]}"
# --- api --------------------------------------------------------------------


def run_api(query: str, search: bool, full: bool) -> int:
    """Prints the reference itself, not a PASS line. Failures print FAIL api."""
    import api_lookup

    try:
        print(api_lookup.lookup(api_reference(), query, search, full), end="")
    except (CheckFailed, api_lookup.NotFound) as failure:
        print(f"FAIL api: {failure}")
        return 1
    return 0


def api_reference() -> Path:
    """The engine's class reference as JSON, built once per Godot version. --doctool
    writes it without descriptions, so this runs the editor headless on an empty project,
    which writes its own class reference cache, and tools/api_dump.gd converts that.
    The environment sends the editor's settings and caches to a scratch folder (HOME and
    XDG_* on Linux and Mac, APPDATA and LOCALAPPDATA on Windows), so the human's own
    editor settings are never touched."""
    binary, version = godot_binary()
    reference = ensure_build_dir("build/api") / f"{version}.json"
    if reference.exists():
        return reference
    print(f"Building the Godot {version} class reference in build/api/ (once)...", flush=True)
    scratch = Path(tempfile.mkdtemp(prefix="tmp-", dir="build/api")).resolve()
    try:
        project = scratch / "project"
        project.mkdir()
        (project / "project.godot").write_text("config_version=5\n")
        folders = {
            "HOME": "home", "XDG_CONFIG_HOME": "config", "XDG_DATA_HOME": "data",
            "XDG_CACHE_HOME": "cache", "APPDATA": "appdata", "LOCALAPPDATA": "localappdata",
        }  # fmt: skip
        env = {**os.environ, **{name: str(scratch / folder) for name, folder in folders.items()}}
        editor = run(
            [binary, "--headless", "--editor", "--path", project.as_posix(), "--quit"], env=env
        )
        cache = next(scratch.rglob("editor_doc_cache-*.res"), None)
        if not cache:
            print(editor.stdout, end="")
            raise CheckFailed("the editor wrote no class reference cache")
        dump = scratch / "reference.json"
        script = ROOT / "tools" / "api_dump.gd"
        result = run(
            [
                binary, "--headless", "--path", project.as_posix(),
                "-s", script.as_posix(), "--", cache.as_posix(), dump.as_posix(),
            ],
            env=env,
        )  # fmt: skip
        if result.returncode != 0 or not dump.exists():
            print(result.stdout, end="")
            raise CheckFailed("tools/api_dump.gd could not convert the class reference")
        os.replace(dump, reference)
    finally:
        shutil.rmtree(scratch, ignore_errors=True)
    return reference


if __name__ == "__main__":
    sys.exit(main())
