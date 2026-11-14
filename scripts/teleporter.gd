extends Area3D
## Teleporter pad trigger: sends any body with warp_to() to `target_path`
## (the other pad's Arrival marker) with a beam / spark / light flash at both ends.

signal teleported(body: Node3D)

@export var target_path: NodePath
@export var cooldown_frames := 45

static var _last_warp_frame := -1000
var flash_count := 0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.has_method("warp_to") or target_path.is_empty():
		return
	var now := Engine.get_physics_frames()
	if now - _last_warp_frame < cooldown_frames:
		return
	_last_warp_frame = now
	var target: Node3D = get_node(target_path)
	flash()
	var other := target.get_parent().get_node_or_null("Trigger")
	if other and other.has_method("flash"):
		other.flash()
	body.warp_to(target.global_transform)
	teleported.emit(body)


func flash() -> void:
	flash_count += 1
	var pad := get_parent()
	var beam: GeometryInstance3D = pad.get_node_or_null("Beam")
	var ring: Node3D = pad.get_node_or_null("Ring")
	var light: OmniLight3D = pad.get_node_or_null("Glow")
	var burst: GPUParticles3D = pad.get_node_or_null("Burst")
	if burst:
		burst.restart()
	var tw := create_tween().set_parallel(true)
	if beam:
		beam.visible = true
		beam.transparency = 0.0
		beam.scale = Vector3(0.6, 0.2, 0.6)
		tw.tween_property(beam, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(beam, "transparency", 1.0, 0.9).set_delay(0.2)
		tw.chain().tween_callback(func(): beam.visible = false)
	if ring:
		var base := ring.scale
		ring.scale = base * Vector3(1.6, 3.0, 1.6)
		tw.tween_property(ring, "scale", base, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if light:
		light.light_energy = 12.0
		tw.tween_property(light, "light_energy", 2.0, 0.8)
