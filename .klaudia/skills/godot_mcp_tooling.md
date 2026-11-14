# Using the Godot MCPs

Two are registered and both point at
`/Applications/Godot.app/Contents/MacOS/Godot`. They are invoked through the
MCP layer as `mcp__grt__*` and `mcp__gsol__*` once connected. Check the tool
list before writing code against them; both expose a lot, and you will save
yourself a false start by looking first.

## Which one to use

They split along a line the documentation itself draws.

- **`gsol`** ("eyes and hands in the Godot editor") is for *making* changes:
  scene editing, script editing, input injection, deterministic game-time
  control, playtests, screenshots. When a change needs to happen in the actual
  editor and the editor needs to show it, this is the one to reach for.
  Deterministic game-time control is the part that matters for testing: the
  game can be stepped a fixed number of frames rather than run in real time,
  which is how you make a playtest reproducible. Use it against a *running
  editor or project*.

- **`grt`** is for *playing back* against a running game, coordinating play
  sessions rather than authoring.

In practice: `gsol` to change the map, `grt` to watch how it plays.

## How to be sure they're present

`claude mcp list` from a klaudia terminal. If the names `grt` and `gsol` come
back with a "Connected" status, they're there. Do not assume that seeing a
name in `/Users/nickglynn/.klaudia/.mcp.json` means the session has loaded it.

If MCP tools from these servers reproduce parse errors validating a script that only
mentions an autoload singleton, that is likely a known pattern from a sibling
3.1 fix in another Godot MCP server and may be same-shaped here. Do not treat
"the tool validates it" as a reason to break project conventions just to make
the parse pass.
