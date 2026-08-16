extends Node

## Co-op arena controller. Added to each arena scene at runtime by
## GameState._maybe_setup_arena when the Net autoload has a live connection.
##
## Multi-player (vs single-player) changes:
##  - The arena's baked-in single "Player" is hidden and its camera disabled so
##    it can never hijack the view or be targeted as a player.
##  - Each connected peer gets its OWN Player node, created LOCALLY on every
##    machine (roster-driven, no cross-machine spawn broadcast), owned by that
##    peer via set_multiplayer_authority and positioned by a MultiplayerSynchronizer:
##       * the peer that owns a Player simulates it (moves/aims/attacks) and
##         its synchronizer broadcasts the position to everyone else;
##       * every non-owner just shows a position-replicated ghost of that Player.
##    Because every machine builds Player_<id> for every peer id in the roster
##    on its own side, there is no network race to "receive" a spawn — a peer
##    that joins late simply re-runs the roster pass and everyone stays in sync.
##  - Only the owning peer's Camera2D is enabled, so each player sees through
##    their own character.
##
## Single-player is untouched: when Net is inactive this node removes itself.

const PLAYER_SCENE: PackedScene = preload("res://src/entities/player/player/player.tscn")


## Created in _ready; holds one Player_<peerId> per connected peer.
var _players: Node2D

## Spawn point for co-op players. Captured from the baked-in single Player's
## position (the arena center) so per-peer players appear where a single player
## would — otherwise they orbited at world (0,0), far from enemies and outside
## the range of every automatic weapon.
var _spawn_point: Vector2 = Vector2(960, 540)


func _ready() -> void:
	var net: Node = get_node_or_null("/root/Net")
	if net == null or not net.active():
		queue_free()
		return

	_hide_baked_player()

	_players = Node2D.new()
	_players.name = "Players"
	add_child(_players)

	# Build a Player for each peer already in the roster, then keep in step as
	# the roster changes (new players join / leave mid-run).
	_ensure_players()
	if net.has_signal("classes_synced"):
		net.classes_synced.connect(_ensure_players)
	if net.has_signal("peer_left"):
		net.peer_left.connect(_on_peer_left)


## The arena scene contains one baked-in single-player "Player" that must not
## collide with per-peer spawns. Hide it, stop it, drop it from the "player"
## group (so enemies/HUD target real per-peer players), and crucially disable
## its Camera2D — otherwise that hidden camera stays "current" and locks every
## player's view to the baked player's old world position (the actual cause of
## "camera locked away from my character"). It is left in the tree (not freed)
## so GameState's bootstrap keeps adding stage furniture.
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
	var cam: Camera2D = baked.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.enabled = false
	# Remember where the single player would have stood, so per-peer players can
	# spawn in the middle of the arena instead of at world origin.
	if baked is Node2D:
		_spawn_point = (baked as Node2D).global_position
	# Relocate the baked player far off-screen and make it fully inert so it
	# can't block per-peer players, eat their projectiles, or be hit at spawn.
	baked.set_deferred("position", _spawn_point + Vector2(5000, 5000))


## Build a Player_<id> node for every peer currently in the roster. Idempotent:
## already-created players are skipped, so this can be re-run whenever the
## roster changes without duplicating anyone.
func _ensure_players() -> void:
	var net: Node = get_node_or_null("/root/Net")
	if net == null or _players == null:
		return
	var roster: Dictionary = net.get("peer_classes") as Dictionary
	if roster.is_empty():
		return
	for key: Variant in roster.keys():
		var id: int = int(key)
		if id < 1:
			continue
		_ensure_player(id, str(roster[key]))


func _ensure_player(id: int, class_id: String) -> void:
	var name: String = "Player_%d" % id
	if _players == null or _players.has_node(name):
		return
	var net: Node = get_node_or_null("/root/Net")
	var p: CharacterBody2D = PLAYER_SCENE.instantiate()
	p.name = name
	p.player_class_id = class_id
	# The owning peer simulates this Player; everyone else shows a ghost.
	p.set_multiplayer_authority(id)

	_add_position_sync(p)
	# Spawn at the arena center so players are actually among the enemies (see
	# _spawn_point). A tiny per-peer stagger keeps spawned players from stacking
	# exactly on top of one another / on the (now hidden) baked player.
	p.position = _spawn_point + Vector2((id - 1) * 40, 0)
	_players.add_child(p)

	# Only the owning peer's camera should be active — and it must be made
	# "current" explicitly, or a hidden/previous camera can lock the view
	# (the direct cause of a player seeing the arena from the wrong spot).
	var cam: Camera2D = p.get_node_or_null("Camera2D") as Camera2D
	if cam:
		var owner_id: int = int(net.my_peer_id) if net else 1
		cam.enabled = owner_id == id
		if owner_id == id:
			cam.make_current()


## Replicate this Player's position from its owning peer to every machine.
func _add_position_sync(p: Node) -> void:
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	cfg.add_property(NodePath(".:position"))
	cfg.property_set_spawn(NodePath(".:position"), true)
	cfg.property_set_replication_mode(NodePath(".:position"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	sync.root_path = NodePath("..")
	p.add_child(sync)


func _on_peer_left(id: int) -> void:
	if _players and _players.has_node("Player_%d" % id):
		_players.get_node("Player_%d" % id).queue_free()
