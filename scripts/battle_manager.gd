class_name BattleManagerSingleton
extends Node

# BattleManager - Match-only state Autoload singleton
# Holds 3-minute countdown, match coins, Refresh Rush charges, active tab focus reference, and L-shape hold state.

signal coins_changed(new_amount: int)
signal match_time_updated(seconds_remaining: float)
signal refresh_charges_changed(remaining: int, max_charges: int)
signal active_tab_focus_changed(focused_tab: Node)
signal focus_transition_started(target_tab: Node, duration: float)
signal triangulation_hold_updated(current_hold: float, target_hold: float)
signal triangulation_completed()
signal match_ended(victory: bool, reason: String)

const BASE_MATCH_DURATION: float = 180.0 # 3 minutes
const TRIANGULATION_TARGET_TIME: float = 30.0 # 30 seconds hold

var is_match_active: bool = false
var match_time_remaining: float = BASE_MATCH_DURATION
var coins: int = 60
var refresh_rush_charges: int = 2
var max_refresh_rush_charges: int = 2

# Active Tab Focus (Single active tab reference)
var active_focused_tab: Node = null
var pending_focus_tab: Node = null
var focus_transition_timer: float = 0.0
var focus_transition_duration: float = 1.0

# Triangulation Hold state
var is_triangulation_holding: bool = false
var triangulation_hold_time: float = 0.0
var triangulation_nodes: Array = [] # [Node, Node, Node] forming the L-shape

# Income ticker
var coin_tick_accumulator: float = 0.0
const COIN_TICK_INTERVAL: float = 1.0

func _process(delta: float) -> void:
	if not is_match_active:
		return

	# Tick match countdown timer (3 minutes)
	match_time_remaining = maxf(0.0, match_time_remaining - delta)
	match_time_updated.emit(match_time_remaining)
	if match_time_remaining <= 0.0:
		end_match(false, "Time expired! The 3-minute battle ended.")
		return

	# Tick 1-second Focus switch transition
	if pending_focus_tab != null:
		focus_transition_timer -= delta
		if focus_transition_timer <= 0.0:
			_apply_focused_tab(pending_focus_tab)
			pending_focus_tab = null

	# Tick focused tab passive coin generation (+50% bonus or upgraded rate)
	coin_tick_accumulator += delta
	if coin_tick_accumulator >= COIN_TICK_INTERVAL:
		coin_tick_accumulator -= COIN_TICK_INTERVAL
		if active_focused_tab != null and is_instance_valid(active_focused_tab):
			var boost_mult: float = 1.5
			var gd = _get_game_data()
			if gd:
				boost_mult = gd.get_focus_boost_multiplier()
			# If the tab is currently inert from relocation or penalised by refresh, no coins
			if active_focused_tab.has_method("can_generate_coins") and active_focused_tab.can_generate_coins():
				var income: int = int(round(4.0 * boost_mult))
				add_coins(income)

	# Triangulation Hold Tick
	if is_triangulation_holding:
		triangulation_hold_time += delta
		triangulation_hold_updated.emit(triangulation_hold_time, TRIANGULATION_TARGET_TIME)
		if triangulation_hold_time >= TRIANGULATION_TARGET_TIME:
			is_triangulation_holding = false
			triangulation_completed.emit()
			end_match(true, "Tab Bar Triangulation Victory! Held L-formation for 30s.")

func _get_game_data() -> Node:
	return get_node_or_null("/root/GameData")

func _get_audio_synth() -> Node:
	return get_node_or_null("/root/AudioSynth")

