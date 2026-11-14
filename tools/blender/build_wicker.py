"""The Wicker Man: summoned woven protector (player character).

Design: wicker-inspo/turn-around-final.png (front/back). Heroic ~2.1 m build on
an anatomical CC0 base body (Quaternius Universal Base Characters, superhero
male) re-rigged onto our own rig; domed woven pauldrons, braided bands at
waist/ribs/knees/ankles/wrists, woven codpiece, spiky wicker hair (stiff
tapered quills in clumps over the whole scalp, not a crown) and a coarse
quill beard; generic base face (not any actor's likeness), faint amber eyes.

Run headless:   Blender -b -P tools/blender/build_wicker.py
Or via the Blender MCP: exec(open('<repo>/tools/blender/build_wicker.py').read(), {'__name__': '__main__'})
Exports assets/characters/wicker.glb (+ src/wicker.blend). Z-up, front = -Y.
GLB pipeline rules: skin/subsurf applied manually, export_apply=False.

Materials (Godot remaps by name): Wicker (body weave), Band (braids/plates),
Straw (alpha cards, unused since round 3), Eye (amber glow), Spike (solid quills).
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

# GUI (Blender MCP): build in a dedicated scene. Headless: operators only see the context scene.
scene = (bpy.data.scenes.get("WickerBuild") or bpy.data.scenes.new("WickerBuild")) if bpy.context.window else bpy.context.scene
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
    "Spike": material("Spike", (0.72, 0.6, 0.38)),
}
MAT_ORDER = ["Wicker", "Band", "Straw", "Eye", "Spike"]

# ------------------------------------------------------------ anatomical base
# Round 3: the body is the Quaternius "Universal Base Characters" superhero male
# (CC0, assets/third_party/quaternius_ubc), posed from T to our A-pose, scaled to
# HEIGHT, and re-rigged onto our own 28-bone rig with its skin weights merged
# bone-by-bone (so our clips, spring bones and weave-in all still apply).
BASE_GLTF = os.path.join(ROOT, "assets", "third_party", "quaternius_ubc", "Superhero_Male_FullBody.gltf")
ARM_FROM_VERTICAL = math.radians(14.0)   # arms hang a little out from the lats (turnaround)
ELBOW_BEND = math.radians(8.0)

before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=BASE_GLTF)
imported = [o for o in bpy.data.objects if o not in before]
for o in imported:
    if o.name not in col.objects:
        col.objects.link(o)
base_arm = next(o for o in imported if o.type == "ARMATURE")
base_body = next(o for o in imported if o.type == "MESH" and o.name.startswith("SuperHero"))
base_eyes = next((o for o in imported if o.type == "MESH" and o.name.startswith("Eyes")), None)
for o in imported:
    if o not in (base_arm, base_body, base_eyes):
        bpy.data.objects.remove(o, do_unlink=True)

# T-pose -> A-pose by rotating the upper arms down about the forward axis (world space).
for o in scene.objects:
    o.select_set(o == base_arm)
bpy.context.view_layer.objects.active = base_arm
bpy.ops.object.mode_set(mode="POSE")
for side in ("l", "r"):
    pb = base_arm.pose.bones[f"upperarm_{side}"]
    mw = base_arm.matrix_world
    h = mw @ pb.head
    t = mw @ base_arm.pose.bones[f"hand_{side}"].head
    sx = 1.0 if t.x > h.x else -1.0
    want = Vector((sx * math.sin(ARM_FROM_VERTICAL), 0.0, -math.cos(ARM_FROM_VERTICAL)))
    q = (t - h).normalized().rotation_difference(want)
    M = Matrix.Translation(h) @ q.to_matrix().to_4x4() @ Matrix.Translation(-h)
    pb.matrix = mw.inverted() @ M @ mw @ pb.matrix
    bpy.context.view_layer.update()
    # Slight natural elbow bend (forearm swings forward, -Y).
    fb = base_arm.pose.bones[f"lowerarm_{side}"]
    e = mw @ fb.head
    M = Matrix.Translation(e) @ Matrix.Rotation(-ELBOW_BEND, 4, "X") @ Matrix.Translation(-e)
    fb.matrix = mw.inverted() @ M @ mw @ fb.matrix
    bpy.context.view_layer.update()
bpy.ops.object.mode_set(mode="OBJECT")


def bake_pose(ob):
    """Bake the posed armature deformation into the mesh, keeping vertex groups."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    cos = [ob.matrix_world @ v.co for v in ev.data.vertices]
    for m in list(ob.modifiers):
        ob.modifiers.remove(m)
    ob.parent = None
    ob.matrix_world = Matrix.Identity(4)
    for v, c in zip(ob.data.vertices, cos):
        v.co = c


bake_pose(base_body)
if base_eyes:
    bake_pose(base_eyes)
BONE_W = {b.name: (base_arm.matrix_world @ b.head, base_arm.matrix_world @ b.tail) for b in base_arm.pose.bones}

