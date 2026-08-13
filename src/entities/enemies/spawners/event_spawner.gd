class_name Event
extends Node2D

## Base class for one-time stage events that trigger after a set amount of
## time has elapsed in the stage. Intended for spawner-like nodes that should
## happen only once per stage (e.g. a boss spawn). Subclasses override
## _trigger() to perform their action.

@export var trigger_time: float = 60.0
@export var is_active: bool = true
@export var destroy_after_trigger: bool = false

signal triggered

var has_triggered: bool = false
var _elapsed: float = 0.0


func _process(delta: float) -> void:
	if not is_active or has_triggered:
		return
	if get_tree().paused:
		return
	_elapsed += delta
	if _elapsed >= trigger_time:
		_do_trigger()


func _do_trigger() -> void:
	has_triggered = true
	triggered.emit()
	_trigger()
	if destroy_after_trigger:
		queue_free()


func get_elapsed() -> float:
	return _elapsed


func get_time_remaining() -> float:
	return maxf(0.0, trigger_time - _elapsed)


# Virtual — overridden by subclasses to perform the one-time event.
func _trigger() -> void:
	pass
