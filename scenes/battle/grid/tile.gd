class_name GridTile
extends Control

# Visual slot for one coordinate cell in the 7x6 Tab Siege grid

signal tile_clicked(grid_pos: Vector2i)
signal tile_hovered(grid_pos: Vector2i, entered: bool)

enum HighlightState {
	NORMAL,
	HOVER,
	VALID_DROP,
	INVALID_DROP
}

var grid_pos: Vector2i = Vector2i.ZERO
var highlight_state: HighlightState = HighlightState.NORMAL
var occupant_tab: Node = null # Reference to current TabBase if occupied

const COLOR_NORMAL_BG: Color = Color(0.12, 0.14, 0.18, 0.6)
const COLOR_NORMAL_BORDER: Color = Color(0.22, 0.26, 0.32, 0.8)
const COLOR_HOVER_BORDER: Color = Color(0.4, 0.5, 0.65, 0.9)
const COLOR_VALID_DROP_BG: Color = Color(0.1, 0.5, 0.8, 0.25)
const COLOR_VALID_DROP_BORDER: Color = Color(0.2, 0.8, 1.0, 0.95)
const COLOR_INVALID_DROP_BG: Color = Color(0.6, 0.1, 0.1, 0.2)
const COLOR_INVALID_DROP_BORDER: Color = Color(0.9, 0.2, 0.2, 0.8)

func _ready() -> void:
	custom_minimum_size = Vector2(104, 88)
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func set_grid_pos(pos: Vector2i) -> void:
	grid_pos = pos
	tooltip_text = "Grid [%d, %d]" % [pos.x, pos.y]
	queue_redraw()

func set_highlight(state: HighlightState) -> void:
	if highlight_state != state:
		highlight_state = state
		queue_redraw()

func is_empty() -> bool:
	return occupant_tab == null or not is_instance_valid(occupant_tab)

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var bg_col := COLOR_NORMAL_BG
	var border_col := COLOR_NORMAL_BORDER
	var border_width: float = 1.0

	match highlight_state:
		HighlightState.HOVER:
			border_col = COLOR_HOVER_BORDER
			border_width = 1.5
		HighlightState.VALID_DROP:
			bg_col = COLOR_VALID_DROP_BG
			border_col = COLOR_VALID_DROP_BORDER
			border_width = 2.5
		HighlightState.INVALID_DROP:
			bg_col = COLOR_INVALID_DROP_BG
			border_col = COLOR_INVALID_DROP_BORDER
			border_width = 2.0

	# Rounded tab dock background
	draw_rect(rect, bg_col, true)
	draw_rect(rect, border_col, false, border_width)

	# Faint coordinate dot / label in corner
	var coord_str := "%d,%d" % [grid_pos.x, grid_pos.y]
	var font := ThemeDB.fallback_font
	var font_size := 9
	draw_string(font, Vector2(6, 14), coord_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.4, 0.45, 0.55, 0.4))

func _on_mouse_entered() -> void:
	if highlight_state == HighlightState.NORMAL:
		set_highlight(HighlightState.HOVER)
	tile_hovered.emit(grid_pos, true)

func _on_mouse_exited() -> void:
	if highlight_state == HighlightState.HOVER:
		set_highlight(HighlightState.NORMAL)
	tile_hovered.emit(grid_pos, false)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tile_clicked.emit(grid_pos)
