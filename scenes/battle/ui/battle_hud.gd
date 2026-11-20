class_name BattleHUD
extends CanvasLayer

# BattleHUD: Vibrant, tactile Flat-Vector Browser UI aesthetic
# Top Bar: Real browser tab strip + macOS traffic-light dots + Chrome-blue active tab pill
#          + Alert-Red rival tab pills + White rounded URL bar + Centered bold timer
#          + Blue-vs-Red tug-of-war / L-Hold progress bar
# Bottom Dock: Dark slate-blue dock (#1E3A5F) + Gold Coin badge + Visual Merge Units indicator
#              + 3 chunky tactile ability buttons (Active Focus, Cursor Strike, Refresh Rush)
#              + Win/Atlas progress pips + Bright green Bookmark Atlas button

signal build_tower_requested()
signal player_strike_requested()
signal refresh_rush_requested()
signal focus_cycle_requested()
signal atlas_menu_requested()
signal restart_requested()
signal tutorial_skipped()

var tutorial_highlight: Panel
var tutorial_label: Label
var tutorial_skip_btn: Button
var tutorial_container: PanelContainer

# Top Chrome HUD references
@onready var timer_label: Label = $TopChrome/URLBar/CenterHBox/TimerLabel
@onready var coins_label: Label = $BottomDock/HBox/CoinBadge/CoinsLabel
@onready var refresh_label: Label = $BottomDock/HBox/RefreshRushBtn/BtnLabel
@onready var focus_label: Label = $TopChrome/TabStrip/ActiveTabPill/HBox/TabNameLabel
@onready var hold_container: Control = $TopChrome/URLBar/CenterHBox/HoldContainer
@onready var hold_bar: ProgressBar = $TopChrome/URLBar/CenterHBox/HoldContainer/HoldBar
@onready var hold_label: Label = $TopChrome/URLBar/CenterHBox/HoldContainer/HoldLabel

# Active & Rival tab pill references
@onready var active_tab_pill: PanelContainer = $TopChrome/TabStrip/ActiveTabPill
@onready var active_tab_hp_bar: ProgressBar = $TopChrome/TabStrip/ActiveTabPill/HBox/TabHPBar
@onready var active_tab_close_btn: Button = $TopChrome/TabStrip/ActiveTabPill/HBox/CloseBtn
@onready var rival_pill_1: PanelContainer = $TopChrome/TabStrip/RivalPill1
@onready var rival_pill_2: PanelContainer = $TopChrome/TabStrip/RivalPill2

# Tug-of-War / Progress bar
@onready var tug_bar: ProgressBar = $TopChrome/URLBar/CenterHBox/TugOfWarBar

# Bottom Dock Ability Buttons
@onready var buy_tower_btn: Button = $BottomDock/HBox/BuyTowerBtn
@onready var strike_btn: Button = $BottomDock/HBox/StrikeBtn
@onready var focus_btn: Button = $BottomDock/HBox/FocusBtn
@onready var refresh_btn: Button = $BottomDock/HBox/RefreshRushBtn
@onready var atlas_dock_btn: Button = $BottomDock/HBox/AtlasBtn
@onready var merge_indicator: PanelContainer = $BottomDock/HBox/MergeIndicator
@onready var pips_container: HBoxContainer = $BottomDock/HBox/PipsContainer

# End Match Modal
@onready var end_modal: Control = $EndModal
@onready var result_title: Label = $EndModal/Panel/VBox/ResultTitle
@onready var result_desc: Label = $EndModal/Panel/VBox/ResultDesc
@onready var pins_earned_label: Label = $EndModal/Panel/VBox/PinsEarnedLabel
@onready var atlas_btn: Button = $EndModal/Panel/VBox/BtnHBox/AtlasBtn
@onready var retry_btn: Button = $EndModal/Panel/VBox/BtnHBox/RetryBtn

