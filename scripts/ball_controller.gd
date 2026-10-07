extends RigidBody3D
class_name BallController
## Swipe-to-shoot. The chord is the aim. The sideways bow is curl.
## A bow toward the bottom of the screen is topspin and dips the ball.
## Air drag and spin-parameter Magnus run only while the ball is airborne.

signal shot_taken(super_shot: bool)

@export var min_swipe_pixels: float = 40.0
@export var max_swipe_pixels: float = 520.0
@export var min_impulse: float = 6.0
@export var max_impulse: float = 13.5
@export var min_lift: float = 2.2
@export var max_lift: float = 3.4
@export var spin_per_pixel: float = 0.05
@export var max_spin: float = 18.0
@export var magnus_coefficient: float = 0.10
@export var super_shot_multiplier: float = 2.5
@export var airborne_clearance: float = 0.08
@export var ready_speed: float = 0.4
@export var air_density: float = 1.2
@export var drag_coefficient: float = 0.25
@export var lift_slope: float = 8.0
@export var lift_max: float = 0.5

const BALL_RADIUS := 0.11
const BALL_AREA := 0.038

var spawn_position: Vector3 = Vector3.ZERO

var _finger: int = -1
var _start_msec: int = 0
var _tracking: bool = false
var _points: PackedVector2Array = PackedVector2Array()
var _kick: AudioStreamPlayer
var _post: AudioStreamPlayer
var _land: AudioStreamPlayer
var _hit_lock: float = 0.0

@onready var fire_trail: GPUParticles3D = $FireTrail


func _ready() -> void:
	spawn_position = global_position
	add_to_group("ball")
	angular_damp = 0.12
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	_arm_posts()
	var sounds := load("res://scripts/crowd_audio.gd")
	_kick = _player(sounds.kick(), -4.0)
	_post = _player(sounds.post(), -5.0)
	_land = _player(sounds.land(), -8.0)


