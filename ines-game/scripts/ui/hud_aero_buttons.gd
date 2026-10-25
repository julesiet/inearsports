extends Control

const PASTEL_GREEN := Color("#cdeac6")
const MIKU_BLUE := Color("#87dbff")
const YELLOW := Color("#fdf581")
const PINK := Color("#ffb6bd")
const WHITE := Color("#ffffff")
const INK := Color("#55717a")

const CELL_SIZE := 12
const CORNER_RADIUS := 14.0
const BORDER_WIDTH := 3

var _centered_message: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	await get_tree().process_frame
	_style_button(NodePath("TopBar/Player1Score"), PASTEL_GREEN)
	_style_button(NodePath("TopBar/RallyStatus"), MIKU_BLUE)
	_style_button(NodePath("TopBar/Player2Score"), PINK)
	_style_button(NodePath("ControllerStatus"), YELLOW)
	_centered_message = get_node_or_null("CenteredMessage") as Label
	if _centered_message != null:
		_style_button_node(_centered_message, YELLOW)
		_centered_message.resized.connect(_refresh_button.bind(_centered_message, YELLOW))
		_refresh_button(_centered_message, YELLOW)
		_centered_message.visible = not _centered_message.text.is_empty()


func _process(_delta: float) -> void:
	if _centered_message != null:
		_centered_message.visible = not _centered_message.text.is_empty()


func _style_button(node_path: NodePath, accent: Color) -> void:
	var label := get_node_or_null(node_path) as Label
	if label == null:
		push_warning("HUD button label not found: %s" % node_path)
		return

	_style_button_node(label, accent)
	label.resized.connect(_refresh_button.bind(label, accent))
	_refresh_button(label, accent)


func _style_button_node(label: Label, accent: Color) -> void:
	label.add_theme_color_override("font_color", INK)
	if label.label_settings != null:
		var local_settings := label.label_settings.duplicate() as LabelSettings
		local_settings.font_color = INK
		label.label_settings = local_settings


func _refresh_button(label: Label, accent: Color) -> void:
	var width := maxi(2, int(round(label.size.x)))
	var height := maxi(2, int(round(label.size.y)))
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	for y in range(height):
		for x in range(width):
			if not _inside_rounded_rect(x, y, width, height):
				continue

			var tile_x := floori(float(x) / CELL_SIZE)
			var tile_y := floori(float(y) / CELL_SIZE)
			var tile_color := accent if (tile_x + tile_y) % 2 == 0 else WHITE
			if x < BORDER_WIDTH or x >= width - BORDER_WIDTH or y < BORDER_WIDTH or y >= height - BORDER_WIDTH:
				tile_color = accent
			image.set_pixel(x, y, tile_color)

	var texture := ImageTexture.create_from_image(image)
	var button_style := StyleBoxTexture.new()
	button_style.texture = texture
	button_style.content_margin_left = 14.0
	button_style.content_margin_right = 14.0
	button_style.content_margin_top = 6.0
	button_style.content_margin_bottom = 6.0
	label.add_theme_stylebox_override("normal", button_style)


func _inside_rounded_rect(x: int, y: int, width: int, height: int) -> bool:
	var radius := minf(CORNER_RADIUS, (float(mini(width, height)) - 1.0) * 0.5)
	var nearest_x := clampf(float(x), radius, float(width) - radius - 1.0)
	var nearest_y := clampf(float(y), radius, float(height) - radius - 1.0)
	var dx := float(x) - nearest_x
	var dy := float(y) - nearest_y
	return dx * dx + dy * dy <= radius * radius