# Front must be -Y: toes point forward.
foot_h, _ = BONE_W["foot_l"]
ball_h, _ = BONE_W["ball_l"]
FLIP = ball_h.y > foot_h.y
zs = [v.co.z for v in base_body.data.vertices]
z0, z1 = min(zs), max(zs)
SCALE = HEIGHT / (z1 - z0)


def to_ours(p):
    p = Vector(p)
    if FLIP:
        p = Vector((-p.x, -p.y, p.z))
    return Vector((p.x * SCALE, p.y * SCALE, (p.z - z0) * SCALE))


for ob in [o for o in (base_body, base_eyes) if o]:
    for v in ob.data.vertices:
        v.co = to_ours(v.co)
    ob.data.update()
BW = {n: (to_ours(h), to_ours(t)) for n, (h, t) in BONE_W.items()}
bpy.data.objects.remove(base_arm, do_unlink=True)


def bh(n):
    return BW[n][0]


def bt(n):
    return BW[n][1]


L, R = 1, -1
OURS_SIDE = {}
for side in ("l", "r"):
    OURS_SIDE[side] = "L" if bh(f"upperarm_{side}").x > 0 else "R"
J = {
    "root": Vector((0, 0, 0)),
    "pelvis": Vector((0, bh("pelvis").y, bh("pelvis").z)),
    "waist": Vector((0, bh("spine_02").y, bh("spine_02").z)),
    "chest": Vector((0, bh("spine_03").y, bh("spine_03").z)),
    "neck": Vector((0, bh("neck_01").y, bh("neck_01").z)),
    "head": Vector((0, bh("Head").y, bh("Head").z)),
    "crown": Vector((0, bh("Head").y, HEIGHT)),
}
for side in ("l", "r"):
    s = OURS_SIDE[side]
    sx = L if s == "L" else R

    def pick(name, tail=False):
        p = bt(f"{name}_{side}") if tail else bh(f"{name}_{side}")
        o = "r" if side == "l" else "l"
        q = bt(f"{name}_{o}") if tail else bh(f"{name}_{o}")
        return Vector((sx * (abs(p.x) + abs(q.x)) * 0.5, (p.y + q.y) * 0.5, (p.z + q.z) * 0.5))

    J[f"clav.{s}"] = pick("clavicle")
    J[f"shoulder.{s}"] = pick("upperarm")
    J[f"elbow.{s}"] = pick("lowerarm")
    J[f"wrist.{s}"] = pick("hand")
    J[f"hand.{s}"] = pick("middle_01")
    J[f"tip.{s}"] = pick("middle_04_leaf", True)
    J[f"thumb0.{s}"] = pick("thumb_01")
    J[f"thumb1.{s}"] = pick("thumb_04_leaf", True)
    J[f"hip.{s}"] = pick("thigh")
    J[f"knee.{s}"] = pick("calf")
    J[f"ankle.{s}"] = pick("foot")
    J[f"ball.{s}"] = pick("ball")
    J[f"toe.{s}"] = pick("ball_leaf", True)
# Spring-bone anchors for the hair and beard, relative to the head joint.
HS = (J["crown"].z - J["head"].z) / 0.24   # head scale vs the round-2 rig
hj = J["head"]
J["mane0"] = hj + Vector((0, 0.06, 0.16)) * HS
J["mane1"] = hj + Vector((0, 0.24, -0.02)) * HS
J["beard0"] = hj + Vector((0, -0.1, 0.02)) * HS
J["beard1"] = hj + Vector((0, -0.15, -0.16)) * HS

# Base bone -> our bone (weights are summed per our bone).
WEIGHT_MAP = {"root": "hips", "pelvis": "hips", "spine_01": "hips", "spine_02": "spine", "spine_03": "chest",
              "neck_01": "neck", "Head": "head"}
for side in ("l", "r"):
    s = OURS_SIDE[side]
    WEIGHT_MAP.update({f"clavicle_{side}": f"clavicle.{s}", f"upperarm_{side}": f"upper_arm.{s}",
                       f"lowerarm_{side}": f"forearm.{s}", f"hand_{side}": f"hand.{s}",
                       f"thigh_{side}": f"thigh.{s}", f"calf_{side}": f"shin.{s}", f"foot_{side}": f"foot.{s}",
                       f"ball_{side}": f"toe.{s}", f"ball_leaf_{side}": f"toe.{s}"})
    for f in ("index", "middle", "ring", "pinky"):
        for k in ("01", "02", "03", "04_leaf"):
            WEIGHT_MAP[f"{f}_{k}_{side}"] = f"fingers.{s}"
    for k in ("01", "02", "03", "04_leaf"):
        WEIGHT_MAP[f"thumb_{k}_{side}"] = f"thumb.{s}"

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
heads = {"chest": J["chest"]}
tails = {"root": Vector((0, 0.25, 0)), "spine": J["chest"]}
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


