class_name SleepBedFlow
extends RefCounted

var bed: SleepBed = null


func setup(bed_node: SleepBed) -> void:
	bed = bed_node


func request_interaction() -> bool:
	var store := bed.get_tree().get_first_node_in_group("store")

	if store != null and store.has_method("can_player_sleep"):
		var sleep_state: Dictionary = store.call("can_player_sleep")

		if not bool(sleep_state.get("allowed", false)):
			bed._show_notification(str(sleep_state.get("message", "It's too early to sleep.")), 1.0)
			return false
	elif not TimeManager.can_sleep():
		bed._show_notification("It's too early to sleep.", 1.0)
		return false

	play_sleep_transition()
	return true


func play_sleep_transition() -> void:
	var fade_overlay := get_fade_overlay()

	if fade_overlay == null:
		if TimeManager.sleep_until_next_day(true):
			bed._show_notification("You rest until morning.", 1.0)
		return

	TimeManager.pause()

	var tween := bed.create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, bed.FADE_DURATION)
	await tween.finished

	TimeManager.sleep_until_next_day(true)
	bed._show_notification("You rest until morning.", 1.0)

	var fade_in_tween := bed.create_tween()
	fade_in_tween.tween_property(fade_overlay, "color:a", 0.0, bed.FADE_DURATION)
	await fade_in_tween.finished


func get_fade_overlay() -> ColorRect:
	var home := bed.get_tree().get_first_node_in_group("home")

	if home == null:
		return null

	return home.get_node_or_null("FadeLayer/FadeOverlay") as ColorRect


func show_notification(text: String, duration: float) -> void:
	var hud := bed.get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("show_notification"):
		hud.call("show_notification", text, duration, false)
