"""Mossy garden tree (twisting trunk, root flare, curving branches, leaf-card canopy).

Run headless:   Blender -b -P tools/blender/build_tree.py
Or via the Blender MCP: exec(open('<repo>/tools/blender/build_tree.py').read(), {'__name__': '__main__'})
Exports assets/props/garden_tree.glb (static). Material names matter for Godot:
"Bark" -> mossy bark shader, "Leaves" -> alpha-scissor leaf cards with wind sway.
Leaf cards carry vertex colour R = sway weight (0 at the branch, 1 at the tip).
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
OUT = os.path.join(ROOT, "assets", "props", "garden_tree.glb")
random.seed(42)

scene = bpy.data.scenes.get("TreeBuild") or bpy.data.scenes.new("TreeBuild")
for ob in list(scene.objects):
    bpy.data.objects.remove(ob, do_unlink=True)
if bpy.context.window:
    bpy.context.window.scene = scene


def mat(name, color):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*color, 1)
    return m


BARK = mat("Bark", (0.35, 0.27, 0.18))
LEAVES = mat("Leaves", (0.2, 0.55, 0.15))

bm = bmesh.new()
col_layer = bm.loops.layers.color.new("Col")
uv_layer = bm.loops.layers.uv.new("UVMap")
SIDES = 9


def frame(t):
    """Orthonormal frame perpendicular to tangent t."""
    up = Vector((0, 0, 1)) if abs(t.z) < 0.95 else Vector((1, 0, 0))
    a = t.cross(up).normalized()
    b = t.cross(a).normalized()
    return a, b


def tube(points, radii, flare=None):
    """Skin a polyline with rings; returns nothing (adds to bm, material 0)."""
    rings = []
    for i, p in enumerate(points):
        t = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
        a, b = frame(t)
        ring = []
        for k in range(SIDES):
            ang = k / SIDES * math.tau
            r = radii[i] * (1.0 + 0.12 * math.sin(ang * 3 + i))  # gnarly, not round
            if flare and i == 0:
                r *= 1.0 + flare * (0.6 + 0.4 * math.sin(ang * 4))
            ring.append(bm.verts.new(p + (a * math.cos(ang) + b * math.sin(ang)) * r))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(SIDES):
            f = bm.faces.new((rings[i][k], rings[i][(k + 1) % SIDES], rings[i + 1][(k + 1) % SIDES], rings[i + 1][k]))
            f.material_index = 0
            for li, loop in enumerate(f.loops):
                loop[uv_layer].uv = ((k + (1 if li in (1, 2) else 0)) / SIDES, (i + (1 if li >= 2 else 0)) * 0.25)
                loop[col_layer] = (0, 0, 0, 1)


def curve(start, direction, length, segs, bend, rise):
    pts = [start.copy()]
    d = direction.normalized()
    p = start.copy()
    for i in range(segs):
        jitter = Vector((random.random() - 0.5, random.random() - 0.5, random.random() - 0.5)) * bend
        d = (d + jitter + Vector((0, 0, rise))).normalized()
        p = p + d * (length / segs)
        pts.append(p.copy())
    return pts


def leaf_card(center, size, tilt, stretch=0.9):
    """Two crossed quads; vertex colour R is the sway weight. stretch > 1 = hanging strand."""
    for rot in (0.0, math.pi * 0.5):
        m = Matrix.Rotation(tilt[2] + rot, 4, "Z") @ Matrix.Rotation(tilt[0], 4, "X")
        hw = size * 0.5
        hh = hw * stretch
        corners = [Vector((-hw, 0, -hh * 1.6 + hh * 0.6)), Vector((hw, 0, -hh * 1.6 + hh * 0.6)), Vector((hw, 0, hh * 0.6)), Vector((-hw, 0, hh * 0.6))]
        vs = [bm.verts.new(center + m @ c) for c in corners]
        f = bm.faces.new(vs)
        f.material_index = 1
        for li, loop in enumerate(f.loops):
            loop[uv_layer].uv = [(0, 1), (1, 1), (1, 0), (0, 0)][li]
            # Hanging (willow-ish): lower corners sway more.
            loop[col_layer] = (1.0 if li < 2 else 0.45, 0, 0, 1)


# Trunk: leans toward +X/-Y (over the pool), twists, flares into roots.
trunk = curve(Vector((0, 0, -0.2)), Vector((0.3, -0.12, 1)), 6.2, 12, 0.3, 0.12)
tube(trunk, [0.9 - 0.052 * i for i in range(len(trunk))], flare=1.1)
# Surface roots.
for k in range(6):
    ang = k / 6 * math.tau + 0.4
    d = Vector((math.cos(ang), math.sin(ang), -0.2))
    pts = curve(Vector((0, 0, 0.45)), d, 2.4, 5, 0.25, -0.06)
    tube(pts, [0.3, 0.24, 0.17, 0.11, 0.06, 0.02])

# Branches from the upper trunk, arching out then drooping.
tips = []
for k in range(8):
    idx = random.randint(7, len(trunk) - 2)
    base = trunk[idx]
    ang = k / 8 * math.tau + random.uniform(-0.3, 0.3)
    d = Vector((math.cos(ang), math.sin(ang), random.uniform(0.25, 0.6)))
    length = random.uniform(2.6, 3.8)
    pts = curve(base, d, length, 6, 0.4, -0.06)
    tube(pts, [0.26 * (1 - j / 7) + 0.03 for j in range(len(pts))])
    tips.extend(pts[2:])
    # Twigs.
    for j in (3, 5):
        if j < len(pts):
            tw = curve(pts[j], d + Vector((random.uniform(-1, 1), random.uniform(-1, 1), 0.3)), 1.2, 3, 0.5, -0.1)
            tube(tw, [0.07, 0.05, 0.03, 0.015])
            tips.extend(tw[1:])
# Crown continuation of the trunk.
crown = curve(trunk[-1], Vector((0.1, 0.1, 1)), 1.5, 3, 0.3, 0.1)
tube(crown, [0.2, 0.15, 0.1, 0.05])
tips.extend(crown[1:])

# Canopy: leaf cards clustered around branch points, drooping.
cards = 0
for p in tips:
    if p.z < 5.0:
        continue  # keep the trunk readable: canopy starts high
    for n in range(5):
        c = p + Vector((random.uniform(-0.8, 0.8), random.uniform(-0.8, 0.8), random.uniform(-0.4, 0.5)))
        leaf_card(c, random.uniform(1.2, 1.8), (random.uniform(-0.3, 0.3), 0, random.uniform(0, math.tau)))
        cards += 1
    # Willow-like hanging strands.
    for n in range(2):
        c = p + Vector((random.uniform(-0.5, 0.5), random.uniform(-0.5, 0.5), -0.2))
        leaf_card(c, random.uniform(0.6, 0.9), (0.0, 0, random.uniform(0, math.tau)), stretch=random.uniform(2.6, 3.6))
        cards += 1

me = bpy.data.meshes.new("GardenTree")
bm.to_mesh(me)
bm.free()
me.materials.append(BARK)
me.materials.append(LEAVES)
ob = bpy.data.objects.new("GardenTree", me)
scene.collection.objects.link(ob)
for p in me.polygons:
    p.use_smooth = p.material_index == 0

os.makedirs(os.path.dirname(OUT), exist_ok=True)
for o in scene.objects:
    o.select_set(o == ob)
bpy.context.view_layer.objects.active = ob
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_apply=True,
                          export_yup=True, export_animations=False, export_vertex_color="ACTIVE")
zs = [v.co.z for v in me.vertices]
xs = [v.co.x for v in me.vertices]
ys = [v.co.y for v in me.vertices]
rep = {"verts": len(me.vertices), "faces": len(me.polygons), "cards": cards,
       "size": [max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)], "out": OUT}
with open("/tmp/tree_build.json", "w") as f:
    json.dump(rep, f)
print("BUILD_TREE_OK", rep)
