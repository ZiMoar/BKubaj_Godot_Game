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
