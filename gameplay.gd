extends GameShell

## The shared shell owns pause, saves and results. One explicit ritual timeline
## replaces room travel: no detached timer or queued doorway can outlive a round.

const Options = preload("res://games/creep_code/creep_code_options.gd")
const PuzzleState = preload("res://games/creep_code/puzzles/puzzle_state.gd")
const Sunrail = preload("res://games/creep_code/puzzles/sliding_window.gd")
const Shaft = preload("res://games/creep_code/puzzles/binary_search.gd")
const Garden = preload("res://games/creep_code/puzzles/breadth_first.gd")
const Wardens = preload("res://games/creep_code/puzzles/two_pointers.gd")
const Archipelago = preload("res://games/creep_code/puzzles/union_find.gd")
const Stair = preload("res://games/creep_code/puzzles/dynamic_programming.gd")
const PuzzleManager = preload("res://games/creep_code/puzzle_manager.gd")
const Observatory = preload("res://games/creep_code/world/observatory.gd")
const RitualHud = preload("res://games/creep_code/ui/ritual_hud.gd")
const Palette = preload("res://games/creep_code/art/palette.gd")
const WORLD_SCENE := preload("res://games/creep_code/world/observatory.tscn")
const PHASE_SECONDS := {
	&"arriving": 0.7, &"restoring": 1.2, &"departing": 0.45, &"finale": 1.6,
}

var _manager: PuzzleManager
var _view: Observatory
var _ritual_hud: RitualHud
var _container: SubViewportContainer
var _viewport: SubViewport
var _stage_input: Control
var _ritual_phase := &"arriving"
var _phase_elapsed := 0.0
var _grimoire_open := false
var _message := ""
var _feedback_kind := &""
var _completed_expedition := false
var _point_awarded := false
var _capture_inset := 0.0


## This identity is the only link the shared framework needs to discover us.
func game_id() -> String:
	return Options.GAME_ID


func _build_playfield() -> void:
	_container = SubViewportContainer.new()
	_container.name = "ObservatoryView"
	_container.stretch = true
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_playfield.add_child(_container)
	_viewport = SubViewport.new()
	_viewport.name = "ObservatoryViewport"
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.gui_disable_input = true
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_container.add_child(_viewport)
	_view = WORLD_SCENE.instantiate() as Observatory
	_viewport.add_child(_view)
	_view.set_outfit(StringName(Store.equipped_id(Options.GAME_ID, Options.OUTFIT_SLOT)))
	Store.equipped_changed.connect(_on_outfit_changed)
	_view.set_reduced_motion(_reduced_motion_enabled)
	_view.set_intense_effects(_intense_effects_enabled)
	_stage_input = Control.new()
	_stage_input.name = "StageInput"
	_stage_input.mouse_filter = Control.MOUSE_FILTER_STOP
	_stage_input.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_hud.get_node("Overlay").add_child(_stage_input)
	_stage_input.gui_input.connect(_on_stage_input)
	_ritual_hud = RitualHud.new()
	_ritual_hud.name = "RitualControls"
	_hud.get_node("Overlay").add_child(_ritual_hud)
	_ritual_hud.action_requested.connect(_on_action)
	get_viewport().size_changed.connect(_resize_world)
	_resize_world()
	_on_controls_changed()


func _reset_round_state() -> void:
	_completed_expedition = false
	_point_awarded = false
	_grimoire_open = false
	_ritual_phase = &"arriving"
	_phase_elapsed = 0.0
	_container.modulate.a = 1.0
	_view.reset_ritual()
	if is_instance_valid(_manager):
		remove_child(_manager)
		_manager.queue_free()
	_manager = PuzzleManager.new()
	_manager.name = "PuzzleManager"
	add_child(_manager)
	var rail := Sunrail.new(Options.SUNRAIL_TILES, 3, Options.SUNRAIL_SECONDS)
	rail.set_relaxed(Settings.tunable_bool(Options.RELAXED_KEY))
	var floors := Options.SHAFT_FLOORS
	var models: Array[PuzzleState] = [
		rail, Shaft.new(floors, _rng.randi_range(1, floors)),
		Garden.new(PackedStringArray(Options.GARDEN_ROWS)),
		Wardens.new(Options.WARDEN_PYLONS, Options.WARDEN_TARGET),
		Archipelago.new(Options.ISLAND_COUNT, Options.BRIDGE_SOCKETS),
		Stair.new(Options.STAIR_COSTS),
	]
	for index in range(Options.RELICS.size()):
		var definition := Options.RELICS[index]
		_manager.register_puzzle(definition["id"], definition["title"], models[index])
	_manager.stage_changed.connect(_on_stage_changed)
	_manager.changed.connect(_on_puzzle_changed)
	_manager.feedback.connect(_on_feedback)
	_manager.puzzle_completed.connect(_on_puzzle_completed)
	_ritual_hud.show()
	_stage_input.show()
	_view.set_running(true)
	_manager.begin_visit(_saved_completions())


