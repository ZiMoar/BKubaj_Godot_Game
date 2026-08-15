extends Node2D

## Procedural "Catacombs" background drawn with Godot's simple _draw() primitives.
## Keeps the grid_background.gd public interface (arena_center / arena_size) so the
## gameplay code (stage door placement, HUD) finds the floor exactly as before —
## only the look changes from a technical grid to a dim stone crypt.
##
## The whole scene is drawn once and cached by Godot, so the many rects here cost
## nothing per frame after the first draw.

## Center of the arena floor (mirrors GridBackground for gameplay compatibility).
@export var arena_center: Vector2 = Vector2(960, 540)
@export var arena_size: Vector2 = Vector2(1920, 1080)

## Stone flag size in pixels (each flag is approx this big).
@export var flag_size: float = 64.0
## Thickness of the masonry wall ring drawn around the arena perimeter.
@export var wall_thickness: float = 150.0

var _rng: RandomNumberGenerator

# Palettes tuned to a cold, dim dungeon so they sit well under the dark UI/HUD.
const FLOOR_BASE := Color(0.095, 0.105, 0.135)
const MORTAR := Color(0.05, 0.06, 0.085)
const WALL_STONE := Color(0.15, 0.16, 0.19)
const WALL_DARK := Color(0.105, 0.115, 0.14)
const WALL_EDGE := Color(0.34, 0.36, 0.44)
const BONE := Color(0.78, 0.78, 0.72)
const BONE_SHADE := Color(0.5, 0.5, 0.46)
const TOMB := Color(0.52, 0.53, 0.57)
const TOMB_DARK := Color(0.34, 0.35, 0.39)


func _draw() -> void:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.seed = 20240815  # fixed seed so the crypt is stable (no flicker)

	var tl := arena_center - arena_size * 0.5

	# Base dark fill the size of the arena.
	draw_rect(Rect2(tl, arena_size), FLOOR_BASE)

	_draw_flagstone_floor(tl, arena_size)
	_draw_wall_ring(tl, arena_size)
	_draw_scattered_props(tl, arena_size)


## Worn flagstone floor: a grid of jittered-width, slightly-shaded stone flags
## separated by thin dark mortar seams, with a few cracks for texture.
func _draw_flagstone_floor(tl: Vector2, size: Vector2) -> void:
	var rows := int(size.y / flag_size) + 1
	for r in range(rows):
		var y := tl.y + r * flag_size
		if y > tl.y + size.y:
			break
		var x := tl.x
		var row_seed := r * 73856093
		while x < tl.x + size.x:
			var w: float = flag_size * (0.72 + ((row_seed + int(x)) & 3) * 0.09)
			w = minf(w, tl.x + size.x - x)
			var shade := 0.15 + ((row_seed + int(x * 0.5)) % 9) * 0.011
			var c := Color(shade * 0.9, shade * 0.95, shade + 0.035)
			draw_rect(Rect2(x + 1.0, y + 1.0, w - 2.0, flag_size - 2.0), c)
			# Occasional crack: a short dark diagonal inside the flag.
			if ((row_seed + int(x)) % 13) == 0:
				draw_line(Vector2(x + 4, y + 6), Vector2(x + 10, y + 13), MORTAR, 1.0)
			x += w


## Masonry wall ring around the perimeter: two stacked rows of dark stone blocks
## with an inner highlight so it reads as a crypt enclosure.
func _draw_wall_ring(tl: Vector2, size: Vector2) -> void:
	var blocks := 96.0
	var i := 0
	# Top band
	_draw_band(Rect2(tl.x, tl.y, size.x, wall_thickness), blocks, i)
	i += 1
	# Bottom band
	_draw_band(Rect2(tl.x, tl.y + size.y - wall_thickness, size.x, wall_thickness), blocks, i)
	i += 1
	# Left band
	_draw_band(Rect2(tl.x, tl.y + wall_thickness, wall_thickness, size.y - wall_thickness * 2.0), blocks, i)
	i += 1
	# Right band
	_draw_band(Rect2(tl.x + size.x - wall_thickness, tl.y + wall_thickness, wall_thickness, size.y - wall_thickness * 2.0), blocks, i)


