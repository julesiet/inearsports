extends StaticBody3D

const NET_WIDTH := 9.0
const NET_HEIGHT := 0.9
const NET_DEPTH := 0.018
const HOLE_SPACING := 0.09


func _ready() -> void:
	var net_material := StandardMaterial3D.new()
	net_material.albedo_color = Color(0.12, 0.14, 0.13, 1.0)
	net_material.roughness = 0.9
	_add_strands(
		Vector3(0.014, NET_HEIGHT, NET_DEPTH),
		Vector3(-NET_WIDTH / 2.0, NET_HEIGHT / 2.0, 0.0),
		int(ceil(NET_WIDTH / HOLE_SPACING)) + 1,
		Vector3(HOLE_SPACING, 0.0, 0.0),
		net_material
	)

	var horizontal_count := int(floor(NET_HEIGHT / HOLE_SPACING)) + 1
	_add_strands(
		Vector3(NET_WIDTH, 0.014, NET_DEPTH),
		Vector3(0.0, 0.04, 0.0),
		horizontal_count,
		Vector3(0.0, HOLE_SPACING, 0.0),
		net_material
	)


func _add_strands(
	strand_size: Vector3,
	first_position: Vector3,
	count: int,
	position_step: Vector3,
	material: Material
) -> void:
	var strand_mesh := BoxMesh.new()
	strand_mesh.size = strand_size
	strand_mesh.material = material

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = strand_mesh
	multimesh.instance_count = count
	for index in range(count):
		var position := first_position + position_step * index
		multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, position))

	var strands := MultiMeshInstance3D.new()
	strands.multimesh = multimesh
	add_child(strands)
