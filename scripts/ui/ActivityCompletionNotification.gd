extends Control


@onready var message: Label = $Panel/Message

@warning_ignore("unused_private_class_variable")
var _notification_flow: ActivityCompletionNotificationFlow = ActivityCompletionNotificationFlow.new()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ready() -> void:
	_notification_flow.setup(self)
	_connect_activity_completion_manager()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _connect_activity_completion_manager() -> void:
	_notification_flow.connect_activity_completion_manager()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _show_message(msg: String) -> void:
	await _notification_flow.show_message(msg)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _hide() -> void:
	_notification_flow.hide()
