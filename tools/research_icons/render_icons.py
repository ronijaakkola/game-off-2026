"""Renders the research upgrade icons in the game's two-tone look, every one under the same
camera and light, to transparent 512 px PNGs. `icon_pngs.py` then makes the tile sizes.

  Blender -b --factory-startup --python tools/research_icons/render_icons.py -- <out> [icon ...]

Blender 5.2. <out> is a folder for the renders, such as tmp/research_icons (git ignores
tmp/). Icons are the keys of ICONS; all of them when none are named. The Speed icon is the
bus from game/bus/models/bus.glb.
"""

import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1 :]
OUT, ONLY = Path(ARGS[0]), ARGS[1:]
OUT.mkdir(parents=True, exist_ok=True)
BUS_GLB = str(Path(__file__).resolve().parents[2] / "game/bus/models/bus.glb")

RES = 512
YAW, PITCH = math.radians(35), math.radians(28)
# Camera direction from the model: front (-Y in Blender) right (+X) and above.
VIEW_DIR = Vector((math.sin(YAW) * math.cos(PITCH), -math.cos(YAW) * math.cos(PITCH), math.sin(PITCH)))
# The night side multiplies by this (linear), as shared/two_tone_light.gdshaderinc.
SHADOW = (0.5, 0.45, 0.78)


def lin(h):
    h = h.lstrip("#")
    rgb = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb)


LILAC, DARK, WHITE = lin("#7361b3"), lin("#2e2b52"), lin("#f5f2ff")
ORANGE, GREY, CYAN = lin("#fa8033"), lin("#b3b8cc"), lin("#99f2ff")
RED, BLUE = lin("#ff4d4d"), lin("#4d80ff")
YELLOW, GOLD, PINK = lin("#ffcc4d"), lin("#f2b632"), lin("#ff7aa8")
BROWN, PALE_LILAC, TEAL = lin("#8a5a3c"), lin("#c4b5f5"), lin("#3fb8b0")
EMBER, GLASS, COFFEE = lin("#ff9a3c"), lin("#cfe9ff"), lin("#5a3624")


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = scene.render.resolution_y = RES
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    scene.eevee.taa_render_samples = 64
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0, 0, 0, 1)
    scene.world = world
    root = bpy.data.objects.new("Root", None)
    scene.collection.objects.link(root)
    return root


def add(obj, root, color, unlit=False, bevel=0.03):
    obj.parent = root
    obj.data.materials.clear()
    m = bpy.data.materials.new(obj.name)
    m["base"] = list(color)
    m["unlit"] = unlit
    obj.data.materials.append(m)
    if bevel:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
    return obj


def box(root, size, color, loc, rot=(0, 0, 0), bevel=0.03, unlit=False):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=[math.radians(r) for r in rot])
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return add(o, root, color, unlit, bevel)


def cyl(root, r1, r2, depth, color, loc, rot=(0, 0, 0), verts=16, bevel=0.015, unlit=False):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=loc,
                                    rotation=[math.radians(r) for r in rot])
    return add(bpy.context.object, root, color, unlit, bevel)


def seat_model(root):
    box(root, (2.3, 1.1, 0.06), DARK, (0, 0, 0))
    for x, col in ((-0.58, LILAC), (0.58, ORANGE)):
        box(root, (0.92, 0.88, 0.2), col, (x, 0, 0.5), bevel=0.06)
        box(root, (0.92, 0.17, 1.0), col, (x, 0.4, 1.05), rot=(-8, 0, 0), bevel=0.06)
        box(root, (0.52, 0.15, 0.24), WHITE, (x, 0.46, 1.64), rot=(-8, 0, 0), bevel=0.05)
        cyl(root, 0.06, 0.06, 0.42, DARK, (x, 0, 0.22), verts=10)


def camera_model(root):
    cyl(root, 0.9, 0.9, 0.08, LILAC, (0, 0, 0), verts=6, bevel=0.02)
    box(root, (0.18, 0.18, 1.6), GREY, (-0.55, 0.45, 0.8))
    box(root, (0.08, 0.5, 0.08), GREY, (-0.55, 0.22, 1.5), bevel=0.01)
    head = bpy.data.objects.new("Head", None)
    bpy.context.scene.collection.objects.link(head)
    head.parent = root
    head.location = (-0.25, -0.05, 1.45)
    head.rotation_euler = (math.radians(15), 0, math.radians(105))
    box(head, (0.36, 0.8, 0.34), WHITE, (0, 0, 0), bevel=0.05)
    box(head, (0.44, 0.95, 0.06), DARK, (0, -0.06, 0.2), bevel=0.02)
    cyl(head, 0.13, 0.13, 0.12, DARK, (0, -0.44, 0), rot=(90, 0, 0), verts=20)
    cyl(head, 0.085, 0.085, 0.03, BLUE, (0, -0.505, 0), rot=(90, 0, 0), verts=20, unlit=True)
    cyl(head, 0.035, 0.035, 0.03, RED, (0.12, -0.41, 0.1), rot=(90, 0, 0), verts=10, unlit=True)