func _ready() -> void:
	end_modal.visible = false
	hold_container.visible = false
	setup_tutorial_ui()
	_apply_tactile_styles()

	var bm = get_node_or_null("/root/BattleManager")
	if bm:
		bm.match_time_updated.connect(_on_time_updated)
		bm.coins_changed.connect(_on_coins_changed)
		bm.refresh_charges_changed.connect(_on_refresh_charges_changed)
		bm.active_tab_focus_changed.connect(_on_focus_changed)
		bm.triangulation_hold_updated.connect(_on_triangulation_updated)
		bm.match_ended.connect(_on_match_ended)

	buy_tower_btn.pressed.connect(_on_buy_tower_pressed)
	strike_btn.pressed.connect(_on_strike_pressed)
	focus_btn.pressed.connect(_on_focus_pressed)
	refresh_btn.pressed.connect(_on_refresh_pressed)
	active_tab_close_btn.pressed.connect(_on_active_tab_close_pressed)
	atlas_dock_btn.pressed.connect(func(): atlas_menu_requested.emit())
	atlas_btn.pressed.connect(func(): atlas_menu_requested.emit())
	retry_btn.pressed.connect(func(): restart_requested.emit())

	_update_pips()

func _apply_tactile_styles() -> void:
	# Style buttons with 3px dark navy border and hard drop shadow (Vector2(3, 4))
	_style_button(buy_tower_btn, Color(0.2, 0.7, 0.4), Color(0.15, 0.58, 0.33)) # Green
	_style_button(strike_btn, Color(0.94, 0.27, 0.27), Color(0.80, 0.18, 0.18)) # Red
	_style_button(focus_btn, Color(0.06, 0.71, 0.83), Color(0.04, 0.58, 0.68)) # Cyan
	_style_button(refresh_btn, Color(0.13, 0.77, 0.36), Color(0.09, 0.62, 0.28)) # Green
	_style_button(atlas_dock_btn, Color(0.13, 0.77, 0.36), Color(0.09, 0.62, 0.28)) # Emerald

func _style_button(btn: Button, normal_col: Color, hover_col: Color) -> void:
	if btn == null:
		return
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = normal_col
	style_normal.border_width_left = 3
	style_normal.border_width_top = 3
	style_normal.border_width_right = 3
	style_normal.border_width_bottom = 3
	style_normal.border_color = Color(0.06, 0.09, 0.16) # #0F172A
	style_normal.corner_radius_top_left = 6
	style_normal.corner_radius_top_right = 6
	style_normal.corner_radius_bottom_left = 6
	style_normal.corner_radius_bottom_right = 6
	style_normal.shadow_size = 0
	style_normal.shadow_offset = Vector2(3, 4)
	style_normal.shadow_color = Color(0.06, 0.09, 0.16)
	btn.add_theme_stylebox_override("normal", style_normal)

	var style_hover := style_normal.duplicate() as StyleBoxFlat
	style_hover.bg_color = hover_col
	btn.add_theme_stylebox_override("hover", style_hover)

	var style_pressed := style_normal.duplicate() as StyleBoxFlat
	style_pressed.shadow_offset = Vector2(1, 1)
	btn.add_theme_stylebox_override("pressed", style_pressed)

func _update_pips() -> void:
	if pips_container == null:
		return
	var gd = get_node_or_null("/root/GameData")
	var wins: int = int(gd.battles_won) if gd != null else 0
	var children := pips_container.get_children()
	for i in range(children.size()):
		var pip = children[i] as Label
		if pip:
			if i < (wins % 3) or wins > 0:
				pip.text = "★"
				pip.add_theme_color_override("font_color", Color(0.96, 0.62, 0.04))
			else:
				pip.text = "☆"
				pip.add_theme_color_override("font_color", Color(0.45, 0.55, 0.65))

func _on_time_updated(seconds_left: float) -> void:
	var mins := int(seconds_left) / 60
	var secs := int(seconds_left) % 60
	timer_label.text = "%02d:%02d" % [mins, secs]
	if seconds_left < 30.0:
		timer_label.add_theme_color_override("font_color", Color(0.94, 0.27, 0.27))
	else:
		timer_label.add_theme_color_override("font_color", Color(0.06, 0.09, 0.16))
	
	# Update Blue-vs-Red tug of war balance
	_update_tug_of_war()

func _update_tug_of_war() -> void:
	var player_count := 0
	var rival_count := 0
	var tabs: Array[Node] = get_tree().get_nodes_in_group("tabs")
	for t in tabs:
		if is_instance_valid(t) and t.has_method("is_alive") and t.is_alive():
			if t.has_method("is_player") and t.is_player():
				player_count += 1
			elif t.has_method("is_rival") and t.is_rival():
				rival_count += 1
	var total: int = maxi(1, player_count + rival_count)
	if tug_bar:
		tug_bar.max_value = float(total)
		tug_bar.value = float(player_count)

