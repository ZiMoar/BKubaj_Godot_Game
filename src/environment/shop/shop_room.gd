class_name ShopRoom
extends Node2D

## Non-combat SHOP room: the player spends gold at pedestals to spawn items.
##
## Always stocked:
##   - +1 Level pedestal (cost scales with current team level)
##   - Normal anvil pedestal (~200 gold)
##
## Randomly stocked (rolled ONCE when the shop spawns, not at buy):
##   - Special pedestal: 30% Elemental / 30% Inverted / 30% Winged Boots / 10% Golden
##   - Heal pedestal: 50% small / 35% great / 15% full heal
##
## Special types cost ~500; golden costs 1000. Heal costs are set so the bigger
## runes are more cost-effective than buying several smalls.

const ShopItemScript: Script = preload("res://src/environment/shop/shop_item.gd")

const NORMAL_ANVIL_COST: int = 200
const SPECIAL_ANVIL_COST: int = 500
const GOLDEN_ANVIL_COST: int = 1000
const HEAL_25_COST: int = 40
const HEAL_50_COST: int = 70
const HEAL_FULL_COST: int = 120

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	_build_shop()


## Position slots for the pedestals (left to right across the floor).
func _slot_positions() -> Array[Vector2]:
	return [
		Vector2(-220, 0),
		Vector2(-110, 0),
		Vector2(0, 0),
		Vector2(110, 0),
	]

func _find_hud() -> Node:
	return get_tree().get_first_node_in_group("hud")


## Compute the level-up cost based on the current team level. Roughly the cost a
## player would have spent on XP elsewhere: base 120 + 40 per level beyond 1.
func _level_up_cost() -> int:
	var level: int = 1
	var mgr: Node = get_tree().get_first_node_in_group("team_xp_manager")
	if mgr and mgr.get("team_level") != null:
		level = int(mgr.get("team_level"))
	level = maxi(1, level)
	return 120 + (level - 1) * 40


## Roll which special variant and which heal variant this shop stocks.
func _roll_variants() -> void:
	var special: int = ShopItemScript.Kind.WINGED_BOOTS
	var special_cost: int = SPECIAL_ANVIL_COST
	var roll_s: float = rng.randf()
	# 30% elemental / 30% inverted / 30% winged boots / 10% golden.
	if roll_s < 0.30:
		special = ShopItemScript.Kind.ELEMENTAL_ANVIL
	elif roll_s < 0.60:
		special = ShopItemScript.Kind.INVERTED_ANVIL
	elif roll_s < 0.90:
		special = ShopItemScript.Kind.WINGED_BOOTS
	else:
		special = ShopItemScript.Kind.GOLDEN_ANVIL
		special_cost = GOLDEN_ANVIL_COST

	var heal: int = ShopItemScript.Kind.HEAL_25
	var heal_cost: int = HEAL_25_COST
	var roll_h: float = rng.randf()
	# 50% small / 35% great / 15% full.
	if roll_h < 0.50:
		heal = ShopItemScript.Kind.HEAL_25
		heal_cost = HEAL_25_COST
	elif roll_h < 0.85:
		heal = ShopItemScript.Kind.HEAL_50
		heal_cost = HEAL_50_COST
	else:
		heal = ShopItemScript.Kind.HEAL_FULL
		heal_cost = HEAL_FULL_COST

	_special_kind = special
	_special_cost = special_cost
	_heal_kind = heal
	_heal_cost = heal_cost


var _special_kind: int = ShopItemScript.Kind.WINGED_BOOTS
var _special_cost: int = SPECIAL_ANVIL_COST
var _heal_kind: int = ShopItemScript.Kind.HEAL_25
var _heal_cost: int = HEAL_25_COST


## Build the 4 pedestals so this shop can be previewed standalone (each one is a
## instantiable ShopItem; a future spawner just needs to add this room + a shop
## with these configured pedestals).
func _build_shop() -> void:
	_roll_variants()
	var slots: Array[Vector2] = _slot_positions()
	_pedestal(slots[0], ShopItemScript.Kind.LEVEL, _level_up_cost())
	_pedestal(slots[1], ShopItemScript.Kind.NORMAL_ANVIL, NORMAL_ANVIL_COST)
	_pedestal(slots[2], _special_kind, _special_cost)
	_pedestal(slots[3], _heal_kind, _heal_cost)


func _pedestal(pos: Vector2, item_kind: int, item_cost: int) -> void:
	var item: Area2D = load("res://src/environment/shop/shop_item.tscn").instantiate()
	# Force the script var (avoid relying on tscn defaults).
	item.set("kind", item_kind)
	item.set("cost", item_cost)
	add_child(item)
	item.position = pos
