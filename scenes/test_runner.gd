extends Node

# TestRunner Node - runs in full scene tree with Autoloads initialized

func _ready() -> void:
	print("Root children:", get_tree().root.get_children())
	print("--- STARTING COMPONENT 1 INTEGRATION TEST SUITE ---")
	test_game_data()
	test_battle_manager()
	test_manhattan_distance()
	test_drag_deadzone()
	test_grid_manager_triangulation()
	test_tab_base_and_combat()
	test_end_to_end_battle_and_atlas()
	print("--- ALL COMPONENT 1 TO 5 TESTS PASSED SUCCESSFULLY! ---")
	get_tree().quit(0)

func test_game_data() -> void:
	print("Testing GameData autoload...")
	var game_data = get_node_or_null("/root/GameData")
	assert(game_data != null, "GameData autoload must exist")
	game_data.upgrades["drag_relocation"] = 0
	game_data.upgrades["refresh_rush"] = 0
	game_data.upgrades["active_focus"] = 0
	game_data.upgrades["sacrifice_shield"] = 0
	assert(game_data.get_drag_max_range() == 4, "Base drag range should be 4")
	assert(game_data.get_drag_cooldown() == 15.0, "Base drag cooldown should be 15s")
	assert(game_data.get_max_refresh_charges() == 2, "Base refresh charges should be 2")
	assert(game_data.get_refresh_cursor_count() == 5, "Base refresh cursor count should be 5")
	assert(is_equal_approx(game_data.get_focus_boost_multiplier(), 1.5), "Base focus multiplier should be 1.5 (+50%)")
	assert(is_equal_approx(game_data.get_focus_switch_delay(), 1.0), "Base focus switch delay should be 1.0s")
	assert(is_equal_approx(game_data.get_shield_duration(), 4.0), "Base shield duration should be 4.0s")
	assert(is_equal_approx(game_data.get_sacrifice_refund_ratio(), 0.5), "Base sacrifice refund should be 50%")
	print("GameData test passed!")

func test_battle_manager() -> void:
	print("Testing BattleManager autoload...")
	var battle_manager = get_node_or_null("/root/BattleManager")
	assert(battle_manager != null, "BattleManager autoload must exist")
	battle_manager.start_match()
	assert(battle_manager.is_match_active == true, "Match should be active after start")
	assert(battle_manager.match_time_remaining == 180.0, "Initial match duration should be 180s")
	assert(battle_manager.coins == 60, "Initial coins should be 60")
	assert(battle_manager.refresh_rush_charges == 2, "Initial refresh charges should be 2")
	
	# Test coin spending
	assert(battle_manager.spend_coins(20) == true, "Should be able to spend 20 coins")
	assert(battle_manager.coins == 40, "Coins should now be 40")
	assert(battle_manager.spend_coins(100) == false, "Should not be able to spend more than balance")
	assert(battle_manager.coins == 40, "Coins should remain 40 after failed spend")
	battle_manager.add_coins(30)
	assert(battle_manager.coins == 70, "Coins should be 70 after adding 30")

	# Test Refresh Rush charge usage
	assert(battle_manager.can_use_refresh_rush() == true, "Should be able to use refresh rush")
	assert(battle_manager.use_refresh_rush_charge() == true, "Should consume 1 charge")
	assert(battle_manager.refresh_rush_charges == 1, "Should have 1 charge left")
	assert(battle_manager.use_refresh_rush_charge() == true, "Should consume 2nd charge")
	assert(battle_manager.refresh_rush_charges == 0, "Should have 0 charges left")
	assert(battle_manager.can_use_refresh_rush() == false, "Should not be able to use refresh rush when 0")
	assert(battle_manager.use_refresh_rush_charge() == false, "Consuming with 0 charges should return false")
	
	print("BattleManager test passed!")

func test_manhattan_distance() -> void:
	print("Testing Manhattan distance range check...")
	var from_tile := Vector2i(2, 2)
	
	# Manhattan distance: abs(dx) + abs(dy)
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
	var distance_small = start_pos.distance_to(small_move)
	assert(distance_small < deadzone, "Move < 10px should NOT trigger drag")
	
	var large_move := Vector2(110.0, 108.0)
	var distance_large = start_pos.distance_to(large_move)
	assert(distance_large >= deadzone, "Move >= 10px SHOULD trigger drag")
	print("Drag deadzone test passed!")

