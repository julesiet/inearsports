extends Node3D

const HEAD_HALF_WIDTH := 0.18
const HEAD_HALF_HEIGHT := 0.25
const HEAD_HALF_DEPTH := 0.025


func _enter_tree() -> void:
	var hit_collision := get_node_or_null("HitArea/HitCollision") as CollisionShape3D
	if hit_collision == null:
		return

	var points := PackedVector3Array()
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		var point := Vector3(
			HEAD_HALF_WIDTH * cos(angle),
			HEAD_HALF_HEIGHT * sin(angle),
			0.0
		)
		points.append(Vector3(point.x, point.y, -HEAD_HALF_DEPTH))
		points.append(Vector3(point.x, point.y, HEAD_HALF_DEPTH))

	var racket_shape := ConvexPolygonShape3D.new()
	racket_shape.points = points
	hit_collision.shape = racket_shape


func _ready() -> void:
	_add_frame()
	_add_stringbed()
	_add_handle()


func _add_frame() -> void:
	var frame_material := StandardMaterial3D.new()
	frame_material.albedo_color = _player_racket_color()
	frame_material.metallic = 0.45
	frame_material.roughness = 0.35

	var frame_mesh := TorusMesh.new()
	frame_mesh.inner_radius = 0.94
	frame_mesh.outer_radius = 1.0
	frame_mesh.rings = 48
	frame_mesh.ring_segments = 12
	frame_mesh.material = frame_material

	var frame := MeshInstance3D.new()
	frame.name = "RacketFrame"
	frame.mesh = frame_mesh
	frame.rotation.x = PI / 2.0
	frame.scale = Vector3(HEAD_HALF_WIDTH, 0.018, HEAD_HALF_HEIGHT)
	add_child(frame)


func _add_stringbed() -> void:
	var string_material := StandardMaterial3D.new()
	string_material.albedo_color = Color(0.9, 0.88, 0.78, 1.0)
	string_material.roughness = 0.8

	var inner_half_width := 0.158
	var inner_half_height := 0.228
	var horizontal_count := 11
	var horizontal_mesh := BoxMesh.new()
	horizontal_mesh.size = Vector3(1.0, 0.006, 0.008)
	horizontal_mesh.material = string_material
	var horizontal_transforms: Array[Transform3D] = []
	for index in range(horizontal_count):
		var y := (float(index) / float(horizontal_count - 1) * 2.0 - 1.0) * 0.18
		var width_ratio := sqrt(1.0 - (y / inner_half_height) ** 2)
		var line_width := inner_half_width * 2.0 * width_ratio
		horizontal_transforms.append(
			Transform3D(Basis.from_scale(Vector3(line_width, 1.0, 1.0)), Vector3(0.0, y, 0.0))
		)
	_add_multimesh("HorizontalStrings", horizontal_mesh, horizontal_transforms)

	var vertical_count := 7
	var vertical_mesh := BoxMesh.new()
	vertical_mesh.size = Vector3(0.006, 1.0, 0.008)
	vertical_mesh.material = string_material
	var vertical_transforms: Array[Transform3D] = []
	for index in range(vertical_count):
		var x := (float(index) / float(vertical_count - 1) * 2.0 - 1.0) * 0.12
		var height_ratio := sqrt(1.0 - (x / inner_half_width) ** 2)
		var line_height := inner_half_height * 2.0 * height_ratio
		vertical_transforms.append(
			Transform3D(Basis.from_scale(Vector3(1.0, line_height, 1.0)), Vector3(x, 0.0, 0.0))
		)
	_add_multimesh("VerticalStrings", vertical_mesh, vertical_transforms)


func _add_multimesh(
	mesh_name: String,
	mesh: BoxMesh,
	transforms: Array[Transform3D]
) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])

	var strings := MultiMeshInstance3D.new()
	strings.name = mesh_name
	strings.multimesh = multimesh
	add_child(strings)


func _add_handle() -> void:
	var frame_material := StandardMaterial3D.new()
	frame_material.albedo_color = _player_racket_color()
	frame_material.metallic = 0.35
	frame_material.roughness = 0.45
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.018
	shaft_mesh.bottom_radius = 0.025
	shaft_mesh.height = 0.14
	shaft_mesh.material = frame_material
	var shaft := MeshInstance3D.new()
	shaft.name = "RacketShaft"
	shaft.mesh = shaft_mesh
	shaft.position.y = -0.29
	add_child(shaft)

	var grip_material := StandardMaterial3D.new()
	grip_material.albedo_color = Color(0.18, 0.12, 0.09, 1.0)
	grip_material.roughness = 0.95
	var grip_mesh := CylinderMesh.new()
	grip_mesh.top_radius = 0.022
	grip_mesh.bottom_radius = 0.022
	grip_mesh.height = 0.2
	grip_mesh.material = grip_material
	var grip := MeshInstance3D.new()
	grip.name = "RacketGrip"
	grip.mesh = grip_mesh
	grip.position.y = -0.46
	add_child(grip)


func _player_racket_color() -> Color:
	var ancestor: Node = self
	while ancestor != null:
		if ancestor.name == "Player1":
			return Color(0.9, 0.08, 0.12, 1.0)
		if ancestor.name == "Player2":
			return Color(0.08, 0.28, 0.92, 1.0)
		ancestor = ancestor.get_parent()
	return Color(0.12, 0.14, 0.17, 1.0)
