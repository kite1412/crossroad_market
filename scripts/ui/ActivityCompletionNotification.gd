extends Control

const ActivityCompletionNotificationFlow = preload("res://scripts/ui/activity/ActivityCompletionNotificationFlow.gd")

@onready var message: Label = $Panel/Message

var _notification_flow: ActivityCompletionNotificationFlow = ActivityCompletionNotificationFlow.new()


func _ready() -> void:
	_notification_flow.setup(self)
	_connect_activity_completion_manager()


func _connect_activity_completion_manager() -> void:
	_notification_flow.connect_activity_completion_manager()


func _show_message(msg: String) -> void:
	await _notification_flow.show_message(msg)


func _hide() -> void:
	_notification_flow.hide()
