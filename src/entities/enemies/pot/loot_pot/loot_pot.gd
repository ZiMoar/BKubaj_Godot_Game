class_name LootPot
extends EnemyBase

## Stationary breakable pot / jug. It never walks, never attacks, and deals no
## contact damage — the only reason to break it is its loot. On death it rolls
## its special loot table:
##   25% small heal · 50% purple XP orb (room-scaled) · 24% magnet · 1% anvil

const HEAL_SCENE: PackedScene = preload("res://src/pickups/heal_pickup/heal_25.tscn")
const ANVIL_SCENE: PackedScene = preload("res://src/environment/anvil/anvil.tscn")
const MAGNET_SCENE: PackedScene = preload("res://src/pickups/magnet_pickup/magnet_pickup.tscn")


func _ready() -> void:
	doodle_kind = 7  # pot / jug silhouette
	doodle_color = Color(0.85, 0.6, 0.35)
	doodle_size = 9.0
	speed = 0.0                # doesn't walk
	contact_damage = 0         # no damage, never hurts the player
	max_health = 60            # as tanky as a bomber
	xp_value = 4
	xp_orb_tier = 3            # purple orb
	gold_value = 6
	weight = 15.0
	stat_scale_per_difficulty = 0.5   # match bomber toughness growth
	damage_scale_ratio = 0.0          # (nothing to scale — no damage)
	speed_scale_per_difficulty = 0.0
	super._ready()


## The pot never moves or attacks. It only ticks its status DoTs so burn/poison
## can still destroy it. No chasing, no orbiting, no contact damage.
func _physics_process(delta: float) -> void:
	_process_status_dots(delta)


## Pots deal no contact damage — break them with a weapon, not by touching them.
func _on_hitbox_touch(_node: Node) -> void:
	pass


func die() -> void:
	_is_dead = true
	_spread_ailments_on_death()
	_register_kill()
	_roll_loot()
	queue_free()


## Single loot-table roll: 25% heal, 50% purple XP, 24% magnet, 1% anvil.
func _roll_loot() -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var roll: float = randf()
	if roll < 0.25:
		_drop_heal()
	elif roll < 0.75:
		_drop_xp()   # purple orb, room-scaled exactly like regular enemies
	elif roll < 0.99:
		_drop_magnet()
	else:
		_drop_anvil()


func _drop_heal() -> void:
	var heal: Node2D = HEAL_SCENE.instantiate() as Node2D
	heal.global_position = global_position + _random_scatter()
	get_tree().current_scene.call_deferred("add_child", heal)


func _drop_magnet() -> void:
	var magnet: Node2D = MAGNET_SCENE.instantiate() as Node2D
	magnet.global_position = global_position + _random_scatter()
	get_tree().current_scene.call_deferred("add_child", magnet)


func _drop_anvil() -> void:
	var anvil: Node2D = ANVIL_SCENE.instantiate() as Node2D
	anvil.global_position = global_position + _random_scatter()
	get_tree().current_scene.call_deferred("add_child", anvil)
