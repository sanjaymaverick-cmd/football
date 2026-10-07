extends AnimatableBody3D
class_name Goalkeeper
## Reads the shot, then commits to a dive. Low wide shots are full-length;
## high shots are a jump. A heavy curl beats him because he does not track
## the ball after he commits. A SIUUU shot sends him the wrong way.

enum Phase { READY, REACT, DIVE, HOLD, RECOVER }

@export var min_x: float = -3.2
@export var max_x: float = 3.2
@export var reaction_time: float = 0.16
@export var dive_time: float = 0.48
@export var hold_time: float = 0.28
@export var recover_time: float = 0.42

var _home: Vector3 = Vector3.ZERO
var _phase: int = Phase.READY
var _timer: float = 0.0
var _from: Vector3 = Vector3.ZERO
var _to: Vector3 = Vector3.ZERO
var _roll: float = 0.0
var _pitch: float = 0.0
var _arc: float = 0.0
var _shot_seen: bool = false

@onready var ball: RigidBody3D = %Ball
@onready var manager: Node = %GameManager
@onready var arm_l: MeshInstance3D = $ArmL
@onready var arm_r: MeshInstance3D = $ArmR


func _siuuu_active() -> bool:
	return manager.get("is_siuuu_active") == true


func _ready() -> void:
	_home = global_position
	_from = _home
	_to = _home


func _physics_process(delta: float) -> void:
	var toward_goal := ball.linear_velocity.z < -3.0 and ball.global_position.z > _home.z + 0.8
	if _phase == Phase.READY and toward_goal and not _shot_seen:
		_begin_react()
	if not toward_goal and ball.linear_velocity.length() < 0.6:
		_shot_seen = false

	_timer += delta
	match _phase:
		Phase.READY:
			_blend_to(_home, 0.0, 0.0, 0.0, clampf(3.0 * delta, 0.0, 1.0))
		Phase.REACT:
			var early := clampf(_timer / reaction_time, 0.0, 1.0)
			var step := _home.lerp(_to, 0.12 * early)
			_blend_to(Vector3(step.x, _home.y, _home.z), 0.0, 0.0, 0.0, 1.0)
			if _timer >= reaction_time:
				_commit()
		Phase.DIVE:
			var t := clampf(_timer / dive_time, 0.0, 1.0)
			var e := t * t * (3.0 - 2.0 * t)
			var pos := _from.lerp(_to, e)
			pos.y += sin(t * PI) * _arc
			_blend_to(pos, _pitch * e, _roll * e, 0.0, 1.0)
			if _timer >= dive_time:
				_phase = Phase.HOLD
				_timer = 0.0
		Phase.HOLD:
			if _timer >= hold_time:
				_phase = Phase.RECOVER
				_timer = 0.0
				_from = global_position
		Phase.RECOVER:
			var u := clampf(_timer / recover_time, 0.0, 1.0)
			var back := _from.lerp(_home, u)
			_blend_to(back, lerpf(_pitch, 0.0, u), lerpf(_roll, 0.0, u), 0.0, 1.0)
			if _timer >= recover_time:
				_phase = Phase.READY
				_timer = 0.0
				_set_arms(false)


func _begin_react() -> void:
	_shot_seen = true
	_phase = Phase.REACT
	_timer = 0.0
	_from = global_position
	# Early read uses little of the bend, so a late inward curl gets past him.
	var predicted := _predict_crossing(0.25)
	_to = _choose_target(predicted, false)


func _commit() -> void:
	var predicted := _predict_crossing(0.3)
	var fear := _siuuu_active()
	_to = _choose_target(predicted, fear)
	_from = global_position
	var dx := _to.x - _home.x
	var wide := absf(dx) > 0.7
	var high := _to.y > 1.35
	# Positive rotation.x tips the head (+Y) toward the ball (+Z).
	# Positive rotation.z tips the head toward -X, so a dive to +X uses a negative roll.
	_pitch = 0.55 if wide or high else 0.2
	var lay := 1.25 if wide and not high else (0.7 if high else 0.35)
	_roll = -signf(dx if absf(dx) > 0.08 else 1.0) * lay
	_arc = 0.55 if high else 0.08
	_phase = Phase.DIVE
	_timer = 0.0
	_set_arms(true)


func _choose_target(predicted: Vector3, fear: bool) -> Vector3:
	var x := clampf(predicted.x, min_x, max_x)
	var y := clampf(predicted.y, 0.46, 1.95)
	if fear:
		x = clampf(-x, min_x, max_x)
		if absf(x) < 1.4:
			x = max_x if predicted.x >= 0.0 else min_x
		y = 0.5
	elif absf(predicted.x - _home.x) < 0.32 and predicted.y < 1.7 and predicted.y > 0.55:
		x = clampf(predicted.x, -0.45, 0.45)
		y = clampf(predicted.y, 0.7, 1.45)
	elif predicted.y < 0.85 or absf(x) > 1.5:
		y = 0.48
	return Vector3(x, y, _home.z)


## Where the ball crosses the keeper's line. magnus_scale < 1 under-reads the curl.
func _predict_crossing(magnus_scale: float) -> Vector3:
	var p := ball.global_position
	var v := ball.linear_velocity
	var w := ball.angular_velocity
	var mass := maxf(ball.mass, 0.05)
	var coeff := 0.0
	if not _siuuu_active() and "magnus_coefficient" in ball:
		coeff = float(ball.magnus_coefficient) * magnus_scale
	var plane_z := _home.z
	var dt := 1.0 / 60.0
	for _i in 90:
		if p.z <= plane_z:
			break
		if p.y > 0.22 and coeff > 0.0:
			v += w.cross(v) * coeff / mass * dt
		v.y -= 9.8 * dt
		p += v * dt
		if p.y < 0.11:
			p.y = 0.11
			if v.y < 0.0:
				v.y = -v.y * 0.25
	return p


func _blend_to(pos: Vector3, pitch: float, roll: float, _yaw: float, weight: float) -> void:
	var blended := global_position.lerp(Vector3(pos.x, pos.y, _home.z), weight)
	var basis := Basis.from_euler(Vector3(pitch, 0.0, roll))
	global_transform = Transform3D(basis, Vector3(blended.x, blended.y, _home.z))


func _set_arms(diving: bool) -> void:
	if diving:
		arm_l.rotation = Vector3(0.0, 0.0, 1.15)
		arm_r.rotation = Vector3(0.0, 0.0, -1.15)
	else:
		arm_l.rotation = Vector3.ZERO
		arm_r.rotation = Vector3.ZERO


func reset_keeper() -> void:
	_phase = Phase.READY
	_timer = 0.0
	_shot_seen = false
	_roll = 0.0
	_pitch = 0.0
	_from = _home
	_to = _home
	global_position = _home
	rotation = Vector3.ZERO
	_set_arms(false)
