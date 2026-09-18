extends RefCounted

## Original, vertex-painted dungeon relics. Each finished prop is one surface.
## Shapes are authored here, not imported from another game or an asset service.

const Palette = preload("res://games/creep_code/art/palette.gd")
const KEEPER_OUTFITS: Array[StringName] = [&"keeper", &"warrior", &"ranger", &"wizard"]
const MODEL_NAMES: Array[StringName] = [
	&"keeper", &"warrior", &"ranger", &"wizard",
	&"portal", &"door", &"console", &"pedestal", &"orrery",
	&"lamp", &"elevator", &"garden_wall", &"garden_step", &"bridge",
	&"rune", &"seal", &"candles", &"relics", &"keystone",
	&"warden", &"island", &"memory_step",
]

static var _meshes: Dictionary[StringName, ArrayMesh] = {}
static var _stage: ArrayMesh


## Immutable props are shared across ritual acts; no geometry is built per frame.
static func mesh(kind: StringName) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var parts := Parts.new()
	match kind:
		&"keeper", &"warrior", &"ranger", &"wizard":
			_keeper(parts, kind)
		&"portal":
			_portal(parts)
		&"door":
			_door(parts)
		&"console":
			_console(parts)
		&"pedestal":
			_pedestal(parts)
		&"orrery":
			_orrery(parts)
		&"lamp":
			_lamp(parts)
		&"elevator":
			_elevator(parts)
		&"garden_wall":
			_garden_wall(parts)
		&"garden_step":
			_garden_step(parts)
		&"bridge":
			_bridge(parts)
		&"rune":
			_rune(parts)
		&"seal":
			_seal(parts)
		&"candles":
			_candles(parts)
		&"relics":
			_relics(parts)
		&"keystone":
			parts.crystal(Vector3(0, -0.35, 0), 0.3, 0.9, Palette.ARCANE)
			parts.ring(Vector3.ZERO, 0.4, 0.45, Palette.BRASS, Vector3(PI * 0.5, 0, 0))
		&"warden":
			_warden(parts)
		&"island":
			_island(parts)
		&"memory_step":
			_memory_step(parts)
		_:
			push_error("Creep Code has no relic model '%s'." % kind)
			return null
	_meshes[kind] = parts.finish()
	return _meshes[kind]


## Equipment and previews share these exact meshes; an outfit cannot substitute
## another prop just because that prop happens to have a valid mesh name.
static func keeper_outfit(id: StringName) -> ArrayMesh:
	if not KEEPER_OUTFITS.has(id):
		push_error("Creep Code has no keeper outfit '%s'." % id)
		return null
	return mesh(id)


## One circular stone theatre stays in place throughout the ritual. Radial
## inlays and an open front give the changing mechanisms space to perform.
static func ritual_stage() -> ArrayMesh:
	if _stage != null:
		return _stage
	var parts := Parts.new()
	parts.cylinder(Vector3(0, -0.55, 0), 9.3, 0.65, Palette.MORTAR)
	parts.cylinder(Vector3(0, -0.22, 0), 9.0, 0.35, Palette.STONE_DARK)
	parts.cylinder(Vector3(0, -0.08, 0), 8.65, 0.18, Palette.STONE)
	for row in range(9):
		for column in range(9):
			var at := Vector3((column - 4) * 1.8, 0.01, (row - 4) * 1.8)
			if Vector2(at.x, at.z).length() > 7.45:
				continue
			var tint := Palette.STONE.darkened(0.035 * float((column * 3 + row * 7) % 5))
			parts.block(at, Vector3(1.74, 0.08, 1.74), tint, 0.045)
			if (column * 3 + row) % 7 == 0:
				for segment in range(3):
					parts.box(at + Vector3(
						-0.4 + segment * 0.24, 0.043, float(segment % 2) * 0.12
					), Vector3(0.36, 0.006, 0.022), Palette.MORTAR,
						Vector3(0, 0.45 if segment % 2 == 0 else -0.45, 0))
	for radius in [6.45, 8.45, 8.85]:
		parts.ring(Vector3(0, 0.065, 0), radius, radius + 0.035, Palette.BRASS)
	for index in range(24):
		var angle := float(index) * TAU / 24.0
		parts.box(Vector3(cos(angle) * 8.05, 0.08, sin(angle) * 8.05),
			Vector3(0.4, 0.04, 0.08), Palette.GOLD, Vector3(0, -angle, 0))
	for side: float in [-1.0, 1.0]:
		var x := side * 6.5
		parts.block(Vector3(x, 0.2, -4.9), Vector3(1.2, 0.4, 1.2), Palette.STONE_LIGHT)
		for course in range(6):
			parts.block(Vector3(x, 0.8 + course * 0.6, -4.9),
				Vector3(0.72, 0.55, 0.8), Palette.STONE_LIGHT.darkened(course * 0.035))
		parts.cap(Vector3(x, 4.45, -4.9), 0.6, 0.6, Palette.BRASS)
		parts.extrude(PackedVector2Array([
			Vector2(-0.48, -1.8), Vector2(0, -1.5), Vector2(0.48, -1.8),
			Vector2(0.48, 0), Vector2(-0.48, 0),
		]), 0.045, Vector3(x, 3.7, -4.45), Palette.CLAY.darkened(0.25))
		parts.box(Vector3(x, 2.95, -4.41), Vector3(0.32, 0.32, 0.025),
			Palette.BRASS, Vector3(0, 0, PI * 0.25))
	parts.arch(Vector3(0, 1.6, -6.9), 4.4, 4.65, 0.6, Palette.STONE_DARK)
	parts.arch(Vector3(0, 1.6, -6.55), 4.49, 4.54, 0.08, Palette.BRASS)
	_stage = parts.finish()
	return _stage


