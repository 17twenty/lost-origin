extends TestCase
## Player controller tests on a code-built fixture (flat floor + wall).

var player: CharacterBody3D

func _fixture() -> void:
	scene = Node3D.new()
	scene.name = "Fixture"
	tree.root.add_child(scene)
	scene.add_child(SceneUtil.box_body(Vector3(100, 1, 100), Vector3(0, -0.5, 0), null, "Floor"))
	# Wall 1.5 m behind the spawn (+Z), tall enough to block the camera arm.
	scene.add_child(SceneUtil.box_body(Vector3(20, 6, 0.5), Vector3(0, 3, 1.5), null, "Wall"))
	player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	scene.add_child(player)
	player.global_position = Vector3(0, 0.1, 0)
	await physics_frames(10)

func test_spawns_grounded_and_idle() -> void:
	await _fixture()
	await seconds(0.5)
	check(player.is_on_floor(), "player on floor")
	check(abs(player.global_position.y) < 0.1, "feet at y≈0 (y=%.3f)" % player.global_position.y)
	check_eq(player.anim_state, "idle", "anim state")

func test_forward_input_accelerates_with_momentum() -> void:
	await _fixture()
	Input.action_press("move_forward")
	await physics_frames(3)
	var early := Vector2(player.velocity.x, player.velocity.z).length()
	check(early > 0.1 and early < player.run_speed * 0.6, "accelerates gradually (v=%.2f)" % early)
	await seconds(1.0)
	var z0: float = player.global_position.z
	var v := Vector2(player.velocity.x, player.velocity.z).length()
	check(abs(v - player.run_speed) < 0.2, "reaches run speed (v=%.2f)" % v)
	check(player.global_position.z < -2.0, "moved forward along -Z (z=%.2f)" % z0)
	check_eq(player.anim_state, "run", "anim state while running")
	var pb: AnimationNodeStateMachinePlayback = player.anim_tree.get("parameters/playback")
	await physics_frames(20)
	check_eq(String(pb.get_current_node()), "run", "AnimationTree playing run")
	Input.action_release("move_forward")
	await physics_frames(3)
	var coast := Vector2(player.velocity.x, player.velocity.z).length()
	check(coast > 0.5, "decelerates rather than stopping dead (v=%.2f)" % coast)
	await seconds(1.0)
	check_eq(player.anim_state, "idle", "back to idle after stopping")

func test_sprint_is_faster() -> void:
	await _fixture()
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await seconds(1.5)
	var v := Vector2(player.velocity.x, player.velocity.z).length()
	check(abs(v - player.sprint_speed) < 0.3, "sprint speed (v=%.2f)" % v)
	check_eq(player.anim_state, "sprint", "anim state sprint")

func test_jump_leaves_ground_and_lands() -> void:
	await _fixture()
	Input.action_press("jump")
	await physics_frames(10)
	check(player.global_position.y > 0.4, "airborne after jump (y=%.2f)" % player.global_position.y)
	check_eq(player.anim_state, "jump", "anim state jump")
	await seconds(1.5)
	check(player.is_on_floor(), "landed")
	Input.action_release("jump")

func test_model_faces_move_direction() -> void:
	await _fixture()
	Input.action_press("move_right")
	await seconds(1.0)
	# Model front is +Z; moving +X should rotate it to yaw ≈ +90°.
	check(abs(wrapf(player.model.rotation.y - PI / 2, -PI, PI)) < 0.15, "model yaw %.2f" % player.model.rotation.y)

func test_camera_collides_with_wall() -> void:
	await _fixture()
	await physics_frames(5)
	var dist: float = player.spring_arm.get_hit_length()
	check(dist < 1.6, "spring arm shortened by wall behind player (len=%.2f)" % dist)
	# Turn around: camera now behind on the open side → full length.
	player.look_input = Vector2(PI, 0)
	await physics_frames(5)
	dist = player.spring_arm.get_hit_length()
	check(dist > 3.0, "full arm length in open space (len=%.2f)" % dist)

func test_wicker_has_full_clip_set_and_thumbs() -> void:
	await _fixture()
	var ap: AnimationPlayer = player.anim_tree.get_node(player.anim_tree.anim_player)
	for c in ["idle", "walk", "run", "sprint", "jump", "fall", "land", "swim", "interact", "look_around", "summon"]:
		check(ap.has_animation(c), "clip %s" % c)
	var skel: Skeleton3D = player.model.find_children("*", "Skeleton3D", true, false)[0]
	check(skel.find_bone("thumb.L") >= 0 and skel.find_bone("thumb.R") >= 0, "thumb bones")
	check(skel.get_bone_count() >= 24, "humanoid rig (%d bones)" % skel.get_bone_count())

func test_walk_fall_land_states() -> void:
	await _fixture()
	Input.action_press("move_forward")
	await physics_frames(6)
	check_eq(player.anim_state, "walk", "slow start plays walk (v=%.2f)" % Vector2(player.velocity.x, player.velocity.z).length())
	Input.action_release("move_forward")
	await seconds(1.0)
	player.global_position = Vector3(0, 6, 0)
	await seconds(0.5)
	check_eq(player.anim_state, "fall", "falling from height plays fall")
	var saw_land := false
	for i in 90:
		await tree.physics_frame
		if player.anim_state == "land":
			saw_land = true
			break
	check(saw_land, "touchdown plays land")

func test_look_around_after_idling() -> void:
	await _fixture()
	await seconds(8.6)
	check_eq(player.anim_state, "look_around", "curious look-around after ~8 s idle")
	Input.action_press("move_forward")
	await physics_frames(10)
	check(player.anim_state != "look_around", "moving cancels look-around")

func test_oneshot_interact() -> void:
	await _fixture()
	player.play_oneshot("interact")
	await physics_frames(5)
	check_eq(player.anim_state, "interact", "interact one-shot plays")
	await seconds(1.3)
	check_eq(player.anim_state, "idle", "back to idle after the one-shot")

func test_secondary_motion_and_body_language() -> void:
	await _fixture()
	check(player.motion != null and player.motion.get_skeleton() != null, "WickerMotion modifier on the skeleton")
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var max_spring := 0.0
	var max_lean := 0.0
	for i in 40:
		await tree.physics_frame
		max_spring = maxf(max_spring, absf(player.motion.spring.x) + absf(player.motion.spring.y))
		max_lean = maxf(max_lean, player.model.rotation.x)
	check(max_spring > 0.02, "mane/beard spring reacts to acceleration (%.3f)" % max_spring)
	check(max_lean > 0.03, "body leans into acceleration (%.3f)" % max_lean)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	player.global_position = Vector3(0, 5, 3)
	var squashed := false
	for i in 120:
		await tree.physics_frame
		if player.model.scale.y < 0.97:
			squashed = true
			break
	check(squashed, "landing squash")