# ------------------------------------------------------------- body (CC0 base)
body = base_body
body.name = "WickerBody"
me = body.data
old_names = {vg.index: vg.name for vg in body.vertex_groups}
acc = [dict() for _ in me.vertices]
for v in me.vertices:
    for g in v.groups:
        ours = WEIGHT_MAP.get(old_names[g.group])
        if ours and g.weight > 1e-4:
            acc[v.index][ours] = acc[v.index].get(ours, 0.0) + g.weight
for vg in list(body.vertex_groups):
    body.vertex_groups.remove(vg)
vgs = {}
by_group = {}
for i, d in enumerate(acc):
    tot = sum(d.values()) or 1.0
    for n, w in d.items():
        by_group.setdefault((n, round(w / tot, 3)), []).append(i)
for (n, w), idx in by_group.items():
    if n not in vgs:
        vgs[n] = body.vertex_groups.new(name=n)
    vgs[n].add(idx, w, "REPLACE")
DOM = [max(d, key=d.get) if d else "hips" for d in acc]
me.update()
BODY_CO = [v.co.copy() for v in me.vertices]
BODY_N = [v.normal.copy() for v in me.vertices]
for uvl in list(me.uv_layers)[1:]:
    me.uv_layers.remove(uvl)
if me.uv_layers:
    me.uv_layers[0].name = "UVMap"
for ca in list(me.color_attributes):
    me.color_attributes.remove(ca)
me.materials.clear()
for m in MAT_ORDER:
    me.materials.append(MATS[m])
BOOT_TOP = (J["ankle.L"].z + 0.07)
for p in me.polygons:
    # Woven boots: the feet up to the ankle band take the tighter Band weave.
    p.material_index = 1 if p.center.z < BOOT_TOP else 0
    p.use_smooth = True
body.parent = rig
arm_mod = body.modifiers.new("Armature", "ARMATURE")
arm_mod.object = rig


def section(bones, centre, axis, slab=0.012):
    """Cross-section of the body around `axis` at `centre`, limited to verts of `bones`.
    Returns (centre, rx, ry, frame) with frame columns (e1, e2, axis)."""
    axis = axis.normalized()
    e1 = (Vector((1, 0, 0)) - axis * axis.x).normalized()
    e2 = axis.cross(e1)
    xs, ys = [], []
    for c, b in zip(BODY_CO, DOM):
        if b in bones:
            r = c - centre
            if abs(r.dot(axis)) < slab:
                xs.append(r.dot(e1))
                ys.append(r.dot(e2))
    if not xs:
        return centre, 0.05, 0.05, Matrix((e1, e2, axis)).transposed()
    cx, cy = (max(xs) + min(xs)) * 0.5, (max(ys) + min(ys)) * 0.5
    return centre + e1 * cx + e2 * cy, (max(xs) - min(xs)) * 0.5, (max(ys) - min(ys)) * 0.5, Matrix((e1, e2, axis)).transposed()


def front_y(bones, x_max, z_lo, z_hi):
    ys = [c.y for c, b in zip(BODY_CO, DOM) if b in bones and abs(c.x) < x_max and z_lo < c.z < z_hi]
    return min(ys) if ys else 0.0


# Detube check: cross-section radius at 5 points along each limb segment must vary.
LIMB_VAR = {}
for bn in ("upper_arm.L", "forearm.L", "thigh.L", "shin.L"):
    h, t = BONE_SEG[bn]
    rads = []
    for f in (0.15, 0.32, 0.5, 0.68, 0.85):
        _, rx, ry, _ = section({bn}, h.lerp(t, f), t - h, 0.01)
        rads.append((rx + ry) * 0.5)
    LIMB_VAR[bn] = round((max(rads) - min(rads)) / max(rads), 3)

# ------------------------------------------------------------------ shells
parts = []


def rigid(ob, bone, mat):
    ob.data.materials.clear()
    for m in MAT_ORDER:
        ob.data.materials.append(MATS[m])
    for p in ob.data.polygons:
        p.material_index = MAT_ORDER.index(mat)
    for vg in list(ob.vertex_groups):
        ob.vertex_groups.remove(vg)
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


def braid(name, centre, rx, ry, strand_r, strands=3, twists=10, frame=None, segs=48):
    """Braided band: `strands` thin tubes twisting around an elliptical ring in `frame`'s XY plane."""
    bmb = bmesh.new()
    sides = 4   # diamond-section strands: braid reads the same, a third of the triangles
    for k in range(strands):
        ph = k / strands * math.tau
        rings = []
        for i in range(segs):
            t = i / segs * math.tau
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
    ob.matrix_world = Matrix.Translation(centre) @ (frame.to_4x4() if frame else Matrix.Identity(4))
    apply_all(ob)
    for poly in ob.data.polygons:
        poly.use_smooth = True
    return ob


def blob(name, loc, scale, rot=(0, 0, 0), segs=16, rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=1.0, location=loc)
    ob = bpy.context.active_object
    if ob.name not in col.objects:
        col.objects.link(ob)
    ob.name = name
    ob.scale = scale
    ob.rotation_euler = rot
    apply_all(ob)
    for poly in ob.data.polygons:
        poly.use_smooth = True
    return ob


