extends SceneTree

## Exercises real ritual payouts and the shared shop, while restoring both the
## saved wallet and in-memory state. Clothes must never become puzzle upgrades.

const Options = preload("res://games/creep_code/creep_code_options.gd")
const Models = preload("res://games/creep_code/art/toy_models.gd")
const Manager = preload("res://games/creep_code/puzzle_manager.gd")
const State = preload("res://games/creep_code/puzzles/puzzle_state.gd")
const Sunrail = preload("res://games/creep_code/puzzles/sliding_window.gd")
const Shaft = preload("res://games/creep_code/puzzles/binary_search.gd")
const Garden = preload("res://games/creep_code/puzzles/breadth_first.gd")
const Wardens = preload("res://games/creep_code/puzzles/two_pointers.gd")
const Archipelago = preload("res://games/creep_code/puzzles/union_find.gd")
const Stair = preload("res://games/creep_code/puzzles/dynamic_programming.gd")
const GAME := "res://games/creep_code/gameplay.tscn"
const FIXTURE := "res://games/creep_code/tests/expedition_fixture.gd"

var _failures := PackedStringArray()
var _store: Node
var _settings: Node
var _game: Node
var _store_state: Dictionary = {}
var _saved_file := PackedByteArray()
var _had_file := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_store = get_root().get_node("Store")
	_settings = get_root().get_node("Settings")
	if not _back_up_store():
		printerr("Cannot safely run outfit tests without backing up the store.")
		quit(1)
		return
	var original_values := (_settings.get("_values") as Dictionary).duplicate(true)
	var save_timer := _settings.get("_save_timer") as Timer
	var previous_mode := save_timer.process_mode
	save_timer.process_mode = Node.PROCESS_MODE_DISABLED
	var previous_game := GameCatalog.current_id()
	GameCatalog.select(Options.GAME_ID)
	_settings.call("set_value", Settings.REDUCED_MOTION_KEY, true)
	_settings.call("set_value", Options.RELAXED_KEY, false)
	get_root().get_node("GameSession").call("configure_single_player")
	(_store.get("_points") as Dictionary)[Options.GAME_ID] = 0
	(_store.get("_owned") as Dictionary)[Options.GAME_ID] = {"keeper": true}
	(_store.get("_equipped") as Dictionary)[Options.GAME_ID] = {
		Options.OUTFIT_SLOT: "keeper",
	}
	_test_catalogue()
	_game = await _new_game()
	if _game != null:
		_finish_ritual()
		_expect(_balance() == 6
			and (_game.get_node("%RoundHighlight") as Label).text.contains("+6 Star Shards earned"),
			"A completed six-relic ritual must bank exactly six shards and say so in results.")
		_game.call("_update_round", 10.0, 0.0)
		_game.call("_on_action", Options.INTERACT)
		_expect(_balance() == 6, "Late finale input must not pay out a second time.")
		_game.call("_on_play_again_pressed")
		_game.call("_update_round", 2.0, 0.0)
		await _test_paused_purchase()
		for id in ["ranger", "wizard"]:
			var previous_balance := _balance()
			_finish_ritual()
			_expect(_balance() == previous_balance + 6 and bool(_store.call("purchase", Options.GAME_ID, id)),
				"A replay must bank six new shards without changing outfit prices.")
			_expect(_balance() == previous_balance + 3 and _worn() == id,
				"Buying %s must spend three shards and equip it immediately." % id)
			_expect(not bool(_store.call("purchase", Options.GAME_ID, id)) and _balance() == previous_balance + 3,
				"An owned outfit cannot be charged twice.")
			_game.call("_on_play_again_pressed")
			_expect(_keeper().mesh == Models.keeper_outfit(StringName(id)),
				"Play Again must retain the player's chosen outfit.")
		var partial: Array[StringName] = [&"sunrail", &"shaft", &"garden", &"wardens", &"archipelago"]
		var previous_balance := _balance()
		_game.set("saved_relays", partial)
		_game.call("_on_play_again_pressed")
		_finish_ritual()
		_expect(_balance() == previous_balance + 1
			and (_game.get_node("%RoundHighlight") as Label).text.contains("+1 Star Shard earned"),
			"A partial save pays only the new relic solved this visit, not its historical seals.")
		_game.queue_free()
		await process_frame
		await _test_persistence_and_intro(previous_balance + 1)
	await _test_preview_motion()
	await _test_title_store()
	_restore_store()
	var values := _settings.get("_values") as Dictionary
	values.clear()
	values.merge(original_values, true)
	save_timer.stop()
	save_timer.process_mode = previous_mode
	GameCatalog.select(previous_game)
	await create_timer(0.25, true, false, true).timeout
	for failure in _failures:
		printerr(failure)
	if _failures.is_empty():
		print("Creep Code outfit store tests passed.")
	quit(0 if _failures.is_empty() else 1)


