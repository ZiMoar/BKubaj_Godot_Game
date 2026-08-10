class_name XPOrbSpatialManager
extends Node

@export var cell_size: float = 96.0

var _cells: Dictionary = {}
var _orb_cells: Dictionary = {}

func _ready() -> void:
	add_to_group("xp_orb_spatial_manager")

func register_orb(orb: XPOrb) -> void:
	if orb == null:
		return

	var orb_id = orb.get_instance_id()
	if _orb_cells.has(orb_id):
		return

	var cell = _world_to_cell(orb.global_position)
	_orb_cells[orb_id] = cell
	_add_to_cell(cell, orb)

func update_orb_cell(orb: XPOrb) -> void:
	if orb == null:
		return

	var orb_id = orb.get_instance_id()
	var new_cell = _world_to_cell(orb.global_position)

	if not _orb_cells.has(orb_id):
		_orb_cells[orb_id] = new_cell
		_add_to_cell(new_cell, orb)
		return

	var old_cell: Vector2i = _orb_cells[orb_id]
	if old_cell == new_cell:
		return

	_remove_from_cell(old_cell, orb)
	_orb_cells[orb_id] = new_cell
	_add_to_cell(new_cell, orb)

func unregister_orb(orb: XPOrb) -> void:
	if orb == null:
		return

	var orb_id = orb.get_instance_id()
	if not _orb_cells.has(orb_id):
		return

	var cell: Vector2i = _orb_cells[orb_id]
	_orb_cells.erase(orb_id)
	_remove_from_cell(cell, orb)

func find_nearest_merge_candidate(source_orb: XPOrb, radius: float) -> XPOrb:
	if source_orb == null:
		return null

	var safe_cell_size = maxf(1.0, cell_size)
	var center = _world_to_cell(source_orb.global_position)
	var cell_radius = ceili(radius / safe_cell_size)
	var nearest_orb: XPOrb = null
	var nearest_distance: float = radius

	for x in range(center.x - cell_radius, center.x + cell_radius + 1):
		for y in range(center.y - cell_radius, center.y + cell_radius + 1):
			var cell_key = Vector2i(x, y)
			if not _cells.has(cell_key):
				continue

			var bucket: Array = _cells[cell_key]
			for candidate in bucket:
				if candidate == source_orb:
					continue
				if not is_instance_valid(candidate):
					continue
				if candidate.is_being_collected or candidate.is_merging:
					continue
				if candidate.tier != source_orb.tier:
					continue

				var distance_to_candidate = source_orb.global_position.distance_to(candidate.global_position)
				if distance_to_candidate < nearest_distance:
					nearest_distance = distance_to_candidate
					nearest_orb = candidate

	return nearest_orb

func _world_to_cell(world_position: Vector2) -> Vector2i:
	var safe_cell_size = maxf(1.0, cell_size)
	return Vector2i(floori(world_position.x / safe_cell_size), floori(world_position.y / safe_cell_size))

func _add_to_cell(cell: Vector2i, orb: XPOrb) -> void:
	var bucket: Array = _cells.get(cell, [])
	bucket.append(orb)
	_cells[cell] = bucket

func _remove_from_cell(cell: Vector2i, orb: XPOrb) -> void:
	if not _cells.has(cell):
		return

	var bucket: Array = _cells[cell]
	var idx = bucket.find(orb)
	if idx != -1:
		bucket.remove_at(idx)

	if bucket.is_empty():
		_cells.erase(cell)
	else:
		_cells[cell] = bucket