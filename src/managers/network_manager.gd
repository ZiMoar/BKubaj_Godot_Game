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


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


## True while a live listen-server/client connection exists.
func active() -> bool:
	return (multiplayer.has_multiplayer_peer()
		and multiplayer.multiplayer_peer != null
		and multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED)


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
	return OK


## Tear down the connection (used when returning to the menu).
func leave() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	is_host = false
	peer_classes = {}


## Host: kick off the run once players are connected. Starts GameState on the
## first arena and tells every client to load the same arena scene.
func host_start_run() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs and gs.has_method("begin_run"):
		gs.begin_run(CATACOMBS_ARENA_PATH)
	load_arena.rpc()


## Every peer (host + clients) loads the shared arena scene.
@rpc("any_peer", "call_local", "reliable")
func load_arena() -> void:
	get_tree().change_scene_to_file(CATACOMBS_ARENA_PATH)


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
	connected_to_host.emit()
	send_class_to_host()


func _on_connection_failed() -> void:
	connection_failed_to_host.emit()


func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	is_host = false
	peer_classes = {}
	server_disconnected.emit()
