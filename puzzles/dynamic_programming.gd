extends "res://games/creep_code/puzzles/puzzle_state.gd"

## Each plaque remembers cost[i] + min(best[i - 1], best[i - 2]).
## The free entrance is step -1. Both the first and second landing are reachable.

var costs: Array[int] = []
var records: Array[int] = []
var player_step := -1
var selected_stride := 1
var energy_used := 0
var energy_budget := 0
var moves_used := 0
var records_complete: bool:
	get:
		return not costs.is_empty() and records.size() == costs.size()


func _init(landing_costs: Array[int]) -> void:
	if landing_costs.is_empty():
		_invalid_configuration("The memory stair needs at least one landing.")
		return
	for cost in landing_costs:
		if cost < 0:
			_invalid_configuration("Stair landing costs must be nonnegative.")
			return
	costs = landing_costs.duplicate()
	var best: Array[int] = []
	for index in range(costs.size()):
		var one := best[index - 1] if index > 0 else 0
		var two := best[index - 2] if index > 1 else 0
		best.append(costs[index] + mini(one, two))
	energy_budget = best.back()
	reset()


func reset() -> void:
	super.reset()
	records.clear()
	player_step = -1
	selected_stride = 1
	energy_used = 0
	moves_used = 0
	changed.emit()


func retry() -> void:
	phase = Phase.ACTIVE
	failure_reason = ""
	player_step = -1
	selected_stride = 1
	energy_used = 0
	moves_used = 0
	changed.emit()


func select_stride(stride: int) -> bool:
	if phase != Phase.ACTIVE:
		return false
	if not _valid_stride(stride):
		return false
	selected_stride = stride
	changed.emit()
	cue.emit(
		"Choose the record %d step(s) behind, then inscribe." % stride if not records_complete
		else "Climb %d step(s) when ready." % stride,
		&"shift"
	)
	return true


func select_landing(index: int) -> bool:
	return select_stride(index - player_step if records_complete else records.size() - index)


func confirm() -> bool:
	if phase != Phase.ACTIVE:
		return false
	if records_complete:
		return step(selected_stride)
	var index := records.size()
	var predecessor := index - selected_stride
	var proposed := costs[index] + _record_at(predecessor)
	var cheapest := costs[index] + mini(
		_record_at(index - 1), _record_at(index - 2) if index > 0 else 0
	)
	if proposed != cheapest:
		cue.emit("That arrival costs %d. The other remembered route is cheaper." % proposed, &"blocked")
		return false
	records.append(proposed)
	selected_stride = 1
	changed.emit()
	if records_complete:
		cue.emit("All plaques remembered. Reach the summit with %d energy; choose one or two steps." % [
			energy_budget,
		], &"heard")
	else:
		cue.emit("Plaque %d remembers %d. Compare the next landing's two predecessors." % [
			index + 1, proposed,
		], &"record")
	return true


func step(stride: int) -> bool:
	if phase != Phase.ACTIVE:
		return false
	if not records_complete:
		cue.emit("Remember each landing's cheapest arrival before climbing.", &"blocked")
		return false
	if not _valid_stride(stride):
		return false
	player_step += stride
	energy_used += costs[player_step]
	moves_used += 1
	if energy_used > energy_budget:
		_fail("The stair spent too much energy. Retry; your remembered plaques stay lit.")
	elif player_step == costs.size() - 1:
		_succeed()
	else:
		selected_stride = 1
		changed.emit()
		cue.emit("Landing %d. %d energy remains." % [
			player_step + 1, energy_budget - energy_used,
		], &"step")
	return true


func cheapest_path() -> Array[int]:
	var path: Array[int] = []
	if not records_complete:
		return path
	var index := costs.size() - 1
	path.append(index)
	while index >= 0:
		var previous := index - 1
		if index > 0 and _record_at(index - 2) < _record_at(previous):
			previous = index - 2
		path.append(previous)
		index = previous
	path.reverse()
	return path


func hint() -> String:
	hints_used += 1
	if hints_used == 1:
		return "Remember the cheapest way here. Build the next step from that."
	if not records_complete:
		return (
			"Choose the smaller BEST total one or two landings behind, not the smaller landing fee. "
			+ "Add this landing's fee. START has a remembered total of zero."
		)
	return (
		"Trace backward from the summit: its BEST total is its fee plus one predecessor's BEST. "
		+ "Reverse those choices to climb. The cheapest next fee alone can waste energy."
	)


func status_text() -> String:
	if phase == Phase.FAILED:
		return failure_reason
	if not records_complete:
		var index := records.size()
		return "Plaque %d/%d, fee %d | BEST: 1 back %d; 2 back %s" % [
			index + 1, costs.size(), costs[index], _record_at(index - 1),
			str(_record_at(index - 2)) if index > 0 else "--",
		]
	return "%s  |  Energy %d/%d  |  Choose one or two steps" % [
		"START" if player_step < 0 else "Landing %d" % (player_step + 1),
		energy_used, energy_budget,
	]


func _valid_stride(stride: int) -> bool:
	if stride != 1 and stride != 2:
		cue.emit("Choose a landing exactly one or two steps away.", &"blocked")
		return false
	if records_complete and player_step + stride >= costs.size():
		cue.emit("That stride would pass the summit. Choose one step.", &"blocked")
		return false
	if not records_complete and records.size() - stride < -1:
		cue.emit("The first plaque can only remember START, one step behind.", &"blocked")
		return false
	return true


func _record_at(index: int) -> int:
	return 0 if index == -1 else records[index]
