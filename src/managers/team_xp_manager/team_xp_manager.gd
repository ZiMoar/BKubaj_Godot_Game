class_name TeamXPManager
extends Node

signal team_xp_changed(current_xp: int, xp_to_next_level: int)
signal team_leveled_up(new_level: int)

@export var team_level: int = 0
@export var current_xp: int = 0
@export var xp_to_next_level: int = 10
@export var xp_growth_factor: float = 1.3

## Highest team level this machine has applied from the authoritative stream.
## Used on clients to detect a new level-up so the HUD opens the stat menu.
var _synced_level: int = 0

func _ready() -> void:
	add_to_group("team_xp_manager")
	call_deferred("_emit_initial_signals")

func _emit_initial_signals() -> void:
	team_xp_changed.emit(current_xp, xp_to_next_level)

func _is_coop() -> bool:
	var net: Node = get_node_or_null("/root/Net")
	return net != null and net.active()


func _is_network_client() -> bool:
	return _is_coop() and not multiplayer.is_server()


## Adds XP. Growth/Avarice are applied on THIS machine (using its own player's
## build), then the converted amount feeds the shared pool. On a client the
## amount is forwarded to the host; the host is the only accumulator and pushes
## the resulting authoritative state back to every machine.
func add_xp(amount: int) -> void:
	var applied_amount: int = _apply_player_modifiers(amount)
	if _is_network_client():
		report_xp.rpc_id(1, applied_amount)
		return
	_accumulate(applied_amount)


## Growth / Avarice modifiers, applied on the machine that collected the orb so
## each player's own build shapes their contribution.
func _apply_player_modifiers(amount: int) -> int:
	var growth_bonus := 0.0
	var player = get_tree().get_first_node_in_group("player") as Node
	if player and player.has_method("get"):
		growth_bonus = maxf(0.0, float(player.get("growth_percent_bonus")))

	var applied_amount := int(round(float(amount) * (1.0 + growth_bonus)))
	return applied_amount


## The single authoritative accumulator (host in co-op, local in single-player).
func _accumulate(applied_amount: int) -> void:
	current_xp += applied_amount
	print("Team gained ", applied_amount, " XP! Total XP: ", current_xp, "/", xp_to_next_level)

	while current_xp >= xp_to_next_level:
		current_xp -= xp_to_next_level
		team_level += 1
		xp_to_next_level = int(xp_to_next_level * xp_growth_factor)
		print("TEAM LEVEL UP! New Team Level: ", team_level, " Next level XP requirement: ", xp_to_next_level)
		team_leveled_up.emit(team_level)

	team_xp_changed.emit(current_xp, xp_to_next_level)
	if _is_coop() and multiplayer.is_server():
		_sync_state_to_clients()


## Client -> host: a client collected XP; the host folds it into the shared pool.
@rpc("any_peer", "reliable")
func report_xp(applied_amount: int) -> void:
	if not _is_coop() or not multiplayer.is_server():
		return
	_accumulate(applied_amount)


## Host -> clients: authoritative team XP state. Clients apply it verbatim and
## fire a level-up if the team crossed into a new level.
@rpc("any_peer", "reliable")
func sync_team_xp(lvl: int, xp: int, next: int) -> void:
	if multiplayer.is_server():
		return  # the host already holds the authoritative state
	team_level = lvl
	current_xp = xp
	xp_to_next_level = next
	if lvl > _synced_level:
		_synced_level = lvl
		team_leveled_up.emit(lvl)
	team_xp_changed.emit(current_xp, xp_to_next_level)


func _sync_state_to_clients() -> void:
	rpc("sync_team_xp", team_level, current_xp, xp_to_next_level)


## Grants a team level immediately, regardless of the current XP cost. Used by
## the test map's "free level" field so level-ups can be triggered without XP.
func add_free_level() -> void:
	if _is_network_client():
		free_level.rpc_id(1)
		return
	_apply_free_level()


@rpc("any_peer", "reliable")
func free_level() -> void:
	if not _is_coop() or not multiplayer.is_server():
		return
	_apply_free_level()


func _apply_free_level() -> void:
	team_level += 1
	xp_to_next_level = int(xp_to_next_level * xp_growth_factor)
	print("FREE TEAM LEVEL UP! New Team Level: ", team_level, " Next: ", xp_to_next_level)
	team_leveled_up.emit(team_level)
	team_xp_changed.emit(current_xp, xp_to_next_level)
	if _is_coop() and multiplayer.is_server():
		_sync_state_to_clients()


func capture_xp_state() -> Dictionary:
	return {
		"team_level": team_level,
		"current_xp": current_xp,
		"xp_to_next_level": xp_to_next_level,
		"xp_growth_factor": xp_growth_factor,
	}


func restore_xp_state(snap: Dictionary) -> void:
	team_level = int(snap.get("team_level", 0))
	current_xp = int(snap.get("current_xp", 0))
	xp_to_next_level = int(snap.get("xp_to_next_level", 10))
	xp_growth_factor = float(snap.get("xp_growth_factor", 1.3))
	_synced_level = team_level
	team_xp_changed.emit(current_xp, xp_to_next_level)
