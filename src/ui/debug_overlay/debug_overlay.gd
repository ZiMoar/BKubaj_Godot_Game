extends Node
## On-screen developer/console overlay (autoload "DebugOverlay").
##
## Toggle with F3 (registered at runtime, so it never collides with the input
## map). Shows three live diagnostics:
##   - FPS and milliseconds per frame
##   - Co-op network round-trip delay (ms) to every connected peer (ENet)
##   - Counts of enemies / projectiles / pickups currently on screen
##
## Because it is an autoload it works in every scene — menus, arenas, co-op.

const REFRESH_INTERVAL := 0.25   # seconds between text refreshes (cheap)

var _label: Label
var _visible_on := false
var _accum := 0.0


func _ready() -> void:
	_register_hotkey()
	var layer := CanvasLayer.new()
	layer.layer = 100   # above the HUD
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.25, 1.0, 0.6))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 4)
	_label.position = Vector2(8, 34)   # just below the HUD's top bar
	_label.visible = false
	root.add_child(_label)


func _register_hotkey() -> void:
	if InputMap.has_action("debug_overlay"):
		return
	InputMap.add_action("debug_overlay")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_F3
	InputMap.action_add_event("debug_overlay", ev)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("debug_overlay"):
		_visible_on = not _visible_on
		_label.visible = _visible_on
	if not _visible_on:
		return
	_accum += delta
	if _accum >= REFRESH_INTERVAL:
		_accum = 0.0
		_label.text = _build_text()
		_label.reset_size()


func _build_text() -> String:
	var fps: float = Performance.get_monitor(Performance.TIME_FPS)
	var frametime: float = 1000.0 / maxf(1.0, fps)
	var lines: Array[String] = [
		"FPS: %d   (%.2f ms/frame)" % [int(fps), frametime],
		_net_line(),
		_entity_line(),
	]
	return "\n".join(lines)


## --- Co-op delay ------------------------------------------------------------

func _net_line() -> String:
	if not multiplayer.has_multiplayer_peer():
		return "NET: offline (single-player)"
	var mp: MultiplayerPeer = multiplayer.multiplayer_peer
	if not (mp is ENetMultiplayerPeer):
		return "NET: non-ENet peer (%s)" % mp.get_class()
	var connected: Array = multiplayer.get_network_connected_peers()
	if connected.is_empty():
		return "NET: host, no clients connected"
	var parts: Array[String] = []
	for id: int in connected:
		parts.append("peer %d: %.1f ms" % [id, _rtt_ms(id)])
	var role := "host" if multiplayer.is_server() else "client"
	return "NET (%s, me=%d): %s" % [role, multiplayer.get_unique_id(), ", ".join(parts)]


## Round-trip time in ms to `peer_id` via ENet's measured statistic.
func _rtt_ms(peer_id: int) -> float:
	var ep: Object = multiplayer.multiplayer_peer.get_peer(peer_id)
	if ep == null or not ep.has_method("get_statistic"):
		return -1.0
	return float(ep.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))


## --- Entity counts ----------------------------------------------------------

func _entity_line() -> String:
	var cam: Camera2D = get_viewport().get_camera_2d()
	var counts := _count_entities(cam)
	var players: int = get_tree().get_nodes_in_group("player").size()
	return "ENT: %d enemies | %d projectiles | %d pickups | %d players" % [
		counts["enemies"], counts["projectiles"], counts["pickups"], players,
	]


func _count_entities(cam: Camera2D) -> Dictionary:
	var counts := {"enemies": 0, "projectiles": 0, "pickups": 0}
	var rect := _visible_rect(cam)
	var root: Node = get_tree().current_scene
	if root != null:
		_count_node(root, rect, counts)
	return counts


func _count_node(node: Node, rect: Rect2, counts: Dictionary) -> void:
	for child: Node in node.get_children():
		_count_node(child, rect, counts)
	if not node is Node2D:
		return
	if not rect.has_point((node as Node2D).global_position):
		return  # off-screen: ignore
	if node.is_in_group("enemies") or node.is_in_group("flying_enemies"):
		counts["enemies"] += 1
	elif (node.is_in_group("xp_orbs") or node.is_in_group("gold_pickups")
			or node.is_in_group("soul_pickups") or node.is_in_group("pickups")):
		counts["pickups"] += 1
	elif ("source_weapon" in node) or ("source_player" in node):
		# Projectiles don't share a group; they do all carry a source_* property.
		counts["projectiles"] += 1


## The camera's visible world rectangle (accounts for zoom).
func _visible_rect(cam: Camera2D) -> Rect2:
	if cam == null or not is_instance_valid(cam):
		return Rect2(Vector2(-1e9, -1e9), Vector2(2e9, 2e9))
	var size: Vector2 = get_viewport().get_visible_rect().size / cam.zoom
	var center: Vector2 = cam.get_screen_center_position()
	return Rect2(center - size * 0.5, size)
