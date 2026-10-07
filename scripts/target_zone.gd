extends Area3D
class_name TargetZone

signal target_hit(bonus_points: int)

@export var bonus_points: int = 50
@export var glow_color: Color = Color(1, 0.8, 0.2, 1)

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_glow()


func _apply_glow() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(glow_color.r, glow_color.g, glow_color.b, 0.3)
	mat.emission_enabled = true
	mat.emission = glow_color
	mat.emission_energy_multiplier = 5.0
	mesh.set_surface_override_material(0, mat)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("ball"):
		return
	target_hit.emit(bonus_points)
	mesh.visible = false
	shape.set_deferred("disabled", true)
	set_deferred("monitoring", false)


func reset_zone() -> void:
	mesh.visible = true
	shape.set_deferred("disabled", false)
	set_deferred("monitoring", true)