def wrap_shell(name, centre, radius, keep, offset, thick):
    """A sphere patch (verts where keep(local) is true) shrink-wrapped onto the body, then thickened outward."""
    bmw = bmesh.new()
    bmesh.ops.create_uvsphere(bmw, u_segments=28, v_segments=16, radius=radius)
    bmesh.ops.delete(bmw, geom=[v for v in bmw.verts if not keep(v.co)], context="VERTS")
    me_w = bpy.data.meshes.new(name)
    bmw.to_mesh(me_w)
    bmw.free()
    ob = bpy.data.objects.new(name, me_w)
    col.objects.link(ob)
    ob.location = centre
    sw = ob.modifiers.new("wrap", "SHRINKWRAP")
    sw.target = body
    sw.wrap_method = "NEAREST_SURFACEPOINT"
    sw.offset = offset
    sm = ob.modifiers.new("smooth", "SMOOTH")
    sm.iterations = 4
    so = ob.modifiers.new("solid", "SOLIDIFY")
    so.thickness = thick
    so.offset = 1.0
    apply_all(ob)
    for poly in ob.data.polygons:
        poly.use_smooth = True
    return ob


def arm_lame(name, bones, centre, axis, height, offset, sx, arc=math.radians(220), segs=18):
    """A curved plate hugging the outside of a limb: an arc of the measured section, flaring at the bottom."""
    c, rx, ry, fr = section(bones, centre, axis, 0.015)
    e1, e2, ax = fr.col[0], fr.col[1], fr.col[2]
    bml = bmesh.new()
    rows = []
    for r in range(3):
        t = r / 2.0
        flare = offset + 0.018 * t * t
        row = []
        for i in range(segs + 1):
            a = -arc / 2 + arc * i / segs
            taper = math.cos((i / segs - 0.5) * math.pi) ** 0.5     # leaf: tall in the middle, pointed at the ends
            z = (0.5 - t) * height * taper
            row.append(bml.verts.new(c + ax * z + e1 * (sx * math.cos(a) * (rx + flare)) + e2 * (math.sin(a) * (ry + flare))))
        rows.append(row)
    for r0, r1 in zip(rows, rows[1:]):
        for i in range(segs):
            bml.faces.new((r0[i], r0[i + 1], r1[i + 1], r1[i]))
    me_l = bpy.data.meshes.new(name)
    bml.to_mesh(me_l)
    bml.free()
    ob = bpy.data.objects.new(name, me_l)
    col.objects.link(ob)
    so = ob.modifiers.new("solid", "SOLIDIFY")
    so.thickness = 0.014
    so.offset = 1.0
    apply_all(ob)
    for poly in ob.data.polygons:
        poly.use_smooth = True
    return ob


def band_on(name, bones, centre, axis, bone, strand_r, twists, strands=3, slab=0.012, snug=1.0):
    c, rx, ry, fr = section(bones, centre, axis, slab)
    return rigid(braid(name, c, rx * snug + strand_r, ry * snug + strand_r, strand_r, strands, twists, fr), bone, "Band")


for s, sx in (("L", L), ("R", R)):
    sh = J[f"shoulder.{s}"]
    # Deltoid cap: outermost/topmost body point over the shoulder joint.
    delt = [c for c, b in zip(BODY_CO, DOM) if b == f"upper_arm.{s}" and c.z > sh.z - 0.1]
    top = max(c.z for c in delt)
    outer = max(abs(c.x) for c in delt)
    # Layered woven pauldron shrink-wrapped over the deltoid: a cap plus two
    # overlapping lames stepping down the arm, and a centre ridge (turnaround).
    dc = Vector((sx * (outer - 0.06), sh.y, top - 0.07))
    RAD = 0.17
    rigid(wrap_shell(f"Pauldron{s}", dc, RAD, lambda v: -0.3 * RAD < v.z and sx * v.x > -0.45 * RAD, 0.016, 0.022),
          f"upper_arm.{s}", "Band")
    # Two leaf-shaped lames overlapping down the outside of the upper arm, flaring at the hem.
    ua_h, ua_t = J[f"shoulder.{s}"], J[f"elbow.{s}"]
    for k, f in enumerate((0.3, 0.46)):
        rigid(arm_lame(f"Lame{s}{k}", {f"upper_arm.{s}"}, ua_h.lerp(ua_t, f), ua_t - ua_h, 0.07, 0.022 + 0.008 * k, sx),
              f"upper_arm.{s}", "Band")
    ridge = blob(f"Ridge{s}", (sx * (outer - 0.06), sh.y, top + 0.022), (0.075, 0.014, 0.018), (0, sx * 0.55, 0), 12, 6)
    rigid(ridge, f"upper_arm.{s}", "Band")
    # Braided bands: wrist, below the knee, ankle; and the woven boot rim.
    el, wr = J[f"elbow.{s}"], J[f"wrist.{s}"]
    band_on(f"Wrist{s}", {f"forearm.{s}"}, el.lerp(wr, 0.88), wr - el, f"forearm.{s}", 0.011, 9)
    kn, an = J[f"knee.{s}"], J[f"ankle.{s}"]
    band_on(f"Knee{s}", {f"shin.{s}", f"thigh.{s}"}, kn.lerp(an, 0.08), an - kn, f"shin.{s}", 0.014, 9)
    band_on(f"Ankle{s}", {f"shin.{s}", f"foot.{s}"}, Vector((an.x, an.y, BOOT_TOP)), Vector((0, 0, 1)), f"shin.{s}", 0.012, 9)
    band_on(f"Sole{s}", {f"foot.{s}", f"toe.{s}"}, Vector((an.x, an.y, 0.03)), Vector((0, 0, 1)), f"foot.{s}", 0.011, 14, slab=0.02)
