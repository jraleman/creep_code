extends Node3D

## One persistent stone theatre hosts every act of the ritual. Only its
## mechanism changes; the dais, keeper, lights and growing constellation stay.
## Models own answers. Animation never spends time, charges or points.

const Options = preload("res://games/creep_code/creep_code_options.gd")
const Manager = preload("res://games/creep_code/puzzle_manager.gd")
const State = preload("res://games/creep_code/puzzles/puzzle_state.gd")
const Sunrail = preload("res://games/creep_code/puzzles/sliding_window.gd")
const Shaft = preload("res://games/creep_code/puzzles/binary_search.gd")
const Garden = preload("res://games/creep_code/puzzles/breadth_first.gd")
const Wardens = preload("res://games/creep_code/puzzles/two_pointers.gd")
const Archipelago = preload("res://games/creep_code/puzzles/union_find.gd")
const Stair = preload("res://games/creep_code/puzzles/dynamic_programming.gd")
const Palette = preload("res://games/creep_code/art/palette.gd")
const Models = preload("res://games/creep_code/art/toy_models.gd")

const CELL_SPACING := 1.55
const CORE_POSITION := Vector3(0, 4.0, -6.0)
const STAR_POSITIONS: Array[Vector3] = [
	Vector3(-4.8, 4.2, -6), Vector3(-2.6, 6.2, -6), Vector3(2.6, 6.2, -6),
	Vector3(4.8, 4.2, -6), Vector3(2.6, 2.7, -6), Vector3(-2.6, 2.7, -6),
]
const FINALE_STARS: Array[Vector3] = [
	Vector3(-4, 2.7, 0), Vector3(-2, 5.5, -0.6), Vector3(2, 5.5, -0.6),
	Vector3(4, 2.7, 0), Vector3(2, 0.8, 1), Vector3(-2, 0.8, 1),
]
const ISLAND_POSITIONS: Array[Vector3] = [
	Vector3(-4.5, 0.65, -2.5), Vector3(0, 0.65, -3.8), Vector3(4.5, 0.65, -2.5),
	Vector3(-4.5, 0.65, 2.5), Vector3(0, 0.65, 3.8), Vector3(4.5, 0.65, 2.5),
]
const NETWORK_COLORS: Array[Color] = [
	Palette.GOLD, Palette.ARCANE, Palette.VIOLET, Palette.RED, Palette.CREAM, Palette.BRASS,
]
const GUIDE_POSITION := Vector3(-5.7, 0.12, 4.0)
const WALK_SECONDS := 0.24

var stage_id: StringName = &""
var camera: Camera3D
var stage_bounds := AABB(Vector3(-9.7, -1, -9.5), Vector3(19.4, 9, 19))
var ambient_angle := 0.0
var _stage: Node3D
var _mechanism: Node3D
var _painted_material: StandardMaterial3D
var _materials: Dictionary[Color, StandardMaterial3D] = {}
var _glow_materials: Dictionary[Color, StandardMaterial3D] = {}
var _torch_lights: Array[OmniLight3D] = []
var _puzzle_light: OmniLight3D
var _core_light: OmniLight3D
var _engine: Node3D
var _halo: MeshInstance3D
var _floor_seal: MeshInstance3D
var _stars: Array[MeshInstance3D] = []
var _links: Array[MeshInstance3D] = []
var _offering: MeshInstance3D
var _offering_start := Vector3.ZERO
var _offering_end := Vector3.ZERO
var _restoration := -1.0
var _finale := 0.0
var _in_finale := false
var _lit_count := 0
var _player: Node3D
var _player_visual: Node3D
var _keeper_mesh: MeshInstance3D
var _outfit_id: StringName = Options.DEFAULT_OUTFIT
var _player_label: Label3D
var _motes: MultiMeshInstance3D
var _sparks: MultiMeshInstance3D
var _effects_time := 0.0
var _spark_time := 0.0
var _spark_origin := Vector3.ZERO
var _action_pulse := 0.0
var _puzzle_energy := 1.0
var _reduced_motion := false
var _intense_effects := true
var _running := true
var _aspect := 16.0 / 9.0
var _arrival := 1.0
var _departure := 0.0
var _frame: Node3D
var _frame_target := 0.0
var _rail_width := 1.0
var _solar_cells: Array[Node3D] = []
var _tiles: Array[MeshInstance3D] = []
var _selected_from := 0
var _selected_width := 3
var _record_label: Label3D
var _floor_meshes: Array[MeshInstance3D] = []
var _floor_labels: Array[Label3D] = []
var _needle: Node3D
var _needle_target := 0.0
var _whisper_orb: MeshInstance3D
var _whisper_direction := 0.0
var _garden_tiles: Dictionary[Vector2i, MeshInstance3D] = {}
var _garden_labels: Dictionary[Vector2i, Label3D] = {}
var _rune_ages: Dictionary[Vector2i, float] = {}
var _garden_size := Vector2i.ZERO
var _garden_from := Vector3.ZERO
var _garden_target := Vector3.ZERO
var _garden_step := 1.0
var _garden_in_motion := false
var _wardens: Array[Node3D] = []
var _warden_targets: Array[Vector3] = []
var _warden_pylons: Array[MeshInstance3D] = []
var _warden_labels: Array[Label3D] = []
var _warden_beam: MeshInstance3D
var _islands: Array[MeshInstance3D] = []
var _network_runes: Array[MeshInstance3D] = []
var _network_labels: Array[Label3D] = []
var _bridge_sockets: Array[MeshInstance3D] = []
var _bridge_meshes: Array[MeshInstance3D] = []
var _bridge_lines: Array[MeshInstance3D] = []
var _bridge_pulses: Array[MeshInstance3D] = []
var _bridge_edges: Array[Vector2i] = []
var _bridge_ages: Dictionary[int, float] = {}
var _stair_tiles: Array[MeshInstance3D] = []
var _stair_labels: Array[Label3D] = []
var _stair_links: Array[MeshInstance3D] = []
var _stair_ages: Dictionary[int, float] = {}
var _stair_focus: MeshInstance3D
var _stair_focus_target := Vector3.ZERO
var _stair_selected := -1
var _pick_meshes: Array[MeshInstance3D] = []
var _pick_labels: Dictionary[Label3D, MeshInstance3D] = {}
var _pick_faces: Dictionary[Mesh, PackedVector3Array] = {}


func _ready() -> void:
	_build_materials()
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Palette.BACKDROP
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Palette.FILL_LIGHT
	settings.ambient_light_energy = 0.36
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = settings
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52, -28, 0)
	light.light_color = Palette.SUNLIGHT
	light.light_energy = 0.52
	light.shadow_enabled = true
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	light.directional_shadow_max_distance = 55.0
	add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.current = true
	add_child(camera)
	_stage = Node3D.new()
	_stage.name = "RitualStage"
	add_child(_stage)
	_painted(_stage, Models.ritual_stage(), Vector3.ZERO)
	_build_ambience()
	_build_constellation()
	_build_keeper()
	_frame_camera()


