class_name LevelConnector
## Seamless walk from the grotto down into the facility (no loading):
##   A  grotto east door (z -64..-68) -> flat tunnel east to x = 17 at y 0.32
##   B  enclosed ramp south along x 13.4..17.0 from z -68 to -84, down to F = -6
##   C  flat bottom z -84..-90.5, door east into the facility vestibule (x 16.4..17.2)
## Also links the two teleporter pads to each other's Arrival marker.

const O := preload("res://tools/level/outdoor.gd")
const FAC := preload("res://tools/level/facility.gd")
const TOP_Y := 0.32
const X0 := 13.4
const X1 := 17.0
const H := 3.4
const T := 0.5

static func build(level: Node3D, markers: Node3D, shots: Node3D) -> void:
	var c := SceneUtil.add(level, Node3D.new(), "Connector")
	var shell := CSGCombiner3D.new()
	shell.name = "Shell"
	shell.use_collision = true
	c.add_child(shell)
	var F := FAC.F
	var xc := (X0 + X1) * 0.5
	var w := X1 - X0
	var ramp_len := 16.0
	var drop := TOP_Y - F
	var ang := atan2(drop, ramp_len)
	var slope := sqrt(ramp_len * ramp_len + drop * drop)
	var sub := CSGShape3D.OPERATION_SUBTRACTION
	var top := TOP_Y + H
	# --- A: flat tunnel from the grotto door; B+C: one tall shaft with a ramp body.
	_box(shell, Vector3(17.5 - 9.8 + T, H + 2 * T, 4 + 2 * T), Vector3((17.5 + 9.8) * 0.5, TOP_Y + H * 0.5, -66), O.rock_mat)
	# Shaft runs from z -67.9 down to the garden's north wall (z -93).
	_box(shell, Vector3(w + 2 * T, top - F + 2 * T, 25.6), Vector3(xc, (top + F) * 0.5, -80.2), FAC.metal)
	_box(shell, Vector3(17.0 - 9.5, H, 4.0), Vector3((17.0 + 9.5) * 0.5, TOP_Y + H * 0.5, -66), O.rock_mat, sub)
	_box(shell, Vector3(w, top - F, 26.1), Vector3(xc, (top + F) * 0.5, -80.95), FAC.metal_dark, sub)
	# Cap the shaft's south end above the garden ceiling (y 2.6+).
	_box(shell, Vector3(w + 2 * T, top + T - 2.6, 2.2), Vector3(xc, (top + T + 2.6) * 0.5, -93.4), FAC.metal)
	# Ramp: top surface runs from (z -68, y 0.32) to (z -84, y F).
	var ramp := SceneUtil.box_body(Vector3(w, 0.3, slope), Vector3(xc, (TOP_Y + F) * 0.5 - 0.15 / cos(ang), -76), FAC.metal, "Ramp")
	ramp.rotation.x = -ang
	c.add_child(ramp)

	# The A tunnel pierces the grotto slot's terrain wall (x 11..13.4).
	var hole_min := Vector3(9.4, TOP_Y - 0.6, -68.6)
	var hole_max := Vector3(14.0, TOP_Y + H + 0.6, -63.4)
	var terrain_mat: ShaderMaterial = (level.get_node("Outdoor/Terrain/Mesh") as MeshInstance3D).material_override
	terrain_mat.set_shader_parameter("hole_min", hole_min)
	terrain_mat.set_shader_parameter("hole_max", hole_max)
	var pass_area := Area3D.new()
	pass_area.name = "TerrainPassthrough"
	pass_area.set_script(load("res://scripts/terrain_passthrough.gd"))
	pass_area.collision_layer = 0
	pass_area.collision_mask = 2
	var pcs := CollisionShape3D.new()
	var pbs := BoxShape3D.new()
	pbs.size = hole_max - hole_min + Vector3(1.0, 0, 0)
	pcs.shape = pbs
	pass_area.add_child(pcs)
	pass_area.position = (hole_min + hole_max) * 0.5
	c.add_child(pass_area)

	# Doors through the neighbouring shells.
	var grotto_shell: CSGCombiner3D = level.get_node("Outdoor/Grotto/Shell")
	_box(grotto_shell, Vector3(4.0, H, 4.0), Vector3(11.5, TOP_Y + H * 0.5, -66), O.rock_mat, sub)

	# Forerunner door frame on the grotto side + trim/lights down the tunnel.
	for y in [TOP_Y + H - 0.05]:
		FAC._strip(c, Vector3(0.15, 0.1, 4.2), Vector3(9.95, y, -66))
	for z in [-63.95, -68.05]:
		FAC._strip(c, Vector3(0.15, H, 0.1), Vector3(9.95, TOP_Y + H * 0.5, z))
		FAC._strip(c, Vector3(7.0, 0.06, 0.08), Vector3(13.5, TOP_Y + 0.05, z + (0.05 if z > -66 else -0.05) * -1.0))
	for x in [X0 + 0.05, X1 - 0.05]:
		var s := FAC._strip(c, Vector3(0.08, 0.06, slope), Vector3(x, (TOP_Y + F) * 0.5 + 0.05, -76))
		s.rotation.x = -ang
		FAC._strip(c, Vector3(0.08, 0.06, 9.0), Vector3(x, F + 0.05, -88.5))
	FAC._hex_floor(c, Vector2(7.0, 4.0), Vector3(13.5, TOP_Y, -66))
	FAC._hex_floor(c, Vector2(w, 9.0), Vector3(xc, F, -88.5))
	FAC._light(c, Vector3(12.0, TOP_Y + H - 0.4, -66), Color(0.5, 0.9, 1.0), 1.2, 7.0)
	FAC._light(c, Vector3(xc, TOP_Y - 1.0 + H - 0.6, -72), Color(0.5, 0.9, 1.0), 1.0, 7.0)
	FAC._light(c, Vector3(xc, F + 2.0 + H - 0.6, -80), Color(0.5, 0.9, 1.0), 1.0, 7.0)
	FAC._light(c, Vector3(xc, F + H - 0.4, -87.5), Color(0.5, 0.9, 1.0), 1.2, 7.0)

	O.camera_zone(c, "CamTunnel", Vector3(9.0, 12.0, 32.0), Vector3(14.0, -2.5, -78.0), 2.6, -0.1)
	var zones := {
		"Zone_GrottoDoor": Vector3(8.0, TOP_Y, -66),
		"Zone_TunnelTop": Vector3(xc, TOP_Y, -66),
		"Zone_RampMid": Vector3(xc, (TOP_Y + F) * 0.5, -76),
		"Zone_TunnelBottom": Vector3(xc, F, -87.5),
	}
	for n in zones:
		SceneUtil.marker(markers, n, zones[n] + Vector3(0, 0.05, 0))
	var shot := SceneUtil.marker(shots, "Shot_Tunnel", Vector3(xc - 0.8, TOP_Y + 2.3, -67.2), Vector3(xc, (TOP_Y + F) * 0.5, -80))
	shot.set_meta("player_pos", Vector3(xc + 0.6, TOP_Y - 1.2, -71.0))

	# Teleporters: each pad sends you to the other pad's Arrival marker.
	var gp: Node3D = level.get_node("Outdoor/Grotto/TeleporterGrotto")
	var fp: Node3D = level.get_node("Facility/ControlRoom/TeleporterFacility")
	var gt: Area3D = gp.get_node("Trigger")
	var ft: Area3D = fp.get_node("Trigger")
	gt.target_path = gt.get_path_to(fp.get_node("Arrival"))
	ft.target_path = ft.get_path_to(gp.get_node("Arrival"))

static func _box(parent: Node, size: Vector3, pos: Vector3, mat: Material, op := CSGShape3D.OPERATION_UNION) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.size = size
	b.position = pos
	b.operation = op
	b.material = mat
	parent.add_child(b)
	return b