func _draw_band(rect: Rect2, blocks: float, seed_off: int) -> void:
	draw_rect(rect, WALL_DARK)
	# Horizontal masonry seams.
	var n := int(rect.size.y / blocks)
	for k in range(1, n):
		var yy := rect.position.y + k * blocks
		draw_line(Vector2(rect.position.x, yy), Vector2(rect.end.x, yy), MORTAR, 2.0)
	# Vertical brick divisions (staggered) + a skull engraving every few bricks.
	var m := int(rect.size.x / blocks)
	for k in range(m + 1):
		var xx := rect.position.x + k * blocks
		var off: float = (blocks * 0.5) if ((k + seed_off) % 2 == 0) else 0.0
		for row in range(n):
			var yy := rect.position.y + row * blocks + off
			draw_line(Vector2(xx, yy), Vector2(xx, yy + blocks), MORTAR, 2.0)
		if ((k + seed_off) % 3) == 0 and n >= 1:
			_draw_skull(Vector2(xx + blocks * 0.5, rect.position.y + blocks * 0.5), blocks * 0.3)
	# Inner highlight so the wall clearly borders the floor.
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3.0)), WALL_EDGE)


## A tiny bone-coloured skull (two dark eye sockets + a jaw) used on walls.
func _draw_skull(pos: Vector2, r: float) -> void:
	draw_circle(pos, r, BONE)
	draw_circle(pos + Vector2(-r * 0.4, -r * 0.15), r * 0.22, WALL_DARK)
	draw_circle(pos + Vector2(r * 0.4, -r * 0.15), r * 0.22, WALL_DARK)
	draw_rect(Rect2(pos - Vector2(r * 0.2, 0), Vector2(r * 0.4, r * 0.28)), WALL_DARK)


## Scatters tombstones and bone piles across the whole floor (along the wall ring
## and through the central fighting area), so the crypt reads clearly wherever the
## player is. Purely cosmetic, no collision — kept off the exact spawn point.
func _draw_scattered_props(tl: Vector2, size: Vector2) -> void:
	# Fractional positions (of arena size) — alternate tombstone / bone pile.
	var spots: Array = [
		Vector2(0.18, 0.10), Vector2(0.78, 0.88),
		Vector2(0.10, 0.30), Vector2(0.90, 0.62),
		Vector2(0.90, 0.34), Vector2(0.12, 0.70),
		# Central band (visible inside the 640x360 camera around the player spawn).
		Vector2(0.42, 0.38), Vector2(0.58, 0.62),
		Vector2(0.55, 0.36), Vector2(0.40, 0.66),
		Vector2(0.50, 0.30), Vector2(0.48, 0.70),
		Vector2(0.36, 0.52), Vector2(0.64, 0.48),
		Vector2(0.30, 0.22), Vector2(0.22, 0.82),
		Vector2(0.72, 0.20), Vector2(0.80, 0.55),
	]
	for s in range(spots.size()):
		var f: Vector2 = spots[s]
		var p := Vector2(tl.x + size.x * f.x, tl.y + size.y * f.y)
		if s % 2 == 0:
			_draw_tombstone(p)
		else:
			_draw_bones(p)


func _draw_tombstone(p: Vector2) -> void:
	var w := 36.0
	var h := 32.0
	draw_rect(Rect2(p - Vector2(w * 0.5, 0), Vector2(w, h)), TOMB)
	draw_arc(p + Vector2(0, 0), w * 0.5, PI, TAU, 12, TOMB_DARK, 4.0)
	draw_rect(Rect2(p - Vector2(4, h * 0.4), Vector2(8, h * 0.5)), TOMB_DARK)


func _draw_bones(p: Vector2) -> void:
	# Two crossed bone shafts + knuckles.
	draw_line(p + Vector2(-17, -10), p + Vector2(15, 12), BONE, 6.0)
	draw_line(p + Vector2(-15, 12), p + Vector2(17, -10), BONE, 6.0)
	draw_circle(p + Vector2(-17, -10), 5.0, BONE)
	draw_circle(p + Vector2(15, 12), 5.0, BONE)
	draw_circle(p + Vector2(-15, 12), 5.0, BONE)
	draw_circle(p + Vector2(17, -10), 5.0, BONE)
	draw_circle(p, 6.0, BONE)