func _process(delta: float) -> void:
	if not _running:
		return
	if not _reduced_motion:
		_effects_time += delta
		ambient_angle += delta * 0.22
	_action_pulse = maxf(0.0, _action_pulse - delta)
	_spark_time = maxf(0.0, _spark_time - delta)
	if is_instance_valid(_frame):
		_frame.position.x = (
			_frame_target if _reduced_motion
			else move_toward(_frame.position.x, _frame_target, delta * 19.0)
		)
	if is_instance_valid(_needle):
		_needle.rotation.y = (
			_needle_target if _reduced_motion
			else lerp_angle(_needle.rotation.y, _needle_target, minf(1.0, delta * 12.0))
		)
	if _garden_in_motion:
		_garden_step = minf(1.0, _garden_step + delta / WALK_SECONDS)
		_update_keeper_step()
	for cell in _rune_ages:
		_rune_ages[cell] = minf(1.0, _rune_ages[cell] + delta * 2.5)
	for index in range(_wardens.size()):
		_wardens[index].position = (
			_warden_targets[index] if _reduced_motion else
			_wardens[index].position.move_toward(_warden_targets[index], delta * 12.0)
		)
	for index in _bridge_ages:
		_bridge_ages[index] = minf(1.0, _bridge_ages[index] + delta * 2.5)
	for index in _stair_ages:
		_stair_ages[index] = minf(1.0, _stair_ages[index] + delta * 2.5)
	if is_instance_valid(_stair_focus):
		_stair_focus.position = (
			_stair_focus_target if _reduced_motion else
			_stair_focus.position.move_toward(_stair_focus_target, delta * 12.0)
		)
	_update_magic()


## Replaying clears transient props, not the persistent theatre or its camera.
func reset_ritual() -> void:
	_clear_mechanism()
	stage_id = &""
	_arrival = 1.0
	_departure = 0.0
	_restoration = -1.0
	_finale = 0.0
	_in_finale = false
	_lit_count = 0
	_effects_time = 0.0
	ambient_angle = 0.0
	_spark_time = 0.0
	_offering.hide()
	_player.position = GUIDE_POSITION
	_present_constellation([])
	_update_magic()


## A mechanism unfolds on the same dais. No room scene, doorway or physics
## character is replaced, and every act uses the same stable camera framing.
func mount_relic(manager: Manager) -> void:
	_clear_mechanism()
	stage_id = manager.current_id
	_arrival = 0.0
	_departure = 0.0
	_restoration = -1.0
	_in_finale = false
	_finale = 0.0
	_offering.hide()
	_mechanism = Node3D.new()
	_mechanism.name = "Relic"
	_stage.add_child(_mechanism)
	_player.position = GUIDE_POSITION
	_player_visual.rotation = Vector3.ZERO
	match stage_id:
		&"sunrail":
			_build_sunrail(manager.current() as Sunrail)
		&"shaft":
			_build_shaft(manager.current() as Shaft)
		&"garden":
			_build_garden(manager.current() as Garden)
		&"wardens":
			_build_wardens(manager.current() as Wardens)
		&"archipelago":
			_build_archipelago(manager.current() as Archipelago)
		&"stair":
			_build_stair(manager.current() as Stair)
		_:
			push_error("Creep Code has no view for relic '%s'." % stage_id)
	if is_instance_valid(_puzzle_light):
		_puzzle_energy = _puzzle_light.light_energy
	present(manager)
	if is_instance_valid(_frame):
		_frame.position.x = _frame_target
	if is_instance_valid(_needle):
		_needle.rotation.y = _needle_target
	_settle_algorithm_markers()
	_apply_mechanism_pose()
	_update_magic()


## Model facts update existing props; decorative motion cannot alter an answer.
func present(manager: Manager) -> void:
	_present_constellation(manager.lit_relays)
	if manager.current_id != stage_id or not is_instance_valid(_mechanism):
		return
	var state := manager.current()
	if state is Sunrail:
		_present_sunrail(state)
	elif state is Shaft:
		_present_shaft(state)
	elif state is Garden:
		_present_garden(state)
	elif state is Wardens:
		_present_wardens(state)
	elif state is Archipelago:
		_present_archipelago(state)
	elif state is Stair:
		_present_stair(state)


## Gameplay drives handoff time so reading, pause and retries cannot race a tween.
func set_arrival_progress(value: float) -> void:
	_arrival = clampf(value, 0.0, 1.0)
	_apply_mechanism_pose()


## The outgoing mechanism folds into the dais before the next one is mounted.
func set_departure_progress(value: float) -> void:
	_departure = clampf(value, 0.0, 1.0)
	_apply_mechanism_pose()


## An earned keystone visibly joins its numbered constellation socket.
func begin_restoration(id: StringName) -> void:
	var index := _relic_index(id)
	if index < 0:
		return
	_offering_start = _relic_origin()
	_offering_end = STAR_POSITIONS[index]
	_restoration = 0.0
	_update_offering()


## The flight is presentation only; the earned achievement is already safe.
func set_restoration_progress(value: float) -> void:
	_restoration = clampf(value, 0.0, 1.0)
	_update_offering()


## The completed constellation, not a walk back to an engine, closes the ritual.
func begin_finale() -> void:
	_clear_mechanism()
	_player.position = GUIDE_POSITION
	_restoration = -1.0
	_offering.hide()
	_finale = 0.0
	_in_finale = true
	play_feedback(&"success")


## The final bloom is bounded geometry and light, never a screen flash.
func set_finale_progress(value: float) -> void:
	_finale = clampf(value, 0.0, 1.0)
	_update_magic()


## Both motion directions restore well-defined poses, including mid-handoff.
func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	if enabled:
		_effects_time = 0.0
		ambient_angle = 0.0
		_action_pulse = 0.0
		_spark_time = 0.0
		if is_instance_valid(_frame):
			_frame.position.x = _frame_target
		if is_instance_valid(_needle):
			_needle.rotation.y = _needle_target
		if _garden_in_motion:
			_garden_step = 1.0
			_update_keeper_step()
		for index in _bridge_ages:
			_bridge_ages[index] = 1.0
		for index in _stair_ages:
			_stair_ages[index] = 1.0
		_settle_algorithm_markers()
	_apply_mechanism_pose()
	_update_offering()
	_update_magic()


## Gentle mechanical motion remains; motes, sparks and light pulses are optional.
func set_intense_effects(enabled: bool) -> void:
	_intense_effects = enabled
	if not enabled:
		_spark_time = 0.0
	_update_magic()


