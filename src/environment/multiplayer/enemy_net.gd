class_name EnemyNet
extends Node

## Host-authoritative enemy synchronization (added to the arena by
## MultiplayerController during a live co-op session, so it exists on EVERY
## machine — host and clients — with identical structure).
##
## The HOST is the only peer that spawns enemies (rule #2: always spawn on the
## server). All pre-existing timer-based spawners in the arena route their
## spawns through request_spawn(), which drives a MultiplayerSpawner whose
## spawn_function instantiates the SAME enemy scene on every peer. Clients do
## NOT spawn locally; they receive the host's spawned enemies via the spawner
## and render them as frozen replicas (AI disabled) whose position / hp come from
## a per-enemy MultiplayerSynchronizer.
##
## Damage (rule #3: RPCs for events): when a client's weapon/projectile hits an
## enemy replica, it calls enemy_base.take_damage() which forwards the already-
## computed hit to the host via apply_enemy_hit(). The host applies it to its
## authoritative copy; the updated hp and the eventual death replicate back.

const GROUP := "enemy_net"

# Shared-drop pickups. When a networked enemy dies, the HOST broadcasts the drop
# values and each machine spawns its OWN copies so its local player(s) can
# collect them (per-machine progression, matching how hp/run-state work).
const XP_ORB_SCENE := preload("res://src/pickups/xp_orb/xp_orb.tscn")
const GOLD_PICKUP_SCENE := preload("res://src/pickups/gold_pickup/gold_pickup.tscn")
const SOUL_PICKUP_SCENE := preload("res://src/pickups/soul_pickup/soul_pickup.tscn")
const ARTEFACT_PICKUP_SCENE := preload("res://src/pickups/artefact_pickup/artefact_pickup.tscn")
const DROP_SCATTER_RADIUS := 28.0

# Enemies spawned by the host before a joining client exists must be reachable
# when the client later applies a hit, so we always route through this id space.
var _enemies: Node2D = null
var _spawner: MultiplayerSpawner = null
var _next_id: int = 1


func _ready() -> void:
	_enemies = Node2D.new()
	_enemies.name = "Enemies"
	add_child(_enemies)

	_spawner = MultiplayerSpawner.new()
	_spawner.name = "EnemySpawner"
	add_child(_spawner)
	_spawner.spawn_path = _spawner.get_path_to(_enemies)
	_spawner.spawn_function = Callable(self, "_spawn_enemy")
	# The host owns the spawner: only it may call spawn(), everyone else
	# receives the spawned enemies. Peer 1 is always the ENet host.
	_spawner.set_multiplayer_authority(1)

	add_to_group(GROUP)


## Host-only entry point used by arena spawners. Creates the enemy on EVERY
## machine via the MultiplayerSpawner. Returns null (the node is built in
## _spawn_enemy on all peers). On a client this is a no-op.
func request_spawn(scene_path: String, pos: Vector2) -> Node2D:
	if not multiplayer.is_server():
		return null
	var net_id: int = _next_id
	_next_id += 1
	_spawner.spawn({"scene": scene_path, "pos": pos, "id": net_id})
	return null


## Called by the MultiplayerSpawner on EVERY peer (host authority + client
## replicas) each time the host spawns an enemy.
func _spawn_enemy(data: Dictionary) -> Node2D:
	var scene: PackedScene = load(str(data["scene"]))
	if scene == null:
		return null
	var en: Node2D = scene.instantiate()
	en.name = "Enemy_%d" % int(data["id"])
	en.global_position = data["pos"]
	# Store the shared network id so the client can address the host's copy when
	# it deals damage, and so the node's _ready can tell it's network-spawned.
	if en.has_method("set_enemy_net_id"):
		en.call("set_enemy_net_id", int(data["id"]))
	en.set_meta("enemy_net_id", int(data["id"]))
	_add_enemy_sync(en)
	return en


