"""Renders the game's icon, `icon.png`: the bus alone on a transparent square, its trail and
glow whole inside the frame, from the menu banner's scene, without saving it.

  Blender -b art/banner/banner.blend --python tools/game_icon/render_game_icon.py -- [size] [samples]

Blender 5.2. `art/` is ignored by git, so the scene is in whichever checkout made the banner.
"""

import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
SIZE = int(ARGS[0]) if ARGS else 1024
SAMPLES = int(ARGS[1]) if len(ARGS) > 1 else 128
OUT = Path(__file__).resolve().parents[2] / "icon.png"

# From the bus to the camera: its nose is at -Y, so this is front, right and above.
VIEW_DIR = Vector((0.62, -1.25, 0.48)).normalized()
LENS = 52
ROLL = math.radians(-7)
# How far back the camera sits from where everything just fits, so the glow has room.
MARGIN = 1.18
# The glare's faintest haze reaches the frame's edge; glow dimmer than this is dropped.
GLOW_FLOOR = 0.15
# The share of the icon's side the picture takes, centred.
FILL = 0.92

scene = bpy.context.scene
cam = scene.camera
objs = bpy.data.objects
scene.render.film_transparent = True
# EXR keeps the glow where the alpha is zero, which a PNG would throw away.
scene.render.image_settings.file_format = "OPEN_EXR"
scene.render.image_settings.color_mode = "RGBA"
scene.render.resolution_x = scene.render.resolution_y = SIZE
scene.render.resolution_percentage = 100
scene.cycles.samples = SAMPLES
for name in ("Giant", "GiantRings", "Frost"):
    objs[name].hide_render = True

coords = []
for name in ("Body", "ThrusterGlow", "TrailLeft", "TrailRight"):
    for v in objs[name].data.vertices:
        coords.extend(objs[name].matrix_world @ v.co)
center = Vector((0, 0.3, 0.18))
cam.data.lens = LENS
cam.data.shift_x = cam.data.shift_y = 0.0
cam.location = center + VIEW_DIR * 3
cam.rotation_euler = (-VIEW_DIR).to_track_quat("-Z", "Y").to_euler()
cam.rotation_euler.rotate_axis("Z", ROLL)
bpy.context.view_layer.update()
fit, _ = cam.camera_fit_coords(bpy.context.evaluated_depsgraph_get(), coords)
back = cam.matrix_world.to_3x3() @ Vector((0, 0, 1))
cam.location = Vector(fit) + back * (Vector(fit) - center).dot(back) * (MARGIN - 1)

exr = str(OUT.with_suffix(".exr"))
scene.render.filepath = exr
bpy.ops.render.render(write_still=True)

src = bpy.data.images.load(exr)
px = np.empty(SIZE * SIZE * 4, dtype=np.float32)
src.pixels.foreach_get(px)
px = px.reshape(SIZE, SIZE, 4)
rgb = np.clip(px[:, :, :3], 0, None)
# The glare's glow has no alpha of its own: give it the alpha of its brightest channel.
glow = np.clip((rgb.max(axis=2) - GLOW_FLOOR) / (1 - GLOW_FLOOR), 0, 1)
alpha = np.clip(np.maximum(px[:, :, 3], glow), 0, 1)
straight = np.clip(rgb / np.maximum(alpha, 1e-6)[:, :, None], 0, 1)
srgb = np.where(straight <= 0.0031308, straight * 12.92, 1.055 * straight ** (1 / 2.4) - 0.055)
rgba = np.concatenate([srgb, alpha[:, :, None]], axis=2).astype(np.float32)

# Centre what was drawn in a square it fills to FILL, then bring that back to SIZE.
rows, cols = np.nonzero(alpha > 0)
crop = rgba[rows.min() : rows.max() + 1, cols.min() : cols.max() + 1]
side = math.ceil(max(crop.shape[:2]) / FILL)
square = np.zeros((side, side, 4), dtype=np.float32)
top, left = (side - crop.shape[0]) // 2, (side - crop.shape[1]) // 2
square[top : top + crop.shape[0], left : left + crop.shape[1]] = crop

dst = bpy.data.images.new("icon", side, side, alpha=True)
dst.alpha_mode = "STRAIGHT"
dst.pixels.foreach_set(square.ravel())
dst.scale(SIZE, SIZE)
dst.filepath_raw = str(OUT)
dst.file_format = "PNG"
dst.save()
Path(exr).unlink()
print("RENDERED", OUT)
