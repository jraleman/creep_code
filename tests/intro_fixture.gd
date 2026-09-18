extends "res://games/creep_code/intro.gd"

## The opening's real timeline can finish without replacing the test runner.

var menu_transitions := 0


func _navigate_to_menu() -> void:
	menu_transitions += 1
