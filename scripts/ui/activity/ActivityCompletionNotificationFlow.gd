class_name ActivityCompletionNotificationFlow
extends RefCounted

var notification: Control = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(notification_node: Control) -> void:
	notification = notification_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func connect_activity_completion_manager() -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var manager := notification.get_node_or_null("/root/ActivityCompletionManager")

	if manager == null:
		notification.call_deferred("_connect_activity_completion_manager")
		return

	if manager.has_signal("activity_completion"):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var show_callable := Callable(notification, "_show_message")

		if not manager.activity_completion.is_connected(show_callable):
			manager.activity_completion.connect(show_callable)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_message(msg: String) -> void:
	notification.message.text = msg
	notification.visible = true
	notification.scale = Vector2.ZERO

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var tween = notification.create_tween()
	tween.tween_property(notification, "scale", Vector2.ONE, 0.2)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	await notification.get_tree().create_timer(2.0).timeout
	hide()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func hide() -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var tween = notification.create_tween()
	tween.tween_property(notification, "scale", Vector2.ZERO, 0.15)
	tween.finished.connect(func():
		notification.visible = false
	)