# Mock tab for testing grid logic
class MockTab extends Node2D:
	var faction: String = "player"
	var inert: bool = false
	func is_player() -> bool: return faction == "player"
	func is_rival() -> bool: return faction == "rival"
	func is_neutral() -> bool: return faction == "neutral"
	func is_inert() -> bool: return inert

func test_grid_manager_triangulation() -> void:
	print("Testing GridManager and L-Shape Triangulation...")
	var gm := GridManager.new()
	add_child(gm)
	
	# Create 3 player tabs in an L-shape:
	# Corner at (1, 1), Arm1 at (2, 1), Arm2 at (1, 2)
	var t1 := MockTab.new()
	var t2 := MockTab.new()
	var t3 := MockTab.new()
	add_child(t1)
	add_child(t2)
	add_child(t3)
	
	gm.register_tab(t1, Vector2i(1, 1))
	gm.register_tab(t2, Vector2i(2, 1))
	gm.register_tab(t3, Vector2i(1, 2))
	
	var res := gm.check_triangulation()
	assert(res["found"] == true, "Should detect L-shape at (1,1), (2,1), (1,2)")
	assert(res["corner"] == t1, "Corner should be t1 at (1,1)")
	
	# Test broken triangulation (straight line: (1,1), (2,1), (3,1))
	gm.relocate_tab(t3, Vector2i(3, 1), 4)
	var res_line := gm.check_triangulation()
	assert(res_line["found"] == false, "Straight line of 3 tabs is NOT an L-shape")
	
	# Test Manhattan distance limit (can't move > 4 tiles)
	var can_jump_far := gm.can_relocate_tab_to(t1, Vector2i(6, 6), 4)
	assert(can_jump_far == false, "Cannot relocate beyond 4 tiles Manhattan distance")
	
	# Test cannot land on rival tab
	var rival_tab := MockTab.new()
	rival_tab.faction = "rival"
	add_child(rival_tab)
	gm.register_tab(rival_tab, Vector2i(2, 2))
	var can_land_on_rival := gm.can_relocate_tab_to(t1, Vector2i(2, 2), 4)
	assert(can_land_on_rival == false, "Cannot land on rival tab")
	
	# Test inert tab disables triangulation
	gm.relocate_tab(t3, Vector2i(1, 2), 4) # restore L-shape
	assert(gm.check_triangulation()["found"] == true, "L-shape restored")
	t1.inert = true # tab is inert after drag
	assert(gm.check_triangulation()["found"] == false, "Inert tab cannot sustain triangulation")
	
	print("GridManager and Triangulation tests passed!")