## Every gesture has a local response, while its words remain in the native HUD.
func play_feedback(kind: StringName) -> void:
	if kind in [&"shift", &"start", &"higher", &"lower", &"pulse", &"heard", &"step", &"connect", &"record"]:
		_action_pulse = 0.55
	if kind in [&"higher", &"lower"]:
		_whisper_direction = 1.0 if kind == &"higher" else -1.0
	elif kind in [&"reset", &"start"]:
		_whisper_direction = 0.0
	if kind == &"success" and not _reduced_motion and _intense_effects:
		_spark_time = 1.2
		_spark_origin = _relic_origin() if is_instance_valid(_mechanism) else CORE_POSITION
	_update_magic()


## The familiar keeper remains a guide and a visible garden cursor, not a commute.
func set_player_labels(enabled: bool) -> void:
	_player_label.visible = enabled


## Changing clothes preserves the keeper, its current hop and every puzzle fact.
func set_outfit(id: StringName) -> void:
	var mesh := Models.keeper_outfit(id)
	if mesh == null:
		return
	_outfit_id = id
	if is_instance_valid(_keeper_mesh):
		_keeper_mesh.mesh = mesh
		_player_label.position.y = mesh.get_aabb().end.y + 0.22


## Results freeze the final tableau without losing its completed pose.
func set_running(enabled: bool) -> void:
	_running = enabled


## The full theatre stays framed at every supported aspect ratio.
func resize_view(view_size: Vector2) -> void:
	_aspect = maxf(0.1, view_size.x / maxf(1.0, view_size.y))
	if camera != null:
		_frame_camera()


## Pick the rendered relic or its billboard number, using this viewport's
## camera. No physics layer, hidden answer or second set of puzzle coordinates.
func pick_relic(screen_position: Vector2) -> Dictionary:
	if not is_instance_valid(_mechanism) or _arrival < 1.0 or _departure > 0.0:
		return {}
	var nearest := INF
	var picked: MeshInstance3D
	for label in _pick_labels:
		if camera.is_position_behind(label.global_position):
			continue
		var bounds := label.get_aabb()
		var scale := label.global_basis.get_scale()
		var a := camera.unproject_position(label.global_position
			+ camera.global_basis.x * bounds.position.x * scale.x
			+ camera.global_basis.y * bounds.position.y * scale.y)
		var b := camera.unproject_position(label.global_position
			+ camera.global_basis.x * bounds.end.x * scale.x
			+ camera.global_basis.y * bounds.end.y * scale.y)
		if Rect2(a.min(b), (b - a).abs()).has_point(screen_position):
			var distance := screen_position.distance_squared_to(
				camera.unproject_position(label.global_position)
			)
			if distance < nearest:
				nearest = distance
				picked = _pick_labels[label]
	if picked != null:
		return picked.get_meta("relic_target")
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	for mesh in _pick_meshes:
		var inverse := mesh.global_transform.affine_inverse()
		var local_origin := inverse * origin
		var local_direction := inverse.basis * direction
		if mesh.mesh.get_aabb().grow(0.05).intersects_ray(
			local_origin, local_direction
		) == null:
			continue
		if not _pick_faces.has(mesh.mesh):
			_pick_faces[mesh.mesh] = mesh.mesh.get_faces()
		var faces := _pick_faces[mesh.mesh]
		# A mushroom's empty bounding-box corners must not hide the next walkway.
		for face in range(0, faces.size(), 3):
			var hit: Variant = Geometry3D.ray_intersects_triangle(
				local_origin, local_direction, faces[face], faces[face + 1], faces[face + 2]
			)
			if hit == null:
				continue
			var local_hit: Vector3 = hit
			var distance := origin.distance_squared_to(mesh.to_global(local_hit))
			if distance < nearest:
				nearest = distance
				picked = mesh
	return picked.get_meta("relic_target") if picked != null else {}


## A deliberate hop must settle before another graph edge is taken.
func is_walking_walkway() -> bool:
	return _garden_in_motion


func _build_materials() -> void:
	_painted_material = Palette.painted_material()


func _build_ambience() -> void:
	for side in [-1.0, 1.0]:
		var at := Vector3(side * 7.7, 0.1, -2.6)
		_painted(_stage, Models.mesh(&"lamp"), at)
		_torch_lights.append(_light(_stage, at + Vector3.UP * 1.4, Palette.FIRE, 2.0, 9.0))
		_painted(_stage, Models.mesh(&"candles"), Vector3(side * 6.8, 0.1, 3.6))
		_painted(_stage, Models.mesh(&"relics"), Vector3(side * 6.1, 0.1, 5.0))
	_floor_seal = _mesh(_stage, Models.mesh(&"seal"), Vector3(0, 0.09, 0), Palette.ARCANE)
	_floor_seal.scale = Vector3.ONE * 2.65
	_floor_seal.material_override = _glow_material(Color(Palette.ARCANE, 0.28))
	_motes = _particle_mesh(24, Palette.GOLD)
	_sparks = _particle_mesh(28, Palette.ARCANE)
	_sparks.hide()


func _build_constellation() -> void:
	_engine = Node3D.new()
	_engine.position = CORE_POSITION
	_stage.add_child(_engine)
	_painted(_engine, Models.mesh(&"orrery"), Vector3.ZERO)
	_core_light = _light(_stage, CORE_POSITION + Vector3(0, 0, 1), Palette.ARCANE, 1.0, 9.0)
	_halo = _mesh(_stage, Models.mesh(&"seal"), CORE_POSITION, Palette.GOLD)
	_halo.rotation.x = PI * 0.5
	_halo.material_override = _glow_material(Color(Palette.VIOLET, 0.5))
	for index in range(STAR_POSITIONS.size()):
		var star := _painted(_stage, Models.mesh(&"keystone"), STAR_POSITIONS[index], false)
		_stars.append(star)
		_label(star, "%d  %s" % [index + 1, Options.RELICS[index]["badge"]],
			Vector3.UP * 0.8, Palette.CREAM, 0.009)
		var link := _box(_stage, Vector3(0.045, 0.045, 1), Vector3.ZERO, Palette.BRASS)
		_links.append(link)
	_offering = _painted(_stage, Models.mesh(&"keystone"), Vector3.ZERO, false)
	_offering.hide()
	_present_constellation([])


func _build_keeper() -> void:
	_player = Node3D.new()
	_player.name = "Keeper"
	_player.position = GUIDE_POSITION
	_stage.add_child(_player)
	_player_visual = Node3D.new()
	_player_visual.name = "KeeperModel"
	_player.add_child(_player_visual)
	_keeper_mesh = _painted(_player_visual, Models.keeper_outfit(_outfit_id), Vector3.ZERO)
	_player_label = _label(_player, "P1",
		Vector3(0, _keeper_mesh.mesh.get_aabb().end.y + 0.22, 0), Palette.CREAM, 0.009)