## Every enemy gets a MultiplayerSynchronizer replicating its position and its
## health from the host (authority) to clients (replicas). root_path ".." is
## relative to the synchronizer node, i.e. the enemy itself.
func _add_enemy_sync(en: Node) -> void:
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	sync.replication_interval = 0.0
	var cfg := SceneReplicationConfig.new()
	var props: Array[NodePath] = [
		NodePath(".:position"),
		NodePath(".:max_health"),
		NodePath(".:current_health"),
	]
	for prop: NodePath in props:
		cfg.add_property(prop)
		cfg.property_set_replication_mode(prop, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	sync.root_path = NodePath("..")
	en.add_child(sync)


## Client -> host: one of this enemy's replicas was hit. Only the host applies
## it (to the authoritative copy). `amount` is already the attacker's final
## damage, so no stats need to travel — the host just commits it and the
## resulting hp / death replicate back out.
@rpc("any_peer", "reliable")
func apply_enemy_hit(enemy_net_id: int, amount: int, is_critical: bool, damage_type: int, suppress_ailment: bool, ailment_multiplier: float) -> void:
	if not multiplayer.is_server():
		return  # only the host decides
	var en: Node2D = _find_enemy(enemy_net_id)
	if en == null or not is_instance_valid(en):
		return
	if en.has_method("take_damage"):
		en.call("take_damage", maxi(1, amount), is_critical, damage_type, suppress_ailment, ailment_multiplier)


## HOST -> every machine: a networked enemy died at `pos` and its drops must be
## shared. Each machine (host included, via call_local) spawns its OWN copies of
## the XP orb and gold coin so its local player(s) can collect them. The soul
## pickup is decided per-machine because it depends on that player's Soul
## Harvest relic. Drop VALUES (xp/gold) come from the host so all machines agree.
@rpc("authority", "reliable", "call_local")
func spawn_shared_drops(pos: Vector2, xp_value: int, xp_tier: int, gold_value: int) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	_spawn_xp_orb(pos, xp_value, xp_tier)
	_spawn_gold_coin(pos, gold_value)
	_spawn_soul(pos)


func _spawn_xp_orb(pos: Vector2, value: int, tier: int) -> void:
	var orb: Node = XP_ORB_SCENE.instantiate()
	if orb == null:
		return
	orb.global_position = pos + _scatter()
	if orb.has_method("setup"):
		orb.setup(maxi(1, value), maxi(1, tier))
	get_tree().current_scene.call_deferred("add_child", orb)


func _spawn_gold_coin(pos: Vector2, value: int) -> void:
	var coin: Node = GOLD_PICKUP_SCENE.instantiate()
	if coin == null:
		return
	coin.global_position = pos + _scatter()
	if coin.has_method("setup"):
		coin.setup(maxi(1, value))
	get_tree().current_scene.call_deferred("add_child", coin)


## HOST -> every machine: the boss died and its relic reward must be shared.
## Each machine spawns its OWN copy so its local player can pick it up — the
## artefact choice is randomized per-player on pickup, so no content needs to
## travel (mirrors how xp/gold drops are per-machine copies of shared values).
@rpc("authority", "reliable", "call_local")
func spawn_boss_relic(pos: Vector2) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var pickup: Node = ARTEFACT_PICKUP_SCENE.instantiate()
	if pickup == null:
		return
	pickup.global_position = pos
	scene.add_child(pickup)


## Soul drops are per-machine: only spawn one if THIS machine's player holds the
## Soul Harvest relic (mirrors enemy_base._drop_soul).
func _spawn_soul(pos: Vector2) -> void:
	var plr: Node = get_tree().get_first_node_in_group("player")
	if plr == null or not plr.has_method("has_artefact") or not plr.has_artefact("soul_harvest"):
		return
	if get_tree().current_scene == null:
		return
	var soul: Node = SOUL_PICKUP_SCENE.instantiate()
	if soul == null:
		return
	soul.global_position = pos + _scatter()
	get_tree().current_scene.call_deferred("add_child", soul)


func _scatter() -> Vector2:
	var angle: float = randf() * TAU
	return Vector2(cos(angle), sin(angle)) * randf_range(6.0, DROP_SCATTER_RADIUS)


func _find_enemy(enemy_net_id: int) -> Node2D:
	if _enemies == null:
		return null
	for c: Node in _enemies.get_children():
		if c.has_meta("enemy_net_id") and int(c.get_meta("enemy_net_id")) == enemy_net_id:
			return c as Node2D
	return null