func _test_catalogue() -> void:
	var manifest := GameCatalog.get_manifest(Options.GAME_ID)
	_expect(manifest.has_store() and manifest.store_items.size() == 4
		and manifest.store_slots.size() == 1, "The keeper must have one wardrobe and four looks.")
	var ids: Array[StringName] = []
	for item: Dictionary in _store.call("items", Options.GAME_ID):
		var id := StringName(str(item["id"]))
		ids.append(id)
		_expect(Models.keeper_outfit(id) != null and not bool(item["locked"]),
			"Every listed outfit must be drawable without an achievement gate.")
		_expect(int(item["price"]) == (0 if id == Options.DEFAULT_OUTFIT else 3),
			"The original keeper is free; each new outfit costs exactly three shards.")
	_expect(ids == Models.KEEPER_OUTFITS and _worn() == "keeper",
		"The catalogue must offer the keeper, warrior, ranger and wizard, starting in the keeper.")
	_expect(not bool(_store.call("purchase", Options.GAME_ID, "warrior"))
		and not bool(_store.call("equip", Options.GAME_ID, "wizard", Options.OUTFIT_SLOT))
		and _balance() == 0, "Unbought outfits must not be wearable or purchasable without shards.")


func _test_paused_purchase() -> void:
	var manager: Manager = _game.get("_manager")
	var rail := manager.current() as Sunrail
	_game.call("_on_action", Options.INTERACT)
	_game.call("_update_round", 1.25, 0.0)
	var seconds := rail.remaining_seconds
	var keeper_id := _keeper().get_instance_id()
	var previous_balance := _balance()
	_game.call("open_pause_menu")
	await process_frame
	var pause := _game.get("_pause_menu") as Node
	_expect((pause.get_node("%StoreButton") as Button).visible,
		"The wardrobe must be reachable without abandoning a ritual.")
	pause.call("_on_store_pressed")
	await process_frame
	var shop := pause.get("_store_overlay") as Node
	var cards: Array = shop.get("_cards")
	var preview_additions := [0]
	_expect(cards.size() == 4 and str(shop.get("game_context_id")) == Options.GAME_ID,
		"The pause overlay must open the real shared shop for Creep Code.")
	for card: Node in cards:
		(card.get("_preview") as Node).child_entered_tree.connect(
			func(_child: Node) -> void: preview_additions[0] += 1
		)
		var preview := card.get("_preview_instance") as Node
		_expect(preview != null and (preview.get("_keeper") as MeshInstance3D).mesh
			== Models.keeper_outfit(StringName(str(card.call("item_id")))),
			"The shelf must preview each real outfit, including ones not yet owned.")
	shop.call("_on_buy_requested", "warrior")
	await process_frame
	_expect(preview_additions[0] == cards.size(),
		"A purchase must refresh each card once, without repeatedly removing deferred focus targets.")
	_expect(paused and _balance() == previous_balance - 3 and _worn() == "warrior"
		and _keeper().mesh == Models.keeper_outfit(&"warrior"),
		"Buying from pause must dress the actual keeper immediately, even while the tree is paused.")
	_expect(_keeper().get_instance_id() == keeper_id and rail.remaining_seconds == seconds
		and rail.phase == State.Phase.ACTIVE and rail.tiles == Options.SUNRAIL_TILES,
		"Equipping must preserve the keeper instance, puzzle configuration and exact remaining time.")
	_store.emit_signal("equipped_changed", "another_game", Options.OUTFIT_SLOT, "wizard")
	_expect(_keeper().mesh == Models.keeper_outfit(&"warrior"),
		"Another game's wardrobe must never change the keeper.")
	for card: Node in cards:
		var preview := card.get("_preview_instance") as Node
		_expect(not preview.is_processing(),
			"Rebuilt previews after a purchase must still honor reduced motion.")
	shop.call("go_back")
	await process_frame
	await process_frame
	pause.call("resume")
	await process_frame
	_expect(not paused and _worn() == "warrior" and rail.remaining_seconds == seconds,
		"Returning from the wardrobe resumes the same dressed keeper and untouched clock.")


