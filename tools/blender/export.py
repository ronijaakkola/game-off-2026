"""Exports one model to its .glb through its Collection Exporter. Args after --: <model>.

Moves the model from its library spot to the world origin first. The library is never
saved afterwards, so the move doesn't stick.
"""

import sys
from pathlib import Path

import bpy

import library

name = sys.argv[sys.argv.index("--") + 1]
collection = bpy.data.collections.get(name)
assert collection is not None, f"no collection named {name!r} in the library"
assert collection.exporters, f"{name!r} has no exporter: make it with library.model()"
glb = Path(bpy.path.abspath(library.exporter(collection).export_properties.filepath))
offset = collection.instance_offset.copy()
for obj in collection.all_objects:
    if obj.parent is None:
        obj.location -= offset
view_layer = bpy.context.view_layer
view_layer.active_layer_collection = view_layer.layer_collection.children[name]
before = glb.stat().st_mtime if glb.exists() else 0.0
glb.parent.mkdir(parents=True, exist_ok=True)
assert bpy.ops.collection.export_all() == {"FINISHED"}
assert glb.exists() and glb.stat().st_mtime > before, f"{glb} was not written"
print("EXPORTED", glb.resolve())