var _prev_coins: int = -1

func _on_coins_changed(new_amount: int) -> void:
	if _prev_coins >= 0 and new_amount > _prev_coins:
		_show_floating_coins(new_amount - _prev_coins)
	_prev_coins = new_amount
	coins_label.text = "$%d Coins" % new_amount
	buy_tower_btn.disabled = new_amount < 20
	strike_btn.disabled = new_amount < 15

func _show_floating_coins(amount: int) -> void:
	var label := Label.new()
	label.text = "+$%d" % amount
	label.add_theme_color_override("font_color", Color(0.96, 0.62, 0.04))
	label.add_theme_font_size_override("font_size", 16)
	label.position = coins_label.global_position + Vector2(10, -24)
	label.z_index = 100
	add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 25.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)

func _on_refresh_charges_changed(remaining: int, max_c: int) -> void:
	refresh_label.text = "⟳ REFRESH (%d/%d)" % [remaining, max_c]
	refresh_btn.disabled = remaining <= 0

func _on_focus_changed(focused_tab: Node) -> void:
	if focused_tab != null and is_instance_valid(focused_tab):
		var title: String = focused_tab.tab_title if "tab_title" in focused_tab else "My Tab"
		focus_label.text = title
		var hp_pct: float = focused_tab.current_hp / focused_tab.max_hp if "current_hp" in focused_tab else 1.0
		active_tab_hp_bar.value = hp_pct * 100.0
	else:
		focus_label.text = "My Tab"
		active_tab_hp_bar.value = 100.0

func _on_triangulation_updated(current: float, target: float) -> void:
	if current > 0.0:
		hold_container.visible = true
		hold_bar.max_value = target
		hold_bar.value = current
		hold_label.text = "L-HOLD: %.1fs / %.1fs" % [current, target]
	else:
		hold_container.visible = false

func _on_match_ended(victory: bool, reason: String) -> void:
	hide_tutorial()
	end_modal.visible = true
	var synth = get_node_or_null("/root/AudioSynth")
	var bm = get_node_or_null("/root/BattleManager")
	var pins_earned := 1
	if victory:
		if synth and synth.has_method("play_victory"):
			synth.play_victory()
		result_title.text = "VICTORY! TAB BAR TRIANGULATED"
		result_title.add_theme_color_override("font_color", Color(0.13, 0.77, 0.36))
		result_desc.text = reason
		
		# Pin rewards: 1 base + 1 for zero tabs lost + 1 for winning under 2:00
		if bm and bm.tabs_lost_this_match == 0:
			pins_earned += 1
		if bm and bm.match_time_remaining >= 60.0:
			pins_earned += 1
		pins_earned = clampi(pins_earned, 1, 3)
		pins_earned_label.text = "+%d PINS EARNED!" % pins_earned
	else:
		if synth and synth.has_method("play_defeat"):
			synth.play_defeat()
		result_title.text = "DEFEAT"
		result_title.add_theme_color_override("font_color", Color(0.94, 0.27, 0.27))
		result_desc.text = reason
		pins_earned_label.text = "0 PINS EARNED"
	
	_update_pips()

func _on_buy_tower_pressed() -> void:
	var bm = get_node_or_null("/root/BattleManager")
	if bm and bm.spend_coins(20):
		build_tower_requested.emit()

func _on_strike_pressed() -> void:
	var bm = get_node_or_null("/root/BattleManager")
	if bm and bm.spend_coins(15):
		player_strike_requested.emit()

func _on_focus_pressed() -> void:
	focus_cycle_requested.emit()
	var bm = get_node_or_null("/root/BattleManager")
	var player_tabs: Array = get_tree().get_nodes_in_group("tabs").filter(
		func(t): return is_instance_valid(t) and t.has_method("is_player") and t.is_player() and t.is_alive()
	)
	if player_tabs.is_empty():
		return
	if bm == null:
		return
	var cur_idx: int = player_tabs.find(bm.active_focused_tab)
	var next_idx: int = (cur_idx + 1) % player_tabs.size()
	bm.request_tab_focus(player_tabs[next_idx])

