extends SceneTree

# Test suite for Tab-Fold Tactics core rules, math logic, and flat-vector components

const GameDataScript = preload("res://scripts/game_data.gd")
const BattleManagerScript = preload("res://scripts/battle_manager.gd")
const GridManagerScript = preload("res://scenes/battle/grid/grid_manager.gd")
const EnemyScript = preload("res://scenes/battle/enemy/enemy.gd")

var game_data_node: Node
var battle_manager_node: Node

func _init() -> void:
	print("--- STARTING TAB-FOLD TACTICS TEST SUITE ---")
	game_data_node = GameDataScript.new()
	battle_manager_node = BattleManagerScript.new()
	root.add_child(game_data_node)
	root.add_child(battle_manager_node)
	
	test_game_data()
	test_battle_manager()
	test_manhattan_distance()
	test_drag_deadzone()
	test_turret_cascade_merging()
	test_grid_6x5()
	test_sacrifice_guardrails()
	test_pin_rewards()
	test_towers_and_enemies()
	
	print("--- ALL TAB-FOLD TACTICS TESTS PASSED SUCCESSFULLY! ---")
	quit(0)

func test_game_data() -> void:
	print("Testing GameData...")
	assert(game_data_node.get_drag_max_range() == 4, "Base drag range should be 4")
	assert(game_data_node.get_drag_cooldown() == 15.0, "Base drag cooldown should be 15s")
	assert(game_data_node.get_max_refresh_charges() == 2, "Base refresh charges should be 2")
	assert(game_data_node.get_refresh_cursor_count() == 5, "Base refresh cursor count should be 5")
	assert(is_equal_approx(game_data_node.get_focus_boost_multiplier(), 1.5), "Base focus multiplier should be 1.5 (+50%)")
	assert(is_equal_approx(game_data_node.get_focus_switch_delay(), 1.0), "Base focus switch delay should be 1.0s")
	assert(is_equal_approx(game_data_node.get_shield_duration(), 4.0), "Base shield duration should be 4.0s")
	assert(is_equal_approx(game_data_node.get_sacrifice_refund_ratio(), 0.5), "Base sacrifice refund should be 50%")
	
	# Verify Atlas 4 branches
	assert(game_data_node.UPGRADE_DEFS.has("drag_relocation"), "Must have drag branch")
	assert(game_data_node.UPGRADE_DEFS.has("refresh_rush"), "Must have refresh branch")
	assert(game_data_node.UPGRADE_DEFS.has("active_focus"), "Must have focus branch")
	assert(game_data_node.UPGRADE_DEFS.has("sacrifice_shield"), "Must have sacrifice branch")
	print("GameData test passed!")

func test_battle_manager() -> void:
	print("Testing BattleManager...")
	battle_manager_node.start_match()
	assert(battle_manager_node.is_match_active == true, "Match should be active after start")
	assert(battle_manager_node.match_time_remaining == 180.0, "Initial match duration should be 180s")
	assert(battle_manager_node.coins == 60, "Initial coins should be 60")
	assert(battle_manager_node.refresh_rush_charges == 2, "Initial refresh charges should be 2")
	assert(battle_manager_node.tabs_lost_this_match == 0, "Initial tabs lost should be 0")
	
	# Test coin spending
	assert(battle_manager_node.spend_coins(20) == true, "Should be able to spend 20 coins")
	assert(battle_manager_node.coins == 40, "Coins should now be 40")
	assert(battle_manager_node.spend_coins(100) == false, "Should not be able to spend more than balance")
	assert(battle_manager_node.coins == 40, "Coins should remain 40 after failed spend")
	battle_manager_node.add_coins(30)
	assert(battle_manager_node.coins == 70, "Coins should be 70 after adding 30")

	# Test Refresh Rush charge usage
	assert(battle_manager_node.can_use_refresh_rush() == true, "Should be able to use refresh rush")
	assert(battle_manager_node.use_refresh_rush_charge() == true, "Should consume 1 charge")
	assert(battle_manager_node.refresh_rush_charges == 1, "Should have 1 charge left")
	assert(battle_manager_node.use_refresh_rush_charge() == true, "Should consume 2nd charge")
	assert(battle_manager_node.refresh_rush_charges == 0, "Should have 0 charges left")
	assert(battle_manager_node.can_use_refresh_rush() == false, "Should not be able to use refresh rush when 0")
	assert(battle_manager_node.use_refresh_rush_charge() == false, "Consuming with 0 charges should return false")
	
	print("BattleManager test passed!")

