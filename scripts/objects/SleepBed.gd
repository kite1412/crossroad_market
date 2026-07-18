class_name SleepBed
extends Area2D

const FADE_DURATION: float = 2.0


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

	_play_sleep_transition()
	return true


func _play_sleep_transition() -> void:
	var fade_overlay := _get_fade_overlay()

	if fade_overlay == null:
		# Fallback: advance day directly if overlay not found
		if TimeManager.sleep_until_next_day(true):
			_show_notification("You rest until morning.", 1.0)
		return

	# Pause time while fading
	TimeManager.pause()

	# Fade out to black
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, FADE_DURATION)
	await tween.finished

	# Advance the day while screen is black
	TimeManager.sleep_until_next_day(true)
	_show_notification("You rest until morning.", 1.0)

	# Fade back in
	var fade_in_tween := create_tween()
	fade_in_tween.tween_property(fade_overlay, "color:a", 0.0, FADE_DURATION)
	await fade_in_tween.finished


func _get_fade_overlay() -> ColorRect:
	var home := get_tree().get_first_node_in_group("home")

	if home == null:
		return null

	return home.get_node_or_null("FadeLayer/FadeOverlay") as ColorRect


func _show_notification(text: String, duration: float) -> void:
	var hud := get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("show_notification"):
		hud.call("show_notification", text, duration, false)
