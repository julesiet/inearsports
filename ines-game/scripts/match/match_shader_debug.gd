extends Node

const STYLIZED_SHADER: Shader = preload("res://shaders/stylized.gdshader")

var _restore_states: Array[Dictionary] = []
var _materials: Array[ShaderMaterial] = []
var _prepared := false
var _halftone_texture: ImageTexture
var _white_texture: ImageTexture


func set_preset(preset_index: int) -> void:
	if preset_index <= 0:
		_restore_original_materials()
		return
	_prepare_materials()
	_restore_original_materials()
	_apply_preset_to_materials(preset_index)
	for state in _restore_states:
		var mesh_instance: MeshInstance3D = state["mesh"]
		var debug_materials: Array = state["debug_materials"]
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		mesh_instance.material_override = null
		for surface_index in range(debug_materials.size()):
			var debug_material: Material = debug_materials[surface_index]
			if debug_material != null:
				mesh_instance.set_surface_override_material(surface_index, debug_material)
			elif state["material_override"] != null:
				mesh_instance.set_surface_override_material(
					surface_index,
					state["material_override"]
				)


func _prepare_materials() -> void:
	if _prepared:
		return
	_prepared = true
	_halftone_texture = _create_halftone_texture()
	var white_image := Image.create(1, 1, false, Image.FORMAT_RGB8)
	white_image.fill(Color.WHITE)
	_white_texture = ImageTexture.create_from_image(white_image)
	var match_root := get_node("../..")
	for node in match_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var original_overrides: Array[Material] = []
		var debug_materials: Array[Material] = []
		var has_debug_material := false
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var original_surface := mesh_instance.get_surface_override_material(surface_index)
			original_overrides.append(original_surface)
			var source_material: Material = mesh_instance.material_override
			if source_material == null:
				source_material = original_surface
			if source_material == null:
				source_material = mesh_instance.mesh.surface_get_material(surface_index)
			var debug_material := _make_debug_material(source_material)
			debug_materials.append(debug_material)
			if debug_material != null:
				has_debug_material = true
				_materials.append(debug_material)
		if has_debug_material:
			_restore_states.append({
				"mesh": mesh_instance,
				"material_override": mesh_instance.material_override,
				"surface_overrides": original_overrides,
				"debug_materials": debug_materials,
			})


func _make_debug_material(source_material: Material) -> ShaderMaterial:
	if source_material is BaseMaterial3D:
		var base_material := source_material as BaseMaterial3D
		if base_material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return null
	var shader_material := ShaderMaterial.new()
	shader_material.shader = STYLIZED_SHADER
	shader_material.set_shader_parameter("albedo_color", Color.WHITE)
	shader_material.set_shader_parameter("albedo_texture", _white_texture)
	shader_material.set_shader_parameter("albedo_affect", 0.0)
	shader_material.set_shader_parameter("use_stepped", true)
	shader_material.set_shader_parameter("steps", 3.0)
	shader_material.set_shader_parameter("step_smoothness", 0.28)
	shader_material.set_shader_parameter("shadow_tint", Color(0.18, 0.23, 0.38, 1.0))
	shader_material.set_shader_parameter("shadow_tint_amount", 0.38)
	shader_material.set_shader_parameter("specular", 0.0)
	shader_material.set_shader_parameter("normal_strength", 0.0)
	shader_material.set_shader_parameter("use_rim", false)
	shader_material.set_shader_parameter("rim_color", Color(0.22, 0.78, 1.0, 1.0))
	shader_material.set_shader_parameter("rim_amount", 2.0)
	shader_material.set_shader_parameter("rim_smoothness", 0.2)
	shader_material.set_shader_parameter("rim_mask_shadow", 0.35)
	shader_material.set_shader_parameter("rim_blend", 0.8)
	shader_material.set_shader_parameter("use_pattern", false)
	shader_material.set_shader_parameter("pattern_texture", _halftone_texture)
	shader_material.set_shader_parameter("pattern_uv_mode", 0)
	shader_material.set_shader_parameter("pattern_tiling", 32.0)
	shader_material.set_shader_parameter("pattern_amount", 0.3)
	shader_material.set_shader_parameter("pattern_smoothness", 0.55)
	shader_material.set_shader_parameter("pattern_blend", 0.7)
	if source_material is BaseMaterial3D:
		var base_material := source_material as BaseMaterial3D
		shader_material.set_shader_parameter("albedo_color", base_material.albedo_color)
		if base_material.albedo_texture != null:
			shader_material.set_shader_parameter("albedo_texture", base_material.albedo_texture)
	return shader_material


func _apply_preset_to_materials(preset_index: int) -> void:
	for material in _materials:
		material.set_shader_parameter("use_stepped", true)
		material.set_shader_parameter("use_rim", false)
		material.set_shader_parameter("use_pattern", false)
		match preset_index:
			1: # Cel shading
				material.set_shader_parameter("steps", 3.0)
				material.set_shader_parameter("shadow_tint_amount", 0.38)
			2: # Cel shading plus rim light
				material.set_shader_parameter("steps", 3.0)
				material.set_shader_parameter("shadow_tint_amount", 0.38)
				material.set_shader_parameter("use_rim", true)
			3: # Halftone cel shading
				material.set_shader_parameter("steps", 4.0)
				material.set_shader_parameter("shadow_tint_amount", 0.25)
				material.set_shader_parameter("use_pattern", true)

		if preset_index == 3:
			material.set_shader_parameter("pattern_blend", 0.7)


func _restore_original_materials() -> void:
	for state in _restore_states:
		var mesh_instance: MeshInstance3D = state["mesh"]
		if mesh_instance == null:
			continue
		mesh_instance.material_override = state["material_override"]
		var surface_overrides: Array = state["surface_overrides"]
		for surface_index in range(surface_overrides.size()):
			mesh_instance.set_surface_override_material(
				surface_index,
				surface_overrides[surface_index]
			)


func _create_halftone_texture() -> ImageTexture:
	const SIZE := 64
	const CELL := 16
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	image.fill(Color.WHITE)
	for y in range(SIZE):
		for x in range(SIZE):
			var local_x := x % CELL - CELL / 2
			var local_y := y % CELL - CELL / 2
			if local_x * local_x + local_y * local_y <= 12:
				image.set_pixel(x, y, Color(0.12, 0.12, 0.12, 1.0))
	return ImageTexture.create_from_image(image)