func _clear_mechanism() -> void:
	_pick_meshes.clear()
	_pick_labels.clear()
	_pick_faces.clear()
	if is_instance_valid(_mechanism):
		_stage.remove_child(_mechanism)
		_mechanism.queue_free()
	_mechanism = null
	_frame = null
	_record_label = null
	_needle = null
	_whisper_orb = null
	_puzzle_light = null
	_solar_cells.clear()
	_tiles.clear()
	_floor_meshes.clear()
	_floor_labels.clear()
	_garden_tiles.clear()
	_garden_labels.clear()
	_rune_ages.clear()
	_wardens.clear()
	_warden_targets.clear()
	_warden_pylons.clear()
	_warden_labels.clear()
	_warden_beam = null
	_islands.clear()
	_network_runes.clear()
	_network_labels.clear()
	_bridge_sockets.clear()
	_bridge_meshes.clear()
	_bridge_lines.clear()
	_bridge_pulses.clear()
	_bridge_edges.clear()
	_bridge_ages.clear()
	_stair_tiles.clear()
	_stair_labels.clear()
	_stair_links.clear()
	_stair_ages.clear()
	_stair_focus = null
	_stair_selected = -1
	_garden_in_motion = false
	_garden_step = 1.0
	_action_pulse = 0.0
	_spark_time = 0.0
	_puzzle_energy = 1.0


func _build_sunrail(state: Sunrail) -> void:
	_rail_width = 13.3 / float(state.tiles.size())
	_painted(_mechanism, Models.block(Vector3(14.3, 0.24, 1.8), Palette.STONE_DARK),
		Vector3(0, 0.16, -0.4), false)
	for index in range(state.tiles.size()):
		var holder := Node3D.new()
		holder.position = Vector3(_rail_x(index, state.tiles.size()), 0.24, -0.4)
		_mechanism.add_child(holder)
		_solar_cells.append(holder)
		var height := 0.25 + absf(state.tiles[index]) * 0.12
		var crystal := _painted(holder, Models.solar_cell(height, state.tiles[index] < 0),
			Vector3.ZERO)
		crystal.scale.x = _rail_width * 0.9
		crystal.set_meta("relic_target", {"selection": mini(index, state.tiles.size() - state.width)})
		_pick_meshes.append(crystal)
		_tiles.append(_mesh(holder, Models.mesh(&"rune"), Vector3(0, 0.23, 0), Palette.BLUE))
		_tiles[index].scale = Vector3(_rail_width * 0.75, 1, 0.85)
		var number := _label(holder, str(state.tiles[index]), Vector3(0, height + 0.47, 0),
			Palette.CREAM, 0.012)
		_pick_labels[number] = crystal
		_label(_mechanism, str(index + 1),
			Vector3(holder.position.x, 0.3, 0.85), Palette.GOLD, 0.007)
	_frame = Node3D.new()
	_frame.position = Vector3(0, 2.5, -0.4)
	_mechanism.add_child(_frame)
	var span := _rail_width * state.width
	for edge in [-1.0, 1.0]:
		_painted(_frame, Models.block(Vector3(span, 0.12, 0.12), Palette.BRASS),
			Vector3(0, 0, edge * 0.88))
		_painted(_frame, Models.block(Vector3(0.12, 0.12, 1.88), Palette.BRASS),
			Vector3(edge * span * 0.5, 0, 0))
		var tether := _box(_frame, Vector3(0.025, 2.1, 0.025),
			Vector3(edge * span * 0.5, -1.0, 0.88), Palette.ARCANE)
		tether.material_override = _glow_material(Color(Palette.ARCANE, 0.6))
	_mesh(_frame, Models.mesh(&"rune"), Vector3(0, 0.04, 0), Palette.GOLD).material_override = (
		_glow_material(Palette.GOLD)
	)
	_puzzle_light = _light(_frame, Vector3(0, 0.8, 0), Palette.ARCANE, 1.4, 7.0)
	_record_label = _label(_mechanism, "", Vector3(0, 0.65, 2.2), Palette.GOLD, 0.012)


func _build_shaft(state: Shaft) -> void:
	var well := CylinderMesh.new()
	well.top_radius = 1.1
	well.bottom_radius = 1.35
	well.height = 0.35
	well.radial_segments = 24
	_mesh(_mechanism, well, Vector3(0, 0.26, 0), Palette.INK)
	_mesh(_mechanism, Models.mesh(&"seal"), Vector3(0, 0.5, 0), Palette.GOLD).material_override = (
		_glow_material(Color(Palette.VIOLET, 0.8))
	)
	for index in range(state.floor_count):
		var angle := _floor_angle(index + 1, state.floor_count)
		var at := Vector3(cos(angle) * 4.7, 0.25, sin(angle) * 4.7)
		var pad := _painted(_mechanism, Models.mesh(&"garden_step"), at, false)
		pad.scale = Vector3.ONE * 0.68
		pad.set_meta("relic_target", {"selection": index + 1})
		_pick_meshes.append(pad)
		_floor_meshes.append(_mesh(_mechanism, Models.mesh(&"rune"),
			at + Vector3.UP * 0.17, Palette.GOLD))
		_floor_meshes[index].scale = Vector3.ONE * 0.65
		_floor_labels.append(_label(_mechanism, str(index + 1), at + Vector3.UP * 0.64,
			Palette.CREAM, 0.009 if state.floor_count <= 15 else 0.0075))
		_pick_labels[_floor_labels[index]] = pad
	_needle = Node3D.new()
	_needle.position.y = 0.55
	_mechanism.add_child(_needle)
	var ray := _box(_needle, Vector3(4.2, 0.055, 0.055), Vector3(2.1, 0, 0), Palette.GOLD)
	ray.material_override = _glow_material(Palette.GOLD)
	_whisper_orb = _painted(_mechanism, Models.mesh(&"keystone"), Vector3(0, 1.6, 0), false)
	_whisper_orb.scale = Vector3.ONE * 1.25
	_puzzle_light = _light(_mechanism, Vector3(0, 2.0, 0), Palette.VIOLET, 1.3, 8.0)
	_record_label = _label(_mechanism, "", Vector3(0, 0.7, 6.0), Palette.GOLD, 0.011)


