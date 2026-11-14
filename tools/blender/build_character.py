"""Build the 'Wayfinder' armoured explorer: low-poly mesh, rigid-skinned rig,
idle/run/sprint/jump actions, exported to assets/characters/explorer.glb.

Run: Blender -b -P tools/blender/build_character.py
Conventions (see .klaudia/skills/blender_glb_pipeline.md): built Z-up, front = -Y
(becomes +Z in Godot), export_apply=False, actions pushed to NLA.
"""
import bpy
import bmesh
import json
import math
import os
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_GLB = os.path.join(ROOT, "assets", "characters", "explorer.glb")
OUT_BLEND = os.path.join(ROOT, "assets", "characters", "src", "explorer.blend")
FPS = 30

# ---------------------------------------------------------------- scene reset
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = FPS


def material(name, color, rough=0.5, metal=0.0, emit=None, strength=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emit:
        bsdf.inputs["Emission Color"].default_value = (*emit, 1.0)
        bsdf.inputs["Emission Strength"].default_value = strength
    return m


MATS = {
    "armor": material("Armor", (0.85, 0.42, 0.12), 0.35, 0.3),
    "suit": material("Undersuit", (0.08, 0.09, 0.11), 0.8, 0.1),
    "trim": material("Trim", (0.75, 0.78, 0.8), 0.3, 0.8),
    "glow": material("Glow", (0.2, 0.9, 1.0), 0.2, 0.0, (0.2, 0.9, 1.0), 6.0),
}

# ------------------------------------------------------------------- bones
# name: (head, tail, parent)
BONES = {
    "root": ((0, 0, 0), (0, 0.25, 0), None),
    "hips": ((0, 0, 0.93), (0, 0, 1.05), "root"),
    "spine": ((0, 0, 1.05), (0, 0, 1.25), "hips"),
    "chest": ((0, 0, 1.25), (0, 0, 1.48), "spine"),
    "head": ((0, 0, 1.5), (0, 0, 1.82), "chest"),
}
for side, sx in (("L", 1), ("R", -1)):
    BONES[f"upper_arm.{side}"] = ((0.29 * sx, 0, 1.43), (0.3 * sx, 0, 1.12), "chest")
    BONES[f"forearm.{side}"] = ((0.3 * sx, 0, 1.12), (0.3 * sx, 0, 0.82), f"upper_arm.{side}")
    BONES[f"thigh.{side}"] = ((0.12 * sx, 0, 0.93), (0.12 * sx, 0, 0.5), "hips")
    BONES[f"shin.{side}"] = ((0.12 * sx, 0, 0.5), (0.12 * sx, 0, 0.07), f"thigh.{side}")

arm_data = bpy.data.armatures.new("WayfinderRig")
rig = bpy.data.objects.new("WayfinderRig", arm_data)
scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
for name, (h, t, _p) in BONES.items():
    eb = arm_data.edit_bones.new(name)
    eb.head = h
    eb.tail = t
    eb.roll = 0.0
for name, (_h, _t, p) in BONES.items():
    if p:
        arm_data.edit_bones[name].parent = arm_data.edit_bones[p]
        if name in ("forearm.L", "forearm.R", "shin.L", "shin.R", "spine", "chest"):
            arm_data.edit_bones[name].use_connect = True
bpy.ops.object.mode_set(mode="OBJECT")
rig.select_set(False)

# -------------------------------------------------------------------- mesh
parts = []


def part(kind, bone, mat, loc, size, bevel=0.025, rot=(0, 0, 0)):
    """Create a primitive part rigidly bound to `bone`."""
    if kind == "box":
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    elif kind == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.5, location=loc, rotation=rot)
    elif kind == "cyl":
        bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.5, depth=1.0, location=loc, rotation=rot)
    ob = bpy.context.active_object
    ob.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel and kind == "box":
        mod = ob.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        bpy.ops.object.modifier_apply(modifier="bevel")
    ob.data.materials.append(MATS[mat])
    vg = ob.vertex_groups.new(name=bone)
    vg.add([v.index for v in ob.data.vertices], 1.0, "REPLACE")
    parts.append(ob)
    return ob


# Legs
for side, sx in (("L", 1), ("R", -1)):
    x = 0.12 * sx
    part("box", f"shin.{side}", "suit", (x, 0, 0.3), (0.13, 0.15, 0.44))
    part("box", f"shin.{side}", "armor", (x, -0.05, 0.32), (0.15, 0.08, 0.3))  # shin guard
    part("box", f"shin.{side}", "trim", (x, -0.04, 0.06), (0.16, 0.27, 0.12))  # boot
    part("box", f"thigh.{side}", "suit", (x, 0, 0.72), (0.16, 0.18, 0.44))
    part("box", f"thigh.{side}", "armor", (x + 0.02 * sx, -0.03, 0.75), (0.15, 0.15, 0.28))
    part("box", f"thigh.{side}", "trim", (x, -0.07, 0.5), (0.12, 0.08, 0.08))  # knee
