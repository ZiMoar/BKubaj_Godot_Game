extends Node

## Autoload (registered as "GameState") that holds the class roster and the
## currently selected class.
## The class-selection menu builds its options from here, so adding a new
## class = registering it in _init below and it appears automatically.

const KNIGHT: Dictionary = {
	"id": "knight",
	"name": "Knight",
	"desc": "Broad combo slashes that end in a heavy stab, plus a tower shield that blocks projectiles and shoves enemies back.",
	"primary": preload("res://src/entities/player/weapons/sword/sword_weapon.tscn"),
	"secondary": preload("res://src/entities/player/abilities/knight_shield.tscn"),
}

const RANGER: Dictionary = {
	"id": "ranger",
	"name": "Ranger",
	"desc": "A piercing Longbow and a Rain of Arrows that blankets a whole area.",
	"primary": preload("res://src/entities/player/weapons/ranger/ranger_bow_weapon.tscn"),
	"secondary": preload("res://src/entities/player/abilities/ranger_rain_weapon.tscn"),
}

const MAGE: Dictionary = {
	"id": "mage",
	"name": "Mage",
	"desc": "Homing Arcane Bolts and Mana Overload that briefly halves every cooldown.",
	"primary": preload("res://src/entities/player/weapons/magic_bolts/magic_bolts_weapon.tscn"),
	"secondary": preload("res://src/entities/player/abilities/mage_overload_weapon.tscn"),
}

var _classes: Dictionary = {}
var selected_class_id: String = "knight"


func _init() -> void:
	_register(KNIGHT)
	_register(RANGER)
	_register(MAGE)


func _register(def: Dictionary) -> void:
	if def.has("id"):
		_classes[def["id"]] = def


## All available classes, for building the selection menu. Order matters.
func get_class_list() -> Array[Dictionary]:
	return _classes.values()


func get_selected_class() -> Dictionary:
	return _classes.get(selected_class_id, KNIGHT)


func set_selected_class(id: String) -> void:
	if _classes.has(id):
		selected_class_id = id