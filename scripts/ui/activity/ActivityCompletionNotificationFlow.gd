class_name ActivityCompletionNotificationFlow
extends RefCounted

var notification: Control = null


func setup(notification_node: Control) -> void:
	notification = notification_node


func connect_activity_completion_manager() -> void:
	var manager := notification.get_node_or_null("/root/ActivityCompletionManager")

	if manager == null:
		notification.call_deferred("_connect_activity_completion_manager")
		return

	if manager.has_signal("activity_completion"):
		var show_callable := Callable(notification, "_show_message")

		if not manager.activity_completion.is_connected(show_callable):
			manager.activity_completion.connect(show_callable)


func show_message(msg: String) -> void:
	notification.message.text = msg
	notification.visible = true
	notification.scale = Vector2.ZERO

	var tween = notification.create_tween()
	tween.tween_property(notification, "scale", Vector2.ONE, 0.2)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	await notification.get_tree().create_timer(2.0).timeout
	hide()


func hide() -> void:
	var tween = notification.create_tween()
	tween.tween_property(notification, "scale", Vector2.ZERO, 0.15)
	tween.finished.connect(func():
		notification.visible = false
	)