func _test_persistence_and_intro(expected_balance: int) -> void:
	_store.call("_save_state")
	(_store.get("_points") as Dictionary)[Options.GAME_ID] = 0
	(_store.get("_owned") as Dictionary)[Options.GAME_ID] = {}
	(_store.get("_equipped") as Dictionary)[Options.GAME_ID] = {}
	_store.call("_load_state")
	_expect(_balance() == expected_balance and _worn() == "wizard",
		"Wallet and equipped outfit must survive a real ConfigFile reload.")
	for id in Models.KEEPER_OUTFITS:
		_expect(bool(_store.call("is_owned", Options.GAME_ID, str(id))),
			"Every purchased outfit must remain owned after reloading.")
	var intro := (load("res://games/creep_code/intro.tscn") as PackedScene).instantiate()
	intro.set_script(load("res://games/creep_code/tests/intro_fixture.gd"))
	get_root().add_child(intro)
	await process_frame
	intro.set_process(false)
	var view := intro.get("_view") as Node
	_expect((view.get("_keeper_mesh") as MeshInstance3D).mesh == Models.keeper_outfit(&"wizard")
		and (view.get("_player_label") as Node3D).position.y
		> Models.keeper_outfit(&"wizard").get_aabb().end.y,
		"The opening must wear the saved outfit, with labels kept above even the tallest hat.")
	_expect(_balance() == expected_balance, "Demonstration relays must never mint spendable shards.")
	intro.queue_free()
	await process_frame
	var config := ConfigFile.new()
	_expect(config.load(Store.SAVE_PATH) == OK, "The outfit save must be readable.")
	config.set_value(Store.EQUIPPED_SECTION, Options.GAME_ID, {
		Options.OUTFIT_SLOT: "future_outfit",
	})
	var owned: PackedStringArray = config.get_value(Store.OWNED_SECTION, Options.GAME_ID)
	owned.append("future_outfit")
	config.set_value(Store.OWNED_SECTION, Options.GAME_ID, owned)
	_expect(config.save(Store.SAVE_PATH) == OK, "The compatibility fixture must be writable.")
	_store.call("_load_state")
	_expect(_worn() == "keeper" and bool(_store.call("is_owned", Options.GAME_ID, "future_outfit")),
		"Unknown saved equipment must display the original keeper without deleting its ownership.")
	var restored := await _new_game()
	if restored != null:
		_expect((restored.get("_view") as Node).get("_outfit_id") == Options.DEFAULT_OUTFIT,
			"A restarted scene must safely resolve equipment from a newer build.")
		restored.queue_free()
		await process_frame


func _test_preview_motion() -> void:
	var packed := load(GameCatalog.get_manifest(Options.GAME_ID).store_preview_scene_path) as PackedScene
	var preview := packed.instantiate() as Control
	preview.call("configure", _store.call("describe", Options.GAME_ID, "ranger"))
	preview.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	preview.size = Vector2(320, 176)
	get_root().add_child(preview)
	await process_frame
	var keeper := preview.get("_keeper") as MeshInstance3D
	var resting := keeper.rotation
	preview.call("set_preview_running", true)
	preview.call("_process", 1.0)
	_expect(keeper.rotation == resting and not preview.is_processing(),
		"A shelf cannot override the player's reduced-motion setting.")
	_settings.call("set_value", Settings.REDUCED_MOTION_KEY, false)
	preview.call("_process", 1.0)
	_expect(keeper.rotation != resting and preview.is_processing(),
		"Motion-enabled previews must turn the real costume, not animate an unrelated icon.")
	preview.call("set_preview_running", false)
	_expect(keeper.rotation == resting and not preview.is_processing(),
		"Stopping a preview restores a stable, readable three-quarter pose.")
	preview.queue_free()
	await process_frame
	_settings.call("set_value", Settings.REDUCED_MOTION_KEY, true)


func _test_title_store() -> void:
	GameCatalog.restrict_to(Options.GAME_ID)
	var menu := (load("res://scenes/menus/main_menu.tscn") as PackedScene).instantiate()
	get_root().add_child(menu)
	await process_frame
	_expect((menu.get_node("%StoreButton") as Button).visible,
		"A standalone Creep Code build must offer its wardrobe on the title screen.")
	menu.queue_free()
	await process_frame
	GameCatalog.clear_restriction()