func _saved_completions() -> Array[StringName]:
	var saved: Array[StringName] = []
	for definition in Options.RELICS:
		if AchievementManager.is_unlocked(definition["achievement"]):
			saved.append(definition["id"])
	return saved


func _activate_round() -> void:
	_refresh_ui()


func _update_round(delta: float, _time_left: float) -> void:
	if get_tree().paused or not _round_active:
		return
	if Router.is_transitioning() or _grimoire_open:
		_view.set_running(false)
		return
	_view.set_running(true)
	if _ritual_phase == &"puzzle":
		_manager.advance(delta)
		return
	_phase_elapsed += delta
	var duration: float = PHASE_SECONDS[_ritual_phase]
	if _reduced_motion_enabled:
		duration *= 0.4
	var progress := clampf(_phase_elapsed / duration, 0.0, 1.0)
	_present_phase(progress)
	if progress >= 1.0:
		_complete_presentation()


func _start_phase(phase: StringName) -> void:
	_ritual_phase = phase
	_phase_elapsed = 0.0
	_container.modulate.a = 1.0
	_present_phase(0.0)
	_refresh_ui()


func _present_phase(progress: float) -> void:
	match _ritual_phase:
		&"arriving":
			_view.set_arrival_progress(progress)
			if _reduced_motion_enabled:
				_container.modulate.a = lerpf(0.55, 1.0, progress)
		&"restoring":
			_view.set_restoration_progress(progress)
		&"departing":
			_view.set_departure_progress(progress)
			if _reduced_motion_enabled:
				_container.modulate.a = lerpf(1.0, 0.55, progress)
		&"finale":
			_view.set_finale_progress(progress)
			if _reduced_motion_enabled:
				_container.modulate.a = lerpf(0.55, 1.0, minf(1.0, progress * 2.0))


func _complete_presentation() -> void:
	_present_phase(1.0)
	match _ritual_phase:
		&"arriving":
			_start_phase(&"puzzle")
			_activate_untimed_relic()
		&"restoring":
			_start_phase(&"departing")
		&"departing":
			if _manager.can_finish():
				_view.begin_finale()
				_start_phase(&"finale")
				AudioManager.request_caption("All six seals joined. The stars return.")
			else:
				_manager.advance_to_next()
		&"finale":
			_completed_expedition = true
			_end_round()


func _activate_untimed_relic() -> void:
	var puzzle := _manager.current()
	if not puzzle is Sunrail and puzzle.phase == PuzzleState.Phase.READY:
		puzzle.activate()


func _handle_gameplay_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed() or Router.is_transitioning():
		return
	for binding in Options.CONTROL_BINDINGS:
		var action: StringName = binding["action"]
		if event.is_action_pressed(action):
			_on_action(action)
			get_viewport().set_input_as_handled()
			return


func _can_take_input() -> bool:
	return _round_active and not get_tree().paused and not Router.is_transitioning()


func _can_adjust_relic() -> bool:
	return _can_take_input() and _ritual_phase == &"puzzle" and not _grimoire_open


func _on_action(action: StringName) -> void:
	if not _can_take_input():
		return
	if _ritual_phase != &"puzzle":
		if action == Options.INTERACT:
			_complete_presentation()
		return
	if action == Options.BACK or (_grimoire_open and action == Options.INTERACT):
		_grimoire_open = not _grimoire_open
		_view.set_running(not _grimoire_open)
		_refresh_ui()
		return
	if action == Options.HINT:
		_grimoire_open = true
		_view.set_running(false)
		_on_feedback(_manager.current().hint(), &"hint")
		_ritual_hud.reveal_hint.call_deferred()
		return
	if _grimoire_open:
		return
	match action:
		Options.LEFT:
			_adjust(Vector2i.LEFT)
		Options.RIGHT:
			_adjust(Vector2i.RIGHT)
		Options.UP:
			_adjust(Vector2i.UP)
		Options.DOWN:
			_adjust(Vector2i.DOWN)
		Options.INTERACT:
			_interact()
		Options.RESET:
			_retry_relic()


