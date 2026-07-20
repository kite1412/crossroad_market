class_name HUDNotificationFlow
extends RefCounted

var hud: CanvasLayer = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(hud_node: CanvasLayer) -> void:
	hud = hud_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process(delta: float) -> void:
	if hud._action_lock_timer > 0.0:
		hud._action_lock_timer = max(0.0, hud._action_lock_timer - delta)

	if hud._notify_timer <= 0.0:
		return

	hud._notify_timer -= delta

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var elapsed: float = hud._notify_duration - hud._notify_timer
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var progress: float = clamp(elapsed / hud._notify_duration, 0.0, 1.0)

	if hud._notify_instant_text:
		hud.notification_label.visible_characters = hud._notify_full_chars
	else:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var reveal_progress: float = clamp(progress / 0.35, 0.0, 1.0)
		hud.notification_label.visible_characters = int(reveal_progress * hud._notify_full_chars)

	if progress < 0.75:
		hud.notification_label.modulate.a = 1.0
	else:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var fade_progress: float = clamp((progress - 0.75) / 0.25, 0.0, 1.0)
		hud.notification_label.modulate.a = 1.0 - fade_progress

	if hud._notify_timer <= 0.0:
		finish_notification()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_notification(
	text: String,
	duration: float = 2.0,
	blocks_actions: bool = true,
	instant_text: bool = false
) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var action_lock_before: float = hud._action_lock_timer
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var readable_duration := get_readable_notification_duration(text, duration)
	hud.notification_label.visible = true
	hud.notification_label.text = text
	hud._notify_full_chars = text.length()
	hud._notify_duration = readable_duration
	hud._notify_timer = hud._notify_duration
	hud._notify_instant_text = instant_text
	hud.notification_label.visible_characters = hud._notify_full_chars if instant_text else 0
	hud.notification_label.modulate.a = 1.0
	hud._notification_finished_emitted = false

	if blocks_actions:
		hud._action_lock_timer = hud._notify_duration

	pass


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_readable_notification_duration(text: String, requested_duration: float) -> float:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var readable_duration: float = float(text.length()) / hud.NOTIFY_CHARS_PER_SECOND
	return max(requested_duration, hud.MIN_NOTIFY_DURATION, readable_duration)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func wait_for_notification_finished() -> void:
	if hud._notify_timer <= 0.0:
		return

	await hud.notification_finished


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func begin_action_lock() -> void:
	hud._action_lock_sessions += 1


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func end_action_lock() -> void:
	hud._action_lock_sessions = max(0, hud._action_lock_sessions - 1)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_action_locked() -> bool:
	return hud._action_lock_sessions > 0 or hud._action_lock_timer > 0.0


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func finish_notification() -> void:
	hud._notify_timer = 0.0
	hud._notify_instant_text = false
	hud._action_lock_timer = 0.0
	hud.notification_label.modulate.a = 0.0
	hud.notification_label.visible_characters = 0
	hud.notification_label.visible = false

	if not hud._notification_finished_emitted:
		hud._notification_finished_emitted = true
		hud.notification_finished.emit()