## Charge is a crystal's height, not its brightness alone.
static func solar_cell(height: float, draining: bool) -> ArrayMesh:
	var parts := Parts.new()
	var paint := Palette.RED if draining else Palette.ARCANE
	parts.block(Vector3(0, 0.09, 0), Vector3(0.88, 0.18, 1.25), Palette.STONE_DARK)
	parts.crystal(Vector3(0, 0.17, 0), 0.42, height, paint)
	parts.ring(Vector3(0, 0.19, 0), 0.28, 0.38, Palette.BRASS)
	for side: float in [-1.0, 1.0]:
		parts.block(Vector3(side * 0.35, 0.28, 0.45),
			Vector3(0.07, 0.35, 0.08), Palette.BRASS, 0.015)
	return parts.finish()


## The tower shelves have real frames and slats; remaining-floor colour is a
## separate indicator so shutter feedback never repaints the entire building.
static func shaft_storey(spacing: float) -> ArrayMesh:
	var parts := Parts.new()
	parts.block(Vector3(0, 0, -0.5), Vector3(5.8, 0.08, 0.65), Palette.STONE_LIGHT, 0.025)
	var height := spacing * 0.82
	for x: float in [-2.4, 0.0, 2.4]:
		parts.block(Vector3(x, height * 0.5 + 0.1, -0.45),
			Vector3(0.16, height, 0.25), Palette.STONE_LIGHT, 0.025)
	parts.block(Vector3(0, height * 0.5 + 0.08, -0.76),
		Vector3(5.6, height, 0.16), Palette.STONE_DARK, 0.025)
	for x: float in [-1.2, 1.2]:
		parts.block(Vector3(x, height * 0.5 + 0.08, -0.65),
			Vector3(1.65, height * 0.64, 0.12), Palette.IRON, 0.025)
		parts.block(Vector3(x, height * 0.5 + 0.08, -0.56),
			Vector3(0.07, height * 0.68, 0.04), Palette.GOLD, 0.01)
	return parts.finish()


## Plain bevelled pieces also use the same painted mesh path as detailed props.
static func block(size: Vector3, color: Color, bevel := 0.07) -> ArrayMesh:
	var parts := Parts.new()
	parts.block(Vector3.ZERO, size, color, bevel)
	return parts.finish()


static func _keeper(parts: Parts, outfit: StringName) -> void:
	var coat := Palette.CLAY
	if outfit == &"warrior":
		coat = Palette.IRON
	elif outfit == &"ranger":
		coat = Palette.MOSS
	elif outfit == &"wizard":
		coat = Palette.BLUE_DARK
	for side: float in [-1.0, 1.0]:
		parts.block(Vector3(side * 0.18, 0.09, 0.08), Vector3(0.3, 0.18, 0.48), Palette.WOOD_DARK)
		parts.block(Vector3(side * 0.18, 0.32, 0), Vector3(0.23, 0.42, 0.26), Palette.BLUE_DARK)
		if outfit == &"ranger" and side < 0:
			parts.ellipsoid(Vector3(-0.4, 0.95, 0), Vector3(0.22, 0.3, 0.26), coat)
			parts.ellipsoid(Vector3(-0.55, 0.83, 0.09), Vector3(0.44, 0.21, 0.27), coat)
			parts.ellipsoid(Vector3(-0.74, 0.87, 0.19),
				Vector3(0.22, 0.2, 0.22), Palette.WOOD_LIGHT)
		else:
			parts.ellipsoid(Vector3(side * 0.4, 0.82, 0), Vector3(0.2, 0.52, 0.24), coat)
			parts.ellipsoid(Vector3(side * 0.4, 0.57, 0.02),
				Vector3(0.22, 0.2, 0.22), Palette.WOOD_LIGHT)
	parts.block(Vector3(0, 0.77, 0), Vector3(0.65, 0.68, 0.43), coat, 0.13)
	if outfit == &"keeper":
		parts.block(Vector3(0, 0.79, -0.29), Vector3(0.52, 0.53, 0.24), Palette.WOOD, 0.09)
	parts.block(Vector3(0, 0.57, 0.23), Vector3(0.65, 0.09, 0.055), Palette.WOOD_DARK, 0.02)
	parts.block(Vector3(0, 0.57, 0.265), Vector3(0.13, 0.11, 0.04), Palette.GOLD, 0.01)
	parts.ellipsoid(Vector3(0, 1.29, 0), Vector3(0.58, 0.56, 0.54), Palette.CREAM)
	if outfit == &"keeper":
		parts.cylinder(Vector3(0, 1.53, 0), 0.43, 0.09, Palette.BLUE_DARK)
		parts.cap(Vector3(0, 1.69, 0), 0.3, 0.32, Palette.BLUE)
	parts.block(Vector3(0, 1.09, 0.23), Vector3(0.65, 0.12, 0.16), Palette.GOLD)
	parts.block(Vector3(0.2, 0.99, 0.23), Vector3(0.16, 0.3, 0.1), Palette.GOLD)
	for side: float in [-1.0, 1.0]:
		var at := Vector3(side * 0.14, 1.32, 0.265)
		parts.cylinder(at, 0.115, 0.065, Palette.BRASS, Vector3(PI * 0.5, 0, 0))
		parts.cylinder(at + Vector3(0, 0, 0.04), 0.079, 0.035, Palette.INK,
			Vector3(PI * 0.5, 0, 0))
		parts.ellipsoid(at + Vector3(-0.02, 0.026, 0.065),
			Vector3(0.037, 0.037, 0.02), Palette.CREAM)
	match outfit:
		&"warrior":
			_warrior_outfit(parts)
		&"ranger":
			_ranger_outfit(parts)
		&"wizard":
			_wizard_outfit(parts)


