extends Node3D
## Stands and boards stay built in code. The pitch, sky, and ball visual are CC0:
## Poly Haven suburban_football_field and football, AmbientCG Grass001.
## Drop folders assets/mixamo, assets/megascans, and assets/sketchfab are not loaded.

const GRASS_DIR := "res://assets/ambientcg/Grass001"
const HDR_PATH := "res://assets/polyhaven/hdr/suburban_football_field_2k.hdr"
const BALL_PATH := "res://assets/polyhaven/football/football_1k.gltf"
const BALL_DIAMETER := 0.22

var _hdri := false


func _ready() -> void:
	if not _paint_real_turf():
		_paint_turf()
	_hdri = _apply_hdri()
	_build_bowl()
	_build_boards()
	_build_lights()
	if not _hdri:
		_build_sky()
	_dress_ball()


func _paint_real_turf() -> bool:
	var ground := get_parent().get_node_or_null("Ground/MeshInstance3D") as MeshInstance3D
	if ground == null:
		push_error("turf ground missing parent=%s" % get_parent())
		return false
	var albedo := _grass_file("color")
	var normal := _grass_file("normal")
	var rough := _grass_file("rough")
	if albedo == null or normal == null or rough == null:
		push_error("grass textures missing")
		return false
	var shader := load("res://shaders/pitch_grass.gdshader") as Shader
	if shader == null:
		push_error("pitch shader missing")
		return false
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("albedo_tex", albedo)
	mat.set_shader_parameter("normal_tex", normal)
	mat.set_shader_parameter("rough_tex", rough)
	var ao := _grass_file("ao")
	if ao != null:
		mat.set_shader_parameter("ao_tex", ao)
	ground.set_surface_override_material(0, mat)
	return true


func _grass_file(kind: String) -> Texture2D:
	var dir := DirAccess.open(GRASS_DIR)
	if dir == null:
		return null
	var best := ""
	for name in dir.get_files():
		var lower := name.to_lower()
		if not (lower.ends_with(".jpg") or lower.ends_with(".png") or lower.ends_with(".webp")):
			continue
		var matched := false
		if kind == "color":
			matched = "color" in lower
		elif kind == "normal":
			matched = "normalgl" in lower and not ("normaldx" in lower)
		elif kind == "rough":
			matched = "rough" in lower
		elif kind == "ao":
			matched = "ambientocclusion" in lower or lower.ends_with("_ao.jpg")
		if matched:
			best = name
	if best == "":
		return null
	return load("%s/%s" % [GRASS_DIR, best]) as Texture2D


func _apply_hdri() -> bool:
	var tex := load(HDR_PATH) as Texture2D
	if tex == null:
		push_error("field hdri missing")
		return false
	var world := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world == null or world.environment == null:
		push_error("world environment missing")
		return false
	var env := world.environment
	var sky := Sky.new()
	var panorama := PanoramaSkyMaterial.new()
	panorama.panorama = tex
	sky.sky_material = panorama
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_exposure = 1.0
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12
	env.glow_intensity = 0.22
	env.glow_strength = 0.35
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.2
	var sun := get_parent().get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.light_energy = 1.05
	return true


func _dress_ball() -> void:
	var ball := get_parent().get_node_or_null("Ball") as Node3D
	if ball == null:
		push_error("ball missing for dress")
		return
	var packed := load(BALL_PATH) as PackedScene
	if packed == null:
		push_error("football model missing")
		return
	var model := packed.instantiate()
	var inflated := model.find_child("football_inflated", true, false) as MeshInstance3D
	if inflated == null or inflated.mesh == null:
		model.free()
		push_error("inflated football mesh missing")
		return
	var aabb := inflated.mesh.get_aabb()
	var longest := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	if longest < 0.001:
		model.free()
		push_error("football aabb empty")
		return
	var fit := BALL_DIAMETER / longest
	var holder := Node3D.new()
	holder.name = "MatchBall"
	inflated.get_parent().remove_child(inflated)
	inflated.owner = null
	holder.add_child(inflated)
	model.free()
	inflated.rotation = Vector3.ZERO
	inflated.scale = Vector3.ONE * fit
	# glTF parks this ball beside the deflated one. Center the mesh on the rigid body.
	inflated.position = -aabb.get_center() * fit
	var prim := ball.get_node_or_null("MeshInstance3D") as GeometryInstance3D
	if prim != null:
		prim.visible = false
	var stripe := ball.get_node_or_null("Stripe") as GeometryInstance3D
	if stripe != null:
		stripe.visible = false
	ball.add_child(holder)


