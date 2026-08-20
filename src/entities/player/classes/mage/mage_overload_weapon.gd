extends Weapon

const OverloadAuraVisualScene: PackedScene = preload("res://src/entities/player/classes/mage/overload_aura_visual.tscn")

## Mage secondary ability: Mana Overload. While active, every weapon's
## cooldowns are halved (player.cooldown_multiplier = 0.5). This ability's own
## recharge cooldown is unaffected: it only starts AFTER the buff ends.
@export var buff_duration: float = 4.0
@export var recharge: float = 8.0

var _buff_active: bool = false

var _elapsed: float = 0.0


func _ready() -> void:
	weapon_name = "Mana Overload"
	trigger_type = TriggerType.SECONDARY
	cooldown = recharge
	damage_type = DamageType.Type.ARCANE
	super._ready()
	var aura := get_node_or_null("OverloadAura")
	if aura:
		aura.visible = false


func _get_aura() -> Node2D:
	return get_node_or_null("OverloadAura") as Node2D


func _process(delta: float) -> void:
	var aura := _get_aura()
	if not _buff_active or aura == null:
		return
	_elapsed += delta
	# Pulse the aura: breathe the scale and alpha so the buff is clearly visible.
	var pulse: float = 0.5 + 0.5 * sin(_elapsed * 6.0)
	aura.scale = Vector2.ONE * (1.0 + 0.10 * pulse)
	if aura.get_node_or_null("Fill"):
		var fill := aura.get_node("Fill") as Polygon2D
		fill.color.a = 0.30 + 0.14 * pulse
	if aura.get_node_or_null("Ring"):
		var ring := aura.get_node("Ring") as Line2D
		ring.default_color.a = 0.85 + 0.15 * pulse


func try_fire() -> void:
	if not can_fire or _buff_active:
		return
	_activate()


func _activate() -> void:
	can_fire = false
	_buff_active = true
	_elapsed = 0.0
	var aura := _get_aura()
	if aura:
		aura.visible = true
	var p = get_player()
	if p and p.has_method("set_cooldown_multiplier"):
		p.set_cooldown_multiplier(0.5)
		p.overload_active = true

	# Co-op: broadcast a visual copy of the overload aura so a teammate sees the
	# buff around this player. The remote copy self-follows this player's replica
	# for buff_duration, then frees. Purely cosmetic.
	var net: Node = get_node_or_null("/root/Net")
	if net and net.has_method("sync_player_effect") and net.active() and p:
		var visual: Node2D = OverloadAuraVisualScene.instantiate()
		visual.global_position = global_position
		net.sync_player_effect(visual, OverloadAuraVisualScene, {
			"player_name": p.name,
			"life": buff_duration,
		})

	# Let the HUD show the full recharge as the "cooldown" bar.
	cooldown_started.emit(recharge)

	await get_tree().create_timer(buff_duration).timeout
	if not is_instance_valid(self):
		return

	_buff_active = false
	if aura and is_instance_valid(aura):
		aura.visible = false
	if is_instance_valid(p) and p.has_method("set_cooldown_multiplier"):
		p.set_cooldown_multiplier(1.0)
		p.overload_active = false

	# Recharge begins only after the buff ends, using the full cooldown
	# (not affected by the buff, since the multiplier is back to 1.0).
	if cooldown_timer:
		cooldown_timer.start(recharge)
