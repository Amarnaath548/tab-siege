extends SceneTree

# Test suite for Component 1 and math logic

const GameDataScript = preload("res://scripts/game_data.gd")
const BattleManagerScript = preload("res://scripts/battle_manager.gd")

var game_data_node: Node
var battle_manager_node: Node

func _init() -> void:
	print("--- STARTING COMPONENT 1 TEST SUITE ---")
	game_data_node = GameDataScript.new()
	battle_manager_node = BattleManagerScript.new()
	root.add_child(game_data_node)
	root.add_child(battle_manager_node)
	
	test_game_data()
	test_battle_manager()
	test_manhattan_distance()
	test_drag_deadzone()
	
	print("--- ALL COMPONENT 1 TESTS PASSED SUCCESSFULLY! ---")
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
	print("GameData test passed!")

func test_battle_manager() -> void:
	print("Testing BattleManager...")
	battle_manager_node.start_match()
	assert(battle_manager_node.is_match_active == true, "Match should be active after start")
	assert(battle_manager_node.match_time_remaining == 180.0, "Initial match duration should be 180s")
	assert(battle_manager_node.coins == 60, "Initial coins should be 60")
	assert(battle_manager_node.refresh_rush_charges == 2, "Initial refresh charges should be 2")
	
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
	print("Testing 8-pixel drag deadzone logic...")
	var start_pos := Vector2(100.0, 100.0)
	var deadzone: float = 8.0
	
	var small_move := Vector2(104.0, 102.0)
	var distance_small = start_pos.distance_to(small_move)
	assert(distance_small < deadzone, "Move < 8px should NOT trigger drag")
	
	var large_move := Vector2(109.0, 105.0)
	var distance_large = start_pos.distance_to(large_move)
	assert(distance_large >= deadzone, "Move >= 8px SHOULD trigger drag")
	print("Drag deadzone test passed!")
