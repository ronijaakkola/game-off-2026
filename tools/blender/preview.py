"""Renders a model as a 2x2 Workbench grid: front, right side, top, three-quarter.
Args after --: <model> <out.png>. For the shape only: Godot's capture judges the look.
"""

import sys
from pathlib import Path

import bpy
import numpy
from mathutils import Vector

SIZE = 512
# Where the camera looks from, in Blender axes (the model's front faces -Y), in grid
# order: top-left, top-right, bottom-left, bottom-right.
VIEWS = [Vector((0, -1, 0)), Vector((1, 0, 0)), Vector((0, 0, 1)), Vector((1, -1.6, 0.8))]

name, out = sys.argv[sys.argv.index("--") + 1 :][:2]
collection = bpy.data.collections.get(name)
assert collection is not None, f"no collection named {name!r} in the library"
scene = bpy.context.scene
for other in scene.collection.children:
    other.hide_render = other != collection
shown = [o for o in collection.all_objects if o.type == "MESH" and not o.name.endswith("-colonly")]
assert shown, f"{name!r} has no visible meshes"
for obj in collection.all_objects:
    obj.hide_render = obj not in shown
# Workbench shows a material's viewport colour, so copy the Principled base colour there.
# The library isn't saved after a preview.
for material in bpy.data.materials:
    bsdf = material.node_tree and material.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        material.diffuse_color = bsdf.inputs["Base Color"].default_value

corners = [obj.matrix_world @ Vector(c) for obj in shown for c in obj.bound_box]
low = Vector(min(c[i] for c in corners) for i in range(3))
high = Vector(max(c[i] for c in corners) for i in range(3))
center = (low + high) / 2
reach = (high - low).length

camera = bpy.data.objects.new("PreviewCamera", bpy.data.cameras.new("PreviewCamera"))
scene.collection.objects.link(camera)
scene.camera = camera
camera.data.type = "ORTHO"
camera.data.ortho_scale = reach * 1.1
camera.data.clip_end = reach * 10
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
scene.render.resolution_x = scene.render.resolution_y = SIZE
scene.render.film_transparent = False

grid = numpy.zeros((SIZE * 2, SIZE * 2, 4), dtype=numpy.float32)
part = Path(out).with_suffix(".part.png")
for index, view in enumerate(VIEWS):
    camera.location = center + view.normalized() * reach * 3
    if view.z > 0.99:  # straight down, with the model's front at the bottom of the image
        camera.rotation_euler = (0, 0, 0)
    else:
        camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = str(part)
    bpy.ops.render.render(write_still=True)
    image = bpy.data.images.load(str(part))
    pixels = numpy.empty(SIZE * SIZE * 4, dtype=numpy.float32)
    image.pixels.foreach_get(pixels)
    bpy.data.images.remove(image)
    row, column = divmod(index, 2)
    # Image rows start at the bottom, so the grid's top row is the upper half.
    top = SIZE * (1 - row)
    grid[top : top + SIZE, column * SIZE : (column + 1) * SIZE] = pixels.reshape(SIZE, SIZE, 4)
part.unlink()

result = bpy.data.images.new("Preview", SIZE * 2, SIZE * 2)
result.pixels.foreach_set(grid.ravel())
result.filepath_raw = out
result.file_format = "PNG"
result.save()
print("PREVIEW", out)
