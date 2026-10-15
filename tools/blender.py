# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""Model library commands. Run from anywhere: `uv run tools/blender.py <command>`.

  run <script> [args]  run a build script against art/models.blend, then save it
                       (creates the library on first use)
  preview <model>      render the model's shape to build/preview/<model>.png
  export <model>       export the model to its .glb, import it into Godot and capture it

Blender 5.2 comes from the BLENDER environment variable or the PATH. Close the library
in Blender first: this edits the file on disk, and a Blender window would overwrite it.
"""

import argparse
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import time
from pathlib import Path

import check
from check import CheckFailed

ROOT = check.ROOT
LIBRARY = Path("art/models.blend")
HELPERS = ROOT / "tools" / "blender"
BLENDER_VERSION = "5.2"
TIMEOUT = 300
PREVIEW_SCENE = "res://tools/model_preview.tscn"


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    commands = parser.add_subparsers(dest="command", required=True)
    run = commands.add_parser("run")
    run.add_argument("script")
    run.add_argument("args", nargs=argparse.REMAINDER)
    commands.add_parser("preview").add_argument("model")
    commands.add_parser("export").add_argument("model")
    args = parser.parse_args()
    # Resolve the script before changing directory, since it's usually in a scratchpad.
    script = Path(args.script).resolve() if args.command == "run" else None
    os.chdir(ROOT)
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

    steps = {
        "run": lambda: run_script(script, args.args),
        "preview": lambda: run_preview(args.model),
        "export": lambda: run_export(args.model),
    }
    return 0 if check.run_step(args.command, steps[args.command]) else 1


# --- Blender ----------------------------------------------------------------

_blender: str | None = None


def blender() -> str:
    global _blender
    if _blender:
        return _blender
    binary = os.environ.get("BLENDER") or shutil.which("blender")
    found = ""
    if binary:
        try:
            found = subprocess.run(
                [binary, "--version"], capture_output=True, text=True, timeout=30
            ).stdout.strip()
        except OSError:
            found = ""
    if not found.startswith(f"Blender {BLENDER_VERSION}."):
        raise CheckFailed(
            f"Blender {BLENDER_VERSION} not found (got {found.splitlines()[0] if found else binary or 'nothing'}). "
            "Set BLENDER to its path, e.g. Mac: "
            "export BLENDER=/Applications/Blender.app/Contents/MacOS/Blender, Windows: "
            'setx BLENDER "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe"'
        )
    _blender = binary
    return binary


def run_blender(script: Path, args: list[str], library: bool = True, save: bool = False) -> str:
    """Runs a script in background Blender with tools/blender/ importable. A failing
    script exits before the save, so a half-built model is never saved."""
    command = [blender(), "--background", "--factory-startup", "--python-exit-code", "1"]
    if library:
        command.append(str(LIBRARY))
    command += ["--python-expr", f"import sys; sys.path.insert(0, {str(HELPERS)!r})"]
    command += ["--python", str(script)]
    if save:
        command += ["--python-expr", "import bpy; bpy.ops.wm.save_mainfile()"]
    command += ["--", *args]
    try:
        result = subprocess.run(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=TIMEOUT,
        )
    except subprocess.TimeoutExpired as timeout:
        raise CheckFailed(f"Blender timed out after {TIMEOUT} s") from timeout
    if result.returncode != 0:
        print(result.stdout, end="")
        raise CheckFailed(f"Blender exit code {result.returncode} running {script.name}")
    return result.stdout


def ensure_library() -> None:
    """Creates art/models.blend on first use. Never overwrites it."""
    if LIBRARY.exists():
        return
    run_blender(HELPERS / "new_library.py", [str(LIBRARY.resolve())], library=False)
    print(f"created the model library at {LIBRARY.as_posix()}")


# --- commands ---------------------------------------------------------------


def run_script(script: Path, args: list[str]):
    if not script.is_file():
        raise CheckFailed(f"no script at {script}")
    ensure_library()
    print(run_blender(script, args, save=True), end="")
    return f"saved {LIBRARY.as_posix()}"


def run_preview(model: str):
    if not LIBRARY.exists():
        raise CheckFailed(f"no model library at {LIBRARY.as_posix()}")
    out = check.ensure_build_dir("build/preview") / f"{model}.png"
    out.unlink(missing_ok=True)
    run_blender(HELPERS / "preview.py", [model, str(out.resolve())])
    if not out.exists():
        raise CheckFailed(f"{out.as_posix()} was not written")
    return f"look at {out.as_posix()} (front, side / top, three-quarter)"


def run_export(model: str):
    if not LIBRARY.exists():
        raise CheckFailed(f"no model library at {LIBRARY.as_posix()}")
    output = run_blender(HELPERS / "export.py", [model])
    glb = Path(re.search(r"^EXPORTED (.+)$", output, re.MULTILINE).group(1).strip())
    try:
        res_path = "res://" + glb.relative_to(ROOT).as_posix()
    except ValueError:
        raise CheckFailed(f"{glb} is outside the project") from None
    print(f"exported {res_path}")
    print(glb_facts(glb))
    check.godot()
    flipped = textures_to_vram(glb)
    if flipped:
        check.run_godot(["--headless", "--path", ".", "--import"])
        print(f"set {flipped} extracted textures to VRAM Compressed")
    return check.run_capture(PREVIEW_SCENE, (res_path,))


def glb_facts(glb: Path) -> str:
    """Nodes, vertex and triangle counts, materials and extensions, from the JSON chunk."""
    data = glb.read_bytes()
    gltf = json.loads(data[20 : 20 + struct.unpack_from("<I", data, 12)[0]])
    accessors = gltf.get("accessors", [])
    lines = []
    for node in gltf.get("nodes", []):
        if "mesh" not in node:
            lines.append(f"  node {node.get('name')}")
            continue
        primitives = gltf["meshes"][node["mesh"]]["primitives"]
        vertices = sum(accessors[p["attributes"]["POSITION"]]["count"] for p in primitives)
        triangles = sum(accessors[p["indices"]]["count"] // 3 for p in primitives if "indices" in p)
        lines.append(f"  node {node.get('name')}: {vertices} vertices, {triangles} triangles")
    materials = [m.get("name", "?") for m in gltf.get("materials", [])]
    lines.append(f"  materials: {len(materials)} ({', '.join(materials)})")
    lines.append(f"  images: {len(gltf.get('images', []))}")
    lines.append(f"  extensions: {', '.join(gltf.get('extensionsUsed', [])) or 'none'}")
    return "\n".join(lines)


def textures_to_vram(glb: Path) -> int:
    """Godot extracts a .glb's images as <model>_<image>.png and imports them Lossless.
    Sets them to VRAM Compressed, which the editor would only do on its first 3D render."""
    lossless = {}
    for config in glb.parent.glob(f"{glb.stem}_*.png.import"):
        text = config.read_text(encoding="utf-8")
        vram, count = re.subn(r"^compress/mode=0$", "compress/mode=2", text, flags=re.MULTILINE)
        if count:
            lossless[config] = vram
    if lossless:
        # Godot re-imports when the .import file's modified time changes, counted in
        # whole seconds, so an edit in the second of its import would go unnoticed.
        time.sleep(1.1)
    for config, vram in lossless.items():
        config.write_text(vram, encoding="utf-8", newline="")
    return len(lossless)

if __name__ == "__main__":
    sys.exit(main())
