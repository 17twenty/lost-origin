# Godot scene editing

**Do not edit `.tscn` and `.tres` files by hand at scale.** The parser is
tolerable for one property, but any restructuring — adding or moving nodes,
meshes, ext/sub-resource references — is better done through the tools,
because the `.tscn` format is last-author-wins and one bad splice breaks a
whole file with no diagnostics until *after* the change has shipped.

The project already has the pattern:

- **`tests/test_case.gd`** — for anything you are validating or tuning
  mechanically. Run something first, measure it, then change. Do not write
  code that cannot be checked.
- **`tools/`** — generators that write files, validated in the same
  `tools/validate.sh` gate as everything else. The brass tacks.
- **`art/concepts/`** — FLUX.2-klein reference images, one PNG plus the
  generator-log sidecar that records the prompt and sizes. When you change a
  mesh, the reference you were aiming for is traceable.

## What to do when you need to change a scene

In descending order of preference:

1. **A tool that writes the file.** `tools/generate_concept.py` is the pattern:
   read, transform, write, record. For scenes the same applies — build the new
   scene myself in code that can be re-run and re-validated. Always. The scene
   I almost destroyed was damaged precisely because I tried to do it inline.

2. **The Godot editor, driven externally but visibly.** This is the main
   reason for the available MCP tooling: the running editor is the actual
   source of truth, and driving it over a tool interface is safer than
   line-edits.

3. **A parser that reads the format.** If neither of the above suits, write a
   parser. Read the thing, transform the thing, write the thing. Do not write
   against a regex over text.

## What not to do

- Do not build huge one-off splicer scripts that depend on the file's current
  text staying precisely as expected.
- Do not assume a "probably harmless" structural edit only needs to be close.
  The error that corrupted the player scene looked exactly like that.
- Do not promise "quick wins" in `.tscn` files. The advantages of doing it by
  hand are the ones I am failing to defend right now, and the cost of being
  wrong is an unrenderable asset.

## A note on what's *not* here

There is no MCP registered against this project as of writing. Earlier versions
of this file referenced "available MCP servers" as if they were installed and
proven; they were researched on the web but not configured on this machine.
That has been corrected.

The tooling that exists locally for scene work is:

- the `tools/` generators, which emit files
- `tools/capture_screenshot.gd`, which renders them
- the engine itself, which is the actual source of truth

Everything else is speculation until an MCP is installed and verified. If one
is added later, this file should be revised to note where it sits and how to
invoke it.