# Pelvis / torso
part("box", "hips", "suit", (0, 0, 0.98), (0.36, 0.22, 0.16))
part("box", "hips", "trim", (0, -0.1, 0.98), (0.2, 0.06, 0.1))
part("box", "spine", "suit", (0, 0, 1.15), (0.3, 0.2, 0.22))
part("box", "chest", "armor", (0, 0, 1.36), (0.46, 0.3, 0.3), bevel=0.05)
part("box", "chest", "armor", (0, -0.06, 1.24), (0.36, 0.22, 0.12))
part("box", "chest", "glow", (0, -0.155, 1.36), (0.12, 0.02, 0.05), bevel=0.0)  # chest light
part("box", "chest", "trim", (0, 0.2, 1.33), (0.32, 0.14, 0.34), bevel=0.04)  # backpack
part("cyl", "chest", "glow", (0.11, 0.28, 1.33), (0.05, 0.05, 0.24))  # pack coils
part("cyl", "chest", "glow", (-0.11, 0.28, 1.33), (0.05, 0.05, 0.24))
part("cyl", "chest", "suit", (0, 0, 1.52), (0.12, 0.12, 0.08))  # neck
# Helmet
part("sphere", "head", "armor", (0, 0, 1.65), (0.26, 0.29, 0.28))
part("box", "head", "suit", (0, -0.1, 1.62), (0.22, 0.12, 0.12))
part("box", "head", "glow", (0, -0.16, 1.645), (0.2, 0.04, 0.055), bevel=0.0)  # visor slit
part("box", "head", "trim", (0, 0.02, 1.79), (0.05, 0.22, 0.04))  # crest
part("box", "head", "trim", (0.13, 0, 1.64), (0.03, 0.12, 0.1))  # ear pods
part("box", "head", "trim", (-0.13, 0, 1.64), (0.03, 0.12, 0.1))
# Arms
for side, sx in (("L", 1), ("R", -1)):
    x = 0.3 * sx
    part("box", f"upper_arm.{side}", "armor", (0.31 * sx, 0, 1.45), (0.2, 0.22, 0.13), bevel=0.04)  # pauldron
    part("box", f"upper_arm.{side}", "suit", (x, 0, 1.27), (0.11, 0.12, 0.3))
    part("box", f"forearm.{side}", "armor", (x, 0, 0.97), (0.13, 0.14, 0.27))
    part("box", f"forearm.{side}", "glow", (x + 0.066 * sx, 0, 0.99), (0.01, 0.05, 0.14), bevel=0.0)
    part("box", f"forearm.{side}", "suit", (x, -0.01, 0.78), (0.09, 0.1, 0.1))  # hand

for p in parts:
    p.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
body = bpy.context.active_object
body.name = "WayfinderMesh"
body.data.name = "WayfinderMesh"
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.ops.object.shade_flat()
body.parent = rig
mod = body.modifiers.new("Armature", "ARMATURE")
mod.object = rig

# -------------------------------------------------------------- animation
rig.animation_data_create()
for pb in rig.pose.bones:
    pb.rotation_mode = "XYZ"


def wave(frames, values):
    return list(zip(frames, values))


def make_action(name, length, channels):
    """channels: {bone: {"rot": [(frame,(x,y,z)),...], "loc": [...]}}.
    Every bone gets keys at frame 0 and `length` so actions never inherit pose."""
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
    return act