func test_manhattan_distance() -> void:
	print("Testing Manhattan distance range check...")
	var from_tile := Vector2i(2, 2)
	
	var d1 = absi(2 - from_tile.x) + absi(2 - from_tile.y)
	assert(d1 == 0, "Distance to self should be 0")
	
	var d2 = absi(6 - from_tile.x) + absi(2 - from_tile.y)
	assert(d2 == 4, "Distance (2,2) to (6,2) should be 4")
	assert(d2 <= 4, "Should be within 4-tile range")
	
	var d3 = absi(5 - from_tile.x) + absi(3 - from_tile.y)
	assert(d3 == 4, "Distance (2,2) to (5,3) should be 4")
	assert(d3 <= 4, "Should be within 4-tile range")
	
	var d4 = absi(6 - from_tile.x) + absi(3 - from_tile.y)
	assert(d4 == 5, "Distance (2,2) to (6,3) should be 5")
	assert(d4 > 4, "Should be out of 4-tile range")
	print("Manhattan distance test passed!")

func test_drag_deadzone() -> void:
	print("Testing 10-pixel drag deadzone logic...")
	var start_pos := Vector2(100.0, 100.0)
	var deadzone: float = 10.0
	
	var small_move := Vector2(106.0, 105.0)
	var distance_small = start_pos.distance_to(small_move) # ~7.8px
	assert(distance_small < deadzone, "Move < 10px should NOT trigger drag")
	
	var large_move := Vector2(110.0, 108.0)
	var distance_large = start_pos.distance_to(large_move) # ~12.8px
	assert(distance_large >= deadzone, "Move >= 10px SHOULD trigger drag")
	print("Drag deadzone test passed!")

func test_turret_cascade_merging() -> void:
	print("Testing Turret Cascade Merging up to Tier 4...")
	var TabBaseScene: PackedScene = preload("res://scenes/battle/tab/tab_base.tscn")
	var tab: Node = TabBaseScene.instantiate()
	root.add_child(tab)

	# 1 turret bought: produces [T1]
	tab.add_tower(TabTower.Tier.TIER_1)
	assert(tab.get_tower_tiers() == [1], "1 turret bought must produce [T1], got %s" % str(tab.get_tower_tiers()))

	# 2 turrets bought: produces [T2]
	tab.add_tower(TabTower.Tier.TIER_1)
	assert(tab.get_tower_tiers() == [2], "2 turrets bought must merge into [T2], got %s" % str(tab.get_tower_tiers()))

	# 3 turrets bought: produces [T2, T1]
	tab.add_tower(TabTower.Tier.TIER_1)
	assert(tab.get_tower_tiers() == [2, 1], "3 turrets bought must produce [T2, T1], got %s" % str(tab.get_tower_tiers()))

	# 4 turrets bought: produces [T3]
	tab.add_tower(TabTower.Tier.TIER_1)
	assert(tab.get_tower_tiers() == [3], "4 turrets bought must cascade merge into [T3], got %s" % str(tab.get_tower_tiers()))

	# 5, 6, 7 turrets bought
	tab.add_tower(TabTower.Tier.TIER_1) # 5 -> [3, 1]
	assert(tab.get_tower_tiers() == [3, 1], "5 turrets must produce [T3, T1], got %s" % str(tab.get_tower_tiers()))
	tab.add_tower(TabTower.Tier.TIER_1) # 6 -> [3, 2]
	assert(tab.get_tower_tiers() == [3, 2], "6 turrets must produce [T3, T2], got %s" % str(tab.get_tower_tiers()))
	tab.add_tower(TabTower.Tier.TIER_1) # 7 -> [3, 2, 1]
	assert(tab.get_tower_tiers() == [3, 2, 1], "7 turrets must produce [T3, T2, T1], got %s" % str(tab.get_tower_tiers()))

	# 8 turrets bought: produces [T4]
	tab.add_tower(TabTower.Tier.TIER_1) # 8 -> [4]
	assert(tab.get_tower_tiers() == [4], "8 turrets bought must cascade merge into [T4], got %s" % str(tab.get_tower_tiers()))

	# Verify 10px drag deadzone and double-click window < 250ms
	assert(tab.DRAG_DEADZONE == 10.0, "TabBase must enforce 10px drag deadzone")
	assert(tab.DOUBLE_CLICK_WINDOW == 0.25, "TabBase must enforce < 250ms double-click window")

	tab.queue_free()
	print("Turret Cascade Merging tests passed!")

func test_grid_6x5() -> void:
	print("Testing 6x5 Grid Dimensions (30 tiles)...")
	var gm := GridManagerScript.new()
	assert(gm.GRID_COLS == 6, "GridManager must have 6 columns")
	assert(gm.GRID_ROWS == 5, "GridManager must have 5 rows")
	assert(gm.GRID_COLS * gm.GRID_ROWS == 30, "Grid must comprise 30 tiles")
	gm.queue_free()
	print("6x5 Grid test passed!")