static func _cloak(parts: Parts, color: Color) -> void:
	parts.extrude(PackedVector2Array([
		Vector2(-0.49, 0.06), Vector2(-0.24, 0), Vector2(0, 0.06),
		Vector2(0.24, 0), Vector2(0.49, 0.06),
		Vector2(0.34, 0.94), Vector2(-0.34, 0.94),
	]), 0.08, Vector3(0, 0.17, -0.33), color)
	for side: float in [-1.0, 1.0]:
		parts.box(Vector3(side * 0.22, 0.67, -0.38),
			Vector3(0.07, 0.81, 0.035), color.darkened(0.15),
			Vector3(0, 0, side * -0.12))


static func _warrior_outfit(parts: Parts) -> void:
	_cloak(parts, Palette.RED.darkened(0.2))
	parts.block(Vector3(0, 0.88, 0.23), Vector3(0.61, 0.43, 0.12), Palette.STONE_LIGHT)
	parts.block(Vector3(0, 0.85, 0.31), Vector3(0.2, 0.55, 0.04), Palette.RED, 0.02)
	for side: float in [-1.0, 1.0]:
		parts.ellipsoid(Vector3(side * 0.41, 1.02, 0),
			Vector3(0.37, 0.26, 0.4), Palette.STONE_LIGHT)
		parts.block(Vector3(side * 0.41, 0.94, 0.18),
			Vector3(0.31, 0.075, 0.06), Palette.BRASS, 0.02)
		parts.block(Vector3(side * 0.18, 0.28, 0.15),
			Vector3(0.25, 0.27, 0.09), Palette.STONE_LIGHT, 0.035)
	parts.ellipsoid(Vector3(0, 1.47, -0.08),
		Vector3(0.73, 0.55, 0.58), Palette.STONE_LIGHT)
	parts.block(Vector3(0, 1.6, 0.16), Vector3(0.11, 0.36, 0.08), Palette.BRASS, 0.02)
	parts.cap(Vector3(0, 1.85, -0.02), 0.11, 0.35, Palette.RED, 0.0)
	var shield := PackedVector2Array([
		Vector2(0, -0.4), Vector2(0.31, -0.12), Vector2(0.31, 0.32),
		Vector2(-0.31, 0.32), Vector2(-0.31, -0.12),
	])
	parts.extrude(shield, 0.12, Vector3(-0.49, 0.74, 0.18), Palette.BRASS)
	for index in range(shield.size()):
		shield[index] *= 0.8
	parts.extrude(shield, 0.035, Vector3(-0.49, 0.74, 0.26), Palette.RED)
	_star(parts, Vector3(-0.49, 0.77, 0.295), 0.14)
	parts.cylinder(Vector3(0.49, 0.48, 0.13), 0.05, 0.28, Palette.WOOD_DARK)
	parts.block(Vector3(0.49, 0.65, 0.13), Vector3(0.34, 0.08, 0.1), Palette.BRASS, 0.02)
	parts.extrude(PackedVector2Array([
		Vector2(-0.075, 0), Vector2(0.075, 0),
		Vector2(0.075, 0.59), Vector2(0, 0.78), Vector2(-0.075, 0.59),
	]), 0.045, Vector3(0.49, 0.68, 0.13), Palette.CREAM)