func _paint_turf() -> void:
	var ground := get_parent().get_node_or_null("Ground/MeshInstance3D") as MeshInstance3D
	if ground == null:
		push_error("turf ground missing parent=%s" % get_parent())
		return
	var image := Image.create(256, 256, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 47
	for y in 256:
		var stripe := int(y / 32) % 2
		var base := Color(0.11, 0.46, 0.16) if stripe == 0 else Color(0.20, 0.62, 0.24)
		for x in 256:
			var n := rng.randf_range(-0.035, 0.045)
			var speckle := rng.randf()
			var c := base
			c.r = clampf(c.r + n, 0.0, 1.0)
			c.g = clampf(c.g + n * 1.4, 0.0, 1.0)
			c.b = clampf(c.b + n * 0.4, 0.0, 1.0)
			if speckle > 0.92:
				c = c.lerp(Color(0.34, 0.55, 0.18), 0.55)
			elif speckle < 0.04:
				c = c.lerp(Color(0.05, 0.22, 0.08), 0.6)
			if speckle > 0.985:
				c = c.lerp(Color(0.45, 0.36, 0.16), 0.7)
			image.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(image)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.albedo_color = Color(1, 1, 1, 1)
	mat.roughness = 0.78
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.07, 0.07, 0.07)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ground.set_surface_override_material(0, mat)


func _build_bowl() -> void:
	_tier(Vector3(0, 1.1, -27.5), Vector3(28, 2.2, 6.5), Color(0.45, 0.47, 0.5))
	_tier(Vector3(0, 3.3, -30.5), Vector3(32, 2.4, 5.5), Color(0.32, 0.34, 0.38))
	_tier(Vector3(0, 5.6, -33.2), Vector3(36, 2.2, 4.5), Color(0.22, 0.24, 0.28))
	_tier(Vector3(-14.5, 1.3, -8), Vector3(6.5, 2.6, 30), Color(0.42, 0.44, 0.48))
	_tier(Vector3(-18.2, 3.6, -8), Vector3(5.5, 2.4, 34), Color(0.28, 0.3, 0.34))
	_tier(Vector3(14.5, 1.3, -8), Vector3(6.5, 2.6, 30), Color(0.42, 0.44, 0.48))
	_tier(Vector3(18.2, 3.6, -8), Vector3(5.5, 2.4, 34), Color(0.28, 0.3, 0.34))
	_tier(Vector3(0, 0.7, 10.5), Vector3(22, 1.4, 5), Color(0.4, 0.42, 0.46))
	_crowd(Vector3(0, 2.5, -27.2), Vector3(24, 1.2, 3.2), 90, Color(0.7, 0.12, 0.16))
	_crowd(Vector3(0, 4.8, -30.2), Vector3(28, 1.2, 2.8), 110, Color(0.12, 0.28, 0.7))
	_crowd(Vector3(-14.2, 2.9, -8), Vector3(2.4, 1.1, 26), 80, Color(0.85, 0.72, 0.15))
	_crowd(Vector3(14.2, 2.9, -8), Vector3(2.4, 1.1, 26), 80, Color(0.15, 0.55, 0.3))
	_crowd(Vector3(0, 1.6, 10.2), Vector3(18, 0.7, 2.2), 40, Color(0.75, 0.3, 0.12))


