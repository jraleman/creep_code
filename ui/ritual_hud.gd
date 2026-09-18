extends Control

## A compact, unboxed action row leaves the full stage available for direct
## interaction. Long rules belong in an on-demand, paused grimoire, not a sidebar.

const Options = preload("res://games/creep_code/creep_code_options.gd")
const Manager = preload("res://games/creep_code/puzzle_manager.gd")
const State = preload("res://games/creep_code/puzzles/puzzle_state.gd")
const Sunrail = preload("res://games/creep_code/puzzles/sliding_window.gd")
const Shaft = preload("res://games/creep_code/puzzles/binary_search.gd")
const Wardens = preload("res://games/creep_code/puzzles/two_pointers.gd")
const Archipelago = preload("res://games/creep_code/puzzles/union_find.gd")
const Stair = preload("res://games/creep_code/puzzles/dynamic_programming.gd")
const Palette = preload("res://games/creep_code/art/palette.gd")

signal action_requested(action: StringName)

var _dock: VBoxContainer
var _caption: Label
var _toolbar: BoxContainer
var _navigation: HBoxContainer
var _utilities: HBoxContainer
var _buttons: Dictionary[StringName, Button] = {}
var _book_buttons: Dictionary[StringName, Button] = {}
var _shade: ColorRect
var _book: PanelContainer
var _book_column: VBoxContainer
var _book_title: Label
var _ledger: Label
var _scroll: ScrollContainer
var _words: VBoxContainer
var _feedback: Label
var _instructions: Label
var _score_rules: Label
var _reading := false
var _wide_directions := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock = VBoxContainer.new()
	_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock.add_theme_constant_override("separation", 8)
	add_child(_dock)
	_caption = _label(_dock, 18, Palette.CREAM)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.max_lines_visible = 2
	_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_caption.add_theme_color_override("font_outline_color", Palette.INK)
	_caption.add_theme_constant_override("outline_size", 5)
	_toolbar = BoxContainer.new()
	_toolbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toolbar.add_theme_constant_override("separation", 6)
	_dock.add_child(_toolbar)
	_navigation = HBoxContainer.new()
	_navigation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_navigation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_navigation.add_theme_constant_override("separation", 4)
	_toolbar.add_child(_navigation)
	for action: StringName in [Options.LEFT, Options.UP, Options.DOWN, Options.RIGHT]:
		_buttons[action] = _button(action, _navigation)
		_buttons[action].size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_buttons[Options.INTERACT] = _button(Options.INTERACT, _navigation)
	_utilities = HBoxContainer.new()
	_utilities.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_utilities.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_utilities.add_theme_constant_override("separation", 4)
	_toolbar.add_child(_utilities)
	for action: StringName in [Options.BACK, Options.RESET, Options.HINT]:
		_buttons[action] = _button(action, _utilities)
	_build_book()
	_apply_primary_style(_buttons[Options.INTERACT])


## Both the normal row and grimoire reflect the player's actual bindings.
func set_bindings(names: Dictionary[StringName, String]) -> void:
	for group in [_buttons, _book_buttons]:
		for action: StringName in group:
			(group[action] as Button).set_meta("key_name", names.get(action, ""))
	var directions := {
		Options.LEFT: "Left", Options.UP: "Up", Options.DOWN: "Down", Options.RIGHT: "Right",
	}
	for action: StringName in directions:
		_buttons[action].text = "%s\n[%s]" % [directions[action], names.get(action, "")]
	_set_button_text(_buttons[Options.BACK], "Grimoire")
	_set_button_text(_buttons[Options.RESET], "Retry")
	_set_button_text(_buttons[Options.HINT], "Hint")
	_set_button_text(_book_buttons[Options.INTERACT], "Return to relic")
	_set_button_text(_book_buttons[Options.HINT], "Next hint")


