extends RefCounted

## Node-free relic contract. Presentation and persistence listen to signals;
## neither physics transforms nor autoloads decide whether a puzzle is solved.

signal changed
signal cue(message: String, kind: StringName)
signal solved
signal failed(reason: String)

enum Phase { READY, ACTIVE, SOLVED, FAILED }

var phase := Phase.READY
var hints_used := 0
var failure_reason := ""


## A retry clears only this attempt, never the manager's completed relics.
func reset() -> void:
	phase = Phase.READY
	hints_used = 0
	failure_reason = ""


## Most mechanisms restart fully; a mapped garden can retain its discoveries.
func retry() -> void:
	reset()


## Explicit arming keeps reading and experimenting separate from a deadline.
func activate() -> void:
	if phase != Phase.READY:
		return
	phase = Phase.ACTIVE
	changed.emit()


## Only a playable relic receives simulation time from the game shell.
func advance(_delta: float) -> void:
	pass


## Hints belong to the mechanism, rather than an out-of-world lesson screen.
func hint() -> String:
	hints_used += 1
	return "Watch what changes, and what stays the same."


## A readable state is also available without a renderer or sound device.
func status_text() -> String:
	return failure_reason if phase == Phase.FAILED else ""


func _succeed() -> void:
	if phase != Phase.ACTIVE:
		return
	phase = Phase.SOLVED
	solved.emit()
	changed.emit()
	cue.emit("Seal restored. The constellation grows.", &"success")


func _fail(reason: String) -> void:
	if phase != Phase.ACTIVE:
		return
	phase = Phase.FAILED
	failure_reason = reason
	failed.emit(reason)
	changed.emit()
	cue.emit(reason, &"failure")


func _invalid_configuration(reason: String) -> void:
	phase = Phase.FAILED
	failure_reason = reason
	push_error("Creep Code puzzle: " + reason)
