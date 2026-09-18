extends "res://games/creep_code/puzzles/puzzle_state.gd"

## Path compression and union by size keep network queries nearly constant.
## Undo rebuilds this small forest; it does not attempt to reverse compression.

var island_count := 0
var sockets: Array[Vector2i] = []
var selected_bridge := 0
var bridges: Array[int] = []
var bridge_limit := 0
var components := 0
var _parents: Array[int] = []
var _sizes: Array[int] = []
var _emblems: Array[int] = []


func _init(islands: int, connections: Array[Vector2i]) -> void:
	if islands < 2 or connections.is_empty():
		_invalid_configuration("The archipelago needs at least two islands and bridge sockets.")
		return
	var seen: Array[Vector2i] = []
	for edge in connections:
		if edge.x < 0 or edge.y < 0 or edge.x >= islands or edge.y >= islands or edge.x == edge.y:
			_invalid_configuration("Each bridge must join two distinct, existing islands.")
			return
		var ordered := Vector2i(mini(edge.x, edge.y), maxi(edge.x, edge.y))
		if seen.has(ordered):
			_invalid_configuration("Bridge sockets must not repeat an island pair.")
			return
		seen.append(ordered)
	island_count = islands
	sockets = connections.duplicate()
	bridge_limit = island_count - 1
	_reset_forest()
	for edge in sockets:
		_join(edge.x, edge.y)
	if components != 1:
		_invalid_configuration("The authored bridge sockets must connect every island.")
		return
	reset()


func reset() -> void:
	super.reset()
	selected_bridge = 0
	bridges.clear()
	_reset_forest()
	changed.emit()


func select_bridge(index: int) -> bool:
	if phase != Phase.READY and phase != Phase.ACTIVE:
		return false
	if index < 0 or index >= sockets.size():
		cue.emit("Choose a numbered bridge socket.", &"blocked")
		return false
	selected_bridge = index
	changed.emit()
	cue.emit("Bridge %d joins islands %d and %d. Connect separate networks." % [
		index + 1, sockets[index].x + 1, sockets[index].y + 1,
	], &"shift")
	return true


func connect_selected() -> bool:
	if phase != Phase.ACTIVE:
		return false
	var edge := sockets[selected_bridge]
	if not _join(edge.x, edge.y):
		cue.emit("Already connected. That bridge adds no network; no charge spent.", &"blocked")
		return false
	bridges.append(selected_bridge)
	if components == 1:
		_succeed()
	else:
		changed.emit()
		cue.emit("Networks merged. %d remain; %d bridges left." % [
			components, bridge_limit - bridges.size(),
		], &"connect")
	return true


func undo() -> bool:
	if phase != Phase.ACTIVE:
		return false
	if bridges.is_empty():
		cue.emit("There is no built bridge to undo.", &"blocked")
		return false
	selected_bridge = bridges.pop_back()
	_reset_forest()
	for index in bridges:
		var edge := sockets[index]
		_join(edge.x, edge.y)
	changed.emit()
	cue.emit("Last bridge returned. Its charge is available again.", &"reset")
	return true


func component(island: int) -> int:
	if island < 0 or island >= island_count:
		push_error("Archipelago component queries require an existing island.")
		return -1
	return _emblems[_root(island)]


func hint() -> String:
	hints_used += 1
	if hints_used == 1:
		return "A bridge matters when it joins two separate worlds."
	return (
		"Islands with the same NET number already share power, even without a direct bridge. "
		+ "Join different numbers. Undo returns your last bridge and its charge."
	)


func status_text() -> String:
	if phase == Phase.FAILED:
		return failure_reason
	var edge := sockets[selected_bridge]
	return "Bridge %d (%d-%d)  |  NET %d -> %d  |  %d networks" % [
		selected_bridge + 1, edge.x + 1, edge.y + 1,
		component(edge.x) + 1, component(edge.y) + 1, components,
	]


func _reset_forest() -> void:
	_parents.clear()
	_sizes.clear()
	_emblems.clear()
	for island in range(island_count):
		_parents.append(island)
		_sizes.append(1)
		_emblems.append(island)
	components = island_count


func _root(island: int) -> int:
	while _parents[island] != island:
		_parents[island] = _parents[_parents[island]]
		island = _parents[island]
	return island


func _join(first: int, second: int) -> bool:
	var a := _root(first)
	var b := _root(second)
	if a == b:
		return false
	if _sizes[a] < _sizes[b]:
		var swap := a
		a = b
		b = swap
	_parents[b] = a
	_sizes[a] += _sizes[b]
	_emblems[a] = mini(_emblems[a], _emblems[b])
	components -= 1
	return true
