class_name GameDataSingleton
extends Node

# GameData - Persistent game progression & settings Autoload singleton

const SAVE_PATH: String = "user://tab_siege_save.json"

signal pins_updated(new_amount: int)
signal upgrade_unlocked(upgrade_id: String, new_level: int)

var pins: int = 0
var battles_played: int = 0
var battles_won: int = 0
var tutorial_done: bool = false

# Upgrade paths and their current levels (0 to 3)
var upgrades: Dictionary = {
	"drag_relocation": 0,
	"refresh_rush": 0,
	"active_focus": 0,
	"sacrifice_shield": 0
}

# Upgrade definitions with metadata, max levels, and costs
const UPGRADE_DEFS: Dictionary = {
	"drag_relocation": {
		"name": "Tab-Fold Drag Range",
		"icon_symbol": "PIN",
		"max_level": 3,
		"costs": [1, 2, 3],
		"descriptions": [
			"Base: 4 tiles Manhattan range, 15s cooldown",
			"Level 1: 5 tiles Manhattan range, 13s cooldown",
			"Level 2: 6 tiles Manhattan range, 11s cooldown",
			"Level 3: 7 tiles Manhattan range, 9s cooldown"
		]
	},
	"refresh_rush": {
		"name": "Overclocked Refresh",
		"icon_symbol": "REFRESH",
		"max_level": 3,
		"costs": [1, 2, 4],
		"descriptions": [
			"Base: 2 charges per battle, 5 cursor strikes",
			"Level 1: 3 charges per battle, 6 cursor strikes",
			"Level 2: 4 charges per battle, 7 cursor strikes",
			"Level 3: 5 charges per battle, 8 cursor strikes"
		]
	},
	"active_focus": {
		"name": "Hyper-Focused Tab",
		"icon_symbol": "FOCUS",
		"max_level": 3,
		"costs": [1, 2, 3],
		"descriptions": [
			"Base: +50% fire rate & coin income, 1.0s switch delay",
			"Level 1: +65% fire rate & coin income, 0.8s switch delay",
			"Level 2: +80% fire rate & coin income, 0.6s switch delay",
			"Level 3: +100% fire rate & coin income, 0.4s switch delay"
		]
	},
	"sacrifice_shield": {
		"name": "Sacrifice Tab Shield",
		"icon_symbol": "SHIELD",
		"max_level": 3,
		"costs": [1, 2, 3],
		"descriptions": [
			"Base: 4s neighbor invulnerability, 50% coin refund",
			"Level 1: 5s neighbor invulnerability, 60% coin refund",
			"Level 2: 6s neighbor invulnerability, 70% coin refund",
			"Level 3: 7.5s neighbor invulnerability, 85% coin refund"
		]
	}
}

func _ready() -> void:
	load_data()

func get_drag_max_range() -> int:
	var lvl: int = upgrades.get("drag_relocation", 0)
	return 4 + lvl

func get_drag_cooldown() -> float:
	var lvl: int = upgrades.get("drag_relocation", 0)
	return maxf(8.0, 15.0 - (lvl * 2.0))

func get_max_refresh_charges() -> int:
	var lvl: int = upgrades.get("refresh_rush", 0)
	return 2 + lvl

func get_refresh_cursor_count() -> int:
	var lvl: int = upgrades.get("refresh_rush", 0)
	return 5 + lvl

func get_focus_boost_multiplier() -> float:
	var lvl: int = upgrades.get("active_focus", 0)
	return 1.5 + (lvl * 0.15)

func get_focus_switch_delay() -> float:
	var lvl: int = upgrades.get("active_focus", 0)
	return maxf(0.3, 1.0 - (lvl * 0.2))

func get_shield_duration() -> float:
	var lvl: int = upgrades.get("sacrifice_shield", 0)
	return 4.0 + (lvl * 1.0 if lvl < 3 else 3.5)

func get_sacrifice_refund_ratio() -> float:
	var lvl: int = upgrades.get("sacrifice_shield", 0)
	return 0.50 + (lvl * 0.10 if lvl < 3 else 0.35)

func add_pins(amount: int) -> void:
	pins += amount
	pins_updated.emit(pins)
	save_data()

func can_afford_upgrade(upgrade_id: String) -> bool:
	if not UPGRADE_DEFS.has(upgrade_id):
		return false
	var def: Dictionary = UPGRADE_DEFS[upgrade_id]
	var current_lvl: int = upgrades.get(upgrade_id, 0)
	if current_lvl >= def["max_level"]:
		return false
	var cost: int = def["costs"][current_lvl]
	return pins >= cost

func purchase_upgrade(upgrade_id: String) -> bool:
	if not can_afford_upgrade(upgrade_id):
		return false
	var def: Dictionary = UPGRADE_DEFS[upgrade_id]
	var current_lvl: int = upgrades.get(upgrade_id, 0)
	var cost: int = def["costs"][current_lvl]
	pins -= cost
	upgrades[upgrade_id] = current_lvl + 1
	pins_updated.emit(pins)
	upgrade_unlocked.emit(upgrade_id, upgrades[upgrade_id])
	save_data()
	return true

func record_battle_result(won: bool, pins_earned: int) -> void:
	battles_played += 1
	if won:
		battles_won += 1
	add_pins(pins_earned)
	save_data()

func save_data() -> void:
	var data: Dictionary = {
		"pins": pins,
		"battles_played": battles_played,
		"battles_won": battles_won,
		"upgrades": upgrades,
		"tutorial_done": tutorial_done
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_string := JSON.stringify(data, "\t")
		file.store_string(json_string)
		file.close()

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var content := file.get_as_text()
		file.close()
		var parsed = JSON.parse_string(content)
		if parsed is Dictionary:
			pins = parsed.get("pins", 0)
			battles_played = parsed.get("battles_played", 0)
			battles_won = parsed.get("battles_won", 0)
			tutorial_done = parsed.get("tutorial_done", false)
			var saved_upgrades = parsed.get("upgrades", {})
			if saved_upgrades is Dictionary:
				for k in saved_upgrades:
					if upgrades.has(k):
						upgrades[k] = saved_upgrades[k]
