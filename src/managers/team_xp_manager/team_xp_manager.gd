class_name TeamXPManager
extends Node

signal team_xp_changed(current_xp: int, xp_to_next_level: int)
signal team_leveled_up(new_level: int)

@export var team_level: int = 0
@export var current_xp: int = 0
@export var xp_to_next_level: int = 10
@export var xp_growth_factor: float = 1.3

func _ready() -> void:
	add_to_group("team_xp_manager")
	call_deferred("_emit_initial_signals")

func _emit_initial_signals() -> void:
	team_xp_changed.emit(current_xp, xp_to_next_level)

func add_xp(amount: int) -> void:
	var growth_bonus := 0.0
	var player = get_tree().get_first_node_in_group("player") as Node
	if player and player.has_method("get"):
		growth_bonus = maxf(0.0, float(player.get("growth_percent_bonus")))

	var applied_amount = int(round(float(amount) * (1.0 + growth_bonus)))
	current_xp += applied_amount
	print("Team gained ", applied_amount, " XP! Total XP: ", current_xp, "/", xp_to_next_level)
	
	while current_xp >= xp_to_next_level:
		current_xp -= xp_to_next_level
		team_level += 1
		xp_to_next_level = int(xp_to_next_level * xp_growth_factor)
		print("TEAM LEVEL UP! New Team Level: ", team_level, " Next level XP requirement: ", xp_to_next_level)
		team_leveled_up.emit(team_level)
		
	team_xp_changed.emit(current_xp, xp_to_next_level)


## Grants a team level immediately, regardless of the current XP cost. Used by
## the test map's "free level" field so level-ups can be triggered without XP.
func add_free_level() -> void:
	team_level += 1
	xp_to_next_level = int(xp_to_next_level * xp_growth_factor)
	print("FREE TEAM LEVEL UP! New Team Level: ", team_level, " Next: ", xp_to_next_level)
	team_leveled_up.emit(team_level)
	team_xp_changed.emit(current_xp, xp_to_next_level)


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
	team_xp_changed.emit(current_xp, xp_to_next_level)
