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
	# Lifesteal is on-kill: breaking a pot leeches health to the player too.
	_apply_kill_lifesteal()
	# Co-op: a network-synced pot dies on the HOST. Roll its loot once here and
	# broadcast so every machine spawns its OWN copy for its local player (mixing
	# in the pot's special heal/xp/magnet/anvil table). Falls back to the local
	# single-roll drop otherwise.
	if _route_pot_loot():
		queue_free()
		return
	_roll_loot()
	queue_free()


## Co-op: this is a host-authoritative networked pot and I am the host. Roll the
## pot's loot once and broadcast it to every machine (including myself via
## call_local) so each spawns its own copy. Returns true if routed this way (the
## caller must NOT also roll locally, or the host would double-drop).
func _route_pot_loot() -> bool:
	var net: Node = get_node_or_null("/root/Net")
	if _enemy_net_id < 0 or net == null or not net.active() or not multiplayer.is_server():
		return false
	var enemy_net: Node = get_tree().get_first_node_in_group("enemy_net")
	if enemy_net == null or not enemy_net.has_method("spawn_pot_loot"):
		return false
	# Single authoritative loot roll mirroring _roll_loot's weighted table:
	# <0.25 heal, <0.75 XP, <0.99 magnet, else anvil. (0 heal, 1 XP, 2 magnet, 3 anvil)
	var r: float = randf()
	var roll: int = 0 if r < 0.25 else (1 if r < 0.75 else (2 if r < 0.99 else 3))
	enemy_net.rpc("spawn_pot_loot", global_position, roll)
	return true


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