def rounded(root, size, color, loc, rot=(0, 0, 0), softness=0.35):
    """A box with deeply rounded edges: a cushion. [softness] is the share of its
    thinnest side that rounds off."""
    o = box(root, size, color, loc, rot, bevel=0)
    mod = o.modifiers.new("Soft", "BEVEL")
    mod.width = min(size) * softness
    mod.segments = 3
    return o


def sphere(root, radius, color, loc, scale=(1, 1, 1), segments=16, unlit=False):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=segments // 2, radius=radius, location=loc)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    # Smooth, so the light's edge across it is one clean line rather than steps.
    bpy.ops.object.shade_smooth()
    return add(o, root, color, unlit, bevel=0)


def letter(root, text, size, color, loc, rot=(90, 0, 0)):
    bpy.ops.object.text_add(location=loc, rotation=[math.radians(r) for r in rot])
    o = bpy.context.object
    o.data.body = text
    o.data.size = size
    o.data.extrude = size * 0.08
    o.data.align_x = o.data.align_y = "CENTER"
    bpy.ops.object.convert(target="MESH")
    return add(bpy.context.object, root, color, bevel=0)


def fuel_tank_model(root):
    """A fat fuel canister lying on its side, with a window showing the cyan fuel."""
    cyl(root, 0.62, 0.62, 2.1, WHITE, (0, 0, 0.7), rot=(0, 90, 0), verts=24, bevel=0.22)
    box(root, (0.8, 0.1, 0.5), CYAN, (0, -0.6, 0.66), bevel=0.05, unlit=True)
    cyl(root, 0.2, 0.2, 0.24, RED, (0.55, 0, 1.38), verts=16, bevel=0.04)


def pillow_model(root):
    """Two soft pillows, one leaning on the other, and a sleepy Z."""
    rounded(root, (1.6, 1.1, 0.5), PALE_LILAC, (0, 0, 0.25), softness=0.45)
    rounded(root, (1.5, 1.0, 0.46), WHITE, (0.1, 0.3, 0.85), rot=(-32, 0, 6), softness=0.45)
    letter(root, "Z", 0.55, LILAC, (0.75, -0.1, 1.55), rot=(80, 0, 35))
    letter(root, "z", 0.38, LILAC, (1.15, -0.25, 1.95), rot=(80, 0, 35))


def portions_model(root):
    """The ride's snack bar and drink, as the portraits show them, made big."""
    # The drink: a tall white cup, a blue band under the rim and a yellow straw.
    cyl(root, 0.42, 0.34, 1.5, WHITE, (0.35, 0.2, 0.75), verts=24, bevel=0.02)
    cyl(root, 0.435, 0.43, 0.2, BLUE, (0.35, 0.2, 1.32), verts=24, bevel=0.01)
    cyl(root, 0.45, 0.45, 0.08, WHITE, (0.35, 0.2, 1.53), verts=24, bevel=0.02)
    cyl(root, 0.05, 0.05, 0.75, YELLOW, (0.42, 0.2, 1.85), rot=(0, 12, 0), verts=8, bevel=0)
    # The snack: a bar upright, its top bare and the rest in a pink wrapper.
    box(root, (0.5, 0.26, 1.05), PINK, (-0.4, -0.25, 0.53), rot=(0, 0, 15), bevel=0.04)
    box(root, (0.46, 0.22, 0.35), BROWN, (-0.4, -0.25, 1.2), rot=(0, 0, 15), bevel=0.06)
    box(root, (0.54, 0.3, 0.06), lin("#ffb3cc"), (-0.4, -0.25, 1.04), rot=(0, 0, 15), bevel=0.02)


def bell_model(root):
    """A door bell swung out mid-ring."""
    root.rotation_euler = (0, math.radians(18), 0)
    sphere(root, 0.32, GOLD, (0, 0, 1.72), scale=(1, 1, 0.9), segments=24)
    cyl(root, 0.62, 0.33, 0.75, GOLD, (0, 0, 1.35), verts=28, bevel=0.03)
    cyl(root, 0.68, 0.68, 0.1, YELLOW, (0, 0, 0.95), verts=28, bevel=0.04)
    sphere(root, 0.14, DARK, (0.12, 0, 0.82), segments=12)


