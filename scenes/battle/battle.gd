class_name Battle
extends Node2D

# Battle: Main combat arena orchestrating grid, tab bases, AI, triangulation, and HUD.

signal open_atlas_requested()
signal battle_restarted()

@onready var grid_manager: GridManager = $GridManager
@onready var triangulation_overlay: Node2D = $TriangulationOverlay
@onready var rival_ai: Node = $RivalAI
@onready var hud: CanvasLayer = $BattleHUD

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
	_spawn_tab(Vector2i(1, 4), TabBaseScript.Faction.PLAYER, "Tab #1", true)
	_spawn_tab(Vector2i(2, 4), TabBaseScript.Faction.PLAYER, "Tab #2", true)

	# Spawn Starting Rival Tabs (Top-Right)
	_spawn_tab(Vector2i(5, 1), TabBaseScript.Faction.RIVAL, "rival://nexus", true)
	_spawn_tab(Vector2i(5, 2), TabBaseScript.Faction.RIVAL, "rival://hub", true)

	# Spawn Neutral Contest Tabs (Center)
	_spawn_tab(Vector2i(2, 2), TabBaseScript.Faction.NEUTRAL, "about:blank", false)
	_spawn_tab(Vector2i(4, 2), TabBaseScript.Faction.NEUTRAL, "about:cache", false)
	_spawn_tab(Vector2i(3, 3), TabBaseScript.Faction.NEUTRAL, "about:memory", false)

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

func _on_triangulation_detected(is_active: bool, l_tabs: Array) -> void:
	if triangulation_overlay.has_method("set_triangulation"):
		triangulation_overlay.set_triangulation(is_active, l_tabs)

func _on_build_tower_requested() -> void:
	var focused = BattleManager.active_focused_tab
	if focused != null and is_instance_valid(focused) and focused.has_method("add_tower"):
		var success: bool = focused.add_tower(TabTower.Tier.TIER_1)
		if success:
			AudioSynth.play_merge()
		else:
			# If full, attempt merge upgrade
			focused.merge_available_towers()

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
