class_name ShopItem
extends Area2D

## A shop pedestal: the player pays gold to spawn the actual item out in front,
## then walks over it to collect (anvils, heal runes, Winged Boots) or takes a
## level-up directly. Once bought, the pedestal is spent (non-repeatable).

signal item_purchased(item_kind: String)

enum Kind {
	LEVEL,               # +1 free level (cost depends on current level)
	NORMAL_ANVIL,        # standard anvil
	ELEMENTAL_ANVIL,     # blue anvil
	INVERTED_ANVIL,      # purple anvil
	GOLDEN_ANVIL,        # guaranteed signature upgrade
	WINGED_BOOTS,        # dash-upgrade choice
	HEAL_25,             # 25% max heal rune
	HEAL_50,             # 50% max heal rune
	HEAL_FULL,           # 100% max heal rune
}

const ANVIL_SCENE: PackedScene = preload("res://src/environment/anvil/anvil.tscn")
const ELEMENTAL_ANVIL_SCENE: PackedScene = preload("res://src/environment/anvil/elemental_anvil.tscn")
const INVERTED_ANVIL_SCENE: PackedScene = preload("res://src/environment/anvil/inverted_anvil.tscn")
const WINGED_BOOTS_SCENE: PackedScene = preload("res://src/pickups/winged_boots/winged_boots.tscn")
const HEAL_25_SCENE: PackedScene = preload("res://src/pickups/heal_pickup/heal_25.tscn")
const HEAL_50_SCENE: PackedScene = preload("res://src/pickups/heal_pickup/heal_50.tscn")
const HEAL_FULL_SCENE: PackedScene = preload("res://src/pickups/heal_pickup/heal_full.tscn")

@export var kind: int = Kind.NORMAL_ANVIL
@export var cost: int = 200

var _player_present: bool = false
var _sold: bool = false

@onready var price_label: Label = get_node_or_null("PriceLabel") as Label
@onready var name_label: Label = get_node_or_null("NameLabel") as Label


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_label()


func _unhandled_input(event: InputEvent) -> void:
	if _sold or not _player_present:
		return
	if event.is_action_pressed("interact"):
		_try_buy()


## Configure this pedestal with a kind + cost (called by the shop room after
## rolling which special/heal variant this shop stocks).
func setup(item_kind: int, item_cost: int) -> void:
	kind = item_kind
	cost = item_cost
	if is_node_ready():
		_update_label()


func _update_label() -> void:
	if name_label:
		name_label.text = _item_name()
	if price_label:
		price_label.text = "%dg" % cost
	queue_redraw()


func _item_name() -> String:
	match kind:
		Kind.LEVEL: return "+1 Level"
		Kind.NORMAL_ANVIL: return "Anvil"
		Kind.ELEMENTAL_ANVIL: return "Elemental Anvil"
		Kind.INVERTED_ANVIL: return "Inverted Anvil"
		Kind.GOLDEN_ANVIL: return "Golden Anvil"
		Kind.WINGED_BOOTS: return "Winged Boots"
		Kind.HEAL_25: return "Small Heal"
		Kind.HEAL_50: return "Great Heal"
		Kind.HEAL_FULL: return "Full Heal"
	return "?"


func _draw() -> void:
	# Pedestal base + a small glow when a buyer is near.
	var colour: Color = _item_color()
	var flash: float = 1.0
	if _player_present and not _sold:
		flash = 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.008)
	draw_circle(Vector2(0, 3), 12.0, Color(0.2, 0.2, 0.22))
	draw_circle(Vector2.ZERO, 9.0, colour * flash)
	draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 20, colour.lightened(0.4), 1.4)


func _item_color() -> Color:
	match kind:
		Kind.LEVEL: return Color(0.7, 0.95, 0.4)
		Kind.NORMAL_ANVIL: return Color(0.6, 0.6, 0.68)
		Kind.ELEMENTAL_ANVIL: return Color(0.4, 0.65, 0.95)
		Kind.INVERTED_ANVIL: return Color(0.8, 0.35, 0.6)
		Kind.GOLDEN_ANVIL: return Color(0.95, 0.72, 0.22)
		Kind.WINGED_BOOTS: return Color(0.6, 0.8, 1.0)
		Kind.HEAL_25: return Color(0.4, 0.85, 0.5)
		Kind.HEAL_50: return Color(0.35, 0.9, 0.5)
		Kind.HEAL_FULL: return Color(0.25, 1.0, 0.55)
	return Color.WHITE


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_present = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_present = false


func _try_buy() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not player.has_method("can_afford") or not player.has_method("spend_gold"):
		return
	if not player.can_afford(cost):
		_flash_deny()
		return
	if not player.spend_gold(cost):
		return

	_sold = true
	_spawn_payload(player)
	item_purchased.emit(str(kind))
	price_label.text = "SOLD"
	name_label.text = ""
	queue_redraw()


## Actually grants / spawns the paid-for item.
func _spawn_payload(_player: Node2D) -> void:
	var spawn_pos: Vector2 = global_position + Vector2(0, 30)
	match kind:
		Kind.LEVEL:
			var xp_mgr: Node = get_tree().get_first_node_in_group("team_xp_manager")
			if xp_mgr and xp_mgr.has_method("add_free_level"):
				xp_mgr.add_free_level()
		Kind.NORMAL_ANVIL:
			_spawn_scene(ANVIL_SCENE, spawn_pos)
		Kind.ELEMENTAL_ANVIL:
			_spawn_scene(ELEMENTAL_ANVIL_SCENE, spawn_pos)
		Kind.INVERTED_ANVIL:
			_spawn_scene(INVERTED_ANVIL_SCENE, spawn_pos)
		Kind.GOLDEN_ANVIL:
			var a: Anvil = ANVIL_SCENE.instantiate()
			a.is_golden = true
			_setup_spawn(a, spawn_pos)
		Kind.WINGED_BOOTS:
			_spawn_scene(WINGED_BOOTS_SCENE, spawn_pos)
		Kind.HEAL_25:
			_spawn_scene(HEAL_25_SCENE, spawn_pos)
		Kind.HEAL_50:
			_spawn_scene(HEAL_50_SCENE, spawn_pos)
		Kind.HEAL_FULL:
			_spawn_scene(HEAL_FULL_SCENE, spawn_pos)


func _spawn_scene(scene: PackedScene, pos: Vector2) -> void:
	var inst: Node2D = scene.instantiate()
	_setup_spawn(inst, pos)


func _setup_spawn(inst: Node2D, pos: Vector2) -> void:
	if get_tree().current_scene != null:
		get_tree().current_scene.add_child(inst)
	elif get_parent() != null:
		get_parent().add_child(inst)
	else:
		add_child(inst)
	inst.global_position = pos


func _flash_deny() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.4, 0.12)
	tween.tween_property(self, "modulate:a", 1.0, 0.12)
