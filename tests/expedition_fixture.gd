extends "res://games/creep_code/gameplay.gd"

## Only persistence is replaced; the complete ritual and its input paths are real.

var saved_relays: Array[StringName] = []
var observed_achievements := PackedStringArray()
var bank_store_rewards := false


func _saved_completions() -> Array[StringName]:
	return saved_relays.duplicate()


func _unlock_round_achievement(id: String) -> void:
	if not observed_achievements.has(id):
		observed_achievements.append(id)
	for definition in Options.RELICS:
		if definition["achievement"] == id and not saved_relays.has(definition["id"]):
			saved_relays.append(definition["id"])


func _record_round(_player_one_total: int, _player_two_total: int) -> String:
	return ""


func _bank_store_points(player_one_total: int, player_two_total: int) -> void:
	if bank_store_rewards:
		super(player_one_total, player_two_total)