func _on_stage_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if (
			event.pressed and event.button_index == MOUSE_BUTTON_LEFT
			and event.device != InputEvent.DEVICE_ID_EMULATION
		):
			_on_stage_pressed(event.position)
			_stage_input.accept_event()
	elif event is InputEventScreenTouch and event.pressed and event.index == 0:
		_on_stage_pressed(event.position)
		_stage_input.accept_event()


func _on_stage_pressed(position: Vector2) -> void:
	if not _can_adjust_relic():
		return
	if not Rect2(Vector2.ZERO, _stage_input.size).has_point(position):
		return
	var point := position / _stage_input.size * Vector2(_viewport.size)
	var target := _view.pick_relic(point)
	if target.has("selection"):
		_on_selection_requested(int(target["selection"]))
	elif target.has("cell"):
		_on_cell_requested(target["cell"])


func _on_selection_requested(value: int) -> void:
	if not _can_adjust_relic():
		return
	var puzzle := _manager.current()
	if puzzle is Sunrail:
		puzzle.select_start(value)
	elif puzzle is Shaft:
		puzzle.select_floor(value)
	elif puzzle is Wardens:
		puzzle.discard(value)
	elif puzzle is Archipelago:
		puzzle.select_bridge(value)
	elif puzzle is Stair:
		puzzle.select_landing(value)


func _on_cell_requested(cell: Vector2i) -> void:
	if not _can_adjust_relic():
		return
	var puzzle := _manager.current() as Garden
	if puzzle != null:
		_adjust(cell - puzzle.player_cell)


func _adjust(direction: Vector2i) -> void:
	var puzzle := _manager.current()
	if puzzle is Sunrail:
		if direction.x != 0:
			puzzle.shift(direction.x)
	elif puzzle is Shaft:
		var change := direction.x if direction.x != 0 else -direction.y
		puzzle.select_floor(puzzle.selected_floor + change)
	elif puzzle is Garden and not _view.is_walking_walkway():
		puzzle.step(direction)
	elif puzzle is Wardens and direction.x != 0:
		puzzle.discard(puzzle.left_index if direction.x < 0 else puzzle.right_index)
	elif puzzle is Archipelago:
		if direction.y < 0:
			puzzle.undo()
		elif direction.x != 0:
			puzzle.select_bridge(wrapi(puzzle.selected_bridge + direction.x, 0, puzzle.sockets.size()))
	elif puzzle is Stair:
		puzzle.select_stride(1 if direction.x < 0 or direction.y < 0 else 2)


func _interact() -> void:
	var puzzle := _manager.current()
	if puzzle.phase == PuzzleState.Phase.FAILED:
		_retry_relic()
	elif puzzle.phase == PuzzleState.Phase.READY:
		puzzle.activate()
	elif puzzle is Sunrail:
		puzzle.confirm()
	elif puzzle is Shaft:
		puzzle.probe()
	elif puzzle is Wardens:
		puzzle.confirm()
	elif puzzle is Archipelago:
		puzzle.connect_selected()
	elif puzzle is Stair and not _view.is_walking_walkway():
		puzzle.confirm()
	elif puzzle is Garden:
		if not puzzle.pulse_finished:
			puzzle.advance(Garden.WAVE_SECONDS * puzzle.rows.size() * puzzle.rows[0].length())
		else:
			_on_feedback("Tap a neighboring platform or use a direction. Follow increasing numbers.", &"heard")
	_refresh_ui()


func _retry_relic() -> void:
	_manager.retry()
	_activate_untimed_relic()
	_refresh_ui()


func _on_stage_changed(_id: StringName) -> void:
	_feedback_kind = &""
	_view.mount_relic(_manager)
	_view.set_player_labels(Settings.player_labels_enabled())
	_message = "The next relic rises. Every restored seal joins your constellation."
	if _manager.solved_this_visit.is_empty():
		_message = (
			"All permanent seals are safe. Relight all six in a fresh ritual."
			if _manager.completed.size() == Options.RELICS.size() else (
				"Resuming with %d saved seals. Begin at the first unrestored relic."
				% _manager.completed.size() if not _manager.completed.is_empty() else
				"One stage, six relics. Restore each seal to awaken the next."
			)
		)
	_start_phase(&"arriving")


func _on_puzzle_changed() -> void:
	_view.present(_manager)
	_refresh_ui()


