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
  test [files]     run the gdUnit4 tests in test/, or the given suites or folders
  test --verbose   also print the run's whole output, the tests' print() lines included
  smoke [scenes]   run every scene the game reaches from the main scene and the autoloads,
                   each on its own (or the given ones) headless, several at once, fail on
                   any logged error
  capture <scene> [--size WxH] [--frames N] [-- args]
                   render a scene in a window (default 1152x648, 60 frames: ~1 s), save
                   the frames to build/capture/; args after -- reach the scene through
                   OS.get_cmdline_user_args()
  all              lint, load, then test and smoke at the same time
  export           export Web to build/web/ and boot the .pck headless (needs the Web templates)
  export --preview export Web Preview (dev console, debug template) to build/web-preview/game/,
                   framed by tools/preview_frame.html
  evidence [frame] push a capture frame (default: the last one) to the pr-evidence branch
                   and print the markdown image line that shows it in a PR body
  api <query>      look up the Godot 4.7.2 class reference: `api Tween` (a class),
                   `api Tween.kill` (one member), `api volume` (a search)
  api --search <text>  search class and member names even when <text> is a class
  api <Class> --full   also print the class description
"""

import argparse
import difflib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from contextlib import contextmanager
from functools import cache
from importlib.metadata import version as pkg_version
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GODOT_VERSION = "4.7.2"
TIMEOUT = 300
# 5 s of game time per scene (FIXED_FPS).
SMOKE_FRAMES = "300"
# Test and smoke run without a window, where Godot sleeps about 7 ms each frame and steps
# by the wall-clock time since the last one, so a test waiting out a 2 s fade waited 2 s.
# A fixed frame rate steps every frame by 1/60 s and runs the frames as fast as they come,
# so timers and tweens finish in frames, not seconds, and the same each run: the full
# test run went from about 2 min to 12 s. A test that needs a long frame raises
# Engine.time_scale for it (test/core/scene_flow/scene_flow_test.gd).
FIXED_FPS = ["--fixed-fps", "60"]
# Smoke boots one Godot per scene, and the boot is most of each run, so several at once.
SMOKE_WORKERS = max(1, min(8, (os.cpu_count() or 2) // 2))
CAPTURE_FRAMES = 60
CAPTURE_SIZE = re.compile(r"^[1-9]\d*x[1-9]\d*$")
# Not part of the game, and not exported: smoke never runs a scene in these.
NOT_GAME = ("tools/", "test/")
# Written by run_export and read by the main menu; ignored by git.
BUILD_COMMIT_FILE = "ui/main_menu/build_commit.txt"
# Files check.py writes, which a script may name although the repo doesn't have them.
GENERATED_FILES = (BUILD_COMMIT_FILE,)
# The preview build's front page: itch's embed, with the game in an iframe under game/.
PREVIEW_FRAME = "tools/preview_frame.html"
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


class TimedOut(CheckFailed):
    """A command that ran past TIMEOUT. It keeps the output printed until then, so the
    failure shows where the run stopped."""

    def __init__(self, command: list[str], output: str | bytes | None):
        if isinstance(output, bytes):
            output = output.decode("utf-8", errors="replace")
        self.output = ANSI.sub("", output or "")
        super().__init__(f"Godot timed out after {TIMEOUT} s: {' '.join(command)}")


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
    test = commands.add_parser("test")
    test.add_argument("files", nargs="*")
    test.add_argument("--verbose", action="store_true")
    commands.add_parser("smoke").add_argument("scenes", nargs="*")
    capture = commands.add_parser("capture")
    capture.add_argument("scene")
    capture.add_argument("--size")
    capture.add_argument("--frames", type=int, default=CAPTURE_FRAMES)
    capture.add_argument("user_args", nargs="*")
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
        "test": lambda: run_test(getattr(args, "files", []), getattr(args, "verbose", False)),
        "smoke": lambda: run_smoke(getattr(args, "scenes", [])),
        "capture": lambda: run_capture(args.scene, args.user_args, args.size, args.frames),
        "export": lambda: run_export(args.preview),
        "evidence": lambda: run_evidence(args.frame),
    }
    if args.command != "all":
        return 0 if run_step(args.command, steps[args.command]) else 1
    failed = [name for name in ("lint", "load") if not run_step(name, steps[name])]
    failed += run_steps_at_once({name: steps[name] for name in ("test", "smoke")})
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


class ThreadOutput:
    """Stands in for sys.stdout while steps run on threads: each thread's prints go to its
    own buffer, so two steps' failure output can't interleave."""

    def __init__(self, real):
        self.real = real
        self.local = threading.local()

    def write(self, text: str) -> int:
        buffer = getattr(self.local, "buffer", None)
        if buffer is None:
            return self.real.write(text)
        buffer.append(text)
        return len(text)

    def flush(self) -> None:
        self.real.flush()


def run_steps_at_once(steps: dict) -> list[str]:
    """Runs independent steps (each its own Godot process) at the same time, then prints
    each one's output whole, in the order given. Returns the names of the failed ones."""
    output = ThreadOutput(sys.stdout)

    def captured(name: str) -> tuple[bool, str]:
        output.local.buffer = []
        passed = run_step(name, steps[name])
        return passed, "".join(output.local.buffer)

    godot()  # Find the binary once, before the threads do.
    sys.stdout = output
    try:
        with ThreadPoolExecutor(len(steps)) as pool:
            results = list(pool.map(captured, steps))
    finally:
        sys.stdout = output.real
    for text in (text for _, text in results):
        print(text, end="")
    return [name for name, (passed, _) in zip(steps, results) if not passed]


# --- lint -------------------------------------------------------------------

