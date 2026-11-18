class_name Battle
extends Node2D

# Battle: Main combat arena orchestrating grid, tab bases, AI, triangulation, and HUD.

signal open_atlas_requested()
signal battle_restarted()

@onready var grid_manager: GridManager = $GridManager
@onready var triangulation_overlay: Node2D = $TriangulationOverlay
@onready var rival_ai: Node = $RivalAI
@onready var hud: CanvasLayer = $BattleHUD

var _player_tab_1: Node2D = null
var _player_tab_2: Node2D = null
var _tutorial_step: int = 0
var _tutorial_tab1_initial_pos: Vector2 = Vector2.ZERO
var _tutorial_tab2_initial_pos: Vector2 = Vector2.ZERO

const TabBaseScript = preload("res://scenes/battle/tab/tab_base.gd")
const TabBaseScene: PackedScene = preload("res://scenes/battle/tab/tab_base.tscn")
const CursorStrikeScene: PackedScene = preload("res://scenes/battle/cursor_strike/cursor_strike.tscn")

func _ready() -> void:
	if "grid_manager" in rival_ai:
		rival_ai.grid_manager = grid_manager
	grid_manager.triangulation_detected.connect(_on_triangulation_detected)

	hud.build_tower_requested.connect(_on_build_tower_requested)
	hud.player_strike_requested.connect(_on_player_strike_requested)
	hud.atlas_menu_requested.connect(func(): open_atlas_requested.emit())
	hud.restart_requested.connect(func(): battle_restarted.emit())

	_setup_match()

func _setup_match() -> void:
	BattleManager.start_match()

	# Spawn Starting Player Tabs (Bottom-Left)
	_player_tab_1 = _spawn_tab(Vector2i(1, 4), TabBaseScript.Faction.PLAYER, "Tab #1", true)
	_player_tab_2 = _spawn_tab(Vector2i(2, 4), TabBaseScript.Faction.PLAYER, "Tab #2", true)

	# Spawn Starting Rival Tabs (Top-Right)
	_spawn_tab(Vector2i(5, 1), TabBaseScript.Faction.RIVAL, "rival://nexus", true)
	_spawn_tab(Vector2i(5, 2), TabBaseScript.Faction.RIVAL, "rival://hub", true)

	# Spawn Neutral Contest Tabs (Center)
	_spawn_tab(Vector2i(2, 2), TabBaseScript.Faction.NEUTRAL, "about:blank", false)
	_spawn_tab(Vector2i(4, 2), TabBaseScript.Faction.NEUTRAL, "about:cache", false)
	_spawn_tab(Vector2i(3, 3), TabBaseScript.Faction.NEUTRAL, "about:memory", false)

	var gd = get_node_or_null("/root/GameData")
	var is_tutorial: bool = gd != null and not gd.tutorial_done
	if is_tutorial:
		BattleManager.request_tab_focus(null)
		_start_tutorial()
	else:
		# Auto-focus the first player tab
		var player_tabs := get_tree().get_nodes_in_group("tabs").filter(func(t): return is_instance_valid(t) and t.has_method("is_player") and t.is_player())
		if not player_tabs.is_empty():
			BattleManager.request_tab_focus(player_tabs[0])

func _spawn_tab(pos: Vector2i, faction_id: int, title: String, with_tower: bool) -> Node:
	var tab: Node = TabBaseScene.instantiate()
	if tab.has_method("set_faction"):
		tab.set_faction(faction_id)
	tab.tab_title = title
	tab.grid_manager = grid_manager
	tab.position = grid_manager.grid_to_world_center(pos)
	add_child(tab)
	grid_manager.register_tab(tab, pos)
	
	if with_tower and tab.has_method("add_tower"):
		tab.add_tower(TabTower.Tier.TIER_1)
	
	return tab

func _process(_delta: float) -> void:
	if _tutorial_step == 0:
		return
	_update_tutorial_highlight()
	if _tutorial_step == 2:
		var moved_1: bool = _player_tab_1 != null and is_instance_valid(_player_tab_1) and _player_tab_1.global_position.distance_to(_tutorial_tab1_initial_pos) > 25.0
		var moved_2: bool = _player_tab_2 != null and is_instance_valid(_player_tab_2) and _player_tab_2.global_position.distance_to(_tutorial_tab2_initial_pos) > 25.0
		if (moved_1 or moved_2) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_advance_tutorial(3)

func _on_triangulation_detected(is_active: bool, l_tabs: Array) -> void:
	if triangulation_overlay.has_method("set_triangulation"):
		triangulation_overlay.set_triangulation(is_active, l_tabs)
	if _tutorial_step == 4 and is_active:
		_finish_tutorial()

func _on_build_tower_requested() -> void:
	var focused = BattleManager.active_focused_tab
	if focused != null and is_instance_valid(focused) and focused.has_method("add_tower"):
		focused.add_tower(TabTower.Tier.TIER_1)
	if _tutorial_step == 3:
		_advance_tutorial(4)

func _on_player_strike_requested() -> void:
	var rival_tabs := get_tree().get_nodes_in_group("tabs").filter(func(t): return is_instance_valid(t) and t.has_method("is_rival") and t.is_rival() and t.is_alive())
	if rival_tabs.is_empty():
		# Can strike neutral tabs to conquer them
		var neutrals := get_tree().get_nodes_in_group("tabs").filter(func(t): return is_instance_valid(t) and t.has_method("is_neutral") and t.is_neutral())
		if not neutrals.is_empty():
			_spawn_player_strike(neutrals[0])
		return

	# Target lowest HP rival tab
	var target: Node = rival_tabs[0]
	for r in rival_tabs:
		if r.current_hp < target.current_hp:
			target = r
	_spawn_player_strike(target)

