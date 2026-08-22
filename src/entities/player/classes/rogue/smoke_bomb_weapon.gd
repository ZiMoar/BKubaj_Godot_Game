extends Weapon

## Rogue secondary ability: Smoke Bomb. For its duration the rogue gains a FLAT
## +25% dodge chance on top of their evasion. Because dodge chance is additive
## with evasion (Ghost Step already stacks the same way), investing enough in
## evasion can push dodge to the cap — effectively guaranteed dodges while the
## cloud lasts.

const SmokeCloudScene: PackedScene = preload("res://src/effects/smoke_cloud/smoke_cloud.tscn")

@export var dodge_bonus: float = 0.25
@export var duration: float = 4.0


func _ready() -> void:
	weapon_name = "Smoke Bomb"
	trigger_type = TriggerType.SECONDARY
	cooldown = 10.0
	super._ready()


func get_signature_pool() -> Array[Dictionary]:
	# This is an ability (secondary), not selectable in the anvil — no signatures.
	return []


func fire() -> void:
	var p := get_player()
	if p == null:
		return
	if p.has_method("set_smoke_bomb"):
		p.set_smoke_bomb(dodge_bonus, duration)
	# Visual: a smoke cloud hugging the player for the buff's duration.
	var cloud: Node2D = SmokeCloudScene.instantiate()
	cloud.name = "SmokeCloud"
	p.add_child(cloud)
	cloud.position = Vector2.ZERO
	if cloud.has_method("setup"):
		cloud.setup(duration, has_signature("toxic_cloud"))
