class_name StageController
extends Node

## Drives the stage-completion flow for an arena.
##
## 1. When the boss spawns, remember that it did.
## 2. When the boss dies, the room is "cleared": kill every remaining enemy
##    WITHOUT dropping loot, then sweep up gold + XP orbs still on the floor.
## 3. Once all drops are collected, open the exit door at the top wall.
## 4. When the player walks through the open door, advance the run (capture the
##    player's progression), load the alternate arena as the next stage.
##
## This node is placed in each arena scene and wired to that arena's StageDoor.

@export_node_path("Node2D") var door_path: NodePath
@export var completion_delay: float = 0.5

var _boss_ever_alive: bool = false
var _completing: bool = false
var _completed: bool = false
var _door: Node2D = null


func _ready() -> void:
	# Detect the boss spawn so we know when the room "has a boss".
	var spawner: Node = get_tree().get_first_node_in_group("boss_spawner")
	if spawner == null:
		# Fallback: BossSpawner isn't in a group by default — find by scanning.
		spawner = _find_boss_spawner()
	if spawner and spawner.has_signal("triggered") and not spawner.triggered.is_connected(_on_boss_spawned):
		spawner.triggered.connect(_on_boss_spawned)

	if door_path and not door_path.is_empty():
		_door = get_node_or_null(door_path) as Node2D


func _find_boss_spawner() -> Node:
	var parent: Node = get_parent()
	if parent:
		for child in parent.get_children():
			if child.name == "BossSpawner":
				return child
	return null


func _on_boss_spawned() -> void:
	_boss_ever_alive = true


func _process(_delta: float) -> void:
	if _completing or _completed:
		return
	if not _boss_ever_alive:
		return
	# Boss was spawned and is now gone -> it died. Start room completion.
	if get_tree().get_nodes_in_group("bosses").is_empty():
		_completing = true
		call_deferred("_begin_completion")


func _begin_completion() -> void:
	# Stop all spawners so no new enemies appear during clean-up / door phase.
	_pause_all_spawners()
	# Kill all remaining enemies without dropping loot.
	var enemies: Array = get_tree().get_nodes_in_group("enemies").duplicate()
	for e: Node in enemies:
		if is_instance_valid(e) and e.has_method("die_without_drop"):
			e.die_without_drop()
		elif is_instance_valid(e) and e.has_method("die"):
			e.die()
	# Defuse any armed bombers so they don't explode on the player during clean-up.
	for b: Node in get_tree().get_nodes_in_group("bombers"):
		if is_instance_valid(b) and b.has_method("queue_free"):
			b.queue_free()
	# Sweep up every drop still on the floor toward the player.
	_start_drop_sweep()


## Stops every enemy spawner in the room so nothing new spawns once the boss is
## dead and the stage is considered cleared.
func _pause_all_spawners() -> void:
	for s: Node in get_tree().get_nodes_in_group("regular_spawner"):
		if is_instance_valid(s):
			s.set("is_spawning", false)
			if s.has_method("set_suppressed"):
				s.set_suppressed(true, 1.0)
			var t: Node = s.get_node_or_null("Timer") if s.has_node("Timer") else null
			if t is Timer:
				t.stop()
	# Also stop the boss spawner (Event) so it can't re-trigger during clean-up.
	for b: Node in get_tree().get_nodes_in_group("boss_spawner"):
		if is_instance_valid(b):
			b.set("is_active", false)


func _start_drop_sweep() -> void:
	# Small delay so foes finishing their die() animations don't drop more loot.
	await get_tree().create_timer(completion_delay).timeout
	if not is_instance_valid(self):
		return
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var any: bool = false
	for orb in get_tree().get_nodes_in_group("xp_orbs"):
		if is_instance_valid(orb) and orb.has_method("start_attraction"):
			orb.start_attraction(player)
			any = true
	for coin in get_tree().get_nodes_in_group("gold_pickups"):
		if is_instance_valid(coin) and coin.has_method("start_attraction"):
			coin.start_attraction(player)
			any = true
	if not any:
		_open_door()
	else:
		# Wait until every drop has been collected (freed) before opening.
		await _wait_for_drops_collected()
		if is_instance_valid(self):
			_open_door()


func _wait_for_drops_collected() -> void:
	while true:
		var remaining: int = 0
		for orb in get_tree().get_nodes_in_group("xp_orbs"):
			if is_instance_valid(orb):
				remaining += 1
		for coin in get_tree().get_nodes_in_group("gold_pickups"):
			if is_instance_valid(coin):
				remaining += 1
		if remaining <= 0 or not is_instance_valid(self):
			return
		await get_tree().create_timer(0.1).timeout


func _open_door() -> void:
	if _completed:
		return
	_completed = true
	if _door and _door.has_method("open_door"):
		_door.open_door()