func _build_garden(state: Garden) -> void:
	_garden_size = Vector2i(state.rows[0].length(), state.rows.size())
	for y in range(_garden_size.y):
		for x in range(_garden_size.x):
			var cell := Vector2i(x, y)
			var at := _cell_position(cell)
			if not state.is_open(cell):
				var wall := _painted(_mechanism, Models.mesh(&"garden_wall"), at)
				wall.set_meta("relic_target", {"cell": cell})
				_pick_meshes.append(wall)
				continue
			var pad := _painted(_mechanism, Models.mesh(&"garden_step"), at, false)
			pad.set_meta("relic_target", {"cell": cell})
			_pick_meshes.append(pad)
			_garden_tiles[cell] = _mesh(_mechanism, Models.mesh(&"rune"),
				at + Vector3.UP * 0.2, Palette.BLUE)
			_garden_labels[cell] = _label(_mechanism, "?", at + Vector3.UP * 0.67,
				Palette.CREAM, 0.009 if cell == state.goal else 0.011)
			_pick_labels[_garden_labels[cell]] = pad
			for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
				if state.is_open(cell + direction):
					var bridge := _painted(_mechanism, Models.mesh(&"bridge"),
						at.lerp(_cell_position(cell + direction), 0.5), false)
					if direction == Vector2i.RIGHT:
						bridge.rotation.y = PI * 0.5
	_garden_target = _cell_position(state.player_cell) + Vector3.UP * 0.16
	_garden_from = _garden_target
	_player.position = _garden_target
	var goal := _cell_position(state.goal)
	var beacon := _painted(_mechanism, Models.mesh(&"keystone"), goal + Vector3(0.4, 0.7, -0.4), false)
	beacon.scale = Vector3.ONE * 0.65
	_puzzle_light = _light(_mechanism, goal + Vector3.UP * 1.8, Palette.VIOLET, 1.2, 7.5)


func _build_wardens(state: Wardens) -> void:
	_rail_width = 13.3 / float(state.values.size())
	_painted(_mechanism, Models.block(Vector3(14.3, 0.24, 1.8), Palette.STONE_DARK),
		Vector3(0, 0.16, -0.4), false)
	for index in range(state.values.size()):
		var holder := Node3D.new()
		holder.position = Vector3(_rail_x(index, state.values.size()), 0.24, -0.4)
		_mechanism.add_child(holder)
		_solar_cells.append(holder)
		var height := 0.35 + absf(state.values[index]) * 0.055
		var pylon := _painted(holder, Models.solar_cell(height, state.values[index] < 0), Vector3.ZERO)
		pylon.set_meta("relic_target", {"selection": index})
		_warden_pylons.append(pylon)
		_pick_meshes.append(pylon)
		_tiles.append(_mesh(holder, Models.mesh(&"rune"), Vector3(0, 0.23, 0), Palette.BLUE))
		var label := _label(holder, str(state.values[index]), Vector3(0, height + 0.55, 0),
			Palette.CREAM, 0.012)
		_warden_labels.append(label)
		_pick_labels[label] = pylon
	for index in range(2):
		var warden := Node3D.new()
		_mechanism.add_child(warden)
		_wardens.append(warden)
		_warden_targets.append(Vector3.ZERO)
		var drone := _painted(warden, Models.mesh(&"warden"), Vector3.ZERO)
		_pick_meshes.append(drone)
		var label := _label(warden, "LEFT" if index == 0 else "RIGHT",
			Vector3.UP * 0.8, Palette.GOLD, 0.009)
		_pick_labels[label] = drone
	_warden_beam = _box(_mechanism, Vector3(0.035, 0.035, 1), Vector3.ZERO, Palette.GOLD)
	_puzzle_light = _light(_mechanism, Vector3(0, 3, 0), Palette.ARCANE, 1.3, 8)
	_record_label = _label(_mechanism, "", Vector3(0, 0.65, 3.1), Palette.GOLD, 0.012)


func _build_archipelago(state: Archipelago) -> void:
	_bridge_edges.assign(state.sockets)
	for index in range(state.island_count):
		var at := ISLAND_POSITIONS[index]
		_islands.append(_painted(_mechanism, Models.mesh(&"island"), at))
		_network_runes.append(_mesh(_mechanism, Models.mesh(&"rune"), at + Vector3.UP * 0.32, Palette.GOLD))
		_network_labels.append(_label(_mechanism, "", at + Vector3.UP * 1.0, Palette.CREAM, 0.0105))
	for index in range(state.sockets.size()):
		var edge := state.sockets[index]
		var from := ISLAND_POSITIONS[edge.x]
		var to := ISLAND_POSITIONS[edge.y]
		var middle := from.lerp(to, 0.5)
		var bridge := _painted(_mechanism, Models.mesh(&"bridge"), middle, false)
		bridge.look_at(to, Vector3.UP)
		_bridge_meshes.append(bridge)
		var line := _box(_mechanism, Vector3(0.04, 0.04, 1), Vector3.ZERO, Palette.ARCANE)
		_place_link(line, from + Vector3.UP * 0.4, to + Vector3.UP * 0.4)
		_bridge_lines.append(line)
		var socket := _mesh(_mechanism, Models.mesh(&"rune"), middle + Vector3.UP * 0.45, Palette.GOLD)
		socket.set_meta("relic_target", {"selection": index})
		socket.scale = Vector3.ONE * 0.7
		_bridge_sockets.append(socket)
		_pick_meshes.append(socket)
		var label := _label(_mechanism, str(index + 1), middle + Vector3.UP * 1.0, Palette.CREAM, 0.009)
		_pick_labels[label] = socket
		var pulse := _mesh(_mechanism, Models.mesh(&"keystone"), middle, Palette.ARCANE)
		pulse.scale = Vector3.ONE * 0.13
		pulse.material_override = _glow_material(Palette.CREAM)
		_bridge_pulses.append(pulse)
	_puzzle_light = _light(_mechanism, Vector3(0, 2.5, 0), Palette.VIOLET, 1.35, 9)
	_record_label = _label(_mechanism, "", Vector3(0, 0.6, 5.4), Palette.GOLD, 0.01)


func _build_stair(state: Stair) -> void:
	for index in range(-1, state.costs.size()):
		var at := _stair_position(index)
		var landing := _painted(_mechanism, Models.mesh(&"memory_step"), at, false)
		landing.set_meta("relic_target", {"selection": index})
		_pick_meshes.append(landing)
		_stair_tiles.append(_mesh(_mechanism, Models.mesh(&"rune"), at + Vector3.UP * 0.2, Palette.BLUE))
		var label := _label(_mechanism, "", at + Vector3.UP * 1.05, Palette.CREAM, 0.0105)
		_stair_labels.append(label)
		_pick_labels[label] = landing
		if index >= 0:
			var support := _painted(_mechanism,
				Models.block(Vector3(0.7, at.y, 0.7), Palette.STONE_DARK),
				Vector3(at.x, at.y * 0.5 - 0.12, at.z), false)
			support.name = "StairSupport%d" % index
	_garden_target = _stair_position(-1) + Vector3.UP * 0.2
	_garden_from = _garden_target
	_player.position = _garden_target
	for index in range(2):
		_stair_links.append(_box(_mechanism, Vector3(0.04, 0.04, 1), Vector3.ZERO, Palette.GOLD))
	_stair_focus = _painted(_mechanism, Models.mesh(&"keystone"), Vector3.ZERO, false)
	_stair_focus.scale = Vector3.ONE * 0.55
	_puzzle_light = _light(_mechanism, Vector3(1, 4, 0), Palette.GOLD, 1.4, 9)
	_record_label = _label(_mechanism, "", Vector3(0, 0.7, 4.8), Palette.GOLD, 0.01)


