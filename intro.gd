extends Control

## The regular intro subtitle/skip/progress layout overlays the real stage.
## Its demonstration manager never connects to achievements or player saves.

const Options = preload("res://games/creep_code/creep_code_options.gd")
const Manager = preload("res://games/creep_code/puzzle_manager.gd")
const Sunrail = preload("res://games/creep_code/puzzles/sliding_window.gd")
const Shaft = preload("res://games/creep_code/puzzles/binary_search.gd")
const Garden = preload("res://games/creep_code/puzzles/breadth_first.gd")
const Wardens = preload("res://games/creep_code/puzzles/two_pointers.gd")
const Archipelago = preload("res://games/creep_code/puzzles/union_find.gd")
const Stair = preload("res://games/creep_code/puzzles/dynamic_programming.gd")
const State = preload("res://games/creep_code/puzzles/puzzle_state.gd")
const Observatory = preload("res://games/creep_code/world/observatory.gd")
const CARD_SECONDS := 2.5
const SUBTITLES: Array[String] = [
	"Gather sunlight. Six relics remember the stars.",
	"Listen to the whispers. Rule out the impossible.",
	"Let every path answer. Follow the shortest echo.",
	"Two wardens. One balanced pair.",
	"Join the islands. Let their networks become one.",
	"Remember each step. Bring back the stars.",
]

@export_file("*.tscn") var next_scene := "res://scenes/menus/main_menu.tscn"

@onready var _frame: MarginContainer = %Frame
@onready var _stage: SubViewportContainer = %Stage
@onready var _view: Observatory = %Observatory
@onready var _card: Label = %Card
@onready var _skip: Button = %SkipButton
@onready var _hint: Label = %Hint
@onready var _progress: ColorRect = %ProgressFill

var _manager: Manager
var _elapsed := 0.0
var _card_index := -1
var _finished := false
var _restored_at := -1.0
var _showing_finale := false


func _ready() -> void:
	_manager = Manager.new()
	add_child(_manager)
	var models := [
		Sunrail.new(Options.SUNRAIL_TILES, 3), Shaft.new(Options.SHAFT_FLOORS, 13),
		Garden.new(PackedStringArray(Options.GARDEN_ROWS)),
		Wardens.new(Options.WARDEN_PYLONS, Options.WARDEN_TARGET),
		Archipelago.new(Options.ISLAND_COUNT, Options.BRIDGE_SOCKETS),
		Stair.new(Options.STAIR_COSTS),
	]
	for index in range(Options.RELICS.size()):
		var definition := Options.RELICS[index]
		_manager.register_puzzle(definition["id"], definition["title"], models[index])
	_manager.changed.connect(func() -> void: _view.present(_manager))
	_manager.puzzle_completed.connect(_on_demo_restored)
	_manager.feedback.connect(_on_demo_cue)
	_view.set_player_labels(false)
	_view.set_outfit(StringName(Store.equipped_id(Options.GAME_ID, Options.OUTFIT_SLOT)))
	Store.equipped_changed.connect(_on_outfit_changed)
	_view.set_reduced_motion(Settings.reduced_motion_enabled())
	_view.set_intense_effects(Settings.visual_effects_enabled())
	Settings.changed.connect(_on_setting_changed)
	_stage.resized.connect(_resize_stage)
	get_viewport().size_changed.connect(_refresh_layout)
	_progress.anchor_right = 0.0
	_card.modulate.a = 0.0
	_hint.text = "Tap Skip to begin" if DisplayServer.is_touchscreen_available() else "Enter / Esc to skip"
	_show_card(0)
	_refresh_layout()
	_resize_stage.call_deferred()
	_skip.grab_focus()
	AudioManager.attach_ui_sounds(self)


func _process(delta: float) -> void:
	if _finished:
		return
	_elapsed += delta
	var duration := Options.RELICS.size() * CARD_SECONDS
	_progress.anchor_right = minf(_elapsed / duration, 1.0)
	if _elapsed >= duration:
		_finish()
		return
	var index := mini(int(_elapsed / CARD_SECONDS), Options.RELICS.size() - 1)
	if index != _card_index:
		_show_card(index)
	var local_time := fmod(_elapsed, CARD_SECONDS)
	_card.modulate.a = clampf(
		minf(local_time, CARD_SECONDS - local_time) / 0.25, 0.0, 1.0
	)
	_stage.modulate.a = clampf(minf(local_time, CARD_SECONDS - local_time) / 0.35, 0.0, 1.0)
	_view.set_arrival_progress(clampf(local_time / 0.65, 0.0, 1.0))
	_animate_demo(delta * 2.0, local_time * 2.0)


func _show_card(index: int) -> void:
	_card_index = index
	_card.text = SUBTITLES[index]
	_manager.completed.clear()
	_restored_at = -1.0
	_showing_finale = false
	var saved: Array[StringName] = []
	for relay in range(index):
		saved.append(Options.RELICS[relay]["id"])
	_manager.begin_visit(saved)
	_view.mount_relic(_manager)
	if not _manager.current() is Sunrail:
		_manager.current().activate()


