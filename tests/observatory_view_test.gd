extends SceneTree

## Real-window checks for every ritual act, its persistent stage and touch UI.
## Optional --creep-capture-dir=<absolute directory> saves the actual gameplay.

const Options = preload("res://games/creep_code/creep_code_options.gd")
const Manager = preload("res://games/creep_code/puzzle_manager.gd")
const Models = preload("res://games/creep_code/art/toy_models.gd")
const Sunrail = preload("res://games/creep_code/puzzles/sliding_window.gd")
const Shaft = preload("res://games/creep_code/puzzles/binary_search.gd")
const Garden = preload("res://games/creep_code/puzzles/breadth_first.gd")
const Wardens = preload("res://games/creep_code/puzzles/two_pointers.gd")
const Archipelago = preload("res://games/creep_code/puzzles/union_find.gd")
const Stair = preload("res://games/creep_code/puzzles/dynamic_programming.gd")
const State = preload("res://games/creep_code/puzzles/puzzle_state.gd")
const GAME := "res://games/creep_code/gameplay.tscn"
const FIXTURE := "res://games/creep_code/tests/expedition_fixture.gd"
const INTRO := "res://games/creep_code/intro.tscn"
const INTRO_FIXTURE := "res://games/creep_code/tests/intro_fixture.gd"