# Waist belt and a woven band under the pecs (turnaround).
pel = J["pelvis"]
band_on("Belt", {"hips", "spine"}, pel + Vector((0, 0, 0.06)), Vector((0, 0, 1)), "hips", 0.018, 16)
RIB_Z = J["chest"].z - 0.07
band_on("RibBand", {"spine", "chest"}, Vector((0, J["chest"].y, RIB_Z)), Vector((0, 0, 1)), "chest", 0.011, 22)
# Sternum ridge and woven codpiece, sat on the measured front surface.
cz = pel.z - 0.1
cod = blob("Cod", (0, front_y({"hips", "thigh.L", "thigh.R"}, 0.04, cz - 0.03, cz + 0.03) + 0.025, cz), (0.06, 0.04, 0.08), (0.25, 0, 0), 12, 8)
rigid(cod, "hips", "Band")
# Faint amber eyes: the base mesh's eyeballs.
EYE_Z = J["head"].z + 0.1 * HS
if base_eyes:
    base_eyes.parent = None
    for m in list(base_eyes.modifiers):
        base_eyes.modifiers.remove(m)
    EYE_Z = sum(v.co.z for v in base_eyes.data.vertices) / len(base_eyes.data.vertices)
    for uvl in list(base_eyes.data.uv_layers)[1:]:
        base_eyes.data.uv_layers.remove(uvl)
    rigid(base_eyes, "head", "Eye")

# ------------------------------------------------------- spiky wicker hair
# Stiff tapered quills in clumps, Poisson-scattered over the WHOLE scalp
# (crown, temples, sides, back, nape) and swept back/up: spiky woven hair,
# never a crown/halo ring. Diamond-section quills; COLOR.r = sway (0 root ->
# 1 tip), COLOR.g = per-quill tone; UV.y = 0 root -> 1 tip (lighter tips).
hb = None
hcol = huv = None


def new_hair_bm():
    global hb, hcol, huv
    hb = bmesh.new()
    hcol = hb.loops.layers.color.new("Col")
    huv = hb.loops.layers.uv.new("UVMap")


def quill(base, direction, length, width, curl, tone):
    """A 4-sided quill tapering to a point, bending by `curl` along its length."""
    d = direction.normalized()
    side = d.cross(Vector((0, 0, 1)))
    if side.length < 0.1:
        side = d.cross(Vector((1, 0, 0)))
    side.normalize()
    up = side.cross(d).normalized()
    ts = (0.0, 0.55)
    rings = []
    p = base.copy()
    dd = d.copy()
    prev_t = 0.0
    for t in ts:
        p = p + dd * length * (t - prev_t)
        dd = (dd + curl * (t - prev_t)).normalized()
        prev_t = t
        r = width * (1.0 - t) ** 0.85
        rings.append(([hb.verts.new(p + (side * math.cos(j * math.pi / 2) + up * math.sin(j * math.pi / 2)) * r) for j in range(4)], t))
    tip = hb.verts.new(p + dd * length * (1.0 - prev_t))

    def face(vs, tvals):
        f = hb.faces.new(vs)
        for li, loop in enumerate(f.loops):
            loop[huv].uv = (li / 4.0, tvals[li])
            loop[hcol] = (tvals[li], tone, 0.0, 1.0)
        f.smooth = True

    for (r0, t0), (r1, t1) in zip(rings, rings[1:]):
        for j in range(4):
            face((r0[j], r0[(j + 1) % 4], r1[(j + 1) % 4], r1[j]), (t0, t0, t1, t1))
    r_last, t_last = rings[-1]
    for j in range(4):
        face((r_last[j], r_last[(j + 1) % 4], tip), (t_last, t_last, 1.0))


def poisson(cands, n, rmin):
    random.shuffle(cands)
    out = []
    for c in cands:
        if all((c[0] - o[0]).length > rmin for o in out):
            out.append(c)
            if len(out) >= n:
                break
    return out


