extends "res://games/creep_code/puzzles/puzzle_state.gd"

## The Echo Garden: a breadth-first wave across an unweighted, four-way maze.
##
## Each frontier is exactly one crossing farther from the source. A cell is
## marked when enqueued, not when visited, so cycles cannot duplicate it or
## replace its first (shortest) predecessor. The player reconstructs the route.

const DIRECTIONS: Array[Vector2i] = [
	Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT,
]
const WAVE_SECONDS := 0.32

var rows := PackedStringArray()
var start := Vector2i.ZERO
var goal := Vector2i.ZERO
var player_cell := Vector2i.ZERO
var distances: Dictionary[Vector2i, int] = {}
var parents: Dictionary[Vector2i, Vector2i] = {}
var pulse_finished := false
var moves_used := 0
var shortest_distance := -1
var wave_distance := 0
var _frontier: Array[Vector2i] = []
var _wave_time := 0.0


func _init(layout: PackedStringArray) -> void:
	if layout.is_empty() or layout[0].is_empty():
		_invalid_configuration("The garden needs a nonempty rectangular map.")
		return
	var starts := 0
	var goals := 0
	for y in range(layout.size()):
		if layout[y].length() != layout[0].length():
			_invalid_configuration("Every garden row must have the same width.")
			return
		for x in range(layout[y].length()):
			var cell := layout[y][x]
			if cell == "S":
				start = Vector2i(x, y)
				starts += 1
			elif cell == "G":
				goal = Vector2i(x, y)
				goals += 1
			elif cell != "." and cell != "#":
				_invalid_configuration("Garden cells must be S, G, . or #.")
				return
	if starts != 1 or goals != 1:
		_invalid_configuration("The garden needs exactly one entrance and exit.")
		return
	rows = layout.duplicate()
	reset()


## A rewind preserves the map, letting observations remain useful on retry.
func reset() -> void:
	super.reset()
	player_cell = start
	distances.clear()
	parents.clear()
	_frontier.clear()
	_wave_time = 0.0
	wave_distance = 0
	pulse_finished = false
	moves_used = 0
	shortest_distance = -1
	changed.emit()


## Once the map is known, a retry rewinds the walk, not the lesson. Keeping
## the distance field avoids making a mistaken turn replay the same reveal.
func retry() -> void:
	if not pulse_finished or shortest_distance < 0:
		reset()
		return
	phase = Phase.ACTIVE
	failure_reason = ""
	player_cell = start
	moves_used = 0
	changed.emit()


## The initial pulse is emitted from the player's entrance platform.
func activate() -> void:
	if phase != Phase.READY:
		return
	distances[start] = 0
	_frontier.assign([start])
	super.activate()
	cue.emit("The lantern is listening along every path at once.", &"pulse")


## Whole distance layers advance together, even after a slow frame.
func advance(delta: float) -> void:
	if phase != Phase.ACTIVE or pulse_finished:
		return
	if delta < 0.0 or not is_finite(delta):
		push_error("Echo Garden requires a nonnegative, finite time step.")
		return
	_wave_time += delta
	while _wave_time >= WAVE_SECONDS and not pulse_finished:
		_wave_time -= WAVE_SECONDS
		_expand_frontier()


## Walkways all cost one charge. Walls and premature moves cost nothing and
## produce explicit feedback; a genuine detour consumes the limited budget.
func step(direction: Vector2i) -> bool:
	if phase != Phase.ACTIVE:
		return false
	if not pulse_finished:
		cue.emit("Let the echoes settle before choosing your route.", &"blocked")
		return false
	if not DIRECTIONS.has(direction) or not is_open(player_cell + direction):
		cue.emit("No walkway in that direction.", &"blocked")
		return false
	player_cell += direction
	moves_used += 1
	if player_cell == goal:
		_succeed()
	elif moves_used >= shortest_distance:
		_fail("The lantern is empty. Rewind and follow a shorter route.")
	else:
		changed.emit()
		cue.emit("%d crossings remain." % (shortest_distance - moves_used), &"step")
	return true


## Both the physical view and the model use the same walkability predicate.
func is_open(cell: Vector2i) -> bool:
	return (
		cell.y >= 0 and cell.y < rows.size()
		and cell.x >= 0 and cell.x < rows[0].length()
		and rows[cell.y][cell.x] != "#"
	)


## The first-discovery tree yields one shortest route; it is not automatically
## painted onto the garden, so finding a route remains a player action.
func shortest_path() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not distances.has(goal):
		return result
	var cell := goal
	result.append(cell)
	while cell != start:
		cell = parents[cell]
		result.append(cell)
	result.reverse()
	return result


## Reading the inscriptions backward avoids mistaking a nearby dead end for
## a route to the exit; more than one equally short route may be valid.
func hint() -> String:
	hints_used += 1
	if hints_used == 1:
		return "Where the light arrives first, the journey is shortest."
	if not pulse_finished:
		return "Equal numbers mean equal distances, even on different branches."
	return "Find EXIT %d on the platforms. Trace %d, %d, ... back to entrance 0." % [
		shortest_distance, shortest_distance - 1, maxi(shortest_distance - 2, 0),
	]


## The budget counts edges, not platforms or diagonal world-space distance.
func status_text() -> String:
	if phase == Phase.FAILED:
		return failure_reason
	if phase == Phase.READY:
		return "The lantern is ready. Send a pulse before taking a step."
	if phase == Phase.SOLVED:
		return "EXIT REACHED  |  %d crossings, no wasted charge" % moves_used
	if not pulse_finished:
		return "Echo layer %d  |  %d platforms heard" % [wave_distance, distances.size()]
	return "Shortest route %d crossings  |  %d charges left" % [
		shortest_distance, shortest_distance - moves_used,
	]


func _expand_frontier() -> void:
	var next: Array[Vector2i] = []
	for cell in _frontier:
		for direction in DIRECTIONS:
			var neighbor := cell + direction
			if not is_open(neighbor) or distances.has(neighbor):
				continue
			distances[neighbor] = distances[cell] + 1
			parents[neighbor] = cell
			next.append(neighbor)
	_frontier = next
	if next.is_empty():
		pulse_finished = true
		if not distances.has(goal):
			_fail("The exit cannot hear this lantern. The garden map is disconnected.")
			return
		shortest_distance = distances[goal]
		cue.emit("The exit answered after %d crossings. Choose your route." % [
			shortest_distance,
		], &"heard")
	else:
		wave_distance += 1
	changed.emit()