var _failures := PackedStringArray()
var _capture_dir := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Creep Code view tests require a real graphics window; omit --headless.")
		quit(1)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--creep-capture-dir="):
			_capture_dir = argument.trim_prefix("--creep-capture-dir=")
			if not _capture_dir.is_absolute_path():
				printerr("The capture directory must be absolute.")
				quit(1)
				return
			if DirAccess.make_dir_recursive_absolute(_capture_dir) != OK:
				printerr("Could not create the requested capture directory.")
				quit(1)
				return
	GameCatalog.select(Options.GAME_ID)
	get_root().get_node("GameSession").call("configure_single_player")
	var settings := get_root().get_node("Settings")
	var original_values := (settings.get("_values") as Dictionary).duplicate(true)
	var save_timer := settings.get("_save_timer") as Timer
	var previous_mode := save_timer.process_mode
	save_timer.process_mode = Node.PROCESS_MODE_DISABLED
	settings.call("set_value", Settings.REDUCED_MOTION_KEY, true)
	get_root().content_scale_size = Vector2i(1920, 1080)
	get_root().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_root().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var packed := load(GAME) as PackedScene
	var fixture := load(FIXTURE) as Script
	if packed == null or fixture == null or not fixture.can_instantiate():
		printerr("The Creep Code scene must compile before its graphics can be checked.")
		quit(1)
		return
	for resolution in [
		Vector2i(1280, 720), Vector2i(720, 1280), Vector2i(360, 640),
		Vector2i(640, 360), Vector2i(960, 540), Vector2i(1920, 720),
	]:
		get_root().size = resolution
		var game := packed.instantiate()
		game.set_script(fixture)
		get_root().add_child(game)
		await process_frame
		await process_frame
		game.set_process(false)
		game.set_process_unhandled_input(false)
		var view := game.get("_view") as Node
		view.set_process(false)
		var stage_instance := (view.get("_stage") as Node).get_instance_id()
		var core_instance := (view.get("_engine") as Node).get_instance_id()
		var manager: Manager = game.get("_manager")
		for definition in Options.RELICS:
			var id: StringName = definition["id"]
			_advance_to_puzzle(game)
			_expect(manager.current_id == id, "The actual timeline must mount %s next." % id)
			if id == &"garden":
				game.call("_on_action", Options.INTERACT)
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			_check_relic(game, id, resolution)
			await _check_picking(game, id, resolution)
			_expect((view.get("_stage") as Node).get_instance_id() == stage_instance
				and (view.get("_engine") as Node).get_instance_id() == core_instance,
				"Every rendered act must share the same physical dais and constellation.")
			if id == &"sunrail":
				await _check_grimoire(game, resolution)
				if resolution == Vector2i(1280, 720):
					await _check_outfits_on_stage(game)
			if id in [&"wardens", &"archipelago", &"stair"] and resolution == Vector2i(1280, 720):
				await _check_algorithm_magic(game, settings, id)
			_solve_relic(game)
			await process_frame
			await RenderingServer.frame_post_draw
			_check_draw_budget(game.get("_viewport") as SubViewport, id)
			if id == &"sunrail" and resolution == Vector2i(1280, 720):
				await _check_live_magic(game, settings)
		game.call("_update_round", 2.0, 0.0)
		game.call("_update_round", 2.0, 0.0)
		game.call("_update_round", 0.35, 0.0)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		_check_relic(game, &"finale", resolution)
		game.queue_free()
		await process_frame
	await _check_outfit_previews()
	await _check_outfit_shop()
	await _check_intro()
	var values := settings.get("_values") as Dictionary
	values.clear()
	values.merge(original_values, true)
	save_timer.stop()
	save_timer.process_mode = previous_mode
	await create_timer(0.15).timeout
	if _failures.is_empty():
		print("Creep Code observatory view tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _check_relic(game: Node, room: StringName, resolution: Vector2i) -> void:
	var viewport := game.get("_viewport") as SubViewport
	var view := game.get("_view") as Node3D
	var camera: Camera3D = view.get("camera")
	var bounds: AABB = view.get("stage_bounds")
	var texture := viewport.get_texture()
	var image := texture.get_image()
	_expect(not image.is_empty(), "The %s viewport must render an image at %s." % [room, resolution])
	_expect(viewport.get_render_info(
		Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_OBJECTS_IN_FRAME
	) > 8,
		"The %s viewport must draw actual props, not just the backdrop." % room)
	var painted: StandardMaterial3D = view.get("_painted_material")
	_expect(painted.vertex_color_use_as_albedo and painted.vertex_color_is_srgb
		and painted.roughness >= 0.9 and painted.albedo_texture != null
		and painted.uv1_triplanar and painted.uv1_world_triplanar,
		"Authored colours and world-space weathering must survive the matte material path.")
	var lights: Array = view.get("_torch_lights")
	_expect(lights.size() == 2 and view.get("_core_light") is OmniLight3D
		and (room == &"finale" or view.get("_puzzle_light") is OmniLight3D),
		"The stage must have real, bounded candle, constellation and relic lighting.")
	for light: OmniLight3D in lights:
		_expect(light.light_energy > 0.0 and not light.shadow_enabled,
			"Local lighting must remain useful with effects off and cheap on Compatibility.")
	var keeper := (view.get("_player_visual") as Node3D).get_child(0) as MeshInstance3D
	var outfit := StringName(str(get_root().get_node("Store").call(
		"equipped_id", Options.GAME_ID, Options.OUTFIT_SLOT
	)))
	_expect(keeper.mesh == Models.keeper_outfit(outfit) and keeper.material_override == painted,
		"The ritual guide must render the equipped outfit using the same painted finish.")
	_check_draw_budget(viewport, room)
	_expect((view.get("_stars") as Array).size() == Options.RELICS.size(),
		"Every playable relic must have its own real constellation socket.")
	if room == &"garden":
		var state := (game.get("_manager") as Manager).current()
		var goal: Vector2i = state.get("goal")
		var labels: Dictionary = view.get("_garden_labels")
		_expect((labels[goal] as Label3D).text.begins_with("EXIT "),
			"The exit word and distance must identify the actual goal tile, not float over a neighbor.")
	var varied := 0
	var background := image.get_pixel(1, 1)
	for y in range(1, 24):
		for x in range(1, 32):
			var color := image.get_pixel(image.get_width() * x / 32, image.get_height() * y / 24)
			if Vector3(color.r, color.g, color.b).distance_to(
				Vector3(background.r, background.g, background.b)
			) > 0.08:
				varied += 1
	_expect(varied > 0, "The %s viewport must contain visible 3D geometry, not only a background." % room)
	for index in range(8):
		var point := camera.unproject_position(bounds.get_endpoint(index))
		_expect(Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(2).has_point(point),
			"Camera framing must retain the full %s ritual at %s." % [room, resolution])
	var controls := game.get("_ritual_hud") as Control
	var dock := controls.get("_dock") as Control
	var visible_size := get_root().get_visible_rect().size
	var canvas := Rect2(Vector2.ZERO, visible_size)
	for key in [
		"_player_one_card", "_player_one_caption", "_player_one_score", "_time_label", "_time_caption",
	]:
		var control := game.get(key) as Control
		_expect(canvas.encloses(control.get_global_rect()),
			"The %s HUD must stay inside %s at %s (got %s)." % [
				key, canvas, resolution, control.get_global_rect(),
			])
	_expect(canvas.encloses(dock.get_global_rect()) and not controls is PanelContainer,
		"The unboxed action row must fit the canvas at %s." % resolution)
	_expect(not (controls.get("_book") as Control).visible,
		"Normal gameplay must not show any rules panel.")
	var container := game.get("_container") as Control
	_expect(not container.get_global_rect().intersects(dock.get_global_rect()),
		"The ritual stage must not overlap its touch controls.")
	_expect(container.size.x >= visible_size.x * 0.9,
		"The stage must use the full available width, not leave a hidden sidebar at %s." % resolution)
	_expect((game.get("_stage_input") as Control).get_global_rect() == container.get_global_rect(),
		"Input and rendering must share exactly the same viewport placement.")
	_expect(container.size.y >= visible_size.y * 0.3,
		"The stage must retain enough height for the keeper and mechanisms at %s." % resolution)
	var buttons: Dictionary = controls.get("_buttons")
	_expect(buttons.size() == 8, "Every gameplay action must have an on-screen control.")
	for button: Button in buttons.values():
		_expect(canvas.encloses(button.get_global_rect()),
			"Action buttons must stay visible without scrolling at %s." % resolution)
		var pixel_scale := float(resolution.y) / visible_size.y
		_expect(button.size.y * pixel_scale >= 43.9,
			"Every action must retain its 44-pixel touch height at %s." % resolution)
	if not _capture_dir.is_empty():
		var path := _capture_dir.path_join("%s_%dx%d.png" % [
			room, resolution.x, resolution.y,
		])
		_expect(get_root().get_texture().get_image().save_png(path) == OK,
			"Could not save the requested capture: %s" % path)


func _check_picking(game: Node, id: StringName, resolution: Vector2i) -> void:
	var view := game.get("_view") as Node3D
	var camera := view.get("camera") as Camera3D
	var labels: Dictionary = view.get("_pick_labels")
	var state := (game.get("_manager") as Manager).current()
	for label: Label3D in labels:
		var mesh := labels[label] as MeshInstance3D
		var point := camera.unproject_position(label.global_position)
		var picked: Dictionary = view.call("pick_relic", point)
		_expect(picked == mesh.get_meta("relic_target"),
			"Clicking rendered %s label '%s' must pick its own relic at %s (got %s)." % [
				id, label.text, resolution, picked,
			])
	for mesh: MeshInstance3D in view.get("_pick_meshes"):
		var target: Dictionary = mesh.get_meta("relic_target")
		if state is Garden and not state.is_open(target["cell"]):
			continue
		var bounds := mesh.mesh.get_aabb()
		var surface := bounds.get_center()
		if not (state is Sunrail or state is Wardens):
			surface.y = bounds.end.y
		var point := camera.unproject_position(mesh.to_global(surface))
		var picked: Dictionary = view.call("pick_relic", point)
		_expect(picked == target,
			"The exposed %s surface %s must be directly pickable at %s (got %s)." % [
				id, target, resolution, picked,
			])
	var target := {"selection": 2} if state is Sunrail else {"selection": 8}
	if state is Garden:
		var path: Array[Vector2i] = state.shortest_path()
		target = {"cell": path[1]}
	elif state is Wardens:
		target = {"selection": state.right_index}
	elif state is Archipelago:
		target = {"selection": 2}
	elif state is Stair:
		game.call("_on_action", Options.INTERACT)
		target = {"selection": -1}
	_click_relic(game, target)
	await process_frame
	if state is Sunrail:
		_expect(state.start_index == 2 and state.phase == State.Phase.READY,
			"A real GUI click must select, not arm, the crystal frame at %s." % resolution)
	elif state is Shaft:
		_expect(state.selected_floor == 8 and state.probes_used == 0,
			"A real GUI click must select a seal without spending a listen at %s." % resolution)
	elif state is Garden:
		_expect(state.moves_used == 1,
			"A real GUI click must take exactly one adjacent garden edge at %s." % resolution)
		game.call("_on_action", Options.RESET)
	elif state is Wardens:
		_expect(state.moves_used == 1 and state.right_index == state.values.size() - 2,
			"A real GUI endpoint click must discard exactly one pylon at %s." % resolution)
		game.call("_on_action", Options.RESET)
	elif state is Archipelago:
		_expect(state.selected_bridge == 2 and state.bridges.is_empty(),
			"A real socket click must select without building or spending a bridge at %s." % resolution)
	elif state is Stair:
		_expect(state.selected_stride == 2 and state.records.size() == 1 and state.energy_used == 0,
			"A real START click must choose a predecessor without inscribing or climbing at %s." % resolution)


func _check_draw_budget(viewport: SubViewport, id: StringName) -> void:
	var draws := viewport.get_render_info(
		Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME
	)
	var triangles := viewport.get_render_info(
		Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME
	)
	_expect(draws < 250 and triangles < 120000,
		"%s must stay within the existing diorama budget (%d draws, %d triangles)." % [
			id, draws, triangles,
		])


func _check_algorithm_magic(game: Node, settings: Node, id: StringName) -> void:
	var view := game.get("_view") as Node
	settings.call("set_value", Settings.REDUCED_MOTION_KEY, false)
	settings.call("set_value", Settings.VISUAL_EFFECTS_KEY, true)
	if id == &"wardens":
		game.call("_on_action", Options.RIGHT)
	elif id == &"archipelago":
		game.call("_on_selection_requested", 0)
		game.call("_on_action", Options.INTERACT)
	else:
		game.call("_on_action", Options.INTERACT)
	view.call("_process", 0.1)
	await process_frame
	await RenderingServer.frame_post_draw
	if id == &"wardens":
		var warden := (view.get("_wardens") as Array)[1] as Node3D
		_expect(warden.position != (view.get("_warden_targets") as Array)[1],
			"The rendered warden must fly toward, not teleport to, its new endpoint.")
	elif id == &"archipelago":
		var bridge := (view.get("_bridge_meshes") as Array)[0] as Node3D
		_expect(bridge.visible and bridge.scale.y > 0.05 and bridge.scale.y < 1.0
			and ((view.get("_bridge_pulses") as Array)[0] as Node3D).visible,
			"A rendered union must unfold bridge geometry and carry an actual 3D power pulse.")
	else:
		_expect(((view.get("_stair_tiles") as Array)[2] as Node3D).scale.x > 1.0
			and (view.get("_stair_focus") as Node3D).visible,
			"Newly remembered costs must bloom on the real stair beneath a moving focus crystal.")
	if not _capture_dir.is_empty():
		_expect(get_root().get_texture().get_image().save_png(
			_capture_dir.path_join("%s_motion_1280x720.png" % id)
		) == OK, "Could not capture the new relic's live animation.")
	game.call("_on_action", Options.BACK)
	var angle: float = view.get("ambient_angle")
	view.call("_process", 1.0)
	_expect(is_equal_approx(float(view.get("ambient_angle")), angle),
		"Reading the grimoire must freeze the rendered algorithm mechanisms.")
	game.call("_on_action", Options.INTERACT)
	settings.call("set_value", Settings.VISUAL_EFFECTS_KEY, false)
	_expect(not (view.get("_motes") as Node3D).visible,
		"Effects-off must suppress decoration on the new relics.")
	for pulse: Node3D in view.get("_bridge_pulses"):
		_expect(not pulse.visible, "Effects-off must also suppress every bridge energy particle.")
	settings.call("set_value", Settings.REDUCED_MOTION_KEY, true)
	view.call("_process", 1.0)
	_expect(is_zero_approx(float(view.get("ambient_angle"))),
		"Reduced motion must park the expanded constellation.")
	for index in range((view.get("_wardens") as Array).size()):
		_expect(((view.get("_wardens") as Array)[index] as Node3D).position
			== (view.get("_warden_targets") as Array)[index],
			"Reduced motion must settle both endpoint drones immediately.")
	for bridge: Node3D in view.get("_bridge_meshes"):
		if bridge.visible:
			_expect(is_equal_approx(bridge.scale.y, 1.0),
				"Reduced motion must present every built bridge fully unfolded.")
	settings.call("set_value", Settings.VISUAL_EFFECTS_KEY, true)
	game.call("_on_action", Options.RESET)


func _check_live_magic(game: Node, settings: Node) -> void:
	settings.call("set_value", Settings.REDUCED_MOTION_KEY, false)
	settings.call("set_value", Settings.VISUAL_EFFECTS_KEY, true)
	var view := game.get("_view") as Node
	view.call("play_feedback", &"success")
	game.call("_update_round", 0.5, 0.0)
	view.call("_process", 0.3)
	await process_frame
	await RenderingServer.frame_post_draw
	_expect((view.get("_motes") as MultiMeshInstance3D).visible
		and (view.get("_sparks") as MultiMeshInstance3D).visible,
		"Effects-on must render real motes and the solve constellation.")
	_expect(is_equal_approx((view.get("_frame") as Node3D).position.x, float(view.get("_frame_target"))),
		"A locked frame and its celebration must mark the actual winning crystals.")
	_expect((view.get("_offering") as Node3D).visible
		and not (view.get("_offering") as Node3D).position.is_equal_approx(view.get("_offering_end")),
		"A collected seal must be visibly flying toward its permanent constellation socket.")
	if not _capture_dir.is_empty():
		_expect(get_root().get_texture().get_image().save_png(
			_capture_dir.path_join("sunrail_restored_1280x720.png")
		) == OK, "Could not capture the live relay celebration.")
	settings.call("set_value", Settings.REDUCED_MOTION_KEY, true)


func _check_grimoire(game: Node, resolution: Vector2i) -> void:
	game.call("_on_action", Options.HINT)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var controls := game.get("_ritual_hud") as Control
	var book := controls.get("_book") as Control
	var scroll := controls.get("_scroll") as ScrollContainer
	var hint := controls.get("_feedback") as Label
	var canvas := Rect2(Vector2.ZERO, get_root().get_visible_rect().size)
	_expect(bool(game.get("_grimoire_open")) and book.visible
		and not (controls.get("_dock") as Control).visible and canvas.encloses(book.get_global_rect()),
		"A hint opens an on-demand book, not a persistent sidebar or overlapping control row.")
	_expect(scroll.get_global_rect().encloses(hint.get_global_rect()),
		"The first inscription must be fully readable at %s (scroll %s, hint %s)." % [
			resolution, scroll.get_global_rect(), hint.get_global_rect(),
		])
	var buttons: Dictionary = controls.get("_book_buttons")
	for button: Button in buttons.values():
		_expect(book.get_global_rect().encloses(button.get_global_rect()),
			"Reading must keep its close and next-hint actions visible at %s." % resolution)
	if not _capture_dir.is_empty():
		_expect(get_root().get_texture().get_image().save_png(
			_capture_dir.path_join("grimoire_%dx%d.png" % [resolution.x, resolution.y])
		) == OK, "Could not capture the grimoire.")
	game.call("_on_action", Options.INTERACT)


func _advance_to_puzzle(game: Node) -> void:
	for step in range(4):
		if game.get("_ritual_phase") == &"puzzle":
			return
		game.call("_update_round", 2.0, 0.0)
	_expect(game.get("_ritual_phase") == &"puzzle", "The timeline must reach a playable relic.")


func _solve_relic(game: Node) -> void:
	var manager: Manager = game.get("_manager")
	var state := manager.current()
	if state is Sunrail:
		for index in range(state.tiles.size() - state.width + 1):
			_click_relic(game, {"selection": index})
			if state.charge == state.maximum_charge:
				break
		game.call("_on_action", Options.INTERACT)
		game.call("_on_action", Options.INTERACT)
	elif state is Shaft:
		for attempt in range(state.probe_limit):
			if state.phase != State.Phase.ACTIVE:
				break
			_click_relic(game, {
				"selection": state.lower_bound + (state.upper_bound - state.lower_bound) / 2,
			})
			game.call("_on_action", Options.INTERACT)
	elif state is Garden:
		var path: Array[Vector2i] = state.shortest_path()
		for index in range(1, path.size()):
			_click_relic(game, {"cell": path[index]})
			(game.get("_view") as Node).call("_process", 1.0)
	elif state is Wardens:
		for move in range(state.values.size()):
			if state.charge == state.target_charge:
				break
			_click_relic(game, {
				"selection": state.left_index if state.charge < state.target_charge else state.right_index,
			})
		game.call("_on_action", Options.INTERACT)
	elif state is Archipelago:
		for index in range(5):
			_click_relic(game, {"selection": index})
			game.call("_on_action", Options.INTERACT)
	elif state is Stair:
		for index in range(state.records.size(), state.costs.size()):
			var one: int = state.records[index - 1] if index > 0 else 0
			var two: int = state.records[index - 2] if index > 1 else 0
			_click_relic(game, {"selection": index - (2 if index > 0 and two < one else 1)})
			game.call("_on_action", Options.INTERACT)
		var path: Array[int] = state.cheapest_path()
		for index in range(1, path.size()):
			_click_relic(game, {"selection": path[index]})
			game.call("_on_action", Options.INTERACT)
			(game.get("_view") as Node).call("_process", 1.0)
	_expect(state.phase == State.Phase.SOLVED,
		"The capture driver must solve %s through actual gameplay input." % manager.current_id)


func _check_outfits_on_stage(game: Node) -> void:
	var view := game.get("_view") as Node
	var previous: StringName = view.get("_outfit_id")
	var keeper := view.get("_keeper_mesh") as MeshInstance3D
	var instance := keeper.get_instance_id()
	for outfit in Models.KEEPER_OUTFITS:
		view.call("set_outfit", outfit)
		await process_frame
		await RenderingServer.frame_post_draw
		_expect(keeper.get_instance_id() == instance
			and keeper.mesh == Models.keeper_outfit(outfit),
			"Each outfit must dress the actual persistent keeper, not a shop-only model.")
		_expect((view.get("_player_label") as Node3D).position.y > keeper.mesh.get_aabb().end.y,
			"The P1 label must clear every costume's hat and equipment.")
		if not _capture_dir.is_empty():
			_expect(get_root().get_texture().get_image().save_png(
				_capture_dir.path_join("outfit_%s_stage.png" % outfit)
			) == OK, "Could not capture the equipped keeper.")
	view.call("set_outfit", previous)


func _check_outfit_previews() -> void:
	get_root().size = Vector2i(640, 640)
	var manifest := GameCatalog.get_manifest(Options.GAME_ID)
	var packed := load(manifest.store_preview_scene_path) as PackedScene
	for item in Options.STORE_ITEMS:
		var preview := packed.instantiate() as Control
		preview.call("configure", item)
		get_root().add_child(preview)
		await process_frame
		await process_frame
		var keeper := preview.get("_keeper") as MeshInstance3D
		var camera := preview.get("_camera") as Camera3D
		var viewport := preview.get("_viewport") as SubViewport
		var resting := keeper.rotation.y
		for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
			keeper.rotation.y = angle
			await process_frame
			for corner in range(8):
				var point := camera.unproject_position(
					keeper.to_global(keeper.mesh.get_aabb().get_endpoint(corner))
				)
				_expect(Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(1).has_point(point),
					"The entire %s outfit must fit throughout its turntable rotation." % item["id"])
		keeper.rotation.y = resting
		await process_frame
		await RenderingServer.frame_post_draw
		_expect(viewport.get_render_info(
			Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_OBJECTS_IN_FRAME
		) >= 2, "An outfit preview must render the actual keeper and its plinth.")
		_expect(viewport.get_render_info(
			Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME
		) < 20000, "The outfit portrait must stay within its Compatibility geometry budget.")
		if not _capture_dir.is_empty():
			_expect(viewport.get_texture().get_image().save_png(
				_capture_dir.path_join("outfit_%s_preview.png" % item["id"])
			) == OK, "Could not capture the full outfit preview.")
		preview.queue_free()
		await process_frame


func _check_outfit_shop() -> void:
	GameCatalog.restrict_to(Options.GAME_ID)
	var packed := load("res://scenes/menus/store.tscn") as PackedScene
	for resolution in [
		Vector2i(1280, 720), Vector2i(720, 1280), Vector2i(360, 640),
		Vector2i(640, 360), Vector2i(1920, 720),
	]:
		get_root().size = resolution
		var shop := packed.instantiate()
		shop.set("game_context_id", Options.GAME_ID)
		get_root().add_child(shop)
		await process_frame
		await process_frame
		var canvas := Rect2(Vector2.ZERO, get_root().get_visible_rect().size)
		var scroll := shop.get_node("Margins/Layout/Scroll") as ScrollContainer
		var cards: Array = shop.get("_cards")
		_expect(cards.size() == 4, "The real shop must display all four keeper looks.")
		_expect(canvas.grow(1).encloses(scroll.get_global_rect()),
			"The store's scrolling viewport must stay on screen at %s (got %s)." % [
				resolution, scroll.get_global_rect(),
			])
		var pixel_scale := float(resolution.x) / canvas.size.x
		for name in ["%Title", "%Balance", "%BackButton", "%Intro"]:
			_expect(canvas.encloses((shop.get_node(name) as Control).get_global_rect()),
				"The store's %s must remain on screen at %s." % [name, resolution])
		for card: Node in cards:
			var button := card.get("_buy_button") as Button
			if button == null:
				button = (card.get("_slot_buttons") as Array)[0] as Button
			scroll.ensure_control_visible(button)
			await process_frame
			await process_frame
			_expect(scroll.get_global_rect().grow(1).encloses(button.get_global_rect()),
				"Every outfit action must be reachable by scrolling at %s." % resolution)
			_expect(canvas.grow(1).encloses(button.get_global_rect()),
				"A scrolled outfit action must be on the actual screen at %s." % resolution)
			_expect(button.get_global_rect().size.y * pixel_scale >= 43.9,
				"The store must retain 44-pixel touch actions at %s." % resolution)
			var description := card.get("_description") as Label
			var font_pixels := float(description.get_theme_font_size("font_size"))
			font_pixels *= description.get_global_transform().get_scale().y * pixel_scale
			_expect(font_pixels >= 12,
				"Outfit descriptions must remain readable at native %s, not just fit a large canvas." % resolution)
			var preview := card.get("_preview_instance") as Node
			_expect((preview.get("_keeper") as MeshInstance3D).mesh
				== Models.keeper_outfit(StringName(str(card.call("item_id")))),
				"Every shop card must show its own outfit mesh.")
		scroll.scroll_vertical = 0
		await process_frame
		await RenderingServer.frame_post_draw
		if not _capture_dir.is_empty():
			_expect(get_root().get_texture().get_image().save_png(
				_capture_dir.path_join("store_%dx%d.png" % [resolution.x, resolution.y])
			) == OK, "Could not capture the outfit store.")
		shop.queue_free()
		await process_frame
	GameCatalog.clear_restriction()
	GameCatalog.select(Options.GAME_ID)


func _check_intro() -> void:
	var packed := load(INTRO) as PackedScene
	var fixture := load(INTRO_FIXTURE) as Script
	_expect(packed != null and fixture != null and fixture.can_instantiate(),
		"The opening must load before its layout is checked.")
	if packed == null or fixture == null or not fixture.can_instantiate():
		return
	for resolution in [
		Vector2i(1280, 720), Vector2i(720, 1280), Vector2i(360, 640),
		Vector2i(640, 360), Vector2i(1920, 720),
	]:
		get_root().size = resolution
		var intro := packed.instantiate()
		intro.set_script(fixture)
		get_root().add_child(intro)
		await process_frame
		intro.set_process(false)
		intro.call("_process", 10.5)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var stage := intro.get_node("%Stage") as SubViewportContainer
		var subtitle := intro.get_node("%Card") as Label
		var skip := intro.get_node("%SkipButton") as Button
		var canvas := Rect2(Vector2.ZERO, get_root().get_visible_rect().size)
		_expect(canvas.encloses(stage.get_global_rect()) and canvas.encloses(subtitle.get_global_rect())
			and canvas.encloses(skip.get_global_rect()),
			"The intro stage, regular subtitle and skip button must fit at %s." % resolution)
		_expect(not intro.has_node("Frame/Layout/Body/Narrative")
			and stage.size.x >= canvas.size.x * 0.99
			and subtitle.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
			"The intro must have a full-width stage and ordinary centered subtitles, not a narrative panel.")
		var viewport := stage.get_child(0) as SubViewport
		_expect(viewport.get_render_info(
			Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_OBJECTS_IN_FRAME
		) > 8, "The intro must show the same real 3D relics, not a flat placeholder.")
		if not _capture_dir.is_empty():
			_expect(get_root().get_texture().get_image().save_png(
				_capture_dir.path_join("intro_%dx%d.png" % [resolution.x, resolution.y])
			) == OK, "Could not capture the intro.")
		intro.queue_free()
		await process_frame


func _click_relic(game: Node, target: Dictionary) -> void:
	var view := game.get("_view") as Node3D
	var camera := view.get("camera") as Camera3D
	var viewport := game.get("_viewport") as SubViewport
	var input := game.get("_stage_input") as Control
	var labels: Dictionary = view.get("_pick_labels")
	for label: Label3D in labels:
		if (labels[label] as MeshInstance3D).get_meta("relic_target") != target:
			continue
		var point := camera.unproject_position(label.global_position)
		var local := point / Vector2(viewport.size) * input.size
		var event := InputEventMouseButton.new()
		event.position = input.get_global_transform_with_canvas() * local
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		get_root().push_input(event, true)
		event.pressed = false
		get_root().push_input(event, true)
		return
	_expect(false, "The visible relic must contain a clickable target for %s." % target)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