func _player(stream: AudioStream, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume
	add_child(player)
	return player


func _arm_posts() -> void:
	var posts := get_parent().get_node_or_null("GoalPosts")
	if posts == null:
		return
	var mat := PhysicsMaterial.new()
	mat.friction = 0.22
	mat.bounce = 0.62
	for child in posts.get_children():
		if child is StaticBody3D:
			(child as StaticBody3D).physics_material_override = mat


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _tracking or not _can_shoot():
			return
		if _touch_blocked(event.position):
			return
		_finger = event.index
		_start_msec = Time.get_ticks_msec()
		_tracking = true
		_points = PackedVector2Array()
		_points.append(event.position)
		return
	if event.index != _finger or not _tracking:
		return
	_tracking = false
	_finger = -1
	if event.canceled:
		return
	if _points.is_empty() or _points[_points.size() - 1].distance_to(event.position) > 1.0:
		_points.append(event.position)
	_release_swipe()


func _on_drag(event: InputEventScreenDrag) -> void:
	if not _tracking or event.index != _finger:
		return
	if _points.is_empty() or _points[_points.size() - 1].distance_to(event.position) >= 5.0:
		_points.append(event.position)


func _release_swipe() -> void:
	if not _can_shoot() or _points.size() < 2:
		return
	var chord := _to_up(_points[_points.size() - 1]) - _to_up(_points[0])
	if chord.y < min_swipe_pixels:
		return
	var duration := maxf(0.016, (Time.get_ticks_msec() - _start_msec) / 1000.0)
	_apply_shot(chord, curl_pixels(_points), duration, _path_length(_points), dip_pixels(_points))


func _can_shoot() -> bool:
	return linear_velocity.length() <= ready_speed and angular_velocity.length() <= ready_speed


func _touch_blocked(screen_pos: Vector2) -> bool:
	var button := get_tree().get_first_node_in_group("siuuu_button")
	if button == null or not button.visible:
		return false
	return button.get_global_rect().has_point(screen_pos)


func _super_shot_active() -> bool:
	var manager := get_node_or_null("%GameManager")
	return manager != null and manager.get("is_siuuu_active") == true


func _to_up(screen_point: Vector2) -> Vector2:
	return Vector2(screen_point.x, -screen_point.y)


func _path_length(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total


## Positive means the path bows to screen-right of its chord.
func curl_pixels(points: PackedVector2Array) -> float:
	if points.size() < 3:
		return 0.0
	var start := _to_up(points[0])
	var chord := _to_up(points[points.size() - 1]) - start
	var span := chord.length()
	if span < 1.0:
		return 0.0
	var dir := chord / span
	var right := Vector2(dir.y, -dir.x)
	var bow := 0.0
	for point in points:
		var signed := (_to_up(point) - start).dot(right)
		if absf(signed) > absf(bow):
			bow = signed
	return bow


## Positive means the path bows toward the bottom of the screen, so the ball dips.
func dip_pixels(points: PackedVector2Array) -> float:
	if points.size() < 3:
		return 0.0
	var start := _to_up(points[0])
	var chord := _to_up(points[points.size() - 1]) - start
	var span := chord.length()
	if span < 1.0:
		return 0.0
	var dir := chord / span
	var screen_down := Vector2(0.0, -1.0)
	var bow := 0.0
	for point in points:
		var offset := _to_up(point) - start
		var lateral := offset - dir * offset.dot(dir)
		var signed := lateral.dot(screen_down)
		if absf(signed) > absf(bow):
			bow = signed
	return bow


func _apply_shot(screen_up: Vector2, curve_pixels: float, duration: float, path_pixels: float = -1.0, dip: float = 0.0) -> void:
	var clamped := screen_up.limit_length(max_swipe_pixels)
	if clamped.y <= 0.0:
		return
	var traveled := path_pixels if path_pixels > 0.0 else clamped.length()
	var speed := traveled / duration
	var length_n := clampf(traveled / 420.0, 0.0, 1.0)
	var speed_n := clampf(speed / 1700.0, 0.0, 1.0)
	var power_n := clampf(length_n * 0.72 + speed_n * 0.5, 0.0, 1.0)
	var strength := lerpf(min_impulse, max_impulse, power_n)
	var aim := _screen_to_world(clamped)
	var impulse := aim * strength
	var upright := clampf(clamped.y / maxf(clamped.length(), 1.0), 0.0, 1.0)
	impulse.y = lerpf(min_lift, max_lift, upright) * lerpf(0.75, 1.0, power_n)

	var super_shot := _super_shot_active()
	if super_shot:
		var lift := impulse.y
		impulse.y = 0.0
		impulse *= super_shot_multiplier
		impulse.y = lift
		angular_velocity = Vector3.ZERO
		fire_trail.restart()
		fire_trail.emitting = true
	else:
		# Positive bow sets negative side spin, which bends to screen-right.
		# Positive dip sets negative pitch spin. With v along -Z that force points down.
		var side := clampf(-curve_pixels * spin_per_pixel, -max_spin, max_spin)
		var pitch := clampf(-dip * spin_per_pixel, -max_spin, max_spin)
		angular_velocity = Vector3(pitch, side, 0.0)
		fire_trail.emitting = false

	sleeping = false
	apply_central_impulse(impulse)
	_strike(_kick, power_n, -10.0, -2.0)
	shot_taken.emit(super_shot)


func _screen_to_world(screen_up: Vector2) -> Vector3:
	var forward := Vector3(0.0, 0.0, -1.0)
	var right := Vector3(1.0, 0.0, 0.0)
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var cam_forward := -cam.global_transform.basis.z
		cam_forward.y = 0.0
		if cam_forward.length() > 0.05:
			forward = cam_forward.normalized()
		var cam_right := cam.global_transform.basis.x
		cam_right.y = 0.0
		if cam_right.length() > 0.05:
			right = cam_right.normalized()
	var aim := right * screen_up.x + forward * screen_up.y
	aim.y = 0.0
	if aim.length() < 0.001:
		return forward
	return aim.normalized()


func _physics_process(delta: float) -> void:
	_hit_lock = maxf(0.0, _hit_lock - delta)
	if fire_trail.emitting:
		fire_trail.global_rotation = Vector3.ZERO
	if _super_shot_active() or not _is_airborne():
		return
	var velocity := linear_velocity
	var speed := velocity.length()
	if speed < 0.4:
		return
	var drag := -0.5 * air_density * drag_coefficient * BALL_AREA * speed * velocity
	apply_central_force(drag)
	var spin := angular_velocity.length()
	if spin < 0.2:
		return
	var spin_param := clampf(BALL_RADIUS * spin / speed, 0.0, 0.6)
	var lift := clampf(lift_slope * spin_param, 0.0, lift_max)
	var magnus_dir := angular_velocity.cross(velocity)
	if magnus_dir.length_squared() < 0.0001:
		return
	var magnus := 0.5 * air_density * lift * BALL_AREA * speed * magnus_dir.normalized() * speed
	apply_central_force(magnus)


func _is_airborne() -> bool:
	return global_position.y > spawn_position.y + airborne_clearance


func _on_body_entered(body: Node) -> void:
	if _hit_lock > 0.0:
		return
	var hit := clampf(linear_velocity.length() / 18.0, 0.0, 1.0)
	var name := str(body.name)
	if name == "LeftPost" or name == "RightPost" or name == "Crossbar":
		_hit_lock = 0.18
		_strike(_post, hit, -14.0, -3.0)
	elif name == "Ground" and hit > 0.18:
		_hit_lock = 0.22
		_strike(_land, hit, -16.0, -7.0)


func _strike(player: AudioStreamPlayer, amount: float, quiet: float, loud: float) -> void:
	if player == null:
		return
	player.volume_db = lerpf(quiet, loud, amount)
	player.pitch_scale = lerpf(0.92, 1.12, amount)
	player.play()


func place_at(world_pos: Vector3) -> void:
	spawn_position = world_pos
	reset_to_spot()


func reset_to_spot() -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_position = spawn_position
	global_rotation = Vector3.ZERO
	sleeping = false
	fire_trail.emitting = false
	fire_trail.restart()
