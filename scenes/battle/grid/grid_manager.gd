class_name GridManager
extends Node2D

# GridManager: Oversees the 7x6 tactical board, tile occupancy,
# Manhattan distance checks, drop validation, and L-Shape Triangulation detection.

signal tab_relocated(tab: Node, from_pos: Vector2i, to_pos: Vector2i)
signal triangulation_detected(is_active: bool, l_tabs: Array)

const GRID_COLS: int = 6
const GRID_ROWS: int = 5
const TILE_WIDTH: float = 104.0
const TILE_HEIGHT: float = 88.0
const TILE_GAP: float = 8.0

# Origin offset to center the 6x5 grid on 1280x720 canvas
const GRID_ORIGIN: Vector2 = Vector2(308.0, 142.0)

var tiles: Dictionary = {} # Vector2i -> GridTile
var tab_positions: Dictionary = {} # Node -> Vector2i
var grid_occupants: Dictionary = {} # Vector2i -> Node

const TileScene: PackedScene = preload("res://scenes/battle/grid/tile.tscn")

func _ready() -> void:
	queue_redraw()
	_generate_grid()

func _draw() -> void:
	var total_w := GRID_COLS * TILE_WIDTH + (GRID_COLS - 1) * TILE_GAP
	var total_h := GRID_ROWS * TILE_HEIGHT + (GRID_ROWS - 1) * TILE_GAP
	var pad := 14.0
	var header_h := 30.0
	var vp_rect := Rect2(
		GRID_ORIGIN.x - pad,
		GRID_ORIGIN.y - header_h - pad,
		total_w + pad * 2.0,
		total_h + header_h + pad * 2.0
	)
	var shadow_rect := Rect2(vp_rect.position + Vector2(3, 4), vp_rect.size)
	
	# Hard drop shadow
	draw_rect(shadow_rect, Color(0.06, 0.09, 0.16, 1.0), true) # #0F172A
	# Browser Viewport Background (#F8FAFC)
	draw_rect(vp_rect, Color(0.97, 0.98, 0.99, 1.0), true) # #F8FAFC
	# 3px dark navy/black border
	draw_rect(vp_rect, Color(0.06, 0.09, 0.16, 1.0), false, 3.0)
	
	# Viewport Mini Toolbar Header
	var header_rect := Rect2(vp_rect.position, Vector2(vp_rect.size.x, header_h))
	draw_rect(header_rect, Color(0.89, 0.91, 0.94, 1.0), true) # #E2E8F0
	draw_line(
		Vector2(vp_rect.position.x, vp_rect.position.y + header_h),
		Vector2(vp_rect.position.x + vp_rect.size.x, vp_rect.position.y + header_h),
		Color(0.06, 0.09, 0.16, 1.0),
		2.0
	)
	
	# Mini traffic-light dots
	var dot_y := vp_rect.position.y + header_h * 0.5
	draw_circle(Vector2(vp_rect.position.x + 14, dot_y), 4.5, Color(0.94, 0.27, 0.27))
	draw_circle(Vector2(vp_rect.position.x + 28, dot_y), 4.5, Color(0.96, 0.62, 0.04))
	draw_circle(Vector2(vp_rect.position.x + 42, dot_y), 4.5, Color(0.06, 0.73, 0.51))
	
	# Mini address pill
	var pill_rect := Rect2(vp_rect.position.x + 58, vp_rect.position.y + 5, vp_rect.size.x - 72, header_h - 10)
	draw_rect(pill_rect, Color(1, 1, 1), true)
	draw_rect(pill_rect, Color(0.80, 0.84, 0.88), false, 1.5)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(pill_rect.position.x + 8, pill_rect.position.y + 14), "🔒 https://tab-tactics.lan/tactical-viewport [6x5 Grid - 30 Tiles]", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.28, 0.33, 0.41))

func _generate_grid() -> void:
	for y in range(GRID_ROWS):
		for x in range(GRID_COLS):
			var pos := Vector2i(x, y)
			var tile: GridTile = TileScene.instantiate()
			tile.set_grid_pos(pos)
			tile.position = grid_to_world_top_left(pos)
			add_child(tile)
			tiles[pos] = tile