func _present_sunrail(state: Sunrail) -> void:
	_selected_from = state.start_index
	_selected_width = state.width
	for index in range(_tiles.size()):
		var selected := index >= state.start_index and index < state.start_index + state.width
		_tiles[index].material_override = _glow_material(Palette.GOLD if selected else (
			Palette.RED if state.tiles[index] < 0 else Palette.BLUE
		))
	_frame_target = _rail_x(state.start_index, state.tiles.size())
	_frame_target += _rail_width * float(state.width - 1) * 0.5
	if _reduced_motion or state.phase == State.Phase.SOLVED:
		_frame.position.x = _frame_target
	_record_label.text = "CHARGE %d   /   RECORD %d" % [state.charge, state.best_charge]


func _present_shaft(state: Shaft) -> void:
	for index in range(_floor_meshes.size()):
		var number := index + 1
		var open := number >= state.lower_bound and number <= state.upper_bound
		_floor_meshes[index].material_override = (
			_glow_material(Palette.GOLD) if open else _material(Palette.INK)
		)
		_floor_labels[index].text = "%d%s" % [number, "" if open else " X"]
	_needle_target = -_floor_angle(state.selected_floor, state.floor_count)
	if _reduced_motion:
		_needle.rotation.y = _needle_target
	_record_label.text = "FLOOR %d   /   OPEN %d-%d" % [
		state.selected_floor, state.lower_bound, state.upper_bound,
	]


func _present_garden(state: Garden) -> void:
	for cell in _garden_tiles:
		var reached := state.distances.has(cell)
		if reached and not _rune_ages.has(cell):
			_rune_ages[cell] = 0.0
		elif not reached:
			_rune_ages.erase(cell)
		_garden_tiles[cell].material_override = _glow_material(
			Palette.GOLD if reached else Palette.BLUE
		)
		var mark := str(state.distances[cell]) if reached else "?"
		_garden_labels[cell].text = "EXIT %s" % mark if cell == state.goal else mark
	_move_keeper(_cell_position(state.player_cell) + Vector3.UP * 0.16, state.moves_used == 0)


func _move_keeper(next: Vector3, reset: bool) -> void:
	if not next.is_equal_approx(_garden_target):
		_garden_from = _player.position
		_garden_target = next
		_garden_step = 0.0
		var direction := next - _garden_from
		_player_visual.rotation.y = atan2(direction.x, direction.z)
		_garden_in_motion = true
	if _reduced_motion or reset:
		_garden_step = 1.0
		_update_keeper_step()


func _present_wardens(state: Wardens) -> void:
	_selected_from = state.left_index
	_selected_width = state.right_index - state.left_index + 1
	for index in range(_warden_pylons.size()):
		var open := index >= state.left_index and index <= state.right_index
		var endpoint := index == state.left_index or index == state.right_index
		_warden_pylons[index].material_override = _painted_material if open else _material(Palette.STONE_DARK)
		_warden_labels[index].text = "%d%s" % [state.values[index], "" if open else " X"]
		_tiles[index].material_override = _glow_material(
			Palette.GOLD if endpoint else (Palette.BLUE if open else Palette.INK)
		)
	for index in range(_wardens.size()):
		var endpoint := state.left_index if index == 0 else state.right_index
		_warden_targets[index] = Vector3(
			_rail_x(endpoint, state.values.size()),
			2.4 if index == 0 else 1.1, -1.65 if index == 0 else 1.9
		)
		(_wardens[index].get_child(0) as MeshInstance3D).set_meta("relic_target", {"selection": endpoint})
	if _reduced_motion or state.moves_used == 0 or state.phase == State.Phase.SOLVED:
		_settle_algorithm_markers()
	_warden_beam.material_override = _glow_material(
		Palette.GOLD if state.charge == state.target_charge else Palette.VIOLET
	)
	_record_label.text = "%d + %d = %d   /   TARGET %d" % [
		state.values[state.left_index], state.values[state.right_index], state.charge, state.target_charge,
	]


func _present_archipelago(state: Archipelago) -> void:
	for island in range(state.island_count):
		var component := state.component(island)
		_network_runes[island].material_override = _glow_material(NETWORK_COLORS[component])
		_network_labels[island].text = "ISLAND %d\nNET %d" % [island + 1, component + 1]
	for index in range(_bridge_meshes.size()):
		var built := state.bridges.has(index)
		if built and not _bridge_ages.has(index):
			_bridge_ages[index] = 1.0 if _reduced_motion else 0.0
		elif not built:
			_bridge_ages.erase(index)
		_bridge_meshes[index].visible = built
		var edge := state.sockets[index]
		var color := NETWORK_COLORS[state.component(edge.x)] if built else Palette.BLUE
		_bridge_lines[index].material_override = _glow_material(Color(color, 0.8 if built else 0.22))
		_bridge_sockets[index].material_override = _glow_material(
			Palette.GOLD if index == state.selected_bridge else color
		)
		_bridge_sockets[index].scale = Vector3.ONE * (0.9 if index == state.selected_bridge else 0.7)
	_record_label.text = "NETWORKS %d / %d   |   BRIDGES %d / %d" % [
		state.components, state.island_count, state.bridges.size(), state.bridge_limit,
	]
	_update_algorithm_magic()


func _present_stair(state: Stair) -> void:
	_stair_labels[0].text = "START\nBEST\n0"
	_stair_selected = (
		state.player_step if state.phase == State.Phase.SOLVED else (
			state.player_step + state.selected_stride if state.records_complete
			else state.records.size() - state.selected_stride
		)
	)
	for index in range(state.costs.size()):
		var known := index < state.records.size()
		if known and not _stair_ages.has(index):
			_stair_ages[index] = 1.0 if _reduced_motion else 0.0
		elif not known:
			_stair_ages.erase(index)
		_stair_labels[index + 1].text = "FEE %d\nBEST\n%s" % [
			state.costs[index], str(state.records[index]) if known else "?",
		]
	for index in range(-1, state.costs.size()):
		_stair_tiles[index + 1].material_override = _glow_material(
			Palette.GOLD if index == _stair_selected else (
				Palette.ARCANE if index < state.records.size() else Palette.BLUE
			)
		)
	var focus := state.player_step if state.records_complete else state.records.size()
	_stair_focus_target = _stair_position(focus) + Vector3.UP * 1.85
	_stair_focus.visible = not state.records_complete
	for index in range(2):
		var other := focus + (index + 1) * (1 if state.records_complete else -1)
		var link := _stair_links[index]
		link.visible = other >= -1 and other < state.costs.size() and state.phase != State.Phase.SOLVED
		if link.visible:
			_place_link(link, _stair_position(focus) + Vector3.UP * 0.4,
				_stair_position(other) + Vector3.UP * 0.4)
			link.material_override = _glow_material(
				Palette.GOLD if index + 1 == state.selected_stride else Color(Palette.ARCANE, 0.35)
			)
	_move_keeper(_stair_position(state.player_step) + Vector3.UP * 0.2, state.moves_used == 0)
	if _reduced_motion:
		_settle_algorithm_markers()
	_record_label.text = (
		"ENERGY %d / %d   |   SUMMIT %d" % [state.energy_used, state.energy_budget, state.costs.size()]
		if state.records_complete else "REMEMBER %d / %d   |   FEE + CHEAPEST PREDECESSOR" % [
			state.records.size(), state.costs.size(),
		]
	)
	_update_algorithm_magic()