crown = J["crown"]
head_verts = [(c, nrm) for c, nrm, b in zip(BODY_CO, BODY_N, DOM) if b == "head"]
CHIN_Z = min(c.z for c, nrm in head_verts if nrm.y < -0.4 and abs(c.x) < 0.03)
HEAD_H = crown.z - CHIN_Z
EAR_X = max(abs(c.x) for c, _ in head_verts if abs(c.z - EYE_Z) < 0.03)
scalp = []
for c, nrm in head_verts:
    hairline = c.z > EYE_Z + 0.055 * HS                     # forehead hairline
    sides = c.z > EYE_Z + 0.012 * HS and nrm.y > -0.3        # temples / above the ears
    back = nrm.y > 0.3 and c.z > J["neck"].z + 0.035 * HS    # back of the skull down to the nape
    if hairline or sides or back:
        scalp.append((c, nrm))
SCALP_SET = {(round(c.x, 5), round(c.y, 5), round(c.z, 5)) for c, _ in scalp}
for poly in me.polygons:
    # Under the quills the scalp takes the tight dark Band weave, so gaps read as dense hair roots.
    if all((round(BODY_CO[i].x, 5), round(BODY_CO[i].y, 5), round(BODY_CO[i].z, 5)) in SCALP_SET for i in poly.vertices):
        poly.material_index = MAT_ORDER.index("Band")
new_hair_bm()
HAIR_ROOTS, HAIR_TIPS = [], []
for layer, (count, rmin, per, lscale) in enumerate(((80, 0.026 * HS, (3, 5), 1.0), (120, 0.018 * HS, (2, 2), 0.38))):
    for c, nrm in poisson(list(scalp), count, rmin):
        elev = max(0.0, min(1.0, (c.z - EYE_Z) / (crown.z - EYE_Z)))
        backness = max(0.0, nrm.y)
        length = (0.07 + 0.11 * elev + 0.06 * backness) * HS * lscale
        if nrm.y < -0.2 and elev < 0.45:
            length *= 0.6                                      # short at the temples
        if c.z < EYE_Z:
            length *= 0.85                                     # shaggy, a bit shorter at the nape
        # Windswept: back everywhere, up only on the crown, falling down-back over the nape.
        lift = 0.2 * elev - 0.45 * (1.0 - elev) * backness
        wind = 1.0 if layer == 0 else 0.25                     # the short under-layer stands up and fills gaps
        d0 = nrm * 1.0 + Vector((0, 0.32, lift)) * wind + Vector((random.uniform(-0.3, 0.3), random.uniform(-0.25, 0.25), random.uniform(-0.25, 0.25)))
        for q in range(random.randint(*per)):
            off = Vector((random.uniform(-1, 1), random.uniform(-1, 1), random.uniform(-1, 1))) * 0.009 * HS
            base = c + off - nrm * 0.006
            d = d0 + Vector((random.uniform(-0.22, 0.22), random.uniform(-0.22, 0.22), random.uniform(-0.22, 0.22)))
            ln = min(length * random.uniform(0.7, 1.15), 0.24 * HS)
            quill(base, d, ln, random.uniform(0.007, 0.012) * HS * (1.3 if layer else 1.0), Vector((0, 0.25, -0.35)) * random.uniform(0.2, 0.8),
                  random.uniform(0.0, 1.0))
            HAIR_ROOTS.append(base)
            HAIR_TIPS.append(base + d.normalized() * ln)
mane_me = bpy.data.meshes.new("WickerMane")
hb.to_mesh(mane_me)
hb.free()
mane = bpy.data.objects.new("WickerMane", mane_me)
col.objects.link(mane)
rigid(mane, "mane", "Spike")

# Beard + moustache: coarser, shorter quills hanging from the jaw, chin and upper lip.
new_hair_bm()
MOUTH_Z = CHIN_Z + 0.32 * (EYE_Z - CHIN_Z)
beard_src = []
for c, nrm, b in zip(BODY_CO, BODY_N, DOM):
    if b == "head" and CHIN_Z - 0.005 < c.z < EYE_Z - 0.06 * HS and nrm.y < 0.15 and abs(c.x) < EAR_X * 0.8:
        if c.z > MOUTH_Z + 0.012 * HS and abs(c.x) < 0.02 * HS and nrm.y < -0.6:
            continue                                            # keep the lips/nose clear
        beard_src.append((c, nrm))
    elif b == "neck" and c.z > CHIN_Z - 0.04 * HS and nrm.y < -0.2:
        beard_src.append((c, nrm))
for c, nrm in poisson(beard_src, 75, 0.017 * HS):
    for q in range(3):
        off = Vector((random.uniform(-1, 1), random.uniform(-1, 1), random.uniform(-1, 1))) * 0.006 * HS
        d = nrm * 0.9 + Vector((0, -0.25, -0.8)) + Vector((random.uniform(-0.2, 0.2), random.uniform(-0.15, 0.15), 0))
        quill(c + off - nrm * 0.004, d, random.uniform(0.035, 0.075) * HS, random.uniform(0.008, 0.013) * HS,
              Vector((0, -0.1, -0.2)), random.uniform(0.0, 1.0))