static func _ranger_outfit(parts: Parts) -> void:
	_cloak(parts, Palette.MOSS.darkened(0.15))
	parts.ellipsoid(Vector3(0, 1.36, -0.09),
		Vector3(0.78, 0.78, 0.65), Palette.MOSS)
	parts.cap(Vector3(0, 1.72, -0.08), 0.23, 0.27, Palette.MOSS, 0.0)
	parts.box(Vector3(0.04, 0.84, 0.245), Vector3(0.12, 0.58, 0.025),
		Palette.WOOD_DARK, Vector3(0, 0, -0.5))
	parts.cylinder(Vector3(0.3, 0.8, -0.43), 0.16, 0.64, Palette.WOOD)
	parts.cylinder(Vector3(0.3, 1.11, -0.43), 0.18, 0.09, Palette.BRASS)
	for index in range(3):
		var at := Vector3(0.19 + index * 0.1, 1.26, -0.43)
		parts.cylinder(at, 0.02, 0.64, Palette.WOOD_LIGHT)
		parts.box(at + Vector3(0, 0.23, 0), Vector3(0.085, 0.15, 0.025), Palette.CREAM)
	var previous := Vector3(-0.59, 0.27, 0.19)
	for index in range(1, 9):
		var t := float(index) / 8.0
		var point := Vector3(-0.59 - sin(t * PI) * 0.25, 0.27 + t * 1.28, 0.19)
		var delta := point - previous
		parts.cylinder(previous.lerp(point, 0.5), 0.035, delta.length(), Palette.WOOD_LIGHT,
			Vector3(0, 0, -atan2(delta.x, delta.y)))
		previous = point
	parts.cylinder(Vector3(-0.59, 0.91, 0.19), 0.012, 1.28, Palette.CREAM)
	parts.block(Vector3(-0.77, 0.87, 0.19), Vector3(0.1, 0.26, 0.11),
		Palette.WOOD_DARK, 0.025)


static func _wizard_outfit(parts: Parts) -> void:
	_cloak(parts, Palette.VIOLET.darkened(0.25))
	parts.extrude(PackedVector2Array([
		Vector2(-0.49, 0), Vector2(0.49, 0),
		Vector2(0.29, 0.87), Vector2(-0.29, 0.87),
	]), 0.5, Vector3(0, 0.16, 0), Palette.BLUE)
	parts.block(Vector3(0, 0.24, 0.27), Vector3(0.86, 0.075, 0.035), Palette.BRASS, 0.02)
	parts.block(Vector3(0, 0.66, 0.28), Vector3(0.7, 0.09, 0.05), Palette.GOLD, 0.02)
	parts.cylinder(Vector3(0, 1.54, 0), 0.5, 0.08, Palette.VIOLET.darkened(0.2))
	parts.cap(Vector3(0, 2.02, 0), 0.41, 0.94, Palette.VIOLET, 0.0)
	parts.cylinder(Vector3(0, 1.61, 0), 0.385, 0.075, Palette.BRASS)
	_star(parts, Vector3(0, 1.9, 0.3), 0.11)
	_star(parts, Vector3(-0.2, 0.43, 0.28), 0.09)
	_star(parts, Vector3(0.18, 0.84, 0.28), 0.07)
	parts.cylinder(Vector3(0.53, 1.02, 0.1), 0.045, 1.94, Palette.WOOD)
	for y: float in [0.51, 0.72, 1.84]:
		parts.cylinder(Vector3(0.53, y, 0.1), 0.065, 0.09, Palette.BRASS)
	parts.crystal(Vector3(0.53, 1.94, 0.1), 0.16, 0.43, Palette.ARCANE)


static func _star(parts: Parts, at: Vector3, radius: float) -> void:
	var points := PackedVector2Array()
	for index in range(8):
		var angle := PI * 0.25 * float(index)
		var reach := radius if index % 2 == 0 else radius * 0.3
		points.append(Vector2(cos(angle), sin(angle)) * reach)
	parts.extrude(points, 0.025, at, Palette.GOLD)


static func _portal(parts: Parts) -> void:
	for side: float in [-1.0, 1.0]:
		var x := side * 1.17
		parts.block(Vector3(x, 0.13, 0), Vector3(0.65, 0.26, 0.82), Palette.STONE_DARK)
		for row in range(4):
			parts.block(Vector3(x, 0.46 + row * 0.4, 0),
				Vector3(0.48, 0.37, 0.61), Palette.STONE_LIGHT.darkened(row * 0.025))
		parts.block(Vector3(x, 0.52, 0.34), Vector3(0.52, 0.13, 0.09), Palette.BRASS)
		parts.block(Vector3(x, 1.58, 0.34), Vector3(0.52, 0.13, 0.09), Palette.BRASS)
		parts.cap(Vector3(x, 1.99, 0), 0.32, 0.25, Palette.STONE_DARK)
	parts.arch(Vector3(0, 1.72, 0), 0.96, 1.4, 0.55, Palette.STONE_LIGHT)
	parts.arch(Vector3(0, 1.72, 0.31), 1.1, 1.22, 0.12, Palette.GOLD)
	parts.block(Vector3(0, 2.96, 0), Vector3(0.5, 0.35, 0.67), Palette.BRASS)
	parts.crystal(Vector3(0, 2.75, 0.4), 0.16, 0.42, Palette.ARCANE)
	parts.block(Vector3(0, 0.05, 0.4), Vector3(2.2, 0.1, 1.0), Palette.STONE_LIGHT)
	for x: float in [-0.65, 0.0, 0.65]:
		parts.block(Vector3(x, 0.11, 0.45), Vector3(0.28, 0.025, 0.24), Palette.BLUE, 0.01)


