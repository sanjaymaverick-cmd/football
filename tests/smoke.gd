extends SceneTree
## Headless check: curl both ways, goal framing, keeper dive, and set pieces.

var main: Node
var ball: BallController
var manager: Node
var cam: Camera3D
var phase := 0
var frames := 0
var x_with_spin := 0.0


func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		push_error("FAILED to load main.tscn")
		quit(1)
		return
	main = packed.instantiate()
	root.add_child(main)
	ball = main.get_node("Ball") as BallController
	manager = main.get_node("GameManager")
	cam = main.get_node("Camera3D") as Camera3D
	if cam.get_parent() != main or ball.get_parent() != main:
		push_error("Camera3D and Ball must both be direct children of Main")
		quit(1)
		return
	if not is_equal_approx(ball.mass, 0.43):
		push_error("ball mass is %s" % ball.mass)
		quit(1)
		return
	if ball.linear_damp_mode != RigidBody3D.DAMP_MODE_REPLACE or not is_equal_approx(ball.linear_damp, 0.05):
		push_error("ball linear damp")
		quit(1)
		return
	if not ball.continuous_cd:
		push_error("continuous_cd is off")
		quit(1)
		return
	if ball.physics_material_override == null or not is_equal_approx(ball.physics_material_override.bounce, 0.4):
		push_error("ball physics material")
		quit(1)
		return
	var ground := main.get_node("Ground") as StaticBody3D
	if ground.physics_material_override == null or not ground.physics_material_override.absorbent:
		push_error("grass material")
		quit(1)
		return
	for path in ["GoalPosts/LeftPost", "GoalPosts/RightPost", "GoalPosts/Crossbar", "ScoreZone", "Goalkeeper", "Stadium", "DefensiveWall"]:
		if main.get_node_or_null(path) == null:
			push_error("missing %s" % path)
			quit(1)
			return
	var engine := str(ProjectSettings.get_setting("physics/3d/physics_engine"))
	print("PHYSICS %s server=%s" % [engine, PhysicsServer3D])
	if engine != "Jolt Physics":
		push_error("expected Jolt Physics, got %s" % engine)
		quit(1)
		return
	print("NODES_OK")


func _boot_play() -> bool:
	root.size = Vector2i(1080, 1920)
	var turf := main.get_node("Ground/MeshInstance3D") as MeshInstance3D
	var grass := turf.get_surface_override_material(0) as ShaderMaterial
	if grass == null or grass.get_shader_parameter("albedo_tex") == null:
		push_error("turf texture missing")
		return false
	if grass.get_shader_parameter("normal_tex") == null or grass.get_shader_parameter("rough_tex") == null:
		push_error("turf normal or roughness missing")
		return false
	var env := (main.get_node("WorldEnvironment") as WorldEnvironment).environment
	var panorama := env.sky.sky_material as PanoramaSkyMaterial if env.sky != null else null
	if env.background_mode != Environment.BG_SKY or panorama == null or panorama.panorama == null:
		push_error("hdri sky missing")
		return false
	for child in main.get_node("Stadium").get_children():
		var shown := child as MeshInstance3D
		if shown == null:
			continue
		var dome := shown.mesh as SphereMesh
		if dome != null and dome.radius > 20.0:
			push_error("sky dome still hiding the hdri")
			return false
	if not _ball_visual_ok():
		return false
	if main.get_node("DefensiveWall").get_child_count() != 2:
		push_error("opening wall should be 2 players, got %s" % main.get_node("DefensiveWall").get_child_count())
		return false
	cam.snap_to_ball()
	if not _goal_in_frame(ball.global_position):
		return false
	ball.place_at(Vector3(-6.2, 0.11, -5.5))
	cam.snap_to_ball()
	if not _goal_in_frame(ball.global_position):
		push_error("tight-angle framing failed")
		return false
	ball.place_at(Vector3(0, 0.11, 1.5))
	cam.snap_to_ball()
	# The flight checks need a clear path. The wall is tested on its own above.
	main.get_node("DefensiveWall").rebuild(0, ball.global_position)
	var right := PackedVector2Array([Vector2(200, 760), Vector2(360, 420), Vector2(210, 60)])
	var left := PackedVector2Array([Vector2(200, 760), Vector2(40, 420), Vector2(190, 60)])
	var straight := PackedVector2Array([Vector2(200, 760), Vector2(200, 420), Vector2(200, 60)])
	var curl_r := ball.curl_pixels(right)
	var curl_l := ball.curl_pixels(left)
	var curl_s := ball.curl_pixels(straight)
	print("CURL right=%s left=%s straight=%s" % [curl_r, curl_l, curl_s])
	if curl_r < 80.0 or curl_l > -80.0 or absf(curl_s) > 12.0:
		push_error("swipe bow did not read both ways")
		return false
	print("STATIC_OK")
	return true


