class_name SleepBedFlow
extends RefCounted

var bed: SleepBed = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(bed_node: SleepBed) -> void:
	bed = bed_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func request_interaction() -> bool:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var store := bed.get_tree().get_first_node_in_group("store")

	if store != null and store.has_method("can_player_sleep"):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var sleep_state: Dictionary = store.call("can_player_sleep")

		if not bool(sleep_state.get("allowed", false)):
			bed._show_notification(str(sleep_state.get("message", "It's too early to sleep.")), 1.0)
			return false
	elif not TimeManager.can_sleep():
		bed._show_notification("It's too early to sleep.", 1.0)
		return false

	play_sleep_transition()
	return true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func play_sleep_transition() -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var fade_overlay := get_fade_overlay()

	if fade_overlay == null:
		if TimeManager.sleep_until_next_day(true):
			bed._show_notification("You rest until morning.", 1.0)
		return

	TimeManager.pause()

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var tween := bed.create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, bed.FADE_DURATION)
	await tween.finished

	TimeManager.sleep_until_next_day(true)
	bed._show_notification("You rest until morning.", 1.0)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var fade_in_tween := bed.create_tween()
	fade_in_tween.tween_property(fade_overlay, "color:a", 0.0, bed.FADE_DURATION)
	await fade_in_tween.finished


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_fade_overlay() -> ColorRect:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var home := bed.get_tree().get_first_node_in_group("home")

	if home == null:
		return null

	return home.get_node_or_null("FadeLayer/FadeOverlay") as ColorRect


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_notification(text: String, duration: float) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var hud := bed.get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("show_notification"):
		hud.call("show_notification", text, duration, false)