func grid_to_world_top_left(pos: Vector2i) -> Vector2:
	return GRID_ORIGIN + Vector2(
		pos.x * (TILE_WIDTH + TILE_GAP),
		pos.y * (TILE_HEIGHT + TILE_GAP)
	)

func grid_to_world_center(pos: Vector2i) -> Vector2:
	return grid_to_world_top_left(pos) + Vector2(TILE_WIDTH * 0.5, TILE_HEIGHT * 0.5)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	var local_pos := world_pos - GRID_ORIGIN
	var cell_w := TILE_WIDTH + TILE_GAP
	var cell_h := TILE_HEIGHT + TILE_GAP
	var gx := int(floor(local_pos.x / cell_w))
	var gy := int(floor(local_pos.y / cell_h))
	return Vector2i(gx, gy)

func is_valid_cell(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < GRID_COLS and pos.y >= 0 and pos.y < GRID_ROWS

func manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func get_tile(pos: Vector2i) -> GridTile:
	return tiles.get(pos, null)

func get_tab_at(pos: Vector2i) -> Node:
	return grid_occupants.get(pos, null)

func get_tab_grid_pos(tab: Node) -> Vector2i:
	return tab_positions.get(tab, Vector2i(-1, -1))

func register_tab(tab: Node, pos: Vector2i) -> void:
	if not is_valid_cell(pos):
		return
	grid_occupants[pos] = tab
	tab_positions[tab] = pos
	var tile := get_tile(pos)
	if tile:
		tile.occupant_tab = tab
	check_triangulation()

func unregister_tab(tab: Node) -> void:
	if tab_positions.has(tab):
		var pos: Vector2i = tab_positions[tab]
		tab_positions.erase(tab)
		if grid_occupants.get(pos) == tab:
			grid_occupants.erase(pos)
		var tile := get_tile(pos)
		if tile and tile.occupant_tab == tab:
			tile.occupant_tab = null
	check_triangulation()

func can_relocate_tab_to(tab: Node, target_pos: Vector2i, max_range: int) -> bool:
	if not is_valid_cell(target_pos):
		return false
	
	var current_pos: Vector2i = get_tab_grid_pos(tab)
	if current_pos == target_pos:
		return false
	
	# Manhattan distance check: abs(dx) + abs(dy) <= max_range
	var dist := manhattan_distance(current_pos, target_pos)
	if dist > max_range:
		return false
	
	# Cannot land on rival tabs
	var occupant: Node = get_tab_at(target_pos)
	if occupant != null and is_instance_valid(occupant):
		if occupant.has_method("is_rival") and occupant.is_rival():
			return false
		# If occupied by another friendly tab, cannot land
		if occupant.has_method("is_player") and occupant.is_player():
			return false
	
	return true

func relocate_tab(tab: Node, target_pos: Vector2i, max_range: int) -> bool:
	if not can_relocate_tab_to(tab, target_pos, max_range):
		return false
	
	var old_pos := get_tab_grid_pos(tab)
	unregister_tab(tab)
	
	# If neutral tab at target, absorb or overwrite neutral tab
	var occupant: Node = get_tab_at(target_pos)
	if occupant != null and is_instance_valid(occupant):
		if occupant.has_method("is_neutral") and occupant.is_neutral():
			unregister_tab(occupant)
			occupant.queue_free()

	register_tab(tab, target_pos)
	tab.position = grid_to_world_center(target_pos)
	tab_relocated.emit(tab, old_pos, target_pos)
	check_triangulation()
	return true

func highlight_valid_drop_tiles(source_tab: Node, max_range: int) -> void:
	var current_pos := get_tab_grid_pos(source_tab)
	for pos in tiles.keys():
		var tile: GridTile = tiles[pos]
		if can_relocate_tab_to(source_tab, pos, max_range):
			tile.set_highlight(GridTile.HighlightState.VALID_DROP)
		else:
			if pos == current_pos:
				tile.set_highlight(GridTile.HighlightState.NORMAL)
			else:
				tile.set_highlight(GridTile.HighlightState.NORMAL)

func clear_tile_highlights() -> void:
	for tile: GridTile in tiles.values():
		tile.set_highlight(GridTile.HighlightState.NORMAL)

func _get_battle_manager() -> Node:
	return get_node_or_null("/root/BattleManager") if is_inside_tree() else null

# L-Shape Triangulation Detector
# Checks if there are 3 player-held tabs forming an orthogonal L-tromino
func check_triangulation() -> Dictionary:
	var player_tabs: Array[Node] = []
	var player_positions: Array[Vector2i] = []
	
	for tab in tab_positions.keys():
		if is_instance_valid(tab) and tab.has_method("is_player") and tab.is_player():
			# Inert tabs (e.g. within 3s downtime after relocate) cannot sustain triangulation
			if tab.has_method("is_inert") and tab.is_inert():
				continue
			player_tabs.append(tab)
			player_positions.append(tab_positions[tab])

	var num_tabs := player_tabs.size()
	var bm = _get_battle_manager()
	if num_tabs < 3:
		triangulation_detected.emit(false, [])
		if bm:
			bm.update_triangulation_status(false, [])
		return {"found": false, "tabs": []}

	# Check all 3-tab combinations
	for i in range(num_tabs):
		for j in range(i + 1, num_tabs):
			for k in range(j + 1, num_tabs):
				var pos_i := player_positions[i]
				var pos_j := player_positions[j]
				var pos_k := player_positions[k]

				# Check if any of the three can be the corner 'V'
				if _is_l_corner(pos_i, pos_j, pos_k):
					var l_tabs = [player_tabs[i], player_tabs[j], player_tabs[k]]
					triangulation_detected.emit(true, l_tabs)
					if bm:
						bm.update_triangulation_status(true, l_tabs)
					return {"found": true, "tabs": l_tabs, "corner": player_tabs[i]}
				
				if _is_l_corner(pos_j, pos_i, pos_k):
					var l_tabs = [player_tabs[j], player_tabs[i], player_tabs[k]]
					triangulation_detected.emit(true, l_tabs)
					if bm:
						bm.update_triangulation_status(true, l_tabs)
					return {"found": true, "tabs": l_tabs, "corner": player_tabs[j]}
				
				if _is_l_corner(pos_k, pos_i, pos_j):
					var l_tabs = [player_tabs[k], player_tabs[i], player_tabs[j]]
					triangulation_detected.emit(true, l_tabs)
					if bm:
						bm.update_triangulation_status(true, l_tabs)
					return {"found": true, "tabs": l_tabs, "corner": player_tabs[k]}

	triangulation_detected.emit(false, [])
	if bm:
		bm.update_triangulation_status(false, [])
	return {"found": false, "tabs": []}

func _is_l_corner(corner: Vector2i, arm1: Vector2i, arm2: Vector2i) -> bool:
	# Both arms must be at distance 1 from corner
	var d1 := manhattan_distance(corner, arm1)
	var d2 := manhattan_distance(corner, arm2)
	if d1 != 1 or d2 != 1:
		return false
	
	# Vector from corner to arm1 and arm2
	var v1 := arm1 - corner
	var v2 := arm2 - corner
	
	# Orthogonal test: dot product == 0 (at 90 degrees)
	return (v1.x * v2.x + v1.y * v2.y) == 0

func get_adjacent_friendly_tabs(pos: Vector2i) -> Array[Node]:
	var result: Array[Node] = []
	var neighbors := [
		Vector2i(pos.x + 1, pos.y),
		Vector2i(pos.x - 1, pos.y),
		Vector2i(pos.x, pos.y + 1),
		Vector2i(pos.x, pos.y - 1)
	]
	for n_pos in neighbors:
		if is_valid_cell(n_pos):
			var tab := get_tab_at(n_pos)
			if tab != null and is_instance_valid(tab) and tab.has_method("is_player") and tab.is_player():
				result.append(tab)
	return result
