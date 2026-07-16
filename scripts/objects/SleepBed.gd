class_name SleepBed
extends Area2D


func _ready() -> void:
	input_pickable = true


func get_hover_display_name() -> String:
	return "Bed"


func request_interaction() -> bool:
	var store := get_tree().get_first_node_in_group("store")

	if store != null and store.has_method("can_player_sleep"):
		var sleep_state: Dictionary = store.call("can_player_sleep")

		if not bool(sleep_state.get("allowed", false)):
			_show_notification(str(sleep_state.get("message", "It's too early to sleep.")), 1.0)
			return false
	elif not TimeManager.can_sleep():
		_show_notification("It's too early to sleep.", 1.0)
		return false

	if TimeManager.sleep_until_next_day(true):
		_show_notification("You rest until morning.", 1.0)
		return true

	_show_notification("It's too early to sleep.", 1.0)
	return false


func _show_notification(text: String, duration: float) -> void:
	var hud := get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("show_notification"):
		hud.call("show_notification", text, duration, false)
