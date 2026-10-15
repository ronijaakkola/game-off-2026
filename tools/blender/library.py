"""Helpers for build scripts that make models in the model library, art/models.blend.

`uv run tools/blender.py run` puts this folder on sys.path, so a build script starts with
`import library`. Through the Blender Lab MCP, add it first:
`sys.path.insert(0, "<repo>/tools/blender")`.

Each model is a top-level collection named after its .glb, carrying a glTF Collection
Exporter with the path and the fixed settings below. Models sit side by side in the
library; the collection's instance_offset records where, and export moves it back.
"""

import math
import warnings

import bpy
from mathutils import Vector

# GLB, +Y up, modifiers applied (or Bevel and Smooth by Angle are lost). Godot 4.7
# can't read Draco or Meshopt and drops GPU instances.
EXPORT_SETTINGS = {
    "export_format": "GLB",
    "export_yup": True,
    "export_apply": True,
    "export_draco_mesh_compression_enable": False,
    "export_meshopt_compression_enable": False,
    "export_gpu_instances": False,
}
# Metres of empty space between models in the library.
SPACING = 1.0


def model(name: str, glb: str) -> bpy.types.Collection:
    """The collection for model `name`, exported to `glb`, a path from the project root
    such as "game/models/piece.glb". A new one is placed beside the other models."""
    collection = bpy.data.collections.get(name)
    if collection is None:
        collection = bpy.data.collections.new(name)
        collection.instance_offset = (_free_x(), 0.0, 0.0)
        bpy.context.scene.collection.children.link(collection)
    settings = exporter(collection).export_properties
    with warnings.catch_warnings(action="ignore", category=RuntimeWarning):
        settings.filepath = "//../" + glb
    return collection


def exporter(collection: bpy.types.Collection):
    """The collection's glTF exporter, created if missing, with the fixed settings."""
    if not collection.exporters:
        view_layer = bpy.context.view_layer
        view_layer.active_layer_collection = view_layer.layer_collection.children[collection.name]
        assert bpy.ops.collection.exporter_add(name="IO_FH_gltf2") == {"FINISHED"}
    settings = collection.exporters[0].export_properties
    # The glTF operator warns that its path doesn't support "//", but a Collection
    # Exporter resolves it against the library, which keeps the path the same in every clone.
    with warnings.catch_warnings(action="ignore", category=RuntimeWarning):
        for key, value in EXPORT_SETTINGS.items():
            setattr(settings, key, value)
    return collection.exporters[0]


def add(collection: bpy.types.Collection, obj: bpy.types.Object) -> bpy.types.Object:
    """Moves `obj`, built around the world origin, into the model at its library spot."""
    for old in obj.users_collection:
        old.objects.unlink(obj)
    collection.objects.link(obj)
    obj.location += collection.instance_offset
    return obj


def clear(collection: bpy.types.Collection) -> None:
    """Deletes the model's objects, to rebuild it from scratch."""
    for obj in list(collection.all_objects):
        bpy.data.objects.remove(obj)


def _free_x() -> float:
    """The first whole metre right of every object in the library, plus SPACING."""
    right = [
        (obj.matrix_world @ Vector(corner)).x
        for obj in bpy.context.scene.objects
        for corner in obj.bound_box
    ]
    return float(math.ceil(max(right) + SPACING)) if right else 0.0