## The caption preserves meaningful clues even when audio captions are disabled.
func present(
	manager: Manager, instructions: String, feedback: String,
	primary: String, phase: StringName, reading: bool, feedback_kind: StringName
) -> void:
	if reading != _reading:
		_scroll.scroll_vertical = 0
	_reading = reading
	_dock.visible = not reading
	_shade.visible = reading
	_book.visible = reading
	var state := manager.current()
	var accepting := phase == &"puzzle" and not reading
	_caption.text = _compact_status(manager, phase)
	if accepting and feedback_kind in [&"blocked", &"higher", &"lower", &"heard", &"failure"]:
		_caption.text = feedback
	_set_button_text(_buttons[Options.INTERACT], primary)
	_buttons[Options.BACK].disabled = phase != &"puzzle"
	_buttons[Options.HINT].disabled = phase != &"puzzle"
	_buttons[Options.RESET].disabled = not accepting
	var direction_names := {
		Options.LEFT: "Left", Options.UP: "Up", Options.DOWN: "Down", Options.RIGHT: "Right",
	}
	if state is Archipelago:
		direction_names[Options.LEFT] = "Prev"
		direction_names[Options.RIGHT] = "Next"
		direction_names[Options.UP] = "Undo"
	elif state is Stair:
		direction_names[Options.LEFT] = "1 step"
		direction_names[Options.RIGHT] = "2 steps"
	_wide_directions = state is Stair
	var units := maxf(1.0, size.x / maxf(1, get_window().size.x))
	for action: StringName in [Options.LEFT, Options.RIGHT, Options.UP, Options.DOWN]:
		_buttons[action].custom_minimum_size.x = (60 if _wide_directions else 44) * units
		_buttons[action].text = "%s\n[%s]" % [
			direction_names[action], _buttons[action].get_meta("key_name", ""),
		]
		_buttons[action].visible = not (
			(state is Wardens or state is Stair) and action in [Options.UP, Options.DOWN]
			or state is Archipelago and action == Options.DOWN
		)
		_buttons[action].disabled = not accepting or (
			state is Sunrail and action in [Options.UP, Options.DOWN]
		) or (
			state is Archipelago and action == Options.UP and state.bridges.is_empty()
		)
	_book_title.text = "GRIMOIRE / " + manager.title(manager.current_id)
	_ledger.text = "Reading paused | Points %d/%d | Permanent seals %d/%d" % [
		manager.solved_this_visit.size(), Options.RELICS.size(),
		manager.completed.size(), Options.RELICS.size(),
	]
	_feedback.text = feedback
	_instructions.text = instructions


## The stage keeps the same full-width bounds whether the book is open or shut.
func layout_for(viewport_size: Vector2, top: float) -> Rect2:
	position = Vector2.ZERO
	size = viewport_size
	var units := maxf(1.0, viewport_size.x / maxf(1, get_window().size.x))
	var margin := 12.0 * units
	var compact := get_window().size.x < 600
	var short_row := not compact and get_window().size.y < 480
	var caption_height := (22 if short_row else 38) * units
	_toolbar.vertical = compact
	_caption.add_theme_font_size_override("font_size", roundi(15 * units))
	_caption.max_lines_visible = 1 if short_row else 2
	_caption.custom_minimum_size.y = caption_height
	for action in _buttons:
		var button := _buttons[action]
		button.add_theme_font_size_override("font_size", roundi(13 * units))
		button.custom_minimum_size = Vector2(0, 44 * units)
		if action in [Options.LEFT, Options.RIGHT, Options.UP, Options.DOWN]:
			button.custom_minimum_size.x = (60 if _wide_directions else 44) * units
	_buttons[Options.INTERACT].custom_minimum_size.x = 116 * units
	_dock.size = Vector2(minf(viewport_size.x - margin * 2, 980 * units), 0)
	var height := caption_height + (94 if compact else 44) * units + 12 * units
	_dock.size.y = height
	_dock.position = Vector2((viewport_size.x - _dock.size.x) * 0.5,
		viewport_size.y - margin - height)
	_shade.position = Vector2(0, top)
	_shade.size = Vector2(viewport_size.x, maxf(1, viewport_size.y - top))
	var book_size := Vector2(
		minf(740 * units, viewport_size.x - margin * 2),
		minf(560 * units, viewport_size.y - top - margin * 2)
	)
	_book.position = Vector2((viewport_size.x - book_size.x) * 0.5,
		top + (viewport_size.y - top - book_size.y) * 0.5)
	_book.size = book_size
	var style := _book.get_theme_stylebox("panel") as StyleBoxFlat
	style.set_content_margin_all(16 * units)
	_book_title.add_theme_font_size_override("font_size", roundi(21 * units))
	_ledger.add_theme_font_size_override("font_size", roundi(12 * units))
	for label in [_feedback, _instructions, _score_rules]:
		label.add_theme_font_size_override("font_size", roundi(16 * units))
	for button in _book_buttons.values():
		button.add_theme_font_size_override("font_size", roundi(14 * units))
		button.custom_minimum_size.y = 44 * units
	return Rect2(Vector2(margin, top), Vector2(
		viewport_size.x - margin * 2, maxf(1, _dock.position.y - top - 8 * units)
	))