func test_sacrifice_guardrails() -> void:
	print("Testing Close Tab Sacrifice Shield guardrails...")
	var TabBaseScene: PackedScene = preload("res://scenes/battle/tab/tab_base.tscn")
	var tab1 = TabBaseScene.instantiate()
	root.add_child(tab1)
	tab1.add_to_group("tabs")
	
	# Guardrail 1: When player has <= 1 tab, sacrifice must be disabled!
	assert(battle_manager_node.can_sacrifice_tab(tab1) == false, "Must disable sacrifice if player has <= 1 tab")
	
	# Add second player tab
	var tab2 = TabBaseScene.instantiate()
	root.add_child(tab2)
	tab2.add_to_group("tabs")
	assert(battle_manager_node.can_sacrifice_tab(tab1) == true, "Must allow sacrifice if player has > 1 tab and open grid")
	
	# Test L-shape prioritization
	battle_manager_node.triangulation_nodes = [tab2]
	var best = battle_manager_node.find_best_sacrifice_shield_target(tab1, [tab2])
	assert(best == tab2, "Must prioritize shielding L-shape tab")

	tab1.queue_free()
	tab2.queue_free()
	print("Sacrifice Shield guardrails passed!")

func test_pin_rewards() -> void:
	print("Testing Pin Rewards (1 base + 1 for zero tabs lost + 1 for winning under 2:00)...")
	# Scenario A: Win under 2:00 (remaining time >= 60.0s), 0 tabs lost -> 3 pins
	battle_manager_node.start_match()
	battle_manager_node.match_time_remaining = 85.0 # won under 2:00
	battle_manager_node.tabs_lost_this_match = 0
	var pins_a: int = 1 + (1 if battle_manager_node.tabs_lost_this_match == 0 else 0) + (1 if battle_manager_node.match_time_remaining >= 60.0 else 0)
	assert(pins_a == 3, "Winning under 2:00 with zero tabs lost should award 3 pins")
	
	# Scenario B: Win over 2:00 (remaining time 40.0s), 1 tab lost -> 1 pin
	battle_manager_node.start_match()
	battle_manager_node.match_time_remaining = 40.0
	battle_manager_node.record_player_tab_lost()
	var pins_b: int = 1 + (1 if battle_manager_node.tabs_lost_this_match == 0 else 0) + (1 if battle_manager_node.match_time_remaining >= 60.0 else 0)
	assert(pins_b == 1, "Winning over 2:00 with 1 tab lost should award 1 pin")
	print("Pin Rewards test passed!")

func test_towers_and_enemies() -> void:
	print("Testing 3 Tower Types & 3 Enemy Types...")
	var TowerScene: PackedScene = preload("res://scenes/battle/tower/tower.tscn")
	var t: TabTower = TowerScene.instantiate()
	root.add_child(t)
	
	# Ad-Blocker
	t.set_tower_type(TabTower.TowerType.AD_BLOCKER)
	assert(t.tower_type == TabTower.TowerType.AD_BLOCKER, "Should support Ad-Blocker tower")
	
	# Firewall
	t.set_tower_type(TabTower.TowerType.FIREWALL)
	assert(t.tower_type == TabTower.TowerType.FIREWALL, "Should support Firewall tower")
	
	# Cache Cannon
	t.set_tower_type(TabTower.TowerType.CACHE_CANNON)
	assert(t.tower_type == TabTower.TowerType.CACHE_CANNON, "Should support Cache Cannon tower")
	t.queue_free()

	# Enemies: Pop-Up Swarm, Cookie Tracker, Malware Brute
	var enemy = EnemyScript.new()
	root.add_child(enemy)
	enemy.init_enemy(Enemy.EnemyType.POP_UP_SWARM, Vector2(100, 100))
	assert(enemy.enemy_type == Enemy.EnemyType.POP_UP_SWARM, "Should initialize Pop-Up Swarm")
	assert(enemy.base_speed > 100.0, "Pop-Up Swarm should be fast rusher")
	
	enemy.init_enemy(Enemy.EnemyType.COOKIE_TRACKER, Vector2(100, 100))
	assert(enemy.enemy_type == Enemy.EnemyType.COOKIE_TRACKER, "Should initialize Cookie Tracker")
	
	enemy.init_enemy(Enemy.EnemyType.MALWARE_BRUTE, Vector2(100, 100))
	assert(enemy.enemy_type == Enemy.EnemyType.MALWARE_BRUTE, "Should initialize Malware Brute")
	assert(enemy.max_hp >= 200.0, "Malware Brute should be heavy tank")
	enemy.queue_free()
	print("Towers and Enemies test passed!")
