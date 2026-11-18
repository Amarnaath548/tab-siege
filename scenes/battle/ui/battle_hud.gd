class_name BattleHUD
extends CanvasLayer

# Battle HUD: Match timer (3:00), Coins, Refresh charges, Active Focus pill,
# Triangulation Hold gauge, Tower purchase button, Player Cursor Strike button, and End Modal.

signal build_tower_requested()
signal player_strike_requested()
signal atlas_menu_requested()
signal restart_requested()

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

func _on_coins_changed(new_amount: int) -> void:
	coins_label.text = "$%d" % new_amount
	buy_tower_btn.disabled = new_amount < 20
	strike_btn.disabled = new_amount < 15

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
	end_modal.visible = true
	if victory:
		result_title.text = "VICTORY! TAB BAR TRIANGULATED"
		result_title.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
		result_desc.text = reason
		var bm = get_node_or_null("/root/BattleManager")
		var pins_earned := 2
		if bm and bm.match_time_remaining >= 60.0:
			pins_earned = 3
		pins_earned_label.text = "+%d PINS EARNED!" % pins_earned
	else:
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
