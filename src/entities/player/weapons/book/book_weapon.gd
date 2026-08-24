extends Weapon

@export var book_scene: PackedScene
@export var book_count: int = 2

var active_books: Array[Area2D] = []

## Tome Volley: each book fires a bolt here on an interval.
var _volley_timer: float = 0.0
const TOME_VOLLEY_INTERVAL: float = 1.0
const TomeBoltScene: PackedScene = preload("res://src/entities/projectiles/magic_bolt/magic_bolt.tscn")


func _ready() -> void:
	weapon_name = "Orbiting Books"
	trigger_type = TriggerType.AUTOMATIC
	cooldown = 5.0
	damage_type = DamageType.Type.ARCANE
	super._ready()
	
	# Spawn books immediately on game load
	call_deferred("try_fire")

func supports_projectile_count() -> bool:
	return true


## Orbiting Books' signature upgrades (granted by the rare golden anvil).
func get_signature_pool() -> Array[Dictionary]:
	return [
		{
			"id": "tome_volley",
			"title": "Tome Volley",
			"description": "Books periodically fire a small arcane bolt at the nearest enemy.",
			"value": 1,
			"apply": func(_w: Weapon) -> void: pass,
		},
		{
			"id": "endless_spiral",
			"title": "Endless Spiral",
			"description": "Your books keep spiraling outward forever instead of stopping at their orbit.",
			"value": 1,
			"apply": func(_w: Weapon) -> void: pass,
		},
		{
			"id": "enlightened",
			"title": "Enlightened",
			"description": "Your books deal +3 damage per team level.",
			"value": 3,
			"apply": func(_w: Weapon) -> void: pass,
		},
	]

func _physics_process(delta: float) -> void:
	# 1. Clean out freed/destroyed book references
	active_books = active_books.filter(func(item): return is_instance_valid(item))
	
	# 2. Drive the orbit position for each surviving book
	var endless: bool = has_signature("endless_spiral")
	for proj in active_books:
		# Endless Spiral: keep growing the orbit target so books spiral out forever.
		if endless and is_instance_valid(proj):
			proj.target_radius += delta * 45.0
		if proj.has_method("update_orbit"):
			proj.update_orbit(delta, global_position)

	# 3. Tome Volley: while the signature is owned, each book periodically fires
	#    a small arcane shot at the nearest enemy.
	if has_signature("tome_volley"):
		_volley_timer -= delta
		if _volley_timer <= 0.0:
			_volley_timer = TOME_VOLLEY_INTERVAL
			_fire_tome_volleys()

func fire() -> void:
	if book_scene == null:
		print("ERROR: book_scene is null! Drag your book.tscn into the Book Weapon Inspector.")
		return
		
	var eff_count: int = get_effective_projectile_count(book_count)
	var angle_step = (2.0 * PI) / eff_count
	var attack_is_critical = roll_critical_hit()
	var attack_damage = get_attack_damage(14)
	# Enlightened: books gain +3 damage per team level.
	if has_signature("enlightened"):
		var mgr: Node = get_tree().get_first_node_in_group("team_xp_manager")
		if mgr:
			attack_damage += int(mgr.get("team_level")) * 3
	if attack_is_critical:
		attack_damage = int(round(float(attack_damage) * get_critical_multiplier()))
	
	for i in range(eff_count):
		var initial_angle = i * angle_step
		var spawned_book = book_scene.instantiate()
		
		# Add to the active level root so it isn't affected by player transforms
		get_tree().current_scene.add_child(spawned_book)
		
		if spawned_book.has_method("setup"):
			spawned_book.setup(initial_angle, global_position)
			spawned_book.damage = attack_damage
			spawned_book.is_critical = attack_is_critical
			spawned_book.source_player = get_player()
			spawned_book.source_weapon = self
			spawned_book.target_radius *= get_area_multiplier()
			spawned_book.scale *= get_area_multiplier()
			var _pl: Node = get_player()
			sync_effect(spawned_book, book_scene, {
				"angle": initial_angle,
				"target_radius": spawned_book.target_radius,
				"player_name": _pl.name if _pl else "",
			})

		active_books.append(spawned_book)


## Tome Volley: each orbiting book lobs a magic bolt at the nearest enemy.
func _fire_tome_volleys() -> void:
	if TomeBoltScene == null or active_books.is_empty():
		return
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	var eff_speed: float = get_effective_projectile_speed(340.0)
	var dmg: int = get_attack_damage(14)
	var crit: bool = roll_critical_hit()
	if crit:
		dmg = int(round(float(dmg) * get_critical_multiplier()))

	var nearest: Node2D = null
	var best_d: float = INF
	for e: Node in enemies:
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		var d: float = global_position.distance_squared_to(en.global_position)
		if d < best_d:
			best_d = d
			nearest = en
	if nearest == null:
		return

	for book: Area2D in active_books:
		if not is_instance_valid(book):
			continue
		var shot: Node = TomeBoltScene.instantiate()
		get_tree().current_scene.add_child(shot)
		sync_projectile(shot, TomeBoltScene)
		if shot.has_method("setup"):
			var to: Vector2 = (nearest.global_position - book.global_position).normalized()
			if to == Vector2.ZERO:
				to = Vector2.RIGHT
			shot.setup(book.global_position, to, eff_speed, dmg, crit, get_player(), self, 0)