func _tier(pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.86
	mesh.surface_set_material(0, mat)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	add_child(inst)


func _crowd(origin: Vector3, area: Vector3, count: int, tint: Color) -> void:
	var person := BoxMesh.new()
	person.size = Vector3(0.28, 0.42, 0.22)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.7
	person.surface_set_material(0, mat)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = person
	multi.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(origin.x * 13.0 + origin.z * 7.0)) + count
	var palette: Array[Color] = [
		tint,
		tint.lerp(Color(0.95, 0.9, 0.85), 0.55),
		Color(0.1, 0.12, 0.16),
		Color(0.85, 0.2, 0.22),
		Color(0.95, 0.82, 0.2),
		Color(0.2, 0.45, 0.9),
	]
	for i in count:
		var px := origin.x + rng.randf_range(-area.x * 0.5, area.x * 0.5)
		var py := origin.y + rng.randf_range(-area.y * 0.5, area.y * 0.5)
		var pz := origin.z + rng.randf_range(-area.z * 0.5, area.z * 0.5)
		multi.set_instance_transform(i, Transform3D(Basis(), Vector3(px, py, pz)))
		multi.set_instance_color(i, palette[rng.randi() % palette.size()])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = multi
	add_child(inst)


func _build_boards() -> void:
	var colors: Array[Color] = [
		Color(0.9, 0.15, 0.18),
		Color(0.12, 0.35, 0.75),
		Color(0.95, 0.78, 0.1),
		Color(0.1, 0.55, 0.32),
		Color(0.95, 0.95, 0.95),
	]
	for i in 6:
		var z := -9.0 + float(i) * 2.3
		_board(Vector3(-8.35, 0.55, z), Vector3(0.12, 0.9, 2.05), colors[i % colors.size()])
		_board(Vector3(8.35, 0.55, z), Vector3(0.12, 0.9, 2.05), colors[(i + 2) % colors.size()])
	_board(Vector3(0, 0.5, 6.15), Vector3(14.5, 0.85, 0.12), Color(0.08, 0.1, 0.14))
	_board(Vector3(-3.2, 0.45, -13.4), Vector3(2.4, 0.7, 0.12), Color(0.85, 0.2, 0.15))
	_board(Vector3(3.2, 0.45, -13.4), Vector3(2.4, 0.7, 0.12), Color(0.15, 0.4, 0.8))


func _board(pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.45
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.18
	mesh.surface_set_material(0, mat)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	add_child(inst)


func _build_lights() -> void:
	var spots: Array[Vector3] = [
		Vector3(-12.5, 0, -18),
		Vector3(12.5, 0, -18),
		Vector3(-12.5, 0, 4),
		Vector3(12.5, 0, 4),
	]
	for base in spots:
		_pole(base)
		var lamp := OmniLight3D.new()
		lamp.position = base + Vector3(0, 11.2, 0)
		lamp.light_color = Color(1.0, 0.96, 0.88)
		lamp.light_energy = 0.8 if _hdri else 2.4
		lamp.omni_range = 36.0
		lamp.shadow_enabled = false
		add_child(lamp)


func _pole(base: Vector3) -> void:
	var pole := BoxMesh.new()
	pole.size = Vector3(0.28, 11.0, 0.28)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.75, 0.78, 0.82)
	metal.metallic = 0.6
	metal.roughness = 0.28
	pole.surface_set_material(0, metal)
	var inst := MeshInstance3D.new()
	inst.mesh = pole
	inst.position = base + Vector3(0, 5.5, 0)
	add_child(inst)
	var head := SphereMesh.new()
	head.radius = 0.45
	head.height = 0.9
	head.radial_segments = 8
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1, 0.97, 0.9)
	glow.emission_enabled = true
	glow.emission = Color(1, 0.95, 0.8)
	glow.emission_energy_multiplier = 3.0
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	head.surface_set_material(0, glow)
	var bulb := MeshInstance3D.new()
	bulb.mesh = head
	bulb.position = base + Vector3(0, 11.2, 0)
	add_child(bulb)


func _build_sky() -> void:
	var image := Image.create(16, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		var t := float(y) / 127.0
		var c := Color(0.36, 0.62, 0.95).lerp(Color(0.78, 0.88, 0.98), t)
		for x in 16:
			image.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(image)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.01, 0.02, 0.01)
	var sky := SphereMesh.new()
	sky.radius = 90.0
	sky.height = 180.0
	sky.radial_segments = 16
	sky.rings = 12
	sky.surface_set_material(0, mat)
	var inst := MeshInstance3D.new()
	inst.mesh = sky
	inst.position = Vector3(0, 10, -8)
	add_child(inst)
