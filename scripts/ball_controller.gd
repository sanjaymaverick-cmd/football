extends RigidBody3D
class_name BallController
## Swipe-to-shoot. Screen-up is -Z (toward the goal). Screen-right is +X.
## Curl comes from the bow of the finger path, so a long inward hook bends
## the ball that way. A straight swipe stays straight.

signal shot_taken(super_shot: bool)

@export var min_swipe_pixels: float = 40.0
@export var max_swipe_pixels: float = 520.0
@export var min_impulse: float = 6.0
@export var max_impulse: float = 13.5
@export var min_lift: float = 2.2
@export var max_lift: float = 3.4
@export var spin_per_pixel: float = 0.05
@export var max_spin: float = 9.0
@export var magnus_coefficient: float = 0.036
@export var super_shot_multiplier: float = 2.5
@export var airborne_clearance: float = 0.08
@export var ready_speed: float = 0.4

var spawn_position: Vector3 = Vector3.ZERO

var _finger: int = -1
var _start_msec: int = 0
var _tracking: bool = false
var _points: PackedVector2Array = PackedVector2Array()

@onready var fire_trail: GPUParticles3D = $FireTrail


func _ready() -> void:
	spawn_position = global_position
	add_to_group("ball")


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
	var release := _release_vector(_points)
	if release.y <= 0.0:
		release = chord
	_apply_shot(release, curl_pixels(_points), duration, _path_length(_points))


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


## Screen pixels, y down, become x-right y-up.
func _to_up(screen_point: Vector2) -> Vector2:
	return Vector2(screen_point.x, -screen_point.y)


func _path_length(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total


## Last portion of the path, in screen-up space. This is the launch direction.
func _release_vector(points: PackedVector2Array) -> Vector2:
	var total := _path_length(points)
	var walked := 0.0
	var mark := total * 0.62
	for i in range(1, points.size()):
		var step := points[i - 1].distance_to(points[i])
		if walked + step >= mark:
			return _to_up(points[points.size() - 1]) - _to_up(points[i - 1])
		walked += step
	return _to_up(points[points.size() - 1]) - _to_up(points[0])


## Positive means the path bows to screen-right of its travel, so the ball bends to +X.
## A long inward hook (the finger path bends back toward the goal) returns a large value.
func curl_pixels(points: PackedVector2Array) -> float:
	if points.size() < 3:
		if points.size() < 2:
			return 0.0
		var short := _to_up(points[1]) - _to_up(points[0])
		return short.x * 0.28
	var start := _to_up(points[0])
	var chord := _to_up(points[points.size() - 1]) - start
	var span := chord.length()
	if span < 1.0:
		return 0.0
	var dir := chord / span
	# Travel (0, +1) is up the screen, toward the goal. Clockwise normal is world/screen right (+1, 0).
	var right := Vector2(dir.y, -dir.x)
	var bow := 0.0
	for point in points:
		var signed := (_to_up(point) - start).dot(right)
		if absf(signed) > absf(bow):
			bow = signed
	return bow + chord.x * 0.28


func _apply_shot(screen_up: Vector2, curve_pixels: float, duration: float, path_pixels: float = -1.0) -> void:
	var clamped := screen_up.limit_length(max_swipe_pixels)
	if clamped.y <= 0.0:
		return
	var traveled := path_pixels if path_pixels > 0.0 else clamped.length()
	var speed := traveled / duration
	var length_n := clampf(traveled / 420.0, 0.0, 1.0)
	var speed_n := clampf(speed / 1700.0, 0.0, 1.0)
	var power_n := clampf(length_n * 0.72 + speed_n * 0.5, 0.0, 1.0)
	var strength := lerpf(min_impulse, max_impulse, power_n)
	# Up the screen is -Z. Right on the screen is +X.
	var aim := Vector3(clamped.x, 0.0, -clamped.y).normalized()
	var impulse := aim * strength
	var upright := clampf(clamped.y / maxf(clamped.length(), 1.0), 0.0, 1.0)
	impulse.y = lerpf(min_lift, max_lift, upright) * lerpf(0.75, 1.0, power_n)

	var super_shot := _super_shot_active()
	if super_shot:
		impulse.z *= super_shot_multiplier
		angular_velocity = Vector3.ZERO
		fire_trail.restart()
		fire_trail.emitting = true
	else:
		# Positive curve_pixels (bow to screen-right) sets negative spin.
		# With v along -Z, ω.y < 0 makes ω × v point to +X.
		var spin := clampf(-curve_pixels * spin_per_pixel, -max_spin, max_spin)
		angular_velocity = Vector3(0.0, spin, 0.0)
		fire_trail.emitting = false

	sleeping = false
	apply_central_impulse(impulse)
	shot_taken.emit(super_shot)


func _physics_process(_delta: float) -> void:
	if fire_trail.emitting:
		fire_trail.global_rotation = Vector3.ZERO
	if _super_shot_active() or not _is_airborne():
		return
	var curve := angular_velocity.cross(linear_velocity) * magnus_coefficient
	apply_central_force(curve)


func _is_airborne() -> bool:
	return global_position.y > spawn_position.y + airborne_clearance


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