def lounge_model(root):
    """A plush three-seat sofa."""
    box(root, (2.2, 0.95, 0.42), LILAC, (0, 0, 0.36), bevel=0.08)
    box(root, (2.2, 0.28, 0.85), LILAC, (0, 0.34, 0.9), bevel=0.1)
    for x in (-1.2, 1.2):
        box(root, (0.28, 0.95, 0.72), LILAC, (x, 0, 0.5), bevel=0.1)
    for x in (-0.68, 0.0, 0.68):
        rounded(root, (0.66, 0.78, 0.22), WHITE, (x, -0.06, 0.67))
        rounded(root, (0.62, 0.2, 0.55), WHITE, (x, 0.18, 1.05), rot=(-10, 0, 0))
    for x in (-1.15, 1.15):
        cyl(root, 0.06, 0.04, 0.16, DARK, (x, -0.3, 0.08), verts=8)
        cyl(root, 0.06, 0.04, 0.16, DARK, (x, 0.3, 0.08), verts=8)
    # Turned a little toward the camera, so it fills a square better.
    root.rotation_euler.z = math.radians(15)


def torus(root, major, minor, color, loc, rot=(0, 0, 0), segments=32, unlit=False):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=segments,
                                     minor_segments=12, location=loc,
                                     rotation=[math.radians(r) for r in rot])
    bpy.ops.object.shade_smooth()
    return add(bpy.context.object, root, color, unlit, bevel=0)


def warm_drive_model(root):
    """A drive nozzle, still glowing warm inside."""
    cyl(root, 0.62, 0.45, 0.9, DARK, (0, 0, 0.95), rot=(90, 0, 0), verts=24, bevel=0.04)
    torus(root, 0.6, 0.08, GREY, (0, -0.45, 0.95), rot=(90, 0, 0))
    cyl(root, 0.5, 0.5, 0.04, EMBER, (0, -0.44, 0.95), rot=(90, 0, 0), verts=24, bevel=0, unlit=True)
    cyl(root, 0.26, 0.26, 0.04, YELLOW, (0, -0.46, 0.95), rot=(90, 0, 0), verts=24, bevel=0, unlit=True)


def fuel_forecast_model(root):
    """A fuel gauge: its needle reads how much the course will burn."""
    face = bpy.data.objects.new("Face", None)
    bpy.context.scene.collection.objects.link(face)
    face.parent = root
    face.location = (0, 0, 0.9)
    face.rotation_euler = (math.radians(75), 0, 0)
    cyl(face, 0.85, 0.85, 0.16, DARK, (0, 0, 0), verts=32, bevel=0.04)
    cyl(face, 0.72, 0.72, 0.06, WHITE, (0, 0, 0.1), verts=32, bevel=0.01)
    # The used part of the tank, in low fuel's red, and what's left, in fuel's cyan.
    box(face, (0.36, 0.14, 0.04), RED, (-0.42, 0.22, 0.14), rot=(0, 0, 40), bevel=0.02, unlit=True)
    box(face, (0.36, 0.14, 0.04), CYAN, (0.42, 0.22, 0.14), rot=(0, 0, -40), bevel=0.02, unlit=True)
    box(face, (0.08, 0.62, 0.05), DARK, (0.14, 0.2, 0.17), rot=(0, 0, -25), bevel=0.02)
    cyl(face, 0.1, 0.1, 0.08, DARK, (0, 0, 0.18), verts=16)


def pumps_model(root):
    """A station's fuel pump with its nozzle on the side."""
    box(root, (0.9, 0.6, 1.7), WHITE, (0, 0, 0.85), bevel=0.08)
    box(root, (0.6, 0.06, 0.4), CYAN, (0, -0.3, 1.3), bevel=0.03, unlit=True)
    box(root, (1.1, 0.8, 0.14), DARK, (0, 0, 0.07), bevel=0.04)
    box(root, (0.22, 0.3, 0.55), DARK, (0.56, -0.05, 0.85), bevel=0.05)


