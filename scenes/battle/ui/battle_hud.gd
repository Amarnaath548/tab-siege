class_name BattleHUD
extends CanvasLayer

# Battle HUD: Match timer (3:00), Coins, Refresh charges, Active Focus pill,
# Triangulation Hold gauge, Tower purchase button, Player Cursor Strike button, and End Modal.

signal build_tower_requested()
signal player_strike_requested()
signal atlas_menu_requested()
signal restart_requested()
signal tutorial_skipped()

var tutorial_highlight: Panel
var tutorial_label: Label
var tutorial_skip_btn: Button
var tutorial_container: PanelContainer

@onready var timer_label: Label = $TopBar/HBox/TimerContainer/TimerLabel
@onready var coins_label: Label = $TopBar/HBox/CoinsContainer/CoinsLabel
@onready var refresh_label: Label = $TopBar/HBox/RefreshContainer/RefreshLabel
@onready var focus_label: Label = $TopBar/HBox/FocusContainer/FocusLabel
@onready var hold_container: Control = $TopBar/HBox/HoldContainer
@onready var hold_bar: ProgressBar = $TopBar/HBox/HoldContainer/HoldBar
@onready var hold_label: Label = $TopBar/HBox/HoldContainer/HoldLabel

@onready var buy_tower_btn: Button = $BottomBar/HBox/BuyTowerBtn
@onready var strike_btn: Button = $BottomBar/HBox/StrikeBtn

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
	atlas_btn.pressed.connect(func(): atlas_menu_requested.emit())
	retry_btn.pressed.connect(func(): restart_requested.emit())

func _on_time_updated(seconds_left: float) -> void:
	var mins := int(seconds_left) / 60
	var secs := int(seconds_left) % 60
	timer_label.text = "%02d:%02d" % [mins, secs]
	if seconds_left < 30.0:
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		timer_label.add_theme_color_override("font_color", Color.WHITE)

var _prev_coins: int = -1

func _on_coins_changed(new_amount: int) -> void:
	if _prev_coins >= 0 and new_amount > _prev_coins:
		_show_floating_coins(new_amount - _prev_coins)
	_prev_coins = new_amount
	coins_label.text = "$%d" % new_amount
	buy_tower_btn.disabled = new_amount < 20
	strike_btn.disabled = new_amount < 15

func _show_floating_coins(amount: int) -> void:
	var label := Label.new()
	label.text = "+$%d" % amount
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	label.add_theme_font_size_override("font_size", 16)
	label.position = coins_label.global_position + Vector2(10, 20)
	label.z_index = 100
	add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 25.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)

func _on_refresh_charges_changed(remaining: int, max_c: int) -> void:
	refresh_label.text = "REFRESH: %d/%d" % [remaining, max_c]

func _on_focus_changed(focused_tab: Node) -> void:
	if focused_tab != null and is_instance_valid(focused_tab):
		var title: String = focused_tab.tab_title if "tab_title" in focused_tab else "Tab"
		focus_label.text = "FOCUS: %s (+50%% BOOST)" % title
		focus_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	else:
		focus_label.text = "FOCUS: NONE (Click a Tab)"
		focus_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))

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
	if victory:
		if synth and synth.has_method("play_victory"):
			synth.play_victory()
		result_title.text = "VICTORY! TAB BAR TRIANGULATED"
		result_title.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
		result_desc.text = reason
		var bm = get_node_or_null("/root/BattleManager")
		var pins_earned := 2
		if bm and bm.match_time_remaining >= 60.0:
			pins_earned = 3
		pins_earned_label.text = "+%d PINS EARNED!" % pins_earned
	else:
		if synth and synth.has_method("play_defeat"):
			synth.play_defeat()
		result_title.text = "DEFEAT"
		result_title.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		result_desc.text = reason
		pins_earned_label.text = "0 PINS EARNED"

func _on_buy_tower_pressed() -> void:
	var bm = get_node_or_null("/root/BattleManager")
	if bm and bm.spend_coins(20):
		build_tower_requested.emit()

func _on_strike_pressed() -> void:
	var bm = get_node_or_null("/root/BattleManager")
	if bm and bm.spend_coins(15):
		player_strike_requested.emit()

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
	h_style.border_color = Color(1.0, 0.85, 0.2, 0.95)
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
	c_style.bg_color = Color(0.08, 0.11, 0.18, 0.92)
	c_style.border_width_left = 1
	c_style.border_width_right = 1
	c_style.border_width_top = 1
	c_style.border_width_bottom = 1
	c_style.border_color = Color(0.4, 0.6, 0.9, 0.7)
	c_style.corner_radius_top_left = 8
	c_style.corner_radius_top_right = 8
	c_style.corner_radius_bottom_left = 8
	c_style.corner_radius_bottom_right = 8
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
	tutorial_label.add_theme_font_size_override("font_size", 16)
	tutorial_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	hbox.add_child(tutorial_label)

	tutorial_skip_btn = Button.new()
	tutorial_skip_btn.name = "TutorialSkipBtn"
	tutorial_skip_btn.text = "Skip"
	tutorial_skip_btn.focus_mode = Control.FOCUS_NONE
	tutorial_skip_btn.pressed.connect(func(): tutorial_skipped.emit())
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
		54.0
	)

func hide_tutorial() -> void:
	if tutorial_container != null:
		tutorial_container.visible = false
	if tutorial_highlight != null:
		tutorial_highlight.visible = false
