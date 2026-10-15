"""Creates an empty model library with scale references. Args after --: <out.blend>."""

import sys

import bpy

out = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_homefile(use_empty=True, use_factory_startup=True)
reference = bpy.data.collections.new("reference")
bpy.context.scene.collection.children.link(reference)
# A 1 m cube and a 1.7 m person-sized post, left of where the models go. Never exported.
for name, size, x in [("Reference1m", (1.0, 1.0, 1.0), -2.0), ("ReferencePerson", (0.4, 0.25, 1.7), -3.5)]:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, 0.0, size[2] / 2))
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for old in obj.users_collection:
        old.objects.unlink(obj)
    reference.objects.link(obj)
bpy.ops.wm.save_as_mainfile(filepath=out)
assert sorted(o.name for o in bpy.data.objects) == ["Reference1m", "ReferencePerson"]