func _present_constellation(lit: Array[StringName]) -> void:
	_lit_count = lit.size()
	for index in range(_stars.size()):
		var restored := lit.has(Options.RELICS[index]["id"])
		_stars[index].material_override = (
			_painted_material if restored else _material(Palette.STONE_DARK)
		)
		var next := (index + 1) % _stars.size()
		var connected := restored and lit.has(Options.RELICS[next]["id"])
		_links[index].material_override = _glow_material(
			Color(Palette.GOLD, 0.85) if connected else Color(Palette.BLUE, 0.22)
		)
	_update_links()


func _apply_mechanism_pose() -> void:
	if not is_instance_valid(_mechanism):
		return
	var opening := smoothstep(0.0, 1.0, _arrival)
	var closing := smoothstep(0.0, 1.0, _departure)
	if _reduced_motion:
		_mechanism.scale = Vector3.ONE
		_mechanism.position.y = 0.0
	else:
		var scale_y := maxf(0.01, opening * (1.0 - closing))
		_mechanism.scale = Vector3(lerpf(0.92, 1.0, opening), scale_y, lerpf(0.92, 1.0, opening))
		_mechanism.position.y = -(1.0 - opening + closing) * 0.28
	_mechanism.visible = _departure < 1.0


func _update_keeper_step() -> void:
	var progress := smoothstep(0.0, 1.0, _garden_step)
	_player.position = _garden_from.lerp(_garden_target, progress)
	if not _reduced_motion:
		_player.position.y += sin(progress * PI) * 0.24
	_garden_in_motion = _garden_step < 1.0


func _update_offering() -> void:
	if not is_instance_valid(_offering):
		return
	_offering.visible = _restoration >= 0.0 and _restoration < 1.0 and not _reduced_motion
	if not _offering.visible:
		return
	var t := smoothstep(0.0, 1.0, _restoration)
	var middle := Vector3(0, 6.8, -1.5)
	_offering.position = (
		_offering_start * (1.0 - t) * (1.0 - t)
		+ middle * 2.0 * t * (1.0 - t) + _offering_end * t * t
	)
	_offering.rotation = Vector3(t * PI, t * TAU, 0)


func _update_magic() -> void:
	if not is_instance_valid(_engine):
		return
	var animated := not _reduced_motion
	var particles_enabled := animated and _intense_effects
	var gathering := (
		smoothstep(0.0, 0.65, _finale) if animated else (1.0 if _in_finale else 0.0)
	)
	_engine.rotation.y = ambient_angle
	_engine.position = CORE_POSITION.lerp(Vector3(0, 2.7, 0), gathering)
	if animated:
		_engine.position.y += sin(_effects_time * 0.8) * 0.08
	_engine.scale = Vector3.ONE * lerpf(1.0, 1.9, gathering)
	_halo.position = _engine.position
	_halo.scale = _engine.scale
	_halo.rotation.z = -ambient_angle * 0.4
	_floor_seal.scale = Vector3.ONE * (2.65 + gathering * 0.3)
	_floor_seal.rotation.y = ambient_angle * 0.18
	_core_light.position = _engine.position + Vector3(0, 0, 1)
	_core_light.light_energy = 0.8 + _lit_count * 0.25
	if particles_enabled and _in_finale:
		_core_light.light_energy += sin(_finale * PI) * 0.35
	for index in range(_stars.size()):
		_stars[index].position = STAR_POSITIONS[index].lerp(FINALE_STARS[index], gathering)
		if animated:
			_stars[index].position.y += sin(_effects_time * 0.9 + index * 1.7) * 0.07
			_stars[index].rotation.y = ambient_angle * (1.0 if index % 2 == 0 else -1.0)
		else:
			_stars[index].rotation = Vector3.ZERO
	_update_links()
	for index in range(_torch_lights.size()):
		_torch_lights[index].light_energy = 2.0 * (
			1.0 + sin(_effects_time * 1.7 + index * 2.3) * 0.055 if particles_enabled else 1.0
		)
	var pulse := sin(_action_pulse / 0.55 * PI) if animated else 0.0
	if is_instance_valid(_puzzle_light):
		_puzzle_light.light_energy = _puzzle_energy + (pulse * 0.22 if particles_enabled else 0.0)
	for index in range(_solar_cells.size()):
		var selected := index >= _selected_from and index < _selected_from + _selected_width
		_solar_cells[index].position.y = 0.24 + (0.12 if selected else 0.0)
		if animated:
			_solar_cells[index].position.y += sin(_effects_time * 1.25 + index * 0.65) * 0.065
	if is_instance_valid(_frame):
		_frame.scale = Vector3.ONE * (1.0 + pulse * 0.035)
	if is_instance_valid(_whisper_orb):
		_whisper_orb.position.y = 1.6 + (sin(_effects_time * 1.1) * 0.12 if animated else 0.0)
		_whisper_orb.position.y += _whisper_direction * pulse * 0.45
		_whisper_orb.rotation.y = ambient_angle
	for cell in _garden_tiles:
		var swell := sin(_rune_ages.get(cell, 1.0) * PI) * 0.16 if animated else 0.0
		_garden_tiles[cell].scale = Vector3.ONE * (1.0 + swell)
		_garden_tiles[cell].position.y = _cell_position(cell).y + 0.2 + swell * 0.55
	_update_algorithm_magic()
	_motes.visible = particles_enabled
	if particles_enabled:
		for index in range(_motes.multimesh.instance_count):
			var phase := float(index) * 2.399 + _effects_time * 0.08
			var at := Vector3(
				cos(phase) * (3.0 + float(index % 4)),
				0.8 + float(index % 5) * 0.48 + sin(_effects_time * 0.45 + phase) * 0.22,
				sin(phase) * 5.0
			)
			_motes.multimesh.set_instance_transform(index, Transform3D(
				Basis.from_scale(Vector3.ONE * 0.025), at
			))
	_sparks.visible = particles_enabled and _spark_time > 0.0
	if _sparks.visible:
		var elapsed := 1.0 - _spark_time / 1.2
		for index in range(_sparks.multimesh.instance_count):
			var angle := float(index) * 2.399
			var drift := Vector3(cos(angle), 0.7 + float(index % 4) * 0.2, sin(angle))
			_sparks.multimesh.set_instance_transform(index, Transform3D(
				Basis.from_scale(Vector3.ONE * (1.0 - elapsed) * 0.065),
				_spark_origin + drift * elapsed * 2.6
			))