func _ball_visual_ok() -> bool:
	var prim := ball.get_node("MeshInstance3D") as GeometryInstance3D
	var stripe := ball.get_node("Stripe") as GeometryInstance3D
	if prim.visible or stripe.visible:
		push_error("primitive ball still visible")
		return false
	var inflated := ball.find_child("football_inflated", true, false) as MeshInstance3D
	if inflated == null or inflated.mesh == null:
		push_error("match ball mesh missing")
		return false
	var world_box: AABB = inflated.global_transform * inflated.mesh.get_aabb()
	var center := world_box.get_center()
	if center.distance_to(ball.global_position) > 0.03:
		push_error("ball visual center %s vs body %s" % [center, ball.global_position])
		return false
	var longest := maxf(world_box.size.x, maxf(world_box.size.y, world_box.size.z))
	var shape := ball.get_node("CollisionShape3D").shape as SphereShape3D
	var diameter := shape.radius * 2.0
	if absf(longest - diameter) > 0.03:
		push_error("ball visual size %s vs collision diameter %s" % [longest, diameter])
		return false
	print("BALL_VISUAL center=%s size=%s" % [center, world_box.size])
	return true


func _process(_delta: float) -> bool:
	frames += 1
	if phase == 0 and frames == 2:
		if not _boot_play():
			quit(1)
			return false
		frames = 0
		phase = 1
		return false
	if phase == 1 and frames >= 8:
		ball._apply_shot(Vector2(160, 280), 160.0, 0.18, 360.0)
		if ball.angular_velocity.y >= 0.0:
			push_error("expected negative sidespin, got %s" % ball.angular_velocity.y)
			quit(1)
			return false
		phase = 2
		frames = 0
	elif phase == 2 and frames >= 4:
		if ball.linear_velocity.z >= -1.0 or ball.linear_velocity.y <= 0.0:
			push_error("shot impulse vz=%s vy=%s" % [ball.linear_velocity.z, ball.linear_velocity.y])
			quit(1)
			return false
		print("SHOT_OK vz=%s vy=%s spin=%s" % [ball.linear_velocity.z, ball.linear_velocity.y, ball.angular_velocity.y])
		phase = 3
		frames = 0
	elif phase == 3 and frames >= 30:
		if ball.global_position.z > -0.4:
			push_error("ball did not travel toward the goal, z=%s" % ball.global_position.z)
			quit(1)
			return false
		print("FLIGHT_OK z=%s" % ball.global_position.z)
		_arm_curve(false, -8.0)
		phase = 4
		frames = 0
	elif phase == 4 and frames >= 70:
		x_with_spin = ball.global_position.x
		print("MAGNUS_X %s" % x_with_spin)
		if x_with_spin <= 0.4:
			push_error("magnus curve did not bend the ball to +X")
			quit(1)
			return false
		_arm_curve(false, 8.0)
		phase = 5
		frames = 0
	elif phase == 5 and frames >= 70:
		var x_left: float = ball.global_position.x
		print("MAGNUS_LEFT %s" % x_left)
		if x_left >= -0.4:
			push_error("left spin did not bend the ball to -X")
			quit(1)
			return false
		_arm_curve(true, -8.0)
		phase = 6
		frames = 0
	elif phase == 6 and frames >= 70:
		var x_super: float = ball.global_position.x
		print("SUPER_X %s" % x_super)
		if absf(x_super) > x_with_spin * 0.45:
			push_error("super shot still curved, x=%s vs %s" % [x_super, x_with_spin])
			quit(1)
			return false
		manager.set("is_siuuu_active", true)
		ball.linear_velocity = Vector3.ZERO
		ball.angular_velocity = Vector3.ZERO
		ball.global_position = ball.spawn_position
		ball._apply_shot(Vector2(0, 300), 80.0, 0.2, 300.0)
		if ball.angular_velocity.length() > 0.01:
			push_error("super shot kept spin %s" % ball.angular_velocity)
			quit(1)
			return false
		if not ball.fire_trail.emitting:
			push_error("fire trail did not start")
			quit(1)
			return false
		phase = 7
		frames = 0
	elif phase == 7 and frames >= 4:
		if ball.linear_velocity.z > -20.0:
			push_error("super forward impulse too small, vz=%s" % ball.linear_velocity.z)
			quit(1)
			return false
		print("SUPER_SHOT_OK vz=%s" % ball.linear_velocity.z)
		manager.set("is_siuuu_active", false)
		ball.sleeping = false
		ball.global_position = Vector3(-2.55, 1.9, -10.2)
		ball.linear_velocity = Vector3(0, 0, -22)
		ball.angular_velocity = Vector3.ZERO
		phase = 8
		frames = 0
	elif phase == 8 and frames >= 40:
		var score := int(manager.get("score"))
		var combo := int(manager.get("combo"))
		print("SCORE %s COMBO %s" % [score, combo])
		if score < 150 or combo < 2:
			push_error("target and goal should score 150 with combo 2")
			quit(1)
			return false
		var before: Vector3 = ball.spawn_position
		if int(manager.get("set_index")) == 0:
			manager.set("_scored_goal", true)
			manager.set("_resetting", true)
			manager._reset_play()
		if ball.spawn_position.distance_to(before) < 0.5 and int(manager.get("set_index")) == 0:
			push_error("goal did not move the next kick")
			quit(1)
			return false
		if main.get_node("DefensiveWall").get_child_count() != 3:
			push_error("next wall should be 3, got %s" % main.get_node("DefensiveWall").get_child_count())
			quit(1)
			return false
		var hint: Label = main.get_node("UI/HUD/HintLabel")
		if not str(hint.text).contains("WALL OF 3"):
			push_error("hint missing next set piece: %s" % hint.text)
			quit(1)
			return false
		print("SET_OK pos=%s" % ball.spawn_position)
		manager.set("_resolved", true)
		manager.set("_shot_live", false)
		var keeper := main.get_node("Goalkeeper") as Goalkeeper
		keeper.reset_keeper()
		ball.global_position = Vector3(0, 0.45, -4)
		ball.linear_velocity = Vector3(7.5, 0.4, -16)
		ball.angular_velocity = Vector3.ZERO
		phase = 9
		frames = 0
	elif phase == 9 and frames >= 90:
		var keeper := main.get_node("Goalkeeper") as Goalkeeper
		print("DIVE_RIGHT x=%s roll=%s pitch=%s" % [keeper.global_position.x, keeper.rotation.z, keeper.rotation.x])
		if keeper.global_position.x < 0.9 or keeper.rotation.z > -0.25:
			push_error("keeper did not dive right")
			quit(1)
			return false
		keeper.reset_keeper()
		ball.global_position = Vector3(0, 0.35, -4)
		ball.linear_velocity = Vector3(-7.5, -0.2, -16)
		ball.angular_velocity = Vector3.ZERO
		phase = 10
		frames = 0
	elif phase == 10 and frames >= 90:
		var keeper := main.get_node("Goalkeeper") as Goalkeeper
		print("DIVE_LEFT x=%s roll=%s" % [keeper.global_position.x, keeper.rotation.z])
		if keeper.global_position.x > -0.9 or keeper.rotation.z < 0.25:
			push_error("keeper did not dive left")
			quit(1)
			return false
		ball.place_at(ball.spawn_position)
		cam.snap_to_ball()
		if not _goal_in_frame(ball.global_position):
			push_error("framing lost on the next free kick")
			quit(1)
			return false
		# 60 m/s straight at the crossbar. Discrete steps can skip a 12 cm bar.
		ball.sleeping = false
		ball.gravity_scale = 0.0
		ball.global_position = Vector3(0, 2.44, -8)
		ball.linear_velocity = Vector3(0, 0, -60)
		ball.angular_velocity = Vector3.ZERO
		phase = 11
		frames = 0
	elif phase == 11 and frames >= 20:
		print("POST_HIT z=%s vz=%s" % [ball.global_position.z, ball.linear_velocity.z])
		if ball.global_position.z < -11.2:
			push_error("fast ball passed through the crossbar, z=%s" % ball.global_position.z)
			quit(1)
			return false
		if ball.linear_velocity.z < -8.0:
			push_error("fast ball kept its speed through the bar, vz=%s" % ball.linear_velocity.z)
			quit(1)
			return false
		print("SMOKE_OK")
		quit(0)
	return false


