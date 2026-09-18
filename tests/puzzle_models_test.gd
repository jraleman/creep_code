extends SceneTree

## Exhaustive small inputs pin the algorithms independently of rendering,
## settings, autoload instances and the developer's saved completion flags.

const State = preload("res://games/creep_code/puzzles/puzzle_state.gd")
const Sunrail = preload("res://games/creep_code/puzzles/sliding_window.gd")
const Shaft = preload("res://games/creep_code/puzzles/binary_search.gd")
const Garden = preload("res://games/creep_code/puzzles/breadth_first.gd")
const Wardens = preload("res://games/creep_code/puzzles/two_pointers.gd")
const Archipelago = preload("res://games/creep_code/puzzles/union_find.gd")
const Stair = preload("res://games/creep_code/puzzles/dynamic_programming.gd")
const Manager = preload("res://games/creep_code/puzzle_manager.gd")
const Options = preload("res://games/creep_code/creep_code_options.gd")
const Definition = preload("res://games/creep_code/game.gd")
const LOOP_GARDEN := ["S..", ".#.", "..G"]

var _failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_rolling_charge()
	_test_direct_selection()
	_test_charge_deadline()
	_test_every_hidden_floor()
	_test_shaft_exhaustion()
	_test_garden_layers_and_routes()
	_test_garden_failures()
	_test_warden_pairs()
	_test_warden_retry()
	_test_island_networks()
	_test_stair_records()
	_test_stair_retry()
	_test_manager()
	_test_fixed_configuration()
	if _failures.is_empty():
		print("Creep Code puzzle model tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _test_rolling_charge() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1807
	for count in range(1, 25):
		var values: Array[int] = []
		for index in range(count):
			values.append(rng.randi_range(-9, 9))
		for width in range(1, count + 1):
			var rail := Sunrail.new(values, width, 5.0)
			var expected_best := -9223372036854775807
			for start in range(count - width + 1):
				var total := 0
				for index in range(start, start + width):
					total += values[index]
				expected_best = maxi(expected_best, total)
				_expect(rail.charge == total, "Rightward scan must retain the exact segment sum.")
				if start < count - width:
					_expect(rail.shift(1), "Every in-bounds rightward scan must move.")
			_expect(rail.maximum_charge == expected_best and rail.best_charge == expected_best,
				"The target and observed best must equal an independent brute-force maximum.")
			for start in range(count - width, -1, -1):
				var total := 0
				for index in range(start, start + width):
					total += values[index]
				_expect(rail.charge == total, "Leftward scans must exchange the opposite end cells.")
				if start > 0:
					rail.shift(-1)
			rail.activate()
			for shift_count in range(count):
				if rail.charge == expected_best:
					break
				rail.shift(1)
			_expect(rail.confirm() and rail.phase == State.Phase.SOLVED,
				"An actual global maximum must solve, including an all-negative rail.")
			_expect(not rail.confirm(), "A solved rail must not award completion twice.")
	var tied := Sunrail.new([3, 1, 3, 1], 2)
	tied.activate()
	tied.shift(1)
	_expect(tied.confirm(), "Any tied maximum is a valid solution.")
	var negative := Sunrail.new([-8, -5, -2, -9], 2)
	_expect(negative.maximum_charge == -7, "A negative-only rail must not use zero as its maximum.")


func _test_charge_deadline() -> void:
	var rail := Sunrail.new([1, 2, 8, 4], 2, 2.0)
	rail.shift(1)
	rail.advance(50.0)
	_expect(rail.phase == State.Phase.READY and rail.remaining_seconds == 2.0,
		"The preview must remain untimed.")
	rail.activate()
	_expect(rail.start_index == 1 and rail.best_charge == 10,
		"Arming must retain the chosen frame and discoveries from the untimed preview.")
	_expect(not rail.confirm() and rail.phase == State.Phase.ACTIVE,
		"A weak lock must give feedback without losing the entire attempt.")
	rail.advance(0.5)
	rail.set_relaxed(true)
	rail.advance(50.0)
	_expect(rail.remaining_seconds == 1.5, "The live untimed assist must preserve remaining time.")
	rail.set_relaxed(false)
	rail.advance(1.5)
	_expect(rail.phase == State.Phase.FAILED and rail.remaining_seconds == 0.0,
		"The precise deadline must fail once, without a negative timer.")
	rail.advance(4.0)
	_expect(not rail.confirm(), "An expired capacitor must not be lockable.")
	rail.reset()
	_expect(rail.phase == State.Phase.READY and rail.remaining_seconds == 2.0,
		"Reset must restore this attempt's timer and input state.")


func _test_direct_selection() -> void:
	var rail := Sunrail.new([5, 9, 2, 1], 1)
	_expect(rail.select_start(3) and rail.charge == 1 and rail.best_charge == 5,
		"Direct selection must inspect only the chosen range, not reveal skipped maxima.")
	_expect(not rail.select_start(4) and rail.start_index == 3,
		"An out-of-bounds direct selection must leave the frame intact.")
	rail.activate()
	_expect(rail.start_index == 3, "Arming must not move a directly selected rune.")
	rail.select_start(1)
	_expect(rail.confirm(), "Touch selection must reach the same solution as directional shifts.")
	_expect(not rail.select_start(0), "A solved frame must stay fixed until an explicit retry.")
	var values: Array[int] = [4, -2, 6, 3, -4, 8, 2]
	for width in range(1, values.size() + 1):
		var scan := Sunrail.new(values, width)
		for start in range(values.size() - width, -1, -1):
			scan.select_start(start)
			var expected := 0
			for index in range(start, start + width):
				expected += values[index]
			_expect(scan.charge == expected,
				"Every direct scan must equal an independent sum, including draining cells.")


func _test_every_hidden_floor() -> void:
	for count in range(1, 66):
		for hidden in range(1, count + 1):
			var shaft := Shaft.new(count, hidden)
			shaft.activate()
			for attempt in range(shaft.probe_limit):
				if shaft.phase != State.Phase.ACTIVE:
					break
				var middle := shaft.lower_bound + (shaft.upper_bound - shaft.lower_bound) / 2
				var previous_width := shaft.upper_bound - shaft.lower_bound + 1
				_expect(shaft.select_floor(middle), "The midpoint must always be an open floor.")
				shaft.probe()
				_expect(hidden >= shaft.lower_bound and hidden <= shaft.upper_bound,
					"A truthful clue must never discard the hidden floor.")
				if shaft.phase == State.Phase.ACTIVE:
					_expect(shaft.upper_bound - shaft.lower_bound + 1 <= previous_width / 2,
						"A midpoint probe must eliminate at least half the candidates.")
			_expect(shaft.phase == State.Phase.SOLVED and shaft.probes_used <= shaft.probe_limit,
				"Halving must find every possible target within the advertised budget.")
			var before := shaft.probes_used
			shaft.probe()
			_expect(shaft.probes_used == before, "A solved shaft cannot consume another probe.")


func _test_shaft_exhaustion() -> void:
	var shaft := Shaft.new(15, 15)
	shaft.activate()
	shaft.probe()
	_expect(shaft.lower_bound == 2 and shaft.upper_bound == 15,
		"Higher must exclude the queried floor itself.")
	_expect(not shaft.select_floor(1) and shaft.probes_used == 1,
		"Selecting a sealed floor must not consume a charge.")
	for attempt in range(shaft.probe_limit):
		if shaft.phase != State.Phase.ACTIVE:
			break
		shaft.select_floor(shaft.lower_bound)
		shaft.probe()
	_expect(shaft.phase == State.Phase.FAILED and shaft.probes_used == 4,
		"Linear guessing must exhaust the four-charge budget.")
	shaft.reset()
	_expect(shaft.hidden_floor == 15 and shaft.lower_bound == 1 and shaft.probes_used == 0,
		"Retry must reopen floors without secretly moving the target.")
	var final_hit := Shaft.new(15, 1)
	final_hit.activate()
	for floor_number in [8, 4, 2, 1]:
		final_hit.select_floor(floor_number)
		final_hit.probe()
	_expect(final_hit.phase == State.Phase.SOLVED and final_hit.probes_used == 4,
		"A hit on the last charge must win, not fail from exhaustion.")


func _test_garden_layers_and_routes() -> void:
	var gardens: Array[Array] = [LOOP_GARDEN, Options.GARDEN_ROWS, [
		"S..#...", ".#.#.#.", ".#...#.", "...#...", "##.#.#.", "...#.#.", ".#....G",
	]]
	var expected_lengths: Array[int] = [4, 8, 12]
	for index in range(gardens.size()):
		var garden := Garden.new(PackedStringArray(gardens[index]))
		garden.activate()
		_expect(garden.distances.size() == 1, "A new wave must start only at the entrance.")
		garden.advance(Garden.WAVE_SECONDS)
		for cell in garden.distances:
			_expect(garden.distances[cell] <= 1, "One beat must reveal exactly one edge layer.")
		garden.advance(100.0)
		_expect(garden.pulse_finished and garden.shortest_distance == expected_lengths[index],
			"The authored garden must have its advertised shortest path.")
		var open_cells := 0
		for row in garden.rows:
			for character in row:
				if character != "#":
					open_cells += 1
		_expect(garden.distances.size() == open_cells,
			"Every authored platform must be reachable and discovered once despite loops.")
		for cell in garden.parents:
			_expect(garden.distances[cell] == garden.distances[garden.parents[cell]] + 1,
				"Every first-discovery predecessor must be one crossing closer to the entrance.")
		var path := garden.shortest_path()
		_expect(path.size() == expected_lengths[index] + 1,
			"A path has one more platform than crossings.")
		for step in range(1, path.size()):
			_expect(garden.step(path[step] - path[step - 1]), "Every shortest-path edge must be playable.")
		_expect(garden.phase == State.Phase.SOLVED and garden.moves_used == expected_lengths[index],
			"Following a shortest path must consume exactly the budget and win.")
	var alternate := Garden.new(PackedStringArray(LOOP_GARDEN))
	alternate.activate()
	alternate.advance(100.0)
	for direction in [Vector2i.DOWN, Vector2i.DOWN, Vector2i.RIGHT, Vector2i.RIGHT]:
		alternate.step(direction)
	_expect(alternate.phase == State.Phase.SOLVED, "A different tied shortest path must also win.")


func _test_garden_failures() -> void:
	var garden := Garden.new(PackedStringArray(LOOP_GARDEN))
	garden.activate()
	_expect(not garden.step(Vector2i.RIGHT) and garden.moves_used == 0,
		"Walking before the pulse settles must not consume charge.")
	garden.advance(100.0)
	_expect(not garden.step(Vector2i.LEFT), "An edge of the map is not a walkway.")
	garden.step(Vector2i.RIGHT)
	_expect(not garden.step(Vector2i.DOWN) and garden.moves_used == 1,
		"A wall must reject movement without charging for an impossible step.")
	garden.step(Vector2i.LEFT)
	garden.step(Vector2i.RIGHT)
	garden.step(Vector2i.RIGHT)
	_expect(garden.phase == State.Phase.FAILED and garden.moves_used == 4,
		"A real detour must exhaust the shortest-route budget.")
	var revealed := garden.distances.duplicate()
	garden.retry()
	_expect(garden.phase == State.Phase.ACTIVE and garden.moves_used == 0
		and garden.player_cell == garden.start and garden.distances == revealed
		and garden.pulse_finished and garden.shortest_distance == 4,
		"Retry must rewind a revealed garden immediately without replaying its wave.")
	for direction in [Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.DOWN]:
		garden.step(direction)
	_expect(garden.phase == State.Phase.SOLVED,
		"A retained wave must still support a valid shortest-route solve.")
	garden.reset()
	_expect(garden.player_cell == garden.start and garden.distances.is_empty(),
		"Rewind must return the lantern and its wave to the entrance.")
	var disconnected := Garden.new(PackedStringArray(["S#G"]))
	disconnected.activate()
	disconnected.advance(2.0)
	_expect(disconnected.phase == State.Phase.FAILED,
		"A disconnected map must report an explicit failure, not a success-shaped empty path.")


func _test_warden_pairs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9117
	for count in range(2, 12):
		for sample in range(8):
			var values: Array[int] = []
			for index in range(count):
				values.append(rng.randi_range(-8, 12))
			values.sort()
			var targets: Array[int] = []
			for left in range(count):
				for right in range(left + 1, count):
					var target := values[left] + values[right]
					if not targets.has(target):
						targets.append(target)
			for target in targets:
				var state := Wardens.new(values, target)
				state.activate()
				for move in range(count):
					if state.charge == target:
						break
					state.discard(state.left_index if state.charge < target else state.right_index)
				_expect(state.left_index < state.right_index and state.confirm()
					and state.phase == State.Phase.SOLVED and state.moves_used <= count - 2,
					"Two pointers must find every attainable target, including negative charges and duplicates.")
				var moves := state.moves_used
				_expect(not state.confirm() and not state.discard(state.left_index)
					and state.moves_used == moves,
					"A solved warden pair must remain fixed and cannot award another seal.")
	var equal := Wardens.new([4, 4], 8)
	equal.activate()
	_expect(equal.confirm(), "Two equal-valued pylons are still distinct valid endpoints.")


func _test_warden_retry() -> void:
	var state := Wardens.new(Options.WARDEN_PYLONS, Options.WARDEN_TARGET)
	_expect(not state.discard(0), "Unarmed wardens cannot discard a pylon.")
	state.activate()
	_expect(not state.discard(3) and state.moves_used == 0,
		"A middle pylon must reject selection without silently moving an endpoint.")
	_expect(not state.confirm() and state.phase == State.Phase.ACTIVE,
		"An unbalanced pair must give a clue without ending the attempt.")
	for index in range(state.values.size() - 1):
		state.discard(state.left_index)
	_expect(state.phase == State.Phase.FAILED and state.left_index == state.right_index,
		"Meeting without a distinct pair must fail rather than count one pylon twice.")
	state.retry()
	_expect(state.phase == State.Phase.READY and state.left_index == 0
		and state.right_index == state.values.size() - 1 and state.moves_used == 0,
		"A warden retry must restore the exact sorted puzzle and both endpoints.")
	state.activate()
	state.advance(1000.0)
	_expect(state.phase == State.Phase.ACTIVE and state.moves_used == 0,
		"Wardens have no hidden countdown or animation-driven moves.")


func _test_island_networks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 818
	for count in range(2, 9):
		var edges: Array[Vector2i] = []
		for first in range(count):
			for second in range(first + 1, count):
				edges.append(Vector2i(first, second))
		for sample in range(12):
			var state := Archipelago.new(count, edges)
			state.activate()
			var order: Array[int] = []
			for index in range(edges.size()):
				order.append(index)
			for index in range(order.size() - 1, 0, -1):
				var other := rng.randi_range(0, index)
				var previous := order[index]
				order[index] = order[other]
				order[other] = previous
			for index in order:
				if state.phase == State.Phase.SOLVED:
					break
				state.select_bridge(index)
				var edge := edges[index]
				var separate := state.component(edge.x) != state.component(edge.y)
				var used := state.bridges.size()
				_expect(state.connect_selected() == separate
					and state.bridges.size() == used + (1 if separate else 0),
					"Only bridges joining separate components may consume a charge.")
				_check_components(state)
				if separate and state.phase == State.Phase.ACTIVE:
					_expect(state.undo() and state.bridges.size() == used,
						"Undo must return exactly the most recent bridge and charge.")
					_check_components(state)
					state.select_bridge(index)
					state.connect_selected()
			_expect(state.phase == State.Phase.SOLVED and state.components == 1
				and state.bridges.size() == count - 1 and not state.undo(),
				"A connected network must win with exactly n-1 bridges and remain restored.")
			state.reset()
			_expect(state.components == count and state.bridges.is_empty()
				and state.phase == State.Phase.READY,
				"A new archipelago must have no retained parents, bridges or spent charges.")
	var cycle := Archipelago.new(4, [
		Vector2i(0, 1), Vector2i(1, 2), Vector2i(0, 2), Vector2i(2, 3),
	])
	cycle.activate()
	_expect(not cycle.undo(), "Undo on an empty archipelago must not invent a bridge.")
	for index in [0, 1]:
		cycle.select_bridge(index)
		cycle.connect_selected()
	cycle.select_bridge(2)
	_expect(not cycle.connect_selected() and cycle.components == 2 and cycle.bridges.size() == 2,
		"An indirect cycle must be detected even when its direct bridge was never built.")
	_expect(not cycle.select_bridge(-1) and cycle.selected_bridge == 2,
		"Invalid socket input cannot change the selected bridge.")


func _check_components(state: Archipelago) -> void:
	for source in range(state.island_count):
		var reached: Array[int] = [source]
		var cursor := 0
		while cursor < reached.size():
			var island := reached[cursor]
			cursor += 1
			for index in state.bridges:
				var edge := state.sockets[index]
				var neighbor := edge.y if edge.x == island else (edge.x if edge.y == island else -1)
				if neighbor >= 0 and not reached.has(neighbor):
					reached.append(neighbor)
		for island in range(state.island_count):
			_expect((state.component(source) == state.component(island)) == reached.has(island),
				"Union-find connectivity must equal an independent graph traversal, including after undo.")
		reached.sort()
		_expect(state.component(source) == reached[0],
			"A network's visible emblem must consistently identify its lowest numbered island.")


func _test_stair_records() -> void:
	for count in range(1, 7):
		for encoding in range(int(pow(3, count))):
			var costs: Array[int] = []
			var digits := encoding
			for index in range(count):
				costs.append(digits % 3)
				digits /= 3
			var state := Stair.new(costs)
			_expect(state.energy_budget == _brute_stair(costs, -1, 0),
				"The stair budget must equal exhaustive route enumeration, including free and tied landings.")
			state.activate()
			_expect(not state.step(1) and state.energy_used == 0 and state.player_step == -1,
				"The player must build the remembered table before taking a charged step.")
			for index in range(count):
				var one := state.records[index - 1] if index > 0 else 0
				var two := state.records[index - 2] if index > 1 else 0
				if index > 0 and one != two:
					state.select_stride(1 if one > two else 2)
					_expect(not state.confirm() and state.records.size() == index,
						"A more expensive predecessor must not be recorded as the cheapest arrival.")
				state.select_stride(2 if index > 0 and two < one else 1)
				_expect(state.confirm() and state.records[index]
					== _brute_stair(costs.slice(0, index + 1), -1, 0),
					"Every remembered plaque must match an independent optimal route to that landing.")
			var path := state.cheapest_path()
			_expect(path[0] == -1 and path.back() == count - 1,
				"A reconstructed route must include the free entrance and the actual summit.")
			for index in range(1, path.size()):
				_expect(state.step(path[index] - state.player_step),
					"Every reconstructed edge must be a legal one- or two-step climb.")
			_expect(state.phase == State.Phase.SOLVED and state.energy_used == state.energy_budget
				and not state.confirm(),
				"A cheapest climb wins exactly once, including zero-energy summits.")


func _brute_stair(costs: Array[int], at: int, spent: int) -> int:
	if at == costs.size() - 1:
		return spent
	var best := 9223372036854775807
	for stride in [1, 2]:
		if at + stride < costs.size():
			best = mini(best, _brute_stair(costs, at + stride, spent + costs[at + stride]))
	return best


func _test_stair_retry() -> void:
	var state := Stair.new(Options.STAIR_COSTS)
	state.activate()
	_expect(not state.select_stride(2), "The first plaque has only the entrance as a predecessor.")
	while not state.records_complete:
		var index := state.records.size()
		var one := state.records[index - 1] if index > 0 else 0
		var two := state.records[index - 2] if index > 1 else 0
		state.select_stride(2 if index > 0 and two < one else 1)
		state.confirm()
	_expect(state.energy_budget == 17, "The authored eight-landing stair has an exact 17-energy optimum.")
	var remembered := state.records.duplicate()
	while state.phase == State.Phase.ACTIVE:
		var next := state.player_step + 1
		var stride := 2 if next + 1 < state.costs.size() and state.costs[next + 1] < state.costs[next] else 1
		state.step(stride)
	_expect(state.phase == State.Phase.FAILED,
		"Always choosing the cheapest next fee must not solve the authored memory lesson.")
	state.retry()
	_expect(state.phase == State.Phase.ACTIVE and state.records == remembered
		and state.player_step == -1 and state.energy_used == 0 and state.moves_used == 0,
		"Retry rewinds the climb but retains all remembered plaques.")
	_expect(not state.select_landing(5) and not state.step(0) and state.energy_used == 0,
		"A distant tap or invalid stride must not teleport the keeper or spend energy.")
	var path := state.cheapest_path()
	for index in range(1, path.size()):
		state.select_landing(path[index])
		state.confirm()
	_expect(state.phase == State.Phase.SOLVED, "Retained records must support a successful retry.")
	state.reset()
	_expect(state.phase == State.Phase.READY and state.records.is_empty(),
		"A fresh ritual must still start with an undiscovered stair.")


func _test_manager() -> void:
	var manager := Manager.new()
	var first := Sunrail.new([1, 3], 1, 2.0)
	var second := Shaft.new(1, 1)
	manager.register_puzzle(&"rail", "Rail", first)
	manager.register_puzzle(&"shaft", "Shaft", second)
	manager.begin_visit([])
	_expect(manager.current_id == &"rail" and manager.next_relic() == &"rail",
		"A new ritual must begin at its first relic, without a hub.")
	_expect(not manager.advance_to_next(), "An unrestored relic cannot be skipped.")
	first.activate()
	manager.advance(0.5)
	_expect(first.phase == State.Phase.ACTIVE and first.remaining_seconds == 1.5,
		"Only supplied puzzle time may spend a capacitor's budget.")
	_expect(second.phase == State.Phase.READY, "The next relic cannot run in the background.")
	first.shift(1)
	first.confirm()
	_expect(manager.completed == [&"rail"] and manager.lit_relays == [&"rail"]
		and manager.solved_this_visit.size() == 1,
		"A solve must light exactly its own seal, bank a point and retain permanent progress.")
	_expect(manager.next_relic() == &"shaft" and not manager.can_finish(),
		"A solved relic must lead to its successor, not prematurely finish the ritual.")
	manager.retry()
	_expect(manager.completed.has(&"rail"), "Retry must never revoke a completion.")
	first.activate()
	first.shift(1)
	first.confirm()
	_expect(manager.solved_this_visit.size() == 1, "Repeating a relic must not farm visit score.")
	_expect(manager.advance_to_next() and manager.current_id == &"shaft",
		"A restored relic must hand over to its successor.")
	second.activate()
	second.probe()
	_expect(manager.can_finish(), "Only every seal in this ritual may awaken the constellation.")
	_expect(manager.next_relic().is_empty() and not manager.advance_to_next(),
		"The last seal must end progression rather than mount a nonexistent relic.")
	manager.begin_visit([&"rail", &"shaft"])
	_expect(not manager.can_finish() and manager.lit_relays.is_empty()
		and manager.completed.size() == 2 and manager.solved_this_visit.is_empty()
		and manager.current_id == &"rail",
		"A complete save must offer a fresh ritual without erasing achievements.")
	_expect(first.phase == State.Phase.READY and first.remaining_seconds == 2.0
		and second.phase == State.Phase.READY,
		"A new ritual must reset transient attempts and their budgets.")
	manager.free()
	var resumed := Manager.new()
	resumed.register_puzzle(&"rail", "Rail", first)
	resumed.register_puzzle(&"shaft", "Shaft", second)
	resumed.begin_visit([&"rail"])
	_expect(resumed.current_id == &"shaft" and resumed.lit_relays == [&"rail"]
		and resumed.solved_this_visit.is_empty(),
		"A partial save prelights its earned seal and resumes at the first missing one.")
	second.activate()
	second.probe()
	_expect(resumed.can_finish() and resumed.solved_this_visit == [&"shaft"],
		"Resuming must count only the relic actually solved in this visit.")
	resumed.begin_visit([])
	_expect(resumed.completed.size() == 2,
		"A later incomplete save input must never revoke an already earned achievement.")
	resumed.free()


func _test_fixed_configuration() -> void:
	var manifest := Definition.manifest()
	_expect(manifest.solo_setup_choices.is_empty(),
		"A fixed ritual must not ask the player to choose a difficulty before playing.")
	for option in manifest.tunables:
		_expect(option["key"] != "game/creep_code_difficulty",
			"The retired difficulty option must not appear in Settings.")
	_expect(Options.SUNRAIL_TILES.size() == 12 and Options.SHAFT_FLOORS == 15
		and Options.GARDEN_ROWS.size() == 5,
		"The single authored configuration must retain the previous default puzzle sizes.")
	var rail := Sunrail.new(Options.SUNRAIL_TILES, 3, Options.SUNRAIL_SECONDS)
	_expect(rail.maximum_charge == 18 and rail.time_limit == 90.0,
		"Removing difficulty must not silently rebalance the default Sunrail.")
	var shaft := Shaft.new(Options.SHAFT_FLOORS, 1)
	_expect(shaft.probe_limit == 4, "Every player gets the same four-question shaft budget.")
	_expect(Options.RELICS.size() == 6 and Options.STORE_CURRENCY["max_per_round"] == 6,
		"The expanded ritual must award one point and one possible shard per distinct relic.")


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