static func _door(parts: Parts) -> void:
	var outline := PackedVector2Array([Vector2(-0.94, 0), Vector2(0.94, 0)])
	for index in range(13):
		var angle := PI * float(index) / 12.0
		outline.append(Vector2(cos(angle) * 0.94, 1.68 + sin(angle) * 0.94))
	parts.extrude(outline, 0.18, Vector3.ZERO, Palette.WOOD_DARK)
	for x: float in [-0.6, -0.3, 0.0, 0.3, 0.6]:
		parts.block(Vector3(x, 0.9, 0.12), Vector3(0.055, 1.75, 0.06), Palette.WOOD, 0.015)
	for y: float in [0.55, 1.35]:
		parts.block(Vector3(0, y, 0.17), Vector3(1.85, 0.13, 0.08), Palette.BRASS, 0.025)
	parts.cylinder(Vector3(0, 1.2, 0.26), 0.22, 0.09, Palette.GOLD, Vector3(PI * 0.5, 0, 0))
	parts.block(Vector3(0, 1.2, 0.33), Vector3(0.08, 0.24, 0.05), Palette.WOOD_DARK, 0.015)


static func _console(parts: Parts) -> void:
	for side: float in [-1.0, 1.0]:
		parts.block(Vector3(side * 0.48, 0.3, 0), Vector3(0.3, 0.6, 0.58), Palette.STONE_DARK)
	parts.block(Vector3(0, 0.68, 0), Vector3(1.4, 0.56, 0.85), Palette.STONE, 0.09)
	parts.block(Vector3(0, 0.99, 0), Vector3(1.56, 0.15, 1.0), Palette.STONE_LIGHT)
	parts.cylinder(Vector3(-0.28, 1.1, 0), 0.26, 0.08, Palette.BRASS)
	parts.cylinder(Vector3(-0.28, 1.15, 0), 0.2, 0.025, Palette.CREAM)
	parts.block(Vector3(-0.25, 1.17, -0.03), Vector3(0.035, 0.025, 0.25), Palette.RED, 0.008)
	parts.cylinder(Vector3(0.38, 1.17, 0.07), 0.065, 0.32, Palette.WOOD_DARK)
	parts.crystal(Vector3(0.38, 1.27, 0.07), 0.16, 0.38, Palette.ARCANE)
	for x: float in [-0.48, 0.0, 0.48]:
		parts.cylinder(Vector3(x, 0.75, 0.45), 0.048, 0.03, Palette.GOLD,
			Vector3(PI * 0.5, 0, 0))


static func _pedestal(parts: Parts) -> void:
	parts.block(Vector3(0, 0.1, 0), Vector3(2.15, 0.2, 2.15), Palette.STONE_DARK, 0.18)
	parts.cylinder(Vector3(0, 0.5, 0), 0.75, 0.7, Palette.STONE)
	parts.cylinder(Vector3(0, 0.86, 0), 0.91, 0.12, Palette.BRASS)
	for index in range(12):
		var angle := TAU * float(index) / 12.0
		parts.block(Vector3(cos(angle) * 0.72, 0.5, sin(angle) * 0.72),
			Vector3(0.1, 0.55, 0.1), Palette.BRASS, 0.025)
	parts.cylinder(Vector3(0, 1.01, 0), 0.25, 0.24, Palette.WOOD_DARK)


static func _orrery(parts: Parts) -> void:
	parts.ring(Vector3.ZERO, 0.94, 1.12, Palette.BRASS)
	parts.ring(Vector3.ZERO, 0.63, 0.76, Palette.GOLD, Vector3(PI / 3.0, 0, 0))
	parts.crystal(Vector3(0, -0.3, 0), 0.3, 0.9, Palette.ARCANE)
	for index in range(16):
		var angle := TAU * float(index) / 16.0
		parts.box(Vector3(cos(angle) * 1.12, 0, sin(angle) * 1.12),
			Vector3(0.23, 0.12, 0.18), Palette.GOLD, Vector3(0, -angle, 0))
	for index in range(3):
		var angle := TAU * float(index) / 3.0
		var at := Vector3(cos(angle) * 0.88, 0.26 + 0.12 * index, sin(angle) * 0.88)
		parts.cylinder(at * Vector3(1, 0.5, 1), 0.035, at.y, Palette.BRASS)
		parts.ellipsoid(at, Vector3.ONE * 0.27,
			[Palette.BLUE, Palette.CLAY, Palette.CREAM][index])


static func _lamp(parts: Parts) -> void:
	parts.block(Vector3(0, 0.09, 0), Vector3(0.62, 0.18, 0.62), Palette.WOOD_DARK)
	parts.cylinder(Vector3(0, 0.55, 0), 0.07, 0.88, Palette.BRASS)
	parts.block(Vector3(0, 1.06, 0), Vector3(0.35, 0.5, 0.35), Palette.FIRE)
	for x: float in [-0.24, 0.24]:
		for z: float in [-0.24, 0.24]:
			parts.block(Vector3(x, 1.06, z), Vector3(0.05, 0.55, 0.05), Palette.WOOD_DARK, 0.01)
	parts.cap(Vector3(0, 1.43, 0), 0.38, 0.28, Palette.IRON)