func test_tab_base_and_combat() -> void:
	print("Testing TabBase, Towers, Sacrifice Shield, and Refresh Rush...")
	var TabScene: PackedScene = preload("res://scenes/battle/tab/tab_base.tscn")
	var tab: Node = TabScene.instantiate()
	add_child(tab)
	
	assert(tab.is_player() == true, "Default tab should be player faction")
	assert(tab.is_alive() == true, "New tab should be alive")
	assert(tab.is_inert() == false, "New tab should not be inert")
	assert(tab.is_shielded() == false, "New tab should not be shielded")
	
	# Add tower 1: produces [T1]
	var added: bool = tab.add_tower(TabTower.Tier.TIER_1)
	assert(added == true, "Should add tower")
	assert(tab.get_tower_tiers() == [1], "Tab should have [T1]")
	
	# Add tower 2: automatically cascade merges into [T2]
	tab.add_tower(TabTower.Tier.TIER_1)
	assert(tab.get_tower_tiers() == [2], "Towers should auto-merge into [T2]")
	
	# Add tower 3: produces [T2, T1]
	tab.add_tower(TabTower.Tier.TIER_1)
	assert(tab.get_tower_tiers() == [2, 1], "Towers should be [T2, T1]")

	# Add tower 4: cascade merges into [T3]
	tab.add_tower(TabTower.Tier.TIER_1)
	assert(tab.get_tower_tiers() == [3], "Towers should cascade merge into [T3]")

	# Add towers 5, 6, 7, 8: cascade merges into [T4]
	tab.add_tower(TabTower.Tier.TIER_1) # 5
	tab.add_tower(TabTower.Tier.TIER_1) # 6
	tab.add_tower(TabTower.Tier.TIER_1) # 7
	tab.add_tower(TabTower.Tier.TIER_1) # 8
	assert(tab.get_tower_tiers() == [4], "8 towers should cascade merge into [T4]")
	
	# Test Sacrifice Shield application
	tab.apply_sacrifice_shield(4.0)
	assert(tab.is_shielded() == true, "Tab should now be shielded")
	var old_hp: float = tab.current_hp
	tab.take_damage(20.0, "rival")
	assert(tab.current_hp == old_hp, "Shielded tab must take 0 damage from strikes")
	
	# Test unshielded damage
	tab.shield_timer = 0.0
	assert(tab.is_shielded() == false, "Shield should be expired")
	tab.take_damage(25.0, "rival")
	assert(tab.current_hp == (old_hp - 25.0), "Unshielded tab should take 25 damage")

	# Test 10-pixel drag deadzone logic
	assert(tab.DRAG_DEADZONE == 10.0, "Deadzone must be exactly 10 pixels")
	
	# Test turret tier label remains upright when turret rotates
	var tower: TabTower = tab.towers[0]
	assert(tower.tier_label != null, "Tower must have a tier_label Label node")
	assert(tower.tier_label.text == "T4", "Tower tier label text should reflect tier, got: %s" % tower.tier_label.text)
	for angle in [0.0, 0.78, 1.57, 3.14, -2.1]:
		tower.rotation = angle
		tower._process(0.016)
		assert(is_zero_approx(tower.tier_label.global_rotation), "Tower tier label global_rotation must be 0.0 when turret rotates to %f, got: %f" % [angle, tower.tier_label.global_rotation])

	# Test tab capture by player updates tab title cleanly (neutral -> Tab #3, rival -> Tab #4)
	var neutral_tab: TabBase = TabScene.instantiate()
	neutral_tab.faction = TabBase.Faction.NEUTRAL
	neutral_tab.tab_title = "about:cache"
	add_child(neutral_tab)
	neutral_tab.take_damage(100.0, "player")
	assert(neutral_tab.is_player() == true, "Neutral tab should become player faction on capture")
	assert(neutral_tab.tab_title == "Tab #3" or neutral_tab.tab_title.begins_with("Tab #"), "Captured neutral tab title should be updated to clean player name, got: %s" % neutral_tab.tab_title)

	var rival_tab: TabBase = TabScene.instantiate()
	rival_tab.faction = TabBase.Faction.RIVAL
	rival_tab.tab_title = "rival://nexus"
	add_child(rival_tab)
	rival_tab.take_damage(100.0, "player")
	assert(rival_tab.is_player() == true, "Rival tab should become player faction on capture")
	assert(rival_tab.tab_title != "rival://nexus" and rival_tab.tab_title.begins_with("Tab #"), "Captured rival tab title should be updated to clean player name, got: %s" % rival_tab.tab_title)

	neutral_tab.queue_free()
	rival_tab.queue_free()

	print("TabBase and Combat tests passed!")

func test_end_to_end_battle_and_atlas() -> void:
	print("Testing Full Battle Arena and Bookmark Atlas...")
	var BattleScene: PackedScene = preload("res://scenes/battle/battle.tscn")
	var battle: Node = BattleScene.instantiate()
	add_child(battle)
	
	# Verify that starting tabs spawned properly
	var tabs := get_tree().get_nodes_in_group("tabs")
	assert(tabs.size() >= 7, "Should have 2 player tabs, 2 rival tabs, and 3 neutral tabs")
	
	# Verify BattleManager match state
	assert(BattleManager.is_match_active == true, "Battle match should be active")
	assert(BattleManager.active_focused_tab != null or BattleManager.pending_focus_tab != null, "Player tab should be focused or transitioning")
	
	# Test Pin awarding and Atlas upgrade purchase
	var initial_pins: int = GameData.pins
	GameData.add_pins(5)
	assert(GameData.pins == initial_pins + 5, "GameData should have gained 5 pins")
	
	var can_buy_drag := GameData.can_afford_upgrade("drag_relocation")
	assert(can_buy_drag == true, "Should be able to afford drag relocation upgrade")
	var old_range: int = GameData.get_drag_max_range()
	var bought := GameData.purchase_upgrade("drag_relocation")
	assert(bought == true, "Should have successfully purchased upgrade")
	assert(GameData.get_drag_max_range() == old_range + 1, "Drag max range should have increased by 1 tile")
	
	# Test Bookmark Atlas scene instantiation and UI rendering
	var AtlasScene: PackedScene = preload("res://scenes/atlas/bookmark_atlas.tscn")
	var atlas: Node = AtlasScene.instantiate()
	add_child(atlas)
	assert(atlas.cards_container.get_child_count() == 4, "Should have rendered 4 upgrade cards in Atlas")
	atlas.queue_free()

	# Clean up
	battle.queue_free()
	print("Full Battle Arena and Bookmark Atlas tests passed!")