func _on_puzzle_completed(id: StringName) -> void:
	var previous: int = _scores[PLAYER_ONE]
	_scores[PLAYER_ONE] = _manager.solved_this_visit.size()
	_point_awarded = _scores[PLAYER_ONE] > previous
	_update_scores()
	for definition in Options.RELICS:
		if definition["id"] == id:
			_unlock_round_achievement(definition["achievement"])
			break
	_view.present(_manager)
	_view.begin_restoration(id)
	_start_phase(&"restoring")


func _on_feedback(message: String, kind: StringName) -> void:
	if kind == &"success":
		message = (
			"+1 point! Seal saved." if _point_awarded else
			"Seal restored again; already counted this visit."
		)
		message += " The stars are returning." if _manager.can_finish() else (
			" The next relic awakens automatically."
		)
	_message = message
	_feedback_kind = kind
	_view.play_feedback(kind)
	var pitch := 1.0
	if kind == &"higher":
		pitch = 1.4
	elif kind == &"lower" or kind == &"failure":
		pitch = 0.7
	AudioManager.play_sfx(
		AudioManager.SFX_FOCUS if kind in [&"success", &"heard", &"hint"] else AudioManager.SFX_CLICK,
		-8.0, pitch
	)
	AudioManager.request_caption(message)
	_refresh_ui()


func _refresh_ui() -> void:
	if not is_instance_valid(_ritual_hud) or not is_instance_valid(_manager):
		return
	var puzzle := _manager.current()
	if puzzle == null:
		return
	var primary := "Skip flourish"
	if _ritual_phase == &"puzzle":
		if _grimoire_open:
			primary = "Return to relic"
		elif puzzle.phase == PuzzleState.Phase.FAILED:
			primary = "Retry relic"
		elif puzzle.phase == PuzzleState.Phase.READY:
			primary = "Arm Sunrail"
		elif puzzle is Sunrail:
			primary = "Lock charge"
		elif puzzle is Shaft:
			primary = "Listen at floor"
		elif puzzle is Garden:
			primary = "Inspect route" if puzzle.pulse_finished else "Reveal echoes now"
		elif puzzle is Wardens:
			primary = "Lock pair"
		elif puzzle is Archipelago:
			primary = "Connect bridge"
		elif puzzle is Stair:
			primary = (
				"Climb %d step(s)" % puzzle.selected_stride if puzzle.records_complete
				else "Inscribe %d back" % puzzle.selected_stride
			)
	elif _ritual_phase == &"finale":
		primary = "See results"
	var instructions := _relic_instructions(puzzle)
	if _ritual_phase in [&"restoring", &"departing"]:
		instructions = "Your seal is already saved. The stage continues automatically."
	elif _ritual_phase == &"finale":
		instructions = "Every seal is safe. " + Options.SCORE_RULES
	_ritual_hud.present(
		_manager, instructions, _message, primary,
		_ritual_phase, _grimoire_open, _feedback_kind
	)
	_present_budget(puzzle)