static func _elevator(parts: Parts) -> void:
	parts.block(Vector3.ZERO, Vector3(2.0, 0.22, 1.7), Palette.WOOD_LIGHT)
	for side: float in [-1.0, 1.0]:
		parts.block(Vector3(side * 0.89, 0.89, -0.59), Vector3(0.14, 1.8, 0.14), Palette.CREAM)
		parts.block(Vector3(side * 0.89, 0.58, 0.04), Vector3(0.11, 0.11, 1.45), Palette.BRASS)
		parts.block(Vector3(side * 0.89, 0.33, 0.67), Vector3(0.12, 0.55, 0.12), Palette.BLUE)
	parts.block(Vector3(0, 1.82, -0.59), Vector3(2, 0.22, 0.35), Palette.CLAY)
	parts.cylinder(Vector3(0, 1.98, -0.59), 0.19, 0.1, Palette.BRASS,
		Vector3(PI * 0.5, 0, 0))
	parts.block(Vector3(0, 0.25, -0.73), Vector3(1.8, 0.45, 0.14), Palette.BLUE)


static func _garden_wall(parts: Parts) -> void:
	parts.block(Vector3(0, 0.15, 0), Vector3(1.3, 0.3, 1.3), Palette.STONE_DARK, 0.16)
	parts.block(Vector3(-0.22, 0.38, -0.22), Vector3(0.66, 0.44, 0.72), Palette.STONE)
	for index in range(3):
		var at := Vector3(-0.33 + index * 0.3, 0.46 + float(index % 2) * 0.28, 0.12 - index * 0.14)
		parts.cylinder(at, 0.07, at.y * 1.4, Palette.CREAM)
		parts.ellipsoid(at + Vector3(0, at.y * 0.62, 0),
			Vector3(0.65, 0.3, 0.65), Palette.VIOLET if index != 1 else Palette.BLUE)
		parts.ellipsoid(at + Vector3(0.1, at.y * 0.75, 0.15),
			Vector3(0.1, 0.045, 0.1), Palette.CREAM)


static func _garden_step(parts: Parts) -> void:
	parts.block(Vector3(0, -0.03, 0), Vector3(1.3, 0.28, 1.3), Palette.STONE_DARK, 0.14)
	parts.block(Vector3(0, 0.09, 0), Vector3(1.21, 0.14, 1.21), Palette.STONE_LIGHT, 0.11)
	for side: float in [-1.0, 1.0]:
		parts.block(Vector3(side * 0.45, 0.18, -0.43), Vector3(0.12, 0.055, 0.12),
			Palette.BRASS, 0.02)


static func _bridge(parts: Parts) -> void:
	parts.block(Vector3(0, -0.025, 0), Vector3(0.58, 0.13, 0.72), Palette.WOOD_DARK)
	for index in range(3):
		parts.block(Vector3(0, 0.055, -0.23 + index * 0.23),
			Vector3(0.66, 0.095, 0.19), Palette.WOOD_LIGHT, 0.025)


static func _warden(parts: Parts) -> void:
	parts.ellipsoid(Vector3.ZERO, Vector3(0.65, 0.55, 0.65), Palette.IRON)
	parts.ring(Vector3.ZERO, 0.34, 0.42, Palette.BRASS)
	parts.crystal(Vector3(0, 0.18, 0), 0.16, 0.4, Palette.ARCANE)
	for side: float in [-1.0, 1.0]:
		parts.box(Vector3(side * 0.48, 0.02, 0), Vector3(0.48, 0.075, 0.32),
			Palette.GOLD, Vector3(0, 0, side * 0.2))
		parts.ellipsoid(Vector3(side * 0.13, 0.02, 0.29), Vector3(0.11, 0.11, 0.08), Palette.CREAM)
	parts.cap(Vector3(0, -0.32, 0), 0.05, 0.25, Palette.BRASS, 3.4)


static func _island(parts: Parts) -> void:
	parts.block(Vector3(0, 0.02, 0), Vector3(1.65, 0.4, 1.65), Palette.STONE_DARK, 0.18)
	parts.block(Vector3(0, 0.22, 0), Vector3(1.55, 0.14, 1.55), Palette.STONE_LIGHT, 0.13)
	parts.cap(Vector3(0, -0.43, 0), 0.18, 0.75, Palette.STONE, 4.0)
	for side: float in [-1.0, 1.0]:
		parts.crystal(Vector3(side * 0.63, -0.16, -0.45), 0.12, 0.35, Palette.VIOLET)
		parts.block(Vector3(side * 0.65, 0.32, 0.55), Vector3(0.12, 0.12, 0.16), Palette.BRASS, 0.025)


static func _memory_step(parts: Parts) -> void:
	_garden_step(parts)
	parts.block(Vector3(0, 0.19, 0.38), Vector3(0.9, 0.07, 0.3), Palette.PAPER, 0.025)
	for side: float in [-1.0, 1.0]:
		parts.block(Vector3(side * 0.5, -0.28, -0.42),
			Vector3(0.14, 0.4, 0.18), Palette.BRASS, 0.025)