def movies_model(root):
    """A fold-down cabin screen, as on a plane, showing a play button."""
    box(root, (1.8, 0.16, 1.2), DARK, (0, 0, 1.1), bevel=0.06)
    box(root, (1.6, 0.05, 1.0), BLUE, (0, -0.07, 1.1), bevel=0.02, unlit=True)
    cyl(root, 0.32, 0.32, 0.04, WHITE, (0.04, -0.11, 1.1), rot=(90, 90, 0), verts=3, bevel=0, unlit=True)
    # The hinge it hangs from, at its top edge.
    cyl(root, 0.08, 0.08, 1.0, GREY, (0, 0.04, 1.76), rot=(0, 90, 0), verts=12, bevel=0.01)


def quick_hands_model(root):
    """A serving tray under a domed cloche."""
    cyl(root, 1.0, 1.0, 0.08, GREY, (0, 0, 0.1), verts=32, bevel=0.03)
    sphere(root, 0.78, WHITE, (0, 0, 0.14), scale=(1, 1, 0.85), segments=32)
    sphere(root, 0.12, GREY, (0, 0, 0.84), segments=16)


def tip_jar_model(root):
    """A glass jar full of gold coins, one more dropping in."""
    cyl(root, 0.55, 0.55, 1.2, GLASS, (0, 0, 0.6), verts=24, bevel=0.1)
    cyl(root, 0.5, 0.5, 0.08, DARK, (0, 0, 1.22), verts=24, bevel=0.02)
    for x, z, tilt in ((-0.18, 1.36, 20), (0.2, 1.38, -15)):
        cyl(root, 0.3, 0.3, 0.08, GOLD, (x, 0, z), rot=(tilt, 70, 0), verts=24, bevel=0.02)
    cyl(root, 0.3, 0.3, 0.08, GOLD, (0.2, 0, 2.0), rot=(0, 70, 20), verts=24, bevel=0.02)


def coffee_model(root):
    """A mug of coffee on its saucer."""
    cyl(root, 0.8, 0.7, 0.08, WHITE, (0, 0, 0.04), verts=32, bevel=0.02)
    cyl(root, 0.5, 0.44, 0.9, WHITE, (0, 0, 0.53), verts=28, bevel=0.04)
    cyl(root, 0.44, 0.44, 0.04, COFFEE, (0, 0, 0.96), verts=28, bevel=0)
    torus(root, 0.26, 0.08, WHITE, (0.52, 0, 0.55), rot=(90, 0, 0))


def timetables_model(root):
    """A departures board: rows of times on a dark panel, on a post."""
    box(root, (0.14, 0.14, 1.2), GREY, (0, 0.1, 0.6), bevel=0.03)
    box(root, (1.7, 0.14, 1.1), DARK, (0, 0, 1.45), bevel=0.06)
    for i, color in enumerate((YELLOW, WHITE, WHITE)):
        z = 1.75 - i * 0.3
        box(root, (0.9, 0.04, 0.14), color, (-0.25, -0.08, z), bevel=0.02, unlit=True)
        box(root, (0.3, 0.04, 0.14), CYAN, (0.5, -0.08, z), bevel=0.02, unlit=True)


def placeholder_model(root):
    """A wrapped box with a bow: the picture for an upgrade with no icon of its own yet."""
    box(root, (1.2, 1.2, 0.95), LILAC, (0, 0, 0.48), bevel=0.05)
    box(root, (1.32, 1.32, 0.26), PALE_LILAC, (0, 0, 1.05), bevel=0.05)
    # The ribbon round it, both ways, over the lid.
    box(root, (0.22, 1.36, 1.3), WHITE, (0, 0, 0.66), bevel=0.02)
    box(root, (1.36, 0.22, 1.3), WHITE, (0, 0, 0.66), bevel=0.02)
    torus(root, 0.28, 0.1, WHITE, (-0.24, 0, 1.36), rot=(90, 0, -25))
    torus(root, 0.28, 0.1, WHITE, (0.24, 0, 1.36), rot=(90, 0, 25))


# How much longer and fatter the exhaust is than in flight.
FLAME_LENGTH = 2.4
FLAME_WIDTH = 2.0


