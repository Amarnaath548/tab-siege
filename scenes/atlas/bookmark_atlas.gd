class_name BookmarkAtlas
extends Control

# Bookmark Atlas Progression Menu:
# Displays the 4 upgrade branches (Drag Relocation, Refresh Rush, Active Focus, Sacrifice Shield)
# and lets players spend earned Pins to permanently unlock tab enhancements.

signal start_battle_requested()

@onready var pins_label: Label = $VBox/TopBar/PinsLabel
@onready var cards_container: HBoxContainer = $VBox/CardsContainer
@onready var launch_btn: Button = $VBox/BottomBar/LaunchBtn
@onready var stats_label: Label = $VBox/BottomBar/StatsLabel

var card_ui_map: Dictionary = {}

func _ready() -> void:
	launch_btn.pressed.connect(func(): start_battle_requested.emit())
	_render_atlas()

func _render_atlas() -> void:
	pins_label.text = "PINS: %d" % GameData.pins
	stats_label.text = "Battles Won: %d / %d" % [GameData.battles_won, GameData.battles_played]
	
	for child in cards_container.get_children():
		child.queue_free()
	card_ui_map.clear()

	for up_id in GameData.UPGRADE_DEFS.keys():
		var def: Dictionary = GameData.UPGRADE_DEFS[up_id]
		var cur_lvl: int = GameData.upgrades.get(up_id, 0)
		var max_lvl: int = def["max_level"]
		
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(260, 380)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Chunky Flat-Vector Card Style
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.97, 0.98, 0.99) # #F8FAFC
		card_style.border_width_left = 3
		card_style.border_width_top = 3
		card_style.border_width_right = 3
		card_style.border_width_bottom = 3
		card_style.border_color = Color(0.06, 0.09, 0.16) # #0F172A
		card_style.corner_radius_top_left = 8
		card_style.corner_radius_top_right = 8
		card_style.corner_radius_bottom_left = 8
		card_style.corner_radius_bottom_right = 8
		card_style.shadow_size = 0
		card_style.shadow_offset = Vector2(3, 4)
		card_style.shadow_color = Color(0.06, 0.09, 0.16)
		card_style.content_margin_left = 16
		card_style.content_margin_top = 16
		card_style.content_margin_right = 16
		card_style.content_margin_bottom = 16
		card.add_theme_stylebox_override("panel", card_style)
		cards_container.add_child(card)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 12)
		card.add_child(vbox)

		# Header
		var title := Label.new()
		title.text = def["name"]
		title.add_theme_font_size_override("font_size", 16)
		title.add_theme_color_override("font_color", Color(0.06, 0.09, 0.16))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(title)

		# Tier indicator
		var tier_label := Label.new()
		tier_label.text = "Level: %d / %d" % [cur_lvl, max_lvl]
		tier_label.add_theme_color_override("font_color", Color(0.12, 0.53, 0.90))
		tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(tier_label)

		# Description
		var desc := Label.new()
		var desc_text := ""
		for i in range(def["descriptions"].size()):
			var prefix := "★ " if i == cur_lvl else "   "
			desc_text += "%s%s\n" % [prefix, def["descriptions"][i]]
		desc.text = desc_text
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color", Color(0.28, 0.33, 0.41))
		desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc)

		# Upgrade Button
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 42)
		var btn_style := StyleBoxFlat.new()
		btn_style.border_width_left = 3
		btn_style.border_width_top = 3
		btn_style.border_width_right = 3
		btn_style.border_width_bottom = 3
		btn_style.border_color = Color(0.06, 0.09, 0.16)
		btn_style.corner_radius_top_left = 6
		btn_style.corner_radius_top_right = 6
		btn_style.corner_radius_bottom_left = 6
		btn_style.corner_radius_bottom_right = 6
		btn_style.shadow_size = 0
		btn_style.shadow_offset = Vector2(3, 4)
		btn_style.shadow_color = Color(0.06, 0.09, 0.16)
		if cur_lvl >= max_lvl:
			btn.text = "MAX LEVEL"
			btn.disabled = true
			btn_style.bg_color = Color(0.80, 0.84, 0.88)
		else:
			var cost: int = def["costs"][cur_lvl]
			btn.text = "UPGRADE (%d PINS)" % cost
			btn.disabled = (GameData.pins < cost)
			btn_style.bg_color = Color(0.13, 0.77, 0.36) if not btn.disabled else Color(0.80, 0.84, 0.88)
			btn.pressed.connect(_on_upgrade_pressed.bind(up_id))
		btn.add_theme_stylebox_override("normal", btn_style)
		
		vbox.add_child(btn)

func _on_upgrade_pressed(upgrade_id: String) -> void:
	if GameData.purchase_upgrade(upgrade_id):
		AudioSynth.play_merge()
		_render_atlas()
