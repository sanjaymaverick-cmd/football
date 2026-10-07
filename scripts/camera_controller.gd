extends Camera3D
## Frames the ball and the whole goal. The camera stays back on the shot
## so a kick does not push the posts out of a portrait view.

const GOAL_LOOK := Vector3(0.0, 1.28, -11.0)

@export var back_distance: float = 9.2
@export var camera_height: float = 5.6
@export var center_pull: float = 0.28
@export var follow_side: float = 1.4
@export var follow_depth: float = 0.28

var _anchor: Vector3 = Vector3.ZERO

@onready var ball: Node3D = %Ball


func _ready() -> void:
	snap_to_ball()


func snap_to_ball() -> void:
	_anchor = ball.global_position
	_apply_pose()


func _physics_process(delta: float) -> void:
	var target := ball.global_position
	_anchor.x = lerpf(_anchor.x, target.x, clampf(follow_side * delta, 0.0, 1.0))
	_anchor.z = lerpf(_anchor.z, target.z, clampf(follow_depth * delta, 0.0, 1.0))
	_anchor.y = target.y
	_apply_pose()


func _apply_pose() -> void:
	var pose := pose_for(_anchor)
	global_position = pose["position"]
	look_at(pose["look"], Vector3.UP)


## Camera sits behind the ball, pulled toward the center line, looking at the goal mouth.
func pose_for(anchor: Vector3) -> Dictionary:
	var from_goal := Vector3(anchor.x, 0.0, anchor.z + 11.0)
	if from_goal.length() < 0.2:
		from_goal = Vector3(0.0, 0.0, 1.0)
	var back := from_goal.normalized().lerp(Vector3(0.0, 0.0, 1.0), center_pull).normalized()
	var cam := Vector3(anchor.x, 0.0, anchor.z) + back * back_distance + Vector3(0.0, camera_height, 0.0)
	cam.x = lerpf(cam.x, 0.0, center_pull)
	return {"position": cam, "look": GOAL_LOOK}
