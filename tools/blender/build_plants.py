"""Lush leaf-card vegetation replacing the pastel Kenney plants (video look).

Run headless:   Blender -b -P tools/blender/build_plants.py
Or via the Blender MCP: exec(open('<repo>/tools/blender/build_plants.py').read(), {'__name__': '__main__'})
Exports assets/props/plants.glb with meshes:
  Palm, PalmBend, PalmShort, TreeFern, Fern, Monstera, Grass
Built in metres, base at the origin, Z-up. Godot rescales each to the Kenney
model it replaces (so existing scatter scales keep working).
Materials: "Trunk", "Frond" (pinnate frond cards), "Broad" (split broad leaves),
"Grass" (blade cards). UVs: U across the card, V along it (0 at the base).
Vertex colour R = sway weight (0 at the base, 1 at frond tips).
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
OUT = os.path.join(ROOT, "assets", "props", "plants.glb")
random.seed(11)

scene = bpy.data.scenes.get("PlantBuild") or bpy.data.scenes.new("PlantBuild")
for ob in list(scene.objects):
    bpy.data.objects.remove(ob, do_unlink=True)
if bpy.context.window:
    bpy.context.window.scene = scene


def mat(name, color):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*color, 1)
    return m


MATS = [mat("Trunk", (0.42, 0.33, 0.22)), mat("Frond", (0.2, 0.5, 0.12)), mat("Broad", (0.15, 0.45, 0.1)), mat("Grass", (0.3, 0.6, 0.15))]
TRUNK, FROND, BROAD, GRASS = 0, 1, 2, 3


class Builder:
    def __init__(self):
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.color.new("Col")
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def face(self, vs, uvs, ws, mi):
        f = self.bm.faces.new([self.bm.verts.new(v) for v in vs])
        f.material_index = mi
        for i, loop in enumerate(f.loops):
            loop[self.uv].uv = uvs[i]
            loop[self.col] = (ws[i], 0, 0, 1)

    def trunk(self, pts, radii, sides=8, sway_top=0.12):
        rings = []
        for i, p in enumerate(pts):
            t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
            up = Vector((0, 0, 1)) if abs(t.z) < 0.95 else Vector((1, 0, 0))
            a = t.cross(up).normalized()
            b = t.cross(a).normalized()
            # Ringed palm trunk: every other ring slightly fatter.
            r = radii[i] * (1.08 if i % 2 else 0.96)
            rings.append([p + (a * math.cos(k / sides * math.tau) + b * math.sin(k / sides * math.tau)) * r for k in range(sides)])
        n = len(rings)
        for i in range(n - 1):
            w0 = sway_top * i / (n - 1)
            w1 = sway_top * (i + 1) / (n - 1)
            for k in range(sides):
                k2 = (k + 1) % sides
                self.face([rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]],
                          [(k / sides, i / n), ((k + 1) / sides, i / n), ((k + 1) / sides, (i + 1) / n), (k / sides, (i + 1) / n)],
                          [w0, w0, w1, w1], TRUNK)

    def frond(self, base, direction, length, width, droop, segs=7, mi=FROND, twist=0.0):
        """Arching card strip: rises, then droops under its own weight."""
        d = Vector((direction.x, direction.y, 0)).normalized()
        side = Vector((-d.y, d.x, 0))
        lift = direction.z
        pts = []
        for i in range(segs + 1):
            t = i / segs
            pts.append(base + d * length * t + Vector((0, 0, length * (lift * t - droop * t * t))))
        for i in range(segs):
            t0, t1 = i / segs, (i + 1) / segs
            w0 = width * (0.35 + math.sin(min(t0 * 1.15, 1.0) * math.pi) * 0.65) * 0.5
            w1 = width * (0.35 + math.sin(min(t1 * 1.15, 1.0) * math.pi) * 0.65) * 0.5
            # Fronds fold slightly along the rib (V-shape) so they read from the side too.
            fold0 = Vector((0, 0, w0 * 0.25))
            fold1 = Vector((0, 0, w1 * 0.25))
            s0 = side * w0
            s1 = side * w1
            p0, p1 = pts[i], pts[i + 1]
            self.face([p0 - s0 + fold0, p0, p1, p1 - s1 + fold1], [(0, t0), (0.5, t0), (0.5, t1), (0, t1)], [t0, t0, t1, t1], mi)
            self.face([p0, p0 + s0 + fold0, p1 + s1 + fold1, p1], [(0.5, t0), (1, t0), (1, t1), (0.5, t1)], [t0, t0, t1, t1], mi)

    def card(self, base, height, width, yaw, tilt, mi, sway=1.0):
        rot = Matrix.Rotation(yaw, 3, "Z") @ Matrix.Rotation(tilt, 3, "X")
        hw = width * 0.5
        c = [rot @ Vector(v) for v in ((-hw, 0, 0), (hw, 0, 0), (hw, 0, height), (-hw, 0, height))]
        self.face([base + v for v in c], [(0, 0), (1, 0), (1, 1), (0, 1)], [0, 0, sway, sway], mi)

    def finish(self, name):
        me = bpy.data.meshes.new(name)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in MATS:
            me.materials.append(m)
        ob = bpy.data.objects.new(name, me)
        scene.collection.objects.link(ob)
        return ob


def palm(name, height, lean, fronds=11, frond_len=3.4):
    b = Builder()
    segs = 14
    pts = []
    for i in range(segs + 1):
        t = i / segs
        # Coconut palms curve: lean grows toward the top.
        pts.append(Vector((lean * t * t * height, 0, height * t)))
    b.trunk(pts, [0.26 - 0.1 * (i / segs) for i in range(segs + 1)])
    top = pts[-1]
    for k in range(fronds):
        ang = k / fronds * math.tau + random.uniform(-0.2, 0.2)
        rise = random.uniform(0.15, 0.6)
        b.frond(top, Vector((math.cos(ang), math.sin(ang), rise)), frond_len * random.uniform(0.85, 1.1), 1.1, random.uniform(0.7, 1.1))
    # A few young fronds pointing up.
    for k in range(3):
        ang = random.uniform(0, math.tau)
        b.frond(top, Vector((math.cos(ang), math.sin(ang), 1.6)), frond_len * 0.6, 0.8, 0.5)
    # Coconut cluster (small trunk-material blobs).
    for k in range(4):
        ang = k / 4 * math.tau
        c = top + Vector((math.cos(ang) * 0.25, math.sin(ang) * 0.25, -0.25))
        pts_c = [c + Vector((0, 0, -0.12)), c, c + Vector((0, 0, 0.12))]
        b.trunk(pts_c, [0.05, 0.13, 0.05], sides=6, sway_top=0.0)
    return b.finish(name)


def tree_fern(name):
    b = Builder()
    h = 3.0
    pts = [Vector((math.sin(i * 0.7) * 0.05, 0, h * i / 8)) for i in range(9)]
    b.trunk(pts, [0.2] * 9, sides=7, sway_top=0.05)
    for k in range(12):
        ang = k / 12 * math.tau
        b.frond(pts[-1], Vector((math.cos(ang), math.sin(ang), 0.55)), 2.3, 0.9, 1.0)
    return b.finish(name)


def fern(name):
    b = Builder()
    for k in range(10):
        ang = k / 10 * math.tau + random.uniform(-0.2, 0.2)
        b.frond(Vector((0, 0, 0.02)), Vector((math.cos(ang), math.sin(ang), random.uniform(0.9, 1.5))), random.uniform(1.0, 1.4), 0.55, 1.1, segs=6)
    return b.finish(name)


def monstera(name):
    b = Builder()
    for k in range(7):
        ang = k / 7 * math.tau + random.uniform(-0.3, 0.3)
        d = Vector((math.cos(ang), math.sin(ang), 0))
        stem_top = d * random.uniform(0.35, 0.6) + Vector((0, 0, random.uniform(0.8, 1.3)))
        b.trunk([Vector((0, 0, 0)), stem_top * 0.5 + Vector((0, 0, 0.1)), stem_top], [0.025, 0.022, 0.018], sides=5, sway_top=0.4)
        # Broad split leaf: one wide card tilted out and down from the stem top.
        b.frond(stem_top, Vector((d.x, d.y, 0.25)), random.uniform(0.75, 1.0), 0.9, 0.6, segs=3, mi=BROAD)
    return b.finish(name)


def grass(name):
    b = Builder()
    for k in range(14):
        yaw = random.uniform(0, math.tau)
        r = random.uniform(0.0, 0.25)
        base = Vector((math.cos(yaw) * r, math.sin(yaw) * r, 0))
        b.card(base, random.uniform(0.35, 0.6), random.uniform(0.25, 0.4), yaw, random.uniform(-0.35, 0.35), GRASS)
    return b.finish(name)


objs = [
    palm("Palm", 7.5, 0.18),
    palm("PalmBend", 6.5, 0.55),
    palm("PalmShort", 3.6, 0.12, fronds=9, frond_len=2.4),
    tree_fern("TreeFern"),
    fern("Fern"),
    monstera("Monstera"),
    grass("Grass"),
]
for i, o in enumerate(objs):
    o.location.x = i * 8.0


def _activate_colors(objs):
    """The glTF exporter only writes the *active* colour attribute; bmesh layers aren't active by default."""
    for o in objs:
        if o.type != "MESH":
            continue
        ca = o.data.color_attributes
        if "Col" in ca:
            ca.active_color_name = "Col"
            ca.render_color_index = ca.find("Col")

_activate_colors(objs)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
for o in scene.objects:
    o.select_set(o in objs)
bpy.context.view_layer.objects.active = objs[0]
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_apply=True,
                          export_yup=True, export_animations=False, export_vertex_color="ACTIVE")
rep = {o.name: [len(o.data.polygons), round(max(v.co.z for v in o.data.vertices), 2)] for o in objs}
rep["out"] = OUT
with open("/tmp/plants_build.json", "w") as f:
    json.dump(rep, f)
print("BUILD_PLANTS_OK", rep)