func _update_algorithm_magic() -> void:
	var animated := not _reduced_motion
	for index in range(_wardens.size()):
		var drone := _wardens[index].get_child(0) as Node3D
		drone.position.y = sin(_effects_time * 1.7 + index * PI) * 0.1 if animated else 0.0
		drone.rotation.z = sin(_effects_time * 1.2 + index * PI) * 0.05 if animated else 0.0
	if is_instance_valid(_warden_beam):
		_place_link(_warden_beam, _wardens[0].position, _wardens[1].position)
	for index in range(_islands.size()):
		_islands[index].position.y = ISLAND_POSITIONS[index].y + (
			sin(_effects_time * 0.8 + index) * 0.045 if animated else 0.0
		)
	for index in range(_bridge_meshes.size()):
		var edge := _bridge_edges[index]
		var from := ISLAND_POSITIONS[edge.x]
		var to := ISLAND_POSITIONS[edge.y]
		var growth := smoothstep(0.0, 1.0, _bridge_ages.get(index, 0.0)) if animated else 1.0
		_bridge_meshes[index].scale = Vector3(1, maxf(0.05, growth),
			maxf(0.001, (from.distance_to(to) - 1.4) / 0.72 * growth))
		_bridge_pulses[index].visible = animated and _intense_effects and _bridge_ages.has(index)
		if _bridge_pulses[index].visible:
			var travel := fmod(_effects_time * 0.6 + index * 0.17, 1.0)
			_bridge_pulses[index].position = from.lerp(to, travel) + Vector3.UP * (
				0.4 + sin(travel * PI) * 0.25
			)
	for index in range(_stair_tiles.size()):
		var swell := sin(_stair_ages.get(index - 1, 1.0) * PI) * 0.18 if animated else 0.0
		_stair_tiles[index].scale = Vector3.ONE * (
			1.1 if index - 1 == _stair_selected else 1.0
		) * (1.0 + swell)
	if is_instance_valid(_stair_focus):
		_stair_focus.rotation.y = ambient_angle


func _settle_algorithm_markers() -> void:
	for index in range(_wardens.size()):
		_wardens[index].position = _warden_targets[index]
	if is_instance_valid(_stair_focus):
		_stair_focus.position = _stair_focus_target


func _relic_origin() -> Vector3:
	match stage_id:
		&"sunrail":
			return Vector3(_frame_target, 2.4, -0.4)
		&"shaft", &"archipelago":
			return Vector3(0, 1.9, 0)
		&"garden", &"stair":
			return _garden_target + Vector3.UP * 1.4
		&"wardens":
			return _warden_targets[0].lerp(_warden_targets[1], 0.5)
	return _player.position + Vector3.UP * 1.4


func _update_links() -> void:
	for index in range(_links.size()):
		var start := _stars[index].position
		var end := _stars[(index + 1) % _stars.size()].position
		_place_link(_links[index], start, end)


func _place_link(link: MeshInstance3D, start: Vector3, end: Vector3) -> void:
	(link.mesh as BoxMesh).size.z = start.distance_to(end)
	link.position = start.lerp(end, 0.5)
	if not start.is_equal_approx(end):
		link.basis = Basis.looking_at(end - start, Vector3.UP)


func _frame_camera() -> void:
	camera.position = Vector3(0, 18, 21)
	camera.look_at(Vector3(0, 1.2, 0))
	var inverse := camera.global_transform.affine_inverse()
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for index in range(8):
		var point: Vector3 = inverse * stage_bounds.get_endpoint(index)
		minimum = minimum.min(Vector2(point.x, point.y))
		maximum = maximum.max(Vector2(point.x, point.y))
	var center := (minimum + maximum) * 0.5
	camera.global_position += camera.global_basis.x * center.x + camera.global_basis.y * center.y
	var span := maximum - minimum
	camera.size = maxf(span.y, span.x / _aspect) * 1.05


func _light(
	parent: Node3D, at: Vector3, color: Color, energy: float, reach: float
) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.3
	light.shadow_enabled = false
	parent.add_child(light)
	light.position = at
	return light


func _particle_mesh(count: int, color: Color) -> MultiMeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 6
	mesh.rings = 2
	var particles := MultiMeshInstance3D.new()
	particles.multimesh = MultiMesh.new()
	particles.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	particles.multimesh.mesh = mesh
	particles.multimesh.instance_count = count
	particles.material_override = _glow_material(color)
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stage.add_child(particles)
	return particles


func _painted(
	parent: Node3D, mesh: ArrayMesh, at: Vector3, casts_shadow := true
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _painted_material
	instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts_shadow
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	parent.add_child(instance)
	instance.position = at
	return instance


func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, at, color)


func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	instance.position = at
	return instance


func _material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.85
		_materials[color] = material
	return _materials[color]


func _glow_material(color: Color) -> StandardMaterial3D:
	if not _glow_materials.has(color):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color
		if color.a < 1.0:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glow_materials[color] = material
	return _glow_materials[color]


func _label(
	parent: Node3D, text: String, at: Vector3, color: Color, pixel_size: float
) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.outline_size = 10
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_modulate = Palette.INK
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)
	label.position = at
	return label


func _rail_x(index: int, count: int) -> float:
	return (float(index) - float(count - 1) * 0.5) * _rail_width


func _floor_angle(number: int, count: int) -> float:
	return float(number - 1) * TAU / float(count) - PI * 0.5


func _cell_position(cell: Vector2i) -> Vector3:
	return Vector3(
		(float(cell.x) - float(_garden_size.x - 1) * 0.5) * CELL_SPACING,
		0.25,
		(float(cell.y) - float(_garden_size.y - 1) * 0.5) * CELL_SPACING
	)


func _stair_position(index: int) -> Vector3:
	var step := float(index + 1)
	return Vector3(-6.0 + step * 1.5, 0.25 + step * 0.22, 2.5 - step * 0.55)


func _relic_index(id: StringName) -> int:
	for index in range(Options.RELICS.size()):
		if Options.RELICS[index]["id"] == id:
			return index
	push_error("Unknown constellation seal '%s'." % id)
	return -1