func _new_game() -> Node:
	var packed := load(GAME) as PackedScene
	var fixture := load(FIXTURE) as Script
	if packed == null or fixture == null or not fixture.can_instantiate():
		_failures.append("The real ritual must compile before its outfit store can be tested.")
		return null
	var game := packed.instantiate()
	game.set_script(fixture)
	game.set("bank_store_rewards", true)
	get_root().add_child(game)
	await process_frame
	game.set_process(false)
	(game.get("_view") as Node).set_process(false)
	return game


func _finish_ritual() -> void:
	for transition in range(Options.RELICS.size() * 4 + 2):
		if not bool(_game.get("_round_active")):
			break
		if _game.get("_ritual_phase") != &"puzzle":
			_game.call("_update_round", 2.0, 0.0)
			continue
		var state := (_game.get("_manager") as Manager).current()
		if state is Sunrail:
			for index in range(state.tiles.size() - state.width + 1):
				_game.call("_on_selection_requested", index)
				if state.charge == state.maximum_charge:
					break
			if state.phase == State.Phase.READY:
				_game.call("_on_action", Options.INTERACT)
			_game.call("_on_action", Options.INTERACT)
		elif state is Shaft:
			for attempt in range(state.probe_limit):
				if state.phase != State.Phase.ACTIVE:
					break
				_game.call("_on_selection_requested",
					state.lower_bound + (state.upper_bound - state.lower_bound) / 2)
				_game.call("_on_action", Options.INTERACT)
		elif state is Garden:
			_game.call("_on_action", Options.INTERACT)
			var path: Array[Vector2i] = state.shortest_path()
			for index in range(1, path.size()):
				_game.call("_on_cell_requested", path[index])
				(_game.get("_view") as Node).call("_process", 1.0)
		elif state is Wardens:
			for move in range(state.values.size()):
				if state.charge == state.target_charge:
					break
				_game.call("_on_action", Options.LEFT if state.charge < state.target_charge else Options.RIGHT)
			_game.call("_on_action", Options.INTERACT)
		elif state is Archipelago:
			for index in range(5):
				_game.call("_on_selection_requested", index)
				_game.call("_on_action", Options.INTERACT)
		elif state is Stair:
			for index in range(state.records.size(), state.costs.size()):
				var one: int = state.records[index - 1] if index > 0 else 0
				var two: int = state.records[index - 2] if index > 1 else 0
				_game.call("_on_action", Options.RIGHT if index > 0 and two < one else Options.LEFT)
				_game.call("_on_action", Options.INTERACT)
			var path: Array[int] = state.cheapest_path()
			for index in range(1, path.size()):
				_game.call("_on_selection_requested", path[index])
				_game.call("_on_action", Options.INTERACT)
				(_game.get("_view") as Node).call("_process", 1.0)
	_expect(not bool(_game.get("_round_active")), "The payout driver must finish the actual ritual.")


func _keeper() -> MeshInstance3D:
	return (_game.get("_view") as Node).get("_keeper_mesh") as MeshInstance3D


func _balance() -> int:
	return int(_store.call("points", Options.GAME_ID))


func _worn() -> String:
	return str(_store.call("equipped_id", Options.GAME_ID, Options.OUTFIT_SLOT))


func _back_up_store() -> bool:
	for key in ["_points", "_owned", "_equipped"]:
		_store_state[key] = (_store.get(key) as Dictionary).duplicate(true)
	_had_file = FileAccess.file_exists(Store.SAVE_PATH)
	if _had_file:
		var file := FileAccess.open(Store.SAVE_PATH, FileAccess.READ)
		if file == null:
			return false
		_saved_file = file.get_buffer(file.get_length())
	return true


func _restore_store() -> void:
	for key in _store_state:
		var values := _store.get(key) as Dictionary
		values.clear()
		values.merge(_store_state[key], true)
	if _had_file:
		var file := FileAccess.open(Store.SAVE_PATH, FileAccess.WRITE)
		_expect(file != null, "The original store file must be restorable.")
		if file != null:
			file.store_buffer(_saved_file)
	elif FileAccess.file_exists(Store.SAVE_PATH):
		_expect(DirAccess.remove_absolute(ProjectSettings.globalize_path(Store.SAVE_PATH)) == OK,
			"The temporary outfit wallet must be removed.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
