class_name TestFacilities
extends Node2D

## Test-map placeholder facilities: infinitely-respawning pickup slots, each
## pinned to a fixed spot. When one is collected it reappears after a short
## cooldown, giving the player a moment to step away before the next one
## reappears. Slots are laid out in two tidy rows — top = the four anvils,
## bottom = the four pickups — so the central corridor (player spawn <-> dummy)
## stays open.

## Scene path for each slot type.
const SCENES := {
	"anvil": "res://src/environment/anvil/anvil.tscn",
	"golden_anvil": "res://src/environment/anvil/anvil.tscn",
	"elemental_anvil": "res://src/environment/anvil/elemental_anvil.tscn",
	"inverted_anvil": "res://src/environment/anvil/inverted_anvil.tscn",
	"box": "res://src/environment/treasure_chest/treasure_chest.tscn",
	"relic": "res://src/pickups/artefact_pickup/artefact_pickup.tscn",
	"cursed_relic": "res://src/pickups/artefact_pickup/artefact_pickup.tscn",
	"winged_boots": "res://src/pickups/winged_boots/winged_boots.tscn",
}

## slot_id -> position relative to this node. Organized as a 2x4 grid: anvils on
## the top row, pickups on the bottom row, spaced ~240px apart so nothing overlaps.
@export var slots: Dictionary = {
	"elemental_anvil": Vector2(-360, -120),
	"anvil": Vector2(-120, -120),
	"inverted_anvil": Vector2(120, -120),
	"golden_anvil": Vector2(360, -120),
	"relic": Vector2(-360, 120),
	"cursed_relic": Vector2(-120, 120),
	"box": Vector2(120, 120),
	"winged_boots": Vector2(360, 120),
}
@export var respawn_cooldown: float = 2.0

var _nodes: Dictionary = {}   # slot_id -> live pickup node
var _waiting: Dictionary = {} # slot_id -> bool (collected, waiting to respawn)
var _timers: Dictionary = {}  # slot_id -> float countdown


func _ready() -> void:
	add_to_group("test_facilities")
	# Defer so we don't add_child onto the arena root while it's still instancing
	# its own children (adds to the parent would otherwise be rejected).
	for slot_id: String in slots:
		_nodes[slot_id] = null
		_waiting[slot_id] = false
		_timers[slot_id] = respawn_cooldown
		call_deferred("_spawn_slot", slot_id)


func _physics_process(delta: float) -> void:
	# Respawn a slot once its pickup has been collected and the cooldown elapsed.
	for slot_id: String in _waiting.keys():
		if not _waiting[slot_id]:
			continue
		if not is_instance_valid(_nodes.get(slot_id)):
			_timers[slot_id] = float(_timers.get(slot_id, respawn_cooldown)) - delta
			if _timers[slot_id] <= 0.0:
				_waiting[slot_id] = false
				_spawn_slot(slot_id)


## Instantiates a fresh pickup for the given slot at its pinned position.
func _spawn_slot(slot_id: String) -> void:
	var inst: Node = (load(SCENES[slot_id]) as PackedScene).instantiate()
	# Set variant flags BEFORE add_child so _ready()/_set_visual() pick them up.
	if slot_id == "golden_anvil":
		inst.set("is_golden", true)
	elif slot_id == "cursed_relic":
		inst.set("cursed", true)
	inst.global_position = global_position + (slots[slot_id] as Vector2)
	get_parent().add_child(inst)
	_nodes[slot_id] = inst
	_waiting[slot_id] = true
	_timers[slot_id] = respawn_cooldown
