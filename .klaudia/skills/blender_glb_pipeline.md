# Blender GLB pipeline

How to get a rigged, animated mesh out of this project's Blender session and
into Godot without breaking it, in the order things have actually failed.

## Reach Blender

The MCP addon (`~/Projects/blender-mcp/`, ported from `ricky-yosh/blender-mcp`)
runs a JSON-over-TCP server on 127.0.0.1:9877 inside the live Blender session.
Two equivalent drivers:

- **`tools/blender_socket.py`** in this repo — one-shot command. Use for any
  Blender query or mutation.

    ```sh
    python3 tools/blender_socket.py '{"command":"get_scene_info"}'
    python3 tools/blender_socket.py '{"command":"execute_python","code":"..."}'
    ```

- **`~/Projects/blender-mcp-go/`** — Go stdio MCP bridge that exposes the same
  commands as MCP tools (`blender_*`). Build from that directory:

    ```sh
    cd ~/Projects/blender-mcp-go && go build -o blender-mcp-go .
    ```

  Registered in `~/.klaudia/.mcp.json` if we want it on all the time.

## Trap: print output is swallowed

`execute_python` returns `{"executed":true,"output":""}`. The addon routes
`print` to the Blender console, not back over the socket. Always **write
results to `/tmp/*.json` inside the Blender snippet** and read them with a
shell command afterwards.

```python
import bpy, json
result = {"bones": [b.name for b in bpy.data.objects["character_rig"].data.bones]}
with open("/tmp/bones.json", "w") as f: f.write(json.dumps(result))
```

## Trap: axis convention

Blender is Z-up. Godot is Y-up. The glTF exporter converts, **but only via
node transforms**. If the mesh data and the armature are not built against
the same axis, the export writes a mesh and rig that disagree by 90° and
Godot renders the mesh in its bind pose lying flat on the floor.

Symptom: a skinned model renders as a white splat at y=0 with the skeleton
standing upright above it, invisible.

Diagnostic: dump vertex bounds and bone head positions.

```python
mesh = bpy.data.objects["worker_mesh"]
ys = [v.co.y for v in mesh.data.vertices]
zs = [v.co.z for v in mesh.data.vertices]
# If max(ys) is ~2 and max(zs) is ~0, the mesh is Y-up in a Z-up world.
```

Fix: rotate the mesh *data* (not the object) so it matches the armature's
axis, then bind.

```python
import mathutils, math
mesh = bpy.data.objects["worker_mesh"]
rot = mathutils.Matrix.Rotation(math.radians(90.0), 4, "X")
for v in mesh.data.vertices:
    v.co = rot @ v.co
mesh.data.update()
```

Build meshes Z-up in the first place for any new character.

## Trap: `export_apply=True` bakes the armature modifier

`bpy.ops.export_scene.gltf(export_apply=True)` applies modifiers on export.
With an Armature modifier present, that *bakes the mesh in its rest pose and
drops the skin*. The GLB then contains a mesh and a skeleton but no skin
linking them, and Godot renders an unanimated block.

Always export skinned models with `export_apply=False`:

```python
bpy.ops.export_scene.gltf(
    filepath=path,
    export_format="GLB",
    export_apply=False,
    export_animations=True,
    export_animation_mode="ACTIONS",
    export_nla_strips=True,
    use_selection=True,
    export_skins=True,
)
```

## Trap: action assignment clobbers NLA

Setting `arm.animation_data.action = bpy.data.actions.new("idle")` replaces
the active action, which orphans what was there before the next time you
export with `export_animation_mode="ACTIONS"`. The exporter sees only the
active action.

Safe pattern: create each action, keyframe it, then push to NLA explicitly,
and leave the active action cleared when done.

```python
for name in ["idle", "walk", "attack_light", "stagger", "death"]:
    action = bpy.data.actions.new(name)
    track = arm.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 1, action)
arm.animation_data.action = None
```

## Verify before integrating in Godot

Three cheap sanity passes before touching any `.tscn`:

1. **Parse the GLB header in Python** (`struct.unpack('<III', ...)`) and check
   that `meshes`, `skins`, and `animations` are all non-empty with the right
   names. Five clips is the contract: `idle`, `walk`, `attack_light`,
   `stagger`, `death`.
2. **Boot Godot headless with a diagnostic script** that loads the scene and
   dumps the node tree. A skinned mesh appears as
   `Skeleton3D -> MeshInstance3D`. If `MeshInstance3D` is elsewhere or
   missing, the export dropped the skin.
3. **Render the actual game scene** with `tools/capture_screenshot.gd` and
   look at the result from the in-game camera. Anything else — Blender's own
   viewport, a three-quarter rig-shot — lies about composition.