func _spawn_player_strike(target: Node) -> void:
	var strike: CursorStrike = CursorStrikeScene.instantiate()
	strike.init_strike(target, 25.0, "player", false)
	add_child(strike)

func _start_tutorial() -> void:
	_tutorial_step = 1
	if hud.has_signal("tutorial_skipped") and not hud.tutorial_skipped.is_connected(_on_tutorial_skipped):
		hud.tutorial_skipped.connect(_on_tutorial_skipped)
	if not BattleManager.active_tab_focus_changed.is_connected(_on_tutorial_focus_changed):
		BattleManager.active_tab_focus_changed.connect(_on_tutorial_focus_changed)
	var cs: Vector2 = _get_screen_cell_size()
	var pos: Vector2 = Vector2.ZERO
	if _player_tab_1 and is_instance_valid(_player_tab_1):
		pos = _player_tab_1.get_global_transform_with_canvas().origin
	hud.show_tutorial_step("Click a tab to focus it (+50% boost)", Rect2(pos - cs * 0.5, cs).grow(4.0))

func _on_tutorial_focus_changed(tab: Node) -> void:
	if _tutorial_step == 1 and tab != null and is_instance_valid(tab):
		_advance_tutorial(2)

func _advance_tutorial(step: int) -> void:
	_tutorial_step = step
	var cs: Vector2 = _get_screen_cell_size()
	match step:
		2:
			if _player_tab_1 and is_instance_valid(_player_tab_1):
				_tutorial_tab1_initial_pos = _player_tab_1.global_position
			if _player_tab_2 and is_instance_valid(_player_tab_2):
				_tutorial_tab2_initial_pos = _player_tab_2.global_position
			var drop_world = grid_manager.grid_to_world_center(Vector2i(1, 3))
			var drop_screen = get_viewport().get_canvas_transform() * drop_world
			hud.show_tutorial_step("Drag a tab to move it", Rect2(drop_screen - cs * 0.5, cs).grow(4.0))
		3:
			if "coins" in BattleManager and BattleManager.coins < 20:
				if BattleManager.has_method("add_coins"):
					BattleManager.add_coins(20 - BattleManager.coins)
				else:
					BattleManager.coins = 20
			hud.show_tutorial_step("Buy towers with coins", hud.buy_tower_btn.get_global_rect().grow(4.0))
		4:
			var combined: Rect2 = Rect2()
			if _player_tab_1 and is_instance_valid(_player_tab_1) and _player_tab_2 and is_instance_valid(_player_tab_2):
				var p1 = _player_tab_1.get_global_transform_with_canvas().origin
				var p2 = _player_tab_2.get_global_transform_with_canvas().origin
				var r1 = Rect2(p1 - cs * 0.5, cs)
				var r2 = Rect2(p2 - cs * 0.5, cs)
				combined = r1.merge(r2).grow(8.0)
			hud.show_tutorial_step("Hold an L-shape for 30s to win", combined)

func _update_tutorial_highlight() -> void:
	var cs: Vector2 = _get_screen_cell_size()
	match _tutorial_step:
		1:
			if _player_tab_1 and is_instance_valid(_player_tab_1):
				var pos = _player_tab_1.get_global_transform_with_canvas().origin
				hud.update_tutorial_rect(Rect2(pos - cs * 0.5, cs).grow(4.0))
		2:
			var drop_world = grid_manager.grid_to_world_center(Vector2i(1, 3))
			var drop_screen = get_viewport().get_canvas_transform() * drop_world
			hud.update_tutorial_rect(Rect2(drop_screen - cs * 0.5, cs).grow(4.0))
		3:
			hud.update_tutorial_rect(hud.buy_tower_btn.get_global_rect().grow(4.0))
		4:
			if _player_tab_1 and is_instance_valid(_player_tab_1) and _player_tab_2 and is_instance_valid(_player_tab_2):
				var p1 = _player_tab_1.get_global_transform_with_canvas().origin
				var p2 = _player_tab_2.get_global_transform_with_canvas().origin
				var r1 = Rect2(p1 - cs * 0.5, cs)
				var r2 = Rect2(p2 - cs * 0.5, cs)
				hud.update_tutorial_rect(r1.merge(r2).grow(8.0))

func _on_tutorial_skipped() -> void:
	_finish_tutorial()

func _finish_tutorial() -> void:
	_tutorial_step = 0
	if hud and hud.has_method("hide_tutorial"):
		hud.hide_tutorial()
	var gd = get_node_or_null("/root/GameData")
	if gd:
		gd.tutorial_done = true
		gd.save_data()

func _get_screen_cell_size() -> Vector2:
	if grid_manager and grid_manager.has_method("grid_to_world_center"):
		var p0 = grid_manager.grid_to_world_center(Vector2i(0, 0))
		var p1 = grid_manager.grid_to_world_center(Vector2i(1, 0))
		var p2 = grid_manager.grid_to_world_center(Vector2i(0, 1))
		var dx = absf(p1.x - p0.x)
		var dy = absf(p2.y - p0.y)
		if dx > 10.0 and dy > 10.0:
			var scale_vec = get_viewport().get_canvas_transform().get_scale().abs()
			return Vector2(dx, dy) * scale_vec
	return Vector2(96.0, 96.0)
