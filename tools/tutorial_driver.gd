extends RefCounted

## Solves all six shipped relics through the live scene's selection/confirm
## paths. Only the random seed and input timings are fixed for the recording.

signal keycap_requested(text: String)

const Options = preload("res://games/creep_code/creep_code_options.gd")
const Manager = preload("res://games/creep_code/puzzle_manager.gd")
const Puzzle = preload("res://games/creep_code/puzzles/puzzle_state.gd")
const Sunrail = preload("res://games/creep_code/puzzles/sliding_window.gd")
const Shaft = preload("res://games/creep_code/puzzles/binary_search.gd")
const Garden = preload("res://games/creep_code/puzzles/breadth_first.gd")
const Wardens = preload("res://games/creep_code/puzzles/two_pointers.gd")
const Archipelago = preload("res://games/creep_code/puzzles/union_find.gd")
const Stair = preload("res://games/creep_code/puzzles/dynamic_programming.gd")
const SOLVE_AT := {
	&"sunrail": 5.65, &"shaft": 13.65, &"garden": 23.65,
	&"wardens": 31.65, &"archipelago": 41.65, &"stair": 55.0,
}
const STEPS: Array[Dictionary] = [
	{"time": 0.0, "title": "Find the strongest three-crystal frame",
		"body": "A / D slides the Sunrail. E arms it, then locks your best charge. H opens paused hints."},
	{"time": 8.0, "title": "Listen halfway through the remaining floors",
		"body": "Select a numbered seal, then E to listen. HIGHER or LOWER rules out half the Whisper Shaft."},
	{"time": 16.0, "title": "Follow the shortest echoes",
		"body": "Let the garden's wave label the paths. Click neighboring platforms and follow increasing numbers to EXIT."},
	{"time": 26.0, "title": "Balance the two wardens",
		"body": "The pylons are sorted. Discard a low or high endpoint until the pair matches the target; E locks it."},
	{"time": 34.0, "title": "Join separate island networks",
		"body": "Select a bridge socket, then E to connect it. Join all six islands with five bridges, not redundant loops."},
	{"time": 44.0, "title": "Remember the cheapest way up",
		"body": "Compare the BEST totals one or two steps behind. Inscribe each plaque, then climb the remembered route."},
	{"time": 59.0, "title": "Restore the constellation",
		"body": "Each different relic earns one point. Hints and retries cost nothing; finish to bank your Star Shards."},
]

var _next_input := 0.9
var _hint_shown := false
var _hint_closed := false


## Only a solo ritual is supported by this game.
func configure(variant: String) -> bool:
	_next_input = 0.9
	_hint_shown = false
	_hint_closed = false
	return variant == "solo"


## Every mechanism receives its own caption while the actual stage transforms.
func steps() -> Array[Dictionary]:
	return STEPS


## Allow a complete remembered stair and the final constellation to settle.
func duration() -> float:
	return 64.0


## Teach the normal Sunrail deadline, not an invisible saved assist.
func settings_overrides() -> Dictionary:
	return {Options.RELAXED_KEY: false}


## The shared solo session still owns results and the eventual shard payout.
func configure_session(session: Node) -> void:
	session.call("configure_single_player")


## Seed 1 places the shaft beacon on floor 13: four genuine midpoint probes.
func start(scene: Node) -> void:
	(scene.get("_rng") as RandomNumberGenerator).seed = 1
	scene.call("_reset_round_state")


