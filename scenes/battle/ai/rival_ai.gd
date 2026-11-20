class_name RivalAI
extends Node

# AI Rival opponent for 3-minute battle:
# Manages rival tab towers, launches cursor strikes, contests neutral tabs,
# and mounts aggressive disruption pushes whenever the player starts a 30s Triangulation Hold!

var strike_timer: float = 0.0
var base_strike_interval: float = 4.5
var aggressive_strike_interval: float = 2.2
var tower_build_timer: float = 0.0
var tower_build_interval: float = 6.0
var enemy_spawn_timer: float = 0.0
var enemy_spawn_interval: float = 4.2

var rival_coins: int = 50
var grid_manager: GridManager = null

const CursorStrikeScene: PackedScene = preload("res://scenes/battle/cursor_strike/cursor_strike.tscn")
const EnemyScene: PackedScene = preload("res://scenes/battle/enemy/enemy.tscn")

func _ready() -> void:
	strike_timer = 3.0 # Initial grace period before first strike
	enemy_spawn_timer = 2.0

func _process(delta: float) -> void:
	var bm = get_node_or_null("/root/BattleManager")
	if bm == null or not bm.is_match_active:
		return

	# Passive income for AI
	rival_coins += int(delta * 4.0)

	# Decide strike interval based on whether player is holding an L-shape
	var current_interval := aggressive_strike_interval if bm.is_triangulation_holding else base_strike_interval
	
	strike_timer += delta
	if strike_timer >= current_interval:
		strike_timer = 0.0
		_execute_ai_cursor_strike(bm)

	tower_build_timer += delta
	if tower_build_timer >= tower_build_interval:
		tower_build_timer = 0.0
		_manage_ai_towers()

	# Tick enemy wave spawner (Pop-Up Swarm, Cookie Tracker, Malware Brute)
	enemy_spawn_timer += delta
	if enemy_spawn_timer >= enemy_spawn_interval:
		enemy_spawn_timer = 0.0
		_spawn_enemy(bm)

func _spawn_enemy(bm: Node) -> void:
	var enemy_type: Enemy.EnemyType = Enemy.EnemyType.POP_UP_SWARM
	if bm.is_triangulation_holding:
		enemy_type = Enemy.EnemyType.MALWARE_BRUTE
	elif bm.coins >= 80:
		enemy_type = Enemy.EnemyType.COOKIE_TRACKER
	else:
		var r := randf()
		if r < 0.5:
			enemy_type = Enemy.EnemyType.POP_UP_SWARM
		elif r < 0.8:
			enemy_type = Enemy.EnemyType.COOKIE_TRACKER
		else:
			enemy_type = Enemy.EnemyType.MALWARE_BRUTE

	var spawn_pos := Vector2(randf_range(820.0, 960.0), randf_range(200.0, 520.0))
	var enemy = EnemyScene.instantiate()
	enemy.init_enemy(enemy_type, spawn_pos)
	get_tree().current_scene.add_child(enemy)

func _execute_ai_cursor_strike(bm: Node) -> void:
	var target_tab: Node = null
	
	# Priority 1: If player is in Triangulation Hold, target one of the 3 L-shape tabs!
	if bm.is_triangulation_holding and not bm.triangulation_nodes.is_empty():
		var valid_l_tabs = bm.triangulation_nodes.filter(func(t): return is_instance_valid(t) and t.has_method("is_alive") and t.is_alive() and not t.is_shielded())
		if not valid_l_tabs.is_empty():
			target_tab = valid_l_tabs[randi() % valid_l_tabs.size()]

	# Priority 2: Target neutral tabs to expand
	if target_tab == null:
		var neutral_tabs = get_tree().get_nodes_in_group("tabs").filter(func(t): return is_instance_valid(t) and t.has_method("is_neutral") and t.is_neutral() and t.is_alive())
		if not neutral_tabs.is_empty():
			target_tab = neutral_tabs[randi() % neutral_tabs.size()]

	# Priority 3: Target any unshielded player tab
	if target_tab == null:
		var player_tabs = get_tree().get_nodes_in_group("tabs").filter(func(t): return is_instance_valid(t) and t.has_method("is_player") and t.is_player() and t.is_alive() and not t.is_shielded())
		if not player_tabs.is_empty():
			target_tab = player_tabs[randi() % player_tabs.size()]

	if target_tab != null:
		var strike: CursorStrike = CursorStrikeScene.instantiate()
		strike.init_strike(target_tab, 18.0, "rival", false)
		get_tree().current_scene.add_child(strike)

func _manage_ai_towers() -> void:
	var rival_tabs = get_tree().get_nodes_in_group("tabs").filter(func(t): return is_instance_valid(t) and t.has_method("is_rival") and t.is_rival() and t.is_alive())
	for tab in rival_tabs:
		if "towers" in tab and tab.towers.size() < 2 and rival_coins >= 20:
			rival_coins -= 20
			tab.add_tower(TabTower.Tier.TIER_1)
		elif "towers" in tab and tab.towers.size() >= 2 and rival_coins >= 30:
			var t1 = tab.towers[0]
			var t2 = tab.towers[1]
			if t1.can_merge_with(t2):
				rival_coins -= 30
				tab.merge_available_towers()
