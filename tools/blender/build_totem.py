"""Carved ruin totem (stacked blocks, carved face, glowing eye slits, finned crown).

Run headless:   Blender -b -P tools/blender/build_totem.py
Or via the Blender MCP:  exec(open('<repo>/tools/blender/build_totem.py').read())
Exports assets/props/totem.glb (static, Z-up -> Y-up). Material names matter:
"Stone" is swapped for the mossy_stone shader in Godot, "Glow" stays emissive.
"""
import bpy
import json
import math
import os

try:
    ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
except NameError:  # exec() via MCP has no __file__
    ROOT = "/Users/nickglynn/Projects/lost-origin"
OUT = os.path.join(ROOT, "assets", "props", "totem.glb")

# Work in a fresh scene so we don't disturb whatever is open in the GUI session.
scene = bpy.data.scenes.get("TotemBuild") or bpy.data.scenes.new("TotemBuild")
for ob in list(scene.objects):
    bpy.data.objects.remove(ob, do_unlink=True)
if bpy.context.window:
    bpy.context.window.scene = scene
coll = scene.collection


def mat(name, color, rough=0.8, emit=None, strength=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = strength
    return m


STONE = mat("Stone", (0.55, 0.53, 0.48))
GLOW = mat("Glow", (0.2, 0.95, 1.0), 0.2, (0.2, 0.95, 1.0), 8.0)
parts = []


def box(loc, size, m=STONE, rot=(0, 0, 0), bevel=0.04, taper=None):
    import bmesh
    me = bpy.data.meshes.new("p")
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
        if taper and v.co.z > 0:  # shrink top face
            v.co.x *= taper
            v.co.y *= taper
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("p", me)
    coll.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = rot
    me.materials.append(m)
    if bevel:
        mod = ob.modifiers.new("b", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        mod.limit_method = "ANGLE"
    parts.append(ob)
    return ob


# Front faces -Y (Godot +Z). Total height ~5.2 m.
box((0, 0, 0.25), (1.6, 1.6, 0.5), bevel=0.08)                     # plinth
box((0, 0, 0.55), (1.3, 1.3, 0.15))                                # step
box((0, 0, 1.25), (1.1, 1.0, 1.3), taper=0.9)                      # lower body
for sx in (-1, 1):                                                 # carved side ribs
    box((sx * 0.56, 0, 1.25), (0.08, 0.7, 1.1))
box((0, -0.5, 1.1), (0.5, 0.06, 0.7), GLOW, bevel=0)               # lower glyph strip (inset)
box((0, -0.52, 1.1), (0.62, 0.05, 0.82), bevel=0.01)               # glyph frame
box((0, 0, 2.0), (1.25, 1.15, 0.22))                               # collar
# Head block with carved face
box((0, 0, 2.75), (1.2, 1.1, 1.3), bevel=0.06)
box((0, -0.58, 3.12), (1.15, 0.2, 0.18))                           # brow ridge
for sx in (-1, 1):
    box((sx * 0.28, -0.56, 2.9), (0.3, 0.06, 0.16), GLOW, bevel=0)     # eye slits
    box((sx * 0.28, -0.6, 2.82), (0.36, 0.08, 0.06))                   # cheek lid under eye
box((0, -0.62, 2.7), (0.16, 0.14, 0.45), taper=0.7)                # nose ridge
box((0, -0.57, 2.3), (0.6, 0.06, 0.1), GLOW, bevel=0)              # mouth slot glow
box((0, -0.6, 2.22), (0.75, 0.1, 0.08))                            # jaw
# Crown with forward-swept fins
box((0, 0, 3.55), (1.0, 0.95, 0.3), taper=0.85)
for sx in (-1, 1):
    box((sx * 0.62, 0.05, 3.85), (0.16, 0.8, 0.9), rot=(0, sx * -0.35, 0), taper=0.5)
box((0, 0.08, 4.0), (0.22, 0.9, 0.7), taper=0.4)                   # centre crest
box((0, -0.38, 3.72), (0.1, 0.04, 0.22), GLOW, bevel=0)            # crown gem

bpy.ops.object.select_all(action="DESELECT")
for p in parts:
    p.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
for p in parts:
    bpy.context.view_layer.objects.active = p
    for m in list(p.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
totem = bpy.context.active_object
totem.name = "Totem"
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.ops.object.shade_flat()

os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.object.select_all(action="DESELECT")
totem.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True,
                          export_apply=True, export_yup=True, export_animations=False)
zs = [v.co.z for v in totem.data.vertices]
rep = {"verts": len(totem.data.vertices), "height": max(zs) - min(zs), "out": OUT}
with open("/tmp/totem_build.json", "w") as f:
    json.dump(rep, f)
print("BUILD_TOTEM_OK", rep)