static func _rune(parts: Parts) -> void:
	parts.ring(Vector3.ZERO, 0.32, 0.35, Palette.ARCANE)
	for index in range(4):
		var angle := float(index) * PI * 0.5
		parts.box(Vector3(cos(angle) * 0.43, 0, sin(angle) * 0.43),
			Vector3(0.1, 0.025, 0.06), Palette.GOLD, Vector3(0, -angle, 0))
	parts.box(Vector3.ZERO, Vector3(0.21, 0.025, 0.21),
		Palette.ARCANE, Vector3(0, PI * 0.25, 0))


static func _seal(parts: Parts) -> void:
	parts.ring(Vector3.ZERO, 1.9, 1.94, Palette.ARCANE)
	parts.ring(Vector3.ZERO, 1.56, 1.58, Palette.GOLD)
	for index in range(12):
		var angle := float(index) * TAU / 12.0
		var at := Vector3(cos(angle) * 1.74, 0, sin(angle) * 1.74)
		parts.box(at, Vector3(0.14, 0.025, 0.055), Palette.GOLD, Vector3(0, -angle, 0))
		parts.box(at, Vector3(0.045, 0.025, 0.15), Palette.ARCANE, Vector3(0, -angle, 0))
	for index in range(3):
		parts.box(Vector3.ZERO, Vector3(2.3, 0.025, 0.035),
			Palette.ARCANE, Vector3(0, float(index) * PI / 3.0, 0))


static func _candles(parts: Parts) -> void:
	parts.cylinder(Vector3(0, 0.05, 0), 0.52, 0.1, Palette.BRASS)
	for index in range(3):
		var at := Vector3(-0.27 + index * 0.27, 0.1, float(index % 2) * 0.24)
		var height := 0.42 + float(index % 2) * 0.32
		parts.cylinder(at + Vector3.UP * height * 0.5, 0.085, height, Palette.CREAM)
		parts.crystal(at + Vector3.UP * height, 0.07, 0.22, Palette.FIRE)


static func _relics(parts: Parts) -> void:
	for index in range(3):
		var at := Vector3(0.08 * float(index % 2), 0.1 + index * 0.18, 0)
		parts.block(at, Vector3(1.0, 0.15, 0.72), Palette.PAPER, 0.025)
		for side: float in [-1.0, 1.0]:
			parts.block(at + Vector3(0, side * 0.07, 0),
				Vector3(1.05, 0.035, 0.76), Palette.CLAY if index == 1 else Palette.WOOD_DARK, 0.01)
	parts.crystal(Vector3(0.1, 0.55, 0), 0.22, 0.68, Palette.VIOLET)