func _arm_curve(super_on: bool, spin_y: float) -> void:
	manager.set("is_siuuu_active", super_on)
	ball.sleeping = false
	ball.global_position = Vector3(0, 3, 0)
	ball.linear_velocity = Vector3(0, 0.2, -12)
	ball.angular_velocity = Vector3(0, spin_y, 0)


func _goal_in_frame(ball_pos: Vector3) -> bool:
	var vp := root.get_viewport().get_visible_rect().size
	if vp.x < 100.0 or vp.y < 100.0:
		push_error("viewport too small %s" % vp)
		return false
	var posts: Array[Vector3] = [
		Vector3(-3.66, 2.44, -11),
		Vector3(3.66, 2.44, -11),
		Vector3(-3.66, 0.25, -11),
		Vector3(3.66, 0.25, -11),
	]
	var ball_screen := cam.unproject_position(ball_pos)
	for p in posts:
		if cam.is_position_behind(p):
			push_error("post behind camera %s" % p)
			return false
		var s := cam.unproject_position(p)
		print("FRAME post %s screen %s vp %s ball %s" % [p, s, vp, ball_screen])
		if s.x < vp.x * 0.04 or s.x > vp.x * 0.96 or s.y < vp.y * 0.03 or s.y > vp.y * 0.82:
			push_error("post outside frame %s at %s" % [p, s])
			return false
		if s.y > ball_screen.y - 30.0:
			push_error("post is not above the ball on screen %s vs %s" % [s, ball_screen])
			return false
	if cam.is_position_behind(ball_pos):
		push_error("ball behind camera")
		return false
	if ball_screen.x < vp.x * 0.03 or ball_screen.x > vp.x * 0.97 or ball_screen.y < vp.y * 0.35 or ball_screen.y > vp.y * 0.96:
		push_error("ball not in the lower frame %s" % ball_screen)
		return false
	return true
