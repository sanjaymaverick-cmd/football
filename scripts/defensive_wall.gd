extends Node3D
## Free-kick wall. Players stand between the ball and the goal, shifted
## toward the near post so an inward curl has a channel at the far side.

const GOAL := Vector3(0.0, 0.0, -11.0)

var _shirts: Array[Color] = [
	Color(0.92, 0.78, 0.12),
	Color(0.86, 0.16, 0.18),
	Color(0.16, 0.38, 0.82),
	Color(0.95, 0.95, 0.95),
	Color(0.12, 0.55, 0.32),
]


func rebuild(count: int, ball_pos: Vector3) -> void:
	for child in get_children():
		child.free()
	if count <= 0:
		return
	var to_goal := GOAL - ball_pos
	to_goal.y = 0.0
	var dist := to_goal.length()
	if dist < 2.0:
		return
	var dir := to_goal / dist
	var wall_dist := clampf(dist * 0.40, 3.6, 7.2)
	var center := ball_pos + dir * wall_dist
	# forward × up, with forward = dir toward the goal. For dir (0,0,-1) this is +X.
	var side := Vector3(-dir.z, 0.0, dir.x)
	var shift := clampf(ball_pos.x * 0.14, -1.1, 1.1)
	var spacing := 0.54
	for i in count:
		var along := (float(i) - float(count - 1) * 0.5) * spacing + shift
		var at := center + side * along
		at.y = 0.9
		_spawn_player(at, i)


func _spawn_player(at: Vector3, index: int) -> void:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 2
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.46, 1.72, 0.36)
	shape_node.shape = shape
	body.add_child(shape_node)

	var shirt := _mat(_shirts[index % _shirts.size()], 0.72)
	var skin := _mat(Color(0.93, 0.73, 0.52), 0.6)
	var shorts := _mat(Color(0.08, 0.09, 0.12), 0.8)
	var hair := _mat(Color(0.12, 0.08, 0.06), 0.7)

	_mesh(body, BoxMesh.new(), shirt, Vector3(0, 0.18, 0), Vector3(0.46, 0.52, 0.28))
	_mesh(body, BoxMesh.new(), shorts, Vector3(0, -0.2, 0), Vector3(0.44, 0.28, 0.26))
	_mesh(body, SphereMesh.new(), skin, Vector3(0, 0.62, 0), Vector3(0.3, 0.3, 0.3))
	_mesh(body, BoxMesh.new(), hair, Vector3(0, 0.74, -0.02), Vector3(0.26, 0.1, 0.22))
	_mesh(body, BoxMesh.new(), skin, Vector3(-0.16, -0.58, 0), Vector3(0.14, 0.46, 0.16))
	_mesh(body, BoxMesh.new(), skin, Vector3(0.16, -0.58, 0), Vector3(0.14, 0.46, 0.16))
	_mesh(body, BoxMesh.new(), skin, Vector3(-0.32, 0.16, 0), Vector3(0.12, 0.42, 0.12))
	_mesh(body, BoxMesh.new(), skin, Vector3(0.32, 0.16, 0), Vector3(0.12, 0.42, 0.12))
	add_child(body)


func _mesh(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, size: Vector3) -> void:
	if mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	elif mesh is SphereMesh:
		(mesh as SphereMesh).radius = size.x * 0.5
		(mesh as SphereMesh).height = size.y
		(mesh as SphereMesh).radial_segments = 8
		(mesh as SphereMesh).rings = 4
	mesh.surface_set_material(0, material)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	parent.add_child(inst)


func _mat(color: Color, rough: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	return mat
