class_name HazardBase
extends Area2D

## A passive hazard in the arena (spikes, tar, etc.) that impairs the player and
## enemies that touch it. Subclasses configure the effect: damage over time,
## slow, or a mix. Detection is by collision mask (Player layer 2 + Enemies
## layer 3), so it reacts to both sides.

@export var damage_on_contact: int = 0
@export var damage_interval: float = 0.5
@export var slow_duration: float = 0.0
@export var slow_factor: float = 0.5

var _tick_timer: Timer

func _ready() -> void:
	add_to_group("hazards")
	collision_layer = 0  # passive — nothing needs to collide with the hazard itself
	collision_mask = 2 + 4  # Player (layer 2) + Enemies (layer 3 = value 4)
	monitoring = true

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_tick_timer = Timer.new()
	_tick_timer.wait_time = damage_interval
	_tick_timer.autostart = true
	_tick_timer.timeout.connect(_tick)
	add_child(_tick_timer)

func _on_body_entered(body: Node2D) -> void:
	_apply(body)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and slow_duration > 0.0 and body.has_method("clear_slow"):
		body.clear_slow()

# Re-apply to anything still standing on the hazard.
func _tick() -> void:
	for body in get_overlapping_bodies():
		_apply(body)

func _apply(body: Node2D) -> void:
	if not _is_valid_target(body):
		return
	if damage_on_contact > 0 and body.has_method("take_damage"):
		if body.is_in_group("player"):
			body.take_damage(damage_on_contact, self)
		else:
			body.take_damage(damage_on_contact)
	if slow_duration > 0.0 and body.has_method("apply_slow"):
		body.apply_slow(slow_duration, slow_factor)

func _is_valid_target(body: Node2D) -> bool:
	return body.is_in_group("player") or body.is_in_group("enemies")