class_name Spikes
extends HazardBase

## A patch of floor spikes. Damage hazard — hurts anything (player or enemies)
## standing on it on a cooldown.

@export var radius: float = 10.0
@export var spike_color: Color = Color(0.75, 0.78, 0.82)

func _ready() -> void:
	damage_on_contact = 6
	damage_interval = 0.5
	super._ready()

func _draw() -> void:
	# Base plate
	draw_circle(Vector2.ZERO, radius, Color(0.3, 0.31, 0.35))
	# Four spikes pointing up-card (drawn as triangles)
	var count := 4
	for i in range(count):
		var a := TAU * float(i) / float(count)
		var tip := Vector2(cos(a), sin(a)) * (radius - 1.0)
		var perp := Vector2(-tip.y, tip.x).normalized()
		var base_w := radius * 0.35
		var p1 := tip * 0.15 + perp * base_w
		var p2 := tip * 0.15 - perp * base_w
		draw_colored_polygon(PackedVector2Array([Vector2.ZERO, p1, tip]),
			spike_color.lightened(0.2))
		draw_colored_polygon(PackedVector2Array([Vector2.ZERO, tip, p2]),
			spike_color.darkened(0.15))