func _relic_instructions(puzzle: PuzzleState) -> String:
	var text := ""
	if puzzle is Sunrail:
		text = "Tap the first crystal of a three-cell frame. Find the strongest total; preview is free."
		if _grimoire_open:
			text += (
				" The brass frame adds those three values."
				+ " Scan ranges to find the largest sum, then Lock charge."
				+ " Arming starts 90 seconds; the grimoire and Pause stop that clock."
			)
		if puzzle.relaxed:
			text += " Untimed Sunrail is on: there is no deadline or score penalty."
	elif puzzle is Shaft:
		text = "Choose a numbered listening seal, then Listen. One charge per question."
		if _grimoire_open:
			text += (
				" The seals represent floors; HIGHER / LOWER rules out impossible ones."
				+ " Try the middle of the remaining interval."
				+ " Selecting is free; only listening spends a charge. There is no countdown."
			)
	elif puzzle is Garden:
		text = "Tap neighboring platforms and follow increasing echoes to EXIT. One charge per crossing."
		if _grimoire_open:
			text += (
				" The wave reveals shortest distances from your starting platform."
				+ " Take neighboring platforms with 1, 2, 3... to reach the exit."
				+ " Walls and unready moves spend nothing. Retry retains revealed echoes."
				+ " There is no countdown."
			)
	elif puzzle is Wardens:
		text = "Match the target with two endpoints. Tap a warden's pylon to discard it, then lock a balanced pair."
		if _grimoire_open:
			text += (
				" The pylons are sorted. Too faint: advance the left warden."
				+ " Too bright: advance the right. Left / Right also move those wardens inward."
				+ " The two pylons must stay distinct. Meeting without a pair needs a free retry."
				+ " There is no countdown."
			)
	elif puzzle is Archipelago:
		text = "Select a numbered socket, then connect islands with different NET numbers. Up undoes the last bridge."
		if _grimoire_open:
			text += (
				" Every island in a connected network shares its lowest island number."
				+ " Joining two separate networks costs one bridge; redundant links cost nothing."
				+ " Left / Right browse sockets. Undo rebuilds the networks and returns one bridge."
				+ " Join all six islands with five bridges. There is no countdown."
			)
	elif puzzle is Stair:
		text = (
			"Choose one or two steps, then climb. Use the remembered BEST totals to reach the summit."
			if puzzle.records_complete else
			"Choose the cheaper BEST total one or two landings behind, then inscribe the next plaque."
		)
		if _grimoire_open:
			text += (
				" Each landing charges its FEE; BEST remembers the cheapest total arrival."
				+ " START costs zero. Left / Up choose one step, Right / Down choose two."
				+ " Tap a predecessor while remembering, or a reachable landing while climbing;"
				+ " Interact confirms. Equal cheapest records both count."
				+ " Retry keeps learned plaques but refunds all climbing energy. There is no countdown."
			)
			text += "\n\nSTART: BEST 0"
			for index in range(puzzle.costs.size()):
				text += "\nLanding %d%s: FEE %d | BEST %s" % [
					index + 1, " (SUMMIT)" if index == puzzle.costs.size() - 1 else "",
					puzzle.costs[index],
					str(puzzle.records[index]) if index < puzzle.records.size() else "?",
				]
	if _grimoire_open:
		text += (
			"\n\nYour constellation grows automatically after each solve."
			+ " An unfinished saved ritual resumes at its first missing seal."
			+ " A fully restored save begins a fresh six-relic ritual."
		)
	return text


func _present_budget(puzzle: PuzzleState) -> void:
	_time_progress.hide()
	if _ritual_phase == &"finale":
		_time_label.text = "%d/%d" % [Options.RELICS.size(), Options.RELICS.size()]
		_time_caption.text = "CONSTELLATION LIT"
	elif puzzle.phase == PuzzleState.Phase.SOLVED:
		_time_label.text = "SAVED"
		_time_caption.text = "SEAL RESTORED"
	elif puzzle is Sunrail:
		_time_label.text = "OFF" if puzzle.relaxed else "%ds" % ceili(puzzle.remaining_seconds)
		_time_caption.text = "UNTIMED SUNRAIL" if puzzle.relaxed else (
			"PAUSED FOR READING" if _grimoire_open else (
				"STARTS WHEN ARMED" if puzzle.phase == PuzzleState.Phase.READY else "SUNRAIL TIME LEFT"
			)
		)
		_time_progress.visible = not puzzle.relaxed
		_time_progress.max_value = puzzle.time_limit
		_time_progress.value = puzzle.remaining_seconds
	elif puzzle is Shaft:
		_time_label.text = str(puzzle.probe_limit - puzzle.probes_used)
		_time_caption.text = "LISTENS LEFT"
	elif puzzle is Garden:
		_time_label.text = str(puzzle.shortest_distance - puzzle.moves_used) if puzzle.pulse_finished else "--"
		_time_caption.text = "STEPS LEFT" if puzzle.pulse_finished else "ECHOES UNFOLDING"
	elif puzzle is Wardens:
		_time_label.text = str(puzzle.target_charge)
		_time_caption.text = "PAIR TARGET"
	elif puzzle is Archipelago:
		_time_label.text = str(puzzle.bridge_limit - puzzle.bridges.size())
		_time_caption.text = "BRIDGES LEFT"
	elif puzzle is Stair:
		_time_label.text = str(
			maxi(0, puzzle.energy_budget - puzzle.energy_used) if puzzle.records_complete
			else puzzle.costs.size() - puzzle.records.size()
		)
		_time_caption.text = "ENERGY LEFT" if puzzle.records_complete else "PLAQUES TO REMEMBER"


func _configure_mode_ui() -> void:
	super()
	_player_one_caption.text = "POINTS (MAX %d)" % Options.RELICS.size()
	_round_instructions.text = Options.SCORE_RULES
	_player_one_streak.hide()
	_callout.hide()
	_hint.get_parent().hide()
	_refresh_ui()


