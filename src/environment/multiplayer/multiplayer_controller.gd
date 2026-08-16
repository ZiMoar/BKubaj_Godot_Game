extends Node

## Co-op arena controller. Added to each arena scene at runtime by
## GameState._maybe_setup_arena when the Net autoload has a live connection.
##
## In multiplayer the arena's baked-in single "Player" node is hidden and a
## Player is SPAWNED PER PEER via a MultiplayerSpawner (host-authoritative).
## Each spawned Player is:
##  - owned by its peer (set_multiplayer_authority), so only that peer simulates
##    its movement/inputs and everyone else just sees it via the synchronizer,
##  - given the class that peer picked (read from Net.peer_classes),
##  - position-replicated to every peer via a MultiplayerSynchronizer.
##
## Single-player is untouched: when Net is inactive this node removes itself.

const PLAYER_SCENE: PackedScene = preload("res://src/entities/player/player/player.tscn")

var _players: Node2D
var _spawner: MultiplayerSpawner


func _ready() -> void:
	var net: Node = get_node_or_null("/root/Net")
	if net == null or not net.active():
		queue_free()
		return
	_hide_baked_player()
	_setup_spawner()
	if net.is_host:
		_spawn_all()
		net.peer_connected.connect(_on_peer_connected)
	net.peer_left.connect(_on_peer_left)


## The arena scene contains one baked-in single-player "Player" that must not
## collide with per-peer spawns. Hide it and remove it from the "player" group
## so enemies/HUD pick up the real per-peer players instead. It is left in the
## tree (not freed) so GameState's bootstrap keeps adding stage furniture.
func _hide_baked_player() -> void:
	var arena: Node = get_tree().current_scene
	if arena == null:
		return
	var baked: Node = arena.get_node_or_null("Player")
	if baked == null:
		return
	baked.visible = false
	baked.set_process(false)
	baked.set_physics_process(false)
	if baked.is_in_group("player"):
		baked.remove_from_group("player")


func _setup_spawner() -> void:
	_players = Node2D.new()
	_players.name = "Players"
	add_child(_players)

	_spawner = MultiplayerSpawner.new()
	_spawner.name = "PlayerSpawner"
	add_child(_spawner)
	_spawner.spawn_path = _spawner.get_path_to(_players)
	_spawner.spawn_function = Callable(self, "_spawn_player")


## Host: spawn the host's own player (id 1) plus every connected client.
func _spawn_all() -> void:
	_spawn_player_for(1)
	for p: int in multiplayer.get_peers():
		if p >= 2:
			_spawn_player_for(p)


func _spawn_player_for(id: int) -> void:
	if id < 1:
		return
	if _players == null or _players.has_node("Player_%d" % id):
		return
	_spawner.spawn(id)


func _on_peer_connected(id: int) -> void:
	# Only the host owns the spawner and initiates spawns for new clients.
	if get_node_or_null("/root/Net") and get_node_or_null("/root/Net").is_host:
		_spawn_player_for(id)


func _on_peer_left(id: int) -> void:
	if _players and _players.has_node("Player_%d" % id):
		_players.get_node("Player_%d" % id).queue_free()


## Called on EVERY peer (host and clients) by the MultiplayerSpawner when the
## host spawns a player, producing that player node at a consistent path.
func _spawn_player(data: Variant) -> Node:
	var id: int = int(data)
	var net: Node = get_node_or_null("/root/Net")
	var p: CharacterBody2D = PLAYER_SCENE.instantiate()
	p.name = "Player_%d" % id
	p.player_class_id = str(net.peer_classes.get(id, "knight")) if net else "knight"
	p.set_multiplayer_authority(id)

	# Only the owning peer's camera should be active.
	var cam := p.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.enabled = net != null and net.my_peer_id == id

	# Replicate this player's position to every peer.
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	cfg.add_property(NodePath(".:position"))
	cfg.property_set_spawn(NodePath(".:position"), true)
	cfg.property_set_replication_mode(NodePath(".:position"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	sync.root_path = NodePath("..")
	p.add_child(sync)
	return p
