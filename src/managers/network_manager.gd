class_name NetworkManager
extends Node

## Co-op networking autoload (registered as "Net").
##
## Implements a NATIVE listening-server (host-and-play) model over ENet — the
## host runs both the server (peer id 1) and its own player; clients connect
## directly to the host's IP and become additional peer ids. No external relay
## or subscription is used; play is over LAN or a port-forwarded IP.
##
## Responsibilities:
##  - Creating the host server (create_host) / connecting a client (join_game).
##  - Tracking each peer's chosen class (peer_classes) so the arena can spawn a
##    correctly-classed Player node per peer.
##  - Signalling connection lifecycle + broadcasting the "load arena" kickoff.

signal peer_connected(id: int)
signal peer_left(id: int)
signal connected_to_host()
signal connection_failed_to_host()
signal server_disconnected()
signal classes_synced()

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 4
const CATACOMBS_ARENA_PATH: String = "res://src/environment/catacombs_arena.tscn"

# The class this machine picked in the co-op setup menu.
var my_class_id: String = "knight"
# Maps peer id (int) -> class id (String) for every connected peer.
var peer_classes: Dictionary = {}
var is_host: bool = false
var my_peer_id: int = 1

## True while a stage transition is being broadcast; prevents double-advancing
## when both players reach the door at nearly the same time. Reset when the
## scene changes to the next arena.
var _advance_in_progress: bool = false
var _last_scene: Node = null
var _run_sync_accum: float = 0.0
const RUN_STATE_SYNC_INTERVAL: float = 2.0


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(delta: float) -> void:
	# Reset the stage-advance guard whenever the arena scene changes.
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var scene: Node = tree.current_scene
	if scene != _last_scene:
		_last_scene = scene
		_advance_in_progress = false
	# Only the host is authoritative for run state; broadcast periodically so
	# clients re-sync stage / difficulty / run timer.
	if not active() or not is_host:
		return
	_run_sync_accum += delta
	if _run_sync_accum >= RUN_STATE_SYNC_INTERVAL:
		_run_sync_accum = 0.0
		_broadcast_run_state()


## True while a live listen-server/client connection exists.
## NOTE: this must NOT be inferred from `multiplayer.multiplayer_peer`, because in
## a plain single-player run Godot still installs a default OfflineMultiplayerPeer
## (status CONNECTION_CONNECTED) — that would make every arena think co-op is live,
## hide the real player and spawn nothing ("invisible player, can't move"). We
## track an explicit flag set only when a real ENet host/join is created.
var _session_active: bool = false

func active() -> bool:
	return _session_active


## Host starts a listening server and becomes peer id 1. Returns OK on success.
func create_host(class_id: String) -> Error:
	my_class_id = class_id
	my_peer_id = 1
	is_host = true
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
	if err != OK:
		is_host = false
		return err
	multiplayer.multiplayer_peer = peer
	peer_classes = {1: class_id}
	_session_active = true
	return OK


