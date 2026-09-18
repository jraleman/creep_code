extends SceneTree

## Real-scene coverage of one continuous ritual: input, timing, automatic
## handoffs, saved progress, replay and accessibility without touching a profile.

const Options = preload("res://games/creep_code/creep_code_options.gd")
const State = preload("res://games/creep_code/puzzles/puzzle_state.gd")
const Manager = preload("res://games/creep_code/puzzle_manager.gd")
const Sunrail = preload("res://games/creep_code/puzzles/sliding_window.gd")
const Shaft = preload("res://games/creep_code/puzzles/binary_search.gd")
const Garden = preload("res://games/creep_code/puzzles/breadth_first.gd")
const Wardens = preload("res://games/creep_code/puzzles/two_pointers.gd")
const Archipelago = preload("res://games/creep_code/puzzles/union_find.gd")
const Stair = preload("res://games/creep_code/puzzles/dynamic_programming.gd")
const GAME := "res://games/creep_code/gameplay.tscn"
const FIXTURE := "res://games/creep_code/tests/expedition_fixture.gd"
const INTRO := "res://games/creep_code/intro.tscn"
const INTRO_FIXTURE := "res://games/creep_code/tests/intro_fixture.gd"
const RETIRED_DIFFICULTY_KEY := "game/creep_code_difficulty"