# Written rules that a regex can check without Godot. Each message names its rule and
# the doc section behind it, so it can be fixed without reading the doc.
SCENE_COMPOSITION = "CODING_STANDARDS.md, Scene composition"
SIGNALS = "CODING_STANDARDS.md, Signals: local or bus"
DEV_CONSOLE = "CODING_STANDARDS.md, Dev console"
ONLINE = "CODING_STANDARDS.md, Online"
AUTOLOADS = "CODING_STANDARDS.md, Autoloads (core systems)"
TESTS = "CODING_STANDARDS.md, Tests"
USER_FILES = "CODING_STANDARDS.md, Saved files"
ASSETS = "CODING_STANDARDS.md, Assets"
FORMATTING = "CODING_STANDARDS.md, Naming"
STATIC_TYPING = "CODING_STANDARDS.md, Static typing"
SCRIPT_SIZE = "CODING_STANDARDS.md, Script size"
GLOSSARY = "CONTEXT.md"
SHADER_COMMENTS = "docs/web-constraints.md, Shader comments are //"
UNIQUE_IDS = ".claude/skills/edit-tscn/SKILL.md, uid and unique_id"
NODE_EXPORTS = ".claude/skills/edit-tscn/SKILL.md, References"
EVENTS_SCRIPT = "core/events/events.gd"
DEV_COMMANDS = "core/dev_console/dev_commands.gd"
ONLINE_FOLDER = "core/online/"
AUDIO_FOLDER = "core/audio/"
BUS_LAYOUT = "core/audio/default_bus_layout.tres"
LINTED = (".gd", ".tscn", ".gdshader")
# Vendored, generated or ignored by git: nothing in these folders is ours to lint.
# Hidden folders (.godot, .claude) are skipped too, as Godot skips them.
NOT_OURS_AT_ROOT = {"addons", "android", "art"}
NOT_OURS_ANYWHERE = {"build", "reports", "__pycache__"}
ASSET_LIMIT_MB = 10
# gdlint fails a script past max-file-lines in gdlintrc. The warning starts here, while
# there is still room to split by job instead of shaving lines to fit.
SCRIPT_LINES_LIMIT = 600
SCRIPT_LINES_WARNING = 500
# A comment, or a string literal (group 2). One pattern, so a # inside a string isn't
# a comment and a quote inside a comment doesn't start a string.
GD_COMMENT_OR_STRING = re.compile(
    r"""(#[^\n]*)|("{3}[\s\S]*?"{3}|'{3}[\s\S]*?'{3}|"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*')"""
)
# Godot's untyped_declaration warning skips loop variables, so `for i in 3:` loads.
UNTYPED_LOOP_VARIABLE = re.compile(r"^[ \t]*for[ \t]+(\w+)[ \t]+in\b", re.MULTILINE)
CLASS_NAME = re.compile(r"^class_name[ \t]+(\w+)", re.MULTILINE)
ENUM = re.compile(r"\benum[ \t]+(\w+)[ \t]*\{([^}]*)\}")
# An @export var line, up to its end: the names in it are its type and its default.
EXPORT_LINE = re.compile(r"^[ \t]*@export\w*\b[^\n]*", re.MULTILINE)
DOTTED_NAME = re.compile(r"(?<![\w.])([A-Z]\w*)(?:\.([A-Z]\w*))?")
# A member set or read by a name written as a literal, which a typo or a rename turns into
# a no-op: Object.set() ignores a name the object doesn't have, and get() returns null.
DYNAMIC_MEMBER = re.compile(r"\.\s*(set|set_deferred|get)\s*\(")
OWN_GET_PARENT = re.compile(r"(?<![\w.])get_parent\s*\(|\bself\s*\.\s*get_parent\s*\(")
SHADER_DIRECTIVE = re.compile(
    r"#\s*(define|undef|include|if|ifdef|ifndef|elif|else|endif|error|pragma)\b"
)
# A bus looked up or set by name. Audio.BUS_NAMES[...] on the right is the supported way.
AUDIO_SERVER_BUS = re.compile(r"\bAudioServer\s*\.\s*\w*bus\w*")
BUS_ASSIGNMENT = re.compile(r"\.\s*bus\s*=(?!=)(?!\s*Audio\s*\.\s*BUS_NAMES\b)")
# A `.bus =` value that is one bare variable, read to find the variable's declared type.
BARE_VALUE = re.compile(r"[ \t]*([A-Za-z_]\w*)[ \t]*(#.*)?$", re.MULTILINE)
# An ext_resource's uid and path, in either order. Godot looks the uid up first and uses
# the path only when no file has that uid.
EXT_RESOURCE_UID = re.compile(
    r'^\[ext_resource (?=[^\n]*?\buid="([^"]+)")(?=[^\n]*?\bpath="res://([^"]+)")'
)
SCENE_HEADER_UID = re.compile(r'\[gd_(?:scene|resource)\b[^\n]*?\buid="([^"]+)"')
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


# gdlint, with max-public-methods off under test/. A suite has a public method per test,
# so the cap that keeps game classes small would split a suite away from the one file it
# mirrors (test-mirror). gdlint reads one gdlintrc for every file, hence the wrapper.
GDLINT = """
import sys
import gdtoolkit.linter.__main__ as gdlint

lint_file = gdlint._lint_file


def lint_file_with_test_rules(path, config):
    if path.replace("\\\\", "/").startswith("test/"):
        config = {**config, "disable": [*config["disable"], "max-public-methods"]}
    return lint_file(path, config)


gdlint._lint_file = lint_file_with_test_rules
sys.argv[0] = "gdlint"
gdlint.main()
"""