func _animate_demo(delta: float, local_time: float) -> void:
	var state := _manager.current()
	if state is Sunrail:
		if local_time < 3.2 and not Settings.reduced_motion_enabled():
			var selection := mini(int(local_time), state.tiles.size() - state.width)
			if state.start_index != selection:
				state.select_start(selection)
		elif local_time >= 3.2 and state.phase != State.Phase.SOLVED:
			for index in range(state.tiles.size() - state.width + 1):
				state.select_start(index)
				if state.charge == state.maximum_charge:
					break
			state.activate()
			state.confirm()
	elif state is Shaft:
		var probes := mini(int(maxf(0.0, local_time - 0.1) / 0.78), 4)
		var floors: Array[int] = [8, 12, 14, 13]
		while state.probes_used < probes and state.phase == State.Phase.ACTIVE:
			state.select_floor(floors[state.probes_used])
			state.probe()
	elif state is Garden and state.phase != State.Phase.SOLVED:
		state.advance(delta * 3.5)
		if state.pulse_finished:
			var path: Array[Vector2i] = state.shortest_path()
			var steps := mini(int(maxf(0.0, local_time - 0.9) / 0.28), path.size() - 1)
			while state.moves_used < steps:
				state.step(path[state.moves_used + 1] - state.player_cell)
	elif state is Wardens and state.phase == State.Phase.ACTIVE:
		var moves := int(maxf(0.0, local_time - 0.4) / 0.5)
		while state.moves_used < moves and state.charge != state.target_charge:
			state.discard(state.left_index if state.charge < state.target_charge else state.right_index)
		if local_time >= 3.2:
			state.confirm()
	elif state is Archipelago and state.phase == State.Phase.ACTIVE:
		var bridges := mini(int(maxf(0.0, local_time - 0.25) / 0.55), state.bridge_limit)
		while state.bridges.size() < bridges:
			state.select_bridge(state.bridges.size())
			state.connect_selected()
	elif state is Stair and state.phase == State.Phase.ACTIVE:
		var plaques := mini(int(maxf(0.0, local_time - 0.1) / 0.2), state.costs.size())
		while state.records.size() < plaques:
			var index: int = state.records.size()
			var one: int = state.records[index - 1] if index > 0 else 0
			var two: int = state.records[index - 2] if index > 1 else 0
			state.select_stride(2 if index > 0 and two < one else 1)
			state.confirm()
		if state.records_complete:
			var path: Array[int] = state.cheapest_path()
			var steps := mini(int(maxf(0.0, local_time - 1.8) / 0.28), path.size() - 1)
			while state.moves_used < steps:
				state.step(path[state.moves_used + 1] - state.player_step)
	if _restored_at < 0.0:
		return
	var collected := (_elapsed - _restored_at) / 0.5
	_view.set_restoration_progress(collected)
	if _manager.can_finish() and collected >= 1.0:
		if not _showing_finale:
			_showing_finale = true
			_view.begin_finale()
		_view.set_finale_progress(clampf((collected - 1.0) / 0.7, 0.0, 1.0))


func _on_demo_restored(id: StringName) -> void:
	_restored_at = _elapsed
	_view.present(_manager)
	_view.begin_restoration(id)
	AudioManager.play_sfx(AudioManager.SFX_FOCUS, -12.0, 0.85 + _card_index * 0.15)
	AudioManager.request_caption("A seal rises into the constellation.")


func _on_demo_cue(_message: String, kind: StringName) -> void:
	_view.play_feedback(kind)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("skip") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish()


func _on_skip_pressed() -> void:
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	set_process(false)
	_view.set_running(false)
	if Router.is_transitioning():
		await Router.transition_finished
	if is_inside_tree():
		_navigate_to_menu()


func _navigate_to_menu() -> void:
	Router.goto(next_scene)


func _on_setting_changed(key: String, value: Variant) -> void:
	if key == Settings.REDUCED_MOTION_KEY:
		_view.set_reduced_motion(bool(value))
	elif key == Settings.VISUAL_EFFECTS_KEY:
		_view.set_intense_effects(bool(value))


func _on_outfit_changed(source_game: String, slot: String, item_id: String) -> void:
	if source_game == Options.GAME_ID and slot == Options.OUTFIT_SLOT:
		_view.set_outfit(StringName(item_id))


func _refresh_layout() -> void:
	var size := get_viewport_rect().size
	var units := maxf(1.0, size.x / maxf(1, get_window().size.x))
	var side := maxf(20 * units, (size.x - 920 * units) * 0.5)
	_frame.add_theme_constant_override("margin_left", roundi(side))
	_frame.add_theme_constant_override("margin_right", roundi(side))
	_frame.add_theme_constant_override("margin_top", roundi(16 * units))
	_frame.add_theme_constant_override("margin_bottom", roundi(16 * units))
	_card.add_theme_font_size_override("font_size", roundi(20 * units))
	_card.offset_top = -96 * units
	_card.offset_bottom = 0
	_hint.add_theme_font_size_override("font_size", roundi(12 * units))
	_skip.add_theme_font_size_override("font_size", roundi(16 * units))
	_skip.custom_minimum_size.y = 44 * units


func _resize_stage() -> void:
	_view.resize_view(_stage.size)