func start_match() -> void:
	is_match_active = true
	match_time_remaining = BASE_MATCH_DURATION
	coins = 60
	var gd = _get_game_data()
	max_refresh_rush_charges = gd.get_max_refresh_charges() if gd else 2
	refresh_rush_charges = max_refresh_rush_charges
	active_focused_tab = null
	pending_focus_tab = null
	focus_transition_timer = 0.0
	is_triangulation_holding = false
	triangulation_hold_time = 0.0
	triangulation_nodes.clear()
	coin_tick_accumulator = 0.0

	coins_changed.emit(coins)
	match_time_updated.emit(match_time_remaining)
	refresh_charges_changed.emit(refresh_rush_charges, max_refresh_rush_charges)
	active_tab_focus_changed.emit(null)
	triangulation_hold_updated.emit(0.0, TRIANGULATION_TARGET_TIME)

func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount
	coins_changed.emit(coins)

func spend_coins(amount: int) -> bool:
	if coins >= amount:
		coins -= amount
		coins_changed.emit(coins)
		return true
	return false

func request_tab_focus(tab: Node) -> void:
	if not is_match_active:
		return
	if tab == active_focused_tab:
		return
	
	var gd = _get_game_data()
	focus_transition_duration = gd.get_focus_switch_delay() if gd else 1.0
	pending_focus_tab = tab
	focus_transition_timer = focus_transition_duration
	focus_transition_started.emit(tab, focus_transition_duration)
	var synth = _get_audio_synth()
	if synth:
		synth.play_focus_switch()

func _apply_focused_tab(tab: Node) -> void:
	if active_focused_tab != null and is_instance_valid(active_focused_tab):
		if active_focused_tab.has_method("set_focused"):
			active_focused_tab.set_focused(false)
	
	active_focused_tab = tab
	if active_focused_tab != null and is_instance_valid(active_focused_tab):
		if active_focused_tab.has_method("set_focused"):
			active_focused_tab.set_focused(true)
	
	active_tab_focus_changed.emit(active_focused_tab)
	var synth = _get_audio_synth()
	if synth:
		synth.play_focus_active()

func clear_focused_tab() -> void:
	if active_focused_tab != null and is_instance_valid(active_focused_tab):
		if active_focused_tab.has_method("set_focused"):
			active_focused_tab.set_focused(false)
	active_focused_tab = null
	pending_focus_tab = null
	active_tab_focus_changed.emit(null)

func can_use_refresh_rush() -> bool:
	return is_match_active and refresh_rush_charges > 0

func use_refresh_rush_charge() -> bool:
	if not can_use_refresh_rush():
		return false
	refresh_rush_charges -= 1
	refresh_charges_changed.emit(refresh_rush_charges, max_refresh_rush_charges)
	return true

func update_triangulation_status(is_l_formed: bool, l_tabs: Array) -> void:
	if not is_match_active:
		return
	
	var synth = _get_audio_synth()
	if is_l_formed:
		triangulation_nodes = l_tabs
		if not is_triangulation_holding:
			is_triangulation_holding = true
			if synth:
				synth.play_triangulation_start()
	else:
		if is_triangulation_holding:
			is_triangulation_holding = false
			# Reset hold timer when formation is broken
			triangulation_hold_time = 0.0
			triangulation_nodes.clear()
			triangulation_hold_updated.emit(0.0, TRIANGULATION_TARGET_TIME)
			if synth:
				synth.play_triangulation_lost()

func end_match(victory: bool, reason: String) -> void:
	if not is_match_active:
		return
	is_match_active = false
	is_triangulation_holding = false
	
	var synth = _get_audio_synth()
	var gd = _get_game_data()
	var pins_earned: int = 0
	if victory:
		pins_earned = 1
		if triangulation_hold_time >= TRIANGULATION_TARGET_TIME:
			pins_earned += 1
		if match_time_remaining >= 60.0:
			pins_earned += 1
		pins_earned = clampi(pins_earned, 1, 3)
		if gd:
			gd.record_battle_result(true, pins_earned)
		if synth:
			synth.play_victory()
	else:
		pins_earned = 0
		if gd:
			gd.record_battle_result(false, 0)
		if synth:
			synth.play_defeat()

	match_ended.emit(victory, reason)