## Delaying each final answer keeps natural handoffs aligned with the captions.
func update(scene: Node, time: float, _delta: float) -> void:
	if not bool(scene.get("_round_active")) or scene.get("_ritual_phase") != &"puzzle":
		return
	if not _hint_shown and time >= 1.7:
		_hint_shown = true
		_action(scene, Options.HINT, "H")
		return
	if bool(scene.get("_grimoire_open")):
		if time >= 2.8:
			_hint_closed = true
			_action(scene, Options.INTERACT, "E")
		return
	if time < _next_input:
		return
	_next_input = time + 0.48
	var manager := scene.get("_manager") as Manager
	var puzzle := manager.current()
	var may_finish := time >= float(SOLVE_AT[manager.current_id])
	if puzzle is Sunrail:
		_sunrail(scene, puzzle, time, may_finish)
	elif puzzle is Shaft:
		_shaft(scene, puzzle, may_finish)
	elif puzzle is Garden:
		_garden(scene, puzzle, may_finish)
	elif puzzle is Wardens:
		if puzzle.charge != puzzle.target_charge:
			var left: bool = puzzle.charge < puzzle.target_charge
			_action(scene, Options.LEFT if left else Options.RIGHT, "A" if left else "D")
		elif may_finish:
			_action(scene, Options.INTERACT, "E")
	elif puzzle is Archipelago:
		var index: int = puzzle.bridges.size()
		if puzzle.selected_bridge != index:
			_select(scene, index)
		elif index < puzzle.bridge_limit - 1 or may_finish:
			_action(scene, Options.INTERACT, "E")
	elif puzzle is Stair:
		_stair(scene, puzzle, may_finish)


func _sunrail(scene: Node, puzzle: Sunrail, time: float, may_finish: bool) -> void:
	if puzzle.charge != puzzle.maximum_charge:
		_action(scene, Options.RIGHT, "D")
	elif puzzle.phase == Puzzle.Phase.READY and time >= 4.7:
		_action(scene, Options.INTERACT, "E")
	elif puzzle.phase == Puzzle.Phase.ACTIVE and may_finish:
		_action(scene, Options.INTERACT, "E")


func _shaft(scene: Node, puzzle: Shaft, may_finish: bool) -> void:
	var middle := puzzle.lower_bound + (puzzle.upper_bound - puzzle.lower_bound) / 2
	if puzzle.selected_floor != middle:
		_select(scene, middle)
	elif puzzle.selected_floor != puzzle.hidden_floor or may_finish:
		_action(scene, Options.INTERACT, "E")


func _garden(scene: Node, puzzle: Garden, may_finish: bool) -> void:
	if not puzzle.pulse_finished:
		_action(scene, Options.INTERACT, "E")
		return
	var path := puzzle.shortest_path()
	var next := puzzle.moves_used + 1
	if next >= path.size() or (next == path.size() - 1 and not may_finish):
		return
	scene.call("_on_cell_requested", path[next])
	keycap_requested.emit("Click")


func _stair(scene: Node, puzzle: Stair, may_finish: bool) -> void:
	var stride := 1
	if not puzzle.records_complete:
		var index := puzzle.records.size()
		var one := puzzle.records[index - 1] if index > 0 else 0
		var two := puzzle.records[index - 2] if index > 1 else 0
		stride = 2 if index > 0 and two < one else 1
	else:
		var path := puzzle.cheapest_path()
		var next := puzzle.moves_used + 1
		if next >= path.size() or (next == path.size() - 1 and not may_finish):
			return
		stride = path[next] - puzzle.player_step
	if puzzle.selected_stride != stride:
		_action(scene, Options.LEFT if stride == 1 else Options.RIGHT,
			"A" if stride == 1 else "D")
	else:
		_action(scene, Options.INTERACT, "E")


## A take must restore every relic with real input, not just visit six pictures.
func validate_finished(scene: Node) -> bool:
	var manager := scene.get("_manager") as Manager
	var shaft := manager.puzzle(&"shaft") as Shaft
	var complete := manager.solved_this_visit.size() == Options.RELICS.size() \
		and bool(scene.get("_completed_expedition")) and manager.failed_attempts == 0 \
		and shaft.probes_used == 4 and _hint_shown and _hint_closed
	if not complete:
		push_error("Creep Code tutorial incomplete: restored=%s, phase=%s, failures=%d."
			% [manager.solved_this_visit, scene.get("_ritual_phase"), manager.failed_attempts])
	return complete


func _action(scene: Node, action: StringName, label: String) -> void:
	scene.call("_on_action", action)
	keycap_requested.emit(label)


func _select(scene: Node, index: int) -> void:
	scene.call("_on_selection_requested", index)
	keycap_requested.emit("Click")
