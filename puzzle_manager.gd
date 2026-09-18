extends Node

## One game-local coordinator carries a continuous, ordered ritual.
##
## This is the singleton/autoload role scoped to a single game: no project
## autoload or game-name branch is needed. Register an ordered set of models,
## connect these signals, and supply saved completions from the host.

const PuzzleState = preload("res://games/creep_code/puzzles/puzzle_state.gd")
signal stage_changed(id: StringName)
signal changed
signal feedback(message: String, kind: StringName)
signal puzzle_completed(id: StringName)

var current_id: StringName = &""
var completed: Array[StringName] = []
var lit_relays: Array[StringName] = []
var solved_this_visit: Array[StringName] = []
var failed_attempts := 0
var _order: Array[StringName] = []
var _models: Dictionary[StringName, PuzzleState] = {}
var _titles: Dictionary[StringName, String] = {}


## Registration defines the ritual order; models remain ignorant of staging.
func register_puzzle(id: StringName, title: String, model: PuzzleState) -> bool:
	if id.is_empty() or _models.has(id) or model == null:
		push_error("PuzzleManager: relic IDs must be unique and have a model.")
		return false
	_order.append(id)
	_models[id] = model
	_titles[id] = title
	model.changed.connect(_on_model_changed)
	model.cue.connect(_on_model_cue)
	model.solved.connect(_on_solved.bind(id))
	model.failed.connect(_on_failed)
	return true


## An unfinished ritual resumes at its first missing seal. A fully restored
## save starts a fresh performance without ever revoking permanent progress.
func begin_visit(saved_completions: Array[StringName]) -> void:
	if _order.is_empty():
		push_error("PuzzleManager: register relics before beginning a ritual.")
		return
	for id in saved_completions:
		if not _models.has(id):
			push_warning("PuzzleManager: unknown saved relic '%s'." % id)
		elif not completed.has(id):
			completed.append(id)
	solved_this_visit.clear()
	failed_attempts = 0
	current_id = &""
	lit_relays.clear()
	if completed.size() < _order.size():
		lit_relays.assign(completed)
	for model in _models.values():
		model.reset()
	_open_relic(next_relic())


## Only a restored current relic may hand over to the next one. There is no
## travel API: the gameplay timeline, not a hub or map, performs the handoff.
func advance_to_next() -> bool:
	var model := current()
	if model == null or model.phase != PuzzleState.Phase.SOLVED:
		feedback.emit("Restore this relic before awakening the next.", &"blocked")
		return false
	var next := next_relic()
	if next.is_empty():
		feedback.emit("The constellation is complete.", &"complete")
		return false
	_open_relic(next)
	return true


func _open_relic(id: StringName) -> void:
	current_id = id
	stage_changed.emit(id)
	changed.emit()


## Resetting never touches the other models or permanent unlocks.
func retry() -> void:
	var model := current()
	if model == null:
		feedback.emit("There is no active relic to retry.", &"blocked")
		return
	model.retry()
	feedback.emit("Attempt reset. No points lost; restored relays are safe.", &"reset")


## The first unrestored relay is always reachable; a complete visit has none.
func next_relic() -> StringName:
	for id in _order:
		if not lit_relays.has(id):
			return id
	return &""


## Gameplay supplies time only while a relic, rather than a flourish or book,
## has the player's attention. The shared shell still owns pause.
func advance(delta: float) -> void:
	var model := current()
	if model != null:
		model.advance(delta)


## Null exists only before registration has been turned into a live ritual.
func current() -> PuzzleState:
	return _models[current_id] if _models.has(current_id) else null


## Explicit lookup lets the game apply live options without searching nodes.
func puzzle(id: StringName) -> PuzzleState:
	if not _models.has(id):
		push_error("PuzzleManager: unknown relic '%s'." % id)
		return null
	return _models[id]


## Presentation reads the same registered names as the ritual coordinator.
func title(id: StringName) -> String:
	return _titles.get(id, "The Astral Ritual")


## A copy prevents UI code from reordering progression accidentally.
func relic_ids() -> Array[StringName]:
	return _order.duplicate()


## Permanent achievements cannot bypass a fresh ritual's final awakening.
func can_finish() -> bool:
	return not _order.is_empty() and lit_relays.size() == _order.size()


func _on_model_changed() -> void:
	changed.emit()


func _on_model_cue(message: String, kind: StringName) -> void:
	feedback.emit(message, kind)


func _on_solved(id: StringName) -> void:
	if id != current_id:
		push_error("PuzzleManager: an inactive relic cannot complete.")
		return
	if not lit_relays.has(id):
		lit_relays.append(id)
	if not completed.has(id):
		completed.append(id)
	if not solved_this_visit.has(id):
		solved_this_visit.append(id)
	puzzle_completed.emit(id)


func _on_failed(_reason: String) -> void:
	failed_attempts += 1
