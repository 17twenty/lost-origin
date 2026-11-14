extends TestCase
## Summoning intro (weave-in).

func _intro() -> Node:
	return scene.get_node("SummonIntro")

func test_weave_in_completes_and_hands_over() -> void:
	await load_main(true)
	await physics_frames(3)
	var intro := _intro()
	var p := get_player()
	check_eq(intro.state, "playing", "intro playing on a new game")
	check(intro.progress < 0.2, "starts unwoven (%.2f)" % intro.progress)
	check(p.input_locked, "input locked during the intro")
	check(intro.cam != null and intro.cam.current, "intro camera is current")
	var glow: StandardMaterial3D = load("res://scenes/generated/totem_glow.tres")
	await seconds(1.0)
	check(glow.emission_energy_multiplier > 8.0, "totem eyes flare (%.1f)" % glow.emission_energy_multiplier)
	var t := 1.0
	while intro.state != "done" and t < 7.0:
		await seconds(0.25)
		t += 0.25
	check_eq(intro.state, "done", "intro finished within 7 s (t=%.2f)" % t)
	check(is_equal_approx(p.weave, 1.0), "fully woven (%.2f)" % p.weave)
	check(not p.input_locked, "control handed back")
	check(p.camera.current, "gameplay camera current")

func test_input_ignored_during_intro() -> void:
	await load_main(true)
	await physics_frames(3)
	var p := get_player()
	var start := p.global_position
	Input.action_press("move_forward")
	await seconds(1.0)
	Input.action_release("move_forward")
	check(Vector2(p.global_position.x - start.x, p.global_position.z - start.z).length() < 0.1, "player did not move while locked")

func test_any_key_skips() -> void:
	await load_main(true)
	await seconds(0.5)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ENTER
	ev.keycode = KEY_ENTER
	ev.pressed = true
	Input.parse_input_event(ev)
	await physics_frames(3)
	var up := InputEventKey.new()
	up.physical_keycode = KEY_ENTER
	up.keycode = KEY_ENTER
	up.pressed = false
	Input.parse_input_event(up)
	check_eq(_intro().state, "done", "skip ends the intro")
	check(is_equal_approx(get_player().weave, 1.0), "skip completes the weave")
	check(not get_player().input_locked, "skip unlocks input")

func test_respawn_reweaves() -> void:
	await load_main()
	var p := get_player()
	await seconds(0.3)
	p.global_position = Vector3(0, -50, 0)
	var dipped := false
	for i in 120:
		await tree.physics_frame
		if p.weave < 0.5:
			dipped = true
		if dipped and is_equal_approx(p.weave, 1.0):
			break
	check(dipped, "respawn starts a re-weave")
	check(is_equal_approx(p.weave, 1.0), "re-weave completes")

func test_summoning_ring_at_spawn() -> void:
	await load_main()
	var ring: Node3D = scene.get_node_or_null("Level/Outdoor/SummoningRing")
	if check(ring != null, "summoning ring exists"):
		check(ring.global_position.distance_to(marker_pos("Spawn")) < 0.5, "ring centred on the spawn")
