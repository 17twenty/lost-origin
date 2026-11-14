"""Hanging vines / moss strands (3 variants) for ruins, cliffs and piers.

Run headless:   Blender -b -P tools/blender/build_vines.py
Or via the Blender MCP: exec(open('<repo>/tools/blender/build_vines.py').read(), {'__name__': '__main__'})
Exports assets/props/vines.glb with meshes Vine_A, Vine_B, Vine_C. Each hangs
from its origin (attachment point) down -Z (Godot -Y). Materials: "Vine" (stem)
and "Leaves" (alpha leaf cards). Vertex colour R = sway weight (0 at the
attachment, 1 at the tip) for the wind shader.
"""
import bpy
import bmesh
import json
import math
import os
import random
from mathutils import Vector, Matrix

try:
    ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
except NameError:
    ROOT = "/Users/nickglynn/Projects/lost-origin"
OUT = os.path.join(ROOT, "assets", "props", "vines.glb")
random.seed(7)

scene = bpy.data.scenes.get("VineBuild") or bpy.data.scenes.new("VineBuild")
for ob in list(scene.objects):
    bpy.data.objects.remove(ob, do_unlink=True)
if bpy.context.window:
    bpy.context.window.scene = scene


def mat(name, color):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*color, 1)
    return m


VINE = mat("Vine", (0.18, 0.3, 0.08))
LEAVES = mat("Leaves", (0.2, 0.55, 0.15))


def build(name, length, strands, leafiness, droop):
    bm = bmesh.new()
    col = bm.loops.layers.color.new("Col")
    uv = bm.loops.layers.uv.new("UVMap")

    def quad(vs, uvs, weights, mat_index):
        verts = [bm.verts.new(v) for v in vs]
        f = bm.faces.new(verts)
        f.material_index = mat_index
        for li, loop in enumerate(f.loops):
            loop[uv].uv = uvs[li]
            loop[col] = (weights[li], 0, 0, 1)

    for s in range(strands):
        L = length * random.uniform(0.6, 1.0)
        start = Vector((random.uniform(-0.25, 0.25), random.uniform(-0.25, 0.25), 0))
        segs = 10
        pts = []
        for i in range(segs + 1):
            t = i / segs
            # Hangs straight down with a lazy S-curve and slight outward droop.
            pts.append(start + Vector((math.sin(t * 3.1 + s) * 0.12 + droop * t * t, math.cos(t * 2.3 + s) * 0.08, -L * t)))
        # Stem: two crossed ribbons.
        for axis in (Vector((1, 0, 0)), Vector((0, 1, 0))):
            for i in range(segs):
                w0 = 0.035 * (1 - 0.5 * i / segs)
                w1 = 0.035 * (1 - 0.5 * (i + 1) / segs)
                a, b = pts[i], pts[i + 1]
                quad([a - axis * w0, a + axis * w0, b + axis * w1, b - axis * w1],
                     [(0, i / segs), (1, i / segs), (1, (i + 1) / segs), (0, (i + 1) / segs)],
                     [i / segs, i / segs, (i + 1) / segs, (i + 1) / segs], 0)
        # Leaf cards along the stem.
        n_leaves = int(segs * leafiness)
        for k in range(n_leaves):
            t = random.uniform(0.05, 1.0)
            idx = min(int(t * segs), segs - 1)
            p = pts[idx].lerp(pts[idx + 1], t * segs - idx)
            size = random.uniform(0.22, 0.38) * (1.15 - 0.5 * t)
            rot = Matrix.Rotation(random.uniform(0, math.tau), 3, "Z") @ Matrix.Rotation(random.uniform(-0.6, 0.6), 3, "X")
            hw = size * 0.5
            corners = [rot @ Vector(c) for c in ((-hw, 0, -hw), (hw, 0, -hw), (hw, 0, hw), (-hw, 0, hw))]
            quad([p + c for c in corners], [(0, 1), (1, 1), (1, 0), (0, 0)], [t] * 4, 1)
    # Moss tuft at the attachment point.
    for k in range(6):
        rot = Matrix.Rotation(k / 6 * math.tau, 3, "Z") @ Matrix.Rotation(0.9, 3, "X")
        hw = 0.28
        corners = [rot @ Vector(c) for c in ((-hw, 0, -hw * 1.4), (hw, 0, -hw * 1.4), (hw, 0, hw * 0.4), (-hw, 0, hw * 0.4))]
        quad([c for c in corners], [(0, 1), (1, 1), (1, 0), (0, 0)], [0.05] * 4, 1)

    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(VINE)
    me.materials.append(LEAVES)
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    return ob


objs = [
    build("Vine_A", 2.6, 3, 1.4, 0.15),   # medium cluster
    build("Vine_B", 4.2, 2, 1.1, 0.3),    # long trailing
    build("Vine_C", 1.4, 5, 1.8, 0.05),   # short dense moss curtain
]
for i, o in enumerate(objs):
    o.location.x = i * 2.0  # spread out for inspection; Godot reads mesh data only

os.makedirs(os.path.dirname(OUT), exist_ok=True)
for o in scene.objects:
    o.select_set(o in objs)
bpy.context.view_layer.objects.active = objs[0]
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_apply=True,
                          export_yup=True, export_animations=False, export_vertex_color="ACTIVE")
rep = {o.name: len(o.data.polygons) for o in objs}
rep["out"] = OUT
with open("/tmp/vines_build.json", "w") as f:
    json.dump(rep, f)
print("BUILD_VINES_OK", rep)