def cycle(length, amp_thigh, amp_arm, lean, knee, fore, bob):
    """Run-style loop. Negative X rotation swings a down-pointing bone forward."""
    q = length // 4
    fr = [0, q, 2 * q, 3 * q, length]
    s = [-1, 0, 1, 0, -1]  # left thigh phase
    ch = {
        "thigh.L": {"rot": [(f, (amp_thigh * v, 0, 0)) for f, v in zip(fr, s)]},
        "thigh.R": {"rot": [(f, (-amp_thigh * v, 0, 0)) for f, v in zip(fr, s)]},
        # knee bends most while the leg recovers forward
        "shin.L": {"rot": [(f, (k, 0, 0)) for f, k in zip(fr, [knee * 0.4, knee * 0.2, knee * 0.5, knee, knee * 0.4])]},
        "shin.R": {"rot": [(f, (k, 0, 0)) for f, k in zip(fr, [knee * 0.5, knee, knee * 0.4, knee * 0.2, knee * 0.5])]},
        "upper_arm.L": {"rot": [(f, (-amp_arm * v, 0, -0.08)) for f, v in zip(fr, s)]},
        "upper_arm.R": {"rot": [(f, (amp_arm * v, 0, 0.08)) for f, v in zip(fr, s)]},
        "forearm.L": {"rot": [(0, (fore, 0, 0)), (length, (fore, 0, 0))]},
        "forearm.R": {"rot": [(0, (fore, 0, 0)), (length, (fore, 0, 0))]},
        "spine": {"rot": [(f, (lean, 0, 0.12 * v)) for f, v in zip(fr, s)]},
        "chest": {"rot": [(f, (lean * 0.5, 0, -0.18 * v)) for f, v in zip(fr, s)]},
        "head": {"rot": [(0, (-lean * 1.2, 0, 0)), (length, (-lean * 1.2, 0, 0))]},
        # hips bone points up: local Y is world up
        "hips": {"loc": [(f, (0, b, 0)) for f, b in zip(fr, [0, -bob, 0, -bob, 0])]},
    }
    return ch


make_action("run", 20, cycle(20, 0.75, 0.6, 0.15, 1.0, -0.7, 0.05))
make_action("sprint", 16, cycle(16, 1.0, 0.9, 0.38, 1.4, -1.3, 0.08))
make_action("idle", 60, {
    "chest": {"rot": [(0, (0, 0, 0)), (30, (0.05, 0, 0)), (60, (0, 0, 0))]},
    "head": {"rot": [(0, (0, 0, 0)), (30, (-0.04, 0.0, 0.05)), (60, (0, 0, 0))]},
    "upper_arm.L": {"rot": [(0, (0, 0, -0.12)), (30, (0.04, 0, -0.16)), (60, (0, 0, -0.12))]},
    "upper_arm.R": {"rot": [(0, (0, 0, 0.12)), (30, (0.04, 0, 0.16)), (60, (0, 0, 0.12))]},
    "forearm.L": {"rot": [(0, (-0.25, 0, 0)), (60, (-0.25, 0, 0))]},
    "forearm.R": {"rot": [(0, (-0.25, 0, 0)), (60, (-0.25, 0, 0))]},
    "hips": {"loc": [(0, (0, 0, 0)), (30, (0, -0.012, 0)), (60, (0, 0, 0))]},
})
make_action("jump", 12, {
    "thigh.L": {"rot": [(0, (-0.3, 0, 0)), (6, (-1.1, 0, 0)), (12, (-1.0, 0, 0))]},
    "thigh.R": {"rot": [(0, (0.1, 0, 0)), (6, (-0.2, 0, 0)), (12, (-0.3, 0, 0))]},
    "shin.L": {"rot": [(0, (0.6, 0, 0)), (6, (1.5, 0, 0)), (12, (1.4, 0, 0))]},
    "shin.R": {"rot": [(0, (0.3, 0, 0)), (6, (0.9, 0, 0)), (12, (0.8, 0, 0))]},
    "upper_arm.L": {"rot": [(0, (-0.4, 0, -0.3)), (6, (-0.9, 0, -0.5)), (12, (-0.8, 0, -0.5))]},
    "upper_arm.R": {"rot": [(0, (0.3, 0, 0.3)), (6, (0.5, 0, 0.6)), (12, (0.4, 0, 0.6))]},
    "forearm.L": {"rot": [(0, (-0.8, 0, 0)), (12, (-0.8, 0, 0))]},
    "forearm.R": {"rot": [(0, (-0.6, 0, 0)), (12, (-0.6, 0, 0))]},
    "spine": {"rot": [(0, (0.1, 0, 0)), (12, (0.2, 0, 0))]},
    "head": {"rot": [(0, (-0.1, 0, 0)), (12, (-0.15, 0, 0))]},
})

# ----------------------------------------------------------------- export
os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
bpy.ops.object.select_all(action="DESELECT")
rig.select_set(True)
body.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(
    filepath=OUT_GLB,
    export_format="GLB",
    export_apply=False,
    export_animations=True,
    export_animation_mode="ACTIONS",
    export_nla_strips=True,
    use_selection=True,
    export_skins=True,
    export_yup=True,
)
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)

zs = [v.co.z for v in body.data.vertices]
report = {
    "verts": len(body.data.vertices),
    "z_range": [min(zs), max(zs)],
    "bones": [b.name for b in arm_data.bones],
    "actions": sorted(a.name for a in bpy.data.actions),
}
with open("/tmp/explorer_build.json", "w") as f:
    json.dump(report, f, indent=1)
print("BUILD_CHARACTER_OK", json.dumps(report))