## Client connects to a host at `ip`. Returns OK if the connection was started.
func join_game(ip: String, class_id: String) -> Error:
	my_class_id = class_id
	is_host = false
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(ip, DEFAULT_PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	peer_classes = {}
	_session_active = true
	return OK


## Tear down the connection (used when returning to the menu).
func leave() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	is_host = false
	peer_classes = {}
	_session_active = false


## Host: kick off the run once players are connected. Starts GameState on the
## first arena and tells every client to load the same arena scene. The run
## start (begin_run) is ALSO relayed, so every machine's GameState runs a real
## session (run_active, difficulty, stage, timer) — otherwise the client would
## load the arena but sit in a "no run" state and nothing would actually happen.
func host_start_run() -> void:
	print("[COOP] HOST starting run. roster=", peer_classes)
	begin_run_relayed.rpc(CATACOMBS_ARENA_PATH)
	load_arena.rpc()


## Every peer starts a real run on the shared arena path (host + clients).
@rpc("any_peer", "call_local", "reliable")
func begin_run_relayed(arena_path: String) -> void:
	print("[COOP] begin_run_relayed received. active=", active(), " arena=", arena_path)
	var gs: Node = get_node_or_null("/root/GameState")
	if gs and gs.has_method("begin_run"):
		gs.begin_run(arena_path)
		print("[COOP] begin_run executed. run_active=", gs.get("run_active"))


## Every peer (host + clients) loads the shared arena scene.
@rpc("any_peer", "call_local", "reliable")
func load_arena() -> void:
	print("[COOP] load_arena: changing scene to catacombs")
	get_tree().change_scene_to_file(CATACOMBS_ARENA_PATH)


# --- Run-state sync (host-authoritative) -------------------------------------
# Stage advancement and the run-level numeric state (stage, difficulty floor,
# run timer) are decided by the host and broadcast, so every machine picks the
# SAME next arena (no per-machine RNG desync) and shows the same run state.

## The player THIS machine owns (the one whose network authority matches the
## local peer). Used to capture the correct local snapshot when advancing — a
## co-op arena also contains other players' ghosts, so blindly taking the first
## "player"-group node could snapshot the wrong character.
func _local_player() -> Node:
	for p: Node in get_tree().get_nodes_in_group("player"):
		if p is CharacterBody2D and p.is_multiplayer_authority():
			return p
	return get_tree().get_first_node_in_group("player") as Node


func _local_xp_manager() -> Node:
	return get_tree().get_first_node_in_group("team_xp_manager") as Node


## Client: a player walked through the exit door — ask the host to advance.
@rpc("any_peer", "reliable")
func request_advance() -> void:
	if not is_host or _advance_in_progress:
		return
	_do_advance()


## Host: advance the authoritative run state, pick the next arena (the single
## RNG source for the whole group), and broadcast it so every machine loads the
## same room together. Guarded so both players reaching the door at once only
## advances a single stage.
func _do_advance() -> void:
	if _advance_in_progress:
		return
	_advance_in_progress = true
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		_advance_in_progress = false
		return
	var player: Node = _local_player()
	var xp_mgr: Node = _local_xp_manager()
	if gs.has_method("advance_stage"):
		gs.advance_stage(player, xp_mgr)
		advance_stage_relayed.rpc(int(gs.get("stage")), float(gs.get("min_difficulty")), str(gs.get("current_arena_path")))


## Every machine applies the host's chosen next stage and loads the same arena.
@rpc("any_peer", "call_local", "reliable")
func advance_stage_relayed(next_stage: int, next_min_difficulty: float, next_path: String) -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs:
		var player: Node = _local_player()
		var xp_mgr: Node = _local_xp_manager()
		if gs.has_method("apply_stage_advance"):
			gs.apply_stage_advance(player, xp_mgr, next_stage, next_min_difficulty, next_path)
	if not next_path.is_empty():
		get_tree().change_scene_to_file(next_path)


## Host periodically broadcasts the authoritative run state so a client that
## joins late or drifts snaps back to the same stage / difficulty / run timer.
func _broadcast_run_state() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		return
	sync_run_state.rpc(int(gs.get("stage")), float(gs.get("min_difficulty")), int(gs.get("run_started_at")))


@rpc("any_peer", "call_local", "reliable")
func sync_run_state(stage: int, min_difficulty: float, run_started_at: int) -> void:
	if is_host:
		return  # the host is the source of truth; don't apply to self
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		return
	gs.set("stage", stage)
	gs.set("min_difficulty", min_difficulty)
	gs.set("run_started_at", run_started_at)


# --- Player projectile visibility ---------------------------------------------
# Each machine simulates its OWN player locally, so a player's weapon projectiles
# only ever exist on the machine that fired them — the other player can't see
# them (their DAMAGE already reaches enemies via the host-authoritative enemy
# pipeline; only the visual is missing). When a weapon fires a travel projectile
# it calls sync_player_projectile(), which broadcasts a collision-disabled VISUAL
# copy to the other machine(s). The firing machine keeps its one real projectile
# (which deals damage using its own player's stats); the remote copies only
# render the travel and can never damage or interact.

## Weapon fired a local projectile: broadcast a visual copy to the other
## machine(s) so they can see it. Only travel projectiles (those with a `speed`
## and a `dir`/`direction`) are syncable; other effects are skipped.
func sync_player_projectile(proj: Node, scene: PackedScene) -> void:
	if not active() or proj == null or scene == null:
		return
	if not ("speed" in proj):
		return
	var dir: Variant = proj.get("dir") if ("dir" in proj) else (proj.get("direction") if ("direction" in proj) else Vector2.RIGHT)
	rpc("spawn_player_projectile_visual", {
		"scene": scene.resource_path,
		"pos": proj.global_position,
		"rotation": proj.rotation,
		"scale": proj.scale,
		"dir": dir,
		"speed": proj.speed,
	})


## Any machine -> the others: a player on another machine fired a projectile.
## Instantiate a collision-disabled visual copy here. The firing machine is
## excluded automatically (rpc() without call_local skips the sender), so it
## keeps its single real projectile.
@rpc("any_peer", "reliable")
func spawn_player_projectile_visual(data: Dictionary) -> void:
	var scene: PackedScene = load(str(data["scene"]))
	if scene == null:
		return
	var proj: Node = scene.instantiate()
	_make_visual_copy(proj)
	proj.global_position = data["pos"]
	proj.rotation = data["rotation"]
	proj.scale = data["scale"]
	proj.set("speed", data["speed"])
	for key: String in ["dir", "direction", "current_dir"]:
		if proj.has(key):
			proj.set(key, data["dir"])
	var current: Node = get_tree().current_scene
	if current:
		current.add_child(proj)


## A weapon spawned a local effect node (AoE / beam / ground telegraph) that
## renders without needing a weapon/player ref. Broadcast a visual-only copy to
## the other machine(s) so they can see it. `extra` carries the effect's render
## params (radius, fuse, polygon, direction...). The remote copy is made inert
## and configured through its setup_visual() method.
func sync_player_effect(effect: Node, scene: PackedScene, extra: Dictionary = {}) -> void:
	if not active() or effect == null or scene == null:
		return
	rpc("spawn_player_effect_visual", {
		"scene": scene.resource_path,
		"pos": effect.global_position,
		"rotation": effect.rotation,
		"scale": effect.scale,
		"extra": extra,
	})


## Any machine -> the others: a player on another machine spawned an effect.
## Instantiate an inert visual-only copy here (setup_visual configures it; the
## effect's own damage paths bail on the visual_copy meta).
@rpc("any_peer", "reliable")
func spawn_player_effect_visual(data: Dictionary) -> void:
	var scene: PackedScene = load(str(data["scene"]))
	if scene == null:
		return
	var effect: Node = scene.instantiate()
	_make_visual_copy(effect)
	effect.global_position = data["pos"]
	effect.rotation = data["rotation"]
	effect.scale = data["scale"]
	var extra: Dictionary = data.get("extra", {})
	if effect.has_method("setup_visual"):
		effect.call("setup_visual", extra)
	var current: Node = get_tree().current_scene
	if current:
		current.add_child(effect)


## Disable everything that lets a projectile deal damage or interact, turning it
## into a pure visual that only renders its travel.
func _make_visual_copy(node: Node) -> void:
	node.set("collision_layer", 0)
	node.set("collision_mask", 0)
	node.set("monitoring", false)
	node.set("monitorable", false)
	if node is Area2D:
		for child in node.get_children():
			if child is CollisionShape2D:
				child.set("disabled", true)
	# Marker so projectiles that deal damage outside of physics collision (e.g.
	# hitscan bolts, ground zones) can refuse to act on a remote visual copy.
	node.set_meta("visual_copy", true)


## Find a player node by its node name. Used by remote visual copies of effects
## that must follow/orbit a SPECIFIC player (a teammate's orbiting book or poison
## spray), which on this machine is that player's replica. Searches the "player"
## group by name because the replicas are nested under a "Players" container, so
## a bare current_scene path lookup would miss them.
static func find_player_by_name(node_name: String) -> Node:
	if node_name.is_empty():
		return null
	var tree: SceneTree = Engine.get_main_loop()
	if tree == null:
		return null
	for p: Node in tree.get_nodes_in_group("player"):
		if p.name == node_name:
			return p
	return null


## Client tells the host which class it picked, so the host knows how to spawn
## this peer's Player and can share the full roster with everyone.
func send_class_to_host() -> void:
	if is_host or not active():
		return
	register_class.rpc_id(1, my_class_id)


## Host records a client's class and rebroadcasts the full roster to everyone.
@rpc("any_peer", "reliable")
func register_class(cls: String) -> void:
	var from: int = multiplayer.get_remote_sender_id()
	peer_classes[from] = cls
	_sync_classes()


## Every peer stores the authoritative class roster.
@rpc("any_peer", "call_local", "reliable")
func sync_classes(roster: Dictionary) -> void:
	peer_classes = roster.duplicate()
	print("[COOP] roster synced: ", roster, " (my_peer=", my_peer_id, ")")
	classes_synced.emit()


func _sync_classes() -> void:
	sync_classes.rpc(peer_classes)


func _on_peer_connected(id: int) -> void:
	peer_connected.emit(id)


func _on_peer_disconnected(id: int) -> void:
	peer_classes.erase(id)
	peer_left.emit(id)


func _on_connected_to_server() -> void:
	my_peer_id = multiplayer.get_unique_id()
	peer_classes[my_peer_id] = my_class_id
	print("[COOP] client connected. my_peer=", my_peer_id, " local_class=", my_class_id, " roster=", peer_classes)
	connected_to_host.emit()
	send_class_to_host()


func _on_connection_failed() -> void:
	_session_active = false
	connection_failed_to_host.emit()


func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	is_host = false
	peer_classes = {}
	_session_active = false
	server_disconnected.emit()