def gdtoolkit(tool: str, args: list[str]) -> subprocess.Popen:
    # gdtoolkit creates its grammar cache folder racily (gdtoolkit#428): parallel
    # runs on a cold cache crash. Creating it first avoids that.
    from gdtoolkit.parser.parser import get_cache_directory

    cache = Path(get_cache_directory(), "gdtoolkit", pkg_version("gdtoolkit"))
    cache.mkdir(parents=True, exist_ok=True)
    entry = ["-c", GDLINT] if tool == "linter" else ["-m", f"gdtoolkit.{tool}"]
    return subprocess.Popen(
        [sys.executable, *entry, *args],
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
        if path.endswith((".gd", ".tscn", ".tres")):
            rules += glossary_problems(path)
        if path.endswith((".tscn", ".tres")):
            rules += wrong_uid_problems(path)
        # The hook leaves this out: a scene is missing its ids for as long as it is being
        # written, and check.py ids fills them in once. The commit hook and CI catch it.
        if path.endswith((".tscn", ".tres")) and not hook:
            rules += missing_id_problems(path)
        if path.endswith(".uid") and not Path(path[: -len(".uid")]).is_file():
            message = (
                f"there is no {path[: -len('.uid')]} beside it: Godot left it for a file "
                "that was deleted or moved. Delete it, or git rm it."
            )
            rules.append(problem(path, None, "orphan-uid", message, ASSETS))
    problems = []
    if linter and formatter:
        lint_output = linter.communicate()[1]
        if linter.returncode != 0:
            problems.append(lint_output.rstrip())
        problems += formatting_problems(formatter, gdlint_failed=linter.returncode != 0)
    warnings = [] if hook else asset_size_warnings(paths) + script_size_warnings(scripts)
    return problems + rules, warnings


def script_size_warnings(scripts: list[str]) -> list[str]:
    """A warning before gdlint's limit fails the script: at the limit the cheap way out is
    to shave lines, which leaves the script doing as many jobs as before."""
    warnings = []
    for path in scripts:
        # A suite mirrors its script, so it splits when the script does.
        if path.startswith("test/"):
            continue
        lines = len(Path(path).read_text(encoding="utf-8", errors="replace").splitlines())
        if lines >= SCRIPT_LINES_WARNING:
            warnings.append(
                f"{path}: Warning: {lines} lines, and lint fails past {SCRIPT_LINES_LIMIT}. "
                "If your change adds to it, move one job out to a component node, a static "
                "helper or a Resource in the same change. Don't trim comments or pack lines "
                f"to fit. (script-size; {SCRIPT_SIZE})"
            )
    return warnings


def never_terms() -> list[tuple[re.Pattern, str, str]]:
    """Each term CONTEXT.md lists after _Never_, as a pattern over normalised text, with
    the term and the glossary entry to use instead."""
    global _never_terms
    if _never_terms is None:
        _never_terms = []
        entry = ""
        for line in Path("CONTEXT.md").read_text(encoding="utf-8").splitlines():
            if heading := re.match(r"\*\*(.+?)\*\*:", line):
                entry = heading.group(1)
            elif line.startswith("_Never_:"):
                for term in line.split(":", 1)[1].split(","):
                    words = re.sub(r"\(.*?\)", "", term).lower().split()
                    if words:
                        pattern = r"\b" + r"\s+".join(map(re.escape, words)) + r"(?:s|es)?\b"
                        _never_terms.append((re.compile(pattern), " ".join(words), entry))
    return _never_terms


_never_terms: list[tuple[re.Pattern, str, str]] | None = None


def glossary_problems(path: str) -> list[str]:
    """A term the glossary rules out, in an identifier, a node name or text the player
    reads. Comments are left alone: they may say what a thing used to be called."""
    text = Path(path).read_text(encoding="utf-8", errors="replace")
    if path.endswith(".gd"):
        code, strings = split_gdscript(text)
        lines = list(enumerate(code.splitlines(), 1)) + strings
    else:
        lines = list(enumerate(text.splitlines(), 1))
    problems = []
    for number, line in sorted(lines):
        # waypoint_radius, WaypointRadius and "way point" read alike once split into words.
        words = re.sub(r"(?<=[a-z0-9])(?=[A-Z])|_", " ", line).lower()
        for pattern, term, entry in never_terms():
            if pattern.search(words):
                message = f'"{term}" is not this project\'s word. The glossary\'s is {entry}.'
                problems.append(problem(path, number, "glossary-term", message, GLOSSARY))
    return problems


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
    problems += untyped_loop_problems(path, code)
    problems += dynamic_member_problems(path, code, source)
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
    if not (outside or path.startswith(AUDIO_FOLDER)):
        problems += bus_name_problems(path, code, source)
    problems += user_path_problems(path, strings, outside)
    if not outside:
        problems += saved_enum_problems(path, code)
    # The hook leaves this out: a script may name a scene before it is written.
    if not (outside or hook):
        problems += missing_path_problems(path, strings)
    return problems


def untyped_loop_problems(path: str, code: str) -> list[str]:
    """Every declaration is typed, and the untyped_declaration error in project.godot
    covers all of them except loop variables, which load untyped without a word."""
    problems = []
    for m in UNTYPED_LOOP_VARIABLE.finditer(code):
        message = (
            f"loop variable {m.group(1)} has no type, and Godot doesn't flag it. "
            f"Write it typed: for {m.group(1)}: int in ..., or the element type of the array."
        )
        problems.append(
            problem(path, line_at(code, m.start()), "typed-loop-variable", message, STATIC_TYPING)
        )
    return problems


def dynamic_member_problems(path: str, code: str, source: str) -> list[str]:
    """node.set(&"name", value) and node.get(&"name") skip the type check, so a misspelled or
    renamed name sets nothing and reads null, with no error in load, smoke or tests. Only a
    literal name is flagged: set(name, value) with a variable is how to bind by name, and
    get("key") is how a Dictionary is read, so get is flagged only with a StringName."""
    problems = []
    for m in DYNAMIC_MEMBER.finditer(code):
        literal = re.match(r"\s*(&?)[\"']", source[m.end() :])
        if not literal or (m.group(1) == "get" and not literal.group(1)):
            continue
        message = (
            f"{m.group(1)}() with a literal name does nothing, with no error, once that name "
            "is misspelled or renamed. Give the script a class_name if it has none, cast to "
            "it and use the member: (%Panel as PassengerPanel).cabin = cabin."
        )
        problems.append(
            problem(path, line_at(code, m.start()), "typed-member", message, STATIC_TYPING)
        )
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


def user_path_problems(path: str, strings: list[tuple[int, str]], outside: bool) -> list[str]:
    """A user:// path names a file no load check sees, so a copy left behind when the
    owner's path changes reads or deletes nothing, without an error: a test then checks a
    file nothing writes and passes. So one script writes each path, as a const. A copy in
    a test or tool is flagged against the owner; two game scripts are flagged both ways."""
    problems = []
    for line, text in strings:
        if not text.startswith("user://") or text == "user://":
            continue
        others = [
            other
            for other in user_path_writers().get(text, [])
            if other != path and (outside or other.split("/")[0] not in ("test", "tools"))
        ]
        if not others:
            continue
        owner = others[0]
        const = user_path_const(owner, text) or "PATH"
        message = (
            f'"{text}" is also written in {", ".join(others)}. One script owns each user:// '
            f"file and writes its path once, as a const: name {owner}'s {const} instead "
            f'(a test preloads it: preload("res://{owner}").{const}), so a moved file '
            "can't leave a copy pointing where nothing writes."
        )
        problems.append(problem(path, line, "user-path-owner", message, USER_FILES))
    return problems


def missing_path_problems(path: str, strings: list[tuple[int, str]]) -> list[str]:
    """A res:// or uid:// string that names no file fails only when its line runs: a
    SceneFlow.go_to target logs an error on the click that reaches it. Load and smoke both
    pass, and smoke drops the missing scene and every scene only it leads to. A string with
    % or { is a template, filled in at run time, so it's left alone."""
    uids = set(project_uids().values())
    problems = []
    for line, text in strings:
        if "%" in text or "{" in text or text in ("res://", "uid://"):
            continue
        if text.startswith("uid://"):
            found = text in uids
        elif text.startswith("res://"):
            target = text.removeprefix("res://").split("::")[0]
            found = Path(target or ".").exists() or target in GENERATED_FILES
        else:
            continue
        if found:
            continue
        message = (
            f"no file is at {text}. A load() or SceneFlow.go_to() of it fails only when "
            "this line runs, and smoke skips that scene and every scene only it leads to. "
            "Fix the path, or write the file first."
        )
        problems.append(problem(path, line, "path-exists", message, SCENE_COMPOSITION))
    return problems


def saved_enum_problems(path: str, code: str) -> list[str]:
    """A .tres or .tscn saves an exported enum as its member's number, and Godot counts
    unnumbered members from 0 in order. A member added or moved above another renumbers
    it, and every saved value then loads as its neighbour, with no error: an upgrade gives
    the wrong trait. So an exported enum numbers every member. Flagged on the enum, and on
    an export in another script, so the hook sees it either way."""
    problems = []
    for name, line, unnumbered in script_enums(path):
        exporter = exported_enums().get((path, name))
        if not exporter or not unnumbered:
            continue
        problems.append(saved_enum_problem(path, line, path, name, unnumbered, exporter))
    for m in EXPORT_LINE.finditer(code):
        for enum_path, name in export_enum_refs(path, m.group(0)):
            if enum_path == path:
                continue
            for enum_name, enum_line, unnumbered in script_enums(enum_path):
                if enum_name == name and unnumbered:
                    line = line_at(code, m.start())
                    where = f"{path}:{line}"
                    problems.append(
                        saved_enum_problem(path, line, enum_path, name, unnumbered, where)
                    )
    return problems


def saved_enum_problem(
    path: str, line: int, enum_path: str, name: str, unnumbered: list[str], exporter: str
) -> str:
    owner = script_classes().get(enum_path)
    full = f"{owner}.{name}" if owner else name
    message = (
        f"enum {full} ({enum_path}) is exported ({exporter}), so scenes and resources save "
        f"it as a number, and {', '.join(unnumbered)} get theirs from their place: adding "
        "or moving a member renumbers the ones after it, and every saved value silently "
        "means another member. Write each member's number: an existing one keeps its "
        "place's (from 0), and a new one takes the next unused number."
    )
    return problem(path, line, "saved-enum", message, STATIC_TYPING)


@cache
def script_enums(path: str) -> list[tuple[str, int, list[str]]]:
    """Each enum a script declares: its name, line, and the members without a number."""
    source = Path(path).read_text(encoding="utf-8", errors="replace")
    code = split_gdscript(source)[0]
    enums = []
    for m in ENUM.finditer(code):
        members = [member.strip() for member in m.group(2).split(",")]
        unnumbered = [member for member in members if member and "=" not in member]
        enums.append((m.group(1), line_at(code, m.start()), unnumbered))
    return enums


@cache
def game_scripts() -> list[str]:
    """Every project script outside test/ and tools/."""
    paths = [file.removeprefix("./") for file in project_files() if file.endswith(".gd")]
    return [path for path in paths if path.split("/")[0] not in ("test", "tools")]


@cache
def script_classes() -> dict[str, str]:
    """Each game script with a class_name, and that name. Tests and tools are left out."""
    classes = {}
    for path in game_scripts():
        source = Path(path).read_text(encoding="utf-8", errors="replace")
        if m := CLASS_NAME.search(source):
            classes[path] = m.group(1)
    return classes


def export_enum_refs(path: str, export: str) -> list[tuple[str, str]]:
    """The enums an @export line names, by the script that declares each: its own, as
    Kind, or another class's, as BusTraits.Type, in a type or a default. Each once, though
    a line names it as both."""
    by_class = {name: script for script, name in script_classes().items()}
    own = {name for name, _, _ in script_enums(path)}
    refs = []
    for m in DOTTED_NAME.finditer(export):
        first, second = m.group(1), m.group(2)
        if first in own:
            refs.append((path, first))
        elif second and first in by_class:
            script = by_class[first]
            if any(name == second for name, _, _ in script_enums(script)):
                refs.append((script, second))
    return list(dict.fromkeys(refs))


@cache
def exported_enums() -> dict[tuple[str, str], str]:
    """Each enum some game script exports, by its script and name, with the first export
    that names it, as path:line."""
    exported: dict[tuple[str, str], str] = {}
    for path in game_scripts():
        source = Path(path).read_text(encoding="utf-8", errors="replace")
        code = split_gdscript(source)[0]
        for m in EXPORT_LINE.finditer(code):
            for ref in export_enum_refs(path, m.group(0)):
                exported.setdefault(ref, f"{path}:{line_at(code, m.start())}")
    return exported


@cache
def user_path_writers() -> dict[str, list[str]]:
    """Each user:// path written as a string in a project script, with the scripts that
    write it, game scripts before tests and tools so the first one is the owner."""
    writers: dict[str, list[str]] = {}
    for file in project_files():
        if not file.endswith(".gd"):
            continue
        path = file.removeprefix("./")
        source = Path(path).read_text(encoding="utf-8", errors="replace")
        for _, text in split_gdscript(source)[1]:
            if text.startswith("user://") and path not in writers.setdefault(text, []):
                writers[text].append(path)
    for paths in writers.values():
        paths.sort(key=lambda p: (p.split("/")[0] in ("test", "tools"), p))
    return writers


def user_path_const(path: str, text: str) -> str | None:
    source = Path(path).read_text(encoding="utf-8", errors="replace")
    m = re.search(rf'^const\s+(\w+)\s*:?[^=\n]*=\s*"{re.escape(text)}"', source, re.M)
    return m.group(1) if m else None


def bus_name_problems(path: str, code: str, source: str) -> list[str]:
    """A bus name that isn't in the layout sends a player to Master, and makes a volume
    change do nothing, both silently. So only Audio names buses."""
    message = (
        f"only {AUDIO_FOLDER} names audio buses: a wrong name fails silently. Use "
        "Audio.set_volume(Audio.Bus.MUSIC, linear) or Audio.get_volume(bus), and set a "
        "player's bus to Audio.BUS_NAMES[Audio.Bus.SFX]."
    )
    assignments = [m for m in BUS_ASSIGNMENT.finditer(code) if not object_value(code, m.end())]
    matches = [*AUDIO_SERVER_BUS.finditer(code), *assignments]
    lines = sorted({line_at(code, m.start()) for m in matches})
    return [problem(path, line, "bus-through-audio", message, AUTOLOADS) for line in lines]


def object_value(code: str, offset: int) -> bool:
    """Whether the value at offset is a variable the script declares as an object, like a
    panel's `bus: FrameshiftBus`: that `.bus` isn't an audio bus. Any other value may be a
    bus name, from a constant, a call or an untyped variable, so the rule checks it."""
    value = BARE_VALUE.match(code, offset)
    if not value:
        return False
    declared = re.findall(rf"\b{value.group(1)}\s*:\s*([A-Za-z_]\w*)", code)
    return any(kind[0].isupper() and kind not in ("String", "StringName") for kind in declared)


def bus_names() -> list[str]:
    """The buses in the bus layout. Master is bus 0, which the layout file leaves out."""
    layout = Path(BUS_LAYOUT).read_text(encoding="utf-8", errors="replace")
    return ["Master", *re.findall(r'^bus/\d+/name = &"([^"]*)"', layout, re.MULTILINE)]


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
    return problems + scene_bus_problems(path, lines) + node_export_problems(path, lines)


def scene_bus_problems(path: str, lines: list[str]) -> list[str]:
    """A player's bus set in the scene file is a name too, and a wrong one plays on Master."""
    buses = bus_names()
    problems = []
    for number, line in enumerate(lines, 1):
        m = re.match(r'bus = &"([^"]*)"', line)
        if m and m.group(1) not in buses:
            message = (
                f'there is no bus "{m.group(1)}" in {BUS_LAYOUT}, so this player plays on '
                f"Master. The buses are {', '.join(buses)} (Audio.Bus)."
            )
            problems.append(problem(path, number, "unknown-bus", message, AUTOLOADS))
    return problems


def node_export_problems(path: str, lines: list[str]) -> list[str]:
    """A script's exported Node (say `@export var target: Planet`) is set from a NodePath
    in the scene only when the node's header lists it in node_paths. Without that, Godot
    leaves the export null with no error, and load, smoke and tests all pass."""
    resources = ext_resource_paths(lines)
    problems = []
    blocks = [n for n, line in enumerate(lines) if line.startswith("[")] + [len(lines)]
    for start, end in zip(blocks, blocks[1:]):
        header = lines[start]
        if not header.startswith("[node "):
            continue
        listed = re.search(r"\bnode_paths=PackedStringArray\(([^)]*)\)", header)
        node_paths = re.findall(r'"([^"]+)"', listed.group(1)) if listed else []
        script = node_script(header, lines[start + 1 : end], resources)
        exports = exported_types(script) if script else {}
        for offset, line in enumerate(lines[start + 1 : end], start + 2):
            m = re.match(r'(\w+) = NodePath\("([^"]*)"\)', line)
            if not m or m.group(1) in node_paths:
                continue
            kind = exports.get(m.group(1))
            if not kind or kind == "NodePath":
                continue
            name = m.group(1)
            message = (
                f"{name} is an exported {kind} in res://{script}, so Godot sets it from "
                f'this path only when the [node] line has node_paths=PackedStringArray("{name}"). '
                f"Without that the export is null at runtime, with no error. Add it to the "
                f"[node] line on line {start + 1}."
            )
            problems.append(problem(path, offset, "node-export-path", message, NODE_EXPORTS))
    return problems


def ext_resource_paths(lines: list[str]) -> dict[str, str]:
    """Each ext_resource's id, mapped to its path from the project root."""
    paths = {}
    for line in lines:
        if line.startswith("[ext_resource "):
            path = re.search(r'\bpath="res://([^"]+)"', line)
            ident = re.search(r'\bid="([^"]+)"', line)
            if path and ident:
                paths[ident.group(1)] = path.group(1)
    return paths


def node_script(header: str, body: list[str], resources: dict[str, str]) -> str | None:
    """The script on a node: its own, else the root script of the scene it instances."""
    for line in body:
        m = re.match(r'script = ExtResource\("([^"]+)"\)', line)
        if m:
            return resources.get(m.group(1))
    m = re.search(r'\binstance=ExtResource\("([^"]+)"\)', header)
    scene = resources.get(m.group(1)) if m else None
    if not scene or not Path(scene).is_file():
        return None
    lines = Path(scene).read_text(encoding="utf-8", errors="replace").splitlines()
    starts = [n for n, line in enumerate(lines) if line.startswith("[node ")]
    if not starts:
        return None
    root = starts[0]
    ends = [n for n, line in enumerate(lines) if n > root and line.startswith("[")]
    body = lines[root + 1 : ends[0] if ends else len(lines)]
    return node_script(lines[root], body, ext_resource_paths(lines))


@cache
def exported_types(script: str) -> dict[str, str]:
    """The declared type of each @export var in a script, by name. Untyped exports and
    scripts that aren't there are left out."""
    if not script.endswith(".gd") or not Path(script).is_file():
        return {}
    code, _ = split_gdscript(Path(script).read_text(encoding="utf-8", errors="replace"))
    found = re.findall(r"@export\w*(?:\([^)]*\))?\s+var\s+(\w+)\s*:\s*(\w+)", code)
    return dict(found)


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


def wrong_uid_problems(path: str) -> list[str]:
    """The uid wins over the path, so another file's uid loads that file instead, and an
    unknown one falls back to the path with only a warning. Load, smoke and tests all
    pass either way. Writing the path alone and running check.py ids gets it right."""
    uids = project_uids()
    owners = {uid: target for target, uid in uids.items()}
    fix = f"Delete uid=\"...\" from the line and run: uv run tools/check.py ids {path}"
    problems = []
    lines = Path(path).read_text(encoding="utf-8", errors="replace").splitlines()
    for number, line in enumerate(lines, 1):
        m = EXT_RESOURCE_UID.match(line)
        if not m or not Path(m.group(2)).is_file():
            continue  # A missing target fails the load check, naming it.
        uid, target = m.groups()
        if uids.get(target) == uid:
            continue
        if uid in owners:
            message = (
                f"{uid} is res://{owners[uid]}'s uid, so Godot loads that file instead of "
                f"res://{target}, without an error. {fix}"
            )
        else:
            message = (
                f"no file has {uid}, so Godot falls back to res://{target} with a warning, "
                f"and the editor rewrites the line on its next save. {fix}"
            )
        problems.append(problem(path, number, "uid-matches-path", message, UNIQUE_IDS))
    return problems


@cache
def project_uids() -> dict[str, str]:
    """Each file's uid, by its path from the project root, from where Godot keeps it: a
    script's .uid sidecar, an imported asset's .import file, or a scene's or resource's
    header. addons/ included, since a scene may reference a plugin's files."""
    uids = {}
    for directory, subdirectories, names in os.walk("."):
        subdirectories[:] = [
            d for d in subdirectories if not d.startswith(".") and d not in NOT_OURS_ANYWHERE
        ]
        for name in names:
            path = Path(directory, name).as_posix().removeprefix("./")
            if name.endswith(".uid"):
                uids[path.removesuffix(".uid")] = Path(path).read_text().strip()
            elif name.endswith(".import"):
                m = re.search(r'^uid="([^"]+)"', Path(path).read_text(errors="replace"), re.M)
                if m:
                    uids[path.removesuffix(".import")] = m.group(1)
            elif name.endswith((".tscn", ".tres")):
                with open(path, encoding="utf-8", errors="replace") as file:
                    m = SCENE_HEADER_UID.match(file.readline())
                if m:
                    uids[path] = m.group(1)
    return uids


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
        raise TimedOut(command, timeout.stdout) from timeout
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
        raise CheckFailed(f"{summary.group(2)} of {summary.group(1)} files failed the load check")
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
    originals = {path: Path(path).read_bytes() for path in order}
    before = resource_dump(order)
    try:
        verify_resave(order, before, originals)
    except CheckFailed:
        # A save that wasn't verified never stays, whatever stopped the check: a failed
        # save, a changed value, a timeout, or a dump that can't read the saved files.
        restore(originals)
        print("The files are as they were before check.py ids.")
        raise
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


def verify_resave(order: list[str], before: list[str], originals: dict[str, bytes]) -> None:
    """Resaves the files through tools/resave.gd and fails if Godot couldn't, or if the
    saved files load with anything but ids changed from the dump taken before."""
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
    changes = dump_changes(before, resource_dump(order))
    if changes:
        print("\n".join(changes))
        raise CheckFailed(
            "the resave changed more than ids (above: - before, + after). "
            "tools/resave.gd explains the case it already handles"
        )
    added = {path: lines for path in order if (lines := added_lines(path, originals[path]))}
    if added:
        for path, lines in added.items():
            print(f"{path} gained:\n" + "\n".join(f"+ {line}" for line in lines))
        raise CheckFailed(
            "the resave wrote more than ids (above). The dump can't see this: it runs "
            "scripts, so a value a script's _init() sets loads the same with or without "
            "the line. Set that value in _ready() instead, or put it in the scene"
        )


# What a resave may change on a line: the ids it adds, the ids it renumbers, and counts.
RESAVE_IDS = re.compile(r' (uid|unique_id|id|load_steps)=("[^"]*"|\d+)|(?<=Resource\()"[^"]*"')


# A shader uniform the material leaves at the shader's default. Godot writes one for every
# uniform the shader gained since the file was saved; the material loads the same with or
# without it, so it can't be a value a script set.
UNSET_SHADER_PARAMETER = re.compile(r"shader_parameter/\w+ = null")


def added_lines(path: str, original: bytes) -> list[str]:
    """The lines a resave added to a file, ids and unset shader uniforms aside. A resave
    only adds those, so any other line is a value that wasn't in the file, such as one a
    script's _init() set."""
    def lines(text: str) -> list[str]:
        return [RESAVE_IDS.sub("", line) for line in text.splitlines() if line.strip()]

    before = lines(original.decode("utf-8", errors="replace"))
    after = lines(Path(path).read_text(encoding="utf-8", errors="replace"))
    left = list(before)
    added = []
    for line in after:
        if line in left:
            left.remove(line)
        elif not UNSET_SHADER_PARAMETER.fullmatch(line):
            added.append(line)
    return added


def resource_dump(paths: list[str]) -> list[str]:
    """What the files hold as the game loads them, one line per stored property, ids left
    out: tools/resource_dump.gd's output."""
    args = ["--headless", "--path", ".", "-s", "res://tools/resource_dump.gd", "--"]
    result = run_godot([*args, *(f"res://{path}" for path in paths)])
    prefixes = tuple(f"res://{path} " for path in paths)
    lines = [line for line in result.stdout.splitlines() if line.startswith(prefixes)]
    if result.returncode != 0 or logged_error(result.stdout) or not lines:
        print(result.stdout, end="")
        raise CheckFailed("tools/resource_dump.gd could not read the files above")
    return lines


def dump_changes(before: list[str], after: list[str]) -> list[str]:
    """The lines of two resource dumps that differ, - before and + after. Files are dumped
    in the same order both times, so a plain line diff reads as a property diff."""
    return [
        line
        for line in difflib.unified_diff(before, after, lineterm="", n=0)
        if line.startswith(("-", "+")) and not line.startswith(("---", "+++"))
    ]


def restore(originals: dict[str, bytes]) -> None:
    for path, content in originals.items():
        Path(path).write_bytes(content)


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


def run_test(files: list[str], verbose: bool):
    """Runs every suite in test/, or the given suites and folders. --verbose prints the
    whole run, which is where a test's print() lines go: by default only failures show."""
    targets = test_targets(files)
    ensure_build_dir("build/reports")
    adds = [arg for target in targets for arg in ("-a", f"res://{target}")]
    try:
        result = run_godot(
            [
                "--headless", "--path", ".", *FIXED_FPS,
                "-s", "-d", "--remote-debug", "tcp://127.0.0.1:0",
                "res://addons/gdUnit4/bin/GdUnitCmdTool.gd",
                *adds, "-c", "-rd", "res://build/reports", "--ignoreHeadlessMode",
            ]
        )  # fmt: skip
    except TimedOut as timeout:
        raise CheckFailed(stalled_test_message(timeout)) from timeout
    output = DEBUGGER_NOISE.sub("", result.stdout)
    if verbose:
        print(output, end="")
    # gdUnit4 exits 0 when it finds nothing, so a wrong path or deleted suites would pass.
    summary = re.search(r"^Overall Summary: (\d+) test cases.*$", output, re.MULTILINE)
    if "No test cases found" in output or (summary and summary.group(1) == "0"):
        raise CheckFailed("no test cases found in " + ", ".join(targets))
    # A runner that stops before the suites run can still exit 0, with no summary.
    if not summary:
        print(output, end="")
        raise CheckFailed(
            f"gdUnit4 printed no summary, so no tests ran (exit code {result.returncode})"
        )
    if result.returncode not in (0, 101):
        failures = FAILED_TEST.findall(output)
        # A failing before() or after() has no FAILED test block, so print everything.
        if not verbose:
            print("".join(failures) + summary.group(0) if failures else output)
        raise CheckFailed(f"gdUnit4 exit code {result.returncode} (report in build/reports/)")
    return f"{summary.group(1)} tests"


def test_targets(files: list[str]) -> list[str]:
    """The given suites and folders as project paths, or test/ itself."""
    if not files:
        return ["test"]
    targets = [project_path(f) for f in files]
    wrong = [
        given
        for given, target in zip(files, targets)
        if not (target == "test" or target.startswith("test/")) or not Path(target).exists()
    ]
    if wrong:
        raise CheckFailed("not a suite or folder under test/: " + ", ".join(wrong))
    return targets


def stalled_test_message(timeout: TimedOut) -> str:
    """A test run that stops making progress is almost always a gdUnit timeout that can't
    fire: its Timers pause with the tree, so a test that leaves the tree paused hangs on
    the next await, its own or a later suite's, instead of failing. Name where it stopped,
    since the bare timeout names nothing."""
    output = DEBUGGER_NOISE.sub("", timeout.output)
    suites = re.findall(r"^Run Test Suite: (\S+)", output, re.MULTILINE)
    tests = re.findall(r"^  \S+ > (\w+)", output, re.MULTILINE)
    if suites:
        where = suites[-1] + (f" > {tests[-1]}" if tests else "")
    else:
        # No suite line: the run stopped before the first suite, or gdUnit's console
        # format changed. Show the output so the failure still says where it stopped.
        tail = "\n".join(output.splitlines()[-20:]) or "(no output)"
        where = f"no test suite (the last output follows)\n{tail}\n"
    return (
        f"{timeout}\nThe run stopped in {where}. gdUnit's timeouts (await_signal_on, wait_until, "
        "the per-test timeout) are Timers that stop while the tree is paused, so a test that "
        "leaves get_tree().paused on, here or in an earlier suite, hangs instead of failing. "
        "Unpause in after_test(), and wait with test/support/pause_proof_wait.gd while paused "
        "(gdunit-tests skill, Signals)."
    )


def main_scene() -> str | None:
    match = re.search(
        r'^run/main_scene="([^"]+)"', Path("project.godot").read_text(), re.MULTILINE
    )
    return match.group(1) if match else None


def main_scene_path() -> str | None:
    """The main scene as a res:// path. The editor may write run/main_scene as a uid://."""
    main = main_scene()
    if not main or not main.startswith("uid://"):
        return main
    by_uid = {uid: "res://" + path for path, uid in project_uids().items()}
    return by_uid.get(main, main)


def logged_error(output: str) -> bool:
    return bool(ERROR_LINE.search(EXIT_LEAK.sub("", output)))


def game_scenes() -> list[str]:
    """The scenes the game can reach, the main scene first: everything a scene, resource or
    script references by res:// or uid:// path, followed from the main scene and the
    autoloads. A scene nothing references yet, such as one still being built, is left out
    until something does, and tools/ and test/ are never followed. Every scene in the game
    instantiates on its own (CODING_STANDARDS.md, Scene composition), and a sub-scene that
    only works inside its parent, or a level the menus reach only after a click, shows it
    only when run."""
    by_uid = {uid: "res://" + path for path, uid in project_uids().items()}
    main = main_scene_path()
    settings = Path("project.godot").read_text(encoding="utf-8", errors="replace")
    autoloads = re.findall(r'^\w+="\*?((?:res|uid)://[^"]+)"', settings, re.MULTILINE)
    seen: set[str] = set()
    pending = [main, *autoloads] if main else autoloads
    while pending:
        reference = pending.pop()
        path = by_uid.get(reference, "") if reference.startswith("uid://") else reference
        path = path.removeprefix("res://")
        game_file = ours(path) and not path.startswith(NOT_GAME) and Path(path).is_file()
        if path in seen or not game_file:
            continue
        seen.add(path)
        text = Path(path).read_text(encoding="utf-8", errors="replace")
        if path.endswith(".gd"):
            # Strings only, so a path in a comment doesn't count as a reference.
            text = "\n".join(string for _, string in split_gdscript(text)[1])
        elif not path.endswith((".tscn", ".tres")):
            continue
        pending += re.findall(r'(?:res|uid)://[^"\s]+', text)
    scenes = sorted("res://" + path for path in seen if path.endswith(".tscn"))
    return ([main] if main in scenes else []) + [scene for scene in scenes if scene != main]


def run_smoke(scenes: list[str]):
    if not scenes:
        scenes = game_scenes()
        if not scenes:
            return "SKIPPED, no main scene set in project.godot"
    godot()  # Find the binary once, before the threads do.
    with ThreadPoolExecutor(SMOKE_WORKERS) as pool:
        results = list(
            pool.map(
                lambda scene: run_godot(
                    ["--headless", "--path", ".", "--scene", scene, *FIXED_FPS, "--quit-after", SMOKE_FRAMES]
                ),
                scenes,
            )
        )
    # Each scene still runs on its own; the first failure in scene order is the one named.
    for scene, result in zip(scenes, results):
        # A crash logs a backtrace but no ERROR line, so only the exit code shows it.
        if result.returncode != 0:
            print(result.stdout, end="")
            raise CheckFailed(f"Godot exited with code {result.returncode} while running {scene}")
        if logged_error(result.stdout):
            print(result.stdout, end="")
            raise CheckFailed(f"errors logged while running {scene}")
    return ", ".join(scenes)


def run_export(preview: bool):
    """Web is the itch.io build. Web Preview is the preview build: it keeps LimboConsole
    and uses the debug template, so its pack boots with no errors at all."""
    preset, folder = ("Web Preview", "build/web-preview/game") if preview else ("Web", "build/web")
    directory = ensure_build_dir(folder)
    if preview:
        shutil.copyfile(PREVIEW_FRAME, directory.parent / "index.html")
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
    # From the repo root, --main-pack would load the project instead of the pack. The pack
    # leaves files out (test/, tools/, the dev console, files that aren't resources), so
    # every scene smoke runs boots from it too: the main scene as a browser starts it, with
    # no --scene, and each other scene on its own.
    main = main_scene_path()
    for scene in [None, *(scene for scene in game_scenes() if scene != main)]:
        scene_args = ["--scene", scene] if scene else []
        boot = run(
            [godot(), "--headless", "--main-pack", "index.pck", *scene_args]
            + ["--quit-after", SMOKE_FRAMES],
            cwd=directory,
        )
        log = boot.stdout if preview else WEB_CONSOLE_MISSING.sub("", boot.stdout)
        if boot.returncode != 0 or logged_error(log):
            print(boot.stdout, end="")
            raise CheckFailed(
                f"errors logged while booting the exported pack ({scene or 'main scene'})"
            )
    return f"{pck.as_posix()} {pck.stat().st_size / 1e6:.1f} MB, boots clean"


def build_commit() -> str:
    """The short commit the main menu shows. CI sets BUILD_COMMIT where HEAD isn't the
    commit people know: a pull_request checkout is GitHub's merge commit, not the PR head."""
    commit = os.environ.get("BUILD_COMMIT") or git("rev-parse", "HEAD")
    commit = commit[:7]
    if not os.environ.get("BUILD_COMMIT") and git("status", "--porcelain", "--untracked-files=no"):
        commit += "-dirty"
    return commit


def run_capture(
    scene: str,
    user_args: list[str] | tuple[str, ...] = (),
    size: str | None = None,
    frames: int = CAPTURE_FRAMES,
):
    """Windowed only: --write-movie crashes under --headless. The scene reads
    user_args through OS.get_cmdline_user_args(). A size other than the project's
    1152x648 makes the canvas_items stretch scale the game, as a browser window does."""
    if size and not CAPTURE_SIZE.match(size):
        raise CheckFailed(f"--size takes WIDTHxHEIGHT, like 1920x1080, not {size}")
    if frames < 1:
        raise CheckFailed("--frames takes a number of frames, 1 or more")
    directory = ensure_build_dir("build/capture")
    for old in directory.iterdir():
        old.unlink()
    command = [
        "--path", ".", "--scene", scene,
        "--write-movie", str((directory / "frame.png").resolve()),
        "--quit-after", str(frames),
        "--", *user_args,
    ]  # fmt: skip
    if size:
        with window_size_override(size):
            result = run_godot(command)
    else:
        result = run_godot(command)
    (directory / "frame.wav").unlink(missing_ok=True)
    frames = sorted(directory.glob("frame*.png"))
    if not frames:
        print(result.stdout, end="")
        raise CheckFailed(f"no frames written for {scene}")
    errors = " (errors logged, see above)" if logged_error(result.stdout) else ""
    if errors:
        print(result.stdout, end="")
    return f"{len(frames)} frames, look at {frames[-1].as_posix()}{errors}"


OVERRIDE_MARK = "; Written by check.py capture --size for one capture; safe to delete."


@contextmanager
def window_size_override(size: str):
    """Movie Maker records at the project's window size and ignores --resolution, so a
    capture at another size needs the window size override. Godot reads it from
    override.cfg beside project.godot, which this writes for the one run (git ignores it)."""
    override = Path("override.cfg")
    # A capture killed before its finally leaves its file behind, which is safe to replace.
    if override.exists() and not override.read_text(encoding="utf-8").startswith(OVERRIDE_MARK):
        raise CheckFailed(
            "override.cfg exists and capture --size didn't write it. It overrides project "
            "settings in every run of the project: move it aside, then capture again"
        )
    width, height = size.split("x")
    override.write_text(
        OVERRIDE_MARK + "\n[display]\n\n"
        f"window/size/window_width_override={width}\n"
        f"window/size/window_height_override={height}\n",
        encoding="utf-8",
    )
    try:
        yield
    finally:
        override.unlink(missing_ok=True)


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