func _on_refresh_pressed() -> void:
	refresh_rush_requested.emit()
	var bm = get_node_or_null("/root/BattleManager")
	if bm and bm.active_focused_tab != null and is_instance_valid(bm.active_focused_tab):
		if bm.active_focused_tab.has_method("execute_refresh_rush"):
			bm.active_focused_tab.execute_refresh_rush()

func _on_active_tab_close_pressed() -> void:
	var bm = get_node_or_null("/root/BattleManager")
	if bm and bm.active_focused_tab != null and is_instance_valid(bm.active_focused_tab):
		if bm.active_focused_tab.has_method("_on_close_sacrifice_clicked"):
			bm.active_focused_tab._on_close_sacrifice_clicked()

func setup_tutorial_ui() -> void:
	if tutorial_highlight != null:
		return

	tutorial_highlight = Panel.new()
	tutorial_highlight.name = "TutorialHighlight"
	tutorial_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h_style := StyleBoxFlat.new()
	h_style.draw_center = false
	h_style.border_width_left = 3
	h_style.border_width_right = 3
	h_style.border_width_top = 3
	h_style.border_width_bottom = 3
	h_style.border_color = Color(0.96, 0.62, 0.04) # #F59E0B
	h_style.corner_radius_top_left = 6
	h_style.corner_radius_top_right = 6
	h_style.corner_radius_bottom_left = 6
	h_style.corner_radius_bottom_right = 6
	tutorial_highlight.add_theme_stylebox_override("panel", h_style)
	tutorial_highlight.visible = false
	add_child(tutorial_highlight)

	tutorial_container = PanelContainer.new()
	tutorial_container.name = "TutorialContainer"
	var c_style := StyleBoxFlat.new()
	c_style.bg_color = Color(0.97, 0.98, 0.99)
	c_style.border_width_left = 3
	c_style.border_width_right = 3
	c_style.border_width_top = 3
	c_style.border_width_bottom = 3
	c_style.border_color = Color(0.06, 0.09, 0.16)
	c_style.corner_radius_top_left = 8
	c_style.corner_radius_top_right = 8
	c_style.corner_radius_bottom_left = 8
	c_style.corner_radius_bottom_right = 8
	c_style.shadow_size = 0
	c_style.shadow_offset = Vector2(3, 4)
	c_style.shadow_color = Color(0.06, 0.09, 0.16)
	c_style.content_margin_left = 14
	c_style.content_margin_right = 14
	c_style.content_margin_top = 6
	c_style.content_margin_bottom = 6
	tutorial_container.add_theme_stylebox_override("panel", c_style)
	tutorial_container.visible = false
	add_child(tutorial_container)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	tutorial_container.add_child(hbox)

	tutorial_label = Label.new()
	tutorial_label.name = "TutorialLabel"
	tutorial_label.add_theme_font_size_override("font_size", 14)
	tutorial_label.add_theme_color_override("font_color", Color(0.06, 0.09, 0.16))
	hbox.add_child(tutorial_label)

	tutorial_skip_btn = Button.new()
	tutorial_skip_btn.name = "TutorialSkipBtn"
	tutorial_skip_btn.text = "Skip"
	tutorial_skip_btn.focus_mode = Control.FOCUS_NONE
	tutorial_skip_btn.pressed.connect(func(): tutorial_skipped.emit())
	_style_button(tutorial_skip_btn, Color(0.88, 0.91, 0.94), Color(0.80, 0.84, 0.88))
	hbox.add_child(tutorial_skip_btn)

func show_tutorial_step(text: String, rect: Rect2) -> void:
	if tutorial_highlight == null:
		setup_tutorial_ui()
	tutorial_container.visible = true
	tutorial_highlight.visible = true
	tutorial_label.text = text
	update_tutorial_rect(rect)
	_update_banner_position()

func update_tutorial_rect(rect: Rect2) -> void:
	if tutorial_highlight != null and tutorial_highlight.visible:
		tutorial_highlight.position = rect.position
		tutorial_highlight.size = rect.size

func _update_banner_position() -> void:
	if tutorial_container == null:
		return
	tutorial_container.reset_size()
	var vp_size := get_viewport().get_visible_rect().size
	tutorial_container.position = Vector2(
		maxf(20.0, (vp_size.x - tutorial_container.size.x) * 0.5),
		102.0
	)

func hide_tutorial() -> void:
	if tutorial_container != null:
		tutorial_container.visible = false
	if tutorial_highlight != null:
		tutorial_highlight.visible = false
