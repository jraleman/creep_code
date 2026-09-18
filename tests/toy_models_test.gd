extends SceneTree

## Geometry checks keep the handmade props compact, painted and outward-facing.

const Models = preload("res://games/creep_code/art/toy_models.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for kind in Models.MODEL_NAMES:
		var mesh := Models.mesh(kind)
		_check_mesh(String(kind), mesh, 6000)
		_expect(mesh == Models.mesh(kind), "%s instances must share immutable geometry." % kind)
	_check_mesh("stage", Models.ritual_stage(), 12000)
	_expect(Models.ritual_stage() == Models.ritual_stage(), "Ritual acts must reuse the stone dais.")
	_expect(Models.ritual_stage().get_aabb().end.y > 5.0,
		"The dungeon must have actual masonry and vaulted ribs, not just a recoloured floor.")
	for height in [0.25, 0.85, 1.33]:
		for draining in [false, true]:
			_check_mesh("solar cell", Models.solar_cell(height, draining), 2000)
	for floors in [7, 15, 31]:
		_check_mesh("tower storey", Models.shaft_storey(12.0 / float(floors)), 2000)
	var arch := Models.mesh(&"portal")
	_expect(not _ray_hits(arch, Vector3(0, 1.1, 3)),
		"The arch must have a genuine open passage, not a solid painted face.")
	_expect(_ray_hits(arch, Vector3(1.17, 1.1, 3))
		and _ray_hits(arch, Vector3(0, 2.96, 3)),
		"The hollow passage must retain solid posts and a crown.")
	_expect(_ray_hits(Models.mesh(&"door"), Vector3(0, 1.1, 3)),
		"A sealed door must visibly close the otherwise empty passage.")
	var keeper := Models.mesh(&"keeper").get_aabb()
	_expect(keeper.position.y >= -0.01 and keeper.end.y > 1.75 and keeper.end.y < 2.0,
		"The keeper must stand on the floor with its hat below the P1 label.")
	for outfit in Models.KEEPER_OUTFITS:
		var mesh := Models.keeper_outfit(outfit)
		_expect(mesh == Models.mesh(outfit) and mesh.get_aabb().position.y >= -0.01,
			"Every outfit must reuse cached geometry and keep the keeper's feet on the floor.")
		_expect(mesh.get_aabb().end.y < 2.6,
			"Outfits must fit the existing stage rather than force a different gameplay camera.")
	_expect(Models.keeper_outfit(&"wizard").get_aabb().end.y > keeper.end.y + 0.5
		and Models.keeper_outfit(&"ranger").get_aabb().size.x > keeper.size.x + 0.2
		and Models.keeper_outfit(&"warrior").get_aabb().size.x > keeper.size.x + 0.2,
		"The hat, bow and shield must give outfits distinct silhouettes, not just recoloured coats.")
	if _failures.is_empty():
		print("Creep Code toy model tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _check_mesh(label: String, mesh: ArrayMesh, triangle_budget: int) -> void:
	_expect(mesh != null and mesh.get_surface_count() == 1,
		"%s must be a single painted draw surface." % label)
	if mesh == null or mesh.get_surface_count() != 1:
		return
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	_expect(not vertices.is_empty() and not indices.is_empty() and indices.size() % 3 == 0,
		"%s must contain indexed triangles." % label)
	_expect(indices.size() / 3 <= triangle_budget,
		"%s exceeds its %d-triangle geometry budget." % [label, triangle_budget])
	_expect(normals.size() == vertices.size() and colors.size() == vertices.size(),
		"%s must retain a normal and paint colour for every vertex." % label)
	if normals.size() != vertices.size() or colors.size() != vertices.size():
		return
	var valid_attributes := true
	var has_green := false
	var paints: Dictionary[Color, bool] = {}
	for index in range(vertices.size()):
		valid_attributes = valid_attributes and vertices[index].is_finite()
		valid_attributes = valid_attributes and normals[index].is_finite()
		valid_attributes = valid_attributes and absf(normals[index].length_squared() - 1.0) < 0.02
		var color := colors[index]
		paints[color] = true
		has_green = has_green or (color.g > color.r + 0.05 and color.g > color.b + 0.05)
	_expect(valid_attributes, "%s must have finite positions and unit normals." % label)
	_expect(paints.size() > 1 and (not has_green or label == "ranger"),
		"%s must retain its authored paint; moss-green cloth belongs to the ranger." % label)
	var valid_winding := true
	for offset in range(0, indices.size(), 3):
		var a := indices[offset]
		var b := indices[offset + 1]
		var c := indices[offset + 2]
		if mini(a, mini(b, c)) < 0 or maxi(a, maxi(b, c)) >= vertices.size():
			_failures.append("%s has an out-of-range vertex index." % label)
			return
		var face := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
		if face.length_squared() < 0.00000001:
			continue
		var normal := (normals[a] + normals[b] + normals[c]).normalized()
		valid_winding = valid_winding and face.normalized().dot(normal) < -0.85
	_expect(valid_winding, "%s must use Godot's clockwise exterior triangle winding." % label)


func _ray_hits(mesh: ArrayMesh, origin: Vector3) -> bool:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for offset in range(0, indices.size(), 3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(
			origin, Vector3.FORWARD,
			vertices[indices[offset]], vertices[indices[offset + 1]], vertices[indices[offset + 2]]
		)
		if hit != null:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