## A deferred reveal cannot scroll a puzzle the player has already returned to.
func reveal_hint() -> void:
	if not _reading:
		return
	var target := _feedback.get_global_rect()
	var viewport := _scroll.get_global_rect()
	if target.size.y > viewport.size.y or target.position.y < viewport.position.y:
		_scroll.scroll_vertical += floori(target.position.y - viewport.position.y)
	elif target.end.y > viewport.end.y:
		_scroll.scroll_vertical += ceili(target.end.y - viewport.end.y)


func _compact_status(manager: Manager, phase: StringName) -> String:
	var title := manager.title(manager.current_id)
	match phase:
		&"arriving":
			return title + " awakens. Click or tap the relic, or use the direction keys."
		&"restoring":
			return "+1 point. Seal saved; your constellation is growing."
		&"departing":
			return "The stage transforms. Your restored seals are safe."
		&"finale":
			return "All six seals joined. The stars return."
	var state := manager.current()
	if state.phase == State.Phase.FAILED:
		return state.failure_reason + " Retrying costs no points."
	if state is Sunrail:
		return "Sunrail | Cells %d-%d: %d charge | Best %d | Tap the first crystal" % [
			state.start_index + 1, state.start_index + state.width, state.charge, state.best_charge,
		]
	if state is Shaft:
		return "Whisper Shaft | Floor %d | Open %d-%d | Tap a seal, then listen" % [
			state.selected_floor, state.lower_bound, state.upper_bound,
		]
	if state is Wardens or state is Archipelago or state is Stair:
		return manager.title(manager.current_id).trim_prefix("The ") + " | " + state.status_text()
	return "Echo Garden | Tap a neighboring platform; follow increasing numbers to EXIT."


func _build_book() -> void:
	_shade = ColorRect.new()
	_shade.color = Color(Palette.INK, 0.78)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_shade)
	_book = PanelContainer.new()
	_book.name = "Grimoire"
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.PANEL
	style.border_color = Palette.BRASS
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16)
	_book.add_theme_stylebox_override("panel", style)
	add_child(_book)
	_book_column = VBoxContainer.new()
	_book_column.add_theme_constant_override("separation", 10)
	_book.add_child(_book_column)
	_book_title = _label(_book_column, 24, Palette.GOLD)
	_ledger = _label(_book_column, 14, Palette.BLUE_LIGHT)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_book_column.add_child(_scroll)
	_words = VBoxContainer.new()
	_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_words.add_theme_constant_override("separation", 18)
	_scroll.add_child(_words)
	_feedback = _label(_words, 20, Palette.CREAM)
	_instructions = _label(_words, 20, Palette.PAPER)
	_score_rules = _label(_words, 18, Palette.GOLD)
	_score_rules.text = Options.SCORE_RULES + "\n\n" + Options.STORE_RULES
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	_book_column.add_child(actions)
	for action: StringName in [Options.INTERACT, Options.HINT]:
		_book_buttons[action] = _button(action, actions)
	_apply_primary_style(_book_buttons[Options.INTERACT])
	_shade.hide()
	_book.hide()


func _button(action: StringName, parent: Container) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 44
	parent.add_child(button)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var compact := button.get_theme_stylebox(state).duplicate() as StyleBox
		compact.set_content_margin_all(5)
		button.add_theme_stylebox_override(state, compact)
	button.pressed.connect(func() -> void: action_requested.emit(action))
	return button


func _apply_primary_style(button: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.BLUE_DARK
	style.border_color = Palette.GOLD
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(6)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_color_override("font_color", Palette.CREAM)


func _set_button_text(button: Button, text: String) -> void:
	button.text = "%s [%s]" % [text, button.get_meta("key_name", "")]


func _label(parent: Node, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
