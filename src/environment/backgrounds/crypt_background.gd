extends GridBackground

## Procedural "Catacombs" background drawn with Godot's simple _draw() primitives.
## Extends GridBackground so every system that recognises the arena floor by class
## (ObstacleSpawner, game_state) still finds it and keeps working — we simply
## override _draw() below so only the crypt is drawn, never the technical grid.
## arena_center / arena_size are inherited from GridBackground (defaults match).
##
## The whole scene is drawn once and cached by Godot, so the many rects here cost
## nothing per frame after the first draw.

## Stone flag size in pixels (each flag is approx this big).
@export var flag_size: float = 64.0
## Thickness of the masonry wall ring drawn around the arena perimeter.
@export var wall_thickness: float = 150.0

# Palettes tuned to a cold, dim dungeon so they sit well under the dark UI/HUD.
const FLOOR_BASE := Color(0.095, 0.105, 0.135)
const MORTAR := Color(0.05, 0.06, 0.085)
const WALL_DARK := Color(0.105, 0.115, 0.14)
const WALL_EDGE := Color(0.34, 0.36, 0.44)
const BONE := Color(0.78, 0.78, 0.72)


func _draw() -> void:
	var tl := arena_center - arena_size * 0.5

	# Base dark fill the size of the arena.
	draw_rect(Rect2(tl, arena_size), FLOOR_BASE)

	_draw_flagstone_floor(tl, arena_size)
	_draw_wall_ring(tl, arena_size)


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


## Masonry wall ring around the perimeter, drawn OUTWARD from the map edges so the
## playable floor fills the whole arena. The wall starts at the map edge (it never
## cuts into the fighting area); skull engravings stay pinned to the band's centre
## line so they never spill outside the wall.
func _draw_wall_ring(tl: Vector2, size: Vector2) -> void:
	var blocks := 96.0
	# Horizontal bands sit above / below the arena; vertical bands fill the corners.
	_draw_band(Rect2(tl.x, tl.y - wall_thickness, size.x, wall_thickness), blocks, 0)
	_draw_band(Rect2(tl.x, tl.y + size.y, size.x, wall_thickness), blocks, 1)
	_draw_band(Rect2(tl.x - wall_thickness, tl.y - wall_thickness, wall_thickness, size.y + wall_thickness * 2.0), blocks, 2)
	_draw_band(Rect2(tl.x + size.x, tl.y - wall_thickness, wall_thickness, size.y + wall_thickness * 2.0), blocks, 3)


func _draw_band(rect: Rect2, blocks: float, seed_off: int) -> void:
	draw_rect(rect, WALL_DARK)
	var is_h: bool = rect.size.x >= rect.size.y
	var length: float = rect.size.x if is_h else rect.size.y
	var n := maxi(1, int(length / blocks))
	# Centre seam that splits the band into two brick courses.
	if is_h:
		draw_line(Vector2(rect.position.x, rect.position.y + rect.size.y * 0.5), Vector2(rect.end.x, rect.position.y + rect.size.y * 0.5), MORTAR, 2.0)
	else:
		draw_line(Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y), Vector2(rect.position.x + rect.size.x * 0.5, rect.end.y), MORTAR, 2.0)
	# Brick divisions along the band (staggered per course).
	for i in range(n + 1):
		var p: float = rect.position.x + i * blocks if is_h else rect.position.y + i * blocks
		if is_h:
			draw_line(Vector2(p, rect.position.y), Vector2(p, rect.end.y), MORTAR, 2.0)
		else:
			draw_line(Vector2(rect.position.x, p), Vector2(rect.end.x, p), MORTAR, 2.0)
	# Skull engravings along the band's centre line, radius kept well inside the band.
	var r := clampf(minf(rect.size.x, rect.size.y) * 0.26, 14.0, 38.0)
	for i in range(n):
		var t := (i + 0.5) / n
		var cx := rect.position.x + (length * t if is_h else rect.size.x * 0.5)
		var cy := rect.position.y + (rect.size.y * 0.5 if is_h else length * t)
		if ((i + seed_off) % 3) == 0:
			_draw_skull(Vector2(cx, cy), r)
	# Thin highlight so the wall reads as a distinct border at the map edge.
	draw_rect(rect, WALL_EDGE, false, 2.0)


## A bone-coloured skull (two dark eye sockets + a jaw) engraved on the walls.
func _draw_skull(pos: Vector2, r: float) -> void:
	draw_circle(pos, r, BONE)
	draw_circle(pos + Vector2(-r * 0.4, -r * 0.15), r * 0.22, WALL_DARK)
	draw_circle(pos + Vector2(r * 0.4, -r * 0.15), r * 0.22, WALL_DARK)
	draw_rect(Rect2(pos - Vector2(r * 0.2, 0), Vector2(r * 0.4, r * 0.28)), WALL_DARK)
