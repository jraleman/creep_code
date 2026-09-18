extends "res://games/creep_code/puzzles/puzzle_state.gd"

## The Sunrail: an O(1) update per one-cell movement of a fixed-width frame.
##
## The charge of overlapping cells is retained. Only the cell leaving the
## frame is subtracted and the cell entering it is added. The independent
## maximum is computed once, so locking a merely local best cannot win.

var tiles: Array[int] = []
var width := 3
var time_limit := 90.0
var relaxed := false
var start_index := 0
var charge := 0
var best_charge := 0
var best_start := 0
var maximum_charge := 0
var remaining_seconds := 0.0
var wrong_locks := 0
var last_exchange := "Slide the frame. Notice the two end cells."


func _init(values: Array[int], frame_width: int, seconds := 90.0) -> void:
	if values.is_empty() or frame_width < 1 or frame_width > values.size():
		_invalid_configuration("A scan frame must fit a nonempty rail.")
		return
	if not is_finite(seconds) or seconds <= 0.0:
		_invalid_configuration("The capacitor duration must be positive and finite.")
		return
	tiles = values.duplicate()
	width = frame_width
	time_limit = seconds
	maximum_charge = _find_maximum()
	reset()


## Only an explicit retry clears the scan and refills the capacitor.
func reset() -> void:
	super.reset()
	start_index = 0
	charge = _first_charge()
	best_charge = charge
	best_start = 0
	remaining_seconds = time_limit
	wrong_locks = 0
	last_exchange = "Preview freely, then arm the capacitor."
	changed.emit()


## Arming retains the player's discoveries and selection; reflexes are not
## the lesson, and repeating a scan should never be the price of reading first.
func activate() -> void:
	if phase != Phase.READY:
		return
	last_exchange = "Capacitor armed. Find and lock the strongest segment."
	super.activate()
	cue.emit(last_exchange, &"start")


## Touch can inspect a particular frame without revealing the skipped ranges.
func select_start(index: int) -> bool:
	if phase != Phase.READY and phase != Phase.ACTIVE:
		return false
	if index < 0 or index + width > tiles.size():
		cue.emit("The whole frame must stay on the rail.", &"blocked")
		return false
	start_index = index
	charge = 0
	for cell in range(start_index, start_index + width):
		charge += tiles[cell]
	_remember_charge()
	last_exchange = "Cells %d-%d hold %d charge." % [
		start_index + 1, start_index + width, charge,
	]
	changed.emit()
	cue.emit(last_exchange, &"shift")
	return true


## Both directions preserve a fixed width, including at either end of the rail.
func shift(direction: int) -> bool:
	if phase != Phase.READY and phase != Phase.ACTIVE:
		return false
	if direction != -1 and direction != 1:
		cue.emit("Move the frame one notch left or right.", &"blocked")
		return false
	var next_start := start_index + direction
	if next_start < 0 or next_start + width > tiles.size():
		cue.emit("The frame has reached the end of the rail.", &"blocked")
		return false

	# Moving left exchanges the rightmost cell for the new leftmost one;
	# moving right does the opposite. Neither path sums the overlap again.
	var leaving := tiles[start_index if direction > 0 else start_index + width - 1]
	var entering := tiles[start_index + width if direction > 0 else next_start]
	charge += entering - leaving
	start_index = next_start
	_remember_charge()
	last_exchange = "Release %d; take %d. Charge %d." % [leaving, entering, charge]
	changed.emit()
	cue.emit(last_exchange, &"shift")
	return true


## Any tied global maximum is valid. A weak lock costs time, not a life.
func confirm() -> bool:
	if phase != Phase.ACTIVE:
		return false
	if charge == maximum_charge:
		_succeed()
		return true
	wrong_locks += 1
	cue.emit("Not enough charge. A stronger segment is still on the rail.", &"blocked")
	changed.emit()
	return false


## Only the playable phase receives ticks. Preview, reading the grimoire,
## shared pause and presentation handoffs never spend the remaining budget.
func advance(delta: float) -> void:
	if phase != Phase.ACTIVE or relaxed:
		return
	if delta < 0.0 or not is_finite(delta):
		push_error("Sunrail requires a nonnegative, finite time step.")
		return
	var previous_second := ceili(remaining_seconds)
	remaining_seconds = maxf(0.0, remaining_seconds - delta)
	if remaining_seconds == 0.0:
		_fail("The capacitor is empty. Reset this attempt and try again.")
	elif ceili(remaining_seconds) != previous_second:
		changed.emit()


## The accessibility assist can be enabled live without erasing discoveries.
func set_relaxed(enabled: bool) -> void:
	relaxed = enabled
	changed.emit()


## The second inscription makes the reusable overlap explicit without jargon.
func hint() -> String:
	hints_used += 1
	if hints_used == 1:
		return "Keep the middle. Release one cell. Take the next."
	if hints_used == 2:
		return "The record remembers your strongest reading. Compare every position."
	return "Your best reading was %d at cells %d-%d. Keep looking if it will not lock." % [
		best_charge, best_start + 1, best_start + width,
	]


## Numbers and cell ranges carry the same information as the beam and its hum.
func status_text() -> String:
	if phase == Phase.FAILED:
		return failure_reason
	var clock := "UNTIMED PREVIEW" if phase == Phase.READY else (
		"NO DEADLINE" if relaxed else "%ds left" % ceili(remaining_seconds)
	)
	if phase == Phase.SOLVED:
		clock = "RELAY RESTORED"
	return "Cells %d-%d: %d charge\nRecord %d at cells %d-%d\n%s" % [
		start_index + 1, start_index + width, charge,
		best_charge, best_start + 1, best_start + width, clock,
	]


func _remember_charge() -> void:
	if charge > best_charge:
		best_charge = charge
		best_start = start_index


func _first_charge() -> int:
	var total := 0
	for index in range(width):
		total += tiles[index]
	return total


func _find_maximum() -> int:
	# Start from a real segment, not zero: all-negative rails must still work.
	var running := _first_charge()
	var best := running
	for index in range(width, tiles.size()):
		running += tiles[index] - tiles[index - width]
		best = maxi(best, running)
	return best
