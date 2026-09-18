extends "res://games/creep_code/puzzles/puzzle_state.gd"

## The Whisper Shaft: truthful comparisons shrink an inclusive floor interval.
##
## The beacon is fixed for an attempt and its retries. A higher/lower answer
## excludes the queried floor as well as the impossible side. Midpoint choices
## therefore guarantee success within floor(log2(n)) + 1 probes; the player,
## not an automatic selector, chooses each new midpoint.

var floor_count := 15
var hidden_floor := 1
var lower_bound := 1
var upper_bound := 15
var selected_floor := 1
var elevator_floor := 1
var probe_limit := 4
var probes_used := 0
var last_clue := "The beacon waits behind one listening door."
var visited_floors: Array[int] = []


func _init(floors: int, target: int) -> void:
	if floors < 1 or target < 1 or target > floors:
		_invalid_configuration("The hidden floor must be inside a nonempty shaft.")
		return
	floor_count = floors
	hidden_floor = target
	# k comparisons can distinguish at most 2^k - 1 floors. Integer arithmetic
	# avoids a rounding error at powers of two or a one-floor shaft.
	var covered := 0
	probe_limit = 0
	while covered < floor_count:
		covered = covered * 2 + 1
		probe_limit += 1
	reset()


## Retries restore every shutter and charge, but never move the beacon.
func reset() -> void:
	super.reset()
	lower_bound = 1
	upper_bound = floor_count
	selected_floor = 1
	elevator_floor = 1
	probes_used = 0
	visited_floors.clear()
	last_clue = "Select a floor. A listening door will say higher or lower."
	changed.emit()


## Sealed floors cannot waste a probe or accidentally widen the search range.
func select_floor(floor_number: int) -> bool:
	if phase != Phase.READY and phase != Phase.ACTIVE:
		return false
	if floor_number < lower_bound or floor_number > upper_bound:
		cue.emit("That floor is sealed. Choose inside the open interval.", &"blocked")
		return false
	selected_floor = floor_number
	changed.emit()
	return true


## A probe counts once, including the successful final probe. A last-charge hit
## wins before exhaustion is considered, avoiding the usual off-by-one failure.
func probe() -> bool:
	if phase != Phase.ACTIVE:
		return false
	probes_used += 1
	elevator_floor = selected_floor
	visited_floors.append(selected_floor)
	if selected_floor == hidden_floor:
		last_clue = "The beacon answers on floor %d." % selected_floor
		_succeed()
		return true

	if selected_floor < hidden_floor:
		lower_bound = selected_floor + 1
		last_clue = "HIGHER than floor %d. The lower doors are sealed." % selected_floor
		cue.emit(last_clue, &"higher")
	else:
		upper_bound = selected_floor - 1
		last_clue = "LOWER than floor %d. The upper doors are sealed." % selected_floor
		cue.emit(last_clue, &"lower")

	# Park at the nearest surviving floor, not its midpoint: discovering the
	# value of a balanced next question remains the player's decision.
	selected_floor = clampi(selected_floor, lower_bound, upper_bound)
	if probes_used >= probe_limit:
		_fail("The listening charges are spent. Reset the shaft to try again.")
	else:
		changed.emit()
	return false


## Hints refer only to the surviving interval, never to the secret target.
func hint() -> String:
	hints_used += 1
	if hints_used == 1:
		return "A good question silences half the tower."
	var middle := lower_bound + (upper_bound - lower_bound) / 2
	return "Floors %d-%d are still open. Floor %d divides them almost evenly." % [
		lower_bound, upper_bound, middle,
	]


## The remaining interval is always readable, even with motion and sound off.
func status_text() -> String:
	if phase == Phase.FAILED:
		return failure_reason
	if phase == Phase.SOLVED:
		return "BEACON FOUND  |  Floor %d  |  %d/%d charges used" % [
			hidden_floor, probes_used, probe_limit,
		]
	return "Select floor %d  |  Open %d-%d  |  %d/%d charges remain" % [
		selected_floor, lower_bound, upper_bound, probe_limit - probes_used, probe_limit,
	]