var _failures := PackedStringArray()
var _settings: Node
var _game: Node
var _stage_instance := 0
var _core_instance := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_settings = get_root().get_node("Settings")
	var original_values := (_settings.get("_values") as Dictionary).duplicate(true)
	var save_timer := _settings.get("_save_timer") as Timer
	var previous_mode := save_timer.process_mode
	save_timer.process_mode = Node.PROCESS_MODE_DISABLED
	var previous_game := GameCatalog.current_id()
	GameCatalog.select(Options.GAME_ID)
	_settings.call("reset_controls_to_defaults", Options.GAME_ID)
	_settings.call("set_value", Options.RELAXED_KEY, false)
	_settings.call("set_value", Settings.REDUCED_MOTION_KEY, false)
	_settings.call("set_value", Settings.VISUAL_EFFECTS_KEY, true)
	get_root().get_node("GameSession").call("configure_single_player")
	var packed := load(GAME) as PackedScene
	var fixture := load(FIXTURE) as Script
	if packed == null or fixture == null or not fixture.can_instantiate():
		_failures.append("The real Creep Code scene and fixture must compile.")
	else:
		_game = packed.instantiate()
		_game.set_script(fixture)
		get_root().add_child(_game)
		await process_frame
		_game.set_process(false)
		(_game.get("_view") as Node).set_process(false)
		_test_arrival()
		await _test_sunrail_and_reading()
		await _test_collection_and_handoff()
		_test_shaft()
		_test_garden()
		_test_wardens()
		_test_archipelago()
		_test_stair_and_finale()
		_test_replay_and_saved_progress()
		await _test_fixed_settings()
		_test_live_settings()
		_test_exit_cancels_timeline()
		_game.queue_free()
		await process_frame
		await _test_intro()
	var values := _settings.get("_values") as Dictionary
	values.clear()
	values.merge(original_values, true)
	save_timer.stop()
	save_timer.process_mode = previous_mode
	GameCatalog.select(previous_game)
	await create_timer(0.2).timeout
	if _failures.is_empty():
		print("Creep Code ritual integration tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _test_arrival() -> void:
	var manager: Manager = _game.get("_manager")
	var view := _game.get("_view") as Node
	_stage_instance = (view.get("_stage") as Node).get_instance_id()
	_core_instance = (view.get("_engine") as Node).get_instance_id()
	_expect(manager.current_id == &"sunrail" and _phase() == &"arriving",
		"A fresh visit must unfold the first relic directly, with no hub or travel menu.")
	_expect(not manager.has_method("enter") and not view.has_signal("doorway_entered"),
		"The old room and doorway system must be removed, not merely relabeled.")
	var viewport := _game.get("_viewport") as SubViewport
	_expect(viewport.own_world_3d and viewport.gui_disable_input,
		"The persistent stage must remain isolated while the shell owns input.")
	_expect(not bool(_game.get("_uses_shell_round_rules"))
		and (_game.get_node("%RoundTimer") as Timer).is_stopped(),
		"The ritual must not inherit an arcade countdown or lives pool.")
	var rail := manager.current() as Sunrail
	_game.call("_update_round", 0.2, 0.0)
	var mechanism := view.get("_mechanism") as Node3D
	_expect(mechanism.scale.y > 0.0 and mechanism.scale.y < 1.0,
		"Arrival must visibly unfold actual 3D geometry, not just change a caption.")
	_press(Options.RIGHT)
	_game.call("_on_selection_requested", 4)
	_press(Options.RESET)
	_expect(rail.start_index == 0 and rail.remaining_seconds == 90.0,
		"Late input during arrival cannot change a preview or spend time.")
	_press(Options.INTERACT)
	_expect(_phase() == &"puzzle" and rail.phase == State.Phase.READY
		and is_equal_approx(mechanism.scale.y, 1.0),
		"One skip settles the arrival but must not also arm the timed puzzle.")
	var controls := _game.get("_ritual_hud") as Control
	_expect(not controls is PanelContainer and not (controls.get("_book") as Control).visible
		and (controls.get("_dock") as Node) is VBoxContainer,
		"Normal play must have an unboxed action row, not a right-side puzzle panel.")
	_expect((_game.get("_stage_input") as Control).mouse_filter == Control.MOUSE_FILTER_STOP,
		"The stage must receive local GUI coordinates for stretched-viewport picking.")


func _test_sunrail_and_reading() -> void:
	var manager: Manager = _game.get("_manager")
	var rail := manager.current() as Sunrail
	_press(Options.RIGHT)
	_expect(rail.start_index == 1 and rail.phase == State.Phase.READY,
		"Bound keys must preview the frame without starting its clock.")
	_game.call("_update_round", 12.0, 0.0)
	_expect(rail.remaining_seconds == 90.0, "An untimed preview must spend no seconds.")
	_press(Options.INTERACT)
	_expect(rail.phase == State.Phase.ACTIVE and rail.start_index == 1,
		"Arming must preserve the chosen preview and record.")
	_press(Options.INTERACT)
	_expect(rail.wrong_locks == 1
		and str((_game.get("_ritual_hud") as Node).get("_caption").text).contains("Not enough charge"),
		"A weak lock must explain its rejection outside the scroll, not hide beneath the controls.")
	_game.call("_update_round", 0.5, 0.0)
	var remaining := rail.remaining_seconds
	_press(Options.BACK)
	_game.call("_update_round", 30.0, 0.0)
	_game.call("_on_selection_requested", 5)
	_press(Options.RIGHT)
	_press(Options.RESET)
	_expect(bool(_game.get("_grimoire_open")) and rail.remaining_seconds == remaining
		and rail.start_index == 1 and rail.phase == State.Phase.ACTIVE,
		"The grimoire must freeze the actual clock and reject underlying puzzle input.")
	_expect((_game.get_node("%TimeCaption") as Label).text == "PAUSED FOR READING",
		"The HUD must explicitly explain why an armed clock is not moving.")
	var buttons: Dictionary = (_game.get("_ritual_hud") as Node).get("_buttons")
	_expect((buttons[Options.RESET] as Button).disabled
		and not (buttons[Options.HINT] as Button).disabled,
		"Reading must reject retries while still allowing the next inscription.")
	_press(Options.HINT)
	_press(Options.HINT)
	_tap_relic({"selection": 4}, true)
	_expect(rail.hints_used == 2 and rail.start_index == 1 and rail.remaining_seconds == remaining
		and bool(_game.get("_grimoire_open")),
		"Successive inscriptions stay readable in the paused grimoire without spending time.")
	_press(Options.INTERACT)
	_expect(not bool(_game.get("_grimoire_open")) and rail.phase == State.Phase.ACTIVE
		and rail.remaining_seconds == remaining,
		"Returning from the book is a single action, not a hidden confirmation.")
	_game.call("open_pause_menu")
	await process_frame
	_game.call("_update_round", 10.0, 0.0)
	_game.call("_on_selection_requested", 5)
	_tap_relic({"selection": 4}, true)
	_game.call("_on_action", Options.INTERACT)
	_expect(paused and rail.remaining_seconds == remaining and rail.start_index == 1,
		"The shared pause must reject both late input and manually supplied timer ticks.")
	(_game.get("_pause_menu") as Node).call("resume")
	await process_frame
	_game.call("_update_round", 100.0, 0.0)
	_expect(rail.phase == State.Phase.FAILED and manager.failed_attempts == 1
		and manager.completed.is_empty(),
		"Expiry fails only the relic and cannot create a point or permanent seal.")
	_press(Options.RESET)
	_expect(rail.phase == State.Phase.READY and rail.remaining_seconds == 90.0,
		"A free Sunrail retry returns to an untimed preview.")
	for index in range(rail.tiles.size() - rail.width + 1):
		_tap_relic({"selection": index})
		if rail.charge == rail.maximum_charge:
			break
	_press(Options.INTERACT)
	_press(Options.INTERACT)
	_expect(rail.phase == State.Phase.SOLVED and _phase() == &"restoring"
		and manager.lit_relays == [&"sunrail"] and int(_game.get("_scores")[0]) == 1,
		"A winning frame must automatically begin collecting exactly one earned seal.")
	_expect((_game.get("observed_achievements") as PackedStringArray).has("creep_code_sunrail"),
		"The seal must be saved immediately, not after its skippable animation.")
	var view := _game.get("_view") as Node
	_expect(is_equal_approx((view.get("_frame") as Node3D).position.x, float(view.get("_frame_target"))),
		"The solved frame must mark its real winning crystals before the offering flies.")


func _test_collection_and_handoff() -> void:
	var manager: Manager = _game.get("_manager")
	var view := _game.get("_view") as Node
	var outgoing := (view.get("_mechanism") as Node).get_instance_id()
	_game.call("_update_round", 0.4, 0.0)
	var offering := view.get("_offering") as Node3D
	_expect(offering.visible and not offering.position.is_equal_approx(view.get("_offering_start"))
		and not offering.position.is_equal_approx(view.get("_offering_end")),
		"The earned keystone must travel along an actual, bounded curved path.")
	_game.call("open_pause_menu")
	await process_frame
	var elapsed: float = _game.get("_phase_elapsed")
	_game.call("_update_round", 10.0, 0.0)
	_game.call("_on_action", Options.INTERACT)
	_expect(_phase() == &"restoring" and float(_game.get("_phase_elapsed")) == elapsed,
		"Pause must stop both natural handoff time and skip input.")
	(_game.get("_pause_menu") as Node).call("resume")
	await process_frame
	_press(Options.RESET)
	_game.call("_on_selection_requested", 0)
	_tap_relic({"selection": 0})
	_expect(manager.current().phase == State.Phase.SOLVED
		and int(_game.get("_scores")[0]) == 1,
		"Retries and late selections cannot rewind a collected seal or award twice.")
	_game.call("_update_round", 1.0, 0.0)
	_expect(_phase() == &"departing" and manager.current_id == &"sunrail",
		"Collection automatically folds the current relic without requesting travel.")
	_game.call("_update_round", 1.0, 0.0)
	_expect(_phase() == &"arriving" and manager.current_id == &"shaft"
		and (view.get("_mechanism") as Node).get_instance_id() != outgoing,
		"Only the outgoing mechanism is replaced by the next relic.")
	var shaft := manager.current() as Shaft
	var selected := shaft.selected_floor
	_tap_relic({"selection": 15}, true)
	_expect(shaft.selected_floor == selected and shaft.probes_used == 0,
		"An unfolding relic must reject direct stage input, not queue a selection.")
	_expect((view.get("_stage") as Node).get_instance_id() == _stage_instance
		and (view.get("_engine") as Node).get_instance_id() == _core_instance,
		"The dais and constellation core must physically persist through the handoff.")
	_game.call("_update_round", 1.0, 0.0)
	_expect(_phase() == &"puzzle" and shaft.phase == State.Phase.ACTIVE
		and shaft.probes_used == 0,
		"The untimed shaft arrives ready to listen, without a redundant arming step or spent probe.")


func _test_shaft() -> void:
	var manager: Manager = _game.get("_manager")
	var shaft := manager.current() as Shaft
	_tap_relic({"selection": 8}, true)
	_expect(shaft.selected_floor == 8 and shaft.probes_used == 0,
		"Touching a numbered seal must not spend a listening charge.")
	for attempt in range(shaft.probe_limit):
		if shaft.phase != State.Phase.ACTIVE:
			break
		var middle := shaft.lower_bound + (shaft.upper_bound - shaft.lower_bound) / 2
		_game.call("_on_selection_requested", middle)
		_press(Options.INTERACT)
	_expect(shaft.phase == State.Phase.SOLVED and shaft.probes_used <= 4
		and manager.lit_relays.size() == 2,
		"The circular listening seals must retain truthful, playable binary-search rules.")
	_advance_to_puzzle()
	_expect(manager.current_id == &"garden" and manager.current().phase == State.Phase.ACTIVE,
		"The garden must awaken and send its first pulse automatically.")


func _test_garden(expected_points := 3) -> void:
	var manager: Manager = _game.get("_manager")
	var garden := manager.current() as Garden
	var view := _game.get("_view") as Node
	_press(Options.RIGHT)
	_expect(garden.moves_used == 0, "Moving before the echo reveal finishes costs no crossing.")
	_press(Options.INTERACT)
	_expect(garden.pulse_finished and garden.shortest_distance == 8 and garden.moves_used == 0,
		"Reveal echoes now must finish the real BFS without spending a step.")
	var path := garden.shortest_path()
	_tap_relic({"cell": path[1]}, true)
	view.call("_process", 0.12)
	var keeper := view.get("_player") as Node3D
	_expect(bool(view.call("is_walking_walkway"))
		and keeper.position.y > Vector3(view.get("_garden_target")).y,
		"A valid garden edge must produce a visible keeper hop.")
	_game.call("_on_cell_requested", path[2])
	_expect(garden.moves_used == 1, "Rapid touch input cannot queue invisible extra crossings.")
	view.call("_process", 1.0)
	var message: String = _game.get("_message")
	_tap_relic({"cell": path[1]}, false, true)
	_expect(garden.moves_used == 1 and str(_game.get("_message")) == message,
		"An emulated mouse press must not repeat a touch or replace its feedback with a false rejection.")
	var revealed := garden.distances.duplicate()
	_press(Options.RESET)
	_expect(garden.phase == State.Phase.ACTIVE and garden.moves_used == 0
		and garden.distances == revealed and not bool(view.call("is_walking_walkway")),
		"A retry settles any hop, restores the entrance and preserves revealed echoes.")
	for index in range(1, path.size()):
		var direction := path[index] - path[index - 1]
		_press({
			Vector2i.UP: Options.UP, Vector2i.DOWN: Options.DOWN,
			Vector2i.LEFT: Options.LEFT, Vector2i.RIGHT: Options.RIGHT,
		}[direction])
		view.call("_process", 1.0)
	_expect(garden.phase == State.Phase.SOLVED and int(_game.get("_scores")[0]) == expected_points
		and not manager.can_finish(),
		"The original garden must award its point without skipping the three new relics.")
	_expect((view.get("_stage") as Node).get_instance_id() == _stage_instance,
		"The garden still occupies the original stone theatre.")


func _test_wardens() -> void:
	_advance_to_puzzle()
	var manager: Manager = _game.get("_manager")
	var state := manager.current() as Wardens
	var view := _game.get("_view") as Node
	var points: int = _game.get("_scores")[0]
	_expect(state != null and manager.current_id == &"wardens"
		and state.phase == State.Phase.ACTIVE and state.moves_used == 0,
		"The wardens must awaken automatically without discarding a pylon.")
	if state == null:
		return
	_game.call("_on_selection_requested", 3)
	_expect(state.moves_used == 0, "Tapping a middle pylon cannot move either warden.")
	var drone := (view.get("_wardens") as Array)[1] as Node3D
	var from := drone.position
	_press(Options.RIGHT)
	view.call("_process", 0.05)
	var target: Vector3 = (view.get("_warden_targets") as Array)[1]
	_expect(state.right_index == 6 and drone.position != from and drone.position != target,
		"A bound endpoint action must produce a real, interpolated warden flight.")
	var parked := drone.position
	_press(Options.BACK)
	view.call("_process", 2.0)
	_press(Options.LEFT)
	_expect(drone.position == parked and state.moves_used == 1,
		"Reading freezes the new mechanical animation and rejects endpoint input.")
	_press(Options.INTERACT)
	for index in range(state.values.size()):
		if state.phase != State.Phase.ACTIVE:
			break
		_press(Options.LEFT)
	_expect(state.phase == State.Phase.FAILED and int(_game.get("_scores")[0]) == points,
		"Meeting wardens need a retry, never a phantom point.")
	_press(Options.RESET)
	_expect(state.phase == State.Phase.ACTIVE and state.moves_used == 0
		and state.left_index == 0 and state.right_index == 7,
		"A warden retry is free and immediately restores both endpoints.")
	for index in range(state.values.size()):
		if state.charge == state.target_charge:
			break
		_tap_relic({"selection": state.left_index if state.charge < state.target_charge else state.right_index}, true)
		view.call("_process", 1.0)
	_press(Options.INTERACT)
	_expect(state.phase == State.Phase.SOLVED and int(_game.get("_scores")[0]) == points + 1
		and (_game.get("observed_achievements") as PackedStringArray).has("creep_code_wardens"),
		"An actual tapped target pair must save its seal (phase %s, endpoints %d/%d, charge %d, moves %d)." % [
			state.phase, state.left_index, state.right_index, state.charge, state.moves_used,
		])


func _test_archipelago() -> void:
	_advance_to_puzzle()
	var manager: Manager = _game.get("_manager")
	var state := manager.current() as Archipelago
	var view := _game.get("_view") as Node
	_expect(state != null and manager.current_id == &"archipelago", "The island networks follow the wardens.")
	if state == null:
		return
	_tap_relic({"selection": 0}, true)
	_expect(state.bridges.is_empty(), "Choosing a bridge socket must not also build it.")
	_press(Options.INTERACT)
	view.call("_process", 0.1)
	var bridge := (view.get("_bridge_meshes") as Array)[0] as MeshInstance3D
	_expect(bridge.visible and bridge.scale.y > 0.05 and bridge.scale.y < 1.0
		and state.components == 5,
		"A real union must unfold its bridge between the merged islands.")
	var labels: Array = view.get("_network_labels")
	_expect((labels[0] as Label3D).text.ends_with("NET 1") and (labels[1] as Label3D).text.ends_with("NET 1"),
		"Connected islands must share a readable emblem, not only a color.")
	_expect(((view.get("_bridge_pulses") as Array)[0] as Node3D).visible,
		"A powered bridge must carry a visible local energy pulse with effects enabled.")
	var scale := bridge.scale
	_press(Options.BACK)
	view.call("_process", 5.0)
	_press(Options.UP)
	_expect(bridge.scale == scale and state.bridges.size() == 1,
		"The grimoire freezes bridge unfolding and blocks undo beneath the book.")
	_press(Options.INTERACT)
	_settings.call("set_value", Settings.REDUCED_MOTION_KEY, true)
	_expect(is_equal_approx(bridge.scale.y, 1.0),
		"Enabling reduced motion must settle an unfolding bridge immediately.")
	_settings.call("set_value", Settings.REDUCED_MOTION_KEY, false)
	_expect(is_equal_approx(bridge.scale.y, 1.0) and state.bridges.size() == 1,
		"Re-enabling motion must not collapse or rebuild an already settled bridge.")
	_press(Options.UP)
	_expect(state.components == 6 and state.bridges.is_empty() and not bridge.visible
		and (labels[1] as Label3D).text.ends_with("NET 2"),
		"The on-screen undo action must remove the bridge, rebuild emblems and refund its charge.")
	_settings.call("set_value", Settings.REDUCED_MOTION_KEY, true)
	_press(Options.INTERACT)
	_settings.call("set_value", Settings.REDUCED_MOTION_KEY, false)
	_expect(bridge.visible and is_equal_approx(bridge.scale.y, 1.0),
		"A bridge built with reduced motion must remain settled when motion is enabled.")
	_press(Options.UP)
	for index in [0, 6]:
		_game.call("_on_selection_requested", index)
		_press(Options.INTERACT)
	_game.call("_on_selection_requested", 7)
	_press(Options.INTERACT)
	_expect(state.bridges.size() == 2 and str(_game.get("_message")).contains("Already connected"),
		"A redundant indirect connection must explain its rejection without spending a bridge.")
	_press(Options.UP)
	for index in range(1, 5):
		_tap_relic({"selection": index})
		_press(Options.INTERACT)
	_expect(state.phase == State.Phase.SOLVED and state.bridges.size() == 5
		and (_game.get("observed_achievements") as PackedStringArray).has("creep_code_archipelago"),
		"Five useful bridges must power all six islands and save their seal.")


func _test_stair_and_finale(expected_points := 6) -> void:
	_advance_to_puzzle()
	var manager: Manager = _game.get("_manager")
	var state := manager.current() as Stair
	var view := _game.get("_view") as Node
	_expect(state != null and manager.current_id == &"stair", "The remembered stair closes the six-relic ritual.")
	if state == null:
		return
	_press(Options.INTERACT)
	view.call("_process", 0.1)
	var labels: Array = view.get("_stair_labels")
	_expect(state.records == [2] and (labels[1] as Label3D).text.ends_with("BEST\n2")
		and ((view.get("_stair_tiles") as Array)[1] as Node3D).scale.x > 1.0,
		"An inscribed cost must update and animate its actual 3D plaque.")
	_press(Options.INTERACT)
	_expect(state.records.size() == 1 and state.energy_used == 0,
		"Inscribing an expensive predecessor must be rejected without spending climbing energy.")
	_tap_relic({"selection": -1}, true)
	_expect(state.selected_stride == 2 and state.records.size() == 1,
		"Tapping START chooses the two-step predecessor without confirming it.")
	_press(Options.INTERACT)
	for index in range(state.records.size(), state.costs.size()):
		var one := state.records[index - 1]
		var two := state.records[index - 2]
		_press(Options.RIGHT if two < one else Options.LEFT)
		_press(Options.INTERACT)
	_expect(state.records_complete and state.energy_budget == 17
		and (_game.get_node("%TimeCaption") as Label).text == "ENERGY LEFT",
		"The completed table must switch from remembering plaques to a 17-energy climb.")
	_press(Options.BACK)
	var instructions: String = (_game.get("_ritual_hud") as Node).get("_instructions").text
	_expect(instructions.contains("START: BEST 0")
		and instructions.contains("Landing 8 (SUMMIT): FEE 4 | BEST 17"),
		"The paused grimoire must expose the learned cost table at native, readable text size.")
	_press(Options.INTERACT)
	var remembered := state.records.duplicate()
	_press(Options.LEFT)
	_press(Options.INTERACT)
	_press(Options.INTERACT)
	_expect(state.moves_used == 1 and state.energy_used == 2,
		"Rapid confirmation must not queue invisible extra stair crossings.")
	view.call("_process", 0.12)
	_expect(bool(view.call("is_walking_walkway")),
		"One- and two-step climbs use actual keeper hops rather than teleporting markers.")
	_settings.call("set_value", Settings.REDUCED_MOTION_KEY, true)
	_expect(not bool(view.call("is_walking_walkway")) and state.moves_used == 1
		and not (view.get("_motes") as Node3D).visible,
		"A live reduced-motion change settles the stair hop without changing the route or energy.")
	_settings.call("set_value", Settings.REDUCED_MOTION_KEY, false)
	_press(Options.RESET)
	_expect(state.records == remembered and state.player_step == -1 and state.energy_used == 0
		and not bool(view.call("is_walking_walkway")),
		"A real stair retry keeps learned costs while rewinding the keeper and its budget.")
	var path := state.cheapest_path()
	for index in range(1, path.size()):
		_tap_relic({"selection": path[index]}, true)
		_press(Options.INTERACT)
		view.call("_process", 1.0)
	_expect(state.phase == State.Phase.SOLVED and manager.can_finish()
		and int(_game.get("_scores")[0]) == expected_points
		and (_game.get("observed_achievements") as PackedStringArray).has("creep_code_stair"),
		"A cheapest climb must join the sixth seal and award only this visit's solved relics.")
	_expect(int(view.get("_stair_selected")) == state.costs.size() - 1,
		"The restored stair must highlight the actual summit, never a nonexistent next landing.")
	_finish_and_assert(expected_points)


func _finish_and_assert(expected_points: int) -> void:
	var view := _game.get("_view") as Node
	_game.call("_update_round", 2.0, 0.0)
	_expect(_phase() == &"departing",
		"The last mechanism must also fold away rather than abruptly disappear.")
	_game.call("_update_round", 2.0, 0.0)
	_expect(_phase() == &"finale" and bool(_game.get("_round_active"))
		and view.get("_mechanism") == null,
		"The final solve automatically clears the platform for its constellation finale.")
	_game.call("_update_round", 0.8, 0.0)
	_expect((view.get("_engine") as Node3D).position.z > -3.0,
		"The growing constellation must gather above the actual dais for its finale.")
	_game.call("_update_round", 2.0, 0.0)
	_expect(not bool(_game.get("_round_active"))
		and (_game.get_node("%RoundOver") as Control).visible,
		"The finale must reach the shared results without an extra button press.")
	_expect((_game.get("observed_achievements") as PackedStringArray).has("creep_code_observatory")
		and not (_game.get("_ritual_hud") as Control).visible,
		"Finale progress is saved and native puzzle controls cannot cover the shared results.")
	_expect((_game.get_node("%RoundSubtitle") as Label).text.contains("%d/6 points" % expected_points),
		"Results must report actual visit points rather than historical completions.")
	var score_caption := _game.get_node(
		"HUD/RoundOver/Center/ScorePanel/Layout/Report/Players/PlayerOne/Layout/ScoreCaption"
	) as Label
	_expect(score_caption.text == "POINTS THIS VISIT (MAX 6)",
		"The results report must advertise the same six-point maximum as gameplay.")


func _test_replay_and_saved_progress() -> void:
	_game.call("_on_play_again_pressed")
	var manager: Manager = _game.get("_manager")
	_expect(manager.current_id == &"sunrail" and not manager.can_finish()
		and manager.completed.size() == 6 and manager.lit_relays.is_empty()
		and int(_game.get("_scores")[0]) == 0 and _phase() == &"arriving",
		"A complete save begins a fresh full ritual, not an instant zero-point result.")
	var view := _game.get("_view") as Node
	_expect((view.get("_stage") as Node).get_instance_id() == _stage_instance
		and is_zero_approx(float(view.get("_finale")))
		and not (view.get("_offering") as Node3D).visible,
		"Replay preserves the theatre but cancels the old finale and flying relic.")
	_press(Options.INTERACT)
	_expect(manager.current().phase == State.Phase.READY and not manager.can_finish(),
		"Skipping replay's arrival cannot arm it or finish a historically completed save.")
	var partial: Array[StringName] = [&"sunrail"]
	_game.set("saved_relays", partial)
	_game.call("_on_play_again_pressed")
	manager = _game.get("_manager")
	_expect(manager.current_id == &"shaft" and manager.lit_relays == partial
		and manager.solved_this_visit.is_empty() and int(_game.get("_scores")[0]) == 0,
		"A partially restored profile must resume at its missing relic with saved stars prelit.")
	_advance_to_puzzle()
	_expect((manager.current() as Shaft).probes_used == 0,
		"Resuming must not consume a listening charge during its presentation.")
	_test_shaft()
	_test_garden(2)
	_test_wardens()
	_test_archipelago()
	_test_stair_and_finale(5)
	var legacy: Array[StringName] = [&"sunrail", &"shaft", &"garden"]
	_game.set("saved_relays", legacy)
	_game.call("_on_play_again_pressed")
	manager = _game.get("_manager")
	_expect(manager.current_id == &"wardens" and manager.completed == legacy
		and manager.lit_relays == legacy and not manager.can_finish()
		and int(_game.get("_scores")[0]) == 0,
		"A completed legacy three-seal save must resume at the first new relic without losing progress.")
	_test_wardens()
	_test_archipelago()
	_test_stair_and_finale(3)
	var none: Array[StringName] = []
	_game.set("saved_relays", none)
	_game.call("_on_play_again_pressed")
	_advance_to_puzzle()


func _test_fixed_settings() -> void:
	var values := _settings.get("_values") as Dictionary
	for retired_choice in [0, 1, 2]:
		values[RETIRED_DIFFICULTY_KEY] = retired_choice
		_game.call("_on_play_again_pressed")
		var manager: Manager = _game.get("_manager")
		var rail := manager.puzzle(&"sunrail") as Sunrail
		var shaft := manager.puzzle(&"shaft") as Shaft
		var garden := manager.puzzle(&"garden") as Garden
		_expect(rail.tiles == Options.SUNRAIL_TILES and shaft.floor_count == 15
			and garden.rows == PackedStringArray(Options.GARDEN_ROWS),
			"A legacy saved difficulty must not change the single playable configuration.")
		_expect(values[RETIRED_DIFFICULTY_KEY] == retired_choice,
			"Retiring a setting must not delete its stored value for older builds.")
	var settings_screen := (load("res://scenes/menus/settings_menu.tscn") as PackedScene).instantiate()
	settings_screen.set("game_context_id", Options.GAME_ID)
	get_root().add_child(settings_screen)
	await process_frame
	var controls: Dictionary = settings_screen.get("_option_controls")
	_expect(not controls.has(RETIRED_DIFFICULTY_KEY) and controls.has(Options.RELAXED_KEY),
		"Settings must remove difficulty while retaining the live untimed accessibility assist.")
	settings_screen.queue_free()
	await process_frame
	_advance_to_puzzle()


func _test_live_settings() -> void:
	_settings.call("set_binding_key", Options.INTERACT_KEY, KEY_F, Options.GAME_ID)
	var buttons: Dictionary = (_game.get("_ritual_hud") as Node).get("_buttons")
	_expect((buttons[Options.INTERACT] as Button).text.contains("[F]"),
		"Primary controls must display newly rebound keys, including during flourishes.")
	var view := _game.get("_view") as Node
	view.call("_process", 0.2)
	var candle := (view.get("_torch_lights") as Array)[0] as OmniLight3D
	_expect(candle.light_energy > 2.0 and candle.light_energy <= 2.11,
		"Enabled candlelight must gently modulate actual local illumination.")
	view.call("play_feedback", &"success")
	_expect((view.get("_sparks") as MultiMeshInstance3D).visible,
		"A solve must produce a bounded local magical celebration.")
	view.call("begin_restoration", &"sunrail")
	view.call("set_restoration_progress", 0.4)
	_settings.call("set_value", Settings.REDUCED_MOTION_KEY, true)
	view.call("_process", 0.1)
	_expect(bool(_game.get("_reduced_motion_enabled")) and bool(view.get("_reduced_motion"))
		and is_zero_approx(float(view.get("ambient_angle"))),
		"Reduced motion must reach both shell and persistent orrery.")
	_expect(not (view.get("_offering") as Node3D).visible
		and not (view.get("_motes") as MultiMeshInstance3D).visible
		and not (view.get("_sparks") as MultiMeshInstance3D).visible,
		"A live motion change must settle flying relics, motes and solve particles immediately.")
	var cells: Array = view.get("_solar_cells")
	var parked := (cells[0] as Node3D).position
	view.call("_process", 1.0)
	_expect((cells[0] as Node3D).position == parked,
		"Reduced motion must park floating crystals, not merely their particles.")
	for light: OmniLight3D in view.get("_torch_lights"):
		_expect(is_equal_approx(light.light_energy, 2.0),
			"Reduced motion retains steady, useful lighting.")
	_game.call("_on_play_again_pressed")
	_game.call("_update_round", 0.1, 0.0)
	_expect((_game.get("_container") as Control).modulate.a < 1.0
		and (view.get("_mechanism") as Node3D).scale.is_equal_approx(Vector3.ONE),
		"A reduced-motion arrival uses opacity, never scaling or flying geometry.")
	_press(Options.INTERACT)
	_expect(_phase() == &"puzzle"
		and is_equal_approx((_game.get("_container") as Control).modulate.a, 1.0),
		"Skipping a reduced-motion arrival restores full opacity without arming the puzzle.")
	_settings.call("set_value", Settings.REDUCED_MOTION_KEY, false)
	_settings.call("set_value", Settings.VISUAL_EFFECTS_KEY, false)
	view.call("play_feedback", &"success")
	_expect(not bool(_game.get("_intense_effects_enabled"))
		and not bool(view.get("_intense_effects")) and is_zero_approx(float(view.get("_spark_time")))
		and not (view.get("_motes") as MultiMeshInstance3D).visible,
		"Effects-off suppresses sparks and motes while keeping the puzzle readable.")
	_settings.call("set_value", Settings.PLAYER_LABELS_KEY, false)
	_expect(not (view.get("_player_label") as Label3D).visible,
		"Player-label preferences must still reach the ritual's keeper.")
	_settings.call("set_value", Options.RELAXED_KEY, true)
	var manager: Manager = _game.get("_manager")
	var rail := manager.current() as Sunrail
	_press(Options.INTERACT)
	_game.call("_update_round", 100.0, 0.0)
	_expect(rail.relaxed and rail.phase == State.Phase.ACTIVE and rail.remaining_seconds == 90.0,
		"Untimed Sunrail must apply live without changing score or consuming its retained deadline.")


func _test_exit_cancels_timeline() -> void:
	_game.call("_on_play_again_pressed")
	var manager: Manager = _game.get("_manager")
	var elapsed: float = _game.get("_phase_elapsed")
	_game.call("_finish_round")
	_game.call("_on_action", Options.INTERACT)
	_game.call("_on_selection_requested", 3)
	_tap_relic({"selection": 3}, true)
	_game.call("_update_round", 10.0, 0.0)
	_expect(not bool(_game.get("_round_active")) and _phase() == &"arriving"
		and float(_game.get("_phase_elapsed")) == elapsed
		and manager.current().phase == State.Phase.READY
		and (manager.current() as Sunrail).start_index == 0
		and not (_game.get("_stage_input") as Control).visible,
		"Exit cleanup rejects late input and cancels pending handoffs before a router fade.")


func _test_intro() -> void:
	var packed := load(INTRO) as PackedScene
	var fixture := load(INTRO_FIXTURE) as Script
	_expect(packed != null and fixture != null and fixture.can_instantiate(),
		"The game-owned opening must compile.")
	if packed == null or fixture == null or not fixture.can_instantiate():
		return
	for skip_early in [false, true]:
		var intro := packed.instantiate()
		intro.set_script(fixture)
		get_root().add_child(intro)
		await process_frame
		intro.set_process(false)
		var view := intro.get("_view") as Node
		view.set_process(false)
		var stage := (view.get("_stage") as Node).get_instance_id()
		var manager: Manager = intro.get("_manager")
		_expect(manager.completed.is_empty(),
			"The intro uses isolated demonstration progress, never the player's achievements.")
		if not skip_early:
			for tick in range(151):
				intro.call("_process", 0.1)
				view.call("_process", 0.1)
				if tick in [20, 45, 70, 95, 120, 145]:
					_expect(manager.lit_relays.size() == tick / 25 + 1,
						"Every intro card must demonstrate and restore its real algorithm relic.")
				if tick == 145:
					_expect(manager.can_finish() and (view.get("_stage") as Node).get_instance_id() == stage,
						"The memory stair demonstration must complete the six-star constellation in 15 seconds.")
			_settings.call("set_value", Settings.REDUCED_MOTION_KEY, true)
			_expect(bool(view.get("_reduced_motion")) and is_zero_approx(float(view.get("_spark_time"))),
				"The opening applies accessibility changes even at the finale.")
		intro.call("_on_skip_pressed")
		intro.call("_on_skip_pressed")
		_expect(int(intro.get("menu_transitions")) == 1 and bool(intro.get("_finished")),
			"Both natural completion and early skip navigate once, never twice.")
		intro.queue_free()
		await process_frame


func _advance_to_puzzle() -> void:
	for step in range(4):
		if _phase() == &"puzzle":
			return
		_game.call("_update_round", 2.0, 0.0)
	_expect(_phase() == &"puzzle", "The finite presentation timeline must reach the next puzzle.")


func _phase() -> StringName:
	return _game.get("_ritual_phase")


func _tap_relic(target: Dictionary, touch := false, emulated := false) -> void:
	var view := _game.get("_view") as Node3D
	var camera := view.get("camera") as Camera3D
	var viewport := _game.get("_viewport") as SubViewport
	var input := _game.get("_stage_input") as Control
	for mesh: MeshInstance3D in view.get("_pick_meshes"):
		if mesh.get_meta("relic_target") != target:
			continue
		var bounds := mesh.mesh.get_aabb()
		var surface := bounds.get_center()
		var state := (_game.get("_manager") as Manager).current()
		if not (state is Sunrail or state is Wardens):
			surface.y = bounds.end.y
		var at := mesh.to_global(surface)
		var point := camera.unproject_position(at) / Vector2(viewport.size) * input.size
		if _phase() == &"puzzle" and not bool(_game.get("_grimoire_open")) and not paused:
			var picked: Dictionary = view.call("pick_relic", camera.unproject_position(at))
			_expect(picked == target, "The %s surface must pick %s, not %s." % [
				(_game.get("_manager") as Manager).current_id, target, picked,
			])
		if touch:
			var event := InputEventScreenTouch.new()
			event.position = point
			event.pressed = true
			_game.call("_on_stage_input", event)
		else:
			var event := InputEventMouseButton.new()
			event.position = point
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = true
			event.device = InputEvent.DEVICE_ID_EMULATION if emulated else 0
			_game.call("_on_stage_input", event)
		return
	_failures.append("The rendered stage must contain a target for %s." % target)


func _press(action: StringName) -> void:
	for binding in Options.CONTROL_BINDINGS:
		if binding["action"] != action:
			continue
		var event := InputEventKey.new()
		event.physical_keycode = int(_settings.call("binding_keycode", binding["key"]))
		event.pressed = true
		_expect(event.is_action_pressed(action), "The physical %s binding must be registered." % action)
		_game.call("_unhandled_input", event)
		return
	_failures.append("No declared binding for %s." % action)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
