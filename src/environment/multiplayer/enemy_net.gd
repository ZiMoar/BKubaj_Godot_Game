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


func _find_enemy(enemy_net_id: int) -> Node2D:
	if _enemies == null:
		return null
	for c: Node in _enemies.get_children():
		if c.has_meta("enemy_net_id") and int(c.get_meta("enemy_net_id")) == enemy_net_id:
			return c as Node2D
	return null
