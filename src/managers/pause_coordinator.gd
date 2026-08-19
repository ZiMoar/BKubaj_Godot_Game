class_name PauseCoordinator
extends Node

## Coordinated pause (autoload "PauseCoord").
##
## In single-player this is just a plain pause: begin_block() pauses the machine,
## end_block() unpauses once every open block is gone.
##
## In co-op, the HOST is authoritative for the GLOBAL pause state:
##   - ANY player opening a blocking UI (esc, level-up, anvil, boots, relic,
##     weapon choice, stats) pauses EVERYONE (rule: any player pauses all).
##   - The game only unpauses once ALL players have closed their blocking UIs.
##   - Opening your own menu pauses you instantly (no network round-trip delay);
##     closing never unpauses you by itself — you wait for the host to confirm
##     everyone is done.
##
## Every machine tracks its own open-block count; it reports the count to the
## host, which sums the per-peer counts and broadcasts the authoritative pause
## state back to everyone.

signal pause_changed(paused: bool)
## Emitted when THIS machine's "waiting" state changes: true while the game is
## paused by someone ELSE (all local UIs closed, but another player still has a
## menu open), false once everyone is done.
signal waiting_changed(waiting: bool)

## Number of blocking UIs currently open on THIS machine.
var _local_blocks: int = 0
var _paused: bool = false
var _waiting_cached: bool = false

## Host-side: peer id -> open-block count.
var _peer_blocks: Dictionary = {}

var _last_scene: Node = null

## Millisecond timestamp of the last begin/end_block activity. Used by the leak
## watchdog so it only clears blocks that have been static for a long time.
var _last_block_activity_ms: int = 0

## Stack origins (caller function/file/line) of every begin_block currently open,
## in open order. When the leak watchdog fires we dump these so the exact menu
## whose end_block() never ran is identifiable from the log.
var _block_sources: Array[Dictionary] = []

## Safety net against a permanently-frozen game: if the game stays paused with
## NO blocking UI visible for this long, a blocking menu was destroyed without
## its matching end_block() (a leaked block). Clear the stale blocks and unpause
## so the run isn't soft-locked forever.
const LEAK_RESET_MS: int = 8000


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _process(_delta: float) -> void:
	# A scene change means a fresh context (menu / new arena) that starts
	# unpaused with a brand-new HUD. Drop any stale block state so a leaked block
	# from a destroyed menu can't leave the game permanently frozen.
	var cs: Node = get_tree().current_scene
	if cs != _last_scene:
		_last_scene = cs
		_reset_for_new_scene()
	# Leak watchdog: if we are paused but NO blocking UI is actually on screen,
	# a menu was destroyed without its end_block() and the block can never be
	# released on its own -> soft-lock. After a grace period, clear it so the
	# game recovers instead of freezing forever. Safe: while a blocking menu is
	# visible (ESC pause, relic, level-up, etc.) this never fires.
	if _local_blocks > 0 and _paused and not _any_blocking_ui_visible():
		if Time.get_ticks_msec() - _last_block_activity_ms > LEAK_RESET_MS:
			push_warning("PauseCoord: leaked pause block detected (%d open) with no blocking UI visible — auto-unpausing. Unmatched begin_block() sources: %s" % [_local_blocks, str(_block_sources)])
			_block_sources.clear()
			_local_blocks = 0
			_report_local_to_host()


## Open a blocking UI on THIS machine. Pauses locally immediately, then tells the
## host so everyone else pauses too.
func begin_block() -> void:
	_local_blocks += 1
	_last_block_activity_ms = Time.get_ticks_msec()
	var st: Array = get_stack()
	if _block_sources.size() < 64 and st.size() > 1:
		_block_sources.append({
			"caller": str(st[1].get("function", "?")),
			"file": str(st[1].get("source", "?")),
			"line": int(st[1].get("line", -1)),
		})
	_report_local_to_host()
	# Immediate local pause for responsiveness (authoritative state may lag).
	if _local_blocks == 1:
		_set_paused(true)
	_notify_waiting()


## Close a blocking UI on THIS machine. Never unpauses by itself: it reports the
## new count and waits for the host to confirm ALL players are done.
func end_block() -> void:
	if _local_blocks <= 0:
		return
	_local_blocks -= 1
	_last_block_activity_ms = Time.get_ticks_msec()
	if not _block_sources.is_empty():
		_block_sources.pop_back()
	_report_local_to_host()
	_notify_waiting()


## True while any blocking UI is currently visible. Menus that pause the game
## add themselves to the "blocking_ui" group so the leak watchdog can tell a
## legitimate (visible) pause apart from a leaked block with nothing on screen.
func _any_blocking_ui_visible() -> bool:
	if not is_inside_tree():
		return false
	for node: Node in get_tree().get_nodes_in_group("blocking_ui"):
		var control: Control = node as Control
		if control != null and control.visible:
			return true
	return false


func is_paused() -> bool:
	return _paused


## True while this machine has all its own menus closed but the game is still
## paused because another player has a menu open (i.e. we are waiting on them).
func is_waiting() -> bool:
	return _paused and _local_blocks == 0


func _notify_waiting() -> void:
	var w: bool = is_waiting()
	if w != _waiting_cached:
		_waiting_cached = w
		waiting_changed.emit(w)


## Discard all block state (used on scene transitions). Clients re-report their
## (now zero) count so the host doesn't keep everyone paused for a stale block.
func reset() -> void:
	_local_blocks = 0
	if multiplayer.is_server():
		_peer_blocks.clear()
	_report_local_to_host()


func _reset_for_new_scene() -> void:
	_local_blocks = 0
	# Report the (now zero) count so the host drops this machine's stale block —
	# otherwise everyone would stay frozen waiting on a menu that no longer exists.
	_report_local_to_host()


func _report_local_to_host() -> void:
	var net: Node = get_node_or_null("/root/Net")
	if net == null or not net.active():
		_recompute()  # single-player: resolve locally
		return
	if multiplayer.is_server():
		_peer_blocks[1] = _local_blocks
		_recompute()
	else:
		report_blocks.rpc_id(1, _local_blocks)


## Host-side: apply the current global pause state and broadcast it to clients.
func _recompute() -> void:
	if not multiplayer.is_server():
		return
	var any_blocked := false
	for id: int in _peer_blocks:
		if int(_peer_blocks[id]) > 0:
			any_blocked = true
			break
	_apply_authoritative(any_blocked)
	sync_pause.rpc(any_blocked)


## A machine with any of its own blocks open can never be unpaused (protects
## against a stale "clear" from the host racing a just-opened local menu).
func _apply_authoritative(paused: bool) -> void:
	_set_paused(paused or _local_blocks > 0)


func _set_paused(p: bool) -> void:
	if _paused == p:
		return
	_paused = p
	get_tree().paused = p
	pause_changed.emit(p)
	_notify_waiting()


## Client -> host: this machine's open-block count changed.
@rpc("any_peer", "reliable")
func report_blocks(count: int) -> void:
	if not multiplayer.is_server():
		return
	var from: int = multiplayer.get_remote_sender_id()
	_peer_blocks[from] = maxi(0, int(count))
	_recompute()


## Host -> clients: authoritative global pause state.
@rpc("any_peer", "call_local", "reliable")
func sync_pause(paused: bool) -> void:
	if multiplayer.is_server():
		return  # host already applied it in _recompute
	_apply_authoritative(paused)


func _on_peer_disconnected(id: int) -> void:
	_peer_blocks.erase(id)
	if multiplayer.is_server():
		_recompute()
