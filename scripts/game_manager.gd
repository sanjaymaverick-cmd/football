extends Node

signal score_changed(score: int)

const CrowdAudio = preload("res://scripts/crowd_audio.gd")
const SET_PIECES := [
	{"title": "FREE KICK  ·  WALL OF 2", "pos": Vector3(0, 0.11, 1.5), "wall": 2},
	{"title": "LEFT FREE KICK  ·  WALL OF 3", "pos": Vector3(-5.2, 0.11, -1.2), "wall": 3},
	{"title": "RIGHT FREE KICK  ·  WALL OF 4", "pos": Vector3(5.0, 0.11, -0.4), "wall": 4},
	{"title": "LONG FREE KICK  ·  WALL OF 5", "pos": Vector3(0.8, 0.11, 3.4), "wall": 5},
	{"title": "TIGHT ANGLE  ·  WALL OF 6", "pos": Vector3(-6.2, 0.11, -5.5), "wall": 6},
]

@export var goal_points: int = 100
@export var combo_max: int = 3
@export var reset_delay: float = 1.25

var score: int = 0
var combo: int = 0
var is_siuuu_active: bool = false
var set_index: int = 0

var _shot_live: bool = false
var _resolved: bool = false
var _resetting: bool = false
var _scored_goal: bool = false

@onready var ball: BallController = %Ball
@onready var keeper: Goalkeeper = %Goalkeeper
@onready var wall: Node3D = %DefensiveWall
@onready var camera: Camera3D = %Camera3D
@onready var score_label: Label = %ScoreLabel
@onready var combo_bar: ProgressBar = %ComboBar
@onready var siuuu_button: Button = %SiuuuButton
@onready var banner: Label = %Banner
@onready var hint: Label = %HintLabel
@onready var cheer_goal: AudioStreamPlayer = $CrowdGoal
@onready var cheer_super: AudioStreamPlayer = $CrowdSuper
@onready var siuuu_voice: AudioStreamPlayer = $SiuuuVoice

var _ambience: AudioStreamPlayer
var _net: AudioStreamPlayer


func _ready() -> void:
	combo_bar.max_value = combo_max
	combo_bar.value = 0
	combo_bar.show_percentage = false
	siuuu_button.visible = false
	siuuu_button.disabled = true
	siuuu_button.pressed.connect(_on_siuuu_pressed)
	banner.visible = false
	%ScoreZone.body_entered.connect(_on_score_zone)
	ball.shot_taken.connect(_on_shot_taken)
	for node in get_tree().get_nodes_in_group("target_zone"):
		var zone := node as TargetZone
		zone.target_hit.connect(_on_target_hit)
	cheer_goal.stream = CrowdAudio.cheer(false)
	cheer_super.stream = CrowdAudio.cheer(true)
	_ambience = AudioStreamPlayer.new()
	_ambience.volume_db = -12.0
	_ambience.stream = CrowdAudio.ambience()
	add_child(_ambience)
	_ambience.play()
	_net = AudioStreamPlayer.new()
	_net.stream = CrowdAudio.net()
	_net.volume_db = -6.0
	add_child(_net)
	_refresh_score()
	_apply_set_piece(0)


func _process(_delta: float) -> void:
	if _ambience != null and not _ambience.playing:
		_ambience.play()


func _physics_process(_delta: float) -> void:
	if not _shot_live or _resetting or _resolved:
		return
	var p := ball.global_position
	var out_of_play := p.y < -1.0 or p.z < -16.0 or p.z > 8.0 or absf(p.x) > 12.0
	var settled := ball.linear_velocity.length() < 0.35 and p.distance_to(ball.spawn_position) > 0.75
	if out_of_play or settled:
		_resolved = true
		banner.visible = false
		_schedule_reset()


func _on_shot_taken(_super_shot: bool) -> void:
	_shot_live = true
	_resolved = false


func _on_score_zone(body: Node) -> void:
	if _resolved or _resetting or not body.is_in_group("ball"):
		return
	if ball.linear_velocity.z >= -0.2:
		return
	_resolved = true
	_scored_goal = true
	score += goal_points
	_add_combo()
	_refresh_score()
	banner.text = "GOAL!"
	banner.visible = true
	if _net != null:
		_net.play()
	if not is_siuuu_active:
		cheer_goal.play()
	_schedule_reset()


func _on_target_hit(bonus_points: int) -> void:
	score += bonus_points
	_add_combo()
	_refresh_score()


func _add_combo() -> void:
	combo = mini(combo + 1, combo_max)
	combo_bar.value = combo


func _on_siuuu_pressed() -> void:
	is_siuuu_active = true
	combo = 0
	combo_bar.value = 0
	siuuu_button.visible = false
	siuuu_button.disabled = true
	banner.text = "SUPER SHOT! SIUUU!"
	banner.visible = true
	cheer_super.play()
	siuuu_voice.play()


func _schedule_reset() -> void:
	if _resetting:
		return
	_resetting = true
	get_tree().create_timer(reset_delay).timeout.connect(_reset_play)


func _reset_play() -> void:
	if not _resetting:
		return
	is_siuuu_active = false
	if _scored_goal:
		set_index = (set_index + 1) % SET_PIECES.size()
		_scored_goal = false
		_apply_set_piece(set_index)
	else:
		ball.reset_to_spot()
		keeper.reset_keeper()
	for node in get_tree().get_nodes_in_group("target_zone"):
		(node as TargetZone).reset_zone()
	banner.visible = false
	_shot_live = false
	_resolved = false
	_resetting = false
	_refresh_button()


func _apply_set_piece(index: int) -> void:
	set_index = index
	var piece: Dictionary = SET_PIECES[index]
	ball.place_at(piece["pos"])
	keeper.reset_keeper()
	wall.rebuild(int(piece["wall"]), piece["pos"])
	if camera.has_method("snap_to_ball"):
		camera.snap_to_ball()
	hint.text = "%s\nHook the swipe inward to curl" % str(piece["title"])
	hint.visible = true


func _refresh_score() -> void:
	score_label.text = "SCORE: %d" % score
	score_changed.emit(score)
	_refresh_button()


func _refresh_button() -> void:
	var ready := combo >= combo_max and not _shot_live and not is_siuuu_active
	siuuu_button.visible = ready
	siuuu_button.disabled = not ready
