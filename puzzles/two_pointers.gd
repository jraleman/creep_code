extends "res://games/creep_code/puzzles/puzzle_state.gd"

## Sorted endpoints let each discarded pylon rule out an entire set of pairs.
## Equal values are allowed, but the two wardens must occupy distinct pylons.

var values: Array[int] = []
var target_charge := 0
var left_index := 0
var right_index := 0
var charge := 0
var moves_used := 0


func _init(pylons: Array[int], target: int) -> void:
	if pylons.size() < 2:
		_invalid_configuration("The wardens need at least two sorted pylons.")
		return
	for index in range(1, pylons.size()):
		if pylons[index] < pylons[index - 1]:
			_invalid_configuration("Warden charges must be sorted from low to high.")
			return
	var left := 0
	var right := pylons.size() - 1
	while left < right and pylons[left] + pylons[right] != target:
		if pylons[left] + pylons[right] < target:
			left += 1
		else:
			right -= 1
	if left == right:
		_invalid_configuration("The warden target needs a pair of distinct pylons.")
		return
	values = pylons.duplicate()
	target_charge = target
	reset()


func reset() -> void:
	super.reset()
	left_index = 0
	right_index = values.size() - 1
	charge = values[left_index] + values[right_index]
	moves_used = 0
	changed.emit()


func activate() -> void:
	if phase != Phase.READY:
		return
	super.activate()
	_compare()


func discard(index: int) -> bool:
	if phase != Phase.ACTIVE:
		return false
	if index != left_index and index != right_index:
		cue.emit("Tap a warden's endpoint, not a pylon between them.", &"blocked")
		return false
	if index == left_index:
		left_index += 1
	else:
		right_index -= 1
	moves_used += 1
	charge = values[left_index] + values[right_index]
	if left_index == right_index:
		_fail("The wardens met without a pair. Retry and use the low / high clues.")
	else:
		changed.emit()
		_compare()
	return true


func confirm() -> bool:
	if phase != Phase.ACTIVE:
		return false
	if charge == target_charge:
		_succeed()
		return true
	_compare()
	return false


func hint() -> String:
	hints_used += 1
	if hints_used == 1:
		return "Too faint? Leave the faintest behind. Too bright? Leave the brightest."
	if charge == target_charge:
		return "These two distinct pylons balance the gate. Lock the pair."
	return (
		"No other partner can make the left pylon's sum larger. Discard that left endpoint."
		if charge < target_charge else
		"No other partner can make the right pylon's sum smaller. Discard that right endpoint."
	)


func status_text() -> String:
	if phase == Phase.FAILED:
		return failure_reason
	return "%d + %d = %d  |  TARGET %d  |  %d pylons remain" % [
		values[left_index], values[right_index], charge, target_charge,
		right_index - left_index + 1,
	]


func _compare() -> void:
	if charge < target_charge:
		cue.emit("TOO FAINT: %d / %d. Advance the left warden." % [
			charge, target_charge,
		], &"higher")
	elif charge > target_charge:
		cue.emit("TOO BRIGHT: %d / %d. Advance the right warden." % [
			charge, target_charge,
		], &"lower")
	else:
		cue.emit("BALANCED: %d + %d = %d. Lock the pair." % [
			values[left_index], values[right_index], target_charge,
		], &"heard")