func _on_controls_changed() -> void:
	super()
	if not is_instance_valid(_ritual_hud):
		return
	var names: Dictionary[StringName, String] = {}
	for binding in Options.CONTROL_BINDINGS:
		names[binding["action"]] = OS.get_keycode_string(Settings.binding_keycode(binding["key"]))
	_ritual_hud.set_bindings(names)
	_refresh_ui()


func _on_outfit_changed(source_game: String, slot: String, item_id: String) -> void:
	if source_game == Options.GAME_ID and slot == Options.OUTFIT_SLOT:
		_view.set_outfit(StringName(item_id))


func _on_player_labels_changed() -> void:
	super()
	if is_instance_valid(_view):
		_view.set_player_labels(Settings.player_labels_enabled())


func _on_game_setting_changed(key: String, value: Variant) -> void:
	if key == Options.RELAXED_KEY and is_instance_valid(_manager):
		var rail := _manager.puzzle(&"sunrail") as Sunrail
		rail.set_relaxed(bool(value))


func _set_reduced_motion_enabled(value: bool) -> void:
	super(value)
	if is_instance_valid(_view):
		_view.set_reduced_motion(value)
	if is_instance_valid(_container) and not value:
		_container.modulate.a = 1.0


func _set_intense_effects_enabled(value: bool) -> void:
	super(value)
	if is_instance_valid(_view):
		_view.set_intense_effects(value)


func _set_capture_inset(bottom: float) -> void:
	_capture_inset = maxf(bottom, 0.0)
	_resize_world.call_deferred()


func _resize_world() -> void:
	if not is_instance_valid(_ritual_hud):
		return
	var size := get_viewport_rect().size
	var units := maxf(1.0, size.x / maxf(1, get_window().size.x))
	var short_window := get_window().size.y < 480
	_player_one_caption.add_theme_font_size_override("font_size", roundi(
		(12 if short_window else 14) * units
	))
	var number_size := roundi((22 if short_window else 28) * units)
	_player_one_score.add_theme_font_size_override("font_size", number_size)
	_mode_title.add_theme_font_size_override("font_size", roundi(18 * units))
	_mode_title.visible = not short_window
	_time_label.add_theme_font_size_override("font_size", number_size)
	_time_caption.add_theme_font_size_override("font_size", roundi(12 * units))
	var top_bar := _player_one_card.get_parent() as Control
	var top := maxf(TOP_CLEARANCE, top_bar.get_combined_minimum_size().y + 64)
	var available := Vector2(size.x, maxf(top + 1.0, size.y - _capture_inset))
	var field := _ritual_hud.layout_for(available, top + 8)
	_container.position = field.position
	_container.size = field.size
	_stage_input.position = field.position
	_stage_input.size = field.size
	_view.resize_view(_container.size)


func _finish_round() -> void:
	_round_active = false
	_grimoire_open = false
	if is_instance_valid(_view):
		_view.set_running(false)
	if is_instance_valid(_stage_input):
		_stage_input.hide()
	if is_instance_valid(_ritual_hud):
		_ritual_hud.hide()


func _describe_round_outcome(_player_one_total: int, _player_two_total: int) -> Dictionary:
	return {
		"result": "THE STARS RETURN" if _completed_expedition else "RITUAL COMPLETE",
		"subtitle": (
			"The constellation shines. %d/%d points earned this visit; every seal is safe."
			% [_scores[PLAYER_ONE], Options.RELICS.size()] if _completed_expedition else
			"Your restored seals are safe. The ritual will resume where you left it."
		),
		"color": Palette.GOLD,
	}


# The shared highlight builder still appends earned shards and unlocks.
func _best_combo_summary() -> String:
	return "%d/%d points | %d failed attempts (no penalty) | No time bonus" % [
		_scores[PLAYER_ONE], Options.RELICS.size(), _manager.failed_attempts,
	]


func _award_round_achievements(_player_one_total: int, _player_two_total: int) -> void:
	if _completed_expedition:
		_unlock_round_achievement("creep_code_observatory")


func _player_stats(player_index: int) -> Dictionary:
	var stats := super(player_index)
	if player_index == PLAYER_ONE and is_instance_valid(_manager):
		stats["misses"] = _manager.failed_attempts
		var totals := _round_totals()
		stats["accuracy"] = _accuracy_percent(totals["hits"], totals["attempts"])
	return stats


func _round_totals() -> Dictionary:
	var restored: int = _scores[PLAYER_ONE]
	return {"hits": restored, "attempts": maxi(Options.RELICS.size(), restored)}