beard_me = bpy.data.meshes.new("WickerBeard")
hb.to_mesh(beard_me)
hb.free()
hair = bpy.data.objects.new("WickerBeard", beard_me)
col.objects.link(hair)
rigid(hair, "beard", "Spike")


def hair_metrics():
    """Spiky-hair-not-a-crown checks (GOAL round 3)."""
    zs_r = [p.z for p in HAIR_ROOTS]
    hc = Vector((0, J["head"].y, EYE_Z))
    bins = set()
    for p in HAIR_ROOTS:
        bins.add(int((math.degrees(math.atan2(p.y - hc.y, p.x - hc.x)) + 360) % 360 // 10))
    tz = sorted(p.z for p in HAIR_TIPS)
    best = 0
    j = 0
    for i in range(len(tz)):
        while tz[i] - tz[j] > 0.06:
            j += 1
        best = max(best, i - j + 1)
    return {"hair_quills": len(HAIR_ROOTS), "root_height_span": (max(zs_r) - min(zs_r)) / HEAD_H,
            "root_azimuth_deg": len(bins) * 10, "tip_plane_frac": best / len(tz),
            "root_elev_std": (sum((z - sum(zs_r) / len(zs_r)) ** 2 for z in zs_r) / len(zs_r)) ** 0.5}

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
hair_idx = (straw_idx, MAT_ORDER.index("Spike"))
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
# Weave flow (round 3): one continuous frame for the whole torso (no panel seams
# between hips/spine/chest), strands fanning across the pecs and lats, vertical
# down the abs, and spiralling around the limbs. Angles are constant per panel.
TORSO = {"hips", "spine", "chest", "neck"}
TORSO_SEG = (Vector((0, J["pelvis"].y, J["pelvis"].z)), Vector((0, J["neck"].y, J["neck"].z)))
SPIRAL = {"forearm": 0.42, "shin": 0.36, "upper_arm": 0.2, "thigh": 0.18}


def flow(bone, c):
    """(angle, uv pivot) for the face at c."""
    cz = J["chest"].z
    if bone in TORSO:
        front = c.y < J["chest"].y
        if front and cz - 0.1 < c.z < cz + 0.17 and abs(c.x) > 0.035:
            return math.copysign(0.5, c.x), (0.0, cz)            # pecs fan out from the sternum
        if not front and J["waist"].z < c.z < cz + 0.12 and abs(c.x) > 0.05:
            return math.copysign(0.4, -c.x), (0.0, cz)           # lats sweep up into a V
        return 0.0, (0.0, 0.0)
    base, side = (bone.split(".") + ["C"])[:2]
    return SPIRAL.get(base, 0.0) * (1.0 if side == "L" else -1.0), (0.0, BONE_SEG[bone][0].z)
for poly in me.polygons:
    if poly.material_index in hair_idx:
        for li in poly.loop_indices:
            uv1.data[li].uv = (min(me.vertices[me.loops[li].vertex_index].co.z / HEIGHT, 1.0), 0.0)
        continue
    # Use the face's majority bone so a face never straddles two frames.
    bones = [vbone[me.loops[li].vertex_index] for li in poly.loop_indices]
    bone = max(set(bones), key=bones.count)
    h, t = TORSO_SEG if bone in TORSO else BONE_SEG[bone]
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
    fa, pivot = flow(bone, poly.center)
    ca, sa = math.cos(fa), math.sin(fa)
    for li, c in zip(poly.loop_indices, coords):
        u, v = c[0] * max(rmean, 0.03) - pivot[0], c[2] + h.z - pivot[1]
        if bone == "head":
            u, v = u * 2.6, v * 2.6                             # finer weave on the face
        uv0.data[li].uv = (u * ca - v * sa + pivot[0], u * sa + v * ca + pivot[1])
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


# Running: a driven, bent-knee stride. Contact on a flexed knee, absorb at
# mid-stance, extend through push-off, then the heel whips up toward the glute
# and the knee drives high before reaching for the next contact. Arms pump
# opposite the legs with the elbows locked near 90 degrees. Phase 0 = left contact.
STRIDE = [  # (phase, thigh, shin, foot); thigh < 0 is forward, shin > 0 bends the knee
    (0.0, -0.55, 0.38, -0.12), (0.125, -0.12, 0.7, 0.18), (0.25, 0.42, 0.42, 0.55), (0.375, 0.62, 1.35, 0.5),
    (0.5, 0.15, 2.15, 0.35), (0.625, -0.85, 1.95, 0.12), (0.75, -1.25, 1.25, -0.08), (0.875, -0.92, 0.6, -0.2),
]
THIGH_LEN = (J["hip.L"] - J["knee.L"]).length
SHIN_LEN = (J["knee.L"] - J["ankle.L"]).length


def reach(th, sh):
    """Vertical hip-to-ankle distance for a sagittal leg pose."""
    return THIGH_LEN * math.cos(th) + SHIN_LEN * math.cos(th + sh)


def run_cycle(length, leg, knee, arm, fore, lean, bob):
    keys = [(ph, th * leg, sh * knee, ft) for ph, th, sh, ft in STRIDE]
    n = len(keys)

    def at(i):
        return keys[i % n]

    frames = [length * ph for ph, *_ in keys] + [length]
    ch = {}
    for side, off in (("L", 0), ("R", n // 2)):
        seq = [at(i + off) for i in range(n)] + [at(off)]
        ch[f"thigh.{side}"] = {"rot": [(f, (k[1], 0, 0)) for f, k in zip(frames, seq)]}
        ch[f"shin.{side}"] = {"rot": [(f, (k[2], 0, 0)) for f, k in zip(frames, seq)]}
        ch[f"foot.{side}"] = {"rot": [(f, (k[3], 0, 0)) for f, k in zip(frames, seq)]}
        # Arm swings opposite its own leg; the elbow closes as the arm drives forward.
        ch[f"upper_arm.{side}"] = {"rot": [(f, (-k[1] / leg * arm, 0, 0)) for f, k in zip(frames, seq)]}
        ch[f"forearm.{side}"] = {"rot": [(f, (fore - 0.35 * max(0.0, k[1] / leg), 0, 0)) for f, k in zip(frames, seq)]}
    # Hips sit low on the stance leg (no foot sinking), float up through the flight phase.
    full = THIGH_LEN + SHIN_LEN
    hip = []
    for i in range(n + 1):
        ph, th, sh, _ = at(i)
        stance = ph <= 0.25 or 0.5 <= ph <= 0.75
        if ph < 0.5:
            r = reach(th, sh) if stance else None
        else:
            o = at(i + n // 2)
            r = reach(o[1], o[2]) if stance else None
        hip.append(-(full - r) if r is not None else None)
    for i in range(n + 1):
        if hip[i] is None:
            hip[i] = max(hip[(i - 1) % (n + 1)] or -0.05, hip[(i + 1) % (n + 1)] or -0.05) + bob
    ch["hips"] = {"loc": [(f, (0, h, 0)) for f, h in zip(frames, hip)]}
    tw = [(f, math.sin(math.tau * f / length)) for f in frames]
    ch["spine"] = {"rot": [(f, (lean, 0, 0.12 * v)) for f, v in tw]}
    ch["chest"] = {"rot": [(f, (lean * 0.4, 0, -0.2 * v)) for f, v in tw]}
    ch["head"] = {"rot": [(0, (-lean * 1.1, 0, 0)), (length, (-lean * 1.1, 0, 0))]}
    for side in ("L", "R"):
        ch[f"fingers.{side}"] = {"rot": [(0, (-1.1, 0, 0)), (length, (-1.1, 0, 0))]}   # loose fists
    return ch


make_action("walk", 32, cycle(32, 0.45, 0.35, 0.05, 0.6, -0.35, 0.03))
make_action("run", 20, run_cycle(20, 0.8, 0.85, 0.7, -1.35, 0.16, 0.025))
make_action("sprint", 14, run_cycle(14, 1.0, 1.0, 0.95, -1.55, 0.3, 0.04))


def ground_run(name, bob, passes=3):
    """Pin the stance foot to the ground: sample the lowest foot point at each stride
    key and shift the hips so stance keys touch z=0 and flight keys float `bob` above."""
    act = bpy.data.actions[name]
    rig.animation_data.action = act
    for t in rig.animation_data.nla_tracks:
        t.mute = True
    fcs = act.fcurves if hasattr(act, "fcurves") else [c for ly in act.layers for st in ly.strips for cb in st.channelbags for c in cb.fcurves]
    fc = next(c for c in fcs if c.data_path == 'pose.bones["hips"].location' and c.array_index == 1)
    length = act.frame_range[1]
    for _ in range(passes):
        lows = []
        for kp in fc.keyframe_points:
            scene.frame_set(int(kp.co.x), subframe=kp.co.x - int(kp.co.x))
            z = min((rig.matrix_world @ getattr(rig.pose.bones[b], e)).z
                    for b in ("foot.L", "foot.R", "toe.L", "toe.R") for e in ("head", "tail"))
            lows.append(z)
        for kp, z in zip(fc.keyframe_points, lows):
            ph = (kp.co.x / length) % 1.0
            stance = ph <= 0.25 + 1e-3 or 0.5 - 1e-3 <= ph <= 0.75 + 1e-3 or ph >= 1.0 - 1e-3
            target = 0.0 if stance else bob
            kp.co.y -= (z - target)
            kp.handle_left.y = kp.handle_right.y = kp.co.y
        fc.update()
    rig.animation_data.action = None
    for t in rig.animation_data.nla_tracks:
        t.mute = False
    scene.frame_set(0)


ground_run("run", 0.05)
ground_run("sprint", 0.09)
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
       "uv_layers": [u.name for u in me.uv_layers], **hair_metrics(),
       "limb_radius_var": LIMB_VAR}
with open("/tmp/wicker_build.json", "w") as f:
    json.dump(rep, f)
print("BUILD_WICKER_OK", rep)