class Parts:
	extends RefCounted

	## A compact model-authoring buffer; it owns no scene nodes or materials.

	var _surface := SurfaceTool.new()

	func _init() -> void:
		_surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	## Native primitives provide indexed, outward-facing geometry for small details.
	func box(at: Vector3, size: Vector3, paint: Color, rotation := Vector3.ZERO) -> void:
		var primitive := BoxMesh.new()
		primitive.size = size
		_append(primitive, Transform3D(Basis.from_euler(rotation), at), paint)

	## Chamfered edges catch the warm key light without a bevel shader or textures.
	func block(at: Vector3, size: Vector3, paint: Color, bevel := 0.07) -> void:
		var x := size.x * 0.5
		var y := size.y * 0.5
		var z := size.z * 0.5
		var cut := minf(bevel, minf(x, minf(y, z)) * 0.8)
		var outline := PackedVector2Array([
			Vector2(-x + cut, -z), Vector2(x - cut, -z),
			Vector2(x, -z + cut), Vector2(x, z - cut),
			Vector2(x - cut, z), Vector2(-x + cut, z),
			Vector2(-x, z - cut), Vector2(-x, -z + cut),
		])
		var bottom: Array[Vector3] = []
		var lower: Array[Vector3] = []
		var upper: Array[Vector3] = []
		var top: Array[Vector3] = []
		for corner in outline:
			var inset := corner * Vector2((x - cut) / x, (z - cut) / z)
			bottom.append(at + Vector3(inset.x, -y, inset.y))
			lower.append(at + Vector3(corner.x, -y + cut, corner.y))
			upper.append(at + Vector3(corner.x, y - cut, corner.y))
			top.append(at + Vector3(inset.x, y, inset.y))
		for index in range(8):
			var next := (index + 1) % 8
			_quad(bottom[index], lower[index], lower[next], bottom[next], paint.darkened(0.08))
			_quad(lower[index], upper[index], upper[next], lower[next], paint)
			_quad(upper[index], top[index], top[next], upper[next], paint.lightened(0.04))
			_triangle(at + Vector3.UP * y, top[next], top[index], paint)
			_triangle(at - Vector3.UP * y, bottom[index], bottom[next], paint)

	## Low segment counts make curved parts read as carved rather than metallic.
	func cylinder(
		at: Vector3, radius: float, height: float, paint: Color, rotation := Vector3.ZERO
	) -> void:
		var primitive := CylinderMesh.new()
		primitive.top_radius = radius
		primitive.bottom_radius = radius
		primitive.height = height
		primitive.radial_segments = 12
		primitive.rings = 1
		_append(primitive, Transform3D(Basis.from_euler(rotation), at), paint)

	## A broad conical cap gives posts, lamps and the keeper a shared silhouette.
	func cap(
		at: Vector3, radius: float, height: float, paint: Color, tip_ratio := 0.26
	) -> void:
		var primitive := CylinderMesh.new()
		primitive.top_radius = radius * tip_ratio
		primitive.bottom_radius = radius
		primitive.height = height
		primitive.radial_segments = 12
		primitive.rings = 1
		_append(primitive, Transform3D(Basis.IDENTITY, at), paint)

	## Six hand-cut facets make crystals legible without transparency or refraction.
	func crystal(at: Vector3, radius: float, height: float, paint: Color) -> void:
		for index in range(6):
			var a := float(index) * TAU / 6.0
			var b := float(index + 1) * TAU / 6.0
			var left := at + Vector3(cos(a) * radius, height * 0.28, sin(a) * radius)
			var right := at + Vector3(cos(b) * radius, height * 0.28, sin(b) * radius)
			var tint := paint.darkened(float(index % 3) * 0.12)
			_triangle(at + Vector3.UP * height, right, left, tint)
			_triangle(at, left, right, tint.darkened(0.15))

	## Full extents make heads and painted planets easy to proportion together.
	func ellipsoid(at: Vector3, size: Vector3, paint: Color) -> void:
		var primitive := SphereMesh.new()
		primitive.radius = 0.5
		primitive.height = 1.0
		primitive.radial_segments = 12
		primitive.rings = 6
		_append(primitive, Transform3D(Basis.from_scale(size), at), paint)

	## An orbit is geometry, so it remains visible on the Compatibility renderer.
	func ring(
		at: Vector3, inner: float, outer: float, paint: Color, rotation := Vector3.ZERO
	) -> void:
		var primitive := TorusMesh.new()
		primitive.inner_radius = inner
		primitive.outer_radius = outer
		primitive.rings = 24
		primitive.ring_segments = 6
		_append(primitive, Transform3D(Basis.from_euler(rotation), at), paint)

	## A hollow arch preserves an actual doorway, not a painted rectangle.
	func arch(at: Vector3, inner: float, outer: float, depth: float, paint: Color) -> void:
		for index in range(16):
			var a := PI * float(index) / 16.0
			var b := PI * float(index + 1) / 16.0
			var ia := at + Vector3(cos(a) * inner, sin(a) * inner, depth * 0.5)
			var ib := at + Vector3(cos(b) * inner, sin(b) * inner, depth * 0.5)
			var oa := at + Vector3(cos(a) * outer, sin(a) * outer, depth * 0.5)
			var ob := at + Vector3(cos(b) * outer, sin(b) * outer, depth * 0.5)
			var back := Vector3(0, 0, -depth)
			_quad(ia, oa, ob, ib, paint)
			_quad(ib + back, ob + back, oa + back, ia + back, paint)
			_quad(oa, oa + back, ob + back, ob, paint.darkened(0.08))
			_quad(ib, ib + back, ia + back, ia, paint.darkened(0.12))

	## Extrusion keeps the curved door face watertight without overlapping caps.
	func extrude(outline: PackedVector2Array, depth: float, at: Vector3, paint: Color) -> void:
		var triangles := Geometry2D.triangulate_polygon(outline)
		for offset in range(0, triangles.size(), 3):
			var front: Array[Vector3] = []
			for corner in range(3):
				var point := outline[triangles[offset + corner]]
				front.append(at + Vector3(point.x, point.y, depth * 0.5))
			_triangle(front[0], front[1], front[2], paint)
			var back := Vector3(0, 0, -depth)
			_triangle(front[2] + back, front[1] + back, front[0] + back, paint)
		for index in range(outline.size()):
			var a := outline[index]
			var b := outline[(index + 1) % outline.size()]
			_quad(
				at + Vector3(a.x, a.y, depth * 0.5), at + Vector3(a.x, a.y, -depth * 0.5),
				at + Vector3(b.x, b.y, -depth * 0.5), at + Vector3(b.x, b.y, depth * 0.5),
				paint.darkened(0.1)
			)

	## Paint and normals are baked once; instances share this one surface.
	func finish() -> ArrayMesh:
		_surface.index()
		return _surface.commit()

	func _append(primitive: Mesh, transform: Transform3D, paint: Color) -> void:
		var arrays := primitive.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var normal_basis := transform.basis.inverse().transposed()
		_surface.set_color(paint)
		for index in indices:
			_surface.set_normal((normal_basis * normals[index]).normalized())
			_surface.add_vertex(transform * points[index])

	func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, paint: Color) -> void:
		_triangle(a, b, c, paint)
		_triangle(a, c, d, paint)

	func _triangle(a: Vector3, b: Vector3, c: Vector3, paint: Color) -> void:
		_surface.set_color(paint)
		_surface.set_normal((b - a).cross(c - a).normalized())
		# Normals describe the exterior; Godot indexes front faces clockwise.
		for point: Vector3 in [a, c, b]:
			_surface.add_vertex(point)
