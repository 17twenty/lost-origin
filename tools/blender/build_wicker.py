"""The Wicker Man: summoned woven protector (player character).

Design: wicker-inspo/turn-around-final.png (front/back). Heroic ~2.1 m build,
domed woven pauldrons, braided bands at waist/knees/ankles/wrists, woven
codpiece, wild straw mane and beard (alpha strand cards), woven face mask with
brow and nose (original face, not any actor's likeness), faint amber eyes.

Run headless:   Blender -b -P tools/blender/build_wicker.py
Or via the Blender MCP: exec(open('<repo>/tools/blender/build_wicker.py').read(), {'__name__': '__main__'})
Exports assets/characters/wicker.glb (+ src/wicker.blend). Z-up, front = -Y.
GLB pipeline rules: skin/subsurf applied manually, export_apply=False.

Materials (Godot remaps by name): Wicker (body weave), Band (braids/plates),
Straw (hair cards, alpha), Eye (amber glow).
UV0: per-region cylindrical coords in metres (U around the bone, V along it) so
the procedural weave follows the limbs. UV1 ("UV2" in Godot): x = weave order
0 (feet) -> 1 (crown) with a per-limb spiral offset, for the weave-in intro.
Vertex colour R: sway weight for straw cards (0 at the root, 1 at the tip).
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
OUT_GLB = os.path.join(ROOT, "assets", "characters", "wicker.glb")
OUT_BLEND = os.path.join(ROOT, "assets", "characters", "src", "wicker.blend")
FPS = 30
HEIGHT = 2.12
random.seed(2026)

scene = bpy.data.scenes.get("WickerBuild") or bpy.data.scenes.new("WickerBuild")
for ob in list(scene.objects):
    bpy.data.objects.remove(ob, do_unlink=True)
if bpy.context.window:
    bpy.context.window.scene = scene
scene.render.fps = FPS
col = scene.collection
# Re-runs in a live GUI session: drop actions from previous builds (else exports gain "idle.001" etc).
for a in list(bpy.data.actions):
    if a.name.split(".")[0] in ("idle", "walk", "run", "sprint", "jump", "fall", "land", "swim", "interact", "look_around", "summon"):
        bpy.data.actions.remove(a)


def material(name, color, emit=None):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = 4.0
    return m


MATS = {
    "Wicker": material("Wicker", (0.55, 0.4, 0.22)),
    "Band": material("Band", (0.45, 0.32, 0.17)),
    "Straw": material("Straw", (0.68, 0.55, 0.33)),
    "Eye": material("Eye", (1.0, 0.6, 0.15), (1.0, 0.55, 0.1)),
}
MAT_ORDER = ["Wicker", "Band", "Straw", "Eye"]

# ------------------------------------------------------------------ skeleton
L, R = 1, -1
J = {  # joint positions (x, y, z); front is -Y
    "root": (0, 0, 0), "pelvis": (0, 0, 1.02), "waist": (0, 0.01, 1.2), "chest": (0, 0, 1.48),
    "neck": (0, 0.01, 1.76), "head": (0, 0.0, 1.88), "crown": (0, 0.01, HEIGHT),
    "mane0": (0, 0.06, 2.04), "mane1": (0, 0.24, 1.86), "beard0": (0, -0.1, 1.9), "beard1": (0, -0.15, 1.72),
}
for s, sx in (("L", L), ("R", R)):
    J[f"clav.{s}"] = (sx * 0.08, 0, 1.68)
    J[f"shoulder.{s}"] = (sx * 0.38, 0.01, 1.67)
    J[f"elbow.{s}"] = (sx * 0.5, 0.03, 1.35)
    J[f"wrist.{s}"] = (sx * 0.56, 0.0, 1.05)
    J[f"hand.{s}"] = (sx * 0.585, -0.01, 0.96)
    J[f"tip.{s}"] = (sx * 0.595, -0.02, 0.86)
    J[f"thumb0.{s}"] = (sx * 0.57, -0.035, 1.02)
    J[f"thumb1.{s}"] = (sx * 0.58, -0.085, 0.95)
    J[f"hip.{s}"] = (sx * 0.13, 0, 1.0)
    J[f"knee.{s}"] = (sx * 0.15, -0.025, 0.58)
    J[f"ankle.{s}"] = (sx * 0.155, 0.02, 0.11)
    J[f"ball.{s}"] = (sx * 0.16, -0.12, 0.04)
    J[f"toe.{s}"] = (sx * 0.165, -0.21, 0.035)

BONES = {  # name: (head joint, tail joint, parent)
    "root": ("root", None, None), "hips": ("pelvis", "waist", "root"), "spine": ("waist", None, "hips"),
    "chest": (None, "neck", "spine"), "neck": ("neck", "head", "chest"), "head": ("head", "crown", "neck"),
    # Secondary-motion bones: the straw mane and beard spring on these in Godot (wicker_motion.gd).
    "mane": ("mane0", "mane1", "head"), "beard": ("beard0", "beard1", "head"),
}
for s in ("L", "R"):
    BONES[f"clavicle.{s}"] = (f"clav.{s}", f"shoulder.{s}", "chest")
    BONES[f"upper_arm.{s}"] = (f"shoulder.{s}", f"elbow.{s}", f"clavicle.{s}")
    BONES[f"forearm.{s}"] = (f"elbow.{s}", f"wrist.{s}", f"upper_arm.{s}")
    BONES[f"hand.{s}"] = (f"wrist.{s}", f"hand.{s}", f"forearm.{s}")
    BONES[f"fingers.{s}"] = (f"hand.{s}", f"tip.{s}", f"hand.{s}")
    BONES[f"thumb.{s}"] = (f"thumb0.{s}", f"thumb1.{s}", f"hand.{s}")
    BONES[f"thigh.{s}"] = (f"hip.{s}", f"knee.{s}", "hips")
    BONES[f"shin.{s}"] = (f"knee.{s}", f"ankle.{s}", f"thigh.{s}")
    BONES[f"foot.{s}"] = (f"ankle.{s}", f"ball.{s}", f"shin.{s}")
    BONES[f"toe.{s}"] = (f"ball.{s}", f"toe.{s}", f"foot.{s}")


def jv(name):
    return Vector(J[name])


arm_data = bpy.data.armatures.new("WickerRig")
rig = bpy.data.objects.new("WickerRig", arm_data)
col.objects.link(rig)
bpy.context.view_layer.objects.active = rig
for o in scene.objects:
    o.select_set(o == rig)
bpy.ops.object.mode_set(mode="EDIT")
heads = {"chest": Vector((0, 0, 1.48))}
tails = {"root": Vector((0, 0.25, 0)), "spine": Vector((0, 0, 1.48))}
for name, (h, t, p) in BONES.items():
    eb = arm_data.edit_bones.new(name)
    eb.head = jv(h) if h else heads[name]
    eb.tail = jv(t) if t else tails[name]
    eb.roll = 0.0
for name, (h, t, p) in BONES.items():
    if p:
        arm_data.edit_bones[name].parent = arm_data.edit_bones[p]
for name in ("spine", "chest", "neck", "head", "forearm.L", "forearm.R", "hand.L", "hand.R", "fingers.L", "fingers.R",
             "shin.L", "shin.R", "foot.L", "foot.R", "toe.L", "toe.R", "upper_arm.L", "upper_arm.R"):
    arm_data.edit_bones[name].use_connect = True
bpy.ops.object.mode_set(mode="OBJECT")
BONE_SEG = {}  # bone -> (head, tail) world vectors, for UV mapping
for b in arm_data.bones:
    BONE_SEG[b.name] = (b.head_local.copy(), b.tail_local.copy())

# ------------------------------------------------------------- body (skin mod)
# Skin-modifier skeleton: (position, (radius_x, radius_y)), heroic proportions.
SK = []
EDGES = []


def sv(pos, rad):
    SK.append((Vector(pos), rad))
    return len(SK) - 1


def chain(ids):
    for a, b in zip(ids, ids[1:]):
        EDGES.append((a, b))


pelvis = sv((0, 0.01, 1.0), (0.225, 0.165))
waist = sv((0, 0.015, 1.18), (0.19, 0.14))
belly = sv((0, 0.0, 1.32), (0.235, 0.16))
chest = sv((0, 0.0, 1.5), (0.31, 0.2))
upper = sv((0, 0.01, 1.64), (0.34, 0.185))
neck0 = sv((0, 0.015, 1.76), (0.105, 0.1))
neck1 = sv((0, 0.01, 1.84), (0.09, 0.09))
headc = sv((0, 0.0, 1.96), (0.125, 0.145))
headt = sv((0, 0.01, 2.08), (0.098, 0.112))
chain([pelvis, waist, belly, chest, upper, neck0, neck1, headc, headt])
for s, sx in (("L", L), ("R", R)):
    clav = sv((sx * 0.21, 0.01, 1.66), (0.16, 0.145))
    sho = sv((sx * 0.37, 0.01, 1.65), (0.155, 0.15))
    bic = sv((sx * 0.445, 0.02, 1.51), (0.125, 0.13))
    elb = sv((sx * 0.5, 0.03, 1.35), (0.088, 0.088))
    fore = sv((sx * 0.53, 0.015, 1.22), (0.108, 0.098))
    wri = sv((sx * 0.56, 0.0, 1.06), (0.065, 0.056))
    hand = sv((sx * 0.578, -0.01, 0.97), (0.07, 0.042))
    tip = sv((sx * 0.592, -0.02, 0.87), (0.05, 0.032))
    EDGES.append((upper, clav))
    chain([clav, sho, bic, elb, fore, wri, hand, tip])
    th0 = sv((sx * 0.572, -0.035, 1.015), (0.026, 0.024))
    th1 = sv((sx * 0.582, -0.08, 0.955), (0.02, 0.018))
    chain([wri, th0, th1])
    hip = sv((sx * 0.125, 0.005, 0.98), (0.145, 0.14))
    thi = sv((sx * 0.14, -0.01, 0.8), (0.15, 0.14))
    kne = sv((sx * 0.15, -0.025, 0.58), (0.092, 0.09))
    calf = sv((sx * 0.152, 0.015, 0.38), (0.118, 0.12))
    ank = sv((sx * 0.155, 0.02, 0.13), (0.07, 0.07))
    heel = sv((sx * 0.157, -0.06, 0.07), (0.08, 0.055))
    toe = sv((sx * 0.162, -0.19, 0.045), (0.065, 0.038))
    EDGES.append((pelvis, hip))
    chain([hip, thi, kne, calf, ank, heel, toe])

skel = bpy.data.meshes.new("WickerSkel")
skel.from_pydata([p for p, _ in SK], EDGES, [])
body = bpy.data.objects.new("WickerBody", skel)
col.objects.link(body)
skin = body.modifiers.new("Skin", "SKIN")
skin.use_smooth_shade = True
skin.branch_smoothing = 0.6
for i, (_, rad) in enumerate(SK):
    sk = skel.skin_vertices[0].data[i]
    sk.radius = rad
    sk.use_root = (i == pelvis)
sub = body.modifiers.new("Sub", "SUBSURF")
sub.levels = 2
for o in scene.objects:
    o.select_set(o == body)
bpy.context.view_layer.objects.active = body
bpy.ops.object.modifier_apply(modifier="Skin")
bpy.ops.object.modifier_apply(modifier="Sub")
# --- Heroic anatomy: push the skin out along its normals with soft muscle blobs.
# (centre, radius, amount); mirrored for L/R where x != 0. Front is -Y.
MUSCLES = [
    ((0.12, -0.16, 1.53), 0.12, 0.072),    # pecs
    ((0.11, -0.12, 1.43), 0.08, -0.022),  # under-pec crease
    ((0.37, -0.01, 1.63), 0.1, 0.063),    # delts
    ((0.43, -0.07, 1.5), 0.07, 0.050),    # biceps
    ((0.44, 0.07, 1.5), 0.07, 0.040),     # triceps
    ((0.51, -0.04, 1.26), 0.075, 0.036),   # forearm flexors
    ((0.2, 0.12, 1.53), 0.13, 0.054),      # lats / upper back
    ((0.12, 0.05, 1.74), 0.08, 0.045),    # traps
    ((0.16, -0.12, 0.84), 0.1, 0.063),    # quads
    ((0.1, -0.1, 0.7), 0.06, 0.032),      # vastus medialis (teardrop)
    ((0.1, 0.13, 0.96), 0.1, 0.054),       # glutes
    ((0.16, 0.08, 0.42), 0.08, 0.058),    # calves
    ((0.0, 0.17, 1.38), 0.06, -0.027),    # spine groove
]
for k in range(3):                         # six-pack rows
    for sx in (-1, 1):
        MUSCLES.append(((sx * 0.055, -0.15, 1.36 - k * 0.075), 0.045, 0.02))
blobs = []
for (c, r, a) in MUSCLES:
    blobs.append((Vector(c), r, a))
    if abs(c[0]) > 1e-4:
        blobs.append((Vector((-c[0], c[1], c[2])), r, a))
bm = bmesh.new()
bm.from_mesh(body.data)
bm.normal_update()
for v in bm.verts:
    push = 0.0
    for c, r, a in blobs:
        d2 = (v.co - c).length_squared
        push += a * math.exp(-d2 / (r * r))
    # V-taper: pinch the waist a touch.
    if 1.1 < v.co.z < 1.3 and abs(v.co.x) < 0.3:
        push -= 0.02 * (1.0 - abs(v.co.z - 1.2) / 0.1)
    v.co += v.normal * push
bm.to_mesh(body.data)
bm.free()
for m in MAT_ORDER:
    body.data.materials.append(MATS[m])
for p in body.data.polygons:
    # Woven boots: the feet up to the ankle band take the tighter Band weave.
    p.material_index = 1 if p.center.z < 0.17 else 0
    p.use_smooth = True

# Automatic weights from the rig.
for o in scene.objects:
    o.select_set(o in (body, rig))
bpy.context.view_layer.objects.active = rig
# Keep the spring bones out of the automatic skin weights (they only drive straw cards).
for bn in ("mane", "beard"):
    arm_data.bones[bn].use_deform = False
bpy.ops.object.parent_set(type="ARMATURE_AUTO")
for bn in ("mane", "beard"):
    arm_data.bones[bn].use_deform = True

# ------------------------------------------------------------------ shells
parts = []


def rigid(ob, bone, mat):
    ob.data.materials.clear()
    for m in MAT_ORDER:
        ob.data.materials.append(MATS[m])
    for p in ob.data.polygons:
        p.material_index = MAT_ORDER.index(mat)
    vg = ob.vertex_groups.new(name=bone)
    vg.add([v.index for v in ob.data.vertices], 1.0, "REPLACE")
    parts.append(ob)
    return ob


def apply_all(ob):
    for o in scene.objects:
        o.select_set(o == ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for m in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def braid(name, centre, rx, ry, strand_r, strands=3, twists=10, tilt=(0.0, 0.0, 0.0), segs=48):
    """Braided band: `strands` thin tubes twisting around an elliptical ring."""
    bmb = bmesh.new()
    sides = 4   # diamond-section strands: braid reads the same, a third of the triangles
    for k in range(strands):
        ph = k / strands * math.tau
        rings = []
        for i in range(segs):
            t = i / segs * math.tau
            # ring centre-line point + local frame
            c = Vector((math.cos(t) * rx, math.sin(t) * ry, 0.0))
            tan = Vector((-math.sin(t) * rx, math.cos(t) * ry, 0.0)).normalized()
            out = Vector((math.cos(t) * ry, math.sin(t) * rx, 0.0)).normalized()
            up = Vector((0, 0, 1))
            a = t * twists + ph
            off = (out * math.cos(a) + up * math.sin(a)) * strand_r * 1.15
            p = c + off
            n1 = (out * math.cos(a) + up * math.sin(a)).normalized()
            n2 = tan.cross(n1).normalized()
            rings.append([bmb.verts.new(p + (n1 * math.cos(j / sides * math.tau) + n2 * math.sin(j / sides * math.tau)) * strand_r) for j in range(sides)])
        for i in range(segs):
            r0, r1 = rings[i], rings[(i + 1) % segs]
            for j in range(sides):
                bmb.faces.new((r0[j], r0[(j + 1) % sides], r1[(j + 1) % sides], r1[j]))
    me_b = bpy.data.meshes.new(name)
    bmb.to_mesh(me_b)
    bmb.free()
    ob = bpy.data.objects.new(name, me_b)
    col.objects.link(ob)
    ob.location = centre
    ob.rotation_euler = tilt
    apply_all(ob)
    for poly in ob.data.polygons:
        poly.use_smooth = True
    return ob


def blob(name, loc, scale, rot=(0, 0, 0), segs=16, rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=1.0, location=loc)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = scale
    ob.rotation_euler = rot
    apply_all(ob)
    for poly in ob.data.polygons:
        poly.use_smooth = True
    return ob


for s, sx in (("L", L), ("R", R)):
    # Domed woven pauldron.
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=10, radius=1.0, location=(sx * 0.4, 0.01, 1.72))
    pd = bpy.context.active_object
    bm = bmesh.new()
    bm.from_mesh(pd.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.15], context="VERTS")
    bm.to_mesh(pd.data)
    bm.free()
    pd.scale = (0.21, 0.2, 0.13)
    pd.rotation_euler = (0, sx * 0.45, 0)
    so = pd.modifiers.new("solid", "SOLIDIFY")
    so.thickness = 0.12
    apply_all(pd)
    rigid(pd, f"clavicle.{s}", "Band")
    # Layered leaf-shaped lames overlapping down the upper arm + a centre ridge (turnaround).
    for k, (dz, sc) in enumerate(((-0.07, 0.86), (-0.13, 0.72))):
        lame = blob(f"Lame{s}{k}", (sx * (0.4 + 0.015 * k), 0.01, 1.71 + dz), (0.16 * sc, 0.17 * sc, 0.055), (0, sx * (0.6 + 0.12 * k), 0))
        rigid(lame, f"clavicle.{s}", "Band")
    ridge = blob(f"Ridge{s}", (sx * 0.4, 0.01, 1.8), (0.16, 0.025, 0.03), (0, sx * 0.45, 0), 12, 6)
    rigid(ridge, f"clavicle.{s}", "Band")
    # Braided bands: wrist, knee, ankle.
    for loc, maj, mino, bone, tilt in (
        (J[f"wrist.{s}"], 0.062, 0.018, f"forearm.{s}", 0.35),
        ((sx * 0.15, -0.025, 0.6), 0.1, 0.026, f"shin.{s}", 0.0),
        ((sx * 0.155, 0.02, 0.17), 0.078, 0.022, f"shin.{s}", 0.0),
    ):
        t = braid(f"Braid{s}{bone}", Vector(loc), maj, maj, mino * 0.55, 3, 9, (0, sx * tilt, 0))
        rigid(t, bone, "Band")
    # Woven boot rim / sole edge.
    sole = braid(f"Sole{s}", Vector((sx * 0.16, -0.07, 0.03)), 0.075, 0.15, 0.012, 3, 14)
    rigid(sole, f"foot.{s}", "Band")
# Waist belt (oval) and woven codpiece.
belt = braid("Belt", Vector((0, 0.012, 1.12)), 0.235, 0.17, 0.02, 3, 16)
rigid(belt, "hips", "Band")
# Woven band around the ribcage under the pecs (turnaround), and a sternum ridge.
rib = braid("RibBand", Vector((0, 0.005, 1.4)), 0.3, 0.2, 0.013, 3, 22)
rigid(rib, "chest", "Band")
stern = blob("Sternum", (0, -0.2, 1.5), (0.025, 0.02, 0.1), (0, 0, 0), 10, 6)
rigid(stern, "chest", "Band")
bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=1.0, location=(0, -0.12, 0.98))
cod = bpy.context.active_object
cod.scale = (0.075, 0.05, 0.095)
apply_all(cod)
rigid(cod, "hips", "Band")
# Face: heavy brow and nose (woven), amber eyes.
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -0.127, 2.015))
brow = bpy.context.active_object
brow.scale = (0.185, 0.04, 0.036)
bv = brow.modifiers.new("b", "BEVEL")
bv.width = 0.01
bv.segments = 2
apply_all(brow)
rigid(brow, "head", "Wicker")
bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.03, radius2=0.009, depth=0.08, location=(0, -0.147, 1.965))
nose = bpy.context.active_object
nose.rotation_euler = (math.radians(-70), 0, 0)
apply_all(nose)
rigid(nose, "head", "Wicker")
for sx in (L, R):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=6, radius=0.012, location=(sx * 0.047, -0.123, 1.995))
    eye = bpy.context.active_object
    apply_all(eye)
    rigid(eye, "head", "Eye")
    # Eye-socket rims (shadowed hollows read from a distance).
    sock = blob(f"Socket{sx}", (sx * 0.047, -0.118, 1.997), (0.03, 0.012, 0.022), (0, 0, 0), 10, 6)
    rigid(sock, "head", "Band")
    # Woven cheekbones.
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=1.0, location=(sx * 0.07, -0.118, 1.955))
    cheek = bpy.context.active_object
    cheek.scale = (0.035, 0.022, 0.025)
    apply_all(cheek)
    rigid(cheek, "head", "Wicker")

# Strong woven jaw + chin under the beard, and a nose bridge up to the brow.
jaw = blob("Jaw", (0, -0.085, 1.905), (0.095, 0.06, 0.05))
rigid(jaw, "head", "Wicker")
bridge = blob("Bridge", (0, -0.142, 1.99), (0.016, 0.02, 0.04), (math.radians(-15), 0, 0), 10, 6)
rigid(bridge, "head", "Wicker")

# ------------------------------------------------------------- straw cards
hb = bmesh.new()
hcol = hb.loops.layers.color.new("Col")
huv = hb.loops.layers.uv.new("UVMap")


def strand(base, direction, length, width):
    d = direction.normalized()
    side = d.cross(Vector((0, 0, 1)))
    if side.length < 0.1:
        side = Vector((1, 0, 0))
    side.normalize()
    mid = base + d * length * 0.5 + Vector((0, 0, -length * 0.12))
    tip = base + d * length + Vector((0, 0, -length * 0.3))
    pts = [base, mid, tip]
    for i in range(2):
        a, b = pts[i], pts[i + 1]
        w0 = width * (1.0 - 0.35 * i)
        w1 = width * (1.0 - 0.35 * (i + 1))
        vs = [hb.verts.new(a - side * w0 * 0.5), hb.verts.new(a + side * w0 * 0.5),
              hb.verts.new(b + side * w1 * 0.5), hb.verts.new(b - side * w1 * 0.5)]
        f = hb.faces.new(vs)
        for li, loop in enumerate(f.loops):
            v = (i + (1 if li >= 2 else 0)) / 2.0
            loop[huv].uv = ((0 if li in (0, 3) else 1), v)
            loop[hcol] = (v, 0, 0, 1)


head_c = Vector((0, 0.01, 2.0))
# Wild mane: whole skull above the ears, falling back and down with volume.
for i in range(440):
    th = random.uniform(0, math.tau)
    ph = random.uniform(0.0, 1.7)
    n = Vector((math.cos(th) * math.sin(ph), math.sin(th) * math.sin(ph), math.cos(ph)))
    if n.y < -0.5 and n.z < 0.8:
        continue  # keep the face clear
    base = head_c + Vector((n.x * 0.122, n.y * 0.138, n.z * 0.115))
    # A big wild ball of straw around the skull (turnaround): strands radiate
    # out in every direction, swept slightly back, crown tufts a little longer.
    d = n + Vector((0, 0.25, -0.1)) + Vector((random.uniform(-0.3, 0.3), random.uniform(-0.2, 0.3), random.uniform(-0.2, 0.3)))
    crown = n.z > 0.5
    strand(base, d, random.uniform(0.13, 0.24) if crown else random.uniform(0.11, 0.2), random.uniform(0.07, 0.12))
mane_me = bpy.data.meshes.new("WickerMane")
hb.to_mesh(mane_me)
hb.free()
mane = bpy.data.objects.new("WickerMane", mane_me)
col.objects.link(mane)
rigid(mane, "mane", "Straw")
hb = bmesh.new()
hcol = hb.loops.layers.color.new("Col")
huv = hb.loops.layers.uv.new("UVMap")
# Beard and moustache: jaw and lower face, hanging down.
for i in range(260):
    th = random.uniform(-1.4, 1.4)
    zr = random.uniform(-0.09, -0.02)
    base = Vector((math.sin(th) * 0.106, -math.cos(th) * 0.118, 1.955 + zr))
    d = Vector((math.sin(th) * 0.3, -0.35, -1.0)) + Vector((random.uniform(-0.2, 0.2), random.uniform(-0.15, 0.15), 0))
    strand(base, d, random.uniform(0.1, 0.24), random.uniform(0.05, 0.085))
for sx in (L, R):
    for i in range(10):
        base = Vector((sx * random.uniform(0.0, 0.04), -0.143, 1.94))
        strand(base, Vector((sx * 0.8, -0.3, -0.5)), random.uniform(0.04, 0.06), 0.025)
hair_me = bpy.data.meshes.new("WickerBeard")
hb.to_mesh(hair_me)
hb.free()
hair = bpy.data.objects.new("WickerBeard", hair_me)
col.objects.link(hair)
rigid(hair, "beard", "Straw")

# Join everything into the body (keeps vertex groups by name).
for o in scene.objects:
    o.select_set(o == body or o in parts)
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
body.name = "WickerMesh"
body.data.name = "WickerMesh"

# ---------------------------------------------------------------- UV mapping
me = body.data
straw_idx = MAT_ORDER.index("Straw")
group_names = {vg.index: vg.name for vg in body.vertex_groups}
uv0 = me.uv_layers.get("UVMap") or me.uv_layers.new(name="UVMap")
uv1 = me.uv_layers.new(name="UV2")
me.uv_layers.active = uv0
LIMB_PHASE = {"L": 0.0, "R": 0.5}


def dominant_bone(v):
    best, w = "chest", -1.0
    for g in v.groups:
        n = group_names.get(g.group)
        if n in BONE_SEG and g.weight > w:
            best, w = n, g.weight
    return best


vbone = [dominant_bone(v) for v in me.vertices]
for poly in me.polygons:
    if poly.material_index == straw_idx:
        for li in poly.loop_indices:
            uv1.data[li].uv = (me.vertices[me.loops[li].vertex_index].co.z / HEIGHT, 0.0)
        continue
    # Use the face's majority bone so a face never straddles two frames.
    bones = [vbone[me.loops[li].vertex_index] for li in poly.loop_indices]
    bone = max(set(bones), key=bones.count)
    h, t = BONE_SEG[bone]
    axis = (t - h).normalized()
    ref = Vector((0, -1, 0)) if abs(axis.y) < 0.9 else Vector((1, 0, 0))
    e1 = (ref - axis * ref.dot(axis)).normalized()
    e2 = axis.cross(e1)
    coords = []
    for li in poly.loop_indices:
        p = me.vertices[me.loops[li].vertex_index].co
        rel = p - h
        along = rel.dot(axis)
        radial = rel - axis * along
        ang = math.atan2(radial.dot(e2), radial.dot(e1))
        coords.append([ang, radial.length, along])
    angs = [c[0] for c in coords]
    if max(angs) - min(angs) > math.pi:
        for c in coords:
            if c[0] < 0:
                c[0] += math.tau
    rmean = sum(c[1] for c in coords) / len(coords)
    for li, c in zip(poly.loop_indices, coords):
        uv0.data[li].uv = (c[0] * max(rmean, 0.03), c[2] + h.z)
        z = me.vertices[me.loops[li].vertex_index].co.z
        side = bone[-1] if bone[-2:] in (".L", ".R") else "C"
        spiral = (c[0] / math.tau) * 0.04 + LIMB_PHASE.get(side, 0.25) * 0.02
        uv1.data[li].uv = (min(max(z / HEIGHT + spiral, 0.0), 1.0), c[0] / math.tau)

# ---------------------------------------------------------------- animation
rig.animation_data_create()
for pb in rig.pose.bones:
    pb.rotation_mode = "XYZ"


def make_action(name, length, channels):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data.action = act
    for pb in rig.pose.bones:
        ch = channels.get(pb.name, {})
        rots = ch.get("rot") or [(0, (0, 0, 0)), (length, (0, 0, 0))]
        locs = ch.get("loc") or [(0, (0, 0, 0)), (length, (0, 0, 0))]
        for f, v in rots:
            pb.rotation_euler = v
            pb.keyframe_insert("rotation_euler", frame=f)
        for f, v in locs:
            pb.location = v
            pb.keyframe_insert("location", frame=f)
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
    act.frame_range = (0, length)
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 0, act)
    rig.animation_data.action = None


def cycle(length, amp_thigh, amp_arm, lean, knee, fore, bob):
    """Locomotion loop. Negative X swings a down-pointing bone forward."""
    q = length // 4
    fr = [0, q, 2 * q, 3 * q, length]
    s = [-1, 0, 1, 0, -1]
    return {
        "thigh.L": {"rot": [(f, (amp_thigh * v, 0, 0)) for f, v in zip(fr, s)]},
        "thigh.R": {"rot": [(f, (-amp_thigh * v, 0, 0)) for f, v in zip(fr, s)]},
        "shin.L": {"rot": [(f, (k, 0, 0)) for f, k in zip(fr, [knee * 0.4, knee * 0.2, knee * 0.5, knee, knee * 0.4])]},
        "shin.R": {"rot": [(f, (k, 0, 0)) for f, k in zip(fr, [knee * 0.5, knee, knee * 0.4, knee * 0.2, knee * 0.5])]},
        "foot.L": {"rot": [(f, (k, 0, 0)) for f, k in zip(fr, [-0.2, 0.1, 0.3, -0.3, -0.2])]},
        "foot.R": {"rot": [(f, (k, 0, 0)) for f, k in zip(fr, [0.3, -0.3, -0.2, 0.1, 0.3])]},
        "upper_arm.L": {"rot": [(f, (-amp_arm * v, 0, 0)) for f, v in zip(fr, s)]},
        "upper_arm.R": {"rot": [(f, (amp_arm * v, 0, 0)) for f, v in zip(fr, s)]},
        "forearm.L": {"rot": [(0, (fore, 0, 0)), (length, (fore, 0, 0))]},
        "forearm.R": {"rot": [(0, (fore, 0, 0)), (length, (fore, 0, 0))]},
        "spine": {"rot": [(f, (lean, 0, 0.1 * v)) for f, v in zip(fr, s)]},
        "chest": {"rot": [(f, (lean * 0.4, 0, -0.16 * v)) for f, v in zip(fr, s)]},
        "head": {"rot": [(0, (-lean * 1.2, 0, 0)), (length, (-lean * 1.2, 0, 0))]},
        "hips": {"loc": [(f, (0, b, 0)) for f, b in zip(fr, [0, -bob, 0, -bob, 0])]},
    }


make_action("walk", 32, cycle(32, 0.45, 0.35, 0.05, 0.6, -0.35, 0.03))
make_action("run", 20, cycle(20, 0.75, 0.6, 0.14, 1.0, -0.8, 0.05))
make_action("sprint", 16, cycle(16, 1.0, 0.85, 0.34, 1.35, -1.25, 0.08))
make_action("idle", 72, {
    "chest": {"rot": [(0, (0, 0, 0)), (36, (0.045, 0, 0)), (72, (0, 0, 0))]},
    "head": {"rot": [(0, (0, 0, 0)), (36, (-0.04, 0.0, 0.04)), (72, (0, 0, 0))]},
    "upper_arm.L": {"rot": [(0, (0, 0, 0)), (36, (0.04, 0, -0.03)), (72, (0, 0, 0))]},
    "upper_arm.R": {"rot": [(0, (0, 0, 0)), (36, (0.04, 0, 0.03)), (72, (0, 0, 0))]},
    "forearm.L": {"rot": [(0, (-0.2, 0, 0)), (72, (-0.2, 0, 0))]},
    "forearm.R": {"rot": [(0, (-0.2, 0, 0)), (72, (-0.2, 0, 0))]},
    "fingers.L": {"rot": [(0, (-0.5, 0, 0)), (72, (-0.5, 0, 0))]},
    "fingers.R": {"rot": [(0, (-0.5, 0, 0)), (72, (-0.5, 0, 0))]},
    "hips": {"loc": [(0, (0, 0, 0)), (36, (0, -0.012, 0)), (72, (0, 0, 0))]},
})
make_action("jump", 12, {
    "thigh.L": {"rot": [(0, (-0.3, 0, 0)), (6, (-1.1, 0, 0)), (12, (-1.0, 0, 0))]},
    "thigh.R": {"rot": [(0, (0.1, 0, 0)), (6, (-0.2, 0, 0)), (12, (-0.3, 0, 0))]},
    "shin.L": {"rot": [(0, (0.6, 0, 0)), (6, (1.5, 0, 0)), (12, (1.4, 0, 0))]},
    "shin.R": {"rot": [(0, (0.3, 0, 0)), (6, (0.9, 0, 0)), (12, (0.8, 0, 0))]},
    "upper_arm.L": {"rot": [(0, (-0.4, 0, -0.2)), (6, (-0.9, 0, -0.4)), (12, (-0.8, 0, -0.4))]},
    "upper_arm.R": {"rot": [(0, (0.3, 0, 0.2)), (6, (0.5, 0, 0.5)), (12, (0.4, 0, 0.5))]},
    "forearm.L": {"rot": [(0, (-0.8, 0, 0)), (12, (-0.8, 0, 0))]},
    "forearm.R": {"rot": [(0, (-0.6, 0, 0)), (12, (-0.6, 0, 0))]},
    "spine": {"rot": [(0, (0.1, 0, 0)), (12, (0.18, 0, 0))]},
    "head": {"rot": [(0, (-0.1, 0, 0)), (12, (-0.15, 0, 0))]},
})

# Airborne / landing.
make_action("fall", 24, {
    "upper_arm.L": {"rot": [(0, (-1.3, 0, -0.3)), (12, (-1.5, 0, -0.4)), (24, (-1.3, 0, -0.3))]},
    "upper_arm.R": {"rot": [(0, (-1.3, 0, 0.3)), (12, (-1.5, 0, 0.4)), (24, (-1.3, 0, 0.3))]},
    "forearm.L": {"rot": [(0, (-0.5, 0, 0)), (24, (-0.5, 0, 0))]},
    "forearm.R": {"rot": [(0, (-0.5, 0, 0)), (24, (-0.5, 0, 0))]},
    "thigh.L": {"rot": [(0, (-0.5, 0, 0)), (12, (-0.3, 0, 0)), (24, (-0.5, 0, 0))]},
    "thigh.R": {"rot": [(0, (-0.2, 0, 0)), (12, (-0.4, 0, 0)), (24, (-0.2, 0, 0))]},
    "shin.L": {"rot": [(0, (0.7, 0, 0)), (24, (0.7, 0, 0))]},
    "shin.R": {"rot": [(0, (0.5, 0, 0)), (24, (0.5, 0, 0))]},
    "spine": {"rot": [(0, (-0.1, 0, 0)), (24, (-0.1, 0, 0))]},
    "head": {"rot": [(0, (0.2, 0, 0)), (24, (0.2, 0, 0))]},
})
make_action("land", 12, {
    "hips": {"loc": [(0, (0, -0.28, 0)), (4, (0, -0.32, 0)), (12, (0, 0, 0))]},
    "thigh.L": {"rot": [(0, (-0.8, 0, 0)), (4, (-0.9, 0, 0)), (12, (0, 0, 0))]},
    "thigh.R": {"rot": [(0, (-0.8, 0, 0)), (4, (-0.9, 0, 0)), (12, (0, 0, 0))]},
    "shin.L": {"rot": [(0, (1.3, 0, 0)), (4, (1.5, 0, 0)), (12, (0, 0, 0))]},
    "shin.R": {"rot": [(0, (1.3, 0, 0)), (4, (1.5, 0, 0)), (12, (0, 0, 0))]},
    "foot.L": {"rot": [(0, (-0.5, 0, 0)), (4, (-0.6, 0, 0)), (12, (0, 0, 0))]},
    "foot.R": {"rot": [(0, (-0.5, 0, 0)), (4, (-0.6, 0, 0)), (12, (0, 0, 0))]},
    "spine": {"rot": [(0, (0.35, 0, 0)), (4, (0.4, 0, 0)), (12, (0, 0, 0))]},
    "upper_arm.L": {"rot": [(0, (-0.5, 0, 0)), (12, (0, 0, 0))]},
    "upper_arm.R": {"rot": [(0, (-0.5, 0, 0)), (12, (0, 0, 0))]},
})
# Breaststroke: body leans forward (the controller also pitches the model in water).
make_action("swim", 40, {
    "spine": {"rot": [(0, (0.35, 0, 0)), (40, (0.35, 0, 0))]},
    "head": {"rot": [(0, (-0.5, 0, 0)), (20, (-0.4, 0, 0)), (40, (-0.5, 0, 0))]},
    "upper_arm.L": {"rot": [(0, (-2.6, 0, 0.2)), (14, (-1.2, 0, -0.9)), (26, (-0.9, 0, -0.2)), (40, (-2.6, 0, 0.2))]},
    "upper_arm.R": {"rot": [(0, (-2.6, 0, -0.2)), (14, (-1.2, 0, 0.9)), (26, (-0.9, 0, 0.2)), (40, (-2.6, 0, -0.2))]},
    "forearm.L": {"rot": [(0, (-0.2, 0, 0)), (20, (-1.6, 0, 0)), (40, (-0.2, 0, 0))]},
    "forearm.R": {"rot": [(0, (-0.2, 0, 0)), (20, (-1.6, 0, 0)), (40, (-0.2, 0, 0))]},
    "thigh.L": {"rot": [(0, (0.2, 0, 0)), (20, (-0.7, 0, -0.3)), (32, (0.3, 0, 0)), (40, (0.2, 0, 0))]},
    "thigh.R": {"rot": [(0, (0.2, 0, 0)), (20, (-0.7, 0, 0.3)), (32, (0.3, 0, 0)), (40, (0.2, 0, 0))]},
    "shin.L": {"rot": [(0, (0.2, 0, 0)), (20, (1.6, 0, 0)), (32, (0.1, 0, 0)), (40, (0.2, 0, 0))]},
    "shin.R": {"rot": [(0, (0.2, 0, 0)), (20, (1.6, 0, 0)), (32, (0.1, 0, 0)), (40, (0.2, 0, 0))]},
})
# Lever pull: reach up with the right hand, haul down, settle.
make_action("interact", 30, {
    "upper_arm.R": {"rot": [(0, (0, 0, 0)), (9, (-2.5, 0, 0.2)), (19, (-0.7, 0, 0.1)), (30, (0, 0, 0))]},
    "forearm.R": {"rot": [(0, (-0.2, 0, 0)), (9, (-0.3, 0, 0)), (19, (-1.4, 0, 0)), (30, (-0.2, 0, 0))]},
    "fingers.R": {"rot": [(0, (0, 0, 0)), (9, (-1.2, 0, 0)), (24, (-1.2, 0, 0)), (30, (-0.3, 0, 0))]},
    "thumb.R": {"rot": [(0, (0, 0, 0)), (9, (-0.8, 0, 0)), (24, (-0.8, 0, 0)), (30, (0, 0, 0))]},
    "spine": {"rot": [(0, (0, 0, 0)), (9, (-0.1, 0, 0)), (19, (0.25, 0, 0)), (30, (0, 0, 0))]},
    "hips": {"loc": [(0, (0, 0, 0)), (19, (0, -0.08, 0)), (30, (0, 0, 0))]},
})
# Curious idle: looks left and right, hand to chin, studying the "high tech".
make_action("look_around", 120, {
    "head": {"rot": [(0, (0, 0, 0)), (20, (0.05, 0.6, 0)), (45, (0.05, 0.6, 0)), (65, (0.05, -0.55, 0)), (95, (0.0, -0.55, 0)), (120, (0, 0, 0))]},
    "neck": {"rot": [(0, (0, 0, 0)), (20, (0, 0.2, 0)), (65, (0, -0.2, 0)), (120, (0, 0, 0))]},
    "upper_arm.R": {"rot": [(0, (0, 0, 0)), (70, (0, 0, 0)), (80, (-1.0, 0, 0.3)), (110, (-1.0, 0, 0.3)), (120, (0, 0, 0))]},
    "forearm.R": {"rot": [(0, (-0.2, 0, 0)), (70, (-0.2, 0, 0)), (80, (-2.2, 0, 0)), (110, (-2.2, 0, 0)), (120, (-0.2, 0, 0))]},
    "chest": {"rot": [(0, (0, 0, 0)), (20, (0, 0.15, 0)), (65, (0, -0.15, 0)), (120, (0, 0, 0))]},
})
# Summoning: kneeling, rising, arms flung wide, then a guardian's stance.
make_action("summon", 90, {
    "hips": {"loc": [(0, (0, -0.75, 0)), (30, (0, -0.65, 0)), (60, (0, 0, 0)), (90, (0, 0, 0))]},
    "thigh.L": {"rot": [(0, (-1.5, 0, 0)), (30, (-1.4, 0, 0)), (60, (0, 0, 0)), (90, (0, 0, 0))]},
    "thigh.R": {"rot": [(0, (-0.3, 0, 0)), (30, (-0.3, 0, 0)), (60, (0, 0, 0)), (90, (0, 0, 0))]},
    "shin.L": {"rot": [(0, (1.7, 0, 0)), (30, (1.6, 0, 0)), (60, (0, 0, 0)), (90, (0, 0, 0))]},
    "shin.R": {"rot": [(0, (2.3, 0, 0)), (30, (2.2, 0, 0)), (60, (0, 0, 0)), (90, (0, 0, 0))]},
    "spine": {"rot": [(0, (0.6, 0, 0)), (30, (0.5, 0, 0)), (60, (-0.12, 0, 0)), (90, (0, 0, 0))]},
    "head": {"rot": [(0, (0.6, 0, 0)), (30, (0.5, 0, 0)), (60, (-0.3, 0, 0)), (90, (0, 0, 0))]},
    "upper_arm.L": {"rot": [(0, (0, 0, 0)), (30, (0, 0, 0)), (60, (-1.4, 0, -0.9)), (75, (-1.4, 0, -0.9)), (90, (0, 0, 0))]},
    "upper_arm.R": {"rot": [(0, (0, 0, 0)), (30, (0, 0, 0)), (60, (-1.4, 0, 0.9)), (75, (-1.4, 0, 0.9)), (90, (0, 0, 0))]},
    "fingers.L": {"rot": [(0, (-1.2, 0, 0)), (45, (-1.2, 0, 0)), (60, (0.2, 0, 0)), (90, (-0.4, 0, 0))]},
    "fingers.R": {"rot": [(0, (-1.2, 0, 0)), (45, (-1.2, 0, 0)), (60, (0.2, 0, 0)), (90, (-0.4, 0, 0))]},
})

# ------------------------------------------------------------------- export

def _activate_colors(objs):
    """The glTF exporter only writes the *active* colour attribute; bmesh layers aren't active by default."""
    for o in objs:
        if o.type != "MESH":
            continue
        ca = o.data.color_attributes
        if "Col" in ca:
            ca.active_color_name = "Col"
            ca.render_color_index = ca.find("Col")

_activate_colors([body])
os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
os.makedirs(os.path.dirname(OUT_BLEND), exist_ok=True)
for o in scene.objects:
    o.select_set(o in (rig, body))
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(
    filepath=OUT_GLB, export_format="GLB", export_apply=False, export_animations=True,
    export_animation_mode="ACTIONS", export_nla_strips=True, use_selection=True, export_skins=True,
    export_yup=True, export_vertex_color="ACTIVE", export_texcoords=True,
)
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND, copy=True)
zs = [v.co.z for v in me.vertices]
rep = {"verts": len(me.vertices), "tris": sum(len(p.vertices) - 2 for p in me.polygons), "height": max(zs) - min(zs),
       "bones": len(arm_data.bones), "actions": sorted(a.name for a in bpy.data.actions if a.use_fake_user),
       "uv_layers": [u.name for u in me.uv_layers]}
with open("/tmp/wicker_build.json", "w") as f:
    json.dump(rep, f)
print("BUILD_WICKER_OK", rep)