def bus_model(root):
    bpy.ops.import_scene.gltf(filepath=BUS_GLB)
    # The glb's collision box, which would draw as a plain box over the bus.
    for o in [o for o in bpy.context.scene.objects if "colonly" in o.name]:
        bpy.data.objects.remove(o)
    for o in [o for o in bpy.context.scene.objects if o.parent is None and o.name != "Root"]:
        o.parent = root
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in meshes:
        for slot in o.material_slots:
            m = slot.material
            bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
            color = tuple(bsdf.inputs["Base Color"].default_value)[:3] if bsdf else (0.8, 0.8, 0.8)
            m["base"] = list(CYAN if "Glow" in o.name else color)
            m["unlit"] = "Glow" in o.name
    bpy.context.view_layer.update()
    # The bus's own exhaust, longer and fatter than in flight, so the icon reads as speed.
    # Both nozzles' cones are one object with its origin at the nozzles. Split into one
    # per nozzle, each with its origin on its own nozzle, so each stretches along the bus
    # (Blender's Y, from the glTF's Z) and fattens in place.
    glow = next(o for o in meshes if "Glow" in o.name)
    nozzle_y = glow.matrix_world.translation.y
    bpy.ops.object.select_all(action="DESELECT")
    glow.select_set(True)
    bpy.context.view_layer.objects.active = glow
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    for cone in list(bpy.context.selected_objects):
        box = [cone.matrix_world @ Vector(c) for c in cone.bound_box]
        center = sum(box, Vector()) / 8
        bpy.context.scene.cursor.location = (center.x, nozzle_y, center.z)
        bpy.ops.object.select_all(action="DESELECT")
        cone.select_set(True)
        bpy.context.view_layer.objects.active = cone
        bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
        cone.scale = (FLAME_WIDTH, FLAME_LENGTH, FLAME_WIDTH)
    # Nose toward the viewer and a little left, so it fills a square and shows the flame.
    root.rotation_euler.z = math.radians(-25)


def frame():
    scene = bpy.context.scene
    bpy.context.view_layer.update()
    rot = (-VIEW_DIR).to_track_quat("-Z", "Y")
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    inv = rot.to_matrix().inverted()
    pts = []
    for o in scene.objects:
        if o.type == "MESH":
            pts += [inv @ (o.matrix_world @ Vector(c)) for c in o.bound_box]
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    cam_data.ortho_scale = max(hi.x - lo.x, hi.y - lo.y) * 1.22
    cam.location = rot.to_matrix() @ ((lo + hi) / 2) + VIEW_DIR * 30
    cam.rotation_euler = rot.to_euler()
    cam_data.clip_end = 100
    # Sun from the upper left of the view, in view space, as the planet icons.
    light_dir = (rot.to_matrix() @ Vector((-0.6, 0.8, 0.5))).normalized()
    sun_data = bpy.data.lights.new("Sun", "SUN")
    sun_data.energy = math.pi
    sun_data.use_shadow = False
    sun = bpy.data.objects.new("Sun", sun_data)
    scene.collection.objects.link(sun)
    sun.rotation_euler = (-light_dir).to_track_quat("-Z", "Y").to_euler()


def two_tone(m):
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emit = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(emit.outputs[0], out.inputs[0])
    base = tuple(m["base"]) + (1.0,)
    if m["unlit"]:
        emit.inputs["Color"].default_value = base
        return
    diff = nt.nodes.new("ShaderNodeBsdfDiffuse")
    diff.inputs["Color"].default_value = (1, 1, 1, 1)
    s2r = nt.nodes.new("ShaderNodeShaderToRGB")
    nt.links.new(diff.outputs[0], s2r.inputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    dark, lit = ramp.color_ramp.elements
    dark.position, dark.color = 0.0, (*SHADOW, 1)
    lit.position, lit.color = 0.004, (1, 1, 1, 1)
    nt.links.new(s2r.outputs["Color"], ramp.inputs["Fac"])
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs["Factor"].default_value = 1.0
    nt.links.new(ramp.outputs["Color"], mul.inputs[6])
    mul.inputs[7].default_value = base
    nt.links.new(mul.outputs[2], emit.inputs["Color"])


# Each icon by its file name, the upgrade it is for, and the model it renders.
ICONS = {
    "speed": bus_model,
    "fuel_tank": fuel_tank_model,
    "warmer_drive": warm_drive_model,
    "fuel_forecast": fuel_forecast_model,
    "faster_pumps": pumps_model,
    "extra_seat": seat_model,
    "pillows": pillow_model,
    "bigger_portions": portions_model,
    "in_flight_movies": movies_model,
    "quick_hands": quick_hands_model,
    "door_chime": bell_model,
    "station_waiting_lounge": lounge_model,
    "tip_jar": tip_jar_model,
    "free_station_coffee": coffee_model,
    "timetables": timetables_model,
    "station_cameras": camera_model,
    "placeholder": placeholder_model,
}
for icon in ONLY or list(ICONS):
    root = reset()
    ICONS[icon](root)
    frame()
    for m in bpy.data.materials:
        if "base" in m:
            two_tone(m)
    bpy.context.scene.render.filepath = str(OUT / f"{icon}.png")
    bpy.ops.render.render(write_still=True)